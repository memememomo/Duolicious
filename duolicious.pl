use strict;
use warnings;
use utf8;
use Encode;
use File::Basename;
use lib dirname(__FILE__) . '/lib';
use Mojolicious::Lite;
use HTML::FillInForm::Lite;
use DBIx::Handler;
use Teng::Schema::Loader;
use DB;
use Model;

# config
my $config_file = app->home->rel_file('/conf/config.pl');
my $config = app->plugin(
    config => {
        file      => $config_file,
        stash_key => 'config',
    }
);

# DB
app->helper(
    db => sub {
        if ( !defined app->{db} ) {
            my $dbi_config = $ENV{'CONFIG_DBI'} || $config->{'DBI'};

            my $handler = DBIx::Handler->new(@{$dbi_config});
            my $db = Teng::Schema::Loader->load(
                namespace => 'DB',
                dbh       => $handler->dbh,
            );
            app->{db} = $db;
            app->{handler} = $handler;
        }

        app->{db}->{dbh} = app->{handler}->dbh;
        app->{db}->{schema}->{dbh} = app->{handler}->dbh;

        return app->{db};
    }
);

app->helper(
    render_filled_html => sub {
        my $self = shift;
        my $params = shift;
        my $html = $self->render_partial(@_)->to_string;

        my $fill = HTML::FillInForm::Lite->new( fill_password => 1 );
        $self->render_text(
            $fill->fill(\$html, $params),
            format => 'html'
        );
    }
);

get '/' => sub {
    my $self = shift;
    $self->render();
} => 'index';

get '/learn/section' => sub {
    my $self = shift;
    $self->render();
} => 'learn/section';

post '/learn/start/:section/:no' => sub {
    my $self = shift;

    my $section = $self->param('section');
    my $no = $self->param('no');

    if ( Model::check_ans($self, $section, $no) ) {
        my $ans_look_count = $self->param('ans_look_count') || 0;
        my $miss_count     = $self->param('miss_count') || 0;
        Model::log($self, $section, $no, $ans_look_count, $miss_count);
        my $next_no = Model::get_next_no($self, $section, $no);
        return $self->redirect_to('learn/start', no => $next_no );
    }

    my %filled = Model::create_question_forms($self, $section, $no);

    my $miss_count = $self->param('miss_count');
    $miss_count++;
    $filled{miss_count} = $miss_count;

    $self->render_filled_html(\%filled);
} => 'learn/start';

get '/learn/start/:section/:no' => { no => 1 } => sub {
    my $self = shift;

    my $no = $self->param('no') || 1;
    my $section = $self->param('section');
    my %filled = Model::create_question_forms($self, $section, $no);

    $self->stash->{error} = 0;

    $self->render_filled_html(\%filled);
} => 'learn/start';

get '/section' => sub {
    my $self = shift;
    $self->render();
} => 'section/index';

get '/question/list/:section' => sub {
    my $self = shift;

    my $itr = $self->db->search('question', { section => $self->param('section') }, { order_by => 'number' });

    my $parser = Mojo::JSON->new;

    my @questions;
    while ( my $row = $itr->next ) {
        my @japanese = @{ $parser->decode( encode_utf8( $row->japanese ) ) };
        push @questions, { number => $row->number, japanese => $japanese[0], id => $row->id };
    }
    $self->stash->{questions} = \@questions;

    $self->render();
} => 'question/list';

any '/question/edit/:section/:id' => sub {
    my $self = shift;

    if ( $self->param('update') ) {
        return Model::question_submit($self);
    }

    my $parser = Mojo::JSON->new;

    my %params = %{ $self->req->params->to_hash };
    my %filled;

    my $question = $self->db->single('question', { id => $self->param('id') });
    my @japanese = @{ $parser->decode( encode_utf8( $question->japanese ) ) };
    my @english  = @{ $parser->decode( encode_utf8( $question->english ) ) };

    my $length = @japanese;
    for my $i ( 0 .. $length ) {
        my $no = $i + 1;
        $filled{"japanese_$no"} ||= $japanese[$i];
        $filled{"english_$no"}  ||= $english[$i];
    }
    $filled{"number"} ||= $question->number;

    my $max_no = $length;
    my $del_no = -1;
    for my $name ( keys %params ) {
        if ( $name =~ /^japanese_(\d+)$/ ) {
            if ( $max_no < $1 ) {
                $max_no = $1;
            }
        }

        if ( $name =~ /^delete_(\d+)$/ ) {
            $del_no = $1;
        }
    }

   my $offset = 0;
    for my $no ( 1 .. $max_no ) {
        if ( $no == $del_no ) {
            $offset += 1;
        }
        my $pos = $no + $offset;
        $filled{"japanese_$no"} = $filled{"japanese_$pos"};
        $filled{"english_$no"}  = $filled{"english_$pos"};
    }

    if ( $offset ) {
        delete $filled{"japanese_$max_no"};
        delete $filled{"english_$max_no"};
        $max_no -= 1;
    }

    if ( $self->param('add') ) {
        $max_no += 1;
    }

    my @questions;
    for my $no ( 1 .. $max_no ) {
        push @questions, { no => $no };
    }

    if ( !@questions ) {
        push @questions, { no => 1 };
    }

    $self->stash->{questions} = \@questions;


    return $self->render_filled_html(\%filled);
} => 'question/edit';

any '/question/create/:section' => sub {
    my $self = shift;

    if ( $self->param('create') ) {
        return Model::question_submit($self);
    }

    my %params = %{ $self->req->params->to_hash };
    my %filled = %params;

    my $max_no = 1;
    my $del_no = -1;
    for my $name ( keys %params ) {
        if ( $name =~ /^japanese_(\d+)$/ ) {
            if ( $max_no < $1 ) {
                $max_no = $1;
            }
        }

        if ( $name =~ /^delete_(\d+)$/ ) {
            $del_no = $1;
        }
    }

   my $offset = 0;
    for my $no ( 1 .. $max_no ) {
        if ( $no == $del_no ) {
            $offset += 1;
        }
        my $pos = $no + $offset;
        $filled{"japanese_$no"} = $filled{"japanese_$pos"};
        $filled{"english_$no"}  = $filled{"english_$pos"};
    }

    if ( $offset ) {
        delete $filled{"japanese_$max_no"};
        delete $filled{"english_$max_no"};
        $max_no -= 1;
    }

    if ( $self->param('add') ) {
        $max_no += 1;
    }

    my @questions;
    for my $no ( 1 .. $max_no ) {
        push @questions, { no => $no };
    }

    if ( !@questions ) {
        push @questions, { no => 1 };
    }

    $self->stash->{questions} = \@questions;

    $self->render_filled_html(\%filled);
} => 'question/create';


any '/review' => sub {
    my $self = shift;

    my ($id, $section, $no);
    if ( lc($self->req->method) eq 'post' ) {
        $id      = $self->param('id');
        $section = $self->param('section');
        $no      = $self->param('no');

        if ( Model::check_ans($self, $section, $no) ) {
            my $ans_look_count = $self->param('ans_look_count') || 0;
            my $miss_count     = $self->param('miss_count')     || 0;
            if ( ! $ans_look_count ) {
                Model::review_log($self, $id, $section, $no, $ans_look_count, $miss_count);
                return $self->redirect_to('review/index');
            }
            $self->stash->{error} = 0;
            $self->stash->{review} = 1;
            $self->stash->{miss_count} = $miss_count;
        }
        else {
            $self->stash->{miss_count} = $self->param('miss_count') + 1;
            $self->stash->{error}  = 1;
            $self->stash->{review} = 0;
        }
    }
    else {
        my $row = Model::review($self);
        $id      = $row->{id};
        $section = $row->{section};
        $no      = $row->{no};
        $self->stash->{error} = 0;
        $self->stash->{review} = 0;
        $self->stash->{miss_count} = 0;
    }

    $self->stash->{id}      = $id;
    $self->stash->{section} = $section;
    $self->stash->{no}      = $no;
    $self->stash->{ans_look_count} = 0;

    my %filled = Model::create_question_forms($self, $section, $no);

    $self->render_filled_html(\%filled);
} => 'review/index';

app->start;

