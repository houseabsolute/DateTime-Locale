use strict;
use warnings;
use utf8;

use Data::Dumper;
use Path::Class;
use Test::More tests => 99;

use LDML;

{
    my $ldml = LDML->new(
        id          => 'cop_Arab_EG',
        source_file => file($0),
        document    => XML::LibXML::Document->new(),
    );
    is_deeply(
        [ $ldml->_parse_id() ],
        [ 'cop', 'Arab', 'EG', undef ],
        '_parse_id for cop_Arab_EG'
    );

}

{
    my $ldml = LDML->new(
        id          => 'hy_AM_REVISED',
        source_file => file($0),
        document    => XML::LibXML::Document->new(),
    );
    is_deeply(
        [ $ldml->_parse_id() ],
        [ 'hy', undef, 'AM', 'REVISED' ],
        '_parse_id for hy_AM_REVISED'
    );
}

{

    # There are no ids with all four parts as of CLDR 1.5.1 but just
    # in case it ever happens ...
    my $ldml = LDML->new(
        id          => 'wo_Latn_SN_REVISED',
        source_file => file($0),
        document    => XML::LibXML::Document->new(),
    );
    is_deeply(
        [ $ldml->_parse_id() ],
        [ 'wo', 'Latn', 'SN', 'REVISED' ],
        '_parse_id for wo_Latn_SN_REVISED'
    );
}

{
    my $ldml = LDML->new_from_file('t/test-data/root.xml');

    ok( $ldml->has_calendar_data(), 'has calendar data' );

    my @data = (
        id              => 'root',
        version         => '1.192',
        generation_date => '2009/06/15 21:39:59',
        parent_id       => 'Base',
        source_file     => file('t/test-data/root.xml'),

        en_language  => 'Root',
        en_script    => undef,
        en_territory => undef,
        en_variant   => undef,

        native_language  => undef,
        native_script    => undef,
        native_territory => undef,
        native_variant   => undef,

        day_format_narrow           => [ 2 .. 7, 1 ],
        day_format_abbreviated      => [ 2 .. 7, 1 ],
        day_format_wide             => [ 2 .. 7, 1 ],
        day_stand_alone_narrow      => [ 2 .. 7, 1 ],
        day_stand_alone_abbreviated => [ 2 .. 7, 1 ],
        day_stand_alone_wide        => [ 2 .. 7, 1 ],

        month_format_narrow           => [ 1 .. 12 ],
        month_format_abbreviated      => [ 1 .. 12 ],
        month_format_wide             => [ 1 .. 12 ],
        month_stand_alone_narrow      => [ 1 .. 12 ],
        month_stand_alone_abbreviated => [ 1 .. 12 ],
        month_stand_alone_wide        => [ 1 .. 12 ],

        quarter_format_narrow           => [ 1 .. 4 ],
        quarter_format_abbreviated      => [ map { 'Q' . $_ } 1 .. 4 ],
        quarter_format_wide             => [ map { 'Q' . $_ } 1 .. 4 ],
        quarter_stand_alone_narrow      => [ 1 .. 4 ],
        quarter_stand_alone_abbreviated => [ map { 'Q' . $_ } 1 .. 4 ],
        quarter_stand_alone_wide        => [ map { 'Q' . $_ } 1 .. 4 ],

        am_pm_abbreviated => [qw( AM PM )],

        era_wide        => [qw( BCE CE )],
        era_abbreviated => [qw( BCE CE )],
        era_narrow      => [qw( BCE CE )],

        date_format_full   => 'EEEE, y MMMM dd',
        date_format_long   => 'y MMMM d',
        date_format_medium => 'y MMM d',
        date_format_short  => 'yyyy-MM-dd',

        time_format_full   => 'HH:mm:ss zzzz',
        time_format_long   => 'HH:mm:ss z',
        time_format_medium => 'HH:mm:ss',
        time_format_short  => 'HH:mm',

        datetime_format => '{1} {0}',

        default_date_format_length => 'medium',
        default_time_format_length => 'medium',

        available_formats => {
            d      => 'd',
            EEEd   => 'd EEE',
            hm     => 'h:mm a',
            Hm     => 'H:mm',
            hms    => 'h:mm:ss a',
            Hms    => 'H:mm:ss',
            M      => 'L',
            Md     => 'M-d',
            MEd    => 'E, M-d',
            MMM    => 'LLL',
            MMMd   => 'MMM d',
            MMMEd  => 'E MMM d',
            MMMMd  => 'MMMM d',
            MMMMEd => 'E MMMM d',
            ms     => 'mm:ss',
            y      => 'y',
            yM     => 'y-M',
            yMEd   => 'EEE, y-M-d',
            yMMM   => 'y MMM',
            yMMMEd => 'EEE, y MMM d',
            yMMMM  => 'y MMMM',
            yQ     => 'y Q',
            yQQQ   => 'y QQQ',
        },

        default_interval_format => "{0} \x{2013} {1}",

        interval_formats => {
            'yMMMd' => {
                'y' => "yyyy-MM-dd \x{2013} yyyy-MM-dd",
                'M' => "yyyy-MM-dd \x{2013} MM-d",
                'd' => "yyyy-MM-d \x{2013} d"
            },
            'd'      => { 'd' => 'd-d' },
            'yMMMEd' => {
                'y' => "E, yyyy-MM-dd \x{2013} E, yyyy-MM-dd",
                'M' => "E, yyyy-MM-dd \x{2013} E, yyyy-MM-dd",
                'd' => "E, yyyy-MM-dd \x{2013} E, yyyy-MM-dd"
            },
            'y'  => { 'y' => 'y-y' },
            'hv' => {
                'a' => 'HH-HH v',
                'h' => 'HH-HH v'
            },
            'yMMMM' => {
                'y' => "yyyy-MM \x{2013} yyyy-MM",
                'M' => "yyyy-MM \x{2013} MM"
            },
            'h' => {
                'a' => 'HH-HH',
                'h' => 'HH-HH'
            },
            'M'   => { 'M' => 'M-M' },
            'yMd' => {
                'y' => "yyyy-MM-dd \x{2013} yyyy-MM-dd",
                'M' => "yyyy-MM-dd \x{2013} MM-dd",
                'd' => "yyyy-MM-dd \x{2013} dd"
            },
            'MMM' => { 'M' => 'LLL-LLL' },
            'MEd' => {
                'M' => "E, MM-dd \x{2013} E, MM-dd",
                'd' => "E, MM-dd \x{2013} E, MM-dd"
            },
            'yM' => {
                'y' => "yyyy-MM \x{2013} yyyy-MM",
                'M' => "yyyy-MM \x{2013} MM"
            },
            'Md' => {
                'M' => "MM-dd \x{2013} MM-dd",
                'd' => "MM-dd \x{2013} dd"
            },
            'yMEd' => {
                'y' => "E, yyyy-MM-dd \x{2013} E, yyyy-MM-dd",
                'M' => "E, yyyy-MM-dd \x{2013} E, yyyy-MM-dd",
                'd' => "E, yyyy-MM-dd \x{2013} E, yyyy-MM-dd"
            },
            'hm' => {
                'a' => 'HH:mm-HH:mm',
                'h' => 'HH:mm-HH:mm',
                'm' => 'HH:mm-HH:mm'
            },
            'hmv' => {
                'a' => 'HH:mm-HH:mm v',
                'h' => 'HH:mm-HH:mm v',
                'm' => 'HH:mm-HH:mm v'
            },
            'MMMEd' => {
                'M' => "E, MM-d \x{2013} E, MM-d",
                'd' => "E, MM-d \x{2013} E, MM-d"
            },
            'MMMM' => { 'M' => 'LLLL-LLLL' },
            'MMMd' => {
                'M' => "MM-d \x{2013} MM-d",
                'd' => "MM-d \x{2013} d"
            },
            'yMMM' => {
                'y' => "yyyy-MM \x{2013} yyyy-MM",
                'M' => "yyyy-MM \x{2013} MM"
            },
        },

        field_names => {
            era   => { name => 'Era' },
            year  => { name => 'Year' },
            month => { name => 'Month' },
            week  => { name => 'Week' },
            day   => {
                name => 'Day',
                '-1' => 'Yesterday',
                '0'  => 'Today',
                '1'  => 'Tomorrow',
            },
            weekday   => { name => 'Day of the Week' },
            dayperiod => { name => 'Dayperiod' },
            hour      => { name => 'Hour' },
            minute    => { name => 'Minute' },
            second    => { name => 'Second' },
            zone      => { name => 'Zone' },
        },

        first_day_of_week => 1,
    );

    test_data( $ldml, 'root', \@data );
}

{
    my $ldml = LDML->new_from_file('t/test-data/ssy.xml');

    my @data = (
        id              => 'ssy',
        version         => '1.1',
        generation_date => '2007/07/19 20:48:11',

        language  => 'ssy',
        script    => undef,
        territory => undef,
        variant   => undef,
        parent_id => 'root',
    );

    test_data( $ldml, 'ssy', \@data );
}

{
    my $ldml = LDML->new_from_file('t/test-data/en_GB.xml');

    my @data = (
        id        => 'en_GB',
        language  => 'en',
        script    => undef,
        territory => 'GB',
        variant   => undef,
        parent_id => 'en',

        first_day_of_week => 7,
    );

    test_data( $ldml, 'en_GB', \@data );
}

{
    my $ldml = LDML->new_from_file('t/test-data/en_US.xml');

    my @data = (
        id => 'en_US',

        first_day_of_week => 7,
    );

    test_data( $ldml, 'en_US', \@data );
}

{
    my $ldml = LDML->new_from_file('t/test-data/az.xml');

    my @data = (
        id => 'az',

        day_format_wide => [
            'bazar ertəsi',
            'çərşənbə axşamı',
            'çərşənbə',
            'cümə axşamı',
            'cümə',
            'şənbə',
            'bazar'
        ],
    );

    test_data( $ldml, 'az', \@data );
}

{
    my $ldml = LDML->new_from_file('t/test-data/gaa.xml');

    my @data = (
        id => 'gaa',

        day_format_abbreviated => [qw( Dzu Dzf Sho Soo Soh Ho Hog )],
    );

    test_data( $ldml, 'gaa', \@data );
}

{
    my $ldml = LDML->new_from_file('t/test-data/ve.xml');

    my @data = (
        id => 've',

        month_format_abbreviated =>
            [qw( Pha Luh Ṱhf Lam Shu Lwi Lwa Ṱha Khu Tsh Ḽar Nye )],
    );

    test_data( $ldml, 've', \@data );
}

{
    my $ldml = LDML->new_from_file('t/test-data/zh_MO.xml');

    is( $ldml->parent_id(), 'zh_Hant_MO', 'parent_id for zh_MO' );
    ok( !$ldml->has_calendar_data(), 'has no calendar data' );
}

{
    my $ldml = LDML->new_from_file('t/test-data/ti.xml');

    cmp_ok(
        scalar @{
            [
                $ldml->document()->documentElement()
                    ->findnodes('localeDisplayNames/territories/territory')
            ]
            },
        '>', 2,
        'ti alias to am for territories was resolved properly'
    );
}

{
    my $ldml = LDML->new_from_file('t/test-data/zh_TW.xml');

    my @data = (
        id => 'zh_TW',

        en_language  => 'Chinese',
        en_script    => undef,
        en_territory => 'Taiwan',
        en_variant   => undef,

        native_language  => '中文',
        native_script    => undef,
        native_territory => '台灣',
        native_variant   => undef,
    );

    test_data( $ldml, 'zh_TW', \@data );
}

{
    my $ldml = LDML->new_from_file('t/test-data/zh_Hant_TW.xml');

    my @data = (
        id => 'zh_Hant_TW',

        en_language  => 'Chinese',
        en_script    => 'Traditional Han',
        en_territory => 'Taiwan',
        en_variant   => undef,

        native_language  => '中文',
        native_script    => '繁體中文',
        native_territory => '台灣',
        native_variant   => undef,
    );

    test_data( $ldml, 'zh_Hant_TW', \@data );
}

sub test_data {
    my $ldml = shift;
    my $id   = shift;
    my $data = shift;

    for ( my $i = 0; $i < @{$data}; $i += 2 ) {
        my $meth = $data->[$i];

        is_deeply(
            $ldml->$meth(),
            $data->[ $i + 1 ],
            "$meth in $id"
        );
    }
}
