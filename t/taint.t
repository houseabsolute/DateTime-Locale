#!perl -T

use strict;
use warnings;

use Path::Tiny qw( path );
use Scalar::Util 'tainted';
use Test2::V0;

# This works around the value of $FindBin::Bin being tainted. See
# https://github.com/kentnl/Test-File-ShareDir/issues/1 for further details.
my $root;

BEGIN {
    $root = path('.')->absolute->stringify;
    ($root) = $root =~ /(.+)/;
}

use Test::File::ShareDir(
    {
        -root  => $root,
        -share => {
            -dist   => { 'DateTime-Locale'  => 'share/' },
            -module => { 'DateTime::Locale' => 'share/' },
        },
    }
);

use DateTime::Locale;

skip_all 'Taint mode is not enabled' unless ${^TAINT};

use File::ShareDir qw( dist_dir );

# Concat code with zero bytes of executable name in order to taint it.
my $code = 'en-GB' . substr $^X, 0, 0;

ok( tainted($code), '$code is tainted' );

try_ok(
    sub {
        is(
            DateTime::Locale->load($code)->code, $code,
            'loaded correct code'
        );
    },
    'tainted load lives'
);

done_testing;
