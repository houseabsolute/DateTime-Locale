package DateTime::Locale::Base;

use strict;
use DateTime::Locale;

###########################################################################
# Subclasses must implement the following methods:

sub month_names;
sub month_abbreviations;
sub day_names;
sub day_abbreviations;
sub am_pms;
sub eras;
sub date_formats;
sub time_formats;
sub date_time_format_pattern_order;

###########################################################################

BEGIN
{
    foreach my $field ( qw( id en_complete_name native_complete_name
                            en_language en_territory en_variant
                            native_language native_territory native_variant
                          )
                      )
    {
        # remove leading 'en_' for method name
        (my $meth_name = $field) =~ s/^en_//;

        # also remove 'complete_'
        $meth_name =~ s/complete_//;

        no strict 'refs';
        *{$meth_name} = sub { $_[0]->{$field} };
    }
}

sub new { my $c = shift; bless { @_ }, $c }

sub language_id  { ( split /_/, $_[0]->id )[0] }
sub territory_id { ( split /_/, $_[0]->id )[1] }
sub variant_id   { ( split /_/, $_[0]->id )[2] }

sub month_name               { $_[0]->month_names->        [ $_[1]->month_0           ] }
sub month_abbreviation       { $_[0]->month_abbreviations->[ $_[1]->month_0           ] }
sub day_name                 { $_[0]->day_names->          [ $_[1]->day_of_week_0     ] }
sub day_abbreviation         { $_[0]->day_abbreviations->  [ $_[1]->day_of_week_0     ] }
sub am_pm                    { $_[0]->am_pms->             [ $_[1]->hour < 12 ? 0 : 1 ] }
sub era;                     # TBA

sub    full_date_format      { $_[0]->date_formats->[0] }
sub    long_date_format      { $_[0]->date_formats->[1] }
sub  medium_date_format      { $_[0]->date_formats->[2] }
sub   short_date_format      { $_[0]->date_formats->[3] }
sub default_date_format      { $_[0]->date_formats->[ DateTime::Locale->default_date_format_length ] }

sub    full_time_format      { $_[0]->time_formats->[0] }
sub    long_time_format      { $_[0]->time_formats->[1] }
sub  medium_time_format      { $_[0]->time_formats->[2] }
sub   short_time_format      { $_[0]->time_formats->[3] }
sub default_time_format      { $_[0]->time_formats->[ DateTime::Locale->default_time_format_length ] }

sub    full_datetime_format { join ' ', ( $_[0]->full_date_format, $_[0]->full_time_format )[@{$_[0]->date_time_format_pattern_order}] }
sub    long_datetime_format { join ' ', ( $_[0]->long_date_format, $_[0]->long_time_format )[@{$_[0]->date_time_format_pattern_order}] }
sub  medium_datetime_format { join ' ', ( $_[0]->medium_date_format, $_[0]->medium_time_format )[@{$_[0]->date_time_format_pattern_order}] }
sub   short_datetime_format { join ' ', ( $_[0]->short_date_format, $_[0]->short_time_format )[@{$_[0]->date_time_format_pattern_order}] }
sub default_datetime_format { join ' ', ( $_[0]->default_date_format, $_[0]->default_time_format )[@{$_[0]->date_time_format_pattern_order}] }

1;

