use strict;
use warnings;

use Test::More tests => 10;

use_ok('XML::Reader');

{
    my $line = '';
    $line .= '<data>' for 1..10;
    $line .= '<item name="abc" id="123">xyz</item>';
    $line .= '</data>' for 1..10;

    {
        my $count = 0;
        my $rdr = XML::Reader->new(\$line, {filter => 1});
        while ($rdr->iterate) { $count++; }
        is($count, 3, 'counting filtered values');
    }

    {
        my $count = 0;
        my $rdr = XML::Reader->new(\$line, {filter => 0});
        while ($rdr->iterate) { $count++; }
        is($count, 24, 'counting unfiltered values');
    }
}

{
    my $line = q{<data c='3' a='1' b='2' />};
    my $out = '';
    my $rdr = XML::Reader->new(\$line);
    while ($rdr->iterate) { $out .= '['.$rdr->tag.'='.$rdr->value.']'; }
    is($out, '[a=1][b=2][c=3]', 'attributes in alphabetical order');
}

{
    my $line = q{<data><!-- test --></data>};
    my $out = '';
    my $rdr = XML::Reader->new(\$line, {comment => 1});
    while ($rdr->iterate) { $out .= '['.$rdr->type.'='.$rdr->value.']'; }
    is($out, '[#=test]', 'comment is produced');
}

{
    my $line = q{<data><!-- test --></data>};
    my $out = '';
    my $rdr = XML::Reader->new(\$line, {comment => 0});
    while ($rdr->iterate) { $out .= '['.$rdr->type.'='.$rdr->value.']'; }
    is($out, '', 'comment is suppressed');
}

{
    my $line = q{<data>     a        b c             </data>};
    my $out = '';
    my $rdr = XML::Reader->new(\$line, {strip => 1});
    while ($rdr->iterate) { $out .= '['.$rdr->type.'='.$rdr->value.']'; }
    is($out, '[T=a b c]', 'field is stripped of spaces');
}

{
    my $line = q{<data>     a        b c             </data>};
    my $out = '';
    my $rdr = XML::Reader->new(\$line, {strip => 0});
    while ($rdr->iterate) { $out .= '['.$rdr->type.'='.$rdr->value.']'; }
    is($out, '[T=     a        b c             ]', 'field is not stripped of spaces');
}

{
    my $line = q{
      <data>
        <item>abc</item>
        <item>
          <dummy/>
          fgh
          <inner name="ttt" id="fff">
            ooo <!-- comment --> ppp
          </inner>
        </item>
      </data>
      };

    my $start_seq = '';
    my $end_seq   = '';

    my $rdr = XML::Reader->new(\$line, {comment => 1, filter => 0});
    while ($rdr->iterate) {
        $start_seq .= $rdr->is_start;
        $end_seq   .= $rdr->is_end;
    }
    is($start_seq, '11011010000000', 'sequence of start-tags');
    is($end_seq,   '01001000000111', 'sequence of end-tags');
}
