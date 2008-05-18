use strict;
use warnings;

use Test::More;

BEGIN
{
    plan skip_all => 'This test is only run for the module author'
        unless -d '.svn' || $ENV{IS_MAINTAINER};
}

use File::Find::Rule;
use Test::Pod::Coverage 1.04;


my $dir = -d 'blib' ? 'blib' : 'lib';

my @files = sort
            File::Find::Rule
                ->file
                ->name('*.pm')
                ->not( File::Find::Rule->grep('This file is auto-generated' ) )
                ->in($dir);

plan tests => scalar @files;

for my $file (@files)
{
    $file =~ s/^.+(DateTime.+)\.pm$/$1/;
    $file =~ s{/}{::}g;

    pod_coverage_ok( $file, { trustme => [ qr/^STORABLE_/ ] } );
}
