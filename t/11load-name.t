use strict;
use warnings;
use utf8;

use Test::More 0.96;

use DateTime::Locale;

my $builder = Test::More->builder;
## no critic (InputOutput::RequireCheckedSyscalls)
binmode $builder->output,         ':encoding(UTF-8)';
binmode $builder->failure_output, ':encoding(UTF-8)';
binmode $builder->todo_output,    ':encoding(UTF-8)';

## use critic

for my $code (qw( English French Italian Latvian latviešu )) {
    ok(
        DateTime::Locale->load($code),
        "code $code loaded a locale"
    );
}

done_testing();
