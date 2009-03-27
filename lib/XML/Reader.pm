package XML::Reader;

use strict;
use warnings;

use XML::Parser;

require Exporter;

our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ( all => [ qw() ] );
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT      = qw();
our $VERSION     = '0.04';

sub new {
    my $class = shift;
    my $self = {};

    my %hash = (comment => 0, strip => 1, filter => 1);
    %hash    = (%hash, %{$_[1]}) if defined $_[1];

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

    # This is a crucial moment: we are trying to open the file (the filename is
    # held in in $_[0]). If the filename happens to be a reference to a scalar, then
    # it is opened quite naturally as an 'in-memory-file'.
    # If the open fails, then we return failure from XML::Reader->new and the calling
    # program has to check $! to handle the failed call.

    open my $fh, '<', $_[0] or return;

    # Now we bless into XML::Reader, and we bless *before* creating the ExpatNB-object.
    # Thereby, to avoid a memory leak, we ensure that for each ExpatNB-object we call
    # XML::Reader->DESTROY when the object goes away. (-- by the way, we create that
    # ExpatNB-object by calling the XML::Parser->parse_start method --)

    bless $self, $class;

    # Now we are ready to call XML::Parser->parse_start -- XML::Parser->parse_start()
    # returns an object of type XML::Parser::ExpatNB. The XML::Parser::ExpatNB object
    # is where all the heavy lifting happens.

    # By calling the XML::Parser::Expat->new method (-- yes, XML::Parser::Expat
    # is a super-class of XML::Parser::ExpatNB --) we will have created a circular reference
    # in $self->{ExpatNB}{parser}.
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

    $self->{ExpatNB} = $XmlParser->parse_start(XR_Data => [], XR_Text => undef, XR_Status => 'ok', XR_fh => $fh)
      or die "Failed assertion #0020 in subroutine XML::Reader->new: Can't create XML::Parser->new";

    # The instruction "XR_Data => []" (-- the 'XR_...' prefix stands for 'Xml::Reader...' --)
    # inside XML::Parser->parse_start() creates an empty array $ExpatNB{XR_Data} = []
    # inside the ExpatNB object. This array is the place where the handlers put their data.
    #
    # Likewise, the instructions "XR_Text => undef", "XR_Status => 'ok'" and "XR_fh => $fh"
    # create corresponding elements inside the $ExpatNB-object.

    $self->{comment} = $hash{comment};
    $self->{strip}   = $hash{strip};
    $self->{filter}  = $hash{filter};

    $self->{using} = !defined($hash{using}) ? [] : ref($hash{using}) ? $hash{using} : [$hash{using}];

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
    $self->{type}     = '?';
    $self->{is_start} = 0;
    $self->{is_end}   = 0;
    $self->{level}    = 0;
    $self->{p_token}  = undef;
    $self->{item}     = '';

    return $self;
}

sub path     { $_[0]->{path};     }
sub tag      { $_[0]->{tag};      }
sub value    { $_[0]->{value};    }
sub type     { $_[0]->{type};     }
sub is_start { $_[0]->{is_start}; }
sub is_end   { $_[0]->{is_end};   }
sub level    { $_[0]->{level};    }
sub prefix   { $_[0]->{prefix};   }

sub XR_Data         { $_[0]->{ExpatNB}{XR_Data};           }
sub XR_Stat_not_ok  { $_[0]->{ExpatNB}{XR_Status} ne 'ok'; }
sub XR_Stat_set_eof { $_[0]->{ExpatNB}{XR_Status} = 'eof'; }
sub XR_fh           { $_[0]->{ExpatNB}{XR_fh};             }

sub handle_start {
    my ($ExpatNB, $element, @a) = @_;

    if (defined $ExpatNB->{XR_Text}) {
        push @{$ExpatNB->{XR_Data}}, ['T', $ExpatNB->{XR_Text}];
        $ExpatNB->{XR_Text} = undef;
    }

    my %attr = @a;
    push @{$ExpatNB->{XR_Data}}, ['S', $element, \%attr];
}

sub handle_end {
    my ($ExpatNB, $element) = @_;

    if (defined $ExpatNB->{XR_Text}) {
        push @{$ExpatNB->{XR_Data}}, ['T', $ExpatNB->{XR_Text}];
        $ExpatNB->{XR_Text} = undef;
    }

    push @{$ExpatNB->{XR_Data}}, ['E', $element];
}

sub handle_comment {
    my ($ExpatNB, $text) = @_;

    push @{$ExpatNB->{XR_Data}}, ['C', $text];
}

sub handle_char {
    my ($ExpatNB, $text) = @_;

    $ExpatNB->{XR_Text} .= $text;
}

sub iterate {
    my $self = shift;

    {
        # try reading 3 tokens...
        until ($self->XR_Stat_not_ok or @{$self->{command}} >= 3) {
            $self->read_token;
        }

        # return failure if end-of-file
        unless (@{$self->{command}}) {
            return;
        }

        # populate values
        $self->populate_values;

        # if the current element is of type 'Z', i.e. a dummy header, then get rid of it
        my $cmd = ${$self->{command}}[0];

        if ($cmd->[0] eq 'Z') {
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
        $self->{tag}      = $cmd->[4];
        $self->{value}    = $cmd->[5];
        $self->{is_start} = $cmd->[2];
        $self->{is_end}   = $cmd->[3];
        $self->{level}    = @{$cmd->[1]} + 1;
        $self->{type}     = '@';
    }
    elsif ($cmd->[0] eq 'T') {
        $self->{path}     = '/'.join('/', @{$cmd->[1]});
        $self->{tag}      = ${$cmd->[1]}[-1];
        $self->{value}    = $cmd->[4];
        $self->{is_start} = $cmd->[2];
        $self->{is_end}   = $cmd->[3];
        $self->{level}    = @{$cmd->[1]};
        $self->{type}     = 'T';
    }
    elsif ($cmd->[0] eq 'C') {
        $self->{path}     = '/'.join('/', @{$cmd->[1]}).'/#';
        $self->{tag}      = '';
        $self->{value}    = $cmd->[4];
        $self->{is_start} = $cmd->[2];
        $self->{is_end}   = $cmd->[3];
        $self->{level}    = @{$cmd->[1]} + 1;
        $self->{type}     = '#';
    }
    else {
        die "Failed assertion #0040 in subroutine XML::Reader->iterate: Found data type '".$cmd->[0]."', but expected ('A', 'C' or 'T')";
    }

    # Here we check for the {using => ...} option
    $self->{prefix} = '';

    for my $check (@{$self->{using}}) {
        if ($check.'/' eq substr($self->{path}, 0, length($check) + 1)) {
            my @ele = split m{/}xms, $check;
            my $count = @ele - 1;
            $self->{prefix} = $check;
            $self->{path}   = substr($self->{path}, length($check));
            $self->{level} -= $count;
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

    # inject empty text in front of start- and end-tags, if needed...
    if (!$self->{filter}) {
        if ($token->found_start_tag
        or  $token->found_end_tag
        or ($token->found_comment and $self->{comment})) {
            if (defined $self->{p_token} and !$self->{p_token}->found_text) {
                my @list = @{$self->{plist}};
                push @{$self->{command}}, ['T', \@list, 0, 0, ''];
            }
        }
    }

    # save the token in p_token...
    $self->{p_token} = $token;

    if ($token->found_start_tag) {
        push @{$self->{plist}}, $token->extract_tag;
        my @list = @{$self->{plist}};

        # inject an empty text-token, in case that there are any attributes that follow...
        if (!$self->{filter} and keys %{$token->extract_attr}) {
            push @{$self->{command}}, ['T', \@list, 0, 0, ''];
        }

        push @{$self->{command}}, map {['A', \@list, 0, 0, $_, $token->extract_attr->{$_}]} sort keys %{$token->extract_attr};
    }
    elsif ($token->found_end_tag) {
        $self->{item} = pop @{$self->{plist}};
    }
    elsif ($token->found_text) {
        my $text = $token->extract_text;

        if (!$self->{filter} or $text =~ m{\S}xms) {
            if ($self->{strip}) {
                $text =~ s{\A \s+}''xms;
                $text =~ s{\s+ \z}''xms;
                $text =~ s{\s+}' 'xmsg;
            }
            my @list = @{$self->{plist}};
            push @{$self->{command}}, ['T', \@list, 0, 0, $text];
        }
    }
    elsif ($token->found_comment and $self->{comment}) {
        my $text = $token->extract_text;
        if ($self->{strip}) {
            $text =~ s{\A \s+}''xms;
            $text =~ s{\s+ \z}''xms;
            $text =~ s{\s+}' 'xmsg;
        }
        my @list = @{$self->{plist}};
        push @{$self->{command}}, ['C', \@list, 0, 0, $text];
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

    until ($self->XR_Stat_not_ok or @{$self->XR_Data}) {

        # Here is the all important reading of a chunk of XML-data from the filehandle...
        read($self->XR_fh, my $buf, 256); # Buffer-length should really be 4096

        if ($buf eq '') {
            $self->XR_Stat_set_eof;
            last;
        }

        # ...and here is the all important parsing of that chunk:
        $self->{ExpatNB}->parse_more($buf);
    }

    unless (@{$self->XR_Data}) {
        return;
    }

    my $token = shift @{$self->XR_Data};
    bless $token, 'XML::Reader::Token';
}

sub DESTROY {
    my $self = shift;

    # There are circular references inside an XML::Parser::ExpatNB-object
    # which need to be cleaned up by calling XML::Parser::Expat->release.

    # I quote from the documentation of 'XML::Parser::Expat' (-- yes,
    # XML::Parser::Expat is a super-class of XML::Parser::ExpatNB --)
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
    return $type eq 'T' || $type eq 'C' ? $self->[1] : '';
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

  my $text = '<root>stu<test param="v">w</test>xyz</root>';
  my $rdr = XML::Reader->new(\$text) or die "Error: $!";

  while ($rdr->iterate) {
      print "Path = ", $rdr->path, ", Value = ", $rdr->value, "\n";
  }

=head1 DESCRIPTION

XML::Reader provides an easy to use and simple interface for sequentially parsing XML
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

For example, the following XML...

  <data>
    <item>abc</item>
    <item>
      <dummy/>
      fgh
      <inner name="ttt" id="fff">
        ooo <!-- comment --> ppp
      </inner>
    </item>
  </data>

...corresponds to a sequence of path/value pairs.

You can also keep track of the start- and end-tags: There is a method C<is_start>
which returns 1 or 0, depending on whether the XML-file had a start tag at the current position. There
is also the equivalent method C<is_end>. Just remember, those two method only make sense if filter is
switched off (otherwise those methods return constant 0). Finally, there is the method C<tag> which
gives you the current tag-name (or attribute-name).

Here is the sequence of path/value pairs, including C<is_start>, C<is_end> and C<tag>:

  path = '/data'                  value = ''        is_start = 1 is_end = 0 tag = 'data'
  path = '/data/item'             value = 'abc'     is_start = 1 is_end = 1 tag = 'item'
  path = '/data'                  value = ''        is_start = 0 is_end = 0 tag = 'data'
  path = '/data/item'             value = ''        is_start = 1 is_end = 0 tag = 'item'
  path = '/data/item/dummy'       value = ''        is_start = 1 is_end = 1 tag = 'dummy'
  path = '/data/item'             value = 'fgh'     is_start = 0 is_end = 0 tag = 'item'
  path = '/data/item/inner'       value = ''        is_start = 1 is_end = 0 tag = 'inner'
  path = '/data/item/inner/@id'   value = 'fff'     is_start = 0 is_end = 0 tag = 'id'
  path = '/data/item/inner/@name' value = 'ttt'     is_start = 0 is_end = 0 tag = 'name'
  path = '/data/item/inner'       value = 'ooo'     is_start = 0 is_end = 0 tag = 'inner'
  path = '/data/item/inner/#'     value = 'comment' is_start = 0 is_end = 0 tag = ''
  path = '/data/item/inner'       value = 'ppp'     is_start = 0 is_end = 1 tag = 'inner'
  path = '/data/item'             value = ''        is_start = 0 is_end = 1 tag = 'item'
  path = '/data'                  value = ''        is_start = 0 is_end = 1 tag = 'data'

=head1 INTERFACE

=head2 Object creation

To create an XML::Reader object, the following syntax is used:

  my $rdr = XML::Reader->new($data, {comment => 0, strip => 1, filter => 1})
    or die "Error: $!";

The element C<$data> (which is mandatory) is either the name of the XML-file, or a
reference to a string, in which case the content of that string is taken as the
text of the XML.

Here is an example to create an XML::Reader object with a file-name:

  my $rdr = XML::Reader->new('input.xml') or die "Error: $!";

Here is another example to create an XML::Reader object with a reference:

  my $rdr = XML::Reader->new(\'<data>abc</data>') or die "Error: $!";

One ,or more, of the following options can be added as a hash-reference:

=over

=item option {comment => 0}

The option {comment => 1} allows comments to be passed through. The option {comment => 0}
disables comments. The default is {comment => 0}.

=item option {strip => 1}

The option {strip => 1} strips all leading and trailing spaces from text and comments.
(attributes are never stripped). The default is {strip => 1}.

=item option {filter => 1}

The option {filter => 1} removes all empty text lines. Be careful if you want to use the
C<is_start> and C<is_end> methods, in which case you have to set option {filter => 0}.
The default is {filter => 1}.

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

Provides the actual value (i.e. text, attribute or comment).

=item type

Provides the type of the value: 'T' for text, '@' for attributes, '#' for comments.

=item tag

Provides the current tag-name (or attribute-name).

=item is_start

Returns 1 or 0, depending on whether the XML-file had a start tag at the current position.
Be careful, this method only make sense if filter is switched off (otherwise constant 0 is
returned).

=item is_end

Returns 1 or 0, depending on whether the XML-file had an end tag at the current position.
Be careful, this method only make sense if filter is switched off (otherwise constant 0 is
returned).

=item level

Indicates the nesting level of the XPath expression (numeric value greater than zero).

=item prefix

Shows the prefix which has been removed in option {using => ...}. Returns the empty string if
option {using => ...} has not been specified.

=back

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
