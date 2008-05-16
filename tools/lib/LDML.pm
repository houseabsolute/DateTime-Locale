package # don't want this indexed by PAUSE
    LDML;

use strict;
use warnings;
use utf8;

use Data::Dumper;
use Lingua::EN::Inflect qw( PL_N );
use List::Util qw( first );
use Path::Class;
use XML::LibXML;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::ClassAttribute;

has 'id' =>
    ( is       => 'ro',
      isa      => 'Str',
      required => 1,
    );

has 'source_file' =>
    ( is       => 'ro',
      isa      => 'Path::Class::File',
      required => 1,
    );

has 'document' =>
    ( is       => 'ro',
      isa      => 'XML::LibXML::Document',
      required => 1,
    );

class_has 'Aliases' =>
    ( is      => 'ro',
      isa     => 'HashRef',
      lazy    => 1,
      default => sub { return { 'C'             => 'en_US_POSIX',
                                'POSIX'         => 'en_US_POSIX',
                                # Apparently the Hebrew locale code was changed from iw to he at
                                # one point.
                                'iw'            => 'he',
                                'iw_IL'         => 'he_IL',
                                # CLDR got rid of no
                                'no'            => 'nn',
                                'no_NO'         => 'nn_NO',
                                'no_NO_NY'      => 'nn_NO',
                              } },
    );

class_has 'FormatLengths' =>
    ( is      => 'ro',
      isa     => 'ArrayRef',
      lazy    => 1,
      default => sub { return [qw( full long medium short ) ] },
    );

has 'version' =>
    ( is         => 'ro',
      isa        => 'Str',
      lazy_build => 1,
    );

has 'generation_date' =>
    ( is         => 'ro',
      isa        => 'Str',
      lazy_build => 1,
    );

has 'language' =>
    ( is      => 'ro',
      isa     => 'Str',
      lazy    => 1,
      default => sub { ( $_[0]->_parse_id() )[0] },
    );

has 'script' =>
    ( is      => 'ro',
      isa     => 'Str|Undef',
      lazy    => 1,
      default => sub { ( $_[0]->_parse_id() )[1] },
    );

has 'territory' =>
    ( is      => 'ro',
      isa     => 'Str|Undef',
      lazy    => 1,
      default => sub { ( $_[0]->_parse_id() )[2] },
    );

has 'variant' =>
    ( is      => 'ro',
      isa     => 'Str|Undef',
      lazy    => 1,
      default => sub { ( $_[0]->_parse_id() )[3] },
    );

has 'parent_id' =>
    ( is         => 'ro',
      isa        => 'Str',
      lazy_build => 1,
    );

class_type 'XML::LibXML::Node';
has '_calendar_node' =>
    ( is      => 'ro',
      isa     => 'XML::LibXML::Node|Undef',
      lazy    => 1,
      default => sub { $_[0]->_find_one_node( q{dates/calendars/calendar[@type='gregorian']} ) },
    );

has 'has_calendar_data' =>
    ( is      => 'ro',
      isa     => 'Bool',
      lazy    => 1,
      default => sub { $_[0]->_calendar_node() ? 1 : 0 },
    );

for my $thing ( { name   => 'day',
                  length => 7,
                  order  => [ qw( mon tue wed thu fri sat sun ) ],
                },
                { name   => 'month',
                  length => 12,
                  order  => [ 1..12 ],
                },
                { name   => 'quarter',
                  length => 4,
                  order  => [ 1..4 ],
                },
              )
{
    for my $context ( qw( format stand_alone ) )
    {
        for my $size ( qw( wide abbreviated narrow ) )
        {
            my $name = $thing->{name};

            my $attr = $name . q{_} . $context . q{_} . $size;
            has $attr =>
                ( is         => 'ro',
                  isa        => 'ArrayRef',
                  lazy_build => 1,
                );

            my $required_length = $thing->{length};

            ( my $xml_context = $context ) =~ s/_/-/g;
            my $path =
                ( join '/',
                  PL_N($name),
                  $name . 'Context' . q{[@type='} . $xml_context . q{']},
                  $name . 'Width' . q{[@type='} . $size . q{']},
                  $name
                );

            my $builder =
                sub { my $self = shift;

                      my @vals =
                          $self->_find_preferred_values
                              ( ( scalar $self->_calendar_node()->findnodes($path) ),
                                'type',
                                $thing->{order},
                              );

                      return [] unless @vals == $thing->{length};

                      return \@vals;
                    };

            __PACKAGE__->meta()->add_method( '_build_' . $attr => $builder );
        }
    }
}

# eras have a different name scheme for sizes than other data
# elements, go figure.
for my $size ( [ wide => 'Names' ], [ abbreviated => 'Abbr' ], [ narrow => 'Narrow' ] )
{
    my $attr = 'era_' . $size->[0];

    has $attr =>
        ( is         => 'ro',
          isa        => 'ArrayRef',
          lazy_build => 1,
        );

    my $path =
        ( join '/',
          'eras',
          'era' . $size->[1],
          'era',
        );

    my $builder =
        sub { my $self = shift;

              my @vals =
                  $self->_find_preferred_values
                      ( ( scalar $self->_calendar_node()->findnodes($path) ),
                        'type',
                        [ 0, 1 ],
                      );

              return [] unless @vals == 2;

              return \@vals;
          };

    __PACKAGE__->meta()->add_method( '_build_' . $attr => $builder );
}

for my $type ( qw( date time ) )
{
    for my $length ( qw( full long medium short ) )
    {
        my $attr = $type . q{_format_} . $length;

        has $attr =>
            ( is         => 'ro',
              isa        => 'Str|Undef',
              lazy_build => 1,
            );

        my $path =
            ( join '/',
              $type . 'Formats',
              $type . q{FormatLength[@type='} . $length . q{']},
              $type . 'Format',
              'pattern',
            );

        my $builder =
            sub { my $self = shift;

                  return eval { $self->_find_one_node_text( $path, $self->_calendar_node() ) };
              };

        __PACKAGE__->meta()->add_method( '_build_' . $attr => $builder );
    }
}

has 'default_date_format_length' =>
    ( is      => 'ro',
      isa     => 'Str|Undef',
      lazy    => 1,
      default => sub { $_[0]->_find_one_node_attribute( 'dateFormats/default',
                                                        $_[0]->_calendar_node(),
                                                        'choice' )
                     },
    );

has 'default_time_format_length' =>
    ( is      => 'ro',
      isa     => 'Str|Undef',
      lazy    => 1,
      default => sub { $_[0]->_find_one_node_attribute( 'timeFormats/default',
                                                        $_[0]->_calendar_node(),
                                                        'choice' )
                     },
    );

has 'am_pm' =>
    ( is         => 'ro',
      isa        => 'ArrayRef',
      lazy_build => 1,
    );

has 'datetime_format' =>
    ( is         => 'ro',
      isa        => 'Str|Undef',
      lazy_build => 1,
    );

has 'available_formats' =>
    ( is         => 'ro',
      isa        => 'HashRef[Str]',
      lazy_build => 1,
    );


{
    my %Cache;
    sub new_from_file
    {
        my $class = shift;
        my $file  = file( shift );

        my $id = $file->basename();
        $id =~ s/\.xml$//i;

        return $Cache{$id}
            if $Cache{$id};

        my $doc = $class->_resolve_document_aliases($file);

        return
            $Cache{$id} = $class->new( id          => $id,
                                       source_file => $file,
                                       document    => $doc,
                                     );
    }
}


{
    my $Parser = XML::LibXML->new();
    sub _resolve_document_aliases
    {
        my $class = shift;
        my $file  = shift;

        my $doc = $Parser->parse_file( $file->stringify() );

        $class->_resolve_aliases_in_node( $doc->documentElement(), $file );

        return $doc;
    }
}

sub _resolve_aliases_in_node
{
    my $class = shift;
    my $node  = shift;
    my $file  = shift;

 ALIAS:
    for my $node ( $node->getElementsByTagName('alias') )
    {
        # Replacing all the aliases is slow, and we really don't care
        # about most of the data in the file, just the
        # localeDisplayNames and the gregorian calendar.
        #
        # We also end up skipping the case where the entire locale is an alias to some
        # other locale. This is handled in the generated Perl code.
        for ( my $p = $node->parentNode(); $p; $p = $p->parentNode() )
        {
            if ( $p->nodeName() eq 'calendar' )
            {
                if ( $p->getAttribute('type') eq 'gregorian' )
                {
                    last;
                }
                else
                {
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

sub _resolve_alias
{
    my $class = shift;
    my $node  = shift;
    my $file  = shift;

    my $source = $node->getAttribute('source')
        or die "Alias with no source in $file";

    if ( $source eq 'locale' )
    {
        $class->_resolve_local_alias( $node, $file );
    }
    else
    {
        $class->_resolve_remote_alias( $node, $file );
    }
}

sub _resolve_local_alias
{
    my $class = shift;
    my $node = shift;
    my $file = shift;

    my $path = $node->getAttribute('path');

    # The path resolves from the context of the parent node, not the
    # current node. Why? Why not?
    $class->_replace_alias_with_path( $node, $path, $node->parentNode(), $file );
}

sub _resolve_remote_alias
{
    my $class = shift;
    my $node  = shift;
    my $file  = shift;

    my $source = $node->getAttribute('source');
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

sub _replace_alias_with_path
{
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

sub BUILD
{
    my $self = shift;

    my $meth = q{_} . $self->id() . q{_hack};

    # This gives us a chance to apply bug fixes to the data as needed.
#    $self->$meth($data)
#        if $self->can($meth);

    return $self;
}

sub _az_hack
{
    my $self = shift;
    my $data = shift;

    # The az.xml file appears to have a mistake in the wide day names,
    # thursday and friday are the same for this locale
    $data->{days}{dayContext}{format}{dayWidth}{wide}{day}[4] =~ s/ \w+$//;
}

sub _gaa_hack
{
    my $self = shift;
    my $data = shift;

    # I am completely making this up, but the data is marked as
    # uncomfimed in the locale file and it's preferable to having two
    # days with the same abbreviation
    $data->{days}{dayContext}{format}{dayWidth}{abbreviated}{day}[0] = 'Hog'
        if $data->{days}{dayContext}{format}{dayWidth}{abbreviated}{day}[0] eq 'Ho';
}

sub _ve_hack
{
    my $self = shift;
    my $data = shift;

    # Again, making stuff up to avoid non-unique abbreviations
    $data->{months}{monthContext}{format}{monthWidth}{abbreviated}{month}[2] = 'Ṱhf'
        if $data->{months}{monthContext}{format}{monthWidth}{abbreviated}{month}[2] eq 'Ṱha';
}

sub _build_version
{
    my $self = shift;

    my $version = $self->_find_one_node_attribute( 'identity/version', 'number' );
    $version =~ s/^\$Revision:\s+//;
    $version =~ s/\s+\$$//;

    return $version;
}

sub _build_generation_date
{
    my $self = shift;

    my $date = $self->_find_one_node_attribute( 'identity/generation', 'date' );
    $date =~ s/^\$Date:\s+//;
    $date =~ s/\s+\$$//;

    return $date;
}

sub _parse_id
{
    my $self = shift;

    return
        $self->id() =~ /([a-z]+)               # language
                        (?: _([A-Z][a-z]+) )?  # script - Title Case - optional
                        (?: _([A-Z]+) )?       # territory - ALL CAPS - optional
                        (?: _([A-Z]+) )?       # variant - ALL CAPS - optional
                       /x;
}

sub _build_parent_id
{
    my $self = shift;

    my $source = $self->_find_one_node_attribute( 'alias', 'source' );
    return $source if defined $source;

    my @parts =
        ( grep { defined }
          $self->language(),
          $self->script(),
          $self->territory(),
          $self->variant(),
        );

    pop @parts;

    if (@parts)
    {
        return join '_', @parts;
    }
    else
    {
        return $self->id() eq 'root' ? 'Base' : 'root';
    }
}

sub _build_am_pm
{
    my $self = shift;

    my $am = $self->_find_one_node_text( 'am', $self->_calendar_node() );
    my $pm = $self->_find_one_node_text( 'pm', $self->_calendar_node() );

    return [] unless defined $am && defined $pm;

    return [ $am, $pm ];
}

sub _build_datetime_format
{
    my $self = shift;

    return
        $self->_find_one_node_text( 'dateTimeFormats/dateTimeFormatLength/dateTimeFormat/pattern',
                                    $self->_calendar_node() );
}

sub _build_available_formats
{
    my $self = shift;

    my @nodes = $self->_calendar_node()->findnodes('dateTimeFormats/availableFormats/dateFormatItem');

    my %index;
    for my $node (@nodes)
    {
        push @{ $index{ $node->getAttribute('id') } }, $node;
    }

    my %formats;
    for my $id ( keys %index )
    {
        my $preferred = $self->_find_preferred_node( @{ $index{$id} } )
            or next;

        $formats{$id} = join '', map { $_->data() } $preferred->childNodes();
    }

    return \%formats;
}

sub _find_preferred_values
{
    my $self  = shift;
    my $nodes = shift;
    my $attr  = shift;
    my $order = shift;

    my @nodes = $nodes->get_nodelist();

    return [] unless @nodes;

    my %index;

    for my $node (@nodes)
    {
        push @{ $index{ $node->getAttribute($attr) } }, $node;
    }

    my @preferred;
    for my $attr ( @{ $order } )
    {
        my @matches = @{ $index{$attr} };

        my $preferred = $self->_find_preferred_node(@matches)
            or next;

        push @preferred, join '', map { $_->data() } $preferred->childNodes();
    }

    return @preferred;
}

sub _find_preferred_node
{
    my $self  = shift;
    my @nodes = @_;

    return unless @nodes;

    return $nodes[0] if @nodes == 1;

    my $non_draft = first { ! $_->getAttribute('draft') } @nodes;

    return $non_draft if $non_draft;

    return $nodes[0];
}

sub _find_one_node_text
{
    my $self = shift;

    my $node = $self->_find_one_node(@_);

    return unless $node;

    return join '', map { $_->data() } $node->childNodes();
}

sub _find_one_node_attribute
{
    my $self = shift;

    # attr name will always be last
    my $attr = pop;

    my $node = $self->_find_one_node(@_);

    return unless $node;

    return $node->getAttribute($attr);
}

sub _find_one_node
{
    my $self    = shift;
    my $path    = shift;
    my $context = shift || $self->document()->documentElement();

    my @nodes = $self->_find_preferred_node( $context->findnodes($path) );

    if ( @nodes > 1 )
    {
        my $context_path = $context->nodePath();

        die "Found multiple nodes for $path under $context_path";
    }

    return $nodes[0];
}

__PACKAGE__->meta()->make_immutable();
no Moose;
no Moose::Util::TypeConstraints;

1;
