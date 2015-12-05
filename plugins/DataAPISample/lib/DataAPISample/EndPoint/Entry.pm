package DataAPISample::EndPoint::Entry;

use strict;
use warnings;
use CustomFields::Util qw( get_meta );

use MT::DataAPI::Endpoint::Common;
use MT::DataAPI::Endpoint::Entry;
use MT::DataAPI::Resource;
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
        my $data = {
            id => $entry->id,
            title => $entry->title,
            start => format_datetime($meta->{ 'dt_start' }),
            end => format_datetime($meta->{ 'dt_end' }),
            allDay => format_datetime($meta->{ 'is_allday' }) ? boolean::true() : boolean::false()
        };
        push(@ret, $data);
    }

    return [ @ret ];
}

sub format_datetime {
    my $data = shift;

    $data =~ s/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/$1-$2-$3 $4:$5:$6/g;

    $data;
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
