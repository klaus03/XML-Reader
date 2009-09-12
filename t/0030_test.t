use strict;
use warnings;

use Test::More tests => 2;

use_ok('XML::Reader');

{
    $DebCnt::obj = 0;

    my $alpha = XML::Reader->newhd(\'<data>abc</data>', {debug => DebCnt->new});
    my $beta  = XML::Reader->newhd(\'<data>abc</data>', {debug => DebCnt->new});

    for (1..10) {
        my $rdr = XML::Reader->newhd(\'<data>abc</data>', {debug => DebCnt->new});
    }

    is($DebCnt::obj, 2, 'XML::Reader does not leak memory');

}

{
    package DebCnt;

    sub new     { our $obj++; bless {}; }
    sub DESTROY { our $obj--; }
}
