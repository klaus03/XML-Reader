use strict;
use warnings;

use Test::More tests => 168;

use_ok('XML::Reader');

{
    my $text = q{<init>n <?test pi?> t<page node="400">m <!-- remark --> r</page></init>};
    my @lines;
    my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";
    while ($rdr->iterate) {
        push @lines, sprintf("Path: %-19s, Value: %s", $rdr->path, $rdr->value);
    }

    is(scalar(@lines), 4,                                  'Pod-Test case no  1: number of output lines');
    is($lines[0], 'Path: /init              , Value: n t', 'Pod-Test case no  1: output line  0');
    is($lines[1], 'Path: /init/page/@node   , Value: 400', 'Pod-Test case no  1: output line  1');
    is($lines[2], 'Path: /init/page         , Value: m r', 'Pod-Test case no  1: output line  2');
    is($lines[3], 'Path: /init              , Value: ',    'Pod-Test case no  1: output line  3');
}

{
  my $line1 = 
    q{<?xml version="1.0" encoding="ISO-8859-1"?>
      <data>
        <item>abc</item>
        <item><!-- c1 -->
          <dummy/>
          fgh
          <inner name="ttt" id="fff">
            ooo <!-- c2 --> ppp
          </inner>
        </item>
      </data>
    };

    {
        my $rdr = XML::Reader->newhd(\$line1) or die "Error: $!";
        my $i = 0;
        my @lines;
        while ($rdr->iterate) { $i++;
            push @lines, sprintf("%3d. pat=%-22s, val=%-9s, s=%-1s, e=%-1s, tag=%-6s, atr=%-6s, t=%-1s, lvl=%2d, c=%s",
             $i, $rdr->path, $rdr->value, $rdr->is_start,
             $rdr->is_end, $rdr->tag, $rdr->attr, $rdr->type, $rdr->level, $rdr->comment);
        }

        is(scalar(@lines), 11,                                                                                                     'Pod-Test case no  2: number of output lines');
        is($lines[ 0], '  1. pat=/data                 , val=         , s=1, e=0, tag=data  , atr=      , t=T, lvl= 1, c=',   'Pod-Test case no  2: output line  0');
        is($lines[ 1], '  2. pat=/data/item            , val=abc      , s=1, e=1, tag=item  , atr=      , t=T, lvl= 2, c=',   'Pod-Test case no  2: output line  1');
        is($lines[ 2], '  3. pat=/data                 , val=         , s=0, e=0, tag=data  , atr=      , t=T, lvl= 1, c=',   'Pod-Test case no  2: output line  2');
        is($lines[ 3], '  4. pat=/data/item            , val=         , s=1, e=0, tag=item  , atr=      , t=T, lvl= 2, c=',   'Pod-Test case no  2: output line  3');
        is($lines[ 4], '  5. pat=/data/item/dummy      , val=         , s=1, e=1, tag=dummy , atr=      , t=T, lvl= 3, c=',   'Pod-Test case no  2: output line  4');
        is($lines[ 5], '  6. pat=/data/item            , val=fgh      , s=0, e=0, tag=item  , atr=      , t=T, lvl= 2, c=',   'Pod-Test case no  2: output line  5');
        is($lines[ 6], '  7. pat=/data/item/inner/@id  , val=fff      , s=0, e=0, tag=@id   , atr=id    , t=@, lvl= 4, c=',   'Pod-Test case no  2: output line  6');
        is($lines[ 7], '  8. pat=/data/item/inner/@name, val=ttt      , s=0, e=0, tag=@name , atr=name  , t=@, lvl= 4, c=',   'Pod-Test case no  2: output line  7');
        is($lines[ 8], '  9. pat=/data/item/inner      , val=ooo ppp  , s=1, e=1, tag=inner , atr=      , t=T, lvl= 3, c=',   'Pod-Test case no  2: output line  8');
        is($lines[ 9], ' 10. pat=/data/item            , val=         , s=0, e=1, tag=item  , atr=      , t=T, lvl= 2, c=',   'Pod-Test case no  2: output line  9');
        is($lines[10], ' 11. pat=/data                 , val=         , s=0, e=1, tag=data  , atr=      , t=T, lvl= 1, c=',   'Pod-Test case no  2: output line 10');
    }
}

{
  use XML::Reader;

  my $line2 = q{
    <data>
      <order>
        <database>
          <customer name="aaa" />
          <customer name="bbb" />
          <customer name="ccc" />
          <customer name="ddd" />
        </database>
      </order>
      <dummy value="ttt">test</dummy>
      <supplier>hhh</supplier>
      <supplier>iii</supplier>
      <supplier>jjj</supplier>
    </data>
    };

    {
        my $rdr = XML::Reader->newhd(\$line2,
          {using => ['/data/order/database/customer', '/data/supplier']});
        my $i = 0;
        my @lines;
        while ($rdr->iterate) { $i++;
            push @lines, sprintf("%3d. prf=%-29s, pat=%-7s, val=%-3s, tag=%-6s, t=%-1s, lvl=%2d",
              $i, $rdr->prefix, $rdr->path, $rdr->value, $rdr->tag, $rdr->type, $rdr->level);
        }

        is(scalar(@lines), 11,                                                                                  'Pod-Test case no  4: number of output lines');
        is($lines[ 0], '  1. prf=/data/order/database/customer, pat=/@name , val=aaa, tag=@name , t=@, lvl= 1', 'Pod-Test case no  4: output line  0');
        is($lines[ 1], '  2. prf=/data/order/database/customer, pat=/      , val=   , tag=      , t=T, lvl= 0', 'Pod-Test case no  4: output line  1');
        is($lines[ 2], '  3. prf=/data/order/database/customer, pat=/@name , val=bbb, tag=@name , t=@, lvl= 1', 'Pod-Test case no  4: output line  2');
        is($lines[ 3], '  4. prf=/data/order/database/customer, pat=/      , val=   , tag=      , t=T, lvl= 0', 'Pod-Test case no  4: output line  3');
        is($lines[ 4], '  5. prf=/data/order/database/customer, pat=/@name , val=ccc, tag=@name , t=@, lvl= 1', 'Pod-Test case no  4: output line  4');
        is($lines[ 5], '  6. prf=/data/order/database/customer, pat=/      , val=   , tag=      , t=T, lvl= 0', 'Pod-Test case no  4: output line  5');
        is($lines[ 6], '  7. prf=/data/order/database/customer, pat=/@name , val=ddd, tag=@name , t=@, lvl= 1', 'Pod-Test case no  4: output line  6');
        is($lines[ 7], '  8. prf=/data/order/database/customer, pat=/      , val=   , tag=      , t=T, lvl= 0', 'Pod-Test case no  4: output line  7');
        is($lines[ 8], '  9. prf=/data/supplier               , pat=/      , val=hhh, tag=      , t=T, lvl= 0', 'Pod-Test case no  4: output line  8');
        is($lines[ 9], ' 10. prf=/data/supplier               , pat=/      , val=iii, tag=      , t=T, lvl= 0', 'Pod-Test case no  4: output line  9');
        is($lines[10], ' 11. prf=/data/supplier               , pat=/      , val=jjj, tag=      , t=T, lvl= 0', 'Pod-Test case no  4: output line 10');
    }

    {
        my $rdr = XML::Reader->newhd(\$line2);
        my $i = 0;
        my @lines;
        while ($rdr->iterate) { $i++;
            push @lines, sprintf("%3d. prf=%-1s, pat=%-37s, val=%-6s, tag=%-11s, t=%-1s, lvl=%2d",
              $i, $rdr->prefix, $rdr->path, $rdr->value, $rdr->tag, $rdr->type, $rdr->level);
        }

        is(scalar(@lines), 26,                                                                                            'Pod-Test case no  5: number of output lines');
        is($lines[ 0], '  1. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1', 'Pod-Test case no  5: output line  0');
        is($lines[ 1], '  2. prf= , pat=/data/order                          , val=      , tag=order      , t=T, lvl= 2', 'Pod-Test case no  5: output line  1');
        is($lines[ 2], '  3. prf= , pat=/data/order/database                 , val=      , tag=database   , t=T, lvl= 3', 'Pod-Test case no  5: output line  2');
        is($lines[ 3], '  4. prf= , pat=/data/order/database/customer/@name  , val=aaa   , tag=@name      , t=@, lvl= 5', 'Pod-Test case no  5: output line  3');
        is($lines[ 4], '  5. prf= , pat=/data/order/database/customer        , val=      , tag=customer   , t=T, lvl= 4', 'Pod-Test case no  5: output line  4');
        is($lines[ 5], '  6. prf= , pat=/data/order/database                 , val=      , tag=database   , t=T, lvl= 3', 'Pod-Test case no  5: output line  5');
        is($lines[ 6], '  7. prf= , pat=/data/order/database/customer/@name  , val=bbb   , tag=@name      , t=@, lvl= 5', 'Pod-Test case no  5: output line  6');
        is($lines[ 7], '  8. prf= , pat=/data/order/database/customer        , val=      , tag=customer   , t=T, lvl= 4', 'Pod-Test case no  5: output line  7');
        is($lines[ 8], '  9. prf= , pat=/data/order/database                 , val=      , tag=database   , t=T, lvl= 3', 'Pod-Test case no  5: output line  8');
        is($lines[ 9], ' 10. prf= , pat=/data/order/database/customer/@name  , val=ccc   , tag=@name      , t=@, lvl= 5', 'Pod-Test case no  5: output line  9');
        is($lines[10], ' 11. prf= , pat=/data/order/database/customer        , val=      , tag=customer   , t=T, lvl= 4', 'Pod-Test case no  5: output line 10');
        is($lines[11], ' 12. prf= , pat=/data/order/database                 , val=      , tag=database   , t=T, lvl= 3', 'Pod-Test case no  5: output line 11');
        is($lines[12], ' 13. prf= , pat=/data/order/database/customer/@name  , val=ddd   , tag=@name      , t=@, lvl= 5', 'Pod-Test case no  5: output line 12');
        is($lines[13], ' 14. prf= , pat=/data/order/database/customer        , val=      , tag=customer   , t=T, lvl= 4', 'Pod-Test case no  5: output line 13');
        is($lines[14], ' 15. prf= , pat=/data/order/database                 , val=      , tag=database   , t=T, lvl= 3', 'Pod-Test case no  5: output line 14');
        is($lines[15], ' 16. prf= , pat=/data/order                          , val=      , tag=order      , t=T, lvl= 2', 'Pod-Test case no  5: output line 15');
        is($lines[16], ' 17. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1', 'Pod-Test case no  5: output line 16');
        is($lines[17], ' 18. prf= , pat=/data/dummy/@value                   , val=ttt   , tag=@value     , t=@, lvl= 3', 'Pod-Test case no  5: output line 17');
        is($lines[18], ' 19. prf= , pat=/data/dummy                          , val=test  , tag=dummy      , t=T, lvl= 2', 'Pod-Test case no  5: output line 18');
        is($lines[19], ' 20. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1', 'Pod-Test case no  5: output line 19');
        is($lines[20], ' 21. prf= , pat=/data/supplier                       , val=hhh   , tag=supplier   , t=T, lvl= 2', 'Pod-Test case no  5: output line 20');
        is($lines[21], ' 22. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1', 'Pod-Test case no  5: output line 21');
        is($lines[22], ' 23. prf= , pat=/data/supplier                       , val=iii   , tag=supplier   , t=T, lvl= 2', 'Pod-Test case no  5: output line 22');
        is($lines[23], ' 24. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1', 'Pod-Test case no  5: output line 23');
        is($lines[24], ' 25. prf= , pat=/data/supplier                       , val=jjj   , tag=supplier   , t=T, lvl= 2', 'Pod-Test case no  5: output line 24');
        is($lines[25], ' 26. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1', 'Pod-Test case no  5: output line 25');
    }
}

{
    my $text = q{<root><test param="v"><a><b>e<data id="z">g</data>f</b></a></test>x <!-- remark --> yz</root>};

    my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";
    my @lines;
    while ($rdr->iterate) {
        push @lines, sprintf("Path: %-24s, Value: %s", $rdr->path, $rdr->value);
    }

    is(scalar(@lines), 11,                                        'Pod-Test case no  6: number of output lines');
    is($lines[ 0], 'Path: /root                   , Value: ',     'Pod-Test case no  6: output line  0');
    is($lines[ 1], 'Path: /root/test/@param       , Value: v',    'Pod-Test case no  6: output line  1');
    is($lines[ 2], 'Path: /root/test              , Value: ',     'Pod-Test case no  6: output line  2');
    is($lines[ 3], 'Path: /root/test/a            , Value: ',     'Pod-Test case no  6: output line  3');
    is($lines[ 4], 'Path: /root/test/a/b          , Value: e',    'Pod-Test case no  6: output line  4');
    is($lines[ 5], 'Path: /root/test/a/b/data/@id , Value: z',    'Pod-Test case no  6: output line  5');
    is($lines[ 6], 'Path: /root/test/a/b/data     , Value: g',    'Pod-Test case no  6: output line  6');
    is($lines[ 7], 'Path: /root/test/a/b          , Value: f',    'Pod-Test case no  6: output line  7');
    is($lines[ 8], 'Path: /root/test/a            , Value: ',     'Pod-Test case no  6: output line  8');
    is($lines[ 9], 'Path: /root/test              , Value: ',     'Pod-Test case no  6: output line  9');
    is($lines[10], 'Path: /root                   , Value: x yz', 'Pod-Test case no  6: output line 10');
}

{
    my $text = q{<?xml version="1.0"?><dummy>xyz <!-- remark --> stu <?ab cde?> test</dummy>};

    {
        my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";
        my @lines;
        while ($rdr->iterate) {
            if ($rdr->is_decl)    { my %h = %{$rdr->dec_hash};
                                    push @lines, "Found decl     ".join('', map{" $_='$h{$_}'"} sort keys %h); }
            if ($rdr->is_proc)    { push @lines, "Found proc      "."t=".$rdr->proc_tgt.", d=". $rdr->proc_data; }
            if ($rdr->is_comment) { push @lines, "Found comment   ".$rdr->comment; }
            push @lines, "Text '".$rdr->value."'" unless $rdr->is_decl;
        }

        is(scalar(@lines),  1,                'Pod-Test case no  7: number of output lines');
        is($lines[ 0], "Text 'xyz stu test'", 'Pod-Test case no  7: output line  0');
    }

    {
        my $rdr = XML::Reader->newhd(\$text, {parse_ct => 1}) or die "Error: $!";
        my @lines;
        while ($rdr->iterate) {
            if ($rdr->is_decl)    { my %h = %{$rdr->dec_hash};
                                    push @lines, "Found decl     ".join('', map{" $_='$h{$_}'"} sort keys %h); }
            if ($rdr->is_proc)    { push @lines, "Found proc      "."t=".$rdr->proc_tgt.", d=". $rdr->proc_data; }
            if ($rdr->is_comment) { push @lines, "Found comment   ".$rdr->comment; }
            push @lines, "Text '".$rdr->value."'" unless $rdr->is_decl;
        }

        is(scalar(@lines),  3,                   'Pod-Test case no  8: number of output lines');
        is($lines[ 0], "Text 'xyz'",             'Pod-Test case no  8: output line  0');
        is($lines[ 1], "Found comment   remark", 'Pod-Test case no  8: output line  1');
        is($lines[ 2], "Text 'stu test'",        'Pod-Test case no  8: output line  2');
    }

    {
        my $rdr = XML::Reader->newhd(\$text, {parse_ct => 1, parse_pi => 1}) or die "Error: $!";
        my @lines;
        while ($rdr->iterate) {
            if ($rdr->is_decl)    { my %h = %{$rdr->dec_hash};
                                    push @lines, "Found decl     ".join('', map{" $_='$h{$_}'"} sort keys %h); }
            if ($rdr->is_proc)    { push @lines, "Found proc      "."t=".$rdr->proc_tgt.", d=". $rdr->proc_data; }
            if ($rdr->is_comment) { push @lines, "Found comment   ".$rdr->comment; }
            push @lines, "Text '".$rdr->value."'" unless $rdr->is_decl;
        }

        is(scalar(@lines),  6,                          'Pod-Test case no  9: number of output lines');
        is($lines[ 0], "Found decl      version='1.0'", 'Pod-Test case no  9: output line  0');
        is($lines[ 1], "Text 'xyz'",                    'Pod-Test case no  9: output line  1');
        is($lines[ 2], "Found comment   remark",        'Pod-Test case no  9: output line  2');
        is($lines[ 3], "Text 'stu'",                    'Pod-Test case no  9: output line  3');
        is($lines[ 4], "Found proc      t=ab, d=cde",   'Pod-Test case no  9: output line  4');
        is($lines[ 5], "Text 'test'",                   'Pod-Test case no  9: output line  5');
    }
}

{
    my $text = q{<root><test param="v"><a><b>e<data id="z">g</data>f</b></a></test>x <!-- remark --> yz</root>};

    {
        my $rdr = XML::Reader->newhd(\$text, {filter => 2}) or die "Error: $!";
        my @lines;
        while ($rdr->iterate) {
            push @lines, sprintf "Path: %-24s, Value: %s", $rdr->path, $rdr->value;
        }

        is(scalar(@lines), 11,                                        'Pod-Test case no 10: number of output lines');
        is($lines[ 0], 'Path: /root                   , Value: ',     'Pod-Test case no 10: output line  0');
        is($lines[ 1], 'Path: /root/test/@param       , Value: v',    'Pod-Test case no 10: output line  1');
        is($lines[ 2], 'Path: /root/test              , Value: ',     'Pod-Test case no 10: output line  2');
        is($lines[ 3], 'Path: /root/test/a            , Value: ',     'Pod-Test case no 10: output line  3');
        is($lines[ 4], 'Path: /root/test/a/b          , Value: e',    'Pod-Test case no 10: output line  4');
        is($lines[ 5], 'Path: /root/test/a/b/data/@id , Value: z',    'Pod-Test case no 10: output line  5');
        is($lines[ 6], 'Path: /root/test/a/b/data     , Value: g',    'Pod-Test case no 10: output line  6');
        is($lines[ 7], 'Path: /root/test/a/b          , Value: f',    'Pod-Test case no 10: output line  7');
        is($lines[ 8], 'Path: /root/test/a            , Value: ',     'Pod-Test case no 10: output line  8');
        is($lines[ 9], 'Path: /root/test              , Value: ',     'Pod-Test case no 10: output line  9');
        is($lines[10], 'Path: /root                   , Value: x yz', 'Pod-Test case no 10: output line 10');
    }

    {
        my $rdr = XML::Reader->newhd(\$text, {filter => 2}) or die "Error: $!";
        my @lines;
        my %at;
        while ($rdr->iterate) {
            my $indentation = '  ' x ($rdr->level - 1);

            if ($rdr->type eq '@')  { $at{$rdr->attr} = $rdr->value; }

            if ($rdr->is_start) {
                push @lines, $indentation.'<'.$rdr->tag.join('', map{" $_='$at{$_}'"} sort keys %at).'>';
            }

            if ($rdr->type eq 'T' and $rdr->value ne '') {
                push @lines, $indentation.'  '.$rdr->value;
            }

            unless ($rdr->type eq '@') { %at  = (); }

            if ($rdr->is_end) {
                push @lines, $indentation.'</'.$rdr->tag.'>';
            }
        }

        is(scalar(@lines), 14,                     'Pod-Test case no 11: number of output lines');
        is($lines[ 0], q{<root>},                'Pod-Test case no 11: output line  0');
        is($lines[ 1], q{  <test param='v'>},    'Pod-Test case no 11: output line  1');
        is($lines[ 2], q{    <a>},               'Pod-Test case no 11: output line  2');
        is($lines[ 3], q{      <b>},             'Pod-Test case no 11: output line  3');
        is($lines[ 4], q{        e},             'Pod-Test case no 11: output line  4');
        is($lines[ 5], q{        <data id='z'>}, 'Pod-Test case no 11: output line  5');
        is($lines[ 6], q{          g},           'Pod-Test case no 11: output line  6');
        is($lines[ 7], q{        </data>},       'Pod-Test case no 11: output line  7');
        is($lines[ 8], q{        f},             'Pod-Test case no 11: output line  8');
        is($lines[ 9], q{      </b>},            'Pod-Test case no 11: output line  9');
        is($lines[10], q{    </a>},              'Pod-Test case no 11: output line 10');
        is($lines[11], q{  </test>},             'Pod-Test case no 11: output line 11');
        is($lines[12], q{  x yz},                'Pod-Test case no 11: output line 12');
        is($lines[13], q{</root>},               'Pod-Test case no 11: output line 13');
    }

    {
        my $rdr = XML::Reader->newhd(\$text, {filter => 3}) or die "Error: $!";
        my @lines;
        while ($rdr->iterate) {
            my $indentation = '  ' x ($rdr->level - 1);

            if ($rdr->is_start) {
                my %at = %{$rdr->att_hash};
                push @lines, $indentation.'<'.$rdr->tag.join('', map{" $_='$at{$_}'"} sort keys %at).'>';
            }

            if ($rdr->type eq 'T' and $rdr->value ne '') {
                push @lines, $indentation.'  '.$rdr->value;
            }

            if ($rdr->is_end) {
                push @lines, $indentation.'</'.$rdr->tag.'>';
            }
        }

        is(scalar(@lines), 14,                     'Pod-Test case no 12: number of output lines');
        is($lines[ 0], q{<root>},                'Pod-Test case no 12: output line  0');
        is($lines[ 1], q{  <test param='v'>},    'Pod-Test case no 12: output line  1');
        is($lines[ 2], q{    <a>},               'Pod-Test case no 12: output line  2');
        is($lines[ 3], q{      <b>},             'Pod-Test case no 12: output line  3');
        is($lines[ 4], q{        e},             'Pod-Test case no 12: output line  4');
        is($lines[ 5], q{        <data id='z'>}, 'Pod-Test case no 12: output line  5');
        is($lines[ 6], q{          g},           'Pod-Test case no 12: output line  6');
        is($lines[ 7], q{        </data>},       'Pod-Test case no 12: output line  7');
        is($lines[ 8], q{        f},             'Pod-Test case no 12: output line  8');
        is($lines[ 9], q{      </b>},            'Pod-Test case no 12: output line  9');
        is($lines[10], q{    </a>},              'Pod-Test case no 12: output line 10');
        is($lines[11], q{  </test>},             'Pod-Test case no 12: output line 11');
        is($lines[12], q{  x yz},                'Pod-Test case no 12: output line 12');
        is($lines[13], q{</root>},               'Pod-Test case no 12: output line 13');
    }
}

{
    my $text = q{<?xml version="1.0" encoding="ISO-8859-1"?>
      <delta>
        <dim alter="511">
          <gamma />
          <beta>
            car <?tt dat?>
          </beta>
        </dim>
        dskjfh <!-- remark --> uuu
      </delta>};

    my $rdr = XML::Reader->newhd(\$text, {filter => 4, parse_pi => 1}) or die "Error: $!";
    my @lines;
    while ($rdr->iterate) {
        push @lines, sprintf "Type = %1s, pyx = %s", $rdr->type, $rdr->pyx;
    }

    is(scalar(@lines), 13,                                                     'Pod-Test case no 13: number of output lines');
    is($lines[ 0], "Type = D, pyx = ?xml version='1.0' encoding='ISO-8859-1'", 'Pod-Test case no 13: output line  0');
    is($lines[ 1], "Type = S, pyx = (delta",                                   'Pod-Test case no 13: output line  1');
    is($lines[ 2], "Type = S, pyx = (dim",                                     'Pod-Test case no 13: output line  2');
    is($lines[ 3], "Type = @, pyx = Aalter 511",                               'Pod-Test case no 13: output line  3');
    is($lines[ 4], "Type = S, pyx = (gamma",                                   'Pod-Test case no 13: output line  4');
    is($lines[ 5], "Type = E, pyx = )gamma",                                   'Pod-Test case no 13: output line  5');
    is($lines[ 6], "Type = S, pyx = (beta",                                    'Pod-Test case no 13: output line  6');
    is($lines[ 7], "Type = T, pyx = -car",                                     'Pod-Test case no 13: output line  7');
    is($lines[ 8], "Type = ?, pyx = ?tt dat",                                  'Pod-Test case no 13: output line  8');
    is($lines[ 9], "Type = E, pyx = )beta",                                    'Pod-Test case no 13: output line  9');
    is($lines[10], "Type = E, pyx = )dim",                                     'Pod-Test case no 13: output line 10');
    is($lines[11], "Type = T, pyx = -dskjfh uuu",                              'Pod-Test case no 13: output line 11');
    is($lines[12], "Type = E, pyx = )delta",                                   'Pod-Test case no 13: output line 12');
}

{
    my $text = q{
      <delta>
        <!-- remark -->
      </delta>};

    my $rdr = XML::Reader->newhd(\$text, {filter => 4, parse_ct => 1}) or die "Error: $!";
    my @lines;
    while ($rdr->iterate) {
        push @lines, sprintf "Type = %1s, pyx = %s", $rdr->type, $rdr->pyx;
    }

    is(scalar(@lines),  3,                    'Pod-Test case no 14: number of output lines');
    is($lines[ 0], "Type = S, pyx = (delta",  'Pod-Test case no 14: output line  0');
    is($lines[ 1], "Type = #, pyx = #remark", 'Pod-Test case no 14: output line  1');
    is($lines[ 2], "Type = E, pyx = )delta",  'Pod-Test case no 14: output line  2');
}

{
    my $text = q{<?xml version="1.0"?>
      <parent abc="def"> <?pt hmf?>
        dskjfh <!-- remark -->
        <child>ghi</child>
      </parent>};

    my $rdr = XML::Reader->newhd(\$text, {filter => 4, parse_pi => 1, parse_ct => 1}) or die "Error: $!";
    my @lines;
    while ($rdr->iterate) {
        my $txt = sprintf "Path %-15s v=%s ", $rdr->path, $rdr->is_value;

        if    ($rdr->is_start)   { push @lines, $txt."Found start tag ".$rdr->tag; }
        elsif ($rdr->is_end)     { push @lines, $txt."Found end tag   ".$rdr->tag; }
        elsif ($rdr->is_decl)    { my %h = %{$rdr->dec_hash};
                                   push @lines, $txt."Found decl     ".join('', map{" $_='$h{$_}'"} sort keys %h); }
        elsif ($rdr->is_proc)    { push @lines, $txt."Found proc      "."t=".$rdr->proc_tgt.", d=".$rdr->proc_data; }
        elsif ($rdr->is_comment) { push @lines, $txt."Found comment   ".$rdr->comment; }
        elsif ($rdr->is_attr)    { push @lines, $txt."Found attribute ".$rdr->attr."='".$rdr->value."'"; }
        elsif ($rdr->is_text)    { push @lines, $txt."Found text      ".$rdr->value; }
    }

    is(scalar(@lines),  10,                                                   'Pod-Test case no 15: number of output lines');
    is($lines[ 0], "Path /               " ."v=0 Found decl      version='1.0'",  'Pod-Test case no 15: output line  0');
    is($lines[ 1], "Path /parent         " ."v=0 Found start tag parent",         'Pod-Test case no 15: output line  1');
    is($lines[ 2], "Path /parent/\@abc    "."v=1 Found attribute abc='def'",      'Pod-Test case no 15: output line  2');
    is($lines[ 3], "Path /parent         " ."v=0 Found proc      t=pt, d=hmf",    'Pod-Test case no 15: output line  3');
    is($lines[ 4], "Path /parent         " ."v=1 Found text      dskjfh",         'Pod-Test case no 15: output line  4');
    is($lines[ 5], "Path /parent         " ."v=0 Found comment   remark",         'Pod-Test case no 15: output line  5');
    is($lines[ 6], "Path /parent/child   " ."v=0 Found start tag child",          'Pod-Test case no 15: output line  6');
    is($lines[ 7], "Path /parent/child   " ."v=1 Found text      ghi",            'Pod-Test case no 15: output line  7');
    is($lines[ 8], "Path /parent/child   " ."v=0 Found end tag   child",          'Pod-Test case no 15: output line  8');
    is($lines[ 9], "Path /parent         " ."v=0 Found end tag   parent",         'Pod-Test case no 15: output line  9');
}

{
    my $text = q{
      <start>
        <param>
          <data>
            <item p1="a" p2="b" p3="c">start1 <inner p1="p">i1</inner> end1</item>
            <item p1="d" p2="e" p3="f">start2 <inner p1="q">i2</inner> end2</item>
            <item p1="g" p2="h" p3="i">start3 <inner p1="r">i3</inner> end3</item>
          </data>
          <dataz>
            <item p1="j" p2="k" p3="l">start9 <inner p1="s">i9</inner> end9</item>
          </dataz>
          <data>
            <item p1="m" p2="n" p3="o">start4 <inner p1="t">i4</inner> end4</item>
          </data>
        </param>
      </start>};

    {
        my $rdr = XML::Reader->newhd(\$text,
          {filter => 2, using => '/start/param/data/item'}) or die "Error: $!";
        my @lines;

        my ($p1, $p3);

        while ($rdr->iterate) {
            if    ($rdr->path eq '/@p1') { $p1 = $rdr->value; }
            elsif ($rdr->path eq '/@p3') { $p3 = $rdr->value; }
            elsif ($rdr->path eq '/' and $rdr->is_start) {
                push @lines, sprintf("item = '%s', p1 = '%s', p3 = '%s'",
                  $rdr->value, $p1, $p3);
            }
            unless ($rdr->is_attr) { $p1 = undef; $p3 = undef; }
        }

        is(scalar(@lines),   4,                               'Pod-Test case no 16: number of output lines');
        is($lines[ 0], "item = 'start1', p1 = 'a', p3 = 'c'", 'Pod-Test case no 16: output line  0');
        is($lines[ 1], "item = 'start2', p1 = 'd', p3 = 'f'", 'Pod-Test case no 16: output line  1');
        is($lines[ 2], "item = 'start3', p1 = 'g', p3 = 'i'", 'Pod-Test case no 16: output line  2');
        is($lines[ 3], "item = 'start4', p1 = 'm', p3 = 'o'", 'Pod-Test case no 16: output line  3');
    }

    {
        my $rdr = XML::Reader->newhd(\$text,
          {filter => 3, using => '/start/param/data/item'}) or die "Error: $!";
        my @lines;

        while ($rdr->iterate) {
            if ($rdr->path eq '/' and $rdr->is_start) {
                push @lines, sprintf("item = '%s', p1 = '%s', p3 = '%s'",
                  $rdr->value, $rdr->att_hash->{p1}, $rdr->att_hash->{p3});
            }
        }

        is(scalar(@lines),   4,                               'Pod-Test case no 17: number of output lines');
        is($lines[ 0], "item = 'start1', p1 = 'a', p3 = 'c'", 'Pod-Test case no 17: output line  0');
        is($lines[ 1], "item = 'start2', p1 = 'd', p3 = 'f'", 'Pod-Test case no 17: output line  1');
        is($lines[ 2], "item = 'start3', p1 = 'g', p3 = 'i'", 'Pod-Test case no 17: output line  2');
        is($lines[ 3], "item = 'start4', p1 = 'm', p3 = 'o'", 'Pod-Test case no 17: output line  3');
    }

    {
        my $rdr = XML::Reader->newhd(\$text,
          {filter => 4, using => '/start/param/data/item'}) or die "Error: $!";
        my @lines;

        my ($count, $p1, $p3);

        while ($rdr->iterate) {
            if    ($rdr->path eq '/@p1') { $p1 = $rdr->value; }
            elsif ($rdr->path eq '/@p3') { $p3 = $rdr->value; }
            elsif ($rdr->path eq '/') {
                if    ($rdr->is_start) { $count = 0; $p1 = undef; $p3 = undef; }
                elsif ($rdr->is_text) {
                    $count++;
                    if ($count == 1) {
                        push @lines, sprintf("item = '%s', p1 = '%s', p3 = '%s'",
                          $rdr->value, $p1, $p3);
                    }
                }
            }
        }

        is(scalar(@lines),   4,                               'Pod-Test case no 18: number of output lines');
        is($lines[ 0], "item = 'start1', p1 = 'a', p3 = 'c'", 'Pod-Test case no 18: output line  0');
        is($lines[ 1], "item = 'start2', p1 = 'd', p3 = 'f'", 'Pod-Test case no 18: output line  1');
        is($lines[ 2], "item = 'start3', p1 = 'g', p3 = 'i'", 'Pod-Test case no 18: output line  2');
        is($lines[ 3], "item = 'start4', p1 = 'm', p3 = 'o'", 'Pod-Test case no 18: output line  3');
    }
}
