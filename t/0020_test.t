use strict;
use warnings;

use Test::More tests => 112;

use_ok('XML::Reader');

{
    my $text = q{<init><page node="400">m <!-- remark --> r</page></init>};
    my @lines;
    my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";
    while ($rdr->iterate) {
        push @lines, sprintf("Path: %-19s, Value: %s", $rdr->path, $rdr->value);
    }

    is(scalar(@lines), 4,                                  'Pod-Test case no  1: number of output lines');
    is($lines[0], 'Path: /init              , Value: ',    'Pod-Test case no  1: output line  0');
    is($lines[1], 'Path: /init/page/@node   , Value: 400', 'Pod-Test case no  1: output line  1');
    is($lines[2], 'Path: /init/page         , Value: m r', 'Pod-Test case no  1: output line  2');
    is($lines[3], 'Path: /init              , Value: ',    'Pod-Test case no  1: output line  3');
}

{
    my $line1 = q{
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
            push @lines, sprintf("%3d. pat=%-22s, val=%-9s, s=%-1s, i=%-1s, e=%-1s, tag=%-6s, atr=%-6s, t=%-1s, lvl=%2d, c=%s",
             $i, $rdr->path, $rdr->value, $rdr->is_start, $rdr->is_init_attr,
             $rdr->is_end, $rdr->tag, $rdr->attr, $rdr->type, $rdr->level, $rdr->comment);
        }

        is(scalar(@lines), 11,                                                                                                     'Pod-Test case no  2: number of output lines');
        is($lines[ 0], '  1. pat=/data                 , val=         , s=1, i=1, e=0, tag=data  , atr=      , t=T, lvl= 1, c=',   'Pod-Test case no  2: output line  0');
        is($lines[ 1], '  2. pat=/data/item            , val=abc      , s=1, i=1, e=1, tag=item  , atr=      , t=T, lvl= 2, c=',   'Pod-Test case no  2: output line  1');
        is($lines[ 2], '  3. pat=/data                 , val=         , s=0, i=1, e=0, tag=data  , atr=      , t=T, lvl= 1, c=',   'Pod-Test case no  2: output line  2');
        is($lines[ 3], '  4. pat=/data/item            , val=         , s=1, i=1, e=0, tag=item  , atr=      , t=T, lvl= 2, c=c1', 'Pod-Test case no  2: output line  3');
        is($lines[ 4], '  5. pat=/data/item/dummy      , val=         , s=1, i=1, e=1, tag=dummy , atr=      , t=T, lvl= 3, c=',   'Pod-Test case no  2: output line  4');
        is($lines[ 5], '  6. pat=/data/item            , val=fgh      , s=0, i=1, e=0, tag=item  , atr=      , t=T, lvl= 2, c=',   'Pod-Test case no  2: output line  5');
        is($lines[ 6], '  7. pat=/data/item/inner/@id  , val=fff      , s=0, i=1, e=0, tag=@id   , atr=id    , t=@, lvl= 4, c=',   'Pod-Test case no  2: output line  6');
        is($lines[ 7], '  8. pat=/data/item/inner/@name, val=ttt      , s=0, i=0, e=0, tag=@name , atr=name  , t=@, lvl= 4, c=',   'Pod-Test case no  2: output line  7');
        is($lines[ 8], '  9. pat=/data/item/inner      , val=ooo ppp  , s=1, i=0, e=1, tag=inner , atr=      , t=T, lvl= 3, c=c2', 'Pod-Test case no  2: output line  8');
        is($lines[ 9], ' 10. pat=/data/item            , val=         , s=0, i=1, e=1, tag=item  , atr=      , t=T, lvl= 2, c=',   'Pod-Test case no  2: output line  9');
        is($lines[10], ' 11. pat=/data                 , val=         , s=0, i=1, e=1, tag=data  , atr=      , t=T, lvl= 1, c=',   'Pod-Test case no  2: output line 10');
    }

    {
        my $rdr = XML::Reader->newhd(\$line1, {filter => 1}) or die "Error: $!";
        my $i = 0;
        my @lines;
        while ($rdr->iterate) { $i++;
            push @lines, sprintf("%3d. pat=%-22s, val=%-9s, tag=%-6s, atr=%-6s, t=%-1s, lvl=%2d",
             $i, $rdr->path, $rdr->value, $rdr->tag, $rdr->attr, $rdr->type, $rdr->level);
        }

        is(scalar(@lines), 5,                                                                                 'Pod-Test case no  3: number of output lines');
        is($lines[ 0], '  1. pat=/data/item            , val=abc      , tag=item  , atr=      , t=T, lvl= 2', 'Pod-Test case no  3: output line  0');
        is($lines[ 1], '  2. pat=/data/item            , val=fgh      , tag=item  , atr=      , t=T, lvl= 2', 'Pod-Test case no  3: output line  1');
        is($lines[ 2], '  3. pat=/data/item/inner/@id  , val=fff      , tag=@id   , atr=id    , t=@, lvl= 4', 'Pod-Test case no  3: output line  2');
        is($lines[ 3], '  4. pat=/data/item/inner/@name, val=ttt      , tag=@name , atr=name  , t=@, lvl= 4', 'Pod-Test case no  3: output line  3');
        is($lines[ 4], '  5. pat=/data/item/inner      , val=ooo ppp  , tag=inner , atr=      , t=T, lvl= 3', 'Pod-Test case no  3: output line  4');
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
    my $text = q{<root><test param="v"><a><b>e<data id="z">g</data>f</b></a></test>x <!-- remark --> yz</root>};

    {
        my $rdr = XML::Reader->newhd(\$text, {filter => 2}) or die "Error: $!";
        my @lines;
        my %at;
        while ($rdr->iterate) {
            my $indentation = '  ' x $rdr->level;

            if ($rdr->is_init_attr) { %at  = (); }
            if ($rdr->type eq '@')  { $at{$rdr->attr} = $rdr->value; }

            if ($rdr->is_start) {
                push @lines, $indentation.'<'.$rdr->tag.join('', map{" $_='$at{$_}'"} sort keys %at).'>';
            }

            if ($rdr->type eq 'T' and $rdr->value ne '') {
                push @lines, $indentation.'  '.$rdr->value;
            }

            if ($rdr->is_end) {
                push @lines, $indentation.'</'.$rdr->tag.'>';
            }
        }

        is(scalar(@lines), 14,                     'Pod-Test case no  7: number of output lines');
        is($lines[ 0], q{  <root>},                'Pod-Test case no  7: output line  0');
        is($lines[ 1], q{    <test param='v'>},    'Pod-Test case no  7: output line  1');
        is($lines[ 2], q{      <a>},               'Pod-Test case no  7: output line  2');
        is($lines[ 3], q{        <b>},             'Pod-Test case no  7: output line  3');
        is($lines[ 4], q{          e},             'Pod-Test case no  7: output line  4');
        is($lines[ 5], q{          <data id='z'>}, 'Pod-Test case no  7: output line  5');
        is($lines[ 6], q{            g},           'Pod-Test case no  7: output line  6');
        is($lines[ 7], q{          </data>},       'Pod-Test case no  7: output line  7');
        is($lines[ 8], q{          f},             'Pod-Test case no  7: output line  8');
        is($lines[ 9], q{        </b>},            'Pod-Test case no  7: output line  9');
        is($lines[10], q{      </a>},              'Pod-Test case no  7: output line 10');
        is($lines[11], q{    </test>},             'Pod-Test case no  7: output line 11');
        is($lines[12], q{    x yz},                'Pod-Test case no  7: output line 12');
        is($lines[13], q{  </root>},               'Pod-Test case no  7: output line 13');
    }

    {
        my $rdr = XML::Reader->newhd(\$text, {filter => 3}) or die "Error: $!";
        my @lines;
        while ($rdr->iterate) {
            my $indentation = '  ' x $rdr->level;

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

        is(scalar(@lines), 14,                     'Pod-Test case no  8: number of output lines');
        is($lines[ 0], q{  <root>},                'Pod-Test case no  8: output line  0');
        is($lines[ 1], q{    <test param='v'>},    'Pod-Test case no  8: output line  1');
        is($lines[ 2], q{      <a>},               'Pod-Test case no  8: output line  2');
        is($lines[ 3], q{        <b>},             'Pod-Test case no  8: output line  3');
        is($lines[ 4], q{          e},             'Pod-Test case no  8: output line  4');
        is($lines[ 5], q{          <data id='z'>}, 'Pod-Test case no  8: output line  5');
        is($lines[ 6], q{            g},           'Pod-Test case no  8: output line  6');
        is($lines[ 7], q{          </data>},       'Pod-Test case no  8: output line  7');
        is($lines[ 8], q{          f},             'Pod-Test case no  8: output line  8');
        is($lines[ 9], q{        </b>},            'Pod-Test case no  8: output line  9');
        is($lines[10], q{      </a>},              'Pod-Test case no  8: output line 10');
        is($lines[11], q{    </test>},             'Pod-Test case no  8: output line 11');
        is($lines[12], q{    x yz},                'Pod-Test case no  8: output line 12');
        is($lines[13], q{  </root>},               'Pod-Test case no  8: output line 13');
    }
}

{
    my $text = q{<root><test param="v"><a><b>e<data id="z">g</data>f</b></a></test>x <!-- remark --> yz</root>};
    my @lines;
    my $rdr = XML::Reader->newhd(\$text, {filter => 1}) or die "Error: $!";
    while ($rdr->iterate) {
        push @lines, sprintf("Path: %-24s, Value: %s", $rdr->path, $rdr->value);
    }

    is(scalar(@lines), 6,                                         'Pod-Test case no  9: number of output lines');
    is($lines[ 0], 'Path: /root/test/@param       , Value: v',    'Pod-Test case no  9: output line  0');
    is($lines[ 1], 'Path: /root/test/a/b          , Value: e',    'Pod-Test case no  9: output line  1');
    is($lines[ 2], 'Path: /root/test/a/b/data/@id , Value: z',    'Pod-Test case no  9: output line  2');
    is($lines[ 3], 'Path: /root/test/a/b/data     , Value: g',    'Pod-Test case no  9: output line  3');
    is($lines[ 4], 'Path: /root/test/a/b          , Value: f',    'Pod-Test case no  9: output line  4');
    is($lines[ 5], 'Path: /root                   , Value: x yz', 'Pod-Test case no  9: output line  5');
}
