use strict;
use warnings;

use Test::More;
use Test::File::ShareDir::Dist { 'DateTime-Locale' => 'share' };

use Storable qw(dclone);

use DateTime::Locale;

{
    my $cldr            = DateTime::Locale->load('en');
    my %locale_data     = $cldr->locale_data;
    my $locale_data_old = dclone( \%locale_data );
    delete $locale_data{available_formats}{d};
    my $locale_data_new = { $cldr->locale_data };

    is_deeply(
        $locale_data_old, $locale_data_new,
        'modifying locale_data doesn\'t affect original locale'
    );
}

done_testing();
