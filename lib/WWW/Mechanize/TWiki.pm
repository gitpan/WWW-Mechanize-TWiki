package WWW::Mechanize::TWiki;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter WWW::Mechanize);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION = '0.01';

use WWW::Mechanize;

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new( %args );
    return $self;
}

sub cgibin {
    my $self = shift;
    my $cgibin = shift;
    my $args = @_;

    $self->{cgibin} = $cgibin;

    return $self;
}

# pub (that's all the directories, right?)
# config (query on page text or bin script for cgibin and pub (and anything else))

sub getPageList
{
    my $self = shift;
    my $iWeb = shift;

    my $xxx = $self->search( $iWeb, {
	skin => 'text',# has no effect during a search :-(
	    nosearch => 'on',
	    nototal => 'on',
	    scope => 'topic',
	    search => '.+',
	    regex => 'on',
	    format => '!$topic',
            separator => '$n',
            header => '!__START__',
} );

    my $topic = $xxx->content();

    $topic =~ s|^.+?__START__||s;
    $topic =~ s|<p />.+?$||s;
    return split( /\n/, $topic );
}

# maps function calls into twiki urls
sub AUTOLOAD {
    our ($AUTOLOAD);
    no strict 'refs';
    (my $action = $AUTOLOAD) =~ s/.*:://;
    *$AUTOLOAD = sub {
	my ($self, $topic, $args) = @_;
	die "no cgibin" unless $self->{cgibin};
	die "no topic on action=[$action]" unless $topic;
	(my $url = URI->new( "$self->{cgibin}/$action/$topic" ))->query_form( $args );
	return $self->get( $url );
    };
    goto &$AUTOLOAD;
}

sub DESTROY
{
}

1;
__END__
=head1 NAME

WWW::Mechanize::TWiki - Perl extension for blah blah blah

=head1 SYNOPSIS

  use WWW::Mechanize::TWiki;
  blah blah blah

=head1 DESCRIPTION

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

WWW::Mechanize, http://twiki.org


=head1 AUTHOR

Will Norris, E<lt>wbniv@saneasylumstudios.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Will Norris

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
