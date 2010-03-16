use 5.006;

use strict;
use warnings;

use Module::Build;

Module::Build->new(
    module_name => 'DateTime::Locale',
    dist_author => 'Dave Rolsky <autarch@urth.org>',
    license     => 'perl',
    requires    => {
        'List::MoreUtils'  => 0,
        'Params::Validate' => '0.91',
        perl               => 5.006,
    },
    build_requires     => { 'Module::Build' => 0 },
    sign               => 1,
    create_makefile_pl => 'traditional',
    meta_merge         => {
        resources => {
            homepage => 'http://datetime.perl.org/',
            bugtracker =>
                'http://rt.cpan.org/NoAuth/Bugs.html?Dist=DateTime-Locale',
            repository => 'http://hg.urth.org/hg/DateTime-Locale',
        },
    },
)->create_build_script;
