use strict;
use warnings;

use Test::More tests => 29;

use_ok('XML::Reader');

{
    $DebCnt::obj = 0;

    my $alpha = XML::Reader->new(\'<data>abc</data>', {debug => DebCnt->new});
    my $beta  = XML::Reader->new(\'<data>abc</data>', {debug => DebCnt->new});

    for (1..10) {
        my $rdr = XML::Reader->new(\'<data>abc</data>', {debug => DebCnt->new});
    }

    is($DebCnt::obj, 2, 'XML::Reader does not leak memory');
}

is(tresult({filter =>   0                           }), q{[Err]},                                                    'Case 001a: {filter =>   0                         }');
is(tresult({filter =>   1                           }), q{[Err]},                                                    'Case 001b: {filter =>   1                         }');
is(tresult({filter =>   2                           }), q{[Ok]<@p1/a><@p2/b><dummy/><sub/data><dummy/>},             'Case 001c: {filter =>   2                         }');
is(tresult({filter =>   3                           }), q{[Ok]<dummy/><sub/data><dummy/>},                           'Case 001d: {filter =>   3                         }');
is(tresult({filter =>   4                           }), q{[Ok]<dummy/><@p1/a><@p2/b><sub/><sub/data><sub/><dummy/>}, 'Case 001f: {filter =>   4                         }');
is(tresult({filter =>   5                           }), q{[Ok]<dummy/<dummy p1='a' p2='b'><sub>data</sub></dummy>>}, 'Case 001e: {filter =>   5                         }');
is(tresult({filter => 888                           }), q{[Err]},                                                    'Case 001g: {filter => 888                         }');

is(tresult({filter =>   2, mode => 'attr-bef-start*'}), q{[Err]},                                                    'Case 002a: {filter =>   2, mode => attr-bef-start*}');
is(tresult({filter =>   3, mode => 'attr-in-hash*'  }), q{[Err]},                                                    'Case 002b: {filter =>   3, mode => attr-in-hash*  }');
is(tresult({filter =>   4, mode => 'pyx*'           }), q{[Err]},                                                    'Case 002c: {filter =>   4, mode => pyx*           }');
is(tresult({filter =>   5, mode => 'branches*'      }), q{[Err]},                                                    'Case 002d: {filter =>   5, mode => branches*      }');

is(tresult({filter =>   2, mode => 'attr-bef-start' }), q{[Ok]<@p1/a><@p2/b><dummy/><sub/data><dummy/>},             'Case 003a: {filter =>   2, mode => attr-bef-start }');
is(tresult({filter =>   3, mode => 'attr-in-hash'   }), q{[Ok]<dummy/><sub/data><dummy/>},                           'Case 003b: {filter =>   3, mode => attr-in-hash   }');
is(tresult({filter =>   4, mode => 'pyx'            }), q{[Ok]<dummy/><@p1/a><@p2/b><sub/><sub/data><sub/><dummy/>}, 'Case 003c: {filter =>   4, mode => pyx            }');
is(tresult({filter =>   5, mode => 'branches'       }), q{[Ok]<dummy/<dummy p1='a' p2='b'><sub>data</sub></dummy>>}, 'Case 003d: {filter =>   5, mode => branches       }');

is(tresult({               mode => 'attr-bef-start' }), q{[Ok]<@p1/a><@p2/b><dummy/><sub/data><dummy/>},             'Case 004a: {               mode => attr-bef-start }');
is(tresult({               mode => 'attr-in-hash'   }), q{[Ok]<dummy/><sub/data><dummy/>},                           'Case 004b: {               mode => attr-in-hash   }');
is(tresult({               mode => 'pyx'            }), q{[Ok]<dummy/><@p1/a><@p2/b><sub/><sub/data><sub/><dummy/>}, 'Case 004c: {               mode => pyx            }');
is(tresult({               mode => 'branches'       }), q{[Ok]<dummy/<dummy p1='a' p2='b'><sub>data</sub></dummy>>}, 'Case 004d: {               mode => branches       }');

{
    my $data = q{<?xml version="1.0" encoding="iso-8859-1"?><init>n <?test pi?> t<page node="400">m <!-- remark --> r</page></init>};

    {
        my $rdr = XML::Reader->new(\$data, {filter => 5, parse_ct => 0, parse_pi => 0},
          {root => '/init', branch => '*'});
        $rdr->iterate;

        is($rdr->value, q{<init>n t<page node='400'>m r</page></init>},                         'test-branch-001: {parse_ct => 0, parse_pi => 0}');
    }

    {
        my $rdr = XML::Reader->new(\$data, {filter => 5, parse_ct => 1, parse_pi => 0},
          {root => '/init', branch => '*'});
        $rdr->iterate;

        is($rdr->value, q{<init>n t<page node='400'>m<!-- remark -->r</page></init>},           'test-branch-002: {parse_ct => 1, parse_pi => 0}');
    }

    {
        my $rdr = XML::Reader->new(\$data, {filter => 5, parse_ct => 0, parse_pi => 1},
          {root => '/init', branch => '*'});
        $rdr->iterate;

        is($rdr->value, q{<init>n<?test pi?>t<page node='400'>m r</page></init>},               'test-branch-003: {parse_ct => 0, parse_pi => 1}');
    }

    {
        my $rdr = XML::Reader->new(\$data, {filter => 5, parse_ct => 1, parse_pi => 1},
          {root => '/init', branch => '*'});
        $rdr->iterate;

        is($rdr->value, q{<init>n<?test pi?>t<page node='400'>m<!-- remark -->r</page></init>}, 'test-branch-004: {parse_ct => 1, parse_pi => 1}');
    }
}

{
    my $data = q{<?xml version="1.0" encoding="iso-8859-1"?><data/>};
    my $rdr = XML::Reader->new(\$data, {parse_pi => 1});
    my %d; while ($rdr->iterate) { %d = (%d, %{$rdr->dec_hash}); }
    is(join(' ', map {"$_='$d{$_}'"} sort keys %d), q{encoding='iso-8859-1' version='1.0'},                  'test-decl-001: <?xml version="1.0" encoding="iso-8859-1"?>');
}

{
    my $data = q{<?xml version="1.0" standalone="yes"?><data/>};
    my $rdr = XML::Reader->new(\$data, {parse_pi => 1});
    my %d; while ($rdr->iterate) { %d = (%d, %{$rdr->dec_hash}); }
    is(join(' ', map {"$_='$d{$_}'"} sort keys %d), q{standalone='yes' version='1.0'},                       'test-decl-002: <?xml version="1.0" standalone="yes"?>');
}

{
    my $data = q{<?xml version="1.0" standalone="no"?><data/>};
    my $rdr = XML::Reader->new(\$data, {parse_pi => 1});
    my %d; while ($rdr->iterate) { %d = (%d, %{$rdr->dec_hash}); }
    is(join(' ', map {"$_='$d{$_}'"} sort keys %d), q{standalone='no' version='1.0'},                        'test-decl-003: <?xml version="1.0" standalone="no"?>');
}

{
    my $data = q{<?xml version="1.0" encoding="iso-8859-1" standalone="yes"?><data/>};
    my $rdr = XML::Reader->new(\$data, {parse_pi => 1});
    my %d; while ($rdr->iterate) { %d = (%d, %{$rdr->dec_hash}); }
    is(join(' ', map {"$_='$d{$_}'"} sort keys %d), q{encoding='iso-8859-1' standalone='yes' version='1.0'}, 'test-decl-004: <?xml version="1.0" encoding="iso-8859-1" standalone="yes"?>');
}

{
    package DebCnt;

    sub new     { our $obj++; bless {}; }
    sub DESTROY { our $obj--; }
}

sub tresult {
    my ($opt) = @_;

    my $text = q{<dummy p1="a" p2="b"><sub>data</sub></dummy>};

    my $rdr = eval{ XML::Reader->new(\$text, $opt, {root => '/dummy', branch => '*'}) };

    my $output = '['.($@ ? 'Err' : 'Ok').']';

    if ($rdr) {
        while ($rdr->iterate) { $output .= '<'.$rdr->tag.'/'.$rdr->value.'>'; }
    }

    $output;
}
