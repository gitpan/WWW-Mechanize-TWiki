package WWW::Mechanize::TWiki;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter WWW::Mechanize);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION = '0.06';

use WWW::Mechanize;
use HTML::TableExtract;

################################################################################

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new( %args );
    return $self;
}

sub cgibin {
    my $self = shift;
    my $cgibin = shift or die "no cgibin?";

    $self->{cgibin} = $cgibin;

    return $self;
}

sub pub
{
    my $self = shift;
    my $pub = shift or die "no pub?";

    return $self->{pub} = $pub;
}

# config (query on page text or bin script for cgibin and pub (and anything else))

sub getPageList
{
    my $self = shift;
    my $iWeb = shift;

    my $tagStartTopics = '__TOPICS__';
    my $xxx = $self->search( $iWeb, {
	skin => '',			# has no (real/positive) effect during a search :-(
	nosearch => 'on',
	nototal => 'on',
	scope => 'topic',
	search => '.+',
	regex => 'on',
	format => '<topic>$topic</topic>',
        separator => '$n',
        header => "!$tagStartTopics",
    } );

    my $topic = $xxx->content();		
    $topic =~ s|^.+?$tagStartTopics||s;		# strip up to start tag
    $topic =~ s|<p />.+?$||s;				# strip after formatted output

    my @topics = ();
    while ( $topic =~ /<topic>([^<]+?)<\/topic>/gi )
    {
    	push @topics, $1;
    }

    return @topics;
}


sub getAttachmentsList
{
    my $self = shift;
    my $topic = shift;
    my $parms = shift;

    my @attachments = ();

    my $attachments = $self->attach( $topic )->content();

    my @cols = qw( Attachment Comment Attribute );
    # qw(I Attachment Action Size Date Who Comment Attribute)
    my $te = HTML::TableExtract->new( headers => [ @cols ] ) or die $!;
    $te->parse( $attachments );

    foreach my $row ($te->rows) 
    {
	my %attach = ();
	my $idxCol = 0;
	foreach my $col ( @cols )
	{
	    my $data = $row->[ $idxCol++ ];
	    $data =~ s/^\s+//;
	    $data =~ s/\s+$//;
	    $attach{$col} = $data;
	}
	( my $attachTopic = $topic ) =~ s|\.|\/|;
	$attach{_filename} = $attach{Attachment};
	$attach{Attachment} = "$self->{pub}/$attachTopic/" . $attach{_filename};
	push @attachments, {
	        %attach,
	    };
    }

    return @attachments;
}

################################################################################

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
        my $response = $self->get( $url );

	my $u = URI->new( $url );
	my $error = {};
	if ( grep { /^oops\.?/ } $u->path_segments() )
	{
	    my %form = $u->query_form();
	    ( $error->{error} = $form{template} ) =~ s/^oops(.+?)/$1/;
#	    ( $error->{error} = $form{template} ) =~ s/^oops(.+?)err/$1/;
#	    delete $form{template};

	    # convert all the named (semi-) generic param# parameters into a perl array
	    map {
		push @{ $error->{message} }, $form{ $_ }
	    } sort grep { /^param\d+$/ } keys %form;
	}

#        print STDERR Data::Dumper::Dumper( $response );
#      http://localhost/~twiki/cgi-bin/twiki/oops/TWikitestcases/ATasteOfTWiki?template=oopssaveerr&param1=Save%20attachment%20error%20/Users/twiki/Sites/htdocs/twiki/TWikitestcases/ATasteOfTWiki/TWikiInstaller.smlp%20is%20not%20writable

#	print STDERR Data::Dumper::Dumper( $response->request );
        $response;
    };
    goto &$AUTOLOAD;
}


#my $url = q{http://localhost/~twiki/cgi-bin/twiki/oops/TWikitestcases/ATasteOfTWiki?template=oopssaveerr&param1=Save%20attachment%20error%20/Users/twiki/Sites/htdocs/twiki/TWikitestcases/ATasteOfTWiki/TWikiInstaller.smlp%20is%20not%20writable&param3=3&param2=2};
#my $u = URI->new( $url );
#print Dumper( $u ), "\n\n\n";
#print Dumper( $u->path_segments() );
#if ( grep { /^oops\.?/ } $u->path_segments() )
#{
##    print Dumper( $u->query_form() );
#    my %h = $u->query_form();
#    my $error = { error => $h{template} };
##    $error->{error} =~ s/oops(.+?)err$/$1/;
#    delete $h{template};
#    # convert all the param# generic parameters into an array of messages
#    my @parms = sort grep { /^param\d+$/ } keys %h;
#    map { push @{ $error->{message} }, $h{ $_ } } @parms;
#        
#    print Dumper( $error );
#}


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
