package WWW::Mechanize::TWiki;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter WWW::Mechanize);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION = '0.12';

use WWW::Mechanize;
use HTML::TableExtract;

################################################################################

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new( stack_depth => 1, cookie_jar => {}, %args );
    return $self;
}

################################################################################

sub credentials {
    require MIME::Base64;
    my $self = shift;
    my @credentials = @_;

    if ( @credentials == 4 ) {
	# http://rt.cpan.org/Public/Bug/Display.html?id=31688
	# 4 argument form no longer supprted by WWW::Mechanize
	shift @credentials, shift @credentials;
    }

    $self->SUPER::credentials( $self->{cgibin}, '', @credentials );
    $self->add_header( Authorization => 'Basic ' . MIME::Base64::encode( $credentials[0] . ':' . $credentials[1] ) );
}

################################################################################

sub cgibin {
    my $self = shift;
    my $cgibin = shift || $self->{cgibin};
    die "no cgibin?" unless $cgibin;
    my $opts = shift;

    $self->{cgibin} = $cgibin;
    $self->{scriptSuffix} = $opts->{scriptSuffix} || '';

    return $self->{cgibin};
}

################################################################################

sub pub
{
    my $self = shift;
    my $pub = shift || $self->{pub};
    die "no pub?" unless $pub;

    return $self->{pub} = $pub;
}

################################################################################

sub getPageList
{
    my $self = shift;
    my $iWeb = shift;
    my $overrides = shift || {};

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
	%{$overrides},			# overrides these defaults
    } );

    warn "search: [", Dumper($xxx), "]\n";
    my $topic = $xxx->content();
    $topic =~ s|^.+?$tagStartTopics||s;		# strip up to start tag
    $topic =~ s|<p />.+?$||s;				# strip after formatted output

    my @topics = ();
    while ( $topic =~ /<topic>([^<]+?)<\/topic>/gi )
    {
    	push @topics, "$iWeb.$1";
#    	push @topics, $1;
    }

    return @topics;
}

################################################################################

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
	$args->{skin} = 'plain';
	(my $url = URI->new( "$self->{cgibin}/$action$self->{scriptSuffix}/$topic" ))->query_form( $args );
        my $response = $self->get( $url );

	my $u = URI->new( $url );
	my $error = {};
	if ( grep { /^oops\b/ } $u->path_segments() )
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

################################################################################

sub DESTROY
{
}

1;
__END__
=head1 NAME

WWW::Mechanize::TWiki - WWW::Mechanize subclass to navigate TWiki wikis

=head1 SYNOPSIS

This document describes a subclass of WWW::Mechanize.  Knowledge of WWW::Mechanize usage is assumed.

  use File::Basename;
  use WWW::Mechanize::TWiki;

  my $mech = WWW::Mechanize::TWiki->new( agent => File::Basename::basename( $0 ), autocheck => 1 ) or die $!;
  $mech->cgibin( 'http://ntwiki.ethermage.net/~develop/cgi-bin', { scriptSuffix => '' } );

  # (optional) establish credentials --- do this *after* setting cgibin
# $mech->credentials( undef, undef, USERNAME => PASSWORD );

  # get a list of topics in the _default web (typically somewhere around 11 topics)
  my @topics = $mech->getPageList( '_default' );

  # create a new page (no modifications, just use the template)
  my $topic = 'Tinderbox.TestsReportSvn' .$svnRev;
  $mech->edit( $topic, { 
      topicparent => 'WebHome', 
      templatetopic => 'TestReportTemplate',
      formtemplate => 'TestReportForm',
  } );
  $mech->click_button( value => 'Save' );

  # attach a file to the newly-created topic
  $mech->follow_link( text => 'Attach' );
  $mech->submit_form( fields => {
      filepath => 'report.txt',
      filecomment => `date`,
      hidefile => undef,
  } );

  # change a topic
  $mech->edit( $topic );
  $mech->field( text => 'New topic text' );
  $mech->click_button( value => 'Save' );

  # append to a topic
  $mech->edit( $topic );
  my $text = $mech->field( 'text' );
  $text .= "   * Adding to the text! `date`";
  $mech->field( text => $text );
  $mech->click_button( value => 'Save' );


=head1 DESCRIPTION

WWW::Mechanize::TWiki provides a programatic interface to TWiki's REST interface.  It does this by
mapping perl functions and data structures onto a TWiki URI.  

For example, WWW::Mechanize::TWiki will turn this method call 

  $mech->edit( 'Tinderbox.TestsReportSvn', { 
      topicparent => 'WebHome', 
      templatetopic => 'TestReportTemplate',
      formtemplate => 'TestReportForm',
  } );

into the following URI: (encoding as needed)

  http://twiki.org/cgi-bin/twiki/edit/Tinderbox.TestReport?topicparent=WebHome;templatetopic=TestReportTemplate;formtemplate=TestReportForm

(or http://twiki.org/cgi-bin/twiki/edit.cgi/Tinderbox.TestReport..., or 
http://twiki.org/cgi-bin/twiki/edit.pl/Tinderbox.TestReport..., etc. depending
on the scriptSuffix option passed to cgibin())

This is the added functionality on top of CPAN:WWW::Mechanize.  
CPAN:WWW::Mechanize functions can still be called, naturally.


=head2 Setup / Configuration

=head3 cgibin( cgi-uri, { scriptSuffix } );

Gets or sets the URI cgi-bin directory of the TWiki scripts

	$mech->cgibin( 'http://twiki.org/cgi-bin/twiki/' );
	print $mech->cgibin();
>http://twiki.org/cgi-bin/twiki/

	$mech->cgibin( 'http://tinderbox.wbniv.wikihosting.com/cgi-bin/twiki/', { scriptSuffix => '.cgi' } );
	print $mech->cgibin();
>http://tinderbox.wbniv.wikihosting.com/cgi-bin/twiki/		       


=head3 pub( pub-uri );

Gets or sets the URI of the TWiki pub directory

	setting pub is optional, although generally recommended.  it is required for downloading or managing 
	attachments.  


=head2 Web Methods

=head3 getPageList( webName );

Returns an array of (fully-qualified) topic names for the specified webName

	my @topics = $mech->getPageList( '_default' );
	print "@topics\n";
>WebChanges WebHome WebIndex WebLeftBar WebNotify WebPreferences WebRss WebSearch WebSearchAdvanced WebStatistics WebTopicList

	my @topics = $mech->getPageList( '_empty' );
	print "@topics\n";
>

=head2 Topic Methods

=head3 getAttachmentsList( topicName );

Returns an array of attachments of a fully-qualified topicName (includes wiki web name).
Each array element is a hash reference which is keyed by the column names.

	my @attachments = getAttachmentsList( 'TWiki.WabiSabi' );
	print Data::Dumper::Dumper( \@attachments );
>$VAR1 = [
>	{ 'filename' => 'report.txt', comment => '', hidden => '' },
>	{ 'filename' => 'report2.txt', comment => '', hidden => 'h' },
>];


=head2 Automatic Methods and Parameters

Invoking method that isn't listed above will construct a URI based on
the method's name and its parameters (in a hash reference) and
forwards it using WWW::Mechanize::get().  


=head2 EXPORT

None by default.


=head1 Examples

=head2 upgrade_topics.pl

This script 

use WWW::Mechanize::TWiki;
use Getopt::Long;

my $Config;

my $result = GetOptions( $Config,
#
                         'cgibin=s', 'scriptsuffix=s', 'web=s',
                         'user=s', 'password=s',
# miscellaneous/generic options
                        'verbose|v',
			 );

my $mech = WWW::Mechanize::TWiki->new() or die $!;
$mech->cgibin( $Config->{cgibin}, { scriptSuffix => $Config->{scriptsuffix} } );
$mech->credentials( undef, undef, $Config->{user} => $Config->{password} ) if $Config->{user};

my @topics = @ARGV
    ? map { "$Config->{web}/$_" } @ARGV
    : $mech->getPageList( $Config->{web} );

my @errors;
foreach my $topic ( @topics )
{
    print "Processing $topic\n" if $Config->{verbose};

    $mech->edit( $topic );
    $mech->field( forcenewrevision => 'on' );
    $mech->click_button( value => 'Save' );
    push @errors, $topic if ( $mech->status() != 200 );
}
print scalar @topics, " topics\n" if $Config->{verbose};
if ( @errors )
{
    print STDERR "Errors processing the following topics:\n";
    foreach my $topic ( @errors )
    {
        print STDERR "\t$topic\n";
    }
}

=head2 bugbase_create_plugins_gateways.pl

This script snippet is used to create a gateway topic for bugs for each TWikiExtension on twiki.org:
_Note_ that develop.twiki.org uses TemplateLogin, and how it has to login differently than a site using credentials.

use WWW::Mechanize::TWiki 0.11;

my $plugin_topics = qr/.+(Plugin|Contrib|AddOn)$/;

################################################################################

my $mechBugsBase = WWW::Mechanize::TWiki->new( autocheck => 1 ) or die $!;
$mechBugsBase->cgibin( 'http://develop.twiki.org/~develop/cgi-bin' );

my $mechTWikiDotOrg = WWW::Mechanize::TWiki->new() or die $!;
$mechTWikiDotOrg->cgibin( 'http://twiki.org/cgi-bin' );

# login to develop.twiki.org
$mechBugsBase->login( 'Bugs.WebHome' );
$mechBugsBase->field( username => USERNAME );
$mechBugsBase->field( password => PASSWORD );
$mechBugsBase->submit();
# get list of extension gateway pages
my @bugsTopics = $mechBugsBase->getPageList( 'Bugs', { search => $plugin_topics } );

# create new gateway page for each twiki.org extension
foreach my $topic ( $mechTWikiDotOrg->getPageList( 'Plugins', { search => $plugin_topics } ) )
{
    my ( $extension ) = $topic =~ /^Plugins\.(.+)$/;            # get base topic name
    next if grep { /^Bugs\.${extension}$/ } @bugsTopics;        # don't change any already there

print "Creating $extension\n";
$mechBugsBase->edit( "Bugs.$extension", {
        templatetopic => 'ExtensionTemplate',
        topicparent => 'Extension',
    } );
$mechBugsBase->click_button( value => 'Save' );
sleep rand 3;                                               # be nice to the poor server
}


=head1 DEPENDENCIES

  CPAN:WWW::Mechanize
  CPAN:HTML::TableExtract
  CPAN:MIME::Base64 (for authentication)


=head1 SEE ALSO

WWW::Mechanize, http://twiki.org


=head1 TODO

  cgibin and pub parameters should be able to be specified in the constructor

  document use with CPAN:LWP::UserAgent::TWiki::TWikiGuest
    (and understand how to make other agents for use with LDAP, etc.)

  getAttachmentList is very specific, but it is built upon a general algorithm
    to convert a table into a perl array of hash references; make a method
    publically available

  look into ways for a TWiki installation to "publish" its interface

  TemplateLogin domains require different client code to login; look into making this happen transparently

=head1 AUTHOR

Will Norris, E<lt>wbniv@cpan.orgE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004,2006 by Will Norris

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
