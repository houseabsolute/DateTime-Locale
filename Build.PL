use strict;

use Module::Build;
use File::Spec;

unless ( -e File::Spec->catfile( qw( lib DateTime Locale root.pm ) ) )
{
    warn <<'EOF';

It looks like you haven't run tools/generate_from_icu to generate the
locale modules yet.

EOF

    my $xml_dir = File::Spec->catdir( File::Spec->curdir, 'icu-xml' );
    if ( -d $xml_dir )
    {
        my $bin = File::Spec->catfile( qw( tools generate_from_icu ) );
        warn "I will generate them for you by running '$bin --dir $xml_dir'.\n";

        system( $bin, '--dir', $xml_dir, '--quiet' )
            and die "Cannot run $bin --dir $xml_dir: $!";

        warn "\nDone generating locale files.\n\n";
    }
    else
    {
        warn <<'EOF';

This script needs ICU XML locale data, available from the
modules/DateTime-Locale/icu-xml directory of the perl-date-time
project on Sourceforge.

Once you've run this script you will be able to test and install this
distribution.

EOF

        exit;
    }
}

Module::Build->new( module_name => 'DateTime::Locale',
                    author      => 'Dave Rolsky <autarch@urth.org>',
                    license     => 'perl',
                    requires    => { 'Params::Validate' => 0,
                                   },
                  )->create_build_script;
