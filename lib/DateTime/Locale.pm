package DateTime::Locale;

use strict;

use DateTime::LocaleCatalog;

use Params::Validate qw( validate validate_pos SCALAR );

use vars qw($VERSION);

$VERSION = 0.04;

BEGIN
{
    return unless $] >= 5.006;

    require utf8; import utf8;
}

my %Class;
my %DataForID;
my %NameToID;
my %NativeNameToID;
my %AliasToID;
my %IDToExtra;

my %LoadCache;

sub register
{
    shift;

    %LoadCache = ();

    foreach my $l ( ref $_[0] ? @{ $_[0] } : $_[0] )
    {
        my @p = %$l;
        my %p = validate( @p, { id               => { type => SCALAR },

                                en_language      => { type => SCALAR },
                                en_territory     => { type => SCALAR, optional => 1 },
                                en_variant       => { type => SCALAR, optional => 1 },

                                native_language  => { type => SCALAR, optional => 1 },
                                native_territory => { type => SCALAR, optional => 1 },
                                native_variant   => { type => SCALAR, optional => 1 },
                                # undocumented hack so we don't have
                                # to generate .pm files for ICU XML
                                # locales which don't differ from
                                # their parents in terms of datetime
                                # data.
                                real_class       => { type => SCALAR, optional => 1 },
                                class            => { type => SCALAR, optional => 1 },
                                replace          => { type => SCALAR, default => 0 },
                              } );

        my $id = $p{id};

        die "'\@' or '=' are not allowed in locale ids"
            if $id =~ /[\@=]/;
        die "You cannot replace an existing locale ('$id') unless you also specify the 'replace' parameter as true\n"
            if ! delete $l->{replace} && exists $DataForID{$id};

        $l->{native_language} = $l->{en_language}
            unless exists $l->{native_language};

        my @en_pieces;
        my @native_pieces;
        foreach my $p ( qw( language territory variant ) )
        {
            push @en_pieces, $l->{"en_$p"} if exists $l->{"en_$p"};
            push @native_pieces, $l->{"native_$p"} if exists $l->{"native_$p"};
        }

        $l->{en_complete_name} = join ' ', @en_pieces;
        $l->{native_complete_name} = join ' ', @native_pieces;

        $DataForID{$id} = $l;

        $NameToID{ $l->{en_complete_name} } = $id;
        $NativeNameToID{ $l->{native_complete_name} } = $id;

        $Class{$id} = $l->{class} if defined exists $l->{class};
    }
}

sub registered_id
{
    shift;
    my ($id) = validate_pos( @_, { type => SCALAR } );

    return 1 if $AliasToID{$id};
    return 1 if $DataForID{$id};

    return 0;
}

sub add_aliases
{
    shift;

    %LoadCache = ();

    my $aliases = ref $_[0] ? $_[0] : {@_};

    while ( my ( $alias, $id ) = each %$aliases )
    {
        die "Unregistered locale '$id' cannot be used as an alias target for $alias"
            unless __PACKAGE__->registered_id($id);

        die "Can't alias an id to itself"
            if $alias eq $id;

        # check for overwrite?

        my %seen = ( $alias => 1, $id => 1 );
        my $copy = $id;
        while ( $copy = $AliasToID{$copy} )
        {
            die "Creating an alias from $alias to $id would create a loop.\n"
                if $seen{$copy};

            $seen{$copy} = 1;
        }

        $AliasToID{$alias} = $id;
    }
}

sub remove_alias
{
    shift;

    %LoadCache = ();

    my ($alias) = validate_pos( @_, { type => SCALAR } );

    return delete $AliasToID{$alias};
}

BEGIN
{
    __PACKAGE__->register( \@DateTime::Locale::Locales );
    __PACKAGE__->add_aliases( \%DateTime::Locale::Aliases );
}

sub ids              { wantarray ? keys %DataForID       : [ keys %DataForID      ] }
sub names            { wantarray ? keys %NameToID        : [ keys %NameToID       ] }
sub native_names     { wantarray ? keys %NativeNameToID  : [ keys %NativeNameToID ] }

# These are hardcoded for backwards comaptibility with the
# DateTime::Language code.
my %OldAliases =
    ( #'Afar'              => undef, # XXX
     'Amharic'           => 'am_ET',
     'Austrian'          => 'de_AT',
     'Brazilian'         => 'pt_BR',
     'Czech'             => 'cs_CZ',
     'Danish'            => 'da_DK',
     'Dutch'             => 'nl_NL',
     'English'           => 'en_US',
     'French'            => 'fr_FR',
     #      'Gedeo'             => undef, # XXX
     'German'            => 'de_DE',
     'Italian'           => 'it_IT',
     'Norwegian'         => 'no_NO',
     'Oromo'             => 'om_ET', # Maybe om_KE or plain om ?
     'Portugese'         => 'pt_PT',
     #      'Sidama'            => undef, # XXX
     'Somali'            => 'so_SO',
     'Spanish'           => 'es_ES',
     'Swedish'           => 'sv_SE',
     #      'Tigre'             => undef, # XXX
     'TigrinyaEthiopian' => 'ti_ET',
     'TigrinyaEritrean'  => 'ti_ER',
    );

sub load
{
    my $class = shift;
    my $name = shift;

    my $key = $name;

    return $LoadCache{$key} if exists $LoadCache{$key};

    # Custom class registered by user
    if ( $Class{$name} )
    {
        return $LoadCache{$key} = $Class{$name}->new;
    }

    # special case for backwards compatibility with DT::Language
    $name = $OldAliases{$name} if exists $OldAliases{$name};

    if ( exists $DataForID{$name} || exists $AliasToID{$name} )
    {
        return $LoadCache{$key} = $class->_load_class_from_id($name);
    }

    foreach my $h ( \%NameToID, \%NativeNameToID )
    {
        return $LoadCache{$key} = $class->_load_class_from_id( $h->{$name} )
            if exists $h->{$name};
    }

    if ( my $id = $class->_guess_id($name) )
    {
        return $LoadCache{$key} = $class->_load_from_id($id);
    }

    die "Invalid locale name or id: $name\n";
}

sub _guess_id
{
    my $class = shift;
    my $name = shift;

    # Strip off charset for LC_* ids : en_GB.UTF-8 etc
    $name =~ s/\..*$//;

    my ( $language, $territory, $variant ) = split /_/, $name;

    foreach my $id ( "\L$language\U$territory\U$variant",
                     "\L$language\U$territory",
                     lc $language
                   )
    {
        return $id
            if exists $DataForID{$id} || exists $AliasToID{$id};
    }
}

sub _load_class_from_id
{
    my $class = shift;
    my $id = shift;

    # We want the first alias for which there is data, even if it has
    # no corresponding .pm file.  There may be multiple levels of
    # alias to go through.
    my $data_id = $id;
    while ( exists $AliasToID{$data_id} && ! exists $DataForID{$data_id} )
    {
        $data_id = $AliasToID{$data_id};
    }

    my $data = $DataForID{$data_id};
    my $subclass = $data->{real_class} ? $data->{real_class} : $data_id;

    my $real_class = "DateTime::Locale::$subclass";

    eval "require $real_class";

    die $@ if $@;

    return $real_class->new( %$data,
                             id => $id,
                           );
}

1;

__END__

=head1 NAME

DateTime::Locale - Localization support for DateTime

=head1 SYNOPSIS

  use DateTime::Locale;

  my $loc = DateTime::Locale->load('en_GB');

  print $loc->native_locale_name,    "\n",
	$loc->long_datetime_format, "\n";

  # but mostly just things like ...

  my $dt = DateTime->now( locale => 'fr' );
  print "Aujord'hui le mois est " . $dt->month_name, "\n":

=head1 DESCRIPTION

DateTime::Locale is primarily a factory for the various locale
subclasses.  It also provides some functions for getting information
on available locales.

If you want to know what methods are available for locale objects,
then please read the C<DateTime::Locale::Base> documentation.

=head1 USAGE

This module provides the following class methods:

=over 4

=item * load( $locale_id | $locale_name | $alias )

Returns the locale object for the specified locale id, name, or alias
- see the C<DateTime::LocaleCatalog> documentation for a list of built
in names and ids.  The name provided may be either the English or
native name.

If the requested locale is not found, a fallback search takes place to
find a suitable replacement.

The fallback search order is:

  language_territory_variant
  language_territory
  language

Eg. For locale C<es_XX_UNKNOWN> the fallback search would be:

  es_XX_UNKNOWN   # Fails - no such locale
  es_XX           # Fails - no such locale
  es              # Found - the es locale is returned as the
                  # closest match to the requested id

If no suitable replacement is found, then an exception is thrown.

Please note that if you provide an B<id> to this method, then the
returned locale object's C<id()> method will B<always> return the
value you gave, even if that value was an alias to some other id.

This is done for forwards compatibility, in case something that is
currently an alias becomes a unique locale in the future.

This means that the value of C<id()> and the object's class may not
match.

The loaded locale is cached, so that B<locale objects may be
singletons>.  Calling C<register()>, C<add_aliases()>,
or C<remove_alias()> clears the cache.

=item * ids

  my @ids = DateTime::Locale->ids;
  my $ids = DateTime::Locale->ids;

Returns an unsorted list of the available locale ids, or an array
reference if called in a scalar context.  This list does not include
aliases.

=item * names

  my @names = DateTime::Locale->names;
  my $names = DateTime::Locale->names;

Returns an unsorted list of the available locale names in English, or
an array reference if called in a scalar context.

=item * native_names

  my @names = DateTime::Locale->native_names;
  my $names = DateTime::Locale->native_names;

Returns an unsorted list of the available locale names in their native
language, or an array reference if called in a scalar context. All
native names are utf8 encoded.

B<NB>: Many locales are only partially translated, so some native
locale names may still contain some English.

=item * add_aliases ( $alias1 => $id1, $alias2 => $id2, ... )

Adds an alias to an existing locale id. This allows a locale to be
C<load()>ed by its alias rather than id or name. Multiple aliases are
allowed.

If the passed locale id is neither registered nor listed in
L</AVAILABLE LOCALES>, an exception is thrown.

 DateTime::Locale->add_aliases( LastResort => 'es_ES' );

 # Equivalent to DateTime::Locale->load('es_ES');
 DateTime::Locale->load('LastResort');

You can also pass a hash reference to this method.

 DateTime::Locale->add_aliases( { Default     => 'en_GB',
                                  Alternative => 'en_US',
                                  LastResort  => 'es_ES' } );

=item * remove_alias( $alias )

Removes a locale id alias, and returns true if the specified alias
actually existed.

 DateTime::Locale->add_aliases( LastResort => 'es_ES' );

 # Equivalent to DateTime::Locale->load('es_ES');
 DateTime::Locale->load('LastResort');

 DateTime::Locale->remove_alias('LastResort');

 # Throws an exception, 'LastResort' no longer exists
 DateTime::Locale->load('LastResort');

=item * register( { ... }, { ... } )

This method allows you to register custom locales with the module.  A
locale is specified as a hash reference, and you may register multiple
locales at once, by passing an array of hash references.

Until registered, custom locales cannot be instantiated via C<load()>
and will not be returned by querying methods such as C<ids()> or
C<names()>.

 register( { id               => $locale_id,
             en_language      => ..., # something like 'English' or 'Afar',

             # All other keys are optional.  These are:
             en_territory => ...,
             en_variant   => ...,

             native_language  => ...,
             native_territory => ...,
             native_variant   => ...,

             # Optional - defaults to DateTime::Locale::$locale_id
             class                => $class_name,

             replace          => $boolean
           },
         )

The locale id and English name are required, and the following formats
should used wherever possible:

 id:   languageId[_territoryId[_variantId]]

 Where:  languageId = Lower case ISO  639 code -
          Always choose 639-1 over 639-2 where possible.

 territoryId = Upper case ISO 3166 code -
               Always choose 3166-1 over 3166-2 where possible.

 variantId = Upper case variant id -
             Basically anything you want, since this is typically the
             component that uniquely identifies a custom locale.

You cannot not use '@' or '=' in locale ids - these are reserved for
future use.  The underscore (_) is the component separator, and should
not be used for any other purpose.

If the "native_*" components are supplied, they must be utf8 encoded
and follow:

If omitted, the native name is assumed to be identical to the English
name.

If class is supplied, it must be the full module name of your custom
locale. If omitted, the locale module is assumed to be a
DateTime::Locale subclass.

Examples:

 DateTime::Locale->register
     ( { id => 'en_GB_RIDAS',
         en_language  => 'English',
         en_territory => 'United Kingdom',
         en_variant   => 'Ridas Custom Locale',
       },
     );

 # Returns instance of class DateTime::Locale::en_GB_RIDAS
 my $l = DateTime::Locale->load('en_GB_RIDAS');

 DateTime::Locale->register
     ( { id => 'hu_HU',
         en_language  => 'Hungarian',
         en_territory => Hungary',
         native_language  => 'Magyar',
         native_territory => 'Magyarország',
       },
     );

 # Returns instance of class DateTime::Locale::hu_HU
 my $l = DateTime::Locale->load('hu_HU');

 DateTime::Locale->register
     ( { id    => 'en_GB_RIDAS',
         name  => 'English United Kingdom Ridas custom locale',
         class => 'Ridas::Locales::CustomGB',
       },
     );

 # Returns instance of class Ridas::Locales::CustomGB
 # NOT Ridas::Locales::Custom::en_GB_RIDAS !
 my $l = DateTime::Locale->load('en_GB_RIDAS');

If you a locale for that id already exists, you must specify the
"replace" parameter as true, or an exception will be thrown.

The complete name for a registered locale is generated by joining
together the language, territory, and variant components with a single
space.

This means that in the first example, the complete English and native
names for the locale would be "English United Kingdom Ridas Custom
Locale", and in the second example the complete English name is
"Hungarian Hungary", while the complete native name is "Magyar
Magyarország".  The locale will be loadable by these complete names
(English and native), via the C<load()> method.

=back

=head1 ADDING CUSTOM LOCALES

These are added in one of two ways:

=over 4

=item 1.

Subclass an existing locale implementing only the changes you require.

=item 2.

Create a completely new locale.

=back

In either case the locale MUST be registered before use.

=head2 Subclass an existing locale.

The following example sublasses the United Kingdom English locale to
provide different date/time formats:

  package Ridas::Locale::en_GB_RIDAS1;

  use strict;
  use DateTime::Locale::en_GB;

  @Ridas::Locale::en_GB_RIDAS1::ISA = qw ( DateTime::Locale::en_GB );

  my $locale_id = 'en_GB_RIDAS1';

  my $date_formats =
  [
    "%A %{day} %B %{ce_year}",
    "%{day} %B %{ce_year}",
    "%{day} %b %{ce_year}",
    "%{day}/%m/%y",
  ];

  my $time_formats =
  [
    "%H h  %{minute} %{time_zone_short_name}",
    "%{hour12}:%M:%S %p",
    "%{hour12}:%M:%S %p",
    "%{hour12}:%M %p",
  ];

  sub date_formats { $date_formats }
  sub time_formats { $time_formats }

  1;

Now register it:

 DateTime::Locale->register
     ( id       => 'en_GB_RIDAS1',

       # name, territory, and variant as described in register() documentation

       class => 'Ridas::Locale::en_GB_RIDAS1' );

=head2 Creating a completely new locale

A completely new custom locale must implement the following methods:

  id
  month_names
  month_abbreviations
  day_names
  day_abbreviations
  am_pms
  eras
  date_formats
  time_formats
  datetime_format_pattern_order
  date_parts_order
  _default_date_format_length
  _default_time_format_length

See C<DateTime::Locale::Base> for a description of each method, and
take a look at F<DateTime/Locale/root.pm> for an example of a complete
implementation.

You are, of course, free to subclass C<DateTime::Locale::Base> if you
want to, though this is not required.

Once created, remember to register it!

Of course, you can always do the registration in the module itself,
and simply load it before using it.

=head1 SUPPORT

Please be aware that all locale data has been generated from the
Common XML Locale Repository project locales (originally ICU locale
data).  The data B<is> currently incomplete, and B<will> contain
errors in some locales.

When reporting errors in data, please check the primary data sources
first, then where necessary report errors directly to the primary
source:

  Common XML Locale Repository/ICU:  fsg.openi18n.locale.user newsgroup

Once these errors have been confirmed, please forward the error
report, and corrections to DateTime.

Support for this module is provided via the datetime@perl.org email
list. See http://lists.perl.org/ for more details.

=head1 AUTHORS

Richard Evans <rich@ridas.com>

Dave Rolsky <autarch@urth.org>

These modules are based on the DateTime::Language modules, which were
in turn based on the Date::Language modules from Graham Barr's
TimeDate distribution.

Thanks to Rick Measham for providing the Java to strftime pattern
conversion routines used during locale generation.

=head1 COPYRIGHT

Copyright (c) 2003 Richard Evans. All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included
with this module.

The locale modules in directory C<DateTime/Locale/> have been
generated from data provided by the Common XML Locale Repository
project, see C<DateTime/Locale/LICENSE.icu> for details on the ICU
data's license.

=head1 SEE ALSO

L<DateTime::Locale::Base>

datetime@perl.org mailing list

http://datetime.perl.org/

=cut

