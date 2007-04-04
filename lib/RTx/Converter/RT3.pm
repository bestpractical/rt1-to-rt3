package RTx::Converter::RT3;

use warnings;
use strict;
use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(config));

use RTx::Converter::RT3::Config;
use RT::User;

=head1 NAME

RTx::Converter::RT3 - Handle the RT3 side of a conversion


=head1 SYNOPSIS

    use RTx::Converter::RT3;
    my $converter = RTx::Converter::RT3->new;

=head1 DESCRIPTION

Object that should be used by converter scripts to 

=head1 METHODS

=head2 new

Returns a converter object after setting up things such as the config

=cut

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    $self->config(RTx::Converter::RT3::Config->new);
    return $self;
}

=head2 config 

Returns a config object

=head2 create_user

Creates a new user, expects a hash of valid values for RT3's
User::Create method plus one special SuperUser argument
that will cause SuperUser rights to be granted after creation

returns an RT::User object, or undef on failure

=cut

sub create_user {
    my $self = shift;
    my %args = ( Privileged => 1, @_ );

    # this is very RT1'y, because we kept super user rights
    # in the users table
    my $is_superuser = delete $args{SuperUser};

	my $user = RT::User->new($RT::SystemUser);

    $user->Load( $args{Name} );

    if ($user->Id) {
        print "\nLoaded ".$user->Name." from the database" if $self->config->debug;
        return $user;
    }
    
    local $RT::MinimumPasswordLength = 1; # some people from RT1 have short passwords
	my ($val, $msg) =  $user->Create( %args );

    if ($val) {
        print "\nAdded queue ".$user->Name if $self->config->debug;
        if ($is_superuser) {
            $user->PrincipalObj->GrantRight( Right => 'SuperUser', Object => $RT::System );
            print " as superuser" if $self->config->debug;
        }
        return $user;
    } else {
        print "\nfailed to create user $args{Name}: $msg";
        return;
    }

}

=head2 create_queue

Creates a new queue, expects a hash of valid values for RT3's
Queue::Create method

returns an RT::Queue object, or undef on failure

=cut

sub create_queue {
    my $self = shift;
    my %args = @_;

    # RT3 really doesn't like undef arguments
    %args = map { $_ => $args{$_} } grep { defined $args{$_} } keys %args;

	my $queue = RT::Queue->new($RT::SystemUser);

	# Try to load up the current queue by name. avoids duplication.
	$queue->Load($args{Name});
	
	#if the queue isn't there, create one.
	if ($queue->id) {
        print "\nLoaded queue ".$queue->Name." from the database" if $self->config->debug;
        return $queue;
    }

    my ($val, $msg) = $queue->Create(%args);

    if ($val) {
        print "\nAdded queue ".$queue->Name if $self->config->debug;
        return $queue;
    } else {
        print "\nfailed to create queue [$args{Name}]: $msg";
        return;
    }

}

=head1 AUTHOR

Kevin Falcone  C<< <falcone@bestpractical.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Best Practical Solutions, LLC.  All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;
