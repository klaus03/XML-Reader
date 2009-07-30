use strict;
use warnings;

use Test::More tests => 88;

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
    my $rdr = XML::Reader->newhd(\$line, {parse_ct => 1});
    while ($rdr->iterate) { $out .= '['.$rdr->path.'='.$rdr->comment.']'; }
    is($out, '[/data=][/data/dummy=][/data/dummy=test][/data=]', 'comment is produced');
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
        my $end_seq   = '';
        my $lvl_seq   = '';

        my $rdr = XML::Reader->new(\$line);
        while ($rdr->iterate) {
            $start_seq .= $rdr->is_start;
            $end_seq   .= $rdr->is_end;
            $lvl_seq   .= '['.$rdr->level.']';
        }
        is($start_seq, '110110100000', 'sequence of start-tags (with new)');
        is($end_seq,   '010010000111', 'sequence of end-tags (with new)');
        is($lvl_seq,   '[1][2][1][2][3][2][3][4][4][3][2][1]', 'sequence of level information (with new)');
    }

    {
        my $start_seq = '';
        my $end_seq   = '';
        my $lvl_seq   = '';

        my $rdr = XML::Reader->newhd(\$line);
        while ($rdr->iterate) {
            $start_seq .= $rdr->is_start;
            $end_seq   .= $rdr->is_end;
            $lvl_seq   .= '['.$rdr->level.']';
        }

        is($start_seq, '11011000100', 'sequence of start-tags (with newhd)');
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

        my $rdr = XML::Reader->newhd(\$line, {parse_ct => 1});
        my $i = 0;
        while ($rdr->iterate) { $i++;
            $comment = $rdr->comment if $i == 2;
            $data    = $rdr->value   if $i == 2;
        }
        is($comment, 'hello', 'comment is correctly recognised');
        is($data,    'ppp', 'data is broken up by comments');
    }

    {
        my $data    = '';
        my $comment = '';

        my $rdr = XML::Reader->new(\$line, {parse_ct => 1});
        my $i = 0;
        while ($rdr->iterate) { $i++;
            $comment .= $rdr->comment if $rdr->type eq 'T';
            $data    .= $rdr->value   if $rdr->type eq 'T';
        }
        is($i,       2, 'only one line is produced (with new)');
        is($comment, 'hello', 'comment is found to be correct (with new)');
        is($data,    'oooppp', 'data is not empty (with new)');
    }
    {
        my $data    = '';
        my $comment = '';

        my $rdr = XML::Reader->newhd(\$line, {parse_ct => 1});
        my $i = 0;
        while ($rdr->iterate) { $i++;
            $comment .= $rdr->comment if $rdr->type eq 'T';
            $data    .= $rdr->value   if $rdr->type eq 'T';
        }
        is($i,       2, 'only one line is produced (with newhd)');
        is($comment, 'hello', 'comment is found to be correct (with newhd)');
        is($data,    'oooppp', 'data is not empty (with newhd)');
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
            my $point = '['.$rdr->prefix.']['.$rdr->path.']['.$rdr->is_start.$rdr->is_end.']['.$rdr->level.']';
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
        is($point_01, '[/data/item][/][11][0]',                                 'check using at data point 01 {filter => 2}');
        is($point_07, '[/data/item][/inner][11][1]',                            'check using at data point 07 {filter => 2}');
        is($point_08, '[/data/item][/][01][0]',                                 'check using at data point 08 {filter => 2}');
        is($point_09, '[/data/btem/user/level/agreement][/][10][0]',            'check using at data point 09 {filter => 2}');
        is($point_15, '[/data/btem/user/level/agreement][/line/@water][00][2]', 'check using at data point 15 {filter => 2}');
        is($point_18, '[/data/btem/user/level/agreement][/line/@ice][00][2]',   'check using at data point 18 {filter => 2}');
        is($point_19, '[/data/btem/user/level/agreement][/line/@water][00][2]', 'check using at data point 19 {filter => 2}');
        is($point_30, '[/data/item][/beta/gamma][10][2]',                       'check using at data point 30 {filter => 2}');
        is($point_41, '[/data/item][/][01][0]',                                 'check using at data point 41 {filter => 2}');
    }
}

{
    my $line = q{<data />};

    my $output = '';

    my $rdr = XML::Reader->newhd(\$line);
    my $i = 0;
    while ($rdr->iterate) { $i++;
        $output .= '['.$rdr->path.'-'.$rdr->value.']['.$rdr->is_start.$rdr->is_end.']['.$rdr->level.']';
    }
    is($output, '[/data-][11][1]', 'the simplest XML possible');
}

{
    my $line = q{<data id="z" />};

    my $output = '';

    my $rdr = XML::Reader->newhd(\$line);
    my $i = 0;
    while ($rdr->iterate) { $i++;
        $output .= '['.$rdr->path.'-'.$rdr->value.']['.$rdr->is_start.$rdr->is_end.']['.$rdr->level.']';
    }
    is($output, '[/data/@id-z][00][2][/data-][11][1]', 'a simple XML with attribute');
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
        $output .= '['.$rdr->is_start.$rdr->is_end.']';
    }
    is($output, '[10][00][00][00][10][00][00][11][01][01]',
       'filter => 2 for is_start, is_end');
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
                    ']['.$rdr->is_start.$rdr->is_end.']['.$rdr->tag.']['.$rdr->attr.']';

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
    is($point_01, '[/data/item][/][abc][T][11][][]',                                  'check filter=>2 at data point 01');
    is($point_05, '[/data/item][/inner/@id][fff][@][00][@id][id]',                    'check filter=>2 at data point 05');
    is($point_08, '[/data/item][/][][T][01][][]',                                     'check filter=>2 at data point 08');
    is($point_14, '[/data/btem/user/lvl/a][/line/@ice][jjj][@][00][@ice][ice]',       'check filter=>2 at data point 14');
    is($point_15, '[/data/btem/user/lvl/a][/line/@water][def][@][00][@water][water]', 'check filter=>2 at data point 15');
    is($point_16, '[/data/btem/user/lvl/a][/line][go][T][11][line][]',                'check filter=>2 at data point 16');
    is($point_22, '[/data/item][/@ts][vy][@][00][@ts][ts]',                           'check filter=>2 at data point 22');
    is($point_38, '[/data/item][/beta/test][t o][T][11][test][]',                     'check filter=>2 at data point 38');
    is($point_42, '[/data/item][/][][T][01][][]',                                     'check filter=>2 at data point 42');
}

{
    my $line = q{<data>abc<?pi abc?><!-- ttt --></data>};

    my $rdr = XML::Reader->newhd(\$line, {filter => 1});

    my $is_start     = 'z';
    my $is_end       = 'z';
    my $is_decl      = 'z';
    my $is_proc      = 'z';
    my $is_comment   = 'z';
    my $is_text      = 'z';
    my $is_attr      = 'z';
    my $proc_tgt     = 'z';
    my $proc_data    = 'z';
    my $comment      = 'z';
    my $dec_hash     = 'z';
    my $att_hash     = 'z';

    my $path         = undef;

    my $i = 0;
    while ($rdr->iterate) { $i++;
        if ($i ==  1) {
            $is_start     = $rdr->is_start;
            $is_end       = $rdr->is_end;
            $is_decl      = $rdr->is_decl;
            $is_proc      = $rdr->is_proc;
            $is_comment   = $rdr->is_comment;
            $is_text      = $rdr->is_text;
            $is_attr      = $rdr->is_attr;
            $proc_tgt     = $rdr->proc_tgt;
            $proc_data    = $rdr->proc_data;
            $comment      = $rdr->comment;
            $dec_hash     = $rdr->dec_hash;
            $att_hash     = $rdr->att_hash;
            $path         = $rdr->path;
        }
    }
    ok(!defined($is_start),     'method is_start is undef for {filter => 1}');
    ok(!defined($is_end),       'method is_end is undef for {filter => 1}');
    ok(!defined($is_decl),      'method is_decl is undef for {filter => 1}');
    ok(!defined($is_proc),      'method is_proc is undef for {filter => 1}');
    ok(!defined($is_comment),   'method is_comment is undef for {filter => 1}');
    ok(!defined($is_text),      'method is_text is undef for {filter => 1}');
    ok(!defined($is_attr),      'method is_attr is undef for {filter => 1}');
    ok(!defined($proc_tgt),     'method proc_tgt is undef for {filter => 1}');
    ok(!defined($proc_data),    'method proc_data is undef for {filter => 1}');
    ok(!defined($comment),      'method comment is undef for {filter => 1}');
    ok(!defined($dec_hash),     'method dec_hash is undef for {filter => 1}');
    ok(!defined($att_hash),     'method att_hash is undef for {filter => 1}');

    ok(defined($path),          'method path is defined for {filter => 1}');
}

# stress tests

{
    my $len = 10000;

    my $c_tag     = 'ab'.('c' x $len).'de';
    my $c_attr    = 'fg'.('h' x $len).'ij';
    my $c_value   = 'kl'.('m' x $len).'no';
    my $c_text    = 'pq'.('r' x $len).'st';
    my $c_comment = 'uv'.('w' x $len).'xy';
    my $c_pi1     = 'z0'.('1' x $len).'23';
    my $c_pi2     = '45'.('6' x $len).'78';

    my $v_starttag = '?';
    my $v_endtag   = '?';
    my $v_attr     = '?';
    my $v_value    = '?';
    my $v_text     = '?';
    my $v_comment  = '?';
    my $v_pi1      = '?';
    my $v_pi2      = '?';

    my $line = qq{<$c_tag $c_attr='$c_value'> $c_text <?$c_pi1 $c_pi2?> <!-- $c_comment --> </$c_tag>};

    my $rdr = XML::Reader->newhd(\$line, {filter => 4, parse_pi => 1, parse_ct => 1}) or die "Error: $!";

    while ($rdr->iterate) {
        if    ($rdr->is_start)   { $v_starttag = $rdr->tag; }
        elsif ($rdr->is_end)     { $v_endtag   = $rdr->tag; }
        elsif ($rdr->is_proc)    { $v_pi1      = $rdr->proc_tgt;
                                   $v_pi2      = $rdr->proc_data; }
        elsif ($rdr->is_comment) { $v_comment  = $rdr->comment; }
        elsif ($rdr->is_attr)    { $v_attr     = $rdr->attr;
                                   $v_value    = $rdr->value; }
        elsif ($rdr->is_text)    { $v_text     = $rdr->value; }
  }

    is(length($v_starttag), $len + 4, 'length of variable $v_starttag');
    is(length($v_endtag),   $len + 4, 'length of variable $v_endtag');
    is(length($v_attr),     $len + 4, 'length of variable $v_attr');
    is(length($v_value),    $len + 4, 'length of variable $v_value');
    is(length($v_text),     $len + 4, 'length of variable $v_text');
    is(length($v_comment),  $len + 4, 'length of variable $v_comment');
    is(length($v_pi1),      $len + 4, 'length of variable $v_pi1');
    is(length($v_pi2),      $len + 4, 'length of variable $v_pi2');

    is(substr($v_starttag, 0, 3).'...'.substr($v_starttag, -3), 'abc...cde', 'content of variable $v_starttag');
    is(substr($v_endtag,   0, 3).'...'.substr($v_endtag,   -3), 'abc...cde', 'content of variable $v_endtag');
    is(substr($v_attr,     0, 3).'...'.substr($v_attr,     -3), 'fgh...hij', 'content of variable $v_attr');
    is(substr($v_value,    0, 3).'...'.substr($v_value,    -3), 'klm...mno', 'content of variable $v_value');
    is(substr($v_text,     0, 3).'...'.substr($v_text,     -3), 'pqr...rst', 'content of variable $v_text');
    is(substr($v_comment,  0, 3).'...'.substr($v_comment,  -3), 'uvw...wxy', 'content of variable $v_comment');
    is(substr($v_pi1,      0, 3).'...'.substr($v_pi1,      -3), 'z01...123', 'content of variable $v_pi1');
    is(substr($v_pi2,      0, 3).'...'.substr($v_pi2,      -3), '456...678', 'content of variable $v_pi2');
}
