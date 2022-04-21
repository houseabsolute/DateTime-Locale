#!perl -T

use Scalar::Util 'tainted';
use Test2::V0 -target => 'DateTime::Locale';

skip_all 'Taint not supported' unless ${^TAINT};

# Concat code with zero bytes of executable name in order to taint it.
my $code = 'en-GB' . substr $^X, 0, 0;

ok tainted $code, 'code is tainted';

try_ok {
    is CLASS->load($code)->code, $code, 'code is correct';
} 'tainted load lives';

done_testing;
