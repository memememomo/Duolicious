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


sub insert_test_params {
    my $t = shift;

    my $res = $t->tx->res;
    my $first = $res->dom->find('form')->first;

    my %values;
    $first->find('input')->each(
        sub {
            my ($e) = @_;
            if ( $e->attrs->{type} ne 'submit' ) {
                $values{$e->attrs->{name}} = $e->attrs->{value};
            }
        }
    );
    $first->find('textarea')->each(
        sub {
            my ($e) = @_;
            $values{$e->attrs->{name}} = $e->text;
        }
    );

    return %values;
}

subtest '問題一覧ページを表示する' => sub {
    my $t = Test::Mojo->new;
    my $mysqld = t::Util::setup_for_duo($t);

    my $parser = Mojo::JSON->new;

    my $section = 1;

    # 問題を登録しておく
    my @japanese;
    my @english;
    for my $no ( 1 .. 3 ) {
        push @japanese, U('テスト' . $no);
        push @english, U('test' . $no);
    }
    $t->app->db->insert('question', {
        section => $section,
        japanese => $parser->encode(\@japanese),
        english  => $parser->encode(\@english),
    });


    $t->get_ok('/question/list/' . $section)
      ->status_is(200)
      ->content_like(qrU("Section$section - 問題一覧"))
      ->content_like(qr/$japanese[0]/);
};

subtest '問題新規登録画面' => sub {
    my $t = Test::Mojo->new;
    my $mysqld = t::Util::setup_for_duo($t);

    my $section = 1;

    $t->get_ok('/question/create/' . $section)
      ->status_is(200)
      ->content_like(qrU("問題登録 - Section$section"))
      ->content_like(qrU("日本語$section"))
      ->content_like(qrU("英語$section"));

    # フォームを増やす
    my %values = insert_test_params($t);
    $t->post_form_ok('/question/create/' . $section, {
        %values,
        add => 1,
    })
    ->status_is(200)
    ->content_like(qrU("日本語2"))
    ->content_like(qrU("英語2"));

    %values = insert_test_params($t);
    $values{japanese_2} = U('テスト2');
    $values{english_2} = U('test2');
    $t->post_form_ok('/question/create/' . $section, {
        %values,
        add => 1,
    })
    ->status_is(200)
    ->content_like(qrU("日本語3"))
    ->content_like(qrU("英語3"))
    ->content_like(qrU('テスト2'))
    ->content_like(qrU('test2'));

    # 削除
    %values = insert_test_params($t);
    $t->post_form_ok('/question/create/' . $section, {
        %values,
        delete_2 => 1,
    })
    ->status_is(200)
    ->content_unlike(qrU("日本語3"))
    ->content_unlike(qrU("英語3"))
    ->content_unlike(qrU("テスト2"))
    ->content_unlike(qrU("test2"));
};

subtest '問題登録処理' => sub {
    my $t = Test::Mojo->new;
    my $mysqld = t::Util::setup_for_duo($t);

    my $section = 1;

    my %values;
    $values{number} = 1;
    for my $no ( 1 .. 3 ) {
        $values{"japanese_$no"} = "テスト$no";
        $values{"english_$no"} = "test$no";
    }

    $t->post_form_ok('/question/create/' . $section, {
        %values,
        create => 1,
    })
    ->status_is(302);

    my $parser = Mojo::JSON->new;

    is $t->app->db->count('question', '*', { section => $section }), 1;
    my $q = $t->app->db->single('question', { section => $section });
    is @{ $parser->decode($q->japanese) }, 3;
    is @{ $parser->decode($q->english) }, 3;
};

done_testing()

