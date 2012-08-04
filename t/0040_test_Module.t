use strict;
use warnings;

use Test::More tests => 18;

use_ok('XML::Reader');

{
    XML::Reader::activate('XML::Parsepp');

    my ($errflag, @result) = test_func(q{<data><item a2="abc" a1="def" a2="ghi"></item></data>}, {dupatt => '|'});

    is($errflag, '',                    'Test-D010-0010: no error');
    is(scalar(@result), 5,              'Test-D010-0020: Find 5 elements');
    is($result[ 0], '<data:>',          'Test-D010-0030: Check element');
    is($result[ 1], '<@a1:def>',        'Test-D010-0040: Check element');
    is($result[ 2], '<@a2:abc|ghi>',    'Test-D010-0050: Check element');
    is($result[ 3], '<item:>',          'Test-D010-0060: Check element');
    is($result[ 4], '<data:>',          'Test-D010-0070: Check element');
}

{
    XML::Reader::activate('XML::Parsepp');

    my ($errflag, @result) = test_func(q{<data><item a2="abc" a1="def" a2="ghi"></item></data>}, {dupatt => 'é'});

    like($errflag, qr{invalid \s dupatt}xms, 'Test-D012-0010: error');
    is(scalar(@result), 0,                       'Test-D012-0020: Find 0 elements');
}

{
    XML::Reader::activate('XML::Parsepp');

    my ($errflag, @result) = test_func(q{<data><item a2="abc" a1="def" a2="ghi"></item></data>}, {dupatt => 'a'});

    like($errflag, qr{invalid \s dupatt}xms, 'Test-D013-0010: error');
    is(scalar(@result), 0,                       'Test-D013-0020: Find 0 elements');
}

{
    XML::Reader::activate('XML::Parsepp');

    my ($errflag, @result) = test_func(q{<data><item a2="abc" a1="def" a2="ghi"></item></data>}, {dupatt => q{'}});

    like($errflag, qr{invalid \s dupatt}xms, 'Test-D014-0010: error');
    is(scalar(@result), 0,                       'Test-D014-0020: Find 0 elements');
}

{
    XML::Reader::activate('XML::Parsepp');

    my ($errflag, @result) = test_func(q{<data><item a2="abc" a1="def" a2="ghi"></item></data>}, {dupatt => q{"}});

    like($errflag, qr{invalid \s dupatt}xms, 'Test-D015-0010: error');
    is(scalar(@result), 0,                       'Test-D015-0020: Find 0 elements');
}

{
    XML::Reader::activate('XML::Parser');

    my ($errflag, @result) = test_func(q{<data><item a2="abc" a1="def" a2="ghi"></item></data>}, {dupatt => '|'});

    like($errflag, qr{Failed \s assertion \s \#0035 \s in \s XML::Reader->new:}xms,    'Test-D020-0010: error');
    is(scalar(@result), 0,                         'Test-D020-0020: Find 0 elements');
}

sub test_func {
    my ($text, $opt) = @_;

    my $err = '';
    my @res;

    eval {
        my $rdr = XML::Reader->new(\$text, $opt);

        while ($rdr->iterate) { push @res, '<'.$rdr->tag.':'.$rdr->value.'>'; }
    };

    if ($@) {
        $err = $@;
        $err =~ s{\s+}' 'xmsg;
        $err =~ s{\A \s+}''xms;
        $err =~ s{\s+ \z}''xms;
    }

    return ($err, @res);
}
