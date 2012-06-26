package DB;
use parent 'Teng';
use DateTime;
__PACKAGE__->load_plugin('Pager');
__PACKAGE__->load_plugin('Count');
__PACKAGE__->load_plugin('BulkInsert');
__PACKAGE__->load_plugin('Pager::MySQLFoundRows');

use Class::Method::Modifiers;


before update => sub {
    my ($self, $table_name, $update_row_data, $update_condition) = @_;
    if ( !$update_row_data->{updated_at} ) {
        $update_row_data->{updated_at} = DateTime->now->set_time_zone('Asia/Tokyo');
    }
};

before insert => sub {
    my ($self, $table_name, $row_data) = @_;
    $row_data->{created_at} = DateTime->now->set_time_zone('Asia/Tokyo');
    $row_data->{updated_at} = DateTime->now->set_time_zone('Asia/Tokyo');
};

before fast_insert => sub {
    my ($self, $table_name, $row_data) = @_;
    $row_data->{created_at} = DateTime->now->set_time_zone('Asia/Tokyo');
    $row_data->{updated_at} = DateTime->now->set_time_zone('Asia/Tokyo');
};


1;
