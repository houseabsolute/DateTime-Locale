#!/usr/bin/perl -w

use strict;
use Test::More tests => 8;

use DateTime::Locale;

{
    package DateTime::Locale::en_GB_RIDAS;

    use base qw(DateTime::Locale::root);
}

{
    package DateTime::Locale::en_FOO_BAR;

    use base qw(DateTime::Locale::root);
}

{
    package DateTime::Locale::en_BAZ_BUZ;

    use base qw(DateTime::Locale::root);
}

{
    package DateTime::Locale::en_QUUX_QUAX;

    use base qw(DateTime::Locale::root);
}

DateTime::Locale->register
    ( id => 'en_GB_RIDAS',
      en_language  => 'English',
      en_territory => 'United Kingdom',
      en_variant   => 'Ridas Custom Locale',
    );

{
    my $l = DateTime::Locale->load('en_GB_RIDAS');
    ok( $l, 'was able to load en_GB_RIDAS' );
    is( $l->variant, 'Ridas Custom Locale', 'variant is set properly' );
}

DateTime::Locale->register
    ( { id => 'en_FOO_BAR',
        en_language  => 'English',
        en_territory => 'United Kingdom',
        en_variant   => 'Foo Bar',
      },
      { id => 'en_BAZ_BUZ',
        en_language  => 'English',
        en_territory => 'United Kingdom',
        en_variant   => 'Baz Buz',
      },
    );

{
    my $l = DateTime::Locale->load('en_FOO_BAR');
    ok( $l, 'was able to load en_FOO_BAR' );
    is( $l->variant, 'Foo Bar', 'variant is set properly' );

    $l = DateTime::Locale->load('en_BAZ_BUZ');
    ok( $l, 'was able to load en_BAZ_BUZ' );
    is( $l->variant, 'Baz Buz', 'variant is set properly' );
}

# backwards compatibility
DateTime::Locale->register
    ( { id => 'en_QUUX_QUAX',
        en_language  => 'English',
        en_territory => 'United Kingdom',
        en_variant   => 'Wacko',
      },
    );

{
    my $l = DateTime::Locale->load('en_QUUX_QUAX');
    ok( $l, 'was able to load en_QUUX_QUAX' );
    is( $l->variant, 'Wacko', 'variant is set properly' );
}
