use strict;
use warnings;

use Test::More tests => 30;

use_ok('XML::Reader');

{
    my $msg = '';
    my $rdr = XML::Reader->new('<') or $msg = "$!";
    is($msg, 'Invalid argument', 'Message correctly returned from new');
}

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

    {
        my $info = '';
        my $rdr = XML::Reader->new(\$line, {filter => 1, using => '/data/data/data/data'});
        while ($rdr->iterate) { $info .= '['.$rdr->level.']'; }
        is($info, '[8][8][7]', 'level information with using and filter');
    }
}

{
    my $line = q{<data c='3' a='1' b='2' />};
    my $out = '';
    my $rdr = XML::Reader->new(\$line, {filter => 1});
    while ($rdr->iterate) { $out .= '['.$rdr->tag.'='.$rdr->value.']'; }
    is($out, '[@a=1][@b=2][@c=3]', 'attributes in alphabetical order');
}

{
    my $line = q{<data>a     b  <!-- c --> d</data>};
    my $out = '';
    my $rdr = XML::Reader->new(\$line);
    while ($rdr->iterate) { $out .= '['.$rdr->tag.'='.$rdr->value.']'; }
    is($out, '[data=][#=c][data=a b d]', 'defaults are ok {comment => 1, strip => 1, filter => 0');
}

{
    my $line = q{<data><!-- test --></data>};
    my $out = '';
    my $rdr = XML::Reader->new(\$line, {comment => 1, filter => 1});
    while ($rdr->iterate) { $out .= '['.$rdr->type.'='.$rdr->value.']'; }
    is($out, '[#=test]', 'comment is produced');
}

{
    my $line = q{<data><!-- test --></data>};
    my $out = '';
    my $rdr = XML::Reader->new(\$line, {comment => 1, filter => 0});
    while ($rdr->iterate) { $out .= '['.$rdr->type.'='.$rdr->value.']'; }
    is($out, '[T=][#=test][T=]', 'comment is produced with filter off');
}

{
    my $line = q{<data><!-- test --></data>};
    my $out = '';
    my $rdr = XML::Reader->new(\$line, {comment => 0, filter => 1});
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
            o <!-- comment --> p <!-- comment2 --> q
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
    is($start_seq, '1101101000000', 'sequence of start-tags');
    is($end_seq,   '0100100000111', 'sequence of end-tags');
    is($lvl_seq,   '[1][2][1][2][3][2][3][4][4][4][3][2][1]', 'sequence of level information');
}

{
    my $line = q{<a><b><c><d></d></c></b></a>};

    my $info = '';

    my $rdr = XML::Reader->new(\$line, {filter => 0});
    while ($rdr->iterate) {
        $info .= '['.$rdr->path.'='.$rdr->value.']';
    }
    is($info, '[/a=][/a/b=][/a/b/c=][/a/b/c/d=][/a/b/c=][/a/b=][/a=]', 'an empty, 4-level deep, nested XML');
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
    my $point_10 = '';
    my $point_11 = '';
    my $point_26 = '';
    my $point_27 = '';
    my $point_39 = '';
    my $point_49 = '';

    my $rdr = XML::Reader->new(\$line, {comment => 1, filter => 0, using => ['/data/item', '/data/btem/user/level/agreement']});
    my $i = 0;
    while ($rdr->iterate) { $i++;
        my $point = '['.$rdr->prefix.']['.$rdr->path.']['.$rdr->is_start.']['.$rdr->is_end.']['.$rdr->level.']';
        if    ($i ==  1) { $point_01 = $point; }
        elsif ($i == 10) { $point_10 = $point; }
        elsif ($i == 11) { $point_11 = $point; }
        elsif ($i == 26) { $point_26 = $point; }
        elsif ($i == 27) { $point_27 = $point; }
        elsif ($i == 39) { $point_39 = $point; }
        elsif ($i == 49) { $point_49 = $point; }
    }
    is($point_01, '[/data/item][/][1][1][0]',                         'check using at data point 01');
    is($point_10, '[/data/item][/][0][1][0]',                         'check using at data point 10');
    is($point_11, '[/data/btem/user/level/agreement][/][1][0][0]',    'check using at data point 11');
    is($point_26, '[/data/btem/user/level/agreement][/][0][1][0]',    'check using at data point 26');
    is($point_27, '[/data/item][/][1][0][0]',                         'check using at data point 27');
    is($point_39, '[/data/item][/beta/gamma/delta/@number][0][0][4]', 'check using at data point 39');
    is($point_49, '[/data/item][/][0][1][0]',                         'check using at data point 49');
}

{
    my $line = q{<data />};

    my $output = '';

    my $rdr = XML::Reader->new(\$line, {comment => 1, filter => 0});
    my $i = 0;
    while ($rdr->iterate) { $i++;
        $output .= '['.$rdr->path.'-'.$rdr->value.'-'.$rdr->is_start.'-'.$rdr->is_end.'-'.$rdr->level.']';
    }
    is($output, '[/data--1-1-1]', 'the simplest XML possible');
}

{
    my $line = q{<data id="z" />};

    my $output = '';

    my $rdr = XML::Reader->new(\$line, {comment => 1, filter => 0});
    my $i = 0;
    while ($rdr->iterate) { $i++;
        $output .= '['.$rdr->path.'-'.$rdr->value.'-'.$rdr->is_start.'-'.$rdr->is_end.'-'.$rdr->level.']';
    }
    is($output, '[/data--1-0-1][/data/@id-z-0-0-2][/data--0-1-1]', 'a simple XML with attribute');
}
