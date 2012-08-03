package Model;

use strict;
use warnings;
use utf8;
use Encode;
use Time::Piece;
use Time::Seconds;

use Mojo::JSON;

sub max_no {
    my %params = @_;

    my $max_no = 1;
    for my $name ( keys %params ) {
        if ( $name =~ /^japanese_(\d+)$/ ) {
            if ( $max_no < $1 ) {
                $max_no = $1;
            }
        }
    }

    return $max_no;
}

sub question_submit {
    my $app = shift;

    my %params = %{ $app->req->params->to_hash };

    my $max_no = Model::max_no(%params);

    my $parser = Mojo::JSON->new;

    my @inserts;
    my @japanese_list;
    my @english_list;
    for my $no ( 1 .. $max_no ) {
        push @japanese_list, $app->param("japanese_" . $no);
        push @english_list, $app->param("english_" . $no);
    }
    my %values = (
        'number'   => $app->param('number'),
        'section'  => $app->param('section'),
        'japanese' => $parser->encode(\@japanese_list),
        'english'  => $parser->encode(\@english_list),
    );

    my $id = $app->param('id') || undef;
    if ( !$id ) {
        $app->db->insert('question', \%values);
    }
    else {
        $app->db->update('question', \%values, { id => $id });
    }

    return $app->redirect_to('question/list');
}

sub create_question_forms {
    my ($app, $section, $no) = @_;

    my $parser = Mojo::JSON->new;

    my @questions = $app->db->search('question', { section => $section }, { order_by => 'number' });
    my $question = $questions[$no-1];

    $app->stash->{japanese} = [];
    $app->stash->{english} = [];
    if ( $question ) {
        my @japanese = @{ $parser->decode( encode_utf8( $question->japanese ) ) };
        my @english  = @{ $parser->decode( encode_utf8( $question->english ) ) };

        my ($j_ref, $e_ref) = Model::_create_question_forms(\@japanese, \@english);
        $app->stash->{japanese} = $j_ref;
        $app->stash->{english} = $e_ref;
    }

    $app->stash->{no} = $no;

    $app->stash->{errors} = 0;
}

sub _create_question_forms {
    my ($japanese_ref, $english_ref) = @_;

    my $no;

    my @japanese;
    $no = 1;
    for my $j ( @{ $japanese_ref } ) {
        push @japanese, { no => $no, str => $j };
        $no++;
    }

    my @english;
    $no = 1;
    for my $e ( @{ $english_ref } ) {
        my @words = split(/\s+/, $e);

        my @forms;
        my $word_no = 1;
        for my $w ( @words ) {
            push @forms, {
                word_no => $word_no,
            };
            $word_no++;
        }
        push @english, {
            no => $no,
            forms => \@forms,
            str => $e
        };
        $no++;
    }

    return (\@japanese, \@english);
}

sub get_next_no {
    my ($app, $section, $no) = @_;
    my $num = $app->db->count('question', '*', { section => $section }, { order_by => 'number' });
    return Model::_get_next_no($no, $num);
}

sub _get_next_no {
    my ($cur, $max) = @_;
    return $cur % $max + 1;
}

sub check_ans {
    my ($app, $section, $no) = @_;

    my $parser = Mojo::JSON->new;

    my @questions = $app->db->search('question', { section => $section }, { order_by => 'number' });
    my $question = $questions[$no-1];

    my @sentence = @{ $parser->decode( encode_utf8( $question->english ) ) };
    my @english;
    for my $s ( @sentence ) {
        my @words = split(/\s+/, $s);
        push @english, \@words;
    }

    my $n = @english;
    $n -= 1;
    for my $i ( 0 .. $n ) {
        my $z = @{ $english[$i] };
        $z -= 1;
        for my $j ( 0 .. $z ) {
            my $word = $english[$i][$j];
            my $no = $i + 1;
            my $word_no = $j + 1;

            my $ans = $app->param("ans_${no}_${word_no}");
            if ( $word ne $ans ) {
                $app->stash->{error} = 1;
                return 0;
            }
        }
    }

    return 1;
}

sub log {
    my ($app, $section, $no, $ans_look_count, $miss_count) = @_;

    my $count = $app->db->count('anslog', '*', { section => $section, no => $no });

    if ( !$count ) {
        $app->db->insert('anslog', {
            section => $section,
            no => $no,
            ans_look_count => $ans_look_count,
            miss_count => $miss_count,
            ans_at => \'NOW()',
        });
    }
}

sub review {
    my ($app) = @_;

    my $now = Time::Piece::localtime;

    my $first_review  = $now - ONE_DAY * 1;
    my $second_review = $first_review - ONE_DAY * 7;
    my $third_review  = $second_review - ONE_DAY * 30;

    my $builder = $app->db->sql_builder;

    my $format = '%Y-%m-%d %H:%M:%S';
    my $cond;

    my $base = $builder->new_condition();
    $base = $base->add(ans_look_count => {'>' => 0});

    $cond = $builder->new_condition();
    $cond->add(miss_count => {'>' => 1});
    $base = $base->compose_or($cond);

    $cond = $builder->new_condition();
    $cond->add(review_count => 0);
    $cond->add(ans_at => {'<=' => $first_review->strftime($format)});
    $base = $base->compose_or($cond);

    $cond = $builder->new_condition();
    $cond->add(review_count => 1);
    $cond->add(ans_at => {'<=' => $second_review->strftime($format)});
    $base = $base->compose_or($cond);

    $cond = $builder->new_condition();
    $cond->add(review_count => 2);
    $cond->add(ans_at => {'<=' => $second_review->strftime($format)});
    $base = $base->compose_or($cond);

    my $maker_select = $builder->new_select();
    $maker_select->add_select('*');
    $maker_select->add_from('anslog');
    $maker_select->set_where($base);

    $maker_select->limit(1);

    my $sql = $maker_select->as_sql;
    my @binds = @{$maker_select->bind};
    warn $sql;
    my $dbh = $app->db->dbh;
    my $sth = $dbh->prepare($sql);
    $sth->execute(@binds);
    my $row = $sth->fetchrow_hashref;
    $sth->finish;

    return $row;
}

sub review_log {
    my ($app, $id, $section, $no, $ans_look_count, $miss_count) = @_;

    my $row = $app->db->single('anslog', {id => $id});

    # ミスや解答確認の復習だったら、削除し、新しいログを残す
    if ( $row->ans_look_count > 0 || $row->miss_count > 1 ) {
        $row->delete;
        Model::log($app, $section, $no, $ans_look_count, $miss_count);
    }
    # 忘却曲線の復習だったら、カウントアップ
    else {
        my $review_count = $row->review_count + 1;
        $row->update({review_count => $review_count});
    }
}

1;
