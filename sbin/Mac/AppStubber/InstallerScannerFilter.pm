use strict;
package Mac::AppStubber::InstallerScannerFilter;


=head1 NAME

Mac::AppStubber::InstallerScannerFilter - Ignores specific items

=head1 SYNOPSIS

$s=Mac::AppStubber::InstallerScannerFilter->new($I<inverse>, @I<path-rexps>)

$s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

=head1 DESCRIPTION

Ensures that certain paths are ignored during scanning and
consequently during installation.

=over 10

=item $s=Mac::AppStubber::InstallerScannerFilter->new($I<inverse>, @I<path-rexps>)

Create a new instance. Provide a list of regular expressions in
I<path-rexps>. When scanning a directory item, the class tries to
match the rexps. If I<inverse> is present, all paths not matching the
I<path-rexps> are matched.

=item $s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

Returns false (C<0>), should one the I<path-rexps> match, causing the
item to be ignored. Otherwise C<undef> is returned, allowing other
scanners to do their work.

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut

require Mac::AppStubber::InstallerScanner;
use vars qw(@ISA);
@ISA= ('Mac::AppStubber::InstallerScanner');


sub new
  {
    my $self=Mac::AppStubber::InstallerScanner::new($_[0]);
    shift;
    $self->{invert}=shift;
    $self->{admitted}=[@_];
    return $self;
  }


# Remark: inverted Run: the return values are inverted:
# --> A matching item will be ignored, a non-matching passed on.
sub create_installer
  {
    my( $this,$dirname,$path ) = @_;
    if( grep {  "$path" =~ m{$_} } @{$this->{admitted}} )
      {
	# The path matched --> We want to keep the path.
	# --> Fail the scanner, so the other scanners can do their work
	return "" if $this->{invert};
	return undef;
      }

    # The path was not in the wanted list --> Tell the scanner that 
    # no installer will be supplied for it. Thus, the item is skipped.
    return undef if $this->{invert};
    return "";
  }

1;
