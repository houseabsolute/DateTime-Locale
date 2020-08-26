use strict;
use warnings;

use Test::More;
use Test::File::ShareDir::Dist { 'DateTime-Locale' => 'share' };

use File::ShareDir qw( dist_dir );
use File::Spec;

use DateTime::Locale;

{

    my $dist_dir            = dist_dir('DateTime-Locale');
    my @dist_dir_components = File::Spec->splitdir($dist_dir);

    pop @dist_dir_components for 0 .. 3; # pop auto/share/dist/DateTime-Locale
    my $share_dir = pop @dist_dir_components;

    chdir File::Spec->catdir(@dist_dir_components)
        or die 'couldn\'t change to tmp directory';

    local @INC = ($share_dir);
    my $l = DateTime::Locale->load('de-DE');

    ok( $l, 'was able to load de-DE locale from relative dir' );
    isa_ok( $l, 'DateTime::Locale::FromData' );
}

done_testing();
