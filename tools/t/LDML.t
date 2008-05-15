use strict;
use warnings;

use Data::Dumper;
use Test::More tests => 55;

use LDML;


{
    my $ldml = LDML->new( id       => 'cop_Arab_EG',
                          document => XML::LibXML::Document->new(),
                        );
    is_deeply( [ $ldml->_parse_id() ],
               [ 'cop', 'Arab', 'EG', undef ],
               '_parse_id for cop_Arab_EG' );

}

{
    my $ldml = LDML->new( id       => 'hy_AM_REVISED',
                          document => XML::LibXML::Document->new(),
                        );
    is_deeply( [ $ldml->_parse_id() ],
               [ 'hy', undef, 'AM', 'REVISED' ],
               '_parse_id for hy_AM_REVISED' );
}

{
    # There are no ids with all four parts as of CLDR 1.5.1 but just
    # in case it ever happens ...
    my $ldml = LDML->new( id       => 'wo_Latn_SN_REVISED',
                          document => XML::LibXML::Document->new(),
                        );
    is_deeply( [ $ldml->_parse_id() ],
               [ 'wo', 'Latn', 'SN', 'REVISED' ],
               '_parse_id for wo_Latn_SN_REVISED' );
}

{
    my $ldml = LDML->new_from_file( 't/test-data/root.xml' );

    is( $ldml->id(), 'root', 'id' );
    is( $ldml->version(), '1.124', 'version' );
    is( $ldml->generation_date(), '2007/11/16 18:12:39', 'generation_date' );
    ok( $ldml->is_complete(), 'ldml is complete' );
    is( $ldml->parent_id(), 'Base', 'parent_id' );

    my %data =
        ( day_format_narrow           => [ 2..7, 1 ],
          day_format_abbreviated      => [ 2..7, 1 ],
          day_format_wide             => [ 2..7, 1 ],
          day_stand_alone_narrow      => [ 2..7, 1 ],
          day_stand_alone_abbreviated => [ 2..7, 1 ],
          day_stand_alone_wide        => [ 2..7, 1 ],

          month_format_narrow           => [ 1..12 ],
          month_format_abbreviated      => [ 1..12 ],
          month_format_wide             => [ 1..12 ],
          month_stand_alone_narrow      => [ 1..12 ],
          month_stand_alone_abbreviated => [ 1..12 ],
          month_stand_alone_wide        => [ 1..12 ],

          quarter_format_narrow           => [ 1..4 ],
          quarter_format_abbreviated      => [ map { 'Q' . $_ } 1..4 ],
          quarter_format_wide             => [ map { 'Q' . $_ } 1..4 ],
          quarter_stand_alone_narrow      => [ 1..4 ],
          quarter_stand_alone_abbreviated => [ map { 'Q' . $_ } 1..4 ],
          quarter_stand_alone_wide        => [ map { 'Q' . $_ } 1..4 ],

          am_pm => [ qw( AM PM ) ],

          era_wide        => [ qw( BCE CE ) ],
          era_abbreviated => [ qw( BCE CE ) ],
          era_narrow      => [ qw( BCE CE ) ],

          date_format_full   => 'EEEE, yyyy MMMM dd',
          date_format_long   => 'yyyy MMMM d',
          date_format_medium => 'yyyy MMM d',
          date_format_short  => 'yyyy-MM-dd',

          time_format_full   => 'HH:mm:ss v',
          time_format_long   => 'HH:mm:ss z',
          time_format_medium => 'HH:mm:ss',
          time_format_short  => 'HH:mm',
        );

    for my $meth ( sort keys %data )
    {
        is_deeply( $ldml->$meth(),
                   $data{$meth},
                   "data for $meth" );
    }
}

{
    my $ldml = LDML->new_from_file( 't/test-data/ssy.xml' );

    is( $ldml->id(), 'ssy', 'id' );
    is( $ldml->version(), '1.1', 'version' );
    is( $ldml->generation_date(), '2007/07/19 20:48:11', 'generation_date' );
    ok( ! $ldml->is_complete(), 'ldml is not complete' );

    is( $ldml->language(), 'ssy', 'language' );
    is( $ldml->script(), undef, 'variant' );
    is( $ldml->territory(), undef, 'territory' );
    is( $ldml->variant(), undef, 'variant' );
    is( $ldml->parent_id(), 'root', 'parent_id' );
}

{
    my $ldml = LDML->new_from_file( 't/test-data/en_GB.xml' );

    is( $ldml->id(), 'en_GB', 'id' );
    is( $ldml->language(), 'en', 'language' );
    is( $ldml->script(), undef, 'variant' );
    is( $ldml->territory(), 'GB', 'territory' );
    is( $ldml->variant(), undef, 'variant' );
    is( $ldml->parent_id(), 'en', 'parent_id' );
}

{
    my $ldml = LDML->new_from_file( 't/test-data/zh_MO.xml' );

    is( $ldml->parent_id(), 'zh_Hant_MO', 'parent_id for zh_MO' );
}

{
    my $ldml = LDML->new_from_file( 't/test-data/ti.xml' );

    cmp_ok( scalar @{ [ $ldml->document()->documentElement()
                             ->findnodes('localeDisplayNames/territories/territory') ] },
            '>',
            2,
            'ti alias to am for territories was resolved properly' );
}
