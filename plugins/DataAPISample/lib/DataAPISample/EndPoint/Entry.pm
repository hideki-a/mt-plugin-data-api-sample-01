package DataAPISample::EndPoint::Entry;

use strict;
use warnings;
use CustomFields::Util qw( get_meta );

use MT::DataAPI::Endpoint::Common;
use MT::DataAPI::Endpoint::Entry;
use MT::DataAPI::Resource;
use MT::Util qw( format_ts ts2iso );
use DateTime;
use boolean ();

sub search_entries_by_field {
    my ( $app, $endpoint ) = @_;

    my $col = 'dt_start';
    my $class = MT->model('entry');
    my $type = MT::Meta->metadata_by_name($class, 'field.' . $col);
    my @entries = MT::Entry->load(
        {
            # blog_id => $app->param('blog_id') ? $app->param('blog_id') : 1,
            blog_id => 1,
            status => MT::Entry::RELEASE()
        },
        {
            join => [
                $class->meta_pkg,
                undef,
                {
                    'entry_id' => \'= entry_id',
                    type => 'field.' . $col,
                    $type->{type} => [ $app->param('start') . ' 00:00:00', $app->param('end') . ' 23:59:59' ]
                },
                {
                    range => {
                        $type->{type} => 1
                    }
                }
            ],
            sort => 'authored_on',
            direction => 'descend',
        }
    );

    my @ret = ();

    foreach my $entry ( @entries ) {
        my $meta = &get_meta($entry);
        my $data;
        my $dt_end;

        if ($meta->{ 'is_allday' }) {
            # 終日スケジュール

            if ($meta->{ 'dt_end' }) {
                # 終了日設定有り…カレンダーの仕様上1日加算
                $dt_end = format_date($meta->{ 'dt_end' }, 'add1day');
            } else {
                $dt_end = '';
            }

            $data = {
                id => $entry->id,
                title => $entry->title,
                allDay => $meta->{ 'is_allday' } ? boolean::true() : boolean::false(),
                start => format_ts('%Y-%m-%d', $meta->{ 'dt_start' }, $app->blog),
                end => $dt_end,
           };
        } else {
            if ($meta->{ 'dt_end' }) {
                $dt_end = ts2iso($app->blog, $meta->{ 'dt_end' }, 1);
            } else {
                $dt_end = '';
            }

            $data = {
                id => $entry->id,
                title => $entry->title,
                allDay => $meta->{ 'is_allday' } ? boolean::true() : boolean::false(),
                start => ts2iso($app->blog, $meta->{ 'dt_start' }, 1),
                end => $dt_end,
            };
        }

        push(@ret, $data);
    }

    return [ @ret ];
}

sub format_date {
    my ( $data, $type ) = @_;

    if ($type eq 'add1day') {
        # 1日加算後、形式の変換を実行
        $data =~ /(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/;
        my $dt = DateTime->new(
            time_zone => 'local',
            year => "$1",
            month => "$2",
            day => "$3",
            hour => 0,
            minute => 0,
            second => 0
        );
        $dt->add( days => 1 );
        return $dt->strftime('%Y-%m-%d');
    }
}

sub filter_entries_by_field {
    my ( $app, $endpoint ) = @_;
    # my $term = { };
    # $term->{basename} = 'test';

    my $col = 'data_aircraft_type';
    my $class = MT->model('entry');
    my $type = MT::Meta->metadata_by_name($class, 'field.' . $col);
    my $args = {
        join => [
            $class->meta_pkg,
            undef,
            {
                'entry_id' => \'= entry_id',
                type => 'field.' . $col,
                $type->{type} => 'A350'
            }
        ],
        sort => 'authored_on',
        direction => 'descend'
    };

    my $res = filtered_list( $app, $endpoint, 'entry', undef, $args ) or return;

    +{  totalResults => $res->{count} + 0,
        items =>
            MT::DataAPI::Resource::Type::ObjectList->new( $res->{objects} ),
    };
}

1;
