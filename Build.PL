use strict;

use Module::Build;


Module::Build->new( module_name => 'DateTime::Locale',
                    dist_author => 'Dave Rolsky <autarch@urth.org>',
                    license     => 'perl',
                    requires    => { 'Params::Validate' => 0,
                                   },
                    build_requires => { 'Module::Build' => 0 },
		    sign        => 1,
                    create_makefile_pl => 'traditional',
                  )->create_build_script;
