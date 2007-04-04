package RTx::Converter::RT1;

use warnings;
use strict;
use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(config _handle _sth));

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
# so we'll avoid having to map records, or do something else "hard"

sub _connect {
    my $self = shift;
    my $config = $self->config;
    
    my $dsn = sprintf("DBI:mysql:database=%s;host=%s;",
                      $config->database, $config->dbhost );
    warn "connecting to $dsn" if $config->debug;
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

=head2 get_user

Intended to be called in a loop.
Wraps over the DBH iterator.  When called for the first time, 
will fetch the users and return one.  Will keep returning one
until we run out.

=cut

sub get_user {
    my $self = shift;

    my $sth = $self->_sth;

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
        $self->_sth($sth);
    }

    my $user_data = $sth->fetchrow_hashref;

    if ($user_data && !$user_data->{EmailAddress}) {
        $user_data->{EmailAddress} = $user_data->{Name}.'@'.$self->config->email_domain;
    }

    return $user_data;
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
