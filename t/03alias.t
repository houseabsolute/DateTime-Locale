use strict;
use Test::More tests => 1;

use DateTime::Locale;

DateTime::Locale->add_aliases( foo => 'root' );
DateTime::Locale->add_aliases( bar => 'foo' );
DateTime::Locale->add_aliases( baz => 'bar' );
eval { DateTime::Locale->add_aliases( bar => 'baz' ) };

like( $@, qr/loop/ );
