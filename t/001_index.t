use strict;
use warnings;

use Test::More;
use Test::Mojo;
use FindBin;

$ENV{MOJO_HOME} = "$FindBin::Bin/..";
require "$ENV{MOJO_HOME}/duolicious.pl";


my $t = Test::Mojo->new;
$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr/Duolicious/);


done_testing;
