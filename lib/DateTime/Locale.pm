package DateTime::Locale;

use strict;

use DateTime::LocaleCatalog;

use Params::Validate qw( validate );

use vars qw($VERSION);

$VERSION = 0.01;

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

sub register
{
    shift;

    my $locales;

    if ( my $ref = ref $_[0] )
    {
        $locales =
            $ref eq "ARRAY" ? shift : die "Argument of ref type: $ref is invalid";
    }
    else
    {
        my %args = validate( @_, { id                   => 1,
                                   en_complete_name     => 1,
                                   native_complete_name => 0,
                                   class                => 0,
                                 } );

        $locales = [ \%args ];
    }

    foreach my $l (@$locales)
    {
        my $id = $l->{id};

        warn "WARNING: Use of reserved characters '\@' or '=' in id may cause compatibility problems with future releases"
            if $id =~ /[\@=]/;
        warn "WARNING: Existing locale '$id' ($DataForID{$id}->{en_complete_name}) has been replaced during registration\n"
            if exists $DataForID{$id};

        $DataForID{$id} = $l;
        $NameToID{ $l->{en_complete_name} } = $id;
        $NativeNameToID{ $l->{native_complete_name} } = $id;
        $Class{$id} = $l->{class} if defined exists $l->{class};
    }
}

sub registered_id
{
    my (undef, $id) = @_;

    return 1 if $AliasToID{$id};
    return 1 if $DataForID{$id};

    return 0;
}

sub add_aliases
{
    shift;

    while ( my ( $alias, $id ) = each %{ $_[0] } )
    {
        die "Unregistered locale '$id' cannot be used as an alias target for $alias"
            unless __PACKAGE__->registered_id($id);

        # check for overwrite?

        $AliasToID{$alias} = $id;
    }
}

sub remove_alias
{
    my (undef, $alias) = @_;

    die "Missing alias" unless $alias;

    warn "WARNING: Removed locale alias '$alias' was set as the default fallback locale\n"
        if $alias eq fallback_id();

    return defined delete $AliasToID{$alias};
}


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

__PACKAGE__->register( \@DateTime::Locale::Locales );
__PACKAGE__->add_aliases( \%DateTime::Locale::Aliases );

sub ids              { wantarray ? keys %DataForID       : [ keys %DataForID       ] }
sub names            { wantarray ? keys %NameToID        : [ keys %NameToID       ] }
sub native_names     { wantarray ? keys %NativeNameToID  : [ keys %NativeNameToID ] }

{
    use constant FORMAT_TYPES      => { F => 0,      L => 1,      M => 2,        S => 3       };
    use constant FORMAT_TYPE_NAMES => { 0 => "Full", 1 => "Long", 2 => "Medium", 3 => "Short" };

    my $Default_date_format = FORMAT_TYPES->{S};
    my $Default_time_format = FORMAT_TYPES->{S};

    sub default_date_format { shift; _default_format(\$Default_date_format, @_) }
    sub default_time_format { shift; _default_format(\$Default_time_format, @_) }

    sub _default_format
    {
        my $ref = shift;

        return $$ref unless @_;

        my ($format) = ( shift =~ /^(.)/ );

        die "Invalid format value" unless defined ($format = FORMAT_TYPES->{uc $format});

        return $$ref = $format;
    }

    sub format_type
    {
        shift;

        return "" unless @_;
        return FORMAT_TYPE_NAMES->{shift()} || "";
    }
}

{
    my %Cached;
    my $Fallback_id = "";

    sub fallback_id
    {
        shift;
        return $Fallback_id unless @_;

        my $fallback_id = shift || "";

        die "Unregistered locale '$fallback_id' cannot be used as a fallback id"
            if $fallback_id and not registered_id(undef, $fallback_id);

        $Fallback_id = $fallback_id;
    }


    sub load
    {
        my $class = shift;
        my $name = shift;

        # Custom class registered by user
        if ( $Class{$name} )
        {
            return $Class{$name}->new;
        }

        # special case for backwards compatibility with DT::Language
        $name = $OldAliases{$name} if exists $OldAliases{$name};

        if ( exists $DataForID{$name} )
        {
            return $class->_load_class_from_id($name);
        }

        foreach my $h ( \%NameToID, \%NativeNameToID )
        {
            return $class->_load_class_from_id( $h->{$name} )
                if exists $h->{$name};
        }

        # Strip off charset for LC_* ids : en_GB.UTF-8 etc
        $name =~ s/\..*$//;

        my ( $language, $territory, $variant ) = split /_/, $name;

        foreach my $id ( "\L$language\U$territory\U$variant",
                         "\L$language\U$territory",
                         lc $language
                       )
        {
            return $class->_load_class_from_id($id)
                if exists $DataForID{$id};
        }
    }
}

sub _load_class_from_id
{
    shift;
    my $id = shift;

    my $real_id = $AliasToID{$id} ? $AliasToID{$id} : $id;

    my $real_class = "DateTime::Locale::$real_id";

    eval "require $real_class";

    die $@ if $@;

    return $real_class->new( id => $id,
                             %{ $DataForID{$id} },
                           );
}

1;
