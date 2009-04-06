package XML::Reader;

use strict;
use warnings;

use XML::Parser;

require Exporter;

our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ( all => [ qw() ] );
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT      = qw();
our $VERSION     = '0.09';

sub new {
    my $class = shift;
    my $self = {};

    my %opt = (strip => 1, filter => 0);
    %opt    = (%opt, %{$_[1]}) if defined $_[1];

    my $XmlParser = XML::Parser->new
      or die "Failed assertion #0010 in subroutine XML::Reader->new: Can't create XML::Parser->new";

    # The following references to the handler-functions from the XML::Parser object will be 
    # copied into the ExpatNB object during the later call to XML::Parser->parse_start.

    $XmlParser->setHandlers(
        Start   => \&handle_start,
        End     => \&handle_end,
        Char    => \&handle_char,
        Comment => \&handle_comment,
    );

    # We are trying to open the file (the filename is held in in $_[0]). If the filename
    # happens to be a reference to a scalar, then it is opened quite naturally as an
    # 'in-memory-file'. If the open fails, then we return failure from XML::Reader->new
    # and the calling program has to check $! to handle the failed call.

    open my $fh, '<', $_[0] or return;

    # Now we bless into XML::Reader, and we bless *before* creating the ExpatNB-object.
    # Thereby, to avoid a memory leak, we ensure that for each ExpatNB-object we call
    # XML::Reader->DESTROY when the object goes away. (-- by the way, we create that
    # ExpatNB-object by calling the XML::Parser->parse_start method --)

    bless $self, $class;

    # Now we are ready to call XML::Parser->parse_start -- XML::Parser->parse_start()
    # returns an object of type XML::Parser::ExpatNB. The XML::Parser::ExpatNB object
    # is where all the heavy lifting happens.

    # By calling the XML::Parser::Expat->new method (-- XML::Parser::Expat is a super-class
    # of XML::Parser::ExpatNB --) we will have created a circular reference in
    # $self->{ExpatNB}{parser}.
    #
    # (-- unfortunately, the circular reference does not show up in Data::Dumper, there
    # is just an integer in $self->{ExpatNB}{parser} that represents a data-structure
    # within the C-function ParserCreate() --).
    #
    # See also the following line of code taken from XML::Parser::Expat->new:
    #
    #   $args{Parser} = ParserCreate($self, $args{ProtocolEncoding}, $args{Namespaces});
    
    # This means that, in order to avoid a memory leak, we have to break this circular
    # reference when we are done with the processing. The breaking of the circular reference
    # will be performed in XML::Reader->DESTROY, which calls XML::Parser::ExpatNB->parse_done.
    # (-- which, in turn, calls XML::Parser::Expat->release to actually break the circular
    # reference --)

    # This is an important moment (-- in terms of memory management, at least --).
    # XML::Parser->parse_start creates an XML::Parser::ExpatNB-object, which in turn generates
    # a circular reference (invisible with Data::Dumper). That circular reference will have to
    # be cleaned up when the XML::Reader-object goes away (see XML::Reader->DESTROY).

    $self->{ExpatNB} = $XmlParser->parse_start(
        XR_Data    => [],
        XR_Text    => '',
        XR_Comment => '',
        XR_Status  => 'ok',
        XR_fh      => $fh,
        XR_First   => 1,
        XR_Strip   => $opt{strip},

      ) or die "Failed assertion #0020 in subroutine XML::Reader->new: Can't create XML::Parser->new";

    # The instruction "XR_Data => []" (-- the 'XR_...' prefix stands for 'Xml::Reader...' --)
    # inside XML::Parser->parse_start() creates an empty array $ExpatNB{XR_Data} = []
    # inside the ExpatNB object. This array is the place where the handlers put their data.
    #
    # Likewise, the instructions "XR_Text => ''", "XR_Comment => ''", "XR_Status => 'ok'"
    # and "XR_fh => $fh" create corresponding elements inside the $ExpatNB-object.

    $self->{filter}  = $opt{filter};
    $self->{using}   = !defined($opt{using}) ? [] : ref($opt{using}) ? $opt{using} : [$opt{using}];

    # remove all spaces and then all leading and trailing '/', then put back a single leading '/'
    for my $check (@{$self->{using}}) {
        $check =~ s{\s}''xmsg;
        $check =~ s{\A /+}''xms;
        $check =~ s{/+ \z}''xms;
        $check = '/'.$check;
    }

    $self->{command}  = [['Z', [], 0, 0, '']];
    $self->{plist}    = [];
    $self->{path}     = '/';
    $self->{prefix}   = '';
    $self->{tag}      = '';
    $self->{value}    = '';
    $self->{comment}  = '';
    $self->{type}     = '?';
    $self->{is_start} = 0;
    $self->{is_end}   = 0;
    $self->{level}    = 0;
    $self->{prev_cd}  = 'T';
    $self->{item}     = '';

    return $self;
}

sub path     { $_[0]->{path};     }
sub tag      { $_[0]->{tag};      }
sub value    { $_[0]->{value};    }
sub comment  { $_[0]->{comment};  }
sub type     { $_[0]->{type};     }
sub is_start { $_[0]->{is_start}; }
sub is_end   { $_[0]->{is_end};   }
sub level    { $_[0]->{level};    }
sub prefix   { $_[0]->{prefix};   }

sub NB_data         { $_[0]->{ExpatNB}{XR_Data};           }
sub NB_stat_not_ok  { $_[0]->{ExpatNB}{XR_Status} ne 'ok'; }
sub NB_stat_set_eof { $_[0]->{ExpatNB}{XR_Status} = 'eof'; }
sub NB_fh           { $_[0]->{ExpatNB}{XR_fh};             }

sub handle_start {
    my ($ExpatNB, $element, @attr) = @_;

    my $text    = $ExpatNB->{XR_Text};
    my $comment = $ExpatNB->{XR_Comment};

    if ($ExpatNB->{XR_Strip}) {
        for ($text, $comment) { 
            s{\A \s+}''xms;
            s{\s+ \z}''xms;
            s{\s+}' 'xmsg;
        }
    }

    push @{$ExpatNB->{XR_Data}}, ['T', $text, $comment] unless $ExpatNB->{XR_First};
    $ExpatNB->{XR_First} = 0;

    $ExpatNB->{XR_Text}    = '';
    $ExpatNB->{XR_Comment} = '';

    push @{$ExpatNB->{XR_Data}}, ['S', $element, {@attr}];
}

sub handle_end {
    my ($ExpatNB, $element) = @_;

    my $text    = $ExpatNB->{XR_Text};
    my $comment = $ExpatNB->{XR_Comment};

    if ($ExpatNB->{XR_Strip}) {
        for ($text, $comment) { 
            s{\A \s+}''xms;
            s{\s+ \z}''xms;
            s{\s+}' 'xmsg;
        }
    }

    push @{$ExpatNB->{XR_Data}}, ['T', $text, $comment];

    $ExpatNB->{XR_Text}    = '';
    $ExpatNB->{XR_Comment} = '';

    push @{$ExpatNB->{XR_Data}}, ['E', $element];
}

sub handle_comment {
    my ($ExpatNB, $comment) = @_;

    $ExpatNB->{XR_Comment} .= $comment;
}

sub handle_char {
    my ($ExpatNB, $text) = @_;

    $ExpatNB->{XR_Text} .= $text;
}

sub iterate {
    my $self = shift;

    {
        # try reading 3 tokens...
        until ($self->NB_stat_not_ok or @{$self->{command}} >= 3) {
            $self->read_token;
        }

        # return failure if end-of-file
        unless (@{$self->{command}}) {
            return;
        }

        # populate values
        $self->populate_values;

        # if the current element is of type 'Z', i.e. a dummy header, then get rid of it
        if (${$self->{command}}[0][0] eq 'Z') {
            shift @{$self->{command}};
            redo;
        }

        # check if option {using => ...} as been requested, and if so, then skip all
        # lines that don't have a prefix...
        if (@{$self->{using}} and $self->{prefix} eq '') {
            shift @{$self->{command}};
            redo;
        }

        shift @{$self->{command}};
    }

    return 1;
}

sub populate_values {
    my $self = shift;

    # checking start- and end-tags can only be performed if the filter is off...
    unless ($self->{filter}) {
        # does the 2nd element exist?
        if (@{$self->{command}} >= 2) {
            my $cmd = ${$self->{command}}[1]; # take the second line...

            my $prv_length = $self->get_length(0);
            my $act_length = $self->get_length(1);
            my $nxt_length = $self->get_length(2);

            if ($prv_length < $act_length) {
                $cmd->[2] = 1; # mark as start-tag
            }

            if ($nxt_length < $act_length) {
                $cmd->[3] = 1; # mark as end-tag
            }
        }
    }

    my $cmd = ${$self->{command}}[0] or die "Failed assertion #0030 in subroutine XML::Reader->populate_values: command stack is empty";

    return if $cmd->[0] eq 'Z';

    if ($cmd->[0] eq 'A') {
        $self->{path}     = '/'.join('/', @{$cmd->[1]}).'/@'.$cmd->[4];
        $self->{tag}      = '@'.$cmd->[4];
        $self->{value}    = $cmd->[5];
        $self->{comment}  = '';
        $self->{is_start} = $cmd->[2];
        $self->{is_end}   = $cmd->[3];
        $self->{level}    = @{$cmd->[1]} + 1;
        $self->{type}     = '@';
    }
    elsif ($cmd->[0] eq 'T') {
        $self->{path}     = '/'.join('/', @{$cmd->[1]});
        $self->{tag}      = ${$cmd->[1]}[-1];
        $self->{value}    = $cmd->[4];
        $self->{comment}  = $cmd->[5];
        $self->{is_start} = $cmd->[2];
        $self->{is_end}   = $cmd->[3];
        $self->{level}    = @{$cmd->[1]};
        $self->{type}     = 'T';
    }
    else {
        die "Failed assertion #0040 in subroutine XML::Reader->iterate: Found data type '".$cmd->[0]."', but expected ('A' or 'T')";
    }

    # Here we check for the {using => ...} option
    $self->{prefix} = '';

    for my $check (@{$self->{using}}) {
        if ($check eq $self->{path}) {
            $self->{prefix} = $check;
            $self->{path}   = '/';
            $self->{level}  = 0;
            $self->{tag}    = ''; # unfortunately we have to nullify the tag here...
            last;
        }
        if ($check.'/' eq substr($self->{path}, 0, length($check) + 1)) { my @temp = split m{/}xms, $check;
            $self->{prefix} = $check;
            $self->{path}   = substr($self->{path}, length($check));
            $self->{level} -= @temp - 1;
            last;
        }
    }
}

sub read_token {
    my $self = shift;

    my $token = $self->get_token;

    unless (defined $token) {
        return;
    }

    if ($token->found_start_tag) {
        push @{$self->{plist}}, $token->extract_tag;
        my @list = @{$self->{plist}};

        unless ($self->{filter}) {
            if (keys %{$token->extract_attr}) {
                push @{$self->{command}}, ['T', \@list, 0, 0, '', ''];
            }
        }

        # inject the attributes...
        push @{$self->{command}},
          map {['A', \@list, 0, 0, $_, $token->extract_attr->{$_}]}
            sort keys %{$token->extract_attr};

        $self->{prev_cd} = keys(%{$token->extract_attr}) ? 'A' : 'T';
    }
    elsif ($token->found_end_tag) {
        unless ($self->{filter}) {
            if ($self->{prev_cd} eq 'A' or $self->{prev_cd} eq 'C') {
                my @list = @{$self->{plist}};
                push @{$self->{command}}, ['T', \@list, 0, 0, '', ''];
                $self->{prev_cd} = 'T';
            }
        }
        $self->{item} = pop @{$self->{plist}};
    }
    elsif ($token->found_text) {
        my $text    = $token->extract_text;
        my $comment = $token->extract_comment;

        if (!$self->{filter} or $text =~ m{\S}xms) {
            my @list = @{$self->{plist}};
            push @{$self->{command}}, ['T', \@list, 0, 0, $text, $comment];
        }
        $self->{prev_cd} = 'T';
    }
}

sub get_length {
    my $self = shift;
    my ($i) = @_;

    if ($i < 0 or $i > $#{$self->{command}}) {
        return 0;
    }

    my $cmd = ${$self->{command}}[$i];
    my $len = @{$cmd->[1]};

    return $len;
}

sub get_token {
    my $self = shift;

    until ($self->NB_stat_not_ok or @{$self->NB_data}) {

        # Here is the all important reading of a chunk of XML-data from the filehandle...
        read($self->NB_fh, my $buf, 4096);

        if ($buf eq '') {
            $self->NB_stat_set_eof;
            last;
        }

        # ...and here is the all important parsing of that chunk:
        $self->{ExpatNB}->parse_more($buf);
    }

    # return failure if end-of-file...
    unless (@{$self->NB_data}) {
        return;
    }

    my $token = shift @{$self->NB_data};
    bless $token, 'XML::Reader::Token';
}

sub DESTROY {
    my $self = shift;

    # There are circular references inside an XML::Parser::ExpatNB-object
    # which need to be cleaned up by calling XML::Parser::Expat->release.

    # I quote from the documentation of 'XML::Parser::Expat' (-- XML::Parser::Expat
    # is a super-class of XML::Parser::ExpatNB --)
    #
    # >> ------------------------------------------------------------------------
    # >> =item release
    # >>
    # >> There are data structures used by XML::Parser::Expat that have circular
    # >> references. This means that these structures will never be garbage
    # >> collected unless these references are explicitly broken. Calling this
    # >> method breaks those references (and makes the instance unusable.)
    # >>
    # >> Normally, higher level calls handle this for you, but if you are using
    # >> XML::Parser::Expat directly, then it's your responsibility to call it.
    # >> ------------------------------------------------------------------------

    # We call XML::Parser::Expat->release by actually calling
    # XML::Parser::ExpatNB->parse_done.

    # There is a possibility that the XML::Parser::ExpatNB-object did not get
    # created, while still blessing the XML::Reader object. Therefore we have to
    # test for this case before calling XML::Parser::ExpatNB->parse_done.

    if ($self->{ExpatNB}) {
        $self->{ExpatNB}->parse_done;
    }
}

# The package used here - XML::Reader::Token 
# has been inspired by    XML::TokeParser::Token

package XML::Reader::Token;

sub found_start_tag { $_[0][0] eq 'S'; }
sub found_end_tag   { $_[0][0] eq 'E'; }
sub found_comment   { $_[0][0] eq 'C'; }
sub found_text      { $_[0][0] eq 'T'; }

sub extract_tag {
    my $self = shift;
    my $type = $self->[0];
    return $type eq 'S' || $type eq 'E' ? $self->[1] : '';
}

sub extract_text {
    my $self = shift;
    my $type = $self->[0];
    return $type eq 'T' ? $self->[1] : '';
}

sub extract_comment {
    my $self = shift;
    my $type = $self->[0];
    return $type eq 'T' ? $self->[2] : '';
}

sub extract_attr {
    my $self = shift;
    my $type = $self->[0];
    return $type eq 'S' ? $self->[2] : {};
}

1;

__END__

=head1 NAME

XML::Reader - Reading XML and providing path information based on a pull-parser.

=head1 SYNOPSIS

  use XML::Reader;

  my $text = q{<root>stu<test param="v">w</test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->new(\$text) or die "Error: $!";
  while ($rdr->iterate) {
      printf "Path: %-18s, Value: %s\n", $rdr->path, $rdr->value;
  }

The above program produces the following output:

  Path: /root             , Value: stu
  Path: /root/test        , Value:
  Path: /root/test/@param , Value: v
  Path: /root/test        , Value: w
  Path: /root             , Value: x yz

=head1 DESCRIPTION

XML::Reader provides a simple and easy to use interface for sequentially parsing XML
files (so called "pull-mode" parsing) and at the same time keeps track of the complete XML-path.

It was developped as a wrapper on top of XML::Parser (while, at the same time, some basic functions
have been copied from XML::TokeParser). Both XML::Parser and XML::TokeParser allow pull-mode
parsing, but do not keep track of the complete XML-Path. Also, the interfaces to XML::Parser and
XML::TokeParser require you to distinguish between start-tags, end-tags and text, which, in my view,
complicates the interface.

There is also XML::TiePYX, which lets you pull-mode parse XML-Files (see
L<http://www.xml.com/pub/a/2000/03/15/feature/index.html> for an introduction to PYX).
But still, with XML::TiePYX you need to account for start-tags, end-tags and text, and it does not
provide the full XML-path.

By contrast, XML::Reader translates start-tags, end-tags and text into XPath-like expressions. So
you don't need to worry about tags, you just get a path and a value, and that's it.

For example, the following XML in variable '$line1'...

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

...can be parsed with XML::Reader using the methods C<iterate> to iterate one-by-one through the
XML-data, C<path> and C<value> to extract the current XML-path and it's value.

You can also keep track of the start- and end-tags: There is a method C<is_start>, which returns 1 or
0, depending on whether the XML-file had a start tag at the current position. There is also the
equivalent method C<is_end>. Just remember, those two method only make sense if filter is switched
off (otherwise those methods return constant 0).

There are also the methods C<comment>, C<tag>, C<type> and C<level>. C<comment> returns the comment,
if any. C<tag> gives you the current tag-name or attribute-name), C<type> returns either 'T' for text or
'@' for attributes and C<level> indicates the current nesting-level, a number >= 0.

Here is a sample program which parses the XML in '$line1' from above to demonstrate the principle...

  use XML::Reader;

  my $rdr = XML::Reader->new(\$line1) or die "Error: $!";
  my $i = 0;
  while ($rdr->iterate) { $i++;
      printf "%3d. pat=%-22s, val=%-9s, s=%-1s, e=%-1s, tag=%-6s, t=%-1s, lvl=%2d, c=%s\n",
       $i, $rdr->path, $rdr->value, $rdr->is_start,
       $rdr->is_end, $rdr->tag, $rdr->type, $rdr->level, $rdr->comment;
  }

...and here is the output:

   1. pat=/data                 , val=         , s=1, e=0, tag=data  , t=T, lvl= 1, c=
   2. pat=/data/item            , val=abc      , s=1, e=1, tag=item  , t=T, lvl= 2, c=
   3. pat=/data                 , val=         , s=0, e=0, tag=data  , t=T, lvl= 1, c=
   4. pat=/data/item            , val=         , s=1, e=0, tag=item  , t=T, lvl= 2, c=c1
   5. pat=/data/item/dummy      , val=         , s=1, e=1, tag=dummy , t=T, lvl= 3, c=
   6. pat=/data/item            , val=fgh      , s=0, e=0, tag=item  , t=T, lvl= 2, c=
   7. pat=/data/item/inner      , val=         , s=1, e=0, tag=inner , t=T, lvl= 3, c=
   8. pat=/data/item/inner/@id  , val=fff      , s=0, e=0, tag=@id   , t=@, lvl= 4, c=
   9. pat=/data/item/inner/@name, val=ttt      , s=0, e=0, tag=@name , t=@, lvl= 4, c=
  10. pat=/data/item/inner      , val=ooo ppp  , s=0, e=1, tag=inner , t=T, lvl= 3, c=c2
  11. pat=/data/item            , val=         , s=0, e=1, tag=item  , t=T, lvl= 2, c=
  12. pat=/data                 , val=         , s=0, e=1, tag=data  , t=T, lvl= 1, c=

If you want, you can set a filter to select only those lines that have a value.

  my $rdr = XML::Reader->new(\$line1, {filter => 1}) or die "Error: $!";

Then the output will be as follows (be careful not to interpret $rdr->is_start or
$rdr->is_end when the filter has been activated. Also be careful if you are looking for
comments. Comments with filter on are only returned if the tag is not empty, that's why
you don't see comment 'c1' in the output below)

   1. pat=/data/item            , val=abc      , s=0, e=0, tag=item  , t=T, lvl= 2, c=
   2. pat=/data/item            , val=fgh      , s=0, e=0, tag=item  , t=T, lvl= 2, c=
   3. pat=/data/item/inner/@id  , val=fff      , s=0, e=0, tag=@id   , t=@, lvl= 4, c=
   4. pat=/data/item/inner/@name, val=ttt      , s=0, e=0, tag=@name , t=@, lvl= 4, c=
   5. pat=/data/item/inner      , val=ooo ppp  , s=0, e=0, tag=inner , t=T, lvl= 3, c=c2

=head1 INTERFACE

=head2 Object creation

To create an XML::Reader object, the following syntax is used:

  my $rdr = XML::Reader->new($data,
    {strip => 1, filter => 0, using => ['/path1', '/path2']})
    or die "Error: $!";

The element $data (which is mandatory) is either the name of the XML-file, or a
reference to a string, in which case the content of that string is taken as the
text of the XML.

Here is an example to create an XML::Reader object with a file-name:

  my $rdr = XML::Reader->new('input.xml') or die "Error: $!";

Here is another example to create an XML::Reader object with a reference:

  my $rdr = XML::Reader->new(\'<data>abc</data>') or die "Error: $!";

One or more of the following options can be added as a hash-reference:

=over

=item option {strip => 1}

The option {strip => 1} strips all leading and trailing spaces from text and comments.
(attributes are never stripped). The default is {strip => 1}.

=item option {filter => 0}

The option {filter => 1} removes all empty text lines. Be careful if you want to use the
C<is_start> and C<is_end> methods, in which case you have to set option {filter => 0}.
The default is {filter => 0}.

=item option {using => ['/path1/path2/path3', '/path4/path5/path6']}

This option removes all lines which do not start with '/path1/path2/path3' (or with
'/path4/path5/path6', for that matter). This effectively leaves only lines starting with
'/path1/path2/path3' or '/path4/path5/path6'. Those lines (which are not removed) will have a
shorter path by effectively removing the prefix '/path1/path2/path3' (or '/path4/path5/path6')
from the path. The removed prefix, however, shows up in the prefix-method.

'/path1/path2/path3' (or '/path4/path5/path6') are supposed to be absolute and complete, i.e.
absolute meaning they have to start with a '/'-character and complete meaning that the last
item in path 'path3' (or 'path6', for that matter) will be completed internally by a trailing
'/'-character.

=back

=head2 Methods

A successfully created object of type XML::Reader provides the following methods:

=over

=item iterate

Reads one single XML-value. It returns 1 after a successful read, or undef when
it hits end-of-file.

=item path

Provides the complete path of the currently selected value, attributes are represented
by leading '@'-signs, comments are represented by a '#'-symbol.

=item value

Provides the actual value (i.e. the value of the current text, attribute or comment).

=item comment

Provides the comments of the XML.

=item type

Provides the type of the value: 'T' for text or '@' for attributes.

=item tag

Provides the current tag-name (or attribute-name).

=item is_start

Returns 1 or 0, depending on whether the XML-file had a start tag at the current position.
Be careful, this method only make sense if filter is switched off (otherwise constant 0 is
returned if filter is switched on).

=item is_end

Returns 1 or 0, depending on whether the XML-file had an end tag at the current position.
Be careful, this method only make sense if filter is switched off (otherwise constant 0 is
returned if filter is switched on).

=item level

Indicates the nesting level of the XPath expression (numeric value greater than zero).

=item prefix

Shows the prefix which has been removed in option {using => ...}. Returns the empty string if
option {using => ...} has not been specified.

=back

=head1 EXAMPLES

Here is a sample piece of XML (in variable '$line2'):

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

=head2 An example with option 'using'

The following program takes this XML and parses it with XML::Reader, including the option 'using'
to target specific elements:

  use XML::Reader;

  my $rdr = XML::Reader->new(\$line2, {filter => 0,
    using => ['/data/order/database/customer', '/data/supplier']});

  my $i = 0;
  while ($rdr->iterate) { $i++;
      printf "%3d. prf=%-29s, pat=%-7s, val=%-3s, s=%-1s, e=%-1s, tag=%-6s, t=%-1s, lvl=%2d\n",
        $i, $rdr->prefix, $rdr->path, $rdr->value, $rdr->is_start,
        $rdr->is_end, $rdr->tag, $rdr->type, $rdr->level;
  }

This is the output of that program:

   1. prf=/data/order/database/customer, pat=/      , val=   , s=1, e=0, tag=      , t=T, lvl= 0
   2. prf=/data/order/database/customer, pat=/@name , val=aaa, s=0, e=0, tag=@name , t=@, lvl= 1
   3. prf=/data/order/database/customer, pat=/      , val=   , s=0, e=1, tag=      , t=T, lvl= 0
   4. prf=/data/order/database/customer, pat=/      , val=   , s=1, e=0, tag=      , t=T, lvl= 0
   5. prf=/data/order/database/customer, pat=/@name , val=bbb, s=0, e=0, tag=@name , t=@, lvl= 1
   6. prf=/data/order/database/customer, pat=/      , val=   , s=0, e=1, tag=      , t=T, lvl= 0
   7. prf=/data/order/database/customer, pat=/      , val=   , s=1, e=0, tag=      , t=T, lvl= 0
   8. prf=/data/order/database/customer, pat=/@name , val=ccc, s=0, e=0, tag=@name , t=@, lvl= 1
   9. prf=/data/order/database/customer, pat=/      , val=   , s=0, e=1, tag=      , t=T, lvl= 0
  10. prf=/data/order/database/customer, pat=/      , val=   , s=1, e=0, tag=      , t=T, lvl= 0
  11. prf=/data/order/database/customer, pat=/@name , val=ddd, s=0, e=0, tag=@name , t=@, lvl= 1
  12. prf=/data/order/database/customer, pat=/      , val=   , s=0, e=1, tag=      , t=T, lvl= 0
  13. prf=/data/supplier               , pat=/      , val=hhh, s=1, e=1, tag=      , t=T, lvl= 0
  14. prf=/data/supplier               , pat=/      , val=iii, s=1, e=1, tag=      , t=T, lvl= 0
  15. prf=/data/supplier               , pat=/      , val=jjj, s=1, e=1, tag=      , t=T, lvl= 0

=head2 An example without option 'using'

The following program takes the same XML and parses it with XML::Reader, but without the option 'using'.

  use XML::Reader;

  my $rdr = XML::Reader->new(\$line2, {filter => 0});
  my $i = 0;
  while ($rdr->iterate) { $i++;
      printf "%3d. prf=%-1s, pat=%-37s, val=%-6s, s=%-1s, e=%-1s, tag=%-11s, t=%-1s, lvl=%2d\n",
       $i, $rdr->prefix, $rdr->path, $rdr->value, $rdr->is_start,
       $rdr->is_end, $rdr->tag, $rdr->type, $rdr->level;
  }

As you can see in the following output, there are many more lines written, the prefix is empty and the path
is much longer than in the previous program:

   1. prf= , pat=/data                                , val=      , s=1, e=0, tag=data       , t=T, lvl= 1
   2. prf= , pat=/data/order                          , val=      , s=1, e=0, tag=order      , t=T, lvl= 2
   3. prf= , pat=/data/order/database                 , val=      , s=1, e=0, tag=database   , t=T, lvl= 3
   4. prf= , pat=/data/order/database/customer        , val=      , s=1, e=0, tag=customer   , t=T, lvl= 4
   5. prf= , pat=/data/order/database/customer/@name  , val=aaa   , s=0, e=0, tag=@name      , t=@, lvl= 5
   6. prf= , pat=/data/order/database/customer        , val=      , s=0, e=1, tag=customer   , t=T, lvl= 4
   7. prf= , pat=/data/order/database                 , val=      , s=0, e=0, tag=database   , t=T, lvl= 3
   8. prf= , pat=/data/order/database/customer        , val=      , s=1, e=0, tag=customer   , t=T, lvl= 4
   9. prf= , pat=/data/order/database/customer/@name  , val=bbb   , s=0, e=0, tag=@name      , t=@, lvl= 5
  10. prf= , pat=/data/order/database/customer        , val=      , s=0, e=1, tag=customer   , t=T, lvl= 4
  11. prf= , pat=/data/order/database                 , val=      , s=0, e=0, tag=database   , t=T, lvl= 3
  12. prf= , pat=/data/order/database/customer        , val=      , s=1, e=0, tag=customer   , t=T, lvl= 4
  13. prf= , pat=/data/order/database/customer/@name  , val=ccc   , s=0, e=0, tag=@name      , t=@, lvl= 5
  14. prf= , pat=/data/order/database/customer        , val=      , s=0, e=1, tag=customer   , t=T, lvl= 4
  15. prf= , pat=/data/order/database                 , val=      , s=0, e=0, tag=database   , t=T, lvl= 3
  16. prf= , pat=/data/order/database/customer        , val=      , s=1, e=0, tag=customer   , t=T, lvl= 4
  17. prf= , pat=/data/order/database/customer/@name  , val=ddd   , s=0, e=0, tag=@name      , t=@, lvl= 5
  18. prf= , pat=/data/order/database/customer        , val=      , s=0, e=1, tag=customer   , t=T, lvl= 4
  19. prf= , pat=/data/order/database                 , val=      , s=0, e=1, tag=database   , t=T, lvl= 3
  20. prf= , pat=/data/order                          , val=      , s=0, e=1, tag=order      , t=T, lvl= 2
  21. prf= , pat=/data                                , val=      , s=0, e=0, tag=data       , t=T, lvl= 1
  22. prf= , pat=/data/dummy                          , val=      , s=1, e=0, tag=dummy      , t=T, lvl= 2
  23. prf= , pat=/data/dummy/@value                   , val=ttt   , s=0, e=0, tag=@value     , t=@, lvl= 3
  24. prf= , pat=/data/dummy                          , val=test  , s=0, e=1, tag=dummy      , t=T, lvl= 2
  25. prf= , pat=/data                                , val=      , s=0, e=0, tag=data       , t=T, lvl= 1
  26. prf= , pat=/data/supplier                       , val=hhh   , s=1, e=1, tag=supplier   , t=T, lvl= 2
  27. prf= , pat=/data                                , val=      , s=0, e=0, tag=data       , t=T, lvl= 1
  28. prf= , pat=/data/supplier                       , val=iii   , s=1, e=1, tag=supplier   , t=T, lvl= 2
  29. prf= , pat=/data                                , val=      , s=0, e=0, tag=data       , t=T, lvl= 1
  30. prf= , pat=/data/supplier                       , val=jjj   , s=1, e=1, tag=supplier   , t=T, lvl= 2
  31. prf= , pat=/data                                , val=      , s=0, e=1, tag=data       , t=T, lvl= 1

=head1 AUTHOR

Klaus Eichner, March 2009

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Klaus Eichner

All rights reserved. This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 RELATED MODULES

If you also want to write XML, have a look at XML::Writer. This module provides a simple interface for
writing XML. (If you are writing non-mixed content XML, consider setting DATA_MODE=>1 and
DATA_INDENT=>2, which allows for proper indentation in your XML-Output file)

=head1 SEE ALSO

L<XML::TokeParser>,
L<XML::Parser>,
L<XML::Parser::Expat>,
L<XML::TiePYX>,
L<XML::Writer>.

=cut
