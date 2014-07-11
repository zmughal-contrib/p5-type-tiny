=pod

=encoding utf-8

=head1 PURPOSE

Print some standard diagnostics before beginning testing.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013-2014 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.


=cut

use strict;
use warnings;
use Test::More;

sub diag_version
{
	my ($module, $version) = @_;
	$version = eval "require $module; $module->VERSION" unless defined $version;
	
	return diag sprintf('  %-30s    undef', $module) unless defined $version;
	
	my ($major, $rest) = split /\./, $version;
	return diag sprintf('  %-30s % 4d.%s', $module, $major, $rest);
}

sub diag_env
{
	require B;
	require Devel::TypeTiny::Perl56Compat;
	my $var = shift;
	return diag sprintf('  $%-30s   %s', $var, exists $ENV{$var} ? B::perlstring($ENV{$var}) : "undef");
}

while (<DATA>)
{
	chomp;
	
	if (/^#\s*(.*)$/ or /^$/)
	{
		diag($1 || "");
		next;
	}

	if (/^\$(.+)$/)
	{
		diag_env($1);
		next;
	}

	if (/^perl$/)
	{
		diag_version("Perl", $]);
		next;
	}
	
	diag_version($_) if /\S/;
}

ok 1;
done_testing;

__END__
# Required:

perl
Exporter::Tiny
Scalar::Util
Test::More
Text::Balanced

# Optional:

Class::ISA
Devel::LexAlias
Devel::StackTrace
Function::Parameters
Moo
Moose
MooseX::Types
Mouse
MouseX::Types
Role::Tiny

# Environment:

$AUTOMATED_TESTING
$NONINTERACTIVE_TESTING
$EXTENDED_TESTING
$AUTHOR_TESTING
$RELEASE_TESTING

$PERL_TYPE_TINY_XS
$PERL_TYPES_STANDARD_STRICTNUM
$MOO_XS_DISABLE
$MOOSE_ERROR_STYLE
$MOUSE_XS
$MOUSE_PUREPERL
$PERL_ONLY

