use strict;
use warnings;

use Test::More;
use Test::Mojo;
use FindBin;

use Mojo::JSON;

use Data::Dumper;

use t::Util;

$ENV{MOJO_HOME} = "$FindBin::Bin/..";
require "$ENV{MOJO_HOME}/duolicious.pl";


subtest 'セクション選択画面' => sub {
    my $t = Test::Mojo->new;
    my $mysqld = t::Util::setup_for_duo($t);

    $t->get_ok('/learn/section')
      ->status_is(200)
      ->content_like(qrU('セクション選択'));

    for my $section ( 1 .. 42 ) {
        $t->content_like(qrU('Section'.$section));
    }
};


done_testing();
