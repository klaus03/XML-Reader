package XML::Reader;

use strict;
use warnings;

use XML::Parser;

require Exporter;

our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ( all => [ qw() ] );
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT      = qw();
our $VERSION     = '0.14';

sub newhd {
    my $class = shift;
    my $self = {};

    my %opt = (strip => 1, filter => 2); # newhd defaults to filter=>2
    %opt    = (%opt, %{$_[1]}) if defined $_[1];

    my $XmlParser = XML::Parser->new
      or die "Failed assertion #0010 in subroutine XML::Reader->newhd: Can't create XML::Parser->new";

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
    # 'in-memory-file'. If the open fails, then we return failure from XML::Reader->newhd
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

      ) or die "Failed assertion #0020 in subroutine XML::Reader->newhd: Can't create XML::Parser->new";

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

    $self->{command}      = [['Z', [], 0, 0, '', '', 0]];
    $self->{plist}        = [];
    $self->{path}         = '/';
    $self->{prefix}       = '';
    $self->{tag}          = '';
    $self->{value}        = '';
    $self->{att_hash}     = {};
    $self->{comment}      = '';
    $self->{type}         = '?';
    $self->{is_init_attr} = 0;
    $self->{is_start}     = 0;
    $self->{is_end}       = 0;
    $self->{level}        = 0;
    $self->{prev_cd}      = 'T';
    $self->{item}         = '';

    return $self;
}

# subroutine new is deprecated (use newhd instead)
sub new {
    my $class = shift;

    my %opt = (strip => 1, filter => 0); # new is depreceated, it defaults to filter=>0
    %opt    = (%opt, %{$_[1]}) if defined $_[1];
    return XML::Reader->newhd($_[0], \%opt);
}

sub path         { $_[0]->{path};         }
sub tag          { $_[0]->{tag};          }
sub attr         { $_[0]->{attr};         }
sub value        { $_[0]->{value};        }
sub att_hash     { $_[0]->{att_hash};     }
sub type         { $_[0]->{type};         }
sub level        { $_[0]->{level};        }
sub prefix       { $_[0]->{prefix};       }
sub comment      { $_[0]->{comment};      }
sub is_init_attr { $_[0]->{is_init_attr}; }
sub is_start     { $_[0]->{is_start};     }
sub is_end       { $_[0]->{is_end};       }

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

        # skip attributes when filter == 3
        if ($self->{filter} == 3 and $self->{type} eq '@') {
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
    unless ($self->{filter} == 1) {
        # does the 2nd element exist?
        if (@{$self->{command}} >= 2) {
            my $cmd_prv =                            ${$self->{command}}[0];                              # take the first line as previous...
            my $cmd_act =                            ${$self->{command}}[1];                              # take the second line as current...
            my $cmd_nxt = @{$self->{command}} >= 3 ? ${$self->{command}}[2] : ['Z', [], 0, 0, '', '', 0]; # take the third line as next...

            my $prv_length = @{$cmd_prv->[1]};
            my $act_length = @{$cmd_act->[1]};
            my $nxt_length = @{$cmd_nxt->[1]};

            my $prv_type = $cmd_prv->[0];
            my $act_type = $cmd_act->[0];
            my $nxt_type = $cmd_nxt->[0];

            if ($self->{filter} == 0) {
                $cmd_act->[2] = (                                          $prv_length < $act_length ) ? 1 : 0; # mark as start-tag
                $cmd_act->[3] = (                                          $nxt_length < $act_length ) ? 1 : 0; # mark as end-tag
            }
            else {
                $cmd_act->[2] = ($act_type eq 'T' and ($prv_type ne 'T' or $prv_length < $act_length)) ? 1 : 0; # mark as start-tag
                $cmd_act->[3] = ($act_type eq 'T' and                      $nxt_length < $act_length ) ? 1 : 0; # mark as end-tag
            }

            $cmd_act->[6] = $prv_type ne 'A' ? 1 : 0; # mark as init_attr
        }
    }

    my $cmd = ${$self->{command}}[0] or die "Failed assertion #0030 in subroutine XML::Reader->populate_values: command stack is empty";

    return if $cmd->[0] eq 'Z';

    $self->{is_start}     = $cmd->[2];
    $self->{is_end}       = $cmd->[3];
    $self->{is_init_attr} = $cmd->[6];

    if ($cmd->[0] eq 'A') {
        $self->{path}     = '/'.join('/', @{$cmd->[1]}).'/@'.$cmd->[4];
        $self->{attr}     = $cmd->[4];
        $self->{value}    = $cmd->[5];
        $self->{comment}  = '';
        $self->{level}    = @{$cmd->[1]} + 1;
        $self->{tag}      = '@'.$cmd->[4];
        $self->{type}     = '@';
    }
    elsif ($cmd->[0] eq 'T') {
        $self->{path}     = '/'.join('/', @{$cmd->[1]});
        $self->{attr}     = '';
        $self->{value}    = $cmd->[4];
        $self->{comment}  = $cmd->[5];
        $self->{level}    = @{$cmd->[1]};
        $self->{tag}      = ${$cmd->[1]}[-1];
        $self->{type}     = 'T';
    }
    else {
        die "Failed assertion #0040 in subroutine XML::Reader->iterate: Found data type '".$cmd->[0]."', but expected ('A' or 'T')";
    }

    if ($self->{filter} == 3) {
        if ($self->{is_init_attr}) {
            $self->{att_hash} = {};
        }
        if ($self->{type} eq '@') {
            $self->{att_hash}{$self->{attr}} = $self->{value};
        }
    }

    if ($self->{filter} == 1) {
        $self->{is_start}     = undef;
        $self->{is_end}       = undef;
        $self->{is_init_attr} = undef;
        $self->{comment}      = undef;
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

        if ($self->{filter} == 0) {
            if (keys %{$token->extract_attr}) {
                push @{$self->{command}}, ['T', \@list, 0, 0, '', '', 0];
            }
        }

        # inject the attributes...
        push @{$self->{command}},
          map {['A', \@list, 0, 0, $_, $token->extract_attr->{$_}]}
            sort keys %{$token->extract_attr};

        $self->{prev_cd} = keys(%{$token->extract_attr}) ? 'A' : 'T';
    }
    elsif ($token->found_end_tag) {
        unless ($self->{filter} == 1) {
            if ($self->{prev_cd} eq 'A' or $self->{prev_cd} eq 'C') {
                my @list = @{$self->{plist}};
                push @{$self->{command}}, ['T', \@list, 0, 0, '', '', 0];
                $self->{prev_cd} = 'T';
            }
        }
        $self->{item} = pop @{$self->{plist}};
    }
    elsif ($token->found_text) {
        my $text    = $token->extract_text;
        my $comment = $token->extract_comment;

        if ($self->{filter} != 1 or $text =~ m{\S}xms) {
            my @list = @{$self->{plist}};
            push @{$self->{command}}, ['T', \@list, 0, 0, $text, $comment, 0];
        }
        $self->{prev_cd} = 'T';
    }
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

  my $text = q{<init><page node="400">m <!-- remark --> r</page></init>};

  my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";
  while ($rdr->iterate) {
      printf "Path: %-19s, Value: %s\n", $rdr->path, $rdr->value;
  }

This program produces the following output:

  Path: /init              , Value:
  Path: /init/page/@node   , Value: 400
  Path: /init/page         , Value: m r
  Path: /init              , Value:

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
equivalent method C<is_end>. If you want to know whether you have encountered a fresh sequence of
attributes, you can use the method C<is_init_attr>.

There are also the methods C<comment>, C<tag>, C<attr>, C<type> and C<level>. C<comment> returns
the comment, if any. C<tag> gives you the current tag-name, C<attr> returns the attribute-name,
C<type> returns either 'T' for text or '@' for attributes and C<level> indicates the current
nesting-level (a number >= 0).

Here is a sample program which parses the XML in '$line1' from above to demonstrate the principle...

  use XML::Reader;

  my $rdr = XML::Reader->newhd(\$line1) or die "Error: $!";
  my $i = 0;
  while ($rdr->iterate) { $i++;
      printf "%3d. pat=%-22s, val=%-9s, s=%-1s, i=%-1s, e=%-1s, tag=%-6s, atr=%-6s, t=%-1s, lvl=%2d, c=%s\n",
       $i, $rdr->path, $rdr->value, $rdr->is_start, $rdr->is_init_attr,
       $rdr->is_end, $rdr->tag, $rdr->attr, $rdr->type, $rdr->level, $rdr->comment;
  }

...and here is the output:

   1. pat=/data                 , val=         , s=1, i=1, e=0, tag=data  , atr=      , t=T, lvl= 1, c=
   2. pat=/data/item            , val=abc      , s=1, i=1, e=1, tag=item  , atr=      , t=T, lvl= 2, c=
   3. pat=/data                 , val=         , s=0, i=1, e=0, tag=data  , atr=      , t=T, lvl= 1, c=
   4. pat=/data/item            , val=         , s=1, i=1, e=0, tag=item  , atr=      , t=T, lvl= 2, c=c1
   5. pat=/data/item/dummy      , val=         , s=1, i=1, e=1, tag=dummy , atr=      , t=T, lvl= 3, c=
   6. pat=/data/item            , val=fgh      , s=0, i=1, e=0, tag=item  , atr=      , t=T, lvl= 2, c=
   7. pat=/data/item/inner/@id  , val=fff      , s=0, i=1, e=0, tag=@id   , atr=id    , t=@, lvl= 4, c=
   8. pat=/data/item/inner/@name, val=ttt      , s=0, i=0, e=0, tag=@name , atr=name  , t=@, lvl= 4, c=
   9. pat=/data/item/inner      , val=ooo ppp  , s=1, i=0, e=1, tag=inner , atr=      , t=T, lvl= 3, c=c2
  10. pat=/data/item            , val=         , s=0, i=1, e=1, tag=item  , atr=      , t=T, lvl= 2, c=
  11. pat=/data                 , val=         , s=0, i=1, e=1, tag=data  , atr=      , t=T, lvl= 1, c=

If you want, you can set option {filter => 1} to select only those lines that have a value.

  use XML::Reader;

  my $rdr = XML::Reader->newhd(\$line1, {filter => 1}) or die "Error: $!";
  my $i = 0;
  while ($rdr->iterate) { $i++;
      printf "%3d. pat=%-22s, val=%-9s, tag=%-6s, atr=%-6s, t=%-1s, lvl=%2d\n",
       $i, $rdr->path, $rdr->value, $rdr->tag, $rdr->attr, $rdr->type, $rdr->level;
  }

In this case the output will be as follows (be careful not to interpret the methods $rdr->is_start,
$rdr->is_init_attr, $rdr->is_end or $rdr->comment when option {filter => 1} is set (those methods
will, in fact, be undefined).

   1. pat=/data/item            , val=abc      , tag=item  , atr=      , t=T, lvl= 2
   2. pat=/data/item            , val=fgh      , tag=item  , atr=      , t=T, lvl= 2
   3. pat=/data/item/inner/@id  , val=fff      , tag=@id   , atr=id    , t=@, lvl= 4
   4. pat=/data/item/inner/@name, val=ttt      , tag=@name , atr=name  , t=@, lvl= 4
   5. pat=/data/item/inner      , val=ooo ppp  , tag=inner , atr=      , t=T, lvl= 3

=head1 INTERFACE

=head2 Object creation

To create an XML::Reader object, the following syntax is used:

  my $rdr = XML::Reader->newhd($data,
    {strip => 1, filter => 2, using => ['/path1', '/path2']})
    or die "Error: $!";

The element $data (which is mandatory) is either the name of the XML-file, or a
reference to a string, in which case the content of that string is taken as the
text of the XML.

Here is an example to create an XML::Reader object with a file-name:

  my $rdr = XML::Reader->newhd('input.xml') or die "Error: $!";

Here is another example to create an XML::Reader object with a reference:

  my $rdr = XML::Reader->newhd(\'<data>abc</data>') or die "Error: $!";

One or more of the following options can be added as a hash-reference:

=over

=item option {using => }

Option Using allows for selecting a sub-tree of the XML.

The syntax is {using => ['/path1/path2/path3', '/path4/path5/path6']}

=item option {filter => }

Option Filter allows to switch on ({filter => 1}), or to switch off ({filter => 2}) a filter for
empty lines.

The syntax is {filter => 1|2}, default is {filter => 2}

=item option {strip => }

Option {strip => 1} strips all leading and trailing spaces from text and comments.
(attributes are never stripped). {strip => 0} leaves text and comments unmodified.

The syntax is {strip => 0|1}, default is {strip => 1}

=back

=head2 Methods

A successfully created object of type XML::Reader provides the following methods:

=over

=item iterate

Reads one single XML-value. It returns 1 after a successful read, or undef when
it hits end-of-file.

=item path

Provides the complete path of the currently selected value, attributes are represented
by leading '@'-signs.

=item value

Provides the actual value (i.e. the value of the current text, attribute or comment).

=item comment

Provides the comments of the XML. Be careful, this method only make sense for option
{filter => 2} (otherwise, in case of {filter => 1}, the method C<comment> returns undef).

=item type

Provides the type of the value: 'T' for text or '@' for attributes.

=item tag

Provides the current tag-name.

=item attr

Provides the current attribute (returns the empty string for non-attribute lines).

=item is_start

Returns 1 or 0, depending on whether the XML-file had a start tag at the current position.
Be careful, this method only make sense for option {filter => 2} (otherwise,
in case of {filter => 1}, the method C<is_start> returns undef).

=item is_init_attr

Returns 1 or 0, depending on whether a new sequence of attributes is initiated.
Be careful, this method only make sense for option {filter => 2} (otherwise,
in case of {filter => 1}, the method C<is_init_attr> returns undef).

=item is_end

Returns 1 or 0, depending on whether the XML-file had an end tag at the current position.
Be careful, this method only make sense for option {filter => 2} (otherwise,
in case of {filter => 1}, the method C<is_end> returns undef).

=item level

Indicates the nesting level of the XPath expression (numeric value greater than zero).

=item prefix

Shows the prefix which has been removed in option {using => ...}. Returns the empty string if
option {using => ...} has not been specified.

=back

=head1 OPTION USING

Option Using allows for selecting a sub-tree of the XML.

Here is how it works in detail...

option {using => ['/path1/path2/path3', '/path4/path5/path6']} removes all lines which do not
start with '/path1/path2/path3' (or with '/path4/path5/path6', for that matter). This effectively
leaves only lines starting with '/path1/path2/path3' or '/path4/path5/path6'.

Those lines (which are not removed) will have a shorter path by effectively removing the prefix 
'/path1/path2/path3' (or '/path4/path5/path6') from the path. The removed prefix, however, shows
up in the prefix-method.

'/path1/path2/path3' (or '/path4/path5/path6') are supposed to be absolute and complete, i.e.
absolute meaning they have to start with a '/'-character and complete meaning that the last
item in path 'path3' (or 'path6', for that matter) will be completed internally by a trailing
'/'-character.

=head2 An example with option 'using'

The following program takes this XML and parses it with XML::Reader, including the option 'using'
to target specific elements:

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

  my $rdr = XML::Reader->newhd(\$line2,
    {using => ['/data/order/database/customer', '/data/supplier']});

  my $i = 0;
  while ($rdr->iterate) { $i++;
      printf "%3d. prf=%-29s, pat=%-7s, val=%-3s, tag=%-6s, t=%-1s, lvl=%2d\n",
        $i, $rdr->prefix, $rdr->path, $rdr->value, $rdr->tag, $rdr->type, $rdr->level;
  }

This is the output of that program:

   1. prf=/data/order/database/customer, pat=/@name , val=aaa, tag=@name , t=@, lvl= 1
   2. prf=/data/order/database/customer, pat=/      , val=   , tag=      , t=T, lvl= 0
   3. prf=/data/order/database/customer, pat=/@name , val=bbb, tag=@name , t=@, lvl= 1
   4. prf=/data/order/database/customer, pat=/      , val=   , tag=      , t=T, lvl= 0
   5. prf=/data/order/database/customer, pat=/@name , val=ccc, tag=@name , t=@, lvl= 1
   6. prf=/data/order/database/customer, pat=/      , val=   , tag=      , t=T, lvl= 0
   7. prf=/data/order/database/customer, pat=/@name , val=ddd, tag=@name , t=@, lvl= 1
   8. prf=/data/order/database/customer, pat=/      , val=   , tag=      , t=T, lvl= 0
   9. prf=/data/supplier               , pat=/      , val=hhh, tag=      , t=T, lvl= 0
  10. prf=/data/supplier               , pat=/      , val=iii, tag=      , t=T, lvl= 0
  11. prf=/data/supplier               , pat=/      , val=jjj, tag=      , t=T, lvl= 0

=head2 An example without option 'using'

The following program takes the same XML and parses it with XML::Reader, but without the option 'using'.

  use XML::Reader;

  my $rdr = XML::Reader->newhd(\$line2);
  my $i = 0;
  while ($rdr->iterate) { $i++;
      printf "%3d. prf=%-1s, pat=%-37s, val=%-6s, tag=%-11s, t=%-1s, lvl=%2d\n",
       $i, $rdr->prefix, $rdr->path, $rdr->value, $rdr->tag, $rdr->type, $rdr->level;
  }

As you can see in the following output, there are many more lines written, the prefix is empty and the path
is much longer than in the previous program:

   1. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1
   2. prf= , pat=/data/order                          , val=      , tag=order      , t=T, lvl= 2
   3. prf= , pat=/data/order/database                 , val=      , tag=database   , t=T, lvl= 3
   4. prf= , pat=/data/order/database/customer/@name  , val=aaa   , tag=@name      , t=@, lvl= 5
   5. prf= , pat=/data/order/database/customer        , val=      , tag=customer   , t=T, lvl= 4
   6. prf= , pat=/data/order/database                 , val=      , tag=database   , t=T, lvl= 3
   7. prf= , pat=/data/order/database/customer/@name  , val=bbb   , tag=@name      , t=@, lvl= 5
   8. prf= , pat=/data/order/database/customer        , val=      , tag=customer   , t=T, lvl= 4
   9. prf= , pat=/data/order/database                 , val=      , tag=database   , t=T, lvl= 3
  10. prf= , pat=/data/order/database/customer/@name  , val=ccc   , tag=@name      , t=@, lvl= 5
  11. prf= , pat=/data/order/database/customer        , val=      , tag=customer   , t=T, lvl= 4
  12. prf= , pat=/data/order/database                 , val=      , tag=database   , t=T, lvl= 3
  13. prf= , pat=/data/order/database/customer/@name  , val=ddd   , tag=@name      , t=@, lvl= 5
  14. prf= , pat=/data/order/database/customer        , val=      , tag=customer   , t=T, lvl= 4
  15. prf= , pat=/data/order/database                 , val=      , tag=database   , t=T, lvl= 3
  16. prf= , pat=/data/order                          , val=      , tag=order      , t=T, lvl= 2
  17. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1
  18. prf= , pat=/data/dummy/@value                   , val=ttt   , tag=@value     , t=@, lvl= 3
  19. prf= , pat=/data/dummy                          , val=test  , tag=dummy      , t=T, lvl= 2
  20. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1
  21. prf= , pat=/data/supplier                       , val=hhh   , tag=supplier   , t=T, lvl= 2
  22. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1
  23. prf= , pat=/data/supplier                       , val=iii   , tag=supplier   , t=T, lvl= 2
  24. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1
  25. prf= , pat=/data/supplier                       , val=jjj   , tag=supplier   , t=T, lvl= 2
  26. prf= , pat=/data                                , val=      , tag=data       , t=T, lvl= 1

=head1 OPTION FILTER

Option Filter allows to switch on ({filter => 1}), or to switch off ({filter => 2}) a filter for
empty lines.

=head2 Option {filter => 2}

With option {filter => 2}, that is the filter for empty lines is switched off, XML::Reader
produces one line for each start-tag and one line for each end-tag. (consecutive start- and
end-tags can be combined into one single line.) Also, attribute lines are added via the
special '/@...' syntax.

Option {filter => 2} is the default.

Here is an example...

  use XML::Reader;

  my $text = q{<root><test param="v"><a><b>e<data id="z">g</data>f</b></a></test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";
  while ($rdr->iterate) {
      printf "Path: %-24s, Value: %s\n", $rdr->path, $rdr->value;
  }

This program (with implicit option {filter => 2} as default) produces the following output:

  Path: /root                   , Value:
  Path: /root/test/@param       , Value: v
  Path: /root/test              , Value:
  Path: /root/test/a            , Value:
  Path: /root/test/a/b          , Value: e
  Path: /root/test/a/b/data/@id , Value: z
  Path: /root/test/a/b/data     , Value: g
  Path: /root/test/a/b          , Value: f
  Path: /root/test/a            , Value:
  Path: /root/test              , Value:
  Path: /root                   , Value: x yz

{filter => 2} also allows to rebuild the structure of the XML with the help of the methods
C<is_start>, C<is_init_attr> and C<is_end>. Please note that the first line ("Path: /root, Value:")
is empty, but important for the structure of the XML. Therefore we can't ignore it.

Let us now look at the same example (with option {filter => 2}), but with an
additional algorithm to reconstruct the original XML:

  use XML::Reader;

  my $text = q{<root><test param="v"><a><b>e<data id="z">g</data>f</b></a></test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";

  my %at;

  while ($rdr->iterate) {
      my $indentation = '  ' x $rdr->level;

      if ($rdr->is_init_attr) { %at  = (); }
      if ($rdr->type eq '@')  { $at{$rdr->attr} = $rdr->value; }

      if ($rdr->is_start) {
          print $indentation, '<', $rdr->tag, join('', map{" $_='$at{$_}'"} sort keys %at), '>', "\n";
      }

      if ($rdr->type eq 'T' and $rdr->value ne '') {
          print $indentation, '  ', $rdr->value, "\n";
      }

      if ($rdr->is_end) {
          print $indentation, '</', $rdr->tag, '>', "\n";
      }
  }

...and here is the output:

  <root>
    <test param='v'>
      <a>
        <b>
          e
          <data id='z'>
            g
          </data>
          f
        </b>
      </a>
    </test>
    x yz
  </root>

...this is proof that the original structure of the XML is not lost.

=head2 Option {filter => 3}

Option {filter = 3} works very much like {filter => 2}.

The difference, though, is that with option {filter => 3} all attribute-lines are filtered
out and instead, the attributes are presented for each start-line in a hash $rdr->att_hash().

This allows, in fact, to dispense with the global %at variable of the previous algorithm, and
use a local %at variable instead:

  my %at = %{$rdr->att_hash};

Here is the new algorithm for {filter => 3}, we don't need to worry about attributes (that is,
we don't need to check fot $rdr->type eq '@') and, as already mentioned, the %at variable is now local:

  use XML::Reader;

  my $text = q{<root><test param="v"><a><b>e<data id="z">g</data>f</b></a></test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->newhd(\$text, {filter => 3}) or die "Error: $!";

  while ($rdr->iterate) {
      my $indentation = '  ' x $rdr->level;

      if ($rdr->is_start) {
          my %at = %{$rdr->att_hash};
          print $indentation, '<', $rdr->tag, join('', map{" $_='$at{$_}'"} sort keys %at), '>', "\n";
      }

      if ($rdr->type eq 'T' and $rdr->value ne '') {
          print $indentation, '  ', $rdr->value, "\n";
      }

      if ($rdr->is_end) {
          print $indentation, '</', $rdr->tag, '>', "\n";
      }
  }

...the output for {filter => 3} is identical to the output for {filter => 2}:

  <root>
    <test param='v'>
      <a>
        <b>
          e
          <data id='z'>
            g
          </data>
          f
        </b>
      </a>
    </test>
    x yz
  </root>

=head2 Option {filter => 1}

Option {filter => 1} reduces the number of output lines (i.e. it removes all
lines that don't have a value).

Be careful if you want to use one of the four methods C<is_start>, C<is_init_attr>,
C<is_end> or C<comment>. In fact, if you have option {filter => 1}, then those four
methods will return undef.

With option {filter => 1} we lose the ability to reconstruct the XML, but simple data
processing is easier.

Here is a sample program:

  use XML::Reader;

  my $text = q{<root><test param="v"><a><b>e<data id="z">g</data>f</b></a></test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->newhd(\$text, {filter => 1}) or die "Error: $!";
  while ($rdr->iterate) {
      printf "Path: %-24s, Value: %s\n", $rdr->path, $rdr->value;
  }

...and here is the output:

  Path: /root/test/@param       , Value: v
  Path: /root/test/a/b          , Value: e
  Path: /root/test/a/b/data/@id , Value: z
  Path: /root/test/a/b/data     , Value: g
  Path: /root/test/a/b          , Value: f
  Path: /root                   , Value: x yz

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
