use strict;
use warnings;
use utf8;

use File::Spec;
use Test::More;

use DateTime::Locale;

my @locale_ids   = sort DateTime::Locale->ids;
my %locale_names = map { $_ => 1 } DateTime::Locale->names;
my %locale_ids   = map { $_ => 1 } DateTime::Locale->ids;

eval { require DateTime };
my $has_dt = $@ ? 0 : 1;

my $dt = DateTime->new( year => 2000, month => 1, day => 1, time_zone => 'UTC' )
    if $has_dt;

my $tests_per_locale = $has_dt ? 23 : 19;

plan tests =>
    7    # starting
    + 1  # load test for root locale
    + ( (@locale_ids - 1) * $tests_per_locale ) # test each local
    + 26 # check_root
    + 50 # check_en_GB
    + 11 # check_es_ES
    + 2  # check_af
    + 5  # check_en_US_POSIX
    + 9  # check_DT_Lang
    ;

ok( @locale_ids >= 240,     'Coverage looks complete' );
ok( $locale_names{English}, "Locale name 'English' found" );
ok( $locale_ids{ar_JO},     "Locale id 'ar_JO' found" );

eval { DateTime::Locale->load('Does not exist') };
like( $@, qr/invalid/i, 'invalid locale name/id to load() causes an error' );

{
    # this type of locale id should work
    my $l = DateTime::Locale->load('en_US.LATIN-1');
    is( $l->id, 'en_US', 'id is en_US' );
}

{
    my $file = File::Spec->catfile( 'lib/DateTime/Locale/zu_ZA.pm' );
    ok( ! -f $file, 'zu_ZA.pm does not exist' );

    my $locale = eval { DateTime::Locale->load('zu_ZA') };
    isa_ok( $locale, 'DateTime::Locale::Base', 'can load zu_ZA locale anyway' );
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

    isa_ok( $locale, 'DateTime::Locale::Base' );

    next if $locale_id eq 'root';

    ok( $locale_ids{ $locale->id }, "'$locale_id':  Has a valid locale id" );

    ok( length $locale->name, "'$locale_id':  Has a locale name" );
    ok( length $locale->native_name,
        "'$locale_id':  Has a native locale name" );

    # Each iteration runs one test if DateTime.pm is not available or
    # there is no matching DateTime.pm method, otherwise it runs two.
    for my $test ( { locale_method    => 'month_names',
                     datetime_method  => 'month_name',
                     datetime_set_key => 'month',
                     count            => 12,
                   },
                   { locale_method    => 'month_abbreviations',
                     datetime_method  => 'month_abbreviation',
                     datetime_set_key => 'month',
                     count            => 12,
                   },
                   { locale_method    => 'day_names',
                     datetime_method  => 'day_name',
                     datetime_set_key => 'day',
                     count            => 7,
                   },
                   { locale_method    => 'day_abbreviations',
                     datetime_method  => 'day_abbreviation',
                     datetime_set_key => 'day',
                     count            => { default => 7,
                                           ii      => 6,
                                           ii_CN   => 6,
                                         },
                   },
                   { locale_method    => 'quarter_names',
                     count            => 4,
                   },
                   { locale_method    => 'quarter_abbreviations',
                     count            => 4,
                   },
                   { locale_method    => 'am_pms',
                     count            => 2,
                   },
                   { locale_method    => 'era_names',
                     count            => 2,
                   },
                   { locale_method    => 'era_abbreviations',
                     count            => 2,
                   },
                 )
    {
        check_array( locale => $locale, %$test );
    }

    # We can't actually expect these to be unique.
    is( scalar @{ $locale->day_narrows() }, 7, 'day_narrows() returns 7 items' );
    is( scalar @{ $locale->month_narrows() }, 12, 'month_narrows() returns 12 items' );

    check_formats( $locale_id, $locale, 'date_formats', 'date_format' );
    check_formats( $locale_id, $locale, 'time_formats', 'time_format' );
}

check_root();
check_en_GB();
check_es_ES();
check_en_US_POSIX();
check_af();
check_DT_Lang();

sub check_array
{
    my %test = @_;

    my $locale_method = $test{locale_method};

    my %unique = map { $_ => 1 } @{ $test{locale}->$locale_method() };

    my $locale_id = $test{locale}->id();

    my $default_count;
    my $unique_count;

    if ( ref $test{count} )
    {
        $default_count = $test{count}{default};
        $unique_count = $test{count}{$locale_id} || $default_count;
    }
    else
    {
        $default_count = $unique_count = $test{count};
    }

    is( keys %unique, $unique_count, "'$locale_id': '$locale_method' contains $unique_count unique items" );

    my $datetime_method = $test{datetime_method};
    return unless $datetime_method && $has_dt;

    for my $i ( 1..$default_count )
    {
        $dt->set( $test{datetime_set_key} => $i );

        delete $unique{ $test{locale}->$datetime_method($dt) };
    }

    is( keys %unique, 0,
        "'$locale_id':  Data returned by '$locale_method' and '$datetime_method' matches" );
}

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

sub check_root
{
    my $locale = DateTime::Locale->load('root');

    my %tests =
        ( day_names =>
          [ qw( 2 3 4 5 6 7 1 ) ],

          day_abbreviations =>
          [ qw( 2 3 4 5 6 7 1 ) ],

          day_narrows =>
          [ qw( 2 3 4 5 6 7 1 ) ],

          month_names =>
          [ qw( 1 2 3 4 5 6 7 8 9 10 11 12 ) ],

          month_abbreviations =>
          [ qw( 1 2 3 4 5 6 7 8 9 10 11 12 ) ],

          month_narrows =>
          [ qw( 1 2 3 4 5 6 7 8 9 10 11 12 ) ],

          quarter_abbreviations =>
          [ qw( Q1 Q2 Q3 Q4 ) ],

          quarter_names =>
          [ qw( Q1 Q2 Q3 Q4 ) ],

          era_abbreviations =>
          [ qw( BCE CE ) ],

          era_names =>
          [ qw( BCE CE ) ],

          am_pms =>
          [ qw( AM PM ) ],

          default_datetime_format => '%{ce_year} %b %{day} %H:%M:%S',
          date_parts_order        => 'ymd',
        );

    test_data( $locale, %tests );

    my %formats =
        ( Ed     => "\%a\ \%\{day\}",
          H      => "\%\{hour\}",
          HHmm   => "\%H\:\%M",
          HHmmss => "\%H\:\%M\:\%S",
          MMMEd  => "\%a\ \%b\ \%\{day\}",
          MMMMd  => "\%B\ \%\{day\}",
          Md     => "\%\{month\}\-\%\{day\}",
          mmss   => "\%M\:\%S",
          yyMM   => "\%y\-\%m",
          yyMMM  => "\%y\ \%b",
          yyQ    => "\%y\ Q",
          yyyy   => "\%\{ce_year\}",
        );

    test_formats( $locale, %formats );
}

sub check_en_GB
{
    my $locale = DateTime::Locale->load('en_GB');

    my %tests =
        ( day_names =>
          [ qw( Monday Tuesday Wednesday Thursday Friday Saturday Sunday ) ],

          day_abbreviations =>
          [ qw( Mon Tue Wed Thu Fri Sat Sun ) ],

          day_narrows =>
          [ qw( M T W T F S S ) ],

          month_names =>
          [ qw( January February March April May June
                July August September October November December ) ],

          month_abbreviations =>
          [ qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ) ],

          month_narrows =>
          [ qw( J F M A M J J A S O N D ) ],

          quarter_abbreviations =>
          [ qw( Q1 Q2 Q3 Q4 ) ],

          quarter_names =>
          [ '1st quarter', '2nd quarter', '3rd quarter', '4th quarter' ],

          eras =>
          [ qw( BC AD ) ],

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

    test_data( $locale, %tests );

    my %formats =
        ( MMMEd    => "\%a\ \%\{day\}\ \%b",
          MMMMd    => "\%\{day\}\ \%B",
          MMdd     => "\%d\/\%m",
          Md       => "\%\{day\}\/\%\{month\}",
          yyMMM    => "\%b\ \%y",
          yyyyMM   => "\%m\/\%\{ce_year\}",
          yyyyMMMM => "\%B\ \%\{ce_year\}",

          # from en
          HHmm    => "\%H\:\%M",
          HHmmss  => "\%H\:\%M\:\%S",
          MMMMdd  => "\%d\ \%B",
          MMMd    => "\%\{day\}\-\%b",
          MMMdd   => "\%d\ \%b",
          MMd     => "\%\{day\}\/\%m",
          hhmm    => "\%l\:\%M\ \%p",
          hhmmss  => "\%l\:\%M\:\%S\ \%p",
          mmss    => "\%M\:\%S",
          yyMM    => "\%m\/\%y",
          yyQ     => "Q\ \%y",
          yyQQQQ  => "QQQQ\ \%y",
          yyyyM   => "\%\{month\}\/\%\{ce_year\}",
          yyyyMMM => "\%b\ \%\{ce_year\}",

          # from root
          Ed     => "\%a\ \%\{day\}",
          H      => "\%\{hour\}",
          yyyy   => "\%\{ce_year\}",
        );

    test_formats( $locale, %formats );
}

sub test_data
{
    my $locale = shift;
    my %tests = @_;

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

sub test_formats
{
    my $locale  = shift;
    my %formats = @_;

    for my $name ( keys %formats )
    {
        is( $locale->format_for($name), $formats{$name},
            "Format for $name with " . $locale->id() );
    }

    is_deeply( [ $locale->available_formats() ],
               [ sort keys %formats ],
               "Format keys for " . $locale->id() . " match what is expected" );
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

sub check_af
{
    my $locale = DateTime::Locale->load('af');

    is_deeply( $locale->month_abbreviations(),
               [ qw( Jan Feb Mar Apr Mei Jun Jul Aug Sep Okt Nov Des ) ],
               'month abbreviations for af use non-draft form' );

    is_deeply( $locale->month_narrows(),
               [ 1..12 ],
               'month narrows for af use draft form because that is the only form available' );
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

