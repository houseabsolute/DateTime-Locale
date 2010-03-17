package    # don't want this indexed by PAUSE
    LDML;

use 5.010;

use strict;
use warnings;
use utf8;

use Carp ();
use Data::Dumper;
use Lingua::EN::Inflect qw( PL_N );
use List::AllUtils qw( all first );
use Path::Class;
use Storable qw( nstore_fd fd_retrieve );
use XML::LibXML;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::ClassAttribute;

has 'id' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'source_file' => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 1,
);

has 'document' => (
    is       => 'ro',
    isa      => 'XML::LibXML::Document',
    required => 1,
);

has 'version' => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

has 'generation_date' => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

has 'language' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { ( $_[0]->_parse_id() )[0] },
);

has 'script' => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    lazy    => 1,
    default => sub { ( $_[0]->_parse_id() )[1] },
);

has 'territory' => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    lazy    => 1,
    default => sub { ( $_[0]->_parse_id() )[2] },
);

has 'variant' => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    lazy    => 1,
    default => sub { ( $_[0]->_parse_id() )[3] },
);

has 'alias_to' => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    lazy    => 1,
    builder => '_build_alias_to',
);

has '_parent_ids' => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    lazy    => 1,
    builder => '_build_parent_ids',
);

class_type 'XML::LibXML::Node';
has '_calendar_node' => (
    is      => 'ro',
    isa     => 'Maybe[XML::LibXML::Node]',
    lazy    => 1,
    default => sub {
        $_[0]->_find_one_node(q{dates/calendars/calendar[@type='gregorian']});
    },
);

has 'has_calendar_data' => (
    is      => 'ro',
    isa     => 'Bool',
    lazy    => 1,
    default => sub { $_[0]->_calendar_node() ? 1 : 0 },
);

for my $thing (
    {
        name   => 'day',
        length => 7,
        order  => [qw( mon tue wed thu fri sat sun )],
    },
    {
        name   => 'month',
        length => 12,
        order  => [ 1 .. 12 ],
    },
    {
        name   => 'quarter',
        length => 4,
        order  => [ 1 .. 4 ],
    },
    ) {
    for my $context (qw( format stand_alone )) {
        for my $size (qw( wide abbreviated narrow )) {
            my $name = $thing->{name};

            my $attr = $name . q{_} . $context . q{_} . $size;
            has $attr => (
                is         => 'ro',
                isa        => 'ArrayRef',
                lazy_build => 1,
            );

            my $required_length = $thing->{length};

            ( my $xml_context = $context ) =~ s/_/-/g;
            my $path = (
                join '/',
                PL_N($name),
                $name . 'Context' . q{[@type='} . $xml_context . q{']},
                $name . 'Width' . q{[@type='} . $size . q{']},
                $name
            );

            my $builder = sub {
                my $self = shift;

                return [] unless $self->has_calendar_data();

                my $vals
                    = $self->_find_preferred_values(
                    ( scalar $self->_calendar_node()->findnodes($path) ),
                    'type',
                    $thing->{order},
                    );

                $self->_fill_from_parent( $attr, $vals, $thing->{length} )
                    unless @{$vals} == $thing->{length}
                        && all {defined} @{$vals};

                unless ( @{$vals} == $thing->{length}
                    && all {defined} @{$vals} ) {
                    warn
                        "Could not fill in all values for $attr from parents for "
                        . $self->id() . "\n";
                }

                return $vals;
            };

            __PACKAGE__->meta()->add_method( '_build_' . $attr => $builder );
        }
    }
}

# eras have a different name scheme for sizes than other data
# elements, go figure.
for my $size (
    [ wide        => 'Names' ],
    [ abbreviated => 'Abbr' ],
    [ narrow      => 'Narrow' ]
    ) {
    my $attr = 'era_' . $size->[0];

    has $attr => (
        is         => 'ro',
        isa        => 'ArrayRef',
        lazy_build => 1,
    );

    my $path = (
        join '/',
        'eras',
        'era' . $size->[1],
        'era',
    );

    my $builder = sub {
        my $self = shift;

        return [] unless $self->has_calendar_data();

        my $vals = $self->_find_preferred_values(
            ( scalar $self->_calendar_node()->findnodes($path) ),
            'type',
            [ 0, 1 ],
        );

        $self->_fill_from_parent( $attr, $vals, 2 )
            unless @{$vals} == 2 && all {defined} @{$vals};

        unless ( @{$vals} == 2 && all {defined} @{$vals} ) {
            warn "Could not fill in all values for $attr from parents for "
                . $self->id() . "\n";
        }

        return $vals;
    };

    __PACKAGE__->meta()->add_method( '_build_' . $attr => $builder );
}

for my $type (qw( date time )) {
    for my $length (qw( full long medium short )) {
        my $attr = $type . q{_format_} . $length;

        has $attr => (
            is         => 'ro',
            isa        => 'Maybe[Str]',
            lazy_build => 1,
        );

        my $path = (
            join '/',
            $type . 'Formats',
            $type . q{FormatLength[@type='} . $length . q{']},
            $type . 'Format',
            'pattern',
        );

        my $builder = sub {
            my $self = shift;

            return unless $self->has_calendar_data();

            return $self->_find_one_node_text(
                $path,
                $self->_calendar_node(),
            );
        };

        __PACKAGE__->meta()->add_method( '_build_' . $attr => $builder );
    }
}

has 'default_date_format_length' => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    lazy    => 1,
    default => sub {
        $_[0]->_find_one_node_attribute(
            'dateFormats/default',
            $_[0]->_calendar_node(),
            'choice'
        );
    },
);

has 'default_time_format_length' => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    lazy    => 1,
    default => sub {
        $_[0]->_find_one_node_attribute(
            'timeFormats/default',
            $_[0]->_calendar_node(),
            'choice'
        );
    },
);

has 'am_pm_abbreviated' => (
    is         => 'ro',
    isa        => 'ArrayRef',
    lazy_build => 1,
);

has 'datetime_format' => (
    is         => 'ro',
    isa        => 'Maybe[Str]',
    lazy_build => 1,
);

has '_available_formats' => (
    is         => 'ro',
    isa        => 'HashRef[Str]',
    lazy_build => 1,
);

has 'merged_available_formats' => (
    is         => 'ro',
    isa        => 'HashRef[Str]',
    lazy_build => 1,
);

has 'default_interval_format' => (
    is         => 'ro',
    isa        => 'Maybe[Str]',
    lazy_build => 1,
);

has 'interval_formats' => (
    is         => 'ro',
    isa        => 'HashRef[HashRef[Str]]',
    lazy_build => 1,
);

has '_field_names' => (
    is         => 'ro',
    isa        => 'HashRef[HashRef[Str]]',
    lazy_build => 1,
);

has 'merged_field_names' => (
    is         => 'ro',
    isa        => 'HashRef[HashRef[Str]]',
    lazy_build => 1,
);

# This is really only built once for all objects
has '_first_day_of_week_index' => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
);

has 'first_day_of_week' => (
    is         => 'ro',
    isa        => 'Int',
    lazy_build => 1,
);

for my $thing (qw( language script territory variant )) {
    {
        my $en_attr = q{en_} . $thing;

        has $en_attr => (
            is         => 'ro',
            isa        => 'Maybe[Str]',
            lazy_build => 1,
        );

        my $en_ldml;
        my $builder = sub {
            my $self = shift;

            my $val_from_id = $self->$thing();
            return unless defined $val_from_id;

            $en_ldml
                ||= ( ref $self )
                ->new_from_file(
                $self->source_file()->dir()->file('en.xml') );

            my $path
                = 'localeDisplayNames/'
                . PL_N($thing) . q{/}
                . $thing
                . q{[@type='}
                . $self->$thing() . q{']};

            return $en_ldml->_find_one_node_text($path);
        };

        __PACKAGE__->meta()->add_method( '_build_' . $en_attr => $builder );
    }

    {
        my $native_attr = q{native_} . $thing;

        has $native_attr => (
            is         => 'ro',
            isa        => 'Maybe[Str]',
            lazy_build => 1,
        );

        my $builder = sub {
            my $self = shift;

            my $val_from_id = $self->$thing();
            return unless defined $val_from_id;

            my $path
                = 'localeDisplayNames/'
                . PL_N($thing) . q{/}
                . $thing
                . q{[@type='}
                . $self->$thing() . q{']};

            for my $ldml ( $self->_self_and_ancestors() ) {
                my $native_val = $ldml->_find_one_node_text($path);

                return $native_val if defined $native_val;
            }

            return;
        };

        __PACKAGE__->meta()
            ->add_method( '_build_' . $native_attr => $builder );
    }
}

sub _build_alias_to {
    my $self = shift;

    my $source = $self->_find_one_node_attribute( 'alias', 'source' );
    return $source if defined $source;

    return;
}

sub parent_ids {
    @{ $_[0]->_parent_ids() };
}

sub _self_and_ancestors {
    my $self = shift;

    return $self, $self->_all_parents();
}

sub _all_parents {
    my $self = shift;

    return map { $_, $_->_all_parents() } $self->_parents();
}

sub _parents {
    my $self = shift;

    return map { $self->_maybe_load($_) } @{ $self->_parent_ids() };
}

sub _maybe_load {
    my $self = shift;
    my $id   = shift;

    my $file = $self->source_file()->dir()->file( $id . '.xml' );

    return unless -f $file;

    return ( ref $self )->new_from_file($file);
}

sub _build_parent_ids {
    my $self = shift;

    my @fallback;
    if ( my $fb = $self->_find_one_node_text('fallback') ) {
        @fallback = split /\s+/, $fb;
    }

    # This is always one id, but if it doesn't exist we want an empty list
    # rather than undef.
    my @implicit = $self->_implicit_parent_id();

    if ( @implicit && $implicit[0] eq 'root' ) {
        return [ @fallback, @implicit ];
    }
    else {
        return [ @implicit, @fallback ];
    }
}

sub _implicit_parent_id {
    my $self = shift;

    my @parts = (
        grep {defined} $self->language(),
        $self->script(),
        $self->territory(),
        $self->variant(),
    );

    pop @parts;

    if (@parts) {
        return join '_', @parts;
    }
    else {
        return if $self->id() eq 'root';
        return 'root';
    }
}

{
    my %Cache;

    sub new_from_file {
        my $class = shift;
        my $file  = file(shift);

        my $id = $file->basename();
        $id =~ s/\.xml$//i;

        return $Cache{$id}
            if $Cache{$id};

        my $doc = $class->_resolve_document_aliases($file);

        return $Cache{$id} = $class->new(
            id          => $id,
            source_file => $file,
            document    => $doc,
        );
    }
}

{
    my $Parser = XML::LibXML->new();
    $Parser->load_catalog('/etc/xml/catalog.xml');
    $Parser->load_ext_dtd(0);

    my %Cache;
    sub _resolve_document_aliases {
        my $class = shift;
        my $file  = shift;

        return $Cache{$file} if exists $Cache{$file};

        my $doc = $Parser->parse_file( $file->stringify() );

        $class->_resolve_aliases_in_node( $doc->documentElement(), $file );

        return $Cache{$file} = $doc;
    }
}

sub _resolve_aliases_in_node {
    my $class = shift;
    my $node  = shift;
    my $file  = shift;

 ALIAS:
    for my $node ( $node->getElementsByTagName('alias') ) {

        # Replacing all the aliases is slow, and we really don't care about
        # most of the data in the file, just the localeDisplayNames and the
        # gregorian calendar.
        #
        # We also end up skipping the case where the entire locale is an alias
        # to some other locale. This is handled in the generated Perl code.
        for ( my $p = $node->parentNode(); $p; $p = $p->parentNode() ) {
            if ( $p->nodeName() eq 'calendar' ) {
                if ( $p->getAttribute('type') eq 'gregorian' ) {
                    last;
                }
                else {
                    next ALIAS;
                }
            }

            last if $p->nodeName() eq 'localeDisplayNames';

            next ALIAS if $p->nodeName() eq 'ldml';
            next ALIAS if $p->nodeName() eq '#document';
        }

        $class->_resolve_alias( $node, $file );
    }
}

sub _resolve_alias {
    my $class = shift;
    my $node  = shift;
    my $file  = shift;

    my $source = $node->getAttribute('source')
        or die "Alias with no source in $file";

    if ( $source eq 'locale' ) {
        $class->_resolve_local_alias( $node, $file );
    }
    else {
        $class->_resolve_remote_alias( $node, $file );
    }
}

sub _resolve_local_alias {
    my $class = shift;
    my $node  = shift;
    my $file  = shift;

    my $path = $node->getAttribute('path');

    # The path resolves from the context of the parent node, not the
    # current node. Why? Why not?
    $class->_replace_alias_with_path( $node, $path, $node->parentNode(),
        $file );
}

sub _resolve_remote_alias {
    my $class = shift;
    my $node  = shift;
    my $file  = shift;

    my $source      = $node->getAttribute('source');
    my $target_file = $file->dir()->file( $source . q{.xml} );

    my $doc = $class->_resolve_document_aliases($target_file);

    # I'm not sure nodePath() will work, since it seems to return an
    # array-based index like /ldml/dates/calendars/calendar[4]. I'm
    # not sure if LDML allows this, but the target file might contain
    # a different ordering or may just be missing something. This
    # whole alias thing is madness.
    #
    # However, remote aliases seem to be a rare case outside of an
    # alias for the entire file, so they can be investigated as
    # needed.
    my $path = $node->getAttribute('path') || $node->parentNode()->nodePath();

    $class->_replace_alias_with_path( $node, $path, $doc, $target_file );
}

sub _replace_alias_with_path {
    my $class   = shift;
    my $node    = shift;
    my $path    = shift;
    my $context = shift;
    my $file    = shift;

    my @targets = $context->findnodes($path);

    my $line = $node->line_number();
    die "Path ($path) resolves to multiple nodes in $file (line $line)"
        if @targets > 1;

    die "Path ($path) does not resolve to any node in $file (line $line)"
        if @targets == 0;

    my $parent = $node->parentNode();

    $parent->removeChildNodes();
    $parent->appendChild( $_->cloneNode(1) ) for $targets[0]->childNodes();

    # This means the same things get resolved multiple times, but it's
    # pretty fast with LibXML, and simpler to code than something more
    # efficient.
    $class->_resolve_aliases_in_node( $parent, $file );
}

sub BUILD {
    my $self = shift;

    my $meth = q{_} . $self->id() . q{_hack};

    # This gives us a chance to apply bug fixes to the data as needed.
    $self->$meth()
        if $self->can($meth);

    return $self;
}

sub _gaa_hack {
    my $self = shift;
    my $data = shift;

    my $path
        = q{days/dayContext[@type='format']/dayWidth[@type='abbreviated']/day[@type='sun']};

    my $day_text
        = $self->_find_one_node_text( $path, $self->_calendar_node() );

    return unless $day_text eq 'Ho';

    # I am completely making this up, but the data is marked as
    # unconfirmed in the locale file and making something up is
    # preferable to having two days with the same abbreviation

    my $day = $self->_find_one_node( $path, $self->_calendar_node() );

    $day->removeChildNodes();
    $day->appendChild( $self->document()->createTextNode('Hog') );
}

sub _ve_hack {
    my $self = shift;
    my $data = shift;

    my $path
        = q{months/monthContext[@type='format']/monthWidth[@type='abbreviated']/month[@type='3']};

    my $day_text
        = $self->_find_one_node_text( $path, $self->_calendar_node() );

    return unless $day_text eq 'Ṱha';

    # Again, making stuff up to avoid non-unique abbreviations

    my $day = $self->_find_one_node( $path, $self->_calendar_node() );

    $day->removeChildNodes();
    $day->appendChild( $self->document()->createTextNode('Ṱhf') );
}

sub _build_version {
    my $self = shift;

    my $version
        = $self->_find_one_node_attribute( 'identity/version', 'number' );
    $version =~ s/^\$Revision:\s+//;
    $version =~ s/\s+\$$//;

    return $version;
}

sub _build_generation_date {
    my $self = shift;

    my $date
        = $self->_find_one_node_attribute( 'identity/generation', 'date' );
    $date =~ s/^\$Date:\s+//;
    $date =~ s/\s+\$$//;

    return $date;
}

sub _parse_id {
    my $self = shift;

    return $self->id() =~ /([a-z]+)               # language
                           (?: _([A-Z][a-z]+) )?  # script - Title Case - optional
                           (?: _([A-Z]+) )?       # territory - ALL CAPS - optional
                           (?: _([A-Z]+) )?       # variant - ALL CAPS - optional
                          /x;
}

sub _build_am_pm_abbreviated {
    my $self = shift;

    my $am = $self->_find_one_node_text( 'am', $self->_calendar_node() );
    my $pm = $self->_find_one_node_text( 'pm', $self->_calendar_node() );

    return [] unless defined $am && defined $pm;

    return [ $am, $pm ];
}

sub _build_datetime_format {
    my $self = shift;

    return $self->_find_one_node_text(
        'dateTimeFormats/dateTimeFormatLength/dateTimeFormat/pattern',
        $self->_calendar_node()
    );
}

sub _build__available_formats {
    my $self = shift;

    return {} unless $self->has_calendar_data();

    my @nodes = $self->_calendar_node()
        ->findnodes('dateTimeFormats/availableFormats/dateFormatItem');

    my %index;
    for my $node (@nodes) {
        push @{ $index{ $node->getAttribute('id') } }, $node;
    }

    my %formats;
    for my $id ( keys %index ) {
        my $preferred = $self->_find_preferred_node( @{ $index{$id} } )
            or next;

        $formats{$id} = join '', map { $_->data() } $preferred->childNodes();
    }

    return \%formats;
}

sub _build_merged_available_formats {
    my $self = shift;

    my %merged_formats;

    for my $ldml ( $self->_self_and_ancestors ) {
        %merged_formats = (
            %{ $ldml->_available_formats() },
            %merged_formats,
        );
    }

    return \%merged_formats;
}

sub _build_default_interval_format {
    my $self = shift;

    return $self->_find_one_node_text(
        'dateTimeFormats/intervalFormats/intervalFormatFallback',
        $self->_calendar_node()
    );
}

sub _build_interval_formats {
    my $self = shift;

    return {} unless $self->has_calendar_data();

    my @ifi_nodes = $self->_calendar_node()
        ->findnodes('dateTimeFormats/intervalFormats/intervalFormatItem');

    my %index;
    for my $ifi_node (@ifi_nodes) {
        for my $gd_node ( $ifi_node->findnodes('greatestDifference') ) {
            push @{ $index{ $ifi_node->getAttribute('id') }
                    { $gd_node->getAttribute('id') } }, $gd_node;
        }
    }

    my %formats;
    for my $ifi_id ( keys %index ) {
        for my $gd_id ( keys %{ $index{$ifi_id} } ) {
            my $preferred
                = $self->_find_preferred_node( @{ $index{$ifi_id}{$gd_id} } )
                or next;

            $formats{$ifi_id}{$gd_id} = join '',
                map { $_->data() } $preferred->childNodes();
        }
    }

    return \%formats;
}

sub _build__field_names {
    my $self = shift;

    return {} unless $self->has_calendar_data();

    my @fields = $self->_calendar_node()->findnodes('fields/field');

    my %names;
    for my $field (@fields) {
        my $key = $field->getAttribute('type');

        if ( my $text = $self->_find_one_node_text( 'displayName', $field ) )
        {
            $names{$key}{name} = $text;
        }

        for my $node ( $field->findnodes('relative') ) {
            next if $node->getAttribute('draft');

            $names{$key}{ $node->getAttribute('type') } = join '',
                map { $_->data() } $node->childNodes();
        }
    }

    return \%names;
}

sub _build_merged_field_names {
    my $self = shift;

    my %merged_names;

    for my $ldml ( $self->_self_and_ancestors ) {
        my $names = $ldml->_field_names();

        for my $field ( keys %{$names} ) {
            %{ $merged_names{$field} } = (
                %{ $names->{$field} },
                %{ $merged_names{$field} || {} },
            );
        }
    }

    return \%merged_names;
}

sub _build_first_day_of_week {
    my $self = shift;

    my $terr = $self->territory();
    return 1 unless defined $terr;

    my $index = $self->_first_day_of_week_index();

    return $index->{$terr} || 1;
}

sub _find_preferred_values {
    my $self  = shift;
    my $nodes = shift;
    my $attr  = shift;
    my $order = shift;

    my @nodes = $nodes->get_nodelist();

    return [] unless @nodes;

    my %index;

    for my $node (@nodes) {
        push @{ $index{ $node->getAttribute($attr) } }, $node;
    }

    my @preferred;
    for my $i ( 0 .. $#{$order} ) {

        my $attr = $order->[$i];

        # There may be nothing in the index for incomplete sets (of
        # days, months, etc)
        my @matches = @{ $index{$attr} || [] };

        my $preferred = $self->_find_preferred_node(@matches)
            or next;

        $preferred[$i] = join '', map { $_->data() } $preferred->childNodes();
    }

    return \@preferred;
}

sub _find_preferred_node {
    my $self  = shift;
    my @nodes = @_;

    return unless @nodes;

    return $nodes[0] if @nodes == 1;

    my $non_draft = first { !$_->getAttribute('draft') } @nodes;

    return $non_draft if $non_draft;

    return $nodes[0];
}

sub _find_one_node_text {
    my $self = shift;

    my $node = $self->_find_one_node(@_);

    return unless $node;

    return join '', map { $_->data() } $node->childNodes();
}

sub _find_one_node_attribute {
    my $self = shift;

    # attr name will always be last
    my $attr = pop;

    my $node = $self->_find_one_node(@_);

    return unless $node;

    return $node->getAttribute($attr);
}

sub _find_one_node {
    my $self    = shift;
    my $path    = shift;
    my $context = shift;

    unless ($context) {
        $context = $self->document()->documentElement()
            or Carp::confess("No document element!");
    }

    return unless $context;

    my @nodes = $self->_find_preferred_node( $context->findnodes($path) );

    if ( @nodes > 1 ) {
        my $context_path = $context->nodePath();

        die "Found multiple nodes for $path under $context_path";
    }

    return $nodes[0];
}

sub _fill_from_parent {
    my $self   = shift;
    my $attr   = shift;
    my $vals   = shift;
    my $length = shift;

    for my $parent ( $self->_all_parents() ) {
        my $parent_vals = $parent->$attr();

        for my $i ( 0 .. $length - 1 ) {
            $vals->[$i] //= $parent_vals->[$i];
        }

        return if @{$vals} == $length;
    }
}

{
    my %days = do {
        my $x = 1;
        map { $_ => $x++ } qw( mon tue wed thu fri sat sun );
    };

    my %index;

    my $file_name = 'supplementalData.xml';

    sub _build__first_day_of_week_index {
        return \%index
            if keys %index;

        my $self = shift;

        my $file;
        for my $dir (
            $self->source_file()->dir(),
            $self->source_file()->dir()->parent()->subdir('supplemental'),
            ) {
            $file = $dir->file($file_name);

            last if -f $file;
        }

        die "Cannot find $file_name"
            unless -f $file;

        my $doc = XML::LibXML->new()->parse_file( $file->stringify() );

        my @nodes = $doc->findnodes('supplementalData/weekData/firstDay');

        for my $node (@nodes) {
            my $day_num = $days{ $node->getAttribute('day') };

            $index{$_} = $day_num
                for split /\s+/, $node->getAttribute('territories');
        }

        return \%index;
    }
}

__PACKAGE__->meta()->make_immutable();
no Moose;
no Moose::Util::TypeConstraints;

1;
