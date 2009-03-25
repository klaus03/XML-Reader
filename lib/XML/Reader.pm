package XML::Reader;

use strict;
use warnings;

use XML::TokeParser;
use Carp;

require Exporter;

our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT      = qw();
our $VERSION     = '0.02';

sub new {
    shift;
    my $self = {};
    bless $self;

    my %hash = (comment => 0, strip => 1, filter => 1);
    %hash    = (%hash, %{$_[1]}) if defined $_[1];

    my $parser = XML::TokeParser->new($_[0]) or return;

    $self->{comment}  = $hash{comment};
    $self->{strip}    = $hash{strip};
    $self->{filter}   = $hash{filter};
    $self->{parser}   = $parser;
    $self->{command}  = [['Z', [], 0, 0, '']];
    $self->{plist}    = [];
    $self->{path}     = '/';
    $self->{tag}      = '';
    $self->{value}    = '';
    $self->{type}     = '?';
    $self->{is_start} = 0;
    $self->{is_end}   = 0;
    $self->{level}    = 0;
    $self->{prvtoken} = '';
    $self->{item}     = '';
    $self->{status}   = 'ok';

    return $self;
}

sub path     { $_[0]->{path};     }
sub tag      { $_[0]->{tag};      }
sub value    { $_[0]->{value};    }
sub type     { $_[0]->{type};     }
sub is_start { $_[0]->{is_start}; }
sub is_end   { $_[0]->{is_end};   }
sub level    { $_[0]->{level};    }

sub iterate {
    my $self = shift;

    {
        # try reading 3 tokens...
        until ($self->{status} ne 'ok' or @{$self->{command}} >= 3) {
            $self->read_token;
        }

        unless (@{$self->{command}}) {
            return;
        }

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

        # if the current element is of type 'Z', i.e. a dummy header, then get rid of it
        my $cmd = ${$self->{command}}[0]; # take the first line...
        if ($cmd->[0] eq 'Z') {
            shift @{$self->{command}};
            redo;
        }
    }

    my $cmd = shift @{$self->{command}};

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
        die "Failed assertion #0010: Found data type '".$cmd->[0]."', but expected ('A', 'C' or 'T')";
    }

    return 1;
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

sub read_token {
    my $self = shift;

    my $token = $self->{parser}->get_token;

    unless (defined $token) {
        $self->{status} = 'eof';
        return;
    }

    # inject empty text in front of start- and end-tags, if needed...
    if (!$self->{filter}) {
        if ($token->is_start_tag
        or  $token->is_end_tag
        or ($token->is_comment and $self->{comment})) {
            if ($self->{prvtoken} ne 'T' and $self->{prvtoken} ne '') {
                my @list = @{$self->{plist}};
                push @{$self->{command}}, ['T', \@list, 0, 0, ''];
            }
        }
    }

    # save the token in prvtoken...
    $self->{prvtoken} = $token->is_text      ? 'T' :
                        $token->is_start_tag ? 'S' :
                        $token->is_end_tag   ? 'E' :
                        $token->is_comment   ? 'C' : '';

    if ($token->is_start_tag) {
        push @{$self->{plist}}, $token->tag;
        my @list = @{$self->{plist}};

        # inject an empty text-token, in case that there are any attributes that follow...
        if (!$self->{filter} and keys %{$token->attr}) {
            push @{$self->{command}}, ['T', \@list, 0, 0, ''];
        }

        push @{$self->{command}}, map {['A', \@list, 0, 0, $_, $token->attr->{$_}]} sort keys %{$token->attr};
    }
    elsif ($token->is_end_tag) {
        $self->{item} = pop @{$self->{plist}};
    }
    elsif ($token->is_text) {
        my $text = $token->text;

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
    elsif ($token->is_comment and $self->{comment}) {
        my $text = $token->text;
        if ($self->{strip}) {
            $text =~ s{\A \s+}''xms;
            $text =~ s{\s+ \z}''xms;
            $text =~ s{\s+}' 'xmsg;
        }
        my @list = @{$self->{plist}};
        push @{$self->{command}}, ['C', \@list, 0, 0, $text];
    }
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

It was developped as a thin wrapper on top of XML::TokeParser. XML::TokeParser allows pull-mode
parsing, but does not keep track of the complete XML-Path. Also, the interface to XML::TokeParser
(see $t->is_start_tag, $t->is_end_tag, $t->is_text) requires you to distinguish between start-tags,
end-tags and text, which, in my view, complicates the interface.

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
L<XML::TiePYX>,
L<XML::Writer>.

=cut
