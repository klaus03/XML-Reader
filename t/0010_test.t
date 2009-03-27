use strict;
use warnings;

use Test::More tests => 23;

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
    my $lvl_seq   = '';

    my $rdr = XML::Reader->new(\$line, {comment => 1, filter => 0});
    while ($rdr->iterate) {
        $start_seq .= $rdr->is_start;
        $end_seq   .= $rdr->is_end;
        $lvl_seq   .= '['.$rdr->level.']';
    }
    is($start_seq, '11011010000000', 'sequence of start-tags');
    is($end_seq,   '01001000000111', 'sequence of end-tags');
    is($lvl_seq,   '[1][2][1][2][3][2][3][4][4][3][4][3][2][1]', 'sequence of level information');
}

{
    my $line = q{
      <data>
        ooo <!-- comment --> ppp
      </data>
      };

    {
        my $data    = '';
        my $comment = '';

        my $rdr = XML::Reader->new(\$line, {comment => 1, filter => 0});
        my $i = 0;
        while ($rdr->iterate) { $i++;
            $comment = $rdr->value if $i == 2;
            $data    = $rdr->value if $i == 3;
        }
        is($comment, 'comment', 'comment comes before data');
        is($data,    'ooo ppp', 'data is not broken up by comments');
    }

    {
        my $data    = '';
        my $comment = '';

        my $rdr = XML::Reader->new(\$line, {comment => 0, filter => 0});
        my $i = 0;
        while ($rdr->iterate) { $i++;
            $comment = $rdr->value if $rdr->type eq '#';
            $data    = $rdr->value if $rdr->type eq 'T';
        }
        is($i,       1, 'only one line is produced');
        is($comment, '', 'comment is empty');
        is($data,    'ooo ppp', 'data is not empty');
    }
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
        <btem>
          <record id="77" used="no">Player 1</record>
          <record id="88" used="no">Player 2</record>
          <user>
            <level>
              <agreement>
                <line water="abc" ice="iii">jump</line>
                <line water="def" ice="jjj">go</line>
                <line water="ghi" ice="kkk">crawl</line>
              </agreement>
            </level>
          </user>
          <record id="99" used="no">Player 3</record>
        </btem>
        <item>
          <alpha name="lll" type="qqq" age="999" />
          <beta test="successful">
            <gamma>
              <delta number="undef">
                letter
              </delta>
            </gamma>
            <test>number one</test>
            <test>number two</test>
            <test>number three</test>
          </beta>
        </item>
      </data>
    };

    my $point_01 = '';
    my $point_07 = '';
    my $point_08 = '';
    my $point_19 = '';
    my $point_20 = '';
    my $point_30 = '';
    my $point_39 = '';

    my $rdr = XML::Reader->new(\$line, {comment => 1, filter => 0, using => ['/data/item', '/data/btem/user/level/agreement']});
    my $i = 0;
    while ($rdr->iterate) { $i++;
        my $point = '['.$rdr->prefix.']['.$rdr->path.']['.$rdr->is_start.']['.$rdr->is_end.']['.$rdr->level.']';
        if    ($i ==  1) { $point_01 = $point; }
        elsif ($i ==  7) { $point_07 = $point; }
        elsif ($i ==  8) { $point_08 = $point; }
        elsif ($i == 19) { $point_19 = $point; }
        elsif ($i == 20) { $point_20 = $point; }
        elsif ($i == 30) { $point_30 = $point; }
        elsif ($i == 39) { $point_39 = $point; }
    }
    is($point_01, '[/data/item][/dummy][1][1][1]',                     'check using at data point 01');
    is($point_07, '[/data/item][/inner][0][1][1]',                     'check using at data point 07');
    is($point_08, '[/data/btem/user/level/agreement][/line][1][0][1]', 'check using at data point 08');
    is($point_19, '[/data/btem/user/level/agreement][/line][0][1][1]', 'check using at data point 19');
    is($point_20, '[/data/item][/alpha][1][0][1]',                     'check using at data point 20');
    is($point_30, '[/data/item][/beta/gamma/delta/@number][0][0][4]',  'check using at data point 30');
    is($point_39, '[/data/item][/beta][0][1][1]',                      'check using at data point 39');
}
