use strict;
use warnings;
use utf8;

use Test::More;

use DateTime::Locale;

if ( $] <= 5.008 ) {
    plan skip_all => 'These tests require Perl 5.8.0+';
}

my $loc = DateTime::Locale->load('zh-Hans-SG');

is( $loc->script,        'Simplified', 'check script' );
is( $loc->native_script, '简体',     'check native_script' );
is( $loc->script_id,     'Hans',       'check script_id' );

is( $loc->territory_id, 'SG', 'check territory_id' );

done_testing();
