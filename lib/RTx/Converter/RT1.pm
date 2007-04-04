package RTx::Converter::RT1;

use warnings;
use strict;
use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(config _handle ));

use RTx::Converter::RT1::Config;
use DBI;

=head1 NAME

RTx::Converter::RT1 - Handle the RT1 side of a conversion


=head1 SYNOPSIS

    use RTx::Converter::RT1;
    my $converter = RTx::Converter::RT1->new;

=head1 DESCRIPTION

Object that should be used by converter scripts to 

=head1 METHODS

=head2 new

Returns a converter object after setting up things such as the config

=cut

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    $self->config(RTx::Converter::RT1::Config->new);
    return $self;
}

=head2 config 

Returns a config object

=head2 _handle

private method for the db handle of the RT1 database

=head2 _connect

conect to the RT1 database

=cut

# this probably really wants to be using DBIx::SearchBuilder or
# some other ORM, but we're really just doing a few simple SQL calls
# so we'll avoid having to map the old tables for now

sub _connect {
    my $self = shift;
    my $config = $self->config;
    
    my $dsn = sprintf("DBI:mysql:database=%s;host=%s;",
                      $config->database, $config->dbhost,
                      { RaiseError => 1 });
    print "connecting to $dsn" if $config->debug;
    my $dbh = DBI->connect($dsn, $config->dbuser, $config->dbpassword) 
        or die "Can't connect to RT1 database: ".$DBI::errstr;

    return $self->_handle($dbh);
}

=head2 _run_query

Takes a sql string and a list of placeholder values

 _run_query( sql => $sql, placeholders => \@placeholders )

Returns a statement handle

=cut

sub _run_query {
    my $self = shift;
    my %args = @_;

    my $handle= $self->_handle|| $self->_connect;

    my @placeholders = @{$args{placeholders}||[]};
    
    my $sth = $handle->prepare($args{sql});
    $sth->execute(@placeholders) or 
      die("Can't run query: $args{sql} - " . 
          join(" ",@placeholders) . 
          "\nReason:" . $DBI::errstr . "\n");
    
    return $sth;
}

=head2 _sth

Stores several named sth's for this object (since multiple queries
can be happening simultaneously).

Takes 
 Name => sth for set
 Name for get

=cut

sub _sth {
    my $self = shift;

    if (@_ > 1) {
        my ($name,$sth) = @_;
        $self->{sths}{$name} = $sth;
    } elsif (@_) {
        my $name = shift;
        $self->{sths}{$name};
    } else {
        die "You must pass at least a name to _sth";
    }
}

=head3 _clean_sth

finishes the sth and gets rid of it
takes the name of the sth

=cut

sub _clean_sth {
    my $self = shift;
    my $name = shift;

    $self->_sth($name)->finish;
    $self->_sth($name,undef);
    return;
}

=head2 get_user

Intended to be called in a loop.
Wraps over the DBH iterator.  When called for the first time, 
will fetch the users and returns one as a hashref.  
Will keep returning one until we run out.

=cut

sub get_user {
    my $self = shift;

    my $sth = $self->_sth('User');

    unless ($sth) {
        my $sql = <<ESQL;
select user_id as Name, 
       real_name as RealName, 
       password as Password, 
       email as EmailAddress, 
       phone as WorkPhone, 
       comments as Comments, 
       admin_rt as SuperUser
from users
ESQL
        $sth = $self->_run_query( sql => $sql );
        $self->_sth(User => $sth);
    }

    my $user_data = $sth->fetchrow_hashref;

    if ($user_data && !$user_data->{EmailAddress}) {
        $user_data->{EmailAddress} = $user_data->{Name}.'@'.$self->config->email_domain;
    }

    $self->_clean_sth('User') unless $user_data;

    return $user_data;
}

=head3 get_queue

Intended to be called in a loop.
Wraps over the DBH iterator.  When called for the first time, 
will fetch the queues and returns one as a hashref.  
Will keep returning one until we run out.

=cut

sub get_queue {
    my $self = shift;

    my $sth = $self->_sth('Queue');

    unless ($sth) {
        my $sql = <<ESQL;
select queue_id as Name, 
       mail_alias as CorrespondAddress, 
       comment_alias as CommentAddress, 
       default_prio as InitialPriority, 
       default_final_prio as FinalPriority, 
       default_due_in as DefaultDueIn
from queues
ESQL
        $sth = $self->_run_query( sql => $sql );
        $self->_sth(Queue => $sth);
    }

    my $queue_data = $sth->fetchrow_hashref;

    if ($queue_data) {
        $queue_data->{Description} = "Imported from RT 1.0";
    }

    $self->_clean_sth('Queue') unless $queue_data;

    return $queue_data;

}

=head3 get_area

Intended to be called in a loop.
Wraps over the DBH iterator.  When called for the first time, 
will fetch the areas for the queue and returns one as a hashref.  
Will keep returning one until we run out.

Takes one argument, Name => Queue's Name

=cut

sub get_area {
    my $self = shift;
    my %args = @_;

    my $sth = $self->_sth('Area');

    unless ($sth) {
        my $sql = 'select area from queue_areas where queue_id = ?';
        $sth = $self->_run_query( sql => $sql, placeholders => [$args{Name}] );
        $self->_sth(Area => $sth);
    }

    my $area_data = $sth->fetchrow_hashref;

    $self->_clean_sth('Area') unless $area_data;

    return $area_data;
}

=head3 get_queue_acl

Intended to be called in a loop.
Wraps over the DBH iterator.  When called for the first time, 
will fetch the acls for the queue and returns one as a hashref.  
Will keep returning one until we run out.

Takes one argument, Name => Queue's Name

=cut

sub get_queue_acl {
    my $self = shift;
    my %args = @_;

    my $sth = $self->_sth('ACL');

    unless ($sth) {
        my $sql = 'select user_id, display, manipulate, admin from queue_acl where queue_id = ?';
        $sth = $self->_run_query( sql => $sql, placeholders => [$args{Name}] );
        $self->_sth(ACL=> $sth);
    }

    my $acl_data = $sth->fetchrow_hashref;

    $self->_clean_sth('ACL') unless $acl_data;

    return $acl_data;
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
