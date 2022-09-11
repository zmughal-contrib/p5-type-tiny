package Type::Params::Alternatives;

use 5.008001;
use strict;
use warnings;

BEGIN {
	if ( $] < 5.010 ) { require Devel::TypeTiny::Perl58Compat }
}

BEGIN {
	$Type::Params::Alternatives::AUTHORITY  = 'cpan:TOBYINK';
	$Type::Params::Alternatives::VERSION    = '1.999_005';
}

$Type::Params::Alternatives::VERSION =~ tr/_//d;

use B ();
use Eval::TypeTiny::CodeAccumulator;
use Types::Standard qw( -is -types -assert );
use Types::TypeTiny qw( -is -types to_TypeTiny );

require Type::Params::Signature;
our @ISA = 'Type::Params::Signature';

sub new {
	my $class = shift;
	my %self  = @_ == 1 ? %{$_[0]} : @_;
	my $self = bless \%self, $class;
	exists( $self->{$_} ) || ( $self->{$_} = $self->{base_options}{$_} )
		for keys %{ $self->{base_options} };
	$self->{sig_class} ||= 'Type::Params::Signature';
	$self->{message}   ||= 'Parameter validation failed';
	return $self;
}

sub base_options      { $_[0]{base_options}      ||= {} }
sub alternatives      { $_[0]{alternatives}      ||= [] }
sub sig_class         { $_[0]{sig_class} }
sub meta_alternatives { $_[0]{meta_alternatives} ||= $_[0]->_build_meta_alternatives }
sub parameters        { [] }

sub _build_meta_alternatives {
	my $self = shift;

	my $index = 0;
	return [
		map {
			my $meta = $self->_build_meta_alternative( $_ );
			$meta->{_index} = $index++;
			$meta;
		} @{ $self->alternatives }
	];
}

sub _build_meta_alternative {
	my ( $self, $alt ) = @_;

	if ( is_CodeRef $alt ) {
		return {
			closure => $alt,
		};
	}
	elsif ( is_HashRef $alt ) {
		my %opts = (
			%{ $self->base_options },
			%$alt,
			want_source  => !!0,
			want_object  => !!0,
			want_details => !!1,
		);
		my $sig = $self->sig_class->new_from_v2api( \%opts );
		return $sig->return_wanted;
	}
	elsif ( is_ArrayRef $alt ) {
		my %opts = (
			%{ $self->base_options },
			positional   => $alt,
			want_source  => !!0,
			want_object  => !!0,
			want_details => !!1,
		);
		my $sig = $self->sig_class->new_from_v2api( \%opts );
		return $sig->return_wanted;
	}
	else {
		$self->_croak( 'Alternative signatures must be CODE, HASH, or ARRAY refs' );
	}
}

sub _build_coderef {
	my $self = shift;
	my $coderef = $self->_new_code_accumulator(
		description => $self->base_options->{description}
			|| sprintf( q{parameter validation for '%s::%s'}, $self->base_options->{package} || '', $self->base_options->{subname} || '__ANON__' )
	);

	$self->_coderef_start( $coderef );

	$coderef->add_line( 'my $return;' );
	$coderef->add_gap;

	for my $meta ( @{ $self->meta_alternatives } ) {
		$self->_coderef_meta_alternative( $coderef, $meta );
	}

	$self->_coderef_end( $coderef );

	return $coderef;
}

sub _coderef_meta_alternative {
	my ( $self, $coderef, $meta ) = ( shift, @_ );

	my @cond = '! $return';
	push @cond, sprintf( '@_ >= %s', $meta->{min_args} ) if defined $meta->{min_args};
	push @cond, sprintf( '@_ <= %s', $meta->{max_args} ) if defined $meta->{max_args};
	if ( defined $meta->{max_args} and defined $meta->{min_args} ) {
		splice @cond, -2, 2, sprintf( '@_ == %s', $meta->{min_args} )
			if $meta->{max_args} == $meta->{min_args};
	}

	my $callback_var = $coderef->add_variable( '$alt', \$meta->{closure} );
	$coderef->add_line( sprintf(
		'eval { $return = [ %s->(@_) ]; ${^TYPE_PARAMS_MULTISIG} = %d }%sif ( %s );',
		$callback_var,
		$meta->{_index},
		"\n\t",
		join( ' and ', @cond ),
	) );
	$coderef->add_gap;

	return $self;
}

sub _coderef_end {
	my ( $self, $coderef ) = ( shift, @_ );
	
	$coderef->add_line( sprintf(
		'%s unless $return;',
		$self->_make_general_fail( message => B::perlstring( $self->{message} ) ),
	) );
	$coderef->add_gap;
	
	$coderef->add_line( $self->_make_return_expression( is_early => 0 ) );
	
	$coderef->{indent} =~ s/\t$//;
	$coderef->add_line( '}' );
	return $self;
}

sub _coderef_check_count {
	shift;
}

sub _make_return_list {
	'@$return';
}

sub make_class_pp_code {
	my $self = shift;
	
	return join(
		qq{\n},
		grep { length $_ }
		map  { $_->{class_definition} || '' }
		@{ $self->meta_alternatives }
	);
}

1;
