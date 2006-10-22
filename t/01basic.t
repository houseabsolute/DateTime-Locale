#!/usr/bin/perl -w

BEGIN
{
    return unless $] >= 5.006;

    require utf8; import utf8;
}

use strict;
use Test::More;

use DateTime::Locale;

my @locale_ids   = sort DateTime::Locale->ids;
my %locale_names = map { $_ => 1 } DateTime::Locale->names;
my %locale_ids   = map { $_ => 1 } DateTime::Locale->ids;

eval { require DateTime };
my $has_dt = $@ ? 0 : 1;

my $dt = DateTime->new( year => 2000, month => 1, day => 1, time_zone => "UTC" )
    if $has_dt;

my $tests_per_locale = $has_dt ? 16 : 12;

plan tests =>
    5    # starting
    + 1  # load test for root locale
    + ( (@locale_ids - 1) * $tests_per_locale ) # test each local
    + 9 # check_root
    + 20 # check_en_GB
    + 11 # check_es_ES
    + 5  # check_en_US_POSIX
    + 9  # check_DT_Lang
    ;

ok( @locale_ids >= 240,     "Coverage looks complete" );
ok( $locale_names{English}, "Locale name 'English' found" );
ok( $locale_ids{ar_JO},     "Locale id 'ar_JO' found" );

eval { DateTime::Locale->load('Does not exist') };
like( $@, qr/invalid/i, 'invalid locale name/id to load() causes an error' );

{
    # this type of locale id should work
    my $l = DateTime::Locale->load('en_US.LATIN-1');
    is( $l->id, 'en_US', 'id is en_US' );
}

for my $locale_id (@locale_ids)
{
    my $locale;

    eval
    {
        $locale = DateTime::Locale->load($locale_id);
    };

    if ($@)
    {
        diag( "$@\nSkipping tests for failed locale: '$locale_id'" );
        fail() for 1..$tests_per_locale;
    }

    isa_ok( $locale, "DateTime::Locale::Base" );

    next if $locale_id eq 'root';

    ok( $locale_ids{ $locale->id },  "'$locale_id':  Has a valid locale id" );

    ok( length $locale->name,        "'$locale_id':  Has a locale name"        );
    ok( length $locale->native_name, "'$locale_id':  Has a native locale name" );

    check_array($locale_id, $locale, "month_names",         "month_name",         "month", 12);
    check_array($locale_id, $locale, "month_abbreviations", "month_abbreviation", "month", 12);

    check_array($locale_id, $locale, "day_names",           "day_name",           "day",   7 );
    check_array($locale_id, $locale, "day_abbreviations",   "day_abbreviation",   "day",   7 );

    check_formats($locale_id, $locale, "date_formats",        "date_format");
    check_formats($locale_id, $locale, "time_formats",        "time_format");
}

check_root();
check_en_GB();
check_es_ES();
check_en_US_POSIX();
check_DT_Lang();

# does 2 tests
sub check_array
{
    my ($locale_id, $locale, $array_func, $item_func, $dt_component, $count) = @_;

    my %unique = map { $_ => 1 } @{ $locale->$array_func() };

    is( keys %unique, $count, "'$locale_id': '$array_func' contains $count unique items" );

    if ($has_dt)
    {
        for my $i ( 1..$count )
        {
            $dt->set($dt_component => $i);

            delete $unique{ $locale->$item_func($dt) };
        }

        is( keys %unique, 0,
            "'$locale_id':  Data returned by '$array_func' and '$item_func match' matches" );
    }
}

# does 2 tests
sub check_formats
{
    my ($locale_id, $locale, $hash_func, $item_func) = @_;

    my %unique = map { $_ => 1 } values %{ $locale->$hash_func() };

    ok( keys %unique >= 1, "'$locale_id': '$hash_func' contains at least 1 unique item" );

    foreach my $format ( qw( full long medium short ) )
    {
        my $method = "${format}_$item_func";

        my $val = $locale->$method();

        if ( defined $val )
        {
            delete $unique{$val};
        }
        else
        {
            Test::More::diag( "$locale_id returned undef for $method()" );
        }
    }

    is( keys %unique, 0,
        "'$locale_id':  Data returned by '$hash_func' and '$item_func patterns' matches" );
}

# 9 tests
sub check_root
{
    my $locale = DateTime::Locale->load('root');

    my %tests =
        ( day_names =>
          [ qw( 2 3 4 5 6 7 1 ) ],

          day_abbreviations =>
          [ qw( 2 3 4 5 6 7 1 ) ],

          month_names =>
          [ qw( 1 2 3 4 5 6 7 8 9 10 11 12 ) ],

          month_abbreviations =>
          [ qw( 1 2 3 4 5 6 7 8 9 10 11 12 ) ],

          era_abbreviations =>
          [ qw( BCE CE ) ],

          era_names =>
          [ qw( BCE CE ) ],

          am_pms =>
          [ qw( AM PM ) ],

          default_datetime_format => '%{ce_year} %b %{day} %H:%M:%S',
          date_parts_order        => 'ymd',
        );

    for my $k ( sort keys %tests )
    {
        my $desc = "$k for " . $locale->id();
        if ( ref $tests{$k} )
        {
            is_deeply( $locale->$k(), $tests{$k}, $desc );
        }
        else
        {
            is( $locale->$k(), $tests{$k}, $desc );
        }
    }
}

# does 20 tests
sub check_en_GB
{
    my $locale = DateTime::Locale->load('en_GB');

    my %tests =
        ( day_names =>
          [ qw( Monday Tuesday Wednesday Thursday Friday Saturday Sunday ) ],

          day_abbreviations =>
          [ qw( Mon Tue Wed Thu Fri Sat Sun ) ],

          month_names =>
          [ qw( January February March April May June
                July August September October November December ) ],

          month_abbreviations =>
          [ qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ) ],

          era_abbreviations =>
          [ qw( BC AD ) ],

          era_names =>
          [ 'Before Christ', 'Anno Domini' ],

          am_pms =>
          [ qw( AM PM ) ],

          name             => 'English United Kingdom',
          native_name      => 'English United Kingdom',
          language         => 'English',
          native_language  => 'English',
          territory        => 'United Kingdom',
          native_territory => 'United Kingdom',
          variant          => undef,
          native_variant   => undef,

          language_id      => 'en',
          territory_id     => 'GB',
          variant_id       => undef,

          default_datetime_format => '%{day} %b %{ce_year} %H:%M:%S',
          date_parts_order        => 'dmy',
        );

    for my $k ( sort keys %tests )
    {
        my $desc = "$k for " . $locale->id();
        if ( ref $tests{$k} )
        {
            is_deeply( $locale->$k(), $tests{$k}, $desc );
        }
        else
        {
            is( $locale->$k(), $tests{$k}, $desc );
        }
    }
}

sub check_es_ES
{
    my $locale = DateTime::Locale->load('es_ES');

    is( $locale->name, 'Spanish Spain', 'name()' );
    is( $locale->native_name, 'español España', 'native_name()' );
    is( $locale->language, 'Spanish', 'language()' );
    is( $locale->native_language, 'español', 'native_language()' );
    is( $locale->territory, 'Spain', 'territory()' );
    is( $locale->native_territory, 'España', 'native_territory()' );
    is( $locale->variant, undef, 'variant()' );
    is( $locale->native_variant, undef, 'native_variant()' );

    is( $locale->language_id, 'es', 'language_id()' );
    is( $locale->territory_id, 'ES', 'territory_id()' );
    is( $locale->variant_id, undef, 'variant_id()' );
}

sub check_en_US_POSIX
{
    my $locale = DateTime::Locale->load('en_US_POSIX');

    is( $locale->variant, 'Posix', 'variant()' );
    is( $locale->native_variant, 'Posix', 'native_variant()' );

    is( $locale->language_id, 'en', 'language_id()' );
    is( $locale->territory_id, 'US', 'territory_id()' );
    is( $locale->variant_id, 'POSIX', 'variant_id()' );
}

sub check_DT_Lang
{
    foreach my $old ( qw ( Austrian TigrinyaEthiopian TigrinyaEritrean
                           Brazilian Portuguese
                           Afar Sidama Tigre ) )
    {
        ok( DateTime::Locale->load($old), "backwards compatibility for $old" );
    }

    foreach my $old ( qw ( Gedeo ) )
    {
      SKIP:
        {
            skip 'No CLDR XML data for some African languages included in DT::Language', 1
                unless $locale_names{$old};

            ok( DateTime::Locale->load($old), "backwards compatibility for $old" );
        }
    }
}

