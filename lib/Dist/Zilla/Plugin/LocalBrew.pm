package Dist::Zilla::Plugin::LocalBrew;
BEGIN {
  $Dist::Zilla::Plugin::LocalBrew::VERSION = '0.02';
}

use File::Spec;
use File::Temp qw(tempdir);

use namespace::clean;

use Moose;
with 'Dist::Zilla::Role::BeforeRelease';

use autodie qw(fork);

has brews => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);

sub mvp_multivalue_args {
    qw/brews/
}

sub with_perlbrew {
    my ( $self, $brew, $fn ) = @_;

    my $path         = $ENV{'PATH'};
    my $perlbrew_bin = File::Spec->catdir($ENV{'PERLBREW_ROOT'}, 'perls',
        $brew, 'bin');

    unless(-x File::Spec->catfile($perlbrew_bin, 'perl')) {
        $self->log_fatal("No such perlbrew environment '$brew'");
        return;
    }

    local $ENV{'PATH'} = $perlbrew_bin . ':' . $path;
    $fn->();
}

sub before_release {
    my ( $self, $tgz ) = @_;

    $tgz = $tgz->absolute;

    unless($ENV{'PERLBREW_ROOT'}) {
        $self->log_fatal("Environment variable 'PERLBREW_ROOT' not found");
        return;
    }

    my $cpanm_location = qx(which cpanm 2>/dev/null);
    unless($cpanm_location) {
        $self->log_fatal("The 'cpanm' program is required to use this plugin");
        return;
    }
    chomp $cpanm_location;

    my $brews = $self->brews;

    unless(@$brews) {
        $self->log_fatal('No perlbrew environments specified in your dist.ini');
    }

    foreach my $brew (@$brews) {
        $self->with_perlbrew($brew, sub {
            my $local_lib = tempdir(CLEANUP => 1);
            $self->log("Running cpanm in perlbrew environment '$brew'");

            my $pid = fork;

            if($pid) {
                waitpid $pid, 0;
                if($?) {
                    $self->log_fatal("cpanm $tgz failed in perlbrew environment '$brew'.  Check ~/.cpanm/build.log for details");
                } else {
                    $self->log("cpanm $tgz succeeded in perlbrew environment '$brew'");
                }
            } else {
                close STDOUT;
                close STDERR;
                exec 'perl', $cpanm_location, '-l', $local_lib, $tgz;
                ## handle failure?
            }
        });
    }
}

no Moose;
1;



=pod

=head1 NAME

Dist::Zilla::Plugin::LocalBrew - Verify that your distribution tests well in a fresh perlbrew

=head1 VERSION

version 0.02

=head1 SYNOPSIS

  # in your dist.ini
  [LocalBrew]
  brews = first-perlbrew
  brews = second-perlbrew

=head1 DESCRIPTION

This plugin builds and tests your module with a set of given perlbrew
environments before a release and aborts the release if testing in any
of them fails.  Any dependencies are installed via cpanminus into
a temporary local lib, so your perlbrew environments aren't altered.
This comes in handy when you want to build against a set of "fresh" Perl
installations (ie. those with only core modules) to make sure all of your
prerequisites are included correctly.

=head1 ATTRIBUTES

=head2 brews

A list of perlbrew environments to build and test in.

=head1 ISSUES

=over

=item Relies on the 'which' program to detect cpanm.

=back

=head1 SEE ALSO

L<Dist::Zilla>, L<App::perlbrew>, L<App::cpanminus>, L<local::lib>

=head1 AUTHOR

Rob Hoelz <rob@hoelz.ro>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Rob Hoelz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dist-Zilla-Plugin-LocalBrew

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut


__END__

# ABSTRACT: Verify that your distribution tests well in a fresh perlbrew

