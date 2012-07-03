use strict;
use warnings;

use Test::More;
use Test::Mojo;
use FindBin;

use Mojo::JSON;

use Model;

use t::Util;

use Data::Dumper;

$ENV{MOJO_HOME} = "$FindBin::Bin/..";
require "$ENV{MOJO_HOME}/duolicious.pl";


subtest 'フォーム作成のために文章を分解' => sub {
    my $t = Test::Mojo->new;
    my $mysqld = t::Util::setup_for_duo($t);

    my @japanese;
    push @japanese, U('汗でびしょぬれだよ。');
    push @japanese, U('来ないで！臭いわ。シャワーを浴びて。');

    my @english;
    push @english, U('I\'m soaked with sweat.');
    push @english, U('Stand back! You stink. Take a shower.');

    my ($j_ref, $e_ref) = Model::_create_question_forms(\@japanese, \@english);

    is @$j_ref, 2;
    is @$e_ref, 2;

    is @{ $e_ref->[0]->{forms} }, 4;
    is @{ $e_ref->[1]->{forms} }, 7;
};

subtest '次の問題の番号を取得' => sub {
    my $t = Test::Mojo->new;

    my $max = 10;

    is Model::_get_next_no(1, $max), 2;
    is Model::_get_next_no(9, $max), 10;
    is Model::_get_next_no(10, $max), 1;
};

done_testing();
