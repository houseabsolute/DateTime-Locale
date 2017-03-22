package DateTime::Locale::Util;

use strict;
use warnings;
use namespace::autoclean 0.19 -except => ['import'];

use Exporter qw( import );

our $VERSION = '1.17';

our @EXPORT_OK = 'parse_locale_code';

sub parse_locale_code {
    my @pieces = split /-/, $_[0];

    return unless @pieces;

    my %codes = ( language => lc shift @pieces );
    if ( @pieces == 1 ) {
        if ( length $pieces[0] == 2 || $pieces[0] =~ /^\d\d\d$/ ) {
            $codes{territory} = uc shift @pieces;
        }
        else {
            $codes{script} = _tc( shift @pieces );
        }
    }
    elsif ( @pieces == 3 ) {
        $codes{script}    = _tc( shift @pieces );
        $codes{territory} = uc shift @pieces;
        $codes{variant}   = uc shift @pieces;
    }
    elsif ( @pieces == 2 ) {

        # I don't think it's possible to have a script + variant without also
        # having a territory.
        if ( length $pieces[1] == 2 || $pieces[1] =~ /^\d\d\d$/ ) {
            $codes{script}    = _tc( shift @pieces );
            $codes{territory} = uc shift @pieces;
        }
        else {
            $codes{territory} = uc shift @pieces;
            $codes{variant}   = uc shift @pieces;
        }
    }

    return %codes;
}

sub _tc {
    return ucfirst lc $_[0];
}

1;

# ABSTRACT: Utility code for DateTime::Locale

__END__

=pod

=encoding UTF-8

=head1 DESCRIPTION

There are no user-facing parts in this module.

=cut
