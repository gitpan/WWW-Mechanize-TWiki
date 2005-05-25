use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'WWW::Mechanize::TWiki',
    VERSION_FROM      => 'lib/WWW/Mechanize/TWiki.pm', # finds $VERSION
    PREREQ_PM         => {
	'WWW::Mechanize'        => '0',
	'HTML::TableExtract'	=> '0',
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/WWW/Mechanize/TWiki.pm', # retrieve abstract from module
       AUTHOR         => 'Will Norris <wbniv@local>') : ()),
);
