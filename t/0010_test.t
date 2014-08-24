use strict;
use warnings;

use Test::More tests => 66;

use_ok('XML::Reader');

{
    my $line = '';
    $line .= '<data>' for 1..10;
    $line .= '<item name="abc" id="123">xyz</item>';
    $line .= '</data>' for 1..10;

    {
        my $count = 0;
        my $rdr = XML::Reader->newhd(\$line, {filter => 1});
        while ($rdr->iterate) { $count++; }
        is($count, 3, 'counting values {filter => 1}');
    }

    {
        my $count = 0;
        my $rdr = XML::Reader->new(\$line);
        while ($rdr->iterate) { $count++; }
        is($count, 24, 'counting values (with new)');
    }

    {
        my $count = 0;
        my $rdr = XML::Reader->newhd(\$line, {filter => 2});
        while ($rdr->iterate) { $count++; }
        is($count, 23, 'counting values {filter => 2}');
    }

    {
        my $info = '';
        my $rdr = XML::Reader->newhd(\$line, {filter => 1, using => '/data/data/data/data'});
        while ($rdr->iterate) { $info .= '['.$rdr->level.']'; }
        is($info, '[8][8][7]', 'level information with using and filter');
    }
}

{
    my $line = q{<data c='3' a='1' b='2' />};
    my $out = '';
    my $rdr = XML::Reader->newhd(\$line, {filter => 1});
    while ($rdr->iterate) { $out .= '['.$rdr->tag.'='.$rdr->value.']'; }
    is($out, '[@a=1][@b=2][@c=3]', 'attributes in alphabetical order');
}

{
    my $line = q{<data><dummy></dummy>a      <!-- b -->    c</data>};
    my $out = '';
    my $rdr = XML::Reader->newhd(\$line);
    while ($rdr->iterate) { $out .= '['.$rdr->tag.'='.$rdr->value.']'; }
    is($out, '[data=][dummy=][data=a c]', 'defaults are ok {strip => 1, filter => 2}');
}

{
    my $line = q{<data><dummy><!-- test --></dummy></data>};
    my $out = '';
    my $rdr = XML::Reader->newhd(\$line);
    while ($rdr->iterate) { $out .= '['.$rdr->path.'='.$rdr->comment.']'; }
    is($out, '[/data=][/data/dummy=test][/data=]', 'comment is produced');
}

{
    my $line = q{<data>     a        b c             </data>};
    my $out = '';
    my $rdr = XML::Reader->newhd(\$line, {strip => 1});
    while ($rdr->iterate) { $out .= '['.$rdr->type.'='.$rdr->value.']'; }
    is($out, '[T=a b c]', 'field is stripped of spaces');
}

{
    my $line = q{<data>     a        b c             </data>};
    my $out = '';
    my $rdr = XML::Reader->newhd(\$line, {strip => 0});
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

    {
        my $start_seq = '';
        my $ini_seq   = '';
        my $end_seq   = '';
        my $lvl_seq   = '';

        my $rdr = XML::Reader->new(\$line);
        while ($rdr->iterate) {
            $start_seq .= $rdr->is_start;
            $ini_seq   .= $rdr->is_init_attr;
            $end_seq   .= $rdr->is_end;
            $lvl_seq   .= '['.$rdr->level.']';
        }
        is($start_seq, '110110100000', 'sequence of start-tags (with new)');
        is($ini_seq,   '111111110011', 'sequence of init_attr (with new)');
        is($end_seq,   '010010000111', 'sequence of end-tags (with new)');
        is($lvl_seq,   '[1][2][1][2][3][2][3][4][4][3][2][1]', 'sequence of level information (with new)');
    }

    {
        my $start_seq = '';
        my $ini_seq   = '';
        my $end_seq   = '';
        my $lvl_seq   = '';

        my $rdr = XML::Reader->newhd(\$line);
        while ($rdr->iterate) {
            $start_seq .= $rdr->is_start;
            $ini_seq   .= $rdr->is_init_attr;
            $end_seq   .= $rdr->is_end;
            $lvl_seq   .= '['.$rdr->level.']';
        }

        is($start_seq, '11011000100', 'sequence of start-tags (with newhd)');
        is($ini_seq,   '11111110011', 'sequence of init_attr (with newhd)');
        is($end_seq,   '01001000111', 'sequence of end-tags (with newhd)');
        is($lvl_seq,   '[1][2][1][2][3][2][4][4][3][2][1]', 'sequence of level information (with newhd)');
    }
}

{
    my $line = q{<a><b><c><d></d></c></b></a>};

    {
        my $info = '';

        my $rdr = XML::Reader->new(\$line);
        while ($rdr->iterate) {
            $info .= '['.$rdr->path.'='.$rdr->value.']';
        }
        is($info, '[/a=][/a/b=][/a/b/c=][/a/b/c/d=][/a/b/c=][/a/b=][/a=]', 'an empty, 4-level deep, nested XML (with new)');
    }

    {
        my $info = '';

        my $rdr = XML::Reader->newhd(\$line);
        while ($rdr->iterate) {
            $info .= '['.$rdr->path.'='.$rdr->value.']';
        }
        is($info, '[/a=][/a/b=][/a/b/c=][/a/b/c/d=][/a/b/c=][/a/b=][/a=]', 'an empty, 4-level deep, nested XML (with newhd)');
    }
}

{
    my $line = q{
      <data>
        ooo <!-- hello --> ppp
      </data>
      };

    {
        my $data    = '';
        my $comment = '';

        my $rdr = XML::Reader->newhd(\$line);
        my $i = 0;
        while ($rdr->iterate) { $i++;
            $comment = $rdr->comment if $i == 1;
            $data    = $rdr->value   if $i == 1;
        }
        is($comment, 'hello', 'comment is correctly recognised');
        is($data,    'ooo ppp', 'data is not broken up by comments');
    }

    {
        my $data    = '';
        my $comment = '';

        my $rdr = XML::Reader->new(\$line);
        my $i = 0;
        while ($rdr->iterate) { $i++;
            $comment .= $rdr->comment if $rdr->type eq 'T';
            $data    .= $rdr->value   if $rdr->type eq 'T';
        }
        is($i,       1, 'only one line is produced (with new)');
        is($comment, 'hello', 'comment is found to be correct (with new)');
        is($data,    'ooo ppp', 'data is not empty (with new)');
    }
    {
        my $data    = '';
        my $comment = '';

        my $rdr = XML::Reader->newhd(\$line);
        my $i = 0;
        while ($rdr->iterate) { $i++;
            $comment .= $rdr->comment if $rdr->type eq 'T';
            $data    .= $rdr->value   if $rdr->type eq 'T';
        }
        is($i,       1, 'only one line is produced (with newhd)');
        is($comment, 'hello', 'comment is found to be correct (with newhd)');
        is($data,    'ooo ppp', 'data is not empty (with newhd)');
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

    {
        my $att_seq = '';

        my $rdr = XML::Reader->new(\$line, {filter => 3, using => ['/data/item/alpha', '/data/item/beta']});
        my $i = 0;
        while ($rdr->iterate) { $i++;
            my %at = %{$rdr->att_hash};
            $att_seq .= '['.join(' ', map {qq($_="$at{$_}")} sort keys %at).']';
        }
        is($att_seq, '[age="999" name="lll" type="qqq"][test="successful"][][number="undef"][][][][][][][][]',
          'check $rdr->att_hash {filter => 3}');
    }

    {
        my $att_seq = '';

        my $rdr = XML::Reader->new(\$line, {filter => 2, using => ['/data/item/alpha', '/data/item/beta']});
        my $i = 0;
        while ($rdr->iterate) { $i++;
            my %at = %{$rdr->att_hash};
            $att_seq .= '['.join(' ', map {qq($_="$at{$_}")} sort keys %at).']';
        }
        is($att_seq, '[][][][][][][][][][][][][][][][][]', 'check $rdr->att_hash {filter => 2}');
    }

    {
        my $point_01 = '';
        my $point_09 = '';
        my $point_10 = '';
        my $point_25 = '';
        my $point_26 = '';
        my $point_38 = '';
        my $point_48 = '';

        my $rdr = XML::Reader->new(\$line, {using => ['/data/item', '/data/btem/user/level/agreement']});
        my $i = 0;
        while ($rdr->iterate) { $i++;
            my $point = '['.$rdr->prefix.']['.$rdr->path.']['.$rdr->is_start.']['.$rdr->is_end.']['.$rdr->level.']';
            if    ($i ==  1) { $point_01 = $point; }
            elsif ($i ==  9) { $point_09 = $point; }
            elsif ($i == 10) { $point_10 = $point; }
            elsif ($i == 25) { $point_25 = $point; }
            elsif ($i == 26) { $point_26 = $point; }
            elsif ($i == 38) { $point_38 = $point; }
            elsif ($i == 48) { $point_48 = $point; }
        }
        is($point_01, '[/data/item][/][1][1][0]',                         'check using at data point 01 {filter => 0}');
        is($point_09, '[/data/item][/][0][1][0]',                         'check using at data point 09 {filter => 0}');
        is($point_10, '[/data/btem/user/level/agreement][/][1][0][0]',    'check using at data point 10 {filter => 0}');
        is($point_25, '[/data/btem/user/level/agreement][/][0][1][0]',    'check using at data point 25 {filter => 0}');
        is($point_26, '[/data/item][/][1][0][0]',                         'check using at data point 26 {filter => 0}');
        is($point_38, '[/data/item][/beta/gamma/delta/@number][0][0][4]', 'check using at data point 38 {filter => 0}');
        is($point_48, '[/data/item][/][0][1][0]',                         'check using at data point 48 {filter => 0}');
    }

    {
        my $point_01 = '';
        my $point_07 = '';
        my $point_08 = '';
        my $point_09 = '';
        my $point_15 = '';
        my $point_18 = '';
        my $point_19 = '';
        my $point_30 = '';
        my $point_41 = '';

        my $rdr = XML::Reader->newhd(\$line, {using => ['/data/item', '/data/btem/user/level/agreement']});
        my $i = 0;
        while ($rdr->iterate) { $i++;
            my $point = '['.$rdr->prefix.']['.$rdr->path.']['.$rdr->is_start.$rdr->is_init_attr.$rdr->is_end.']['.$rdr->level.']';
            if    ($i ==  1) { $point_01 = $point; }
            elsif ($i ==  7) { $point_07 = $point; }
            elsif ($i ==  8) { $point_08 = $point; }
            elsif ($i ==  9) { $point_09 = $point; }
            elsif ($i == 15) { $point_15 = $point; }
            elsif ($i == 18) { $point_18 = $point; }
            elsif ($i == 19) { $point_19 = $point; }
            elsif ($i == 30) { $point_30 = $point; }
            elsif ($i == 41) { $point_41 = $point; }
        }
        is($point_01, '[/data/item][/][111][0]',                                 'check using at data point 01 {filter => 2}');
        is($point_07, '[/data/item][/inner][101][1]',                            'check using at data point 07 {filter => 2}');
        is($point_08, '[/data/item][/][011][0]',                                 'check using at data point 08 {filter => 2}');
        is($point_09, '[/data/btem/user/level/agreement][/][110][0]',            'check using at data point 09 {filter => 2}');
        is($point_15, '[/data/btem/user/level/agreement][/line/@water][000][2]', 'check using at data point 15 {filter => 2}');
        is($point_18, '[/data/btem/user/level/agreement][/line/@ice][010][2]',   'check using at data point 18 {filter => 2}');
        is($point_19, '[/data/btem/user/level/agreement][/line/@water][000][2]', 'check using at data point 19 {filter => 2}');
        is($point_30, '[/data/item][/beta/gamma][110][2]',                       'check using at data point 30 {filter => 2}');
        is($point_41, '[/data/item][/][011][0]',                                 'check using at data point 41 {filter => 2}');
    }
}

{
    my $line = q{<data />};

    my $output = '';

    my $rdr = XML::Reader->newhd(\$line);
    my $i = 0;
    while ($rdr->iterate) { $i++;
        $output .= '['.$rdr->path.'-'.$rdr->value.']['.$rdr->is_start.$rdr->is_init_attr.$rdr->is_end.']['.$rdr->level.']';
    }
    is($output, '[/data-][111][1]', 'the simplest XML possible');
}

{
    my $line = q{<data id="z" />};

    my $output = '';

    my $rdr = XML::Reader->newhd(\$line);
    my $i = 0;
    while ($rdr->iterate) { $i++;
        $output .= '['.$rdr->path.'-'.$rdr->value.']['.$rdr->is_start.$rdr->is_init_attr.$rdr->is_end.']['.$rdr->level.']';
    }
    is($output, '[/data/@id-z][010][2][/data-][101][1]', 'a simple XML with attribute');
}

{
    my $line = q{<apple orange="banana" />};

    my $tag  = '';
    my $attr = '';

    my $rdr = XML::Reader->newhd(\$line);
    my $i = 0;
    while ($rdr->iterate) { $i++;
        $tag  .= '['.$rdr->tag.']';
        $attr .= '['.$rdr->attr.']';
    }
    is($tag,  '[@orange][apple]', 'verify tags');
    is($attr, '[orange][]', 'verify attributes');
}

{
    my $line = q{<data>abc<![CDATA[  x    y  z >  <  &  ]]>def</data>};

    my $output = '';

    my $rdr = XML::Reader->newhd(\$line);
    my $i = 0;
    while ($rdr->iterate) { $i++;
        $output .= '['.$rdr->value.']';
    }
    is($output, '[abc x y z > < & def]', 'CDATA is processed correctly');
}

{
    my $line = q{<root><id order='desc' nb='no' screen='color'>show
    <data name='abc' addr='def'>definition</data>text</id></root>};

    my $rdr = XML::Reader->newhd(\$line);

    my $output = '';

    my $i = 0;
    while ($rdr->iterate) { $i++;
        $output .= '['.$rdr->is_start.$rdr->is_init_attr.$rdr->is_end.']';
    }
    is($output, '[110][010][000][000][100][010][000][101][011][011]',
       'filter => 2 for is_start, is_init_attr, is_end');
}

{
    my $line = q{
      <data>
        <item>abc</item>
        <item>
          <dummy/>
          fgh
          <inner name="ttt" id="fff">
            o <!-- comment --> p
          </inner>
        </item>
        <btem>
          <record id="77" used="no">Player 1</record>
          <record id="88" used="no">Player 2</record>
          <user>
            <lvl>
              <a>
                <line water="abc" ice="iii">jump</line>
                <line water="def" ice="jjj">go</line>
                <line water="ghi" ice="kkk">crawl</line>
              </a>
            </lvl>
          </user>
          <record id="99" used="no">Player 3</record>
        </btem>
        <item ts="vy">
          <alpha name="lll" type="qqq" age="999" />
          <beta test="sful">
            <gamma>
              <d num="undef">
                letter
              </d>
            </gamma>
            <test>one</test>
            <test>t         o</test>
            <test>three</test>
          </beta>
        </item>
      </data>
};

    my $point_01 = '';
    my $point_05 = '';
    my $point_08 = '';
    my $point_14 = '';
    my $point_15 = '';
    my $point_16 = '';
    my $point_22 = '';
    my $point_38 = '';
    my $point_42 = '';

    my $rdr = XML::Reader->newhd(\$line, {using => ['/data/item', '/data/btem/user/lvl/a']});

    my $i = 0;
    while ($rdr->iterate) { $i++;
        my $point = '['.$rdr->prefix.']['.$rdr->path.']['.$rdr->value.']['.$rdr->type.
                    ']['.$rdr->is_start.$rdr->is_init_attr.$rdr->is_end.']['.$rdr->tag.']['.$rdr->attr.']';

        if    ($i ==  1) { $point_01 = $point; }
        elsif ($i ==  5) { $point_05 = $point; }
        elsif ($i ==  8) { $point_08 = $point; }
        elsif ($i == 14) { $point_14 = $point; }
        elsif ($i == 15) { $point_15 = $point; }
        elsif ($i == 16) { $point_16 = $point; }
        elsif ($i == 22) { $point_22 = $point; }
        elsif ($i == 38) { $point_38 = $point; }
        elsif ($i == 42) { $point_42 = $point; }
    }
    is($point_01, '[/data/item][/][abc][T][111][][]',                                  'check filter=>2 at data point 01');
    is($point_05, '[/data/item][/inner/@id][fff][@][010][@id][id]',                    'check filter=>2 at data point 05');
    is($point_08, '[/data/item][/][][T][011][][]',                                     'check filter=>2 at data point 08');
    is($point_14, '[/data/btem/user/lvl/a][/line/@ice][jjj][@][010][@ice][ice]',       'check filter=>2 at data point 14');
    is($point_15, '[/data/btem/user/lvl/a][/line/@water][def][@][000][@water][water]', 'check filter=>2 at data point 15');
    is($point_16, '[/data/btem/user/lvl/a][/line][go][T][101][line][]',                'check filter=>2 at data point 16');
    is($point_22, '[/data/item][/@ts][vy][@][010][@ts][ts]',                           'check filter=>2 at data point 22');
    is($point_38, '[/data/item][/beta/test][t o][T][111][test][]',                     'check filter=>2 at data point 38');
    is($point_42, '[/data/item][/][][T][011][][]',                                     'check filter=>2 at data point 42');
}

{
    my $line = q{<data>abc</data>};


    my $rdr = XML::Reader->newhd(\$line, {filter => 1});

    my $is_start     = 'z';
    my $is_init_attr = 'z';
    my $is_end       = 'z';
    my $comment      = 'z';
    my $path         = 'z';

    my $i = 0;
    while ($rdr->iterate) { $i++;
        if ($i ==  1) {
            $is_start     = $rdr->is_start;
            $is_init_attr = $rdr->is_init_attr;
            $is_end       = $rdr->is_end;
            $comment      = $rdr->comment;
            $path         = $rdr->path;
        }
    }
    ok(!defined($is_start),     'method is_start is undef for {filter => 1}');
    ok(!defined($is_init_attr), 'method is_init_attr is undef for {filter => 1}');
    ok(!defined($is_end),       'method is_end is undef for {filter => 1}');
    ok(!defined($comment),      'method comment is undef for {filter => 1}');
    ok(defined($path),          'method path is defined for {filter => 1}');
}
