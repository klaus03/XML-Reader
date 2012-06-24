use strict;
use warnings;

use Test::More tests => 271;

use_ok('XML::Reader', qw(XML::Parsepp slurp_xml));

{
    my $text = q{<init>n <?test pi?> t<page node="400">m <!-- remark --> r</page></init>};
    my @lines;
    my $rdr = XML::Reader->new(\$text) or die "Error: $!";
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
        my $rdr = XML::Reader->new(\$line1) or die "Error: $!";
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
        my $rdr = XML::Reader->new(\$line2,
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
        my $rdr = XML::Reader->new(\$line2);
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

    my $rdr = XML::Reader->new(\$text) or die "Error: $!";
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
        my $rdr = XML::Reader->new(\$text) or die "Error: $!";
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
        my $rdr = XML::Reader->new(\$text, {parse_ct => 1}) or die "Error: $!";
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
        my $rdr = XML::Reader->new(\$text, {parse_ct => 1, parse_pi => 1}) or die "Error: $!";
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
        my $rdr = XML::Reader->new(\$text, {filter => 2}) or die "Error: $!";
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
        my $rdr = XML::Reader->new(\$text, {filter => 2}) or die "Error: $!";
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

        is(scalar(@lines), 14,                   'Pod-Test case no 11: number of output lines');
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
        my $rdr = XML::Reader->new(\$text, {filter => 3}) or die "Error: $!";
        my @lines;
        while ($rdr->iterate) {
            my $indentation = '  ' x ($rdr->level - 1);

            if ($rdr->is_start) {
                push @lines, $indentation.'<'.$rdr->tag.
                  join('', map{" $_='".$rdr->att_hash->{$_}."'"} sort keys %{$rdr->att_hash}).'>';
            }

            if ($rdr->type eq 'T' and $rdr->value ne '') {
                push @lines, $indentation.'  '.$rdr->value;
            }

            if ($rdr->is_end) {
                push @lines, $indentation.'</'.$rdr->tag.'>';
            }
        }

        is(scalar(@lines), 14,                   'Pod-Test case no 12: number of output lines');
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

    my $rdr = XML::Reader->new(\$text, {filter => 4, parse_pi => 1}) or die "Error: $!";
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

    my $rdr = XML::Reader->new(\$text, {filter => 4, parse_ct => 1}) or die "Error: $!";
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

    my $rdr = XML::Reader->new(\$text, {filter => 4, parse_pi => 1, parse_ct => 1}) or die "Error: $!";
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

    is(scalar(@lines),  10,                                                       'Pod-Test case no 15: number of output lines');
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
        my $rdr = XML::Reader->new(\$text,
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
        my $rdr = XML::Reader->new(\$text,
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
        my $rdr = XML::Reader->new(\$text,
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

{
    my $line2 = q{
    <data>
      <supplier>ggg</supplier>
      <supplier>hhh</supplier>
      <order>
        <database>
          <customer name="smith" id="652">
            <street>high street</street>
            <city>boston</city>
          </customer>
          <customer name="jones" id="184">
            <street>maple street</street>
            <city>new york</city>
          </customer>
          <customer name="stewart" id="520">
            <street>ring road</street>
            <city>dallas</city>
          </customer>
        </database>
      </order>
      <dummy value="ttt">test</dummy>
      <supplier>iii</supplier>
      <supplier>jjj</supplier>
    </data>
    };

    my $aref = slurp_xml(\$line2,
      { root => '/data/order/database/customer', branch => ['/@name', '/street', '/city'] },
      { root => '/data/supplier',                branch => ['/']                          },
    );

    my @lines;

    for (@{$aref->[0]}) {
        push @lines, sprintf("Cust: Name = %-7s Street = %-12s City = %s", $_->[0], $_->[1], $_->[2]);
    }

    for (@{$aref->[1]}) {
        push @lines, sprintf("Supp: Name = %s", $_->[0]);
    }

    is(scalar(@lines),   7,                                                      'Pod-Test case no 19: number of output lines');
    is($lines[ 0], "Cust: Name = smith   Street = high street  City = boston",   'Pod-Test case no 19: output line  0');
    is($lines[ 1], "Cust: Name = jones   Street = maple street City = new york", 'Pod-Test case no 19: output line  1');
    is($lines[ 2], "Cust: Name = stewart Street = ring road    City = dallas",   'Pod-Test case no 19: output line  2');
    is($lines[ 3], "Supp: Name = ggg",                                           'Pod-Test case no 19: output line  3');
    is($lines[ 4], "Supp: Name = hhh",                                           'Pod-Test case no 19: output line  4');
    is($lines[ 5], "Supp: Name = iii",                                           'Pod-Test case no 19: output line  5');
    is($lines[ 6], "Supp: Name = jjj",                                           'Pod-Test case no 19: output line  6');
}

{
    my $line2 = q{
    <data>
      <supplier>ggg</supplier>
      <supplier>hhh</supplier>
      <order>
        <database>
          <customer name="smith" id="652">
            <street>high street</street>
            <city>boston</city>
          </customer>
          <customer name="jones" id="184">
            <street>maple street</street>
            <city>new york</city>
          </customer>
          <customer name="stewart" id="520">
            <street>ring road</street>
            <city>dallas</city>
          </customer>
        </database>
      </order>
      <dummy value="ttt">test</dummy>
      <supplier>iii</supplier>
      <supplier>jjj</supplier>
    </data>
    };

    my $rdr = XML::Reader->new(\$line2, {filter => 5},
      { root => '/data/order/database/customer', branch => ['/@name', '/street', '/city'] },
      { root => '/data/supplier',                branch => ['/']                          },
    );

    my @lines;

    while ($rdr->iterate) {
        if ($rdr->rx == 0) {
            for ($rdr->rvalue) {
                push @lines, sprintf("Cust: Name = %-7s Street = %-12s City = %s", $_->[0], $_->[1], $_->[2]);
            }
        }
        elsif ($rdr->rx == 1) {
            for ($rdr->rvalue) {
                push @lines, sprintf("Supp: Name = %s", $_->[0]);
            }
        }
    }

    is(scalar(@lines),   7,                                                      'Pod-Test case no 20: number of output lines');
    is($lines[ 0], "Supp: Name = ggg",                                           'Pod-Test case no 20: output line  0');
    is($lines[ 1], "Supp: Name = hhh",                                           'Pod-Test case no 20: output line  1');
    is($lines[ 2], "Cust: Name = smith   Street = high street  City = boston",   'Pod-Test case no 20: output line  2');
    is($lines[ 3], "Cust: Name = jones   Street = maple street City = new york", 'Pod-Test case no 20: output line  3');
    is($lines[ 4], "Cust: Name = stewart Street = ring road    City = dallas",   'Pod-Test case no 20: output line  4');
    is($lines[ 5], "Supp: Name = iii",                                           'Pod-Test case no 20: output line  5');
    is($lines[ 6], "Supp: Name = jjj",                                           'Pod-Test case no 20: output line  6');
}

# Pod-Test case no 21: for XML-Reader ver 0.33 (25 Apr 2010), test for {filter => 5}:
#   - you can now have duplicate roots (which was not possible before)
#   - allow branch => '*' which will effectively collect all events and construct a sub-tree in XML format
#   - allow relative roots, such as 'tag1/tag2' or '//tag1/tag2'
#     that XML-format has the correct translations
#       + < into &lt;
#       + > into &gt;
#       + & into &amp;
#       + ' into &apos;
#       + " into &quot;

{
    my $line2 = q{
    <data>
      <supplier>ggg</supplier>
      <customer name="o'rob" id="444">
        <street>pod alley</street>
        <city>no city</city>
      </customer>
      <zcustomer name="ggg" id="842">
        <street>uuu</street>
        <city>rrr</city>
      </zcustomer>
      <customerz name="nnn" id="88">
        <street>oo</street>
        <city>yy</city>
      </customerz>
      <section>
        <tcustomer name="troy">
          <street>on</street>
          <city>rr</city>
        </tcustomer>
        <tcustomer id="44">
          <street></street>
          <city> </city>
        </tcustomer>
      </section>
      <section9>
        <tcustomer>
          <d1>f</d1>
          <d2>g</d2>
        </tcustomer>
        <tcustomer z="">
          <d1></d1>
          <d2> </d2>
        </tcustomer>
      </section9>
      <section>
        <tcustomer name="" />
        <tcustomer name="nb" id5="33">
          <street>aw</street>
          <city>ac</city>
        </tcustomer>
        <tcustomer name="john" id5="33">
          <city>abc</city>
        </tcustomer>
        <tcustomer name="bob" id1="22">
          <street>sn</street>
        </tcustomer>
      </section>
      <supplier>hhh</supplier>
      <zzz>
        <customer name='"sue"' id="111">
          <street>baker street</street>
          <city>sidney</city>
        </customer>
      </zzz>
      <order>
        <database>
          <customer name="&lt;smith&gt;" id="652">
            <street>high street</street>
            <city>boston</city>
          </customer>
          <customer name="&amp;jones" id="184">
            <street>maple street</street>
            <city>new york</city>
          </customer>
          <customer name="stewart" id="520">
            <street>  ring   road   </street>
            <city>  "'&amp;&lt;&#65;&gt;'"  </city>
          </customer>
        </database>
      </order>
      <dummy value="ttt">test</dummy>
      <supplier>iii</supplier>
      <supplier>jjj</supplier>
    </data>
    };

    {
        my $rdr = XML::Reader->new(\$line2, {filter => 5},
          { root => 'customer',       branch => ['/@name', '/street', '/city'] },
          { root => '/data/supplier', branch => ['/']                          },
          { root => '//customer',     branch => '*' },
          { root => '//customer',     branch => '**' },
          { root => '//customer',     branch => '+' },
        );

        my @stm0;
        my @stm1;
        my @stm2;

        my @lin0;
        my @lin1;
        my @lin2;
        my @lin3;
        my @lin4;

        my @lrv0;
        my @lrv2;

        while ($rdr->iterate) {
            if ($rdr->rx == 0) {
                push @stm0, $rdr->path;
                for ($rdr->rvalue) {
                     push @lin0, sprintf("Cust: Name = %-7s Street = %-12s City = %s", $_->[0], $_->[1], $_->[2]);
                }
                my @rv = $rdr->value;
                push @lrv0, sprintf("C-rv: Name = %-7s Street = %-12s City = %s", $rv[0], $rv[1], $rv[2]);
            }
            elsif ($rdr->rx == 1) {
                push @stm1, $rdr->path;
                for ($rdr->rvalue) {
                    push @lin1, sprintf("Supp: Name = %s", $_->[0]);
                }
            }
            elsif ($rdr->rx == 2) {
                push @stm2, $rdr->path;
                for ($rdr->rvalue) {
                    push @lin2, $_;
                }
                push @lrv2, $rdr->value;
            }
            elsif ($rdr->rx == 3) {
                for ($rdr->rvalue) {
                    push @lin3, $_;
                }
            }
            elsif ($rdr->rx == 4) {
                for ($rdr->rvalue) {
                    local $" = "', '";
                    push @lin4, "Pyx: '@$_'";
                }
            }
        }

        is(scalar(@stm0),   5,                          'Pod-Test case no 21-a: number of stems');
        is($stm0[ 0], q{/data/customer},                'Pod-Test case no 21-a: stem  0');
        is($stm0[ 1], q{/data/zzz/customer},            'Pod-Test case no 21-a: stem  1');
        is($stm0[ 2], q{/data/order/database/customer}, 'Pod-Test case no 21-a: stem  2');
        is($stm0[ 3], q{/data/order/database/customer}, 'Pod-Test case no 21-a: stem  3');
        is($stm0[ 4], q{/data/order/database/customer}, 'Pod-Test case no 21-a: stem  4');

        is(scalar(@stm1),   4,           'Pod-Test case no 21-b: number of stems');
        is($stm1[ 0], q{/data/supplier}, 'Pod-Test case no 21-b: stem  0');
        is($stm1[ 1], q{/data/supplier}, 'Pod-Test case no 21-b: stem  1');
        is($stm1[ 2], q{/data/supplier}, 'Pod-Test case no 21-b: stem  2');
        is($stm1[ 3], q{/data/supplier}, 'Pod-Test case no 21-b: stem  3');

        is(scalar(@stm2),   5,                          'Pod-Test case no 21-c: number of stems');
        is($stm2[ 0], q{/data/customer},                'Pod-Test case no 21-c: stem  0');
        is($stm2[ 1], q{/data/zzz/customer},            'Pod-Test case no 21-c: stem  1');
        is($stm2[ 2], q{/data/order/database/customer}, 'Pod-Test case no 21-c: stem  2');
        is($stm2[ 3], q{/data/order/database/customer}, 'Pod-Test case no 21-c: stem  3');
        is($stm2[ 4], q{/data/order/database/customer}, 'Pod-Test case no 21-c: stem  4');

        is(scalar(@lin0),   5,                                                       'Pod-Test case no 21-d: number of output lines');
        is($lin0[ 0], q{Cust: Name = o'rob   Street = pod alley    City = no city},  'Pod-Test case no 21-d: output line  0');
        is($lin0[ 1], q{Cust: Name = "sue"   Street = baker street City = sidney},   'Pod-Test case no 21-d: output line  1');
        is($lin0[ 2], q{Cust: Name = <smith> Street = high street  City = boston},   'Pod-Test case no 21-d: output line  2');
        is($lin0[ 3], q{Cust: Name = &jones  Street = maple street City = new york}, 'Pod-Test case no 21-d: output line  3');
        is($lin0[ 4], q{Cust: Name = stewart Street = ring road    City = "'&<A>'"}, 'Pod-Test case no 21-d: output line  4');

        is(scalar(@lin1),   4,                                                       'Pod-Test case no 21-e: number of output lines');
        is($lin1[ 0], q{Supp: Name = ggg},                                           'Pod-Test case no 21-e: output line  0');
        is($lin1[ 1], q{Supp: Name = hhh},                                           'Pod-Test case no 21-e: output line  1');
        is($lin1[ 2], q{Supp: Name = iii},                                           'Pod-Test case no 21-e: output line  2');
        is($lin1[ 3], q{Supp: Name = jjj},                                           'Pod-Test case no 21-e: output line  3');

        is(scalar(@lin2),   5, 'Pod-Test case no 21-f: number of output lines');

        is($lin2[ 0],
            q{<customer id='444' name='o&apos;rob'>}.
              q{<street>pod alley</street>}.
              q{<city>no city</city>}.
            q{</customer>},
          'Pod-Test case no 21-f: output line  0');

        is($lin2[ 1],
            q{<customer id='111' name='"sue"'>}.
              q{<street>baker street</street>}.
              q{<city>sidney</city>}.
            q{</customer>},
          'Pod-Test case no 21-f: output line  1');

        is($lin2[ 2],
            q{<customer id='652' name='&lt;smith&gt;'>}.
              q{<street>high street</street>}.
              q{<city>boston</city>}.
            q{</customer>},
          'Pod-Test case no 21-f: output line  2');

        is($lin2[ 3],
            q{<customer id='184' name='&amp;jones'>}.
              q{<street>maple street</street>}.
              q{<city>new york</city>}.
            q{</customer>},
          'Pod-Test case no 21-f: output line  3');

        is($lin2[ 4],
            q{<customer id='520' name='stewart'>}.
              q{<street>ring road</street>}.
              q{<city>"'&amp;&lt;A&gt;'"</city>}.
            q{</customer>},
          'Pod-Test case no 21-f: output line  4');

        is(scalar(@lin3),   5, 'Pod-Test case no 21-g: number of output lines');

        is($lin3[ 0], undef, 'Pod-Test case no 21-g: output line  0');
        is($lin3[ 1], undef, 'Pod-Test case no 21-g: output line  1');
        is($lin3[ 2], undef, 'Pod-Test case no 21-g: output line  2');
        is($lin3[ 3], undef, 'Pod-Test case no 21-g: output line  3');
        is($lin3[ 4], undef, 'Pod-Test case no 21-g: output line  4');


        is(scalar(@lrv0),   5,                                                       'Pod-Test case no 21-h: number of output lines');
        is($lrv0[ 0], q{C-rv: Name = o'rob   Street = pod alley    City = no city},  'Pod-Test case no 21-h: output line  0');
        is($lrv0[ 1], q{C-rv: Name = "sue"   Street = baker street City = sidney},   'Pod-Test case no 21-h: output line  1');
        is($lrv0[ 2], q{C-rv: Name = <smith> Street = high street  City = boston},   'Pod-Test case no 21-h: output line  2');
        is($lrv0[ 3], q{C-rv: Name = &jones  Street = maple street City = new york}, 'Pod-Test case no 21-h: output line  3');
        is($lrv0[ 4], q{C-rv: Name = stewart Street = ring road    City = "'&<A>'"}, 'Pod-Test case no 21-h: output line  4');

        is(scalar(@lrv2),   5, 'Pod-Test case no 21-i: number of output lines');

        is($lrv2[ 0],
            q{<customer id='444' name='o&apos;rob'>}.
              q{<street>pod alley</street>}.
              q{<city>no city</city>}.
            q{</customer>},
          'Pod-Test case no 21-i: output line  0');

        is($lrv2[ 1],
            q{<customer id='111' name='"sue"'>}.
              q{<street>baker street</street>}.
              q{<city>sidney</city>}.
            q{</customer>},
          'Pod-Test case no 21-i: output line  1');

        is($lrv2[ 2],
            q{<customer id='652' name='&lt;smith&gt;'>}.
              q{<street>high street</street>}.
              q{<city>boston</city>}.
            q{</customer>},
          'Pod-Test case no 21-i: output line  2');

        is($lrv2[ 3],
            q{<customer id='184' name='&amp;jones'>}.
              q{<street>maple street</street>}.
              q{<city>new york</city>}.
            q{</customer>},
          'Pod-Test case no 21-i: output line  3');

        is($lrv2[ 4],
            q{<customer id='520' name='stewart'>}.
              q{<street>ring road</street>}.
              q{<city>"'&amp;&lt;A&gt;'"</city>}.
            q{</customer>},
          'Pod-Test case no 21-i: output line  4');

        is(scalar(@lin4),   5, 'Pod-Test case no 21-j: number of output lines');

        is($lin4[ 0],
            q{Pyx: }.
            q{'(customer', }.
            q{'Aid 444', }.
            q{'Aname o'rob', }.
            q{'(street', }.
            q{'-pod alley', }.
            q{')street', }.
            q{'(city', }.
            q{'-no city', }.
            q{')city', }.
            q{')customer'},
          'Pod-Test case no 21-j: output line  0');

        is($lin4[ 1],
            q{Pyx: }.
            q{'(customer', }.
            q{'Aid 111', }.
            q{'Aname "sue"', }.
            q{'(street', }.
            q{'-baker street', }.
            q{')street', }.
            q{'(city', }.
            q{'-sidney', }.
            q{')city', }.
            q{')customer'},
          'Pod-Test case no 21-j: output line  1');

        is($lin4[ 2],
            q{Pyx: }.
            q{'(customer', }.
            q{'Aid 652', }.
            q{'Aname <smith>', }.
            q{'(street', }.
            q{'-high street', }.
            q{')street', }.
            q{'(city', }.
            q{'-boston', }.
            q{')city', }.
            q{')customer'},
          'Pod-Test case no 21-j: output line  2');

        is($lin4[ 3],
            q{Pyx: }.
            q{'(customer', }.
            q{'Aid 184', }.
            q{'Aname &jones', }.
            q{'(street', }.
            q{'-maple street', }.
            q{')street', }.
            q{'(city', }.
            q{'-new york', }.
            q{')city', }.
            q{')customer'},
          'Pod-Test case no 21-j: output line  3');

        is($lin4[ 4],
            q{Pyx: }.
            q{'(customer', }.
            q{'Aid 520', }.
            q{'Aname stewart', }.
            q{'(street', }.
            q{'-ring road', }.
            q{')street', }.
            q{'(city', }.
            q{'-"'&<A>'"', }.
            q{')city', }.
            q{')customer'},
          'Pod-Test case no 21-j: output line  4');
    }

    {
        my $rdr = XML::Reader->new(\$line2, {filter => 5, sepchar => ' ! '},
          { root => '/data/section', branch => [
            '/tcustomer/@name',
            '/tcustomer/@id',
            '/tcustomer/street',
            '/tcustomer/city',
          ] },
        );

        my @l_name;
        my @l_id;
        my @l_street;
        my @l_city;

        while ($rdr->iterate) {
            my ($name, $id, $street, $city) = $rdr->value;
            for ($name, $id, $street, $city) { $_ = '*undef*' unless defined $_; }

            push @l_name,   $name;
            push @l_id,     $id;
            push @l_street, $street;
            push @l_city,   $city;
        }

        is(scalar(@l_name),   2,                  'Pod-Test case no 21-k: l_name   - number of output lines');
        is($l_name[ 0],   q{troy},                'Pod-Test case no 21-k: l_name   - output line  0');
        is($l_name[ 1],   q{ ! nb ! john ! bob},  'Pod-Test case no 21-k: l_name   - output line  1');

        is(scalar(@l_id),     2,                  'Pod-Test case no 21-k: l_id     - number of output lines');
        is($l_id[ 0],     q{44},                  'Pod-Test case no 21-k: l_id     - output line  0');
        is($l_id[ 1],     q{*undef*},             'Pod-Test case no 21-k: l_id     - output line  1');

        is(scalar(@l_street), 2,                  'Pod-Test case no 21-k: l_street - number of output lines');
        is($l_street[ 0], q{on},                  'Pod-Test case no 21-k: l_street - output line  0');
        is($l_street[ 1], q{aw ! sn},             'Pod-Test case no 21-k: l_street - output line  1');

        is(scalar(@l_city),   2,                  'Pod-Test case no 21-k: l_city   - number of output lines');
        is($l_city[ 0],   q{rr},                  'Pod-Test case no 21-k: l_city   - output line  0');
        is($l_city[ 1],   q{ac ! abc},            'Pod-Test case no 21-k: l_city   - output line  1');
    }

    {
        my $rdr = XML::Reader->new(\$line2, {filter => 5}, # ... the same as the previous case, except here is no {sepchar => }
          { root => '/data/section', branch => [
            '/tcustomer/@name',
            '/tcustomer/@id',
            '/tcustomer/street',
            '/tcustomer/city',
          ] },
        );

        my @l_name;
        my @l_id;
        my @l_street;
        my @l_city;

        while ($rdr->iterate) {
            my ($name, $id, $street, $city) = $rdr->value;
            for ($name, $id, $street, $city) { $_ = '*undef*' unless defined $_; }

            push @l_name,   $name;
            push @l_id,     $id;
            push @l_street, $street;
            push @l_city,   $city;
        }

        is(scalar(@l_name),   2,               'Pod-Test case no 21-l: l_name   - number of output lines');
        is($l_name[ 0],   q{troy},             'Pod-Test case no 21-l: l_name   - output line  0');
        is($l_name[ 1],   q{nbjohnbob},        'Pod-Test case no 21-l: l_name   - output line  1');

        is(scalar(@l_id),     2,               'Pod-Test case no 21-l: l_id     - number of output lines');
        is($l_id[ 0],     q{44},               'Pod-Test case no 21-l: l_id     - output line  0');
        is($l_id[ 1],     q{*undef*},          'Pod-Test case no 21-l: l_id     - output line  1');

        is(scalar(@l_street), 2,               'Pod-Test case no 21-l: l_street - number of output lines');
        is($l_street[ 0], q{on},               'Pod-Test case no 21-l: l_street - output line  0');
        is($l_street[ 1], q{awsn},             'Pod-Test case no 21-l: l_street - output line  1');

        is(scalar(@l_city),   2,               'Pod-Test case no 21-l: l_city   - number of output lines');
        is($l_city[ 0],   q{rr},               'Pod-Test case no 21-l: l_city   - output line  0');
        is($l_city[ 1],   q{acabc},            'Pod-Test case no 21-l: l_city   - output line  1');
    }

    {
        my $rdr_strip_0 = XML::Reader->new(\$line2, {filter => 5, sepchar => '*', strip => 0},
          { root => '/data/section9', branch => [
            '/tcustomer/@y',
            '/tcustomer/@z',
            '/tcustomer/d1',
            '/tcustomer/d2',
          ] },
        );

        my $txt_strip_0 = '';
        while ($rdr_strip_0->iterate) {
            my ($y, $z, $d1, $d2) = $rdr_strip_0->value;
            for ($y, $z, $d1, $d2) { $_ = '?' unless defined $_; }
            $txt_strip_0 .= "[y='$y', z='$z', d1='$d1', d2='$d2']";
        }

        my $rdr_strip_1 = XML::Reader->new(\$line2, {filter => 5, sepchar => '*', strip => 1},
          { root => '/data/section9', branch => [
            '/tcustomer/@y',
            '/tcustomer/@z',
            '/tcustomer/d1',
            '/tcustomer/d2',
          ] },
        );

        my $txt_strip_1 = '';
        while ($rdr_strip_1->iterate) {
            my ($y, $z, $d1, $d2) = $rdr_strip_1->value;
            for ($y, $z, $d1, $d2) { $_ = '?' unless defined $_; }
            $txt_strip_1 .= "[y='$y', z='$z', d1='$d1', d2='$d2']";
        }

        is($txt_strip_0, q{[y='?', z='', d1='f', d2='g}.q{* }.q{']}, 'Pod-Test case no 21-n: txt_strip_0');
        is($txt_strip_1, q{[y='?', z='', d1='f', d2='g}.      q{']}, 'Pod-Test case no 21-n: txt_strip_1');
    }
}

{
    my $line2 = q{
    <data>
      <p>
        <p>b1</p>
        <p>b2</p>
      </p>
      <p>
        b3
      </p>
    </data>
    };

    my $rdr = XML::Reader->new(\$line2, {filter => 5},
      { root => 'p', branch => '*' },
    );

    my @lines;

    while ($rdr->iterate) {
        push @lines, $rdr->value;
    }

    is(scalar(@lines),   2,                      'Pod-Test case no 22: number of lines');
    is($lines[ 0], q{<p><p>b1</p><p>b2</p></p>}, 'Pod-Test case no 22: line  0');
    is($lines[ 1], q{<p>b3</p>},                 'Pod-Test case no 22: line  1');
}
