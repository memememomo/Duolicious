package DB;
use parent 'Teng';
use DateTime;
__PACKAGE__->load_plugin('Pager');
__PACKAGE__->load_plugin('Count');

use Class::Method::Modifiers;


before update => sub {
    my ($self, $table_name, $update_row_data, $update_condition) = @_;
    if ( !$update_row_data->{updated_at} ) {
        $update_row_data->{updated_at} = DateTime->now->set_time_zone('Asia/Tokyo')->strftime('%Y-%m%-d %H:%M:%S');
    }
};

before insert => sub {
    my ($self, $table_name, $row_data) = @_;
    $row_data->{created_at} = DateTime->now->set_time_zone('Asia/Tokyo')->strftime('%Y-%m%-d %H:%M:%S');
    $row_data->{updated_at} = DateTime->now->set_time_zone('Asia/Tokyo')->strftime('%Y-%m%-d %H:%M:%S');
};

before fast_insert => sub {
    my ($self, $table_name, $row_data) = @_;
    $row_data->{created_at} = DateTime->now->set_time_zone('Asia/Tokyo')->strftime('%Y-%m%-d %H:%M:%S');
    $row_data->{updated_at} = DateTime->now->set_time_zone('Asia/Tokyo')->strftime('%Y-%m%-d %H:%M:%S');
};


1;
