package t::Util;
use strict;
use warnings;
use Encode;
use Test::mysqld;
use Test::Fixture::DBI;
use Test::Mojo;
use Test::More;

use base 'Exporter';
our @EXPORT = qw/U u E e eU qrU/;

use File::Basename;
use lib dirname(__FILE__) . '/lib';
use Test::MyApp::mysqld;

{
    package Test::Mojo;

    sub link_ok {
        my ($t, $url) = @_;

        local $Test::Builder::Level = $Test::Builder::Level + 1;

        my @links;
        $t->ua->get($url)->res->dom->find('a[href]')->each(sub {
                                                               my $self = shift;
                                                               push @links, $self->attrs->{href};
                                                           });
        foreach my $link (@links) {
            $t->get_ok($link)->status_is(200) unless $link =~ /logout/;
        }
    }
}

sub test_dbname {
    return 'test_duolicious';
}

sub dbh_mysqld {
    my $mysqld = shift;
    my $dbh = DBI->connect(
        $mysqld->dsn,
        'root',
        '',
        +{
            AutoCommit => 0,
            RaiseError => 1,
            mysql_enable_utf8 => 1
        }
    );
    $dbh->do("CREATE DATABASE IF NOT EXISTS test_duolicious");
    $dbh->do("use " . t::Util::test_dbname());
    $dbh;
}


sub setup_mysqld {
    my ($schema, $fixture) = @_;

    my $mysqld = Test::MyApp::mysqld->setup;
    Test::MyApp::mysqld->cleanup($mysqld);

    my $dbh = dbh_mysqld($mysqld);


    # テーブル作成
    construct_database(
        dbh      => $dbh,
        database => $schema,
    );

    # 初期データ
    for my $f (@$fixture) {
        construct_fixture(
            dbh => $dbh,
            fixture => $f,
        );
    }

    $dbh->commit();

    return $mysqld;
}


sub setup_for_duo {
    my ($t, $schema, $fixture) = @_;

    $schema  ||= dirname(__FILE__) . '/mysqld/schema.yaml';
    $fixture ||= [];

    my $mysqld = t::Util::setup_mysqld($schema, $fixture);

    my %args = (
        'dbname' => t::Util::test_dbname()
    );
    $ENV{'CONFIG_DBI'} = [
        $mysqld->dsn(%args), 'root', '',
        {
            mysql_enable_utf8 => 1,
            RaiseError => 0,
        }
    ];

    return $mysqld;
}

sub U($) { decode_utf8($_[0]) }
sub u($) { encode_utf8($_[0]) }
sub E($) { decode('euc-jp', $_[0]) }
sub e($) { encode('euc-jp', $_[0]) }
sub eU($) { e(U($_[0])) }
sub qrU($) {
    my $str = decode_utf8($_[0]);
    return qr/$str/;
}

1;
