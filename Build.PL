use 5.006;

use strict;
use warnings;

use Module::Build;


Module::Build->new( module_name => 'DateTime::Locale',
                    dist_author => 'Dave Rolsky <autarch@urth.org>',
                    license     => 'perl',
                    requires    => { 'Class::ISA'       => 0,
                                     'List::MoreUtils'  => 0,
                                     'Params::Validate' => 0,
                                     perl               => 5.006,
                                   },
                    build_requires => { 'Module::Build' => 0 },
		    sign        => 1,
                    create_makefile_pl => 'traditional',
                  )->create_build_script;
