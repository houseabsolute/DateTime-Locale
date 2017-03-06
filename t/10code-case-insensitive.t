use strict;
use warnings;
use utf8;

use Test::More 0.96;
use Test::File::ShareDir -share =>
    { -dist => { locale_data => './locale_data' } };

use DateTime::Locale;

for my $code (qw( en EN en-us EN-US EN-us sHi-LatN-mA )) {
    ok(
        DateTime::Locale->load($code),
        "code $code loaded a locale"
    );
}

done_testing();
