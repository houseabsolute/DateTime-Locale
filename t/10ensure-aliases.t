use strict;
use warnings;

use Test::More;

use DateTime::Locale;


my @aliases = qw( C POSIX chi per khm );

plan tests => scalar @aliases;


for my $alias (@aliases)
{
    ok( DateTime::Locale->load($alias), "alias mapping for $alias exists" );
}
