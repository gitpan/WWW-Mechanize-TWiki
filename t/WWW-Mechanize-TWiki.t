# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl WWW-Mechanize-TWiki.t'

#########################

use Test::More tests => 2;
BEGIN { use_ok('WWW::Mechanize::TWiki') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
isa_ok( WWW::Mechanize::TWiki->new(), 'WWW::Mechanize::TWiki' );


