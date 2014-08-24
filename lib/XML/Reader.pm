package XML::Reader;

use strict;
use warnings;
use Carp;

use XML::Parser;

require Exporter;

our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ( all => [ qw(slurp_xml) ] );
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT      = qw();
our $VERSION     = '0.34';

sub newhd {
    my $class = shift;
    my $self = {};

    # Option {filter => 2} includes attribute lines before <start>.
    # Option {filter => 3} no       attribute lines.
    # Option {filter => 4} includes attribute lines after <start> and splits <start>, text and </end>.
    # Option {filter => 5} reads roots and branches.

    my %opt = (strip => 1, filter => 2, parse_pi => 0, parse_ct => 0); # newhd defaults to filter=>2
    %opt    = (%opt, %{$_[1]}) if defined $_[1];

    unless ($opt{filter} == 2 or $opt{filter} == 3 or $opt{filter} == 4 or $opt{filter} == 5) {
        croak "Failed assertion #0005 in subroutine XML::Reader->newhd: filter is set to '$opt{filter}', but must be 2, 3, 4 or 5";
    }

    my $XmlParser = XML::Parser->new
      or croak "Failed assertion #0010 in subroutine XML::Reader->newhd: Can't create XML::Parser->new";

    # The following references to the handler-functions from the XML::Parser object will be 
    # copied into the ExpatNB object during the later call to XML::Parser->parse_start.

    $XmlParser->setHandlers(
        Start   => \&handle_start,
        End     => \&handle_end,
        Proc    => \&handle_procinst,
        XMLDecl => \&handle_decl,
        Char    => \&handle_char,
        Comment => \&handle_comment,
    );

    # We are trying to open the file (the filename is held in in $_[0]). If the filename
    # happens to be a reference to a scalar, then it is opened quite naturally as an
    # 'in-memory-file'. If the open fails, then we return failure from XML::Reader->newhd
    # and the calling program has to check $! to handle the failed call.
    # If, however, the filename is already a filehandle (i.e. ref($_[0]) eq 'GLOB'), then
    # we use that filehandle directly

    my $fh;
    if (ref($_[0]) eq 'GLOB') {
        $fh = $_[0];
    }
    else {
        open $fh, '<', $_[0] or return;
    }

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
    # will be performed in XML::Reader->DESTROY, which calls XML::Parser::Expat->release.

    # This is an important moment (-- in terms of memory management, at least --).
    # XML::Parser->parse_start creates an XML::Parser::ExpatNB-object, which in turn generates
    # a circular reference (invisible with Data::Dumper). That circular reference will have to
    # be cleaned up when the XML::Reader-object goes away (see XML::Reader->DESTROY).

    $self->{ExpatNB} = $XmlParser->parse_start(
        XR_Data      => [],
        XR_Text      => '',
        XR_Comment   => '',
        XR_fh        => $fh,
        XR_Att       => [],
        XR_ProcInst  => [],
        XR_Decl      => {},
        XR_Prv_SPECD => '',
        XR_Emit_attr => ($opt{filter} == 3 ? 0 : 1),
        XR_Split_up  => ($opt{filter} == 4 || $opt{filter} == 5 ? 1 : 0),
        XR_Strip     => $opt{strip},
        XR_ParseInst => $opt{parse_pi},
        XR_ParseComm => $opt{parse_ct},
      ) or croak "Failed assertion #0020 in subroutine XML::Reader->newhd: Can't create XML::Parser->parse_start";

    # for XML::Reader, version 0.21 (12-Sep-2009):
    # inject an {XR_debug} into $self->{ExpatNB}, if so requested by $opt{debug}

    if (exists $opt{debug}) { $self->{ExpatNB}{XR_debug} = $opt{debug}; }

    # The instruction "XR_Data => []" (-- the 'XR_...' prefix stands for 'Xml::Reader...' --)
    # inside XML::Parser->parse_start() creates an empty array $ExpatNB{XR_Data} = []
    # inside the ExpatNB object. This array is the place where the handlers put their data.
    #
    # Likewise, the instructions "XR_Text => ''", "XR_Comment => ''", and "XR_fh => $fh" , etc...
    # create corresponding elements inside the $ExpatNB-object.

    $self->{filter}  = $opt{filter};
    $self->{using}   = !defined($opt{using}) ? [] : ref($opt{using}) ? $opt{using} : [$opt{using}];

    # ********************************************************************************************
    # The following lines have been disabled by Klaus Eichner, 30 Oct 2009 (for version 0.29)
    # ********************************************************************************************
    # remove all spaces and then all leading and trailing '/', then put back a single leading '/'
    # for my $check (@{$self->{using}}) {
    #    $check =~ s{\s}''xmsg;
    #    $check =~ s{\A /+}''xms;
    #    $check =~ s{/+ \z}''xms;
    #    $check = '/'.$check;
    # }
    # ********************************************************************************************

    $self->{bush}  = [];
    $self->{rlist} = [];

    if ($self->{filter} == 5) {
        for my $object (@_[2..$#_]) {
            if ($object->{root} =~ m{\A // ([^/] .*) \z}xms
            or  $object->{root} =~ m{\A    ([^/] .*) \z}xms) {
                my $chunk = $1;
                push @{$self->{rlist}}, {
                    root   => undef,
                    qr1    => qr{ / \Q$chunk\E \z}xms,
                    qrfix  => undef,
                    branch => $object->{branch},
                  };
            }
            else {
                push @{$self->{rlist}}, {
                    root   => $object->{root},
                    qr1    => undef,
                    qrfix  => undef,
                    branch => $object->{branch},
                  };
            }
        }
    }

    $self->{plist}        = [];
    $self->{path}         = '/';
    $self->{prefix}       = '';
    $self->{tag}          = '';
    $self->{value}        = '';
    $self->{att_hash}     = {};
    $self->{dec_hash}     = {};
    $self->{comment}      = '';
    $self->{pyx}          = '';
    $self->{rx}           = 0;
    $self->{rvalue}       = [];
    $self->{rstem}        = '';
    $self->{rresult}      = [];
    $self->{proc}         = '';
    $self->{type}         = '?';
    $self->{is_start}     = 0;
    $self->{is_end}       = 0;
    $self->{is_decl}      = 0;
    $self->{is_proc}      = 0;
    $self->{is_comment}   = 0;
    $self->{is_text}      = 0;
    $self->{is_attr}      = 0;
    $self->{is_value}     = 0;
    $self->{level}        = 0;
    $self->{item}         = '';

    return $self;
}

sub path         { $_[0]{path};         }
sub tag          { $_[0]{tag};          }
sub attr         { $_[0]{attr};         }
sub value        { $_[0]{value};        }
sub att_hash     { $_[0]{att_hash};     }
sub dec_hash     { $_[0]{dec_hash};     }
sub type         { $_[0]{type};         }
sub level        { $_[0]{level};        }
sub prefix       { $_[0]{prefix};       }
sub comment      { $_[0]{comment};      }
sub pyx          { $_[0]{pyx};          }
sub rx           { $_[0]{rx};           }
sub rvalue       { $_[0]{rvalue};       }
sub rstem        { $_[0]{rstem};        }
sub proc_tgt     { $_[0]{proc_tgt};     }
sub proc_data    { $_[0]{proc_data};    }
sub is_decl      { $_[0]{is_decl};      }
sub is_start     { $_[0]{is_start};     }
sub is_proc      { $_[0]{is_proc};      }
sub is_comment   { $_[0]{is_comment};   }
sub is_text      { $_[0]{is_text};      }
sub is_attr      { $_[0]{is_attr};      }
sub is_value     { $_[0]{is_value};     }
sub is_end       { $_[0]{is_end};       }

sub rval {
  ref $_[0]{rvalue} eq 'SCALAR' ? ${$_[0]{rvalue}} :
  ref $_[0]{rvalue} eq 'ARRAY'  ? @{$_[0]{rvalue}} :
                                  undef;
}

sub NB_data      { $_[0]{ExpatNB}{XR_Data}; }
sub NB_fh        { $_[0]{ExpatNB}{XR_fh};   }

sub iterate {
    my $self = shift;

    {
        if ($self->{filter} == 5) {
            my $res = shift @{$self->{rresult}};
            if ($res) {
                $self->{rx}     = $res->[0];
                $self->{rvalue} = $res->[1];
                $self->{rstem}  = $res->[2];
                return 1;
            }
        }

        my $token = $self->get_token;
        unless (defined $token) {
            return;
        }

        if ($token->found_start_tag) {
            push @{$self->{plist}}, $token->extract_tag;
            redo;
        }

        if ($token->found_end_tag) {
            pop @{$self->{plist}};
            redo;
        }

        my $prv_SPECD = $token->extract_prv_SPECD;
        my $nxt_SPECD = $token->extract_nxt_SPECD;

        $self->{rx}     = 0;
        $self->{rvalue} = [];
        $self->{rstem}  = '';

        if ($token->found_text) {
            my $text    = $token->extract_text;
            my $comment = $token->extract_comment;

            my $proc_tgt  = '';
            my $proc_data = '';
            if (@{$token->extract_proc} == 2) {
                $proc_tgt  = ${$token->extract_proc}[0];
                $proc_data = ${$token->extract_proc}[1];
            }

            $self->{is_decl}      =                          $prv_SPECD eq 'D'  ? 1 : 0;
            $self->{is_start}     =                          $prv_SPECD eq 'S'  ? 1 : 0;
            $self->{is_proc}      =                          $prv_SPECD eq 'P'  ? 1 : 0;
            $self->{is_comment}   =                          $prv_SPECD eq 'C'  ? 1 : 0;
            $self->{is_text}      = ($self->{filter} != 4 || $prv_SPECD eq '-') ? 1 : 0;
            $self->{is_end}       =                          $nxt_SPECD eq 'E'  ? 1 : 0;

            $self->{is_attr}      = 0;
            $self->{is_value}     = ($self->{is_text} || $self->{is_attr}) ? 1 : 0;

            $self->{path}         = '/'.join('/', @{$self->{plist}});
            $self->{attr}         = '';
            $self->{value}        = $text;
            $self->{comment}      = $comment;
            $self->{proc_tgt}     = $proc_tgt;
            $self->{proc_data}    = $proc_data;
            $self->{level}        = @{$self->{plist}};
            $self->{tag}          = @{$self->{plist}} ? ${$self->{plist}}[-1] : '';
            $self->{type}         = 'T';
            $self->{att_hash}     = {@{$token->extract_attr}};
            $self->{dec_hash}     = {@{$token->extract_decl}};
        }
        elsif ($token->found_attr) {
            my $key = $token->extract_attkey;
            my $val = $token->extract_attval;

            $self->{is_decl}      = 0;
            $self->{is_start}     = 0;
            $self->{is_proc}      = 0;
            $self->{is_comment}   = 0;
            $self->{is_text}      = 0;
            $self->{is_end}       = 0;

            $self->{is_attr}      = 1;
            $self->{is_value}     = 1;

            $self->{path}         = '/'.join('/', @{$self->{plist}}).'/@'.$key;
            $self->{attr}         = $key;
            $self->{value}        = $val;
            $self->{comment}      = '';
            $self->{proc_tgt}     = '';
            $self->{proc_data}    = '';
            $self->{level}        = @{$self->{plist}} + 1;
            $self->{tag}          = '@'.$key;
            $self->{type}         = '@';
            $self->{att_hash}     = {};
            $self->{dec_hash}     = {};
        }
        else {
            croak "Failed assertion #0030 in subroutine XML::Reader->iterate: Found data type '".$token->[0]."'";
        }

        # for {filter => 4} setup pyx
        # (-- and promote $self->{type} from 'T'/'@' to any of the following codes: 'D', '?', 'S', 'E', '#', 'T', '@' --)
        if ($self->{filter} == 4) {
            if    ($self->{type} eq '@') { $self->{pyx} = 'A'.$self->{attr}.' '.$self->{value}; }
            elsif ($self->{is_decl})     { my $dc = $self->{dec_hash};
                                           $self->{type} = 'D'; $self->{pyx} = '?xml'.join('', map {" $_='$dc->{$_}'"} sort {$b cmp $a} keys %$dc); }
            elsif ($self->{is_proc})     { $self->{type} = '?'; $self->{pyx} = '?'.$self->{proc_tgt}.' '.$self->{proc_data}; }
            elsif ($self->{is_start})    { $self->{type} = 'S'; $self->{pyx} = '('.$self->{tag}; }
            elsif ($self->{is_end})      { $self->{type} = 'E'; $self->{pyx} = ')'.$self->{tag}; }
            elsif ($self->{is_comment})  { $self->{type} = '#'; $self->{pyx} = '#'.$self->{comment}; }
            elsif ($self->{is_text})     { $self->{type} = 'T'; $self->{pyx} = '-'.$self->{value}; }
            else {
                croak "Failed assertion #0040 in subroutine XML::Reader->iterate: Found invalid ".
                  "prv_SPECD = '$prv_SPECD', ".
                  "nxt_SPECD = '$nxt_SPECD', ".
                  "type = '".$self->{type}."'";
            }
            $self->{pyx} =~ s{\n}'\\n'xmsg; # replace newlines by a literal "\\n"
        }
        else {
            $self->{pyx} = undef;
        }

        # for {filter => 5} check roots
        if ($self->{filter} == 5) {
            for my $r (0..$#{$self->{rlist}}) {
                my $param = $self->{rlist}[$r];

                my $twig;
                my $stem;

                my $root;
                if (defined $param->{root}) {
                    $root = $param->{root};
                }
                elsif (defined $param->{qrfix}) {
                    $root = $param->{qrfix};
                }
                elsif (defined $param->{qr1}) {
                    if ($self->{path} =~ $param->{qr1}) {
                        $root = $self->{path};
                        $param->{qrfix} = $root;
                    }
                }

                if (defined $root) {
                    if ($self->{path} eq $root) {
                        $stem = $root;
                        $twig = '/';
                    }
                    elsif (substr($self->{path}, 0, length($root) + 1) eq $root.'/') {
                        $stem = $root;
                        $twig = substr($self->{path}, length($root));
                    }
                }

                next unless defined $twig;

                if (ref $param->{branch}) { # here we have an array of branches...
                    if ($twig eq '/' and $self->{is_start}) {
                        $self->{bush}[$r] = [];
                    }

                    if ($self->{is_value}) {
                        for my $i (0..$#{$param->{branch}}) {
                            if ($param->{branch}[$i] eq $twig) {
                                $self->{bush}[$r][$i] .= $self->{value};
                            }
                        }
                    }
                }
                else { # here we have branch that is a simple scalar...
                    if ($twig eq '/' and $self->{is_start}) {
                        $self->{bush}[$r] = \do{ my $xml = '' };
                    }

                    if ($param->{branch} eq '*') { # addition for ver 0.34 (Klaus Eichner, 26th Apr 2010)
                        my $element = '';
                        if ($self->{is_start}) {
                            $element .= '<'.$self->{tag};
                            for my $key (sort keys %{$self->{att_hash}}) {
                                my $kval = $self->{att_hash}{$key};
                                $kval =~ s{&}'&amp;'xmsg;
                                $kval =~ s{'}'&apos;'xmsg;
                                $kval =~ s{<}'&lt;'xmsg;
                                $kval =~ s{>}'&gt;'xmsg;
                                $element .= qq{ $key='$kval'};
                            }
                            $element .= '>';
                        }
                        if ($self->{is_text}) {
                            my $tval = $self->{value};
                            if ($tval ne '') {
                                $tval =~ s{&}'&amp;'xmsg;
                                $tval =~ s{<}'&lt;'xmsg;
                                $tval =~ s{>}'&gt;'xmsg;
                                $element .= $tval;
                            }
                        }
                        if ($self->{is_end}) {
                            $element .= '</'.$self->{tag}.'>';
                        }

                        ${$self->{bush}[$r]} .= $element;
                    }
                }

                if ($twig eq '/' and $self->{is_end}) {
                    push @{$self->{rresult}}, [$r, $self->{bush}[$r], $stem];
                    $param->{qrfix} = undef;
                }
            }
            redo;
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

        # check if option {using => ...} has been requested, and if so, then skip all
        # lines that don't have a prefix...
        if (@{$self->{using}} and $self->{prefix} eq '') {
            redo;
        }
    }

    return 1;
}

sub get_token {
    my $self = shift;

    until (@{$self->NB_data}) {

        # Here is the all important reading of a chunk of XML-data from the filehandle...
        read($self->NB_fh, my $buf, 4096);

        # We leave immediately as soon as there is no more data left (EOF)
        last if $buf eq '';

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
sub handle_decl {
    my ($ExpatNB, $version, $encoding, $standalone) = @_;

    return unless $ExpatNB->{XR_ParseInst};

    convert_structure($ExpatNB, 'D');
    $ExpatNB->{XR_Decl} = [(defined $version    ? (version    => $version)    : ()),
                           (defined $encoding   ? (encoding   => $encoding)   : ()),
                           (defined $standalone ? (standalone => $standalone) : ()),
                          ];
}

sub handle_procinst {
    my ($ExpatNB, $target, $data) = @_;

    return unless $ExpatNB->{XR_ParseInst};

    convert_structure($ExpatNB, 'P');
    $ExpatNB->{XR_ProcInst} = [$target, $data];
}

sub handle_comment {
    my ($ExpatNB, $comment) = @_;

    return unless $ExpatNB->{XR_ParseComm};

    convert_structure($ExpatNB, 'C');
    $ExpatNB->{XR_Comment} = $comment;
}

sub handle_start {
    my ($ExpatNB, $element, @attr) = @_;

    convert_structure($ExpatNB, 'S');
    $ExpatNB->{XR_Att} = \@attr;
    push @{$ExpatNB->{XR_Data}}, ['<', $element];
}

sub handle_end {
    my ($ExpatNB, $element) = @_;

    convert_structure($ExpatNB, 'E');
    push @{$ExpatNB->{XR_Data}}, ['>', $element];
}

sub handle_char {
    my ($ExpatNB, $text) = @_;

    $ExpatNB->{XR_Text} .= $text;
}

sub convert_structure {
    my ($ExpatNB, $Param_SPECD) = @_; # $Param_SPECD can be either 'S', 'P', 'E', 'C' or 'D' (or even '*')

    # These are the text and comment that may be stripped
    my $text    = $ExpatNB->{XR_Text};
    my $comment = $ExpatNB->{XR_Comment};

    # strip spaces if requested...
    if ($ExpatNB->{XR_Strip}) {
        for my $item ($text, $comment) {
            $item =~ s{\A \s+}''xms;
            $item =~ s{\s+ \z}''xms;
            $item =~ s{\s+}' 'xmsg;
        }
    }

    # Don't do anything for the first tag...
    unless ($ExpatNB->{XR_Prv_SPECD} eq '') {
        # Here we save the previous 'SPECD' and the current (i.e. next) 'SPECD' into lexicals
        # so that we can manipulate them
        my $prev_SPECD = $ExpatNB->{XR_Prv_SPECD};
        my $next_SPECD = $Param_SPECD;

        # Do we want <start>, <end>, <!-- comment --> and <? pi ?> split up into separate lines ?
        if ($ExpatNB->{XR_Split_up}) {
            if ($prev_SPECD ne 'E') {
                # emit the opening tag with empty text
                push @{$ExpatNB->{XR_Data}},
                  ['T', '', $comment, $prev_SPECD, '*', $ExpatNB->{XR_Att}, $ExpatNB->{XR_ProcInst}, $ExpatNB->{XR_Decl}];
            }

            if ($ExpatNB->{XR_Emit_attr}) {
                # Here we emit attributes on their proper lines -- *after* the start-line (see above) ...
                my %at = @{$ExpatNB->{XR_Att}};
                for my $key (sort keys %at) {
                    push @{$ExpatNB->{XR_Data}}, ['A', $key, $at{$key}];
                }
            }

            # emit text (only if it is not empty)
            unless ($text eq '') {
                push @{$ExpatNB->{XR_Data}},
                  ['T', $text, '', '-', '*', [], [], []];
            }

            if ($next_SPECD eq 'E') {
                # emit the closing tag with empty text
                push @{$ExpatNB->{XR_Data}},
                  ['T', '', '', '*', $next_SPECD, [], [], []];
            }
        }
        # Here we don't want <start>, <end>, <!-- comment --> and <? pi ?> split up into separate lines !
        else {
            # Do we really want to emit attributes on their proper lines ? -- or do we just
            # want to publish the attributes on element ${$ExpatNB->{XR_Data}}[5] ?
            if ($ExpatNB->{XR_Emit_attr}) {

                my %at = @{$ExpatNB->{XR_Att}};

                # Here we emit attributes on their proper lines -- *before* the start line (see below) ...
                for my $key (sort keys %at) {
                    push @{$ExpatNB->{XR_Data}}, ['A', $key, $at{$key}];
                }
            }

            # And here we emit the text
            push @{$ExpatNB->{XR_Data}},
              ['T', $text, $comment, $prev_SPECD, $next_SPECD, $ExpatNB->{XR_Att}, $ExpatNB->{XR_ProcInst}, $ExpatNB->{XR_Decl}];
        }
    }

    # Initialise values:
    $ExpatNB->{XR_Text}      = '';
    $ExpatNB->{XR_Comment}   = '';
    $ExpatNB->{XR_Att}       = [];
    $ExpatNB->{XR_ProcInst}  = [];
    $ExpatNB->{XR_Decl}      = [];

    $ExpatNB->{XR_Prv_SPECD} = $Param_SPECD;
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

    # There is a possibility that the XML::Parser::ExpatNB-object did not get
    # created, while still blessing the XML::Reader object. Therefore we have to
    # test for this case before calling XML::Parser::ExpatNB->release.

    if ($self->{ExpatNB}) {
        $self->{ExpatNB}->release; # ...and not $self->{ExpatNB}->parse_done;
    }
}

sub slurp_xml {
    my $data = shift;

    my @tree = map {[]} @_; # start with as many empty lists as there are roots 

    my $rdr = XML::Reader->newhd($data, {filter => 5}, @_) or die "Error: $!";

    while ($rdr->iterate) {
        push @{$tree[$rdr->rx]}, $rdr->rvalue;
    }

    return \@tree;
}

# The package used here - XML::Reader::Token 
# has been inspired by    XML::TokeParser::Token

package XML::Reader::Token;

our $VERSION = '0.34';

sub found_start_tag   { $_[0][0] eq '<'; }
sub found_end_tag     { $_[0][0] eq '>'; }
sub found_attr        { $_[0][0] eq 'A'; }
sub found_text        { $_[0][0] eq 'T'; }

sub extract_tag       { $_[0][1]; } # type eq '<' or '>'

sub extract_attkey    { $_[0][1]; } # type eq 'A'
sub extract_attval    { $_[0][2]; } # type eq 'A'

sub extract_text      { $_[0][1]; } # type eq 'T'
sub extract_comment   { $_[0][2]; } # type eq 'T'

sub extract_prv_SPECD { $_[0][3]; } # type eq 'T'
sub extract_nxt_SPECD { $_[0][4]; } # type eq 'T'
sub extract_attr      { $_[0][5]; } # type eq 'T'
sub extract_proc      { $_[0][6]; } # type eq 'T'
sub extract_decl      { $_[0][7]; } # type eq 'T'

1;

__END__

=head1 NAME

XML::Reader - Reading XML and providing path information based on a pull-parser.

=head1 SYNOPSIS

  use XML::Reader;

  my $text = q{<init>n <?test pi?> t<page node="400">m <!-- remark --> r</page></init>};

  my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";
  while ($rdr->iterate) {
      printf "Path: %-19s, Value: %s\n", $rdr->path, $rdr->value;
  }

This program produces the following output:

  Path: /init              , Value: n t
  Path: /init/page/@node   , Value: 400
  Path: /init/page         , Value: m r
  Path: /init              , Value:

=head1 DESCRIPTION

XML::Reader provides a simple and easy to use interface for sequentially parsing XML
files (so called "pull-mode" parsing) and at the same time keeps track of the complete XML-path.

It was developped as a wrapper on top of XML::Parser (while, at the same time, some basic functions
have been copied from XML::TokeParser). Both XML::Parser and XML::TokeParser allow pull-mode
parsing, but do not keep track of the complete XML-Path. Also, the interfaces to XML::Parser and
XML::TokeParser require you to distinguish between start-tags, end-tags and text on seperate lines,
which, in my view, complicates the interface (although, XML::Reader allows option {filter => 4} which
emulates start-tags, end-tags and text on separate lines, if that's what you want).

There is also XML::TiePYX, which lets you pull-mode parse XML-Files (see
L<http://www.xml.com/pub/a/2000/03/15/feature/index.html> for an introduction to PYX).
But still, with XML::TiePYX you need to account for start-tags, end-tags and text, and it does not
provide the full XML-path.

By contrast, XML::Reader translates start-tags, end-tags and text into XPath-like expressions. So
you don't need to worry about tags, you just get a path and a value, and that's it. (However, should
you wish to operate XML::Reader in a PYX compatible mode, there is option {filter => 4}, as mentioned
above, which allows you to parse XML in that way).

But going back to the normal mode of operation, here is an example XML in variable '$line1':

  my $line1 = 
  q{<?xml version="1.0" encoding="iso-8859-1"?>
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

This example can be parsed with XML::Reader using the methods C<iterate> to iterate one-by-one through the
XML-data, C<path> and C<value> to extract the current XML-path and its value.

You can also keep track of the start- and end-tags: There is a method C<is_start>, which returns 1 or
0, depending on whether the XML-file had a start tag at the current position. There is also the
equivalent method C<is_end>.

There are also the methods C<tag>, C<attr>, C<type> and C<level>. C<tag> gives you the current tag-name,
C<attr> returns the attribute-name, C<type> returns either 'T' for text or '@' for attributes and
C<level> indicates the current nesting-level (a number >= 0).

Here is a sample program which parses the XML in '$line1' from above to demonstrate the principle...

  use XML::Reader;

  my $rdr = XML::Reader->newhd(\$line1) or die "Error: $!";
  my $i = 0;
  while ($rdr->iterate) { $i++;
      printf "%3d. pat=%-22s, val=%-9s, s=%-1s, e=%-1s, tag=%-6s, atr=%-6s, t=%-1s, lvl=%2d\n", $i,
        $rdr->path, $rdr->value, $rdr->is_start, $rdr->is_end, $rdr->tag, $rdr->attr, $rdr->type, $rdr->level;
  }

...and here is the output:

   1. pat=/data                 , val=         , s=1, e=0, tag=data  , atr=      , t=T, lvl= 1
   2. pat=/data/item            , val=abc      , s=1, e=1, tag=item  , atr=      , t=T, lvl= 2
   3. pat=/data                 , val=         , s=0, e=0, tag=data  , atr=      , t=T, lvl= 1
   4. pat=/data/item            , val=         , s=1, e=0, tag=item  , atr=      , t=T, lvl= 2
   5. pat=/data/item/dummy      , val=         , s=1, e=1, tag=dummy , atr=      , t=T, lvl= 3
   6. pat=/data/item            , val=fgh      , s=0, e=0, tag=item  , atr=      , t=T, lvl= 2
   7. pat=/data/item/inner/@id  , val=fff      , s=0, e=0, tag=@id   , atr=id    , t=@, lvl= 4
   8. pat=/data/item/inner/@name, val=ttt      , s=0, e=0, tag=@name , atr=name  , t=@, lvl= 4
   9. pat=/data/item/inner      , val=ooo ppp  , s=1, e=1, tag=inner , atr=      , t=T, lvl= 3
  10. pat=/data/item            , val=         , s=0, e=1, tag=item  , atr=      , t=T, lvl= 2
  11. pat=/data                 , val=         , s=0, e=1, tag=data  , atr=      , t=T, lvl= 1

=head1 INTERFACE

=head2 Object creation

To create an XML::Reader object, the following syntax is used:

  my $rdr = XML::Reader->newhd($data,
    {strip => 1, filter => 2, using => ['/path1', '/path2']})
    or die "Error: $!";

The element $data (which is mandatory) is the name of the XML-file, or a
reference to a string, in which case the content of that string is taken as the
text of the XML.

Alternatively, $data can also be a previously opened filehandle, such as \*STDIN, in which case
that filehandle is used to read the XML.

Here is an example to create an XML::Reader object with a file-name:

  my $rdr = XML::Reader->newhd('input.xml') or die "Error: $!";

Here is another example to create an XML::Reader object with a reference:

  my $rdr = XML::Reader->newhd(\'<data>abc</data>') or die "Error: $!";

Here is an example to create an XML::Reader object with an open filehandle:

  open my $fh, '<', 'input.xml' or die "Error: $!";
  my $rdr = XML::Reader->newhd($fh);

Here is an example to create an XML::Reader object with \*STDIN:

  my $rdr = XML::Reader->newhd(\*STDIN);

One or more of the following options can be added as a hash-reference:

=over

=item option {parse_ct => }

Option {parse_ct => 1} allows for comments to be parsed, default is {parse_ct => 0}

=item option {parse_pi => }

Option {parse_pi => 1} allows for processing-instructions and XML-Declarations to be parsed,
default is {parse_pi => 0}

=item option {using => }

Option {using => } allows for selecting a sub-tree of the XML.

The syntax is {using => ['/path1/path2/path3', '/path4/path5/path6']}

=item option {filter => }

Option {filter => 2} shows all lines, including attributes.

Option {filter => 3} removes attribute lines (i.e. it removes lines where $rdr->type eq '@').
Instead, it returns the attributes in a hash $rdr->att_hash.

Option {filter => 4} breaks down each line into its
individual start-tags, end-tags, attributes, comments and processing-instructions.
This allows the parsing of XML into pyx-formatted lines.

Option {filter => 5} selects only data for a given root. The elements for each root are collected in
an array reference (as specified by the branch) and returned when the root is complete. This
processing lies half way between option using (where all elements are returned one by one) and the
function slurp_xml (where all elements are collected in a branch, and all branches are collected
in an in-memory structure).

The syntax is {filter => 2|3|4|5}, default is {filter => 2}

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

Provides the actual value (i.e. the value of the current text or attribute).

Note that, when {filter => 2 or 3} and in case of an XML declaration (i.e. $rdr->is_decl == 1),
you want to suppress any value (which would be empty anyway). A typical code fragment would be:

  print $rdr->value, "\n" unless $rdr->is_decl;

The above code does *not* apply for {filter => 4}, in which case a simple "print $rdr->value;" suffices:

  print $rdr->value, "\n";

=item comment

Provides the comment of the XML. You should check if $rdr->is_comment is true before accessing the comment.

=item type

Provides the type of the value: 'T' for text, '@' for attributes.

If option {filter => 4} is in effect, then the type can be: 'T' for text, '@' for attributes,
'S' for start tags, 'E' for end-tags, '#' for comments, 'D' for the XML Declaration, '?' for
processing-instructions.

=item tag

Provides the current tag-name.

=item attr

Provides the current attribute name (returns the empty string for non-attribute lines).

=item level

Indicates the nesting level of the XPath expression (numeric value greater than zero).

=item prefix

Shows the prefix which has been removed in option {using => ...}. Returns the empty string if
option {using => ...} has not been specified.

=item att_hash

Returns a reference to a hash with the current attributes of a start-tag (or empty hash if
it is not a start-tag).

=item dec_hash

Returns a reference to a hash with the current attributes of an XML-Declaration (or empty hash if
it is not an XML-Declaration).

=item proc_tgt

Returns the target (i.e. the first part) of a processing-instruction (or an empty string if
the current event is not a processing-instruction).

=item proc_data

Returns the data (i.e. the second part) of a processing-instruction (or an empty string if
the current event is not a processing-instruction).

=item pyx

Returns the pyx string of the current XML-event.

The pyx string is a string that starts with a specific first character. That first character
of each line of PYX tells you what type of event you are dealing with: if the first character is '(',
then you are dealing with a start event. If it's a ')', then you are dealing with and end event. If
it's an 'A' then you are dealing with attributes. If it's '-', then you are dealing with text. If it's
'?', then you are dealing with processing-instructions. (see L<http://www.xml.com/pub/a/2000/03/15/feature/index.html>
for an introduction to PYX).

The method C<pyx> makes sense only if option {filter => 4} is selected, for any filter other
than 4, undef is returned.

=item is_start

Returns 1 if the XML-file had a start tag at the current position, otherwise 0 is returned.

=item is_end

Returns 1 if the XML-file had an end tag at the current position, otherwise 0 is returned.

=item is_decl

Returns 1 if the XML-file had an XML-Declaration at the current position, otherwise 0 is returned.

=item is_proc

Returns 1 if the XML-file had a processing-instruction at the current position, otherwise 0 is returned.

=item is_comment

Returns 1 if the XML-file had a comment at the current position, otherwise 0 is returned.

=item is_text

Returns 1 if the XML-file had text at the current position, otherwise 0 is returned.

=item is_attr

Returns 1 if the XML-file had an attribute at the current position, otherwise 0 is returned.

=item is_value

Returns 1 if the XML-file has either a text or an attribute at the current position, otherwise 0 is
returned. This is mostly useful in mode {filter => 4} to see whether the method value() can be used.

=item rx

This is the index of the currently selected branch (only useful when {filter => 5} was set).

=item rval

This is the value of the currently selected branch (only useful when {filter => 5} was set).

=item rvalue

This is a reference to either a scalar or to an array of the currently selected branch (only useful when
{filter => 5} was set). rvalue is a faster, but not so convenient version of rval (with rvalue you will
have to do the dereferencing yourself).

=item rstem

This is the stem of the currently selected branch (only useful when {filter => 5} was set).

=back

=head1 OPTION USING

Option {using => ...} allows for selecting a sub-tree of the XML.

Here is how it works in detail...

option {using => ['/path1/path2/path3', '/path4/path5/path6']} eliminates all lines which do not
start with '/path1/path2/path3' (or with '/path4/path5/path6', for that matter). This effectively
leaves only lines starting with '/path1/path2/path3' or '/path4/path5/path6'.

Those lines (which are not eliminated) will have a shorter path by effectively removing the prefix 
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

=head1 OPTION PARSE_CT

Option {parse_ct => 1} allows for comments to be parsed (usually, comments are ignored by XML::Reader,
that is {parse_ct => 0} is the default.

Here is an example where comments are ignored by default:

  use XML::Reader;

  my $text = q{<?xml version="1.0"?><dummy>xyz <!-- remark --> stu <?ab cde?> test</dummy>};

  my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";

  while ($rdr->iterate) {
      if ($rdr->is_decl)    { my %h = %{$rdr->dec_hash};
                              print "Found decl     ",  join('', map{" $_='$h{$_}'"} sort keys %h), "\n"; }
      if ($rdr->is_proc)    { print "Found proc      ", "t=", $rdr->proc_tgt, ", d=", $rdr->proc_data, "\n"; }
      if ($rdr->is_comment) { print "Found comment   ", $rdr->comment, "\n"; }
      print "Text '", $rdr->value, "'\n" unless $rdr->is_decl;
  }

Here is the output:

  Text 'xyz stu test'

Now, the very same XML data, and the same algorithm, except for the option {parse_ct => 1}, which is now
activated:

  use XML::Reader;

  my $text = q{<?xml version="1.0"?><dummy>xyz <!-- remark --> stu <?ab cde?> test</dummy>};

  my $rdr = XML::Reader->newhd(\$text, {parse_ct => 1}) or die "Error: $!";

  while ($rdr->iterate) {
      if ($rdr->is_decl)    { my %h = %{$rdr->dec_hash};
                              print "Found decl     ",  join('', map{" $_='$h{$_}'"} sort keys %h), "\n"; }
      if ($rdr->is_proc)    { print "Found proc      ", "t=", $rdr->proc_tgt, ", d=", $rdr->proc_data, "\n"; }
      if ($rdr->is_comment) { print "Found comment   ", $rdr->comment, "\n"; }
      print "Text '", $rdr->value, "'\n" unless $rdr->is_decl;
  }

Here is the output:

  Text 'xyz'
  Found comment   remark
  Text 'stu test'

=head1 OPTION PARSE_PI

Option {parse_pi => 1} allows for processing-instructions and XML-Declarations to be parsed (usually,
processing-instructions and XML-Declarations are ignored by XML::Reader, that is {parse_pi => 0} is the default.

As an example, we use the very same XML data, and the same algorithm from the above paragraph, except for the
option {parse_pi => 1}, which is now activated (together with option {parse_ct => 1}):

  use XML::Reader;

  my $text = q{<?xml version="1.0"?><dummy>xyz <!-- remark --> stu <?ab cde?> test</dummy>};

  my $rdr = XML::Reader->newhd(\$text, {parse_ct => 1, parse_pi => 1}) or die "Error: $!";

  while ($rdr->iterate) {
      if ($rdr->is_decl)    { my %h = %{$rdr->dec_hash};
                              print "Found decl     ",  join('', map{" $_='$h{$_}'"} sort keys %h), "\n"; }
      if ($rdr->is_proc)    { print "Found proc      ", "t=", $rdr->proc_tgt, ", d=", $rdr->proc_data, "\n"; }
      if ($rdr->is_comment) { print "Found comment   ", $rdr->comment, "\n"; }
      print "Text '", $rdr->value, "'\n" unless $rdr->is_decl;
  }

Note the "unless $rdr->is_decl" in the above code. This is to avoid outputting any value after the XML declaration
(which would be empty anyway).

Here is the output:

  Found decl      version='1.0'
  Text 'xyz'
  Found comment   remark
  Text 'stu'
  Found proc      t=ab, d=cde
  Text 'test'

=head1 OPTION FILTER

Option {filter => } allows to select different operation modes when processing the XML data.

=head2 Option {filter => 2}

With option {filter => 2}, XML::Reader produces one line for each character event.
A preceding start-tag results in method is_start to be set to 1, a trailing end-tag
results in method is_end to be set to 1. Likewise, a preceding comment results in method
is_comment to be set to 1, a preceding XML-declaration results in method is_decl to be set
to 1, a preceding processing-instruction results in method is_proc to be set to 1.

Also, attribute lines are added via the special '/@...' syntax.

Option {filter => 2} is the default.

Here is an example...

  use XML::Reader;

  my $text = q{<root><test param='&lt;&gt;v"'><a><b>"e"<data id="&lt;&gt;z'">'g'&amp;&lt;&gt;</data>}.
             q{f</b></a></test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";
  while ($rdr->iterate) {
      printf "Path: %-24s, Value: %s\n", $rdr->path, $rdr->value;
  }

This program (with implicit option {filter => 2} as default) produces the following output:

  Path: /root                   , Value:
  Path: /root/test/@param       , Value: <>v"
  Path: /root/test              , Value:
  Path: /root/test/a            , Value:
  Path: /root/test/a/b          , Value: "e"
  Path: /root/test/a/b/data/@id , Value: <>z'
  Path: /root/test/a/b/data     , Value: 'g'&<>
  Path: /root/test/a/b          , Value: f
  Path: /root/test/a            , Value:
  Path: /root/test              , Value:
  Path: /root                   , Value: x yz

The same {filter => 2} also allows to rebuild the structure of the XML with the help of the methods
C<is_start> and C<is_end>. To make things more interesting, we have the following additional requirement:
We want any text (but not tags and not attributes) to be wrapped inside a pair of "**...**" when it is
displayed. Please note also that in the above output, the first line ("Path: /root, Value:")
is empty, but important for the structure of the XML. Therefore we can't ignore it.

Let us now look at the same example (with option {filter => 2}), but with an additional algorithm to
reconstruct the original XML plus the additional requirement to wrap text (but not tags and not attributes)
inside "** **":

  use XML::Reader;

  my $text = q{<root><test param='&lt;&gt;v"'><a><b>"e"<data id="&lt;&gt;z'">'g'&amp;&lt;&gt;</data>}.
             q{f</b></a></test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";

  my %at;

  while ($rdr->iterate) {
      my $indentation = '  ' x ($rdr->level - 1);

      if ($rdr->type eq '@')  {
          $at{$rdr->attr} = $rdr->value;
          for ($at{$rdr->attr}) {
              s{&}'&amp;'xmsg;
              s{'}'&apos;'xmsg;
              s{<}'&lt;'xmsg;
              s{>}'&gt;'xmsg;
          }
      }


      if ($rdr->is_start) {
          print $indentation, '<', $rdr->tag, join('', map{" $_='$at{$_}'"} sort keys %at), '>', "\n";
      }

      unless ($rdr->type eq '@') { %at = (); }

      if ($rdr->type eq 'T' and $rdr->value ne '') {
          my $v = $rdr->value;
          for ($v) {
              s{&}'&amp;'xmsg;
              s{<}'&lt;'xmsg;
              s{>}'&gt;'xmsg;
          }
          print $indentation, "  ** $v **\n";
      }

      if ($rdr->is_end) {
          print $indentation, '</', $rdr->tag, '>', "\n";
      }
  }

...and here is the output:

  <root>
    <test param='&lt;&gt;v"'>
      <a>
        <b>
          ** "e" **
          <data id='&lt;&gt;z&apos;'>
            ** 'g'&amp;&lt;&gt; **
          </data>
          ** f **
        </b>
      </a>
    </test>
    ** x yz **
  </root>

...this is proof that the original structure of the XML is not lost.

=head2 Option {filter => 3}

Option {filter => 3} works very much like {filter => 2}.

The difference, though, is that with option {filter => 3} all attribute-lines are suppressed
and instead, the attributes are presented for each start-line in the hash $rdr->att_hash().

This allows, in fact, to dispense with the global %at variable of the previous algorithm, and
use %{$rdr->att_hash} instead:

Here is the new algorithm for {filter => 3}, we don't need to worry about attributes (that is,
we don't need to check fot $rdr->type eq '@') and, as already mentioned, the %at variable is
replaced by %{$rdr->att_hash} :

  use XML::Reader;

  my $text = q{<root><test param='&lt;&gt;v"'><a><b>"e"<data id="&lt;&gt;z'">'g'&amp;&lt;&gt;</data>}.
             q{f</b></a></test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->newhd(\$text, {filter => 3}) or die "Error: $!";

  while ($rdr->iterate) {
      my $indentation = '  ' x ($rdr->level - 1);

      if ($rdr->is_start) {
          my %h = %{$rdr->att_hash};
          for (values %h) {
              s{&}'&amp;'xmsg;
              s{'}'&apos;'xmsg;
              s{<}'&lt;'xmsg;
              s{>}'&gt;'xmsg;
          }
          print $indentation, '<', $rdr->tag,
            join('', map{" $_='$h{$_}'"} sort keys %h),
            '>', "\n";
      }

      if ($rdr->type eq 'T' and $rdr->value ne '') {
          my $v = $rdr->value;
          for ($v) {
              s{&}'&amp;'xmsg;
              s{<}'&lt;'xmsg;
              s{>}'&gt;'xmsg;
          }
          print $indentation, "  ** $v **\n";
      }

      if ($rdr->is_end) {
          print $indentation, '</', $rdr->tag, '>', "\n";
      }
  }

...the output for {filter => 3} is identical to the output for {filter => 2}:

  <root>
    <test param='&lt;&gt;v"'>
      <a>
        <b>
          ** "e" **
          <data id='&lt;&gt;z&apos;'>
            ** 'g'&amp;&lt;&gt; **
          </data>
          ** f **
        </b>
      </a>
    </test>
    ** x yz **
  </root>

Finally, we can (and we should) delegate the writing of XML to another module. I would suggest that
we use L<XML::Writer> for that. Here is the program that uses L<XML::Writer> to output XML:

  use XML::Reader;
  use XML::Writer;

  my $text = q{<root><test param='&lt;&gt;v"'><a><b>"e"<data id="&lt;&gt;z'">'g'&amp;&lt;&gt;</data>}.
             q{f</b></a></test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->newhd(\$text, {filter => 3}) or die "Error: $!";
  my $wrt = XML::Writer->new(OUTPUT => \*STDOUT, NEWLINES => 1);

  while ($rdr->iterate) {
      if ($rdr->is_start)                          { $wrt->startTag($rdr->tag, %{$rdr->att_hash}); }
      if ($rdr->type eq 'T' and $rdr->value ne '') { $wrt->characters('** '.$rdr->value.' **'); }
      if ($rdr->is_end)                            { $wrt->endTag($rdr->tag); }
  }

  $wrt->end();

Here is the output from L<XML::Writer>:

  <root
  ><test param="&lt;&gt;v&quot;"
  ><a
  ><b
  >** "e" **<data id="&lt;&gt;z'"
  >** 'g'&amp;&lt;&gt; **</data
  >** f **</b
  ></a
  ></test
  >** x yz **</root
  >

The format written by L<XML::Writer> needs some getting used to, but it is valid XML.

=head2 Option {filter => 4}

Although this is not the main purpose of XML::Reader, option {filter => 4} can generate individual lines for
start-tags, end-tags, comments, processing-instructions and XML-Declarations. Its aim is to generate
a pyx string for further processing and analysis.

Here is an example:

  use XML::Reader;

  my $text = q{<?xml version="1.0" encoding="iso-8859-1"?>
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

  while ($rdr->iterate) {
      printf "Type = %1s, pyx = %s\n", $rdr->type, $rdr->pyx;
  }

And here is the output:

  Type = D, pyx = ?xml version='1.0' encoding='iso-8859-1'
  Type = S, pyx = (delta
  Type = S, pyx = (dim
  Type = @, pyx = Aalter 511
  Type = S, pyx = (gamma
  Type = E, pyx = )gamma
  Type = S, pyx = (beta
  Type = T, pyx = -car
  Type = ?, pyx = ?tt dat
  Type = E, pyx = )beta
  Type = E, pyx = )dim
  Type = T, pyx = -dskjfh uuu
  Type = E, pyx = )delta

Be aware that comments can be produced by C<pyx> in a non-standard way if requested by {parse_ct => 1}. In fact,
comments are produced with a leading hash symbol which is not part of the pyx specification,
as can be seen by the following example:

  use XML::Reader;

  my $text = q{
    <delta>
      <!-- remark -->
    </delta>};

  my $rdr = XML::Reader->newhd(\$text, {filter => 4, parse_ct => 1}) or die "Error: $!";

  while ($rdr->iterate) {
      printf "Type = %1s, pyx = %s\n", $rdr->type, $rdr->pyx;
  }

Here is the output:

  Type = S, pyx = (delta
  Type = #, pyx = #remark
  Type = E, pyx = )delta

Finally, when operating with {filter => 4}, the usual methods (C<value>, C<attr>, C<path>, C<is_start>,
C<is_end>, C<is_decl>, C<is_proc>, C<is_comment>, C<is_attr>, C<is_text>, C<is_value>, C<comment>, C<proc_tgt>,
C<proc_data>, C<dec_hash> or C<att_hash>) remain operational. Here is an example:

  use XML::Reader;

  my $text = q{<?xml version="1.0"?>
    <parent abc="def"> <?pt hmf?>
      dskjfh <!-- remark -->
      <child>ghi</child>
    </parent>};

  my $rdr = XML::Reader->newhd(\$text, {filter => 4, parse_pi => 1, parse_ct => 1}) or die "Error: $!";

  while ($rdr->iterate) {
      printf "Path %-15s v=%s ", $rdr->path, $rdr->is_value;

      if    ($rdr->is_start)   { print "Found start tag ", $rdr->tag, "\n"; }
      elsif ($rdr->is_end)     { print "Found end tag   ", $rdr->tag, "\n"; }
      elsif ($rdr->is_decl)    { my %h = %{$rdr->dec_hash};
                                 print "Found decl     ",  join('', map{" $_='$h{$_}'"} sort keys %h), "\n"; }
      elsif ($rdr->is_proc)    { print "Found proc      ", "t=",    $rdr->proc_tgt, ", d=", $rdr->proc_data, "\n"; }
      elsif ($rdr->is_comment) { print "Found comment   ", $rdr->comment, "\n"; }
      elsif ($rdr->is_attr)    { print "Found attribute ", $rdr->attr, "='", $rdr->value, "'\n"; }
      elsif ($rdr->is_text)    { print "Found text      ", $rdr->value, "\n"; }
  }

Here is the output:

  Path /               v=0 Found decl      version='1.0'
  Path /parent         v=0 Found start tag parent
  Path /parent/@abc    v=1 Found attribute abc='def'
  Path /parent         v=0 Found proc      t=pt, d=hmf
  Path /parent         v=1 Found text      dskjfh
  Path /parent         v=0 Found comment   remark
  Path /parent/child   v=0 Found start tag child
  Path /parent/child   v=1 Found text      ghi
  Path /parent/child   v=0 Found end tag   child
  Path /parent         v=0 Found end tag   parent

Note that v=1 (i.e. $rdr->is_value == 1) for all text and all attributes.

=head2 Option {filter => 5}

With option {filter => 5}, you specify one (or many) roots, each root has a set of branches attached.
What you then get back is one record for each occurence of a root in the XML tree.
A root can start with a single slash (such as {root => '/tag1/tag2'}), in which case the path is
absolute, or it can start with a double-slash (such as {root => '//tag1/tag2'}), in which case the path
is relative. If you start your root with no slash at all (such as {root => 'tag1/tag2'}), your path is
also relative.

Each record then contains the elements that have been specified in the branches. (As a special case, the
branch can be a single '*' character, in which case the complete XML is produced for the root).

To obtain the elements that have been specified in the branches, you can use either function $rdr->rvalue
or $rdr->rval.

The easiest way to explain its effect is to show an example.

  use XML::Reader;

  my $line2 = q{
  <data>
    <supplier>ggg</supplier>
    <customer name="o'rob" id="444">
      <street>pod alley</street>
      <city>no city</city>
    </customer>
    <customer1 name="troy" id="333">
      <street>one way</street>
      <city>any city</city>
    </customer1>
    <tcustomer name="nbc" id="777">
      <street>away</street>
      <city>acity</city>
    </tcustomer>
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
    <p>
      <p>b1</p>
      <p>b2</p>
    </p>
    <p>
      b3
    </p>
  </data>
  };

Let's say we want to read the name, the street and the city of all customers in
any relative path ('customer') and we also want to read the supplier in the absolute path
'/data/supplier'. Then, we want to have data for the relative customer ('//customer')
supplied as pure XML ({branch => '*'}). Finally we want to have data for the relative path 'p'
as pure XML.

Data for our first root ('customer') is identified by $rdr->rx == 0, data for our second root
('/data/supplier') is identified by $rdr->rx == 1, data for our third root ('//customer')
is identified by $rdr->rx == 2, and data for our fourth root ('p') is identified by $rdr-rx == 3.

In the following program we will use function rdr->rvalue to obtain the data:

  my $rdr = XML::Reader->newhd(\$line2, {filter => 5},
    { root => 'customer',       branch => ['/@name', '/street', '/city'] },
    { root => '/data/supplier', branch => ['/']                          },
    { root => '//customer',     branch => '*' },
    { root => 'p',              branch => '*' },
  );

  my $root0 = '';
  my $root1 = '';
  my $root2 = '';
  my $root3 = '';

  my $stem0 = '';

  while ($rdr->iterate) {
      if ($rdr->rx == 0) {
          $stem0 .= "  ".$rdr->rstem."\n";
          for ($rdr->rvalue) {
              $root0 .= sprintf "  Cust: Name = %-7s Street = %-12s City = %s\n", $_->[0], $_->[1], $_->[2];
          }
      }
      elsif ($rdr->rx == 1) {
          for ($rdr->rvalue) {
              $root1 .= "  Supp: Name = ".$_->[0]."\n";
          }
      }
      elsif ($rdr->rx == 2) {
          for ($rdr->rvalue) {
              $root2 .= "  Xml: ".$$_."\n";
          }
      }
      elsif ($rdr->rx == 3) {
          for ($rdr->rvalue) {
              $root3 .= "  P: ".$$_."\n";
          }
      }
  }

  print "root0:\n$root0\n";
  print "stem0:\n$stem0\n";
  print "root1:\n$root1\n";
  print "root2:\n$root2\n";
  print "root3:\n$root3\n";

This is the output:

  root0:
    Cust: Name = o'rob   Street = pod alley    City = no city
    Cust: Name = "sue"   Street = baker street City = sidney
    Cust: Name = <smith> Street = high street  City = boston
    Cust: Name = &jones  Street = maple street City = new york
    Cust: Name = stewart Street = ring road    City = "'&<A>'"

  stem0:
    /data/customer
    /data/zzz/customer
    /data/order/database/customer
    /data/order/database/customer
    /data/order/database/customer

  root1:
    Supp: Name = ggg
    Supp: Name = hhh
    Supp: Name = iii
    Supp: Name = jjj

  root2:
    Xml: <customer id='444' name='o&apos;rob'><street>pod alley</street><city>no city</city></customer>
    Xml: <customer id='111' name='"sue"'><street>baker street</street><city>sidney</city></customer>
    Xml: <customer id='652' name='&lt;smith&gt;'><street>high street</street><city>boston</city></customer>
    Xml: <customer id='184' name='&amp;jones'><street>maple street</street><city>new york</city></customer>
    Xml: <customer id='520' name='stewart'><street>ring road</street><city>"'&amp;&lt;A&gt;'"</city></customer>

  root3:
    P: <p><p>b1</p><p>b2</p></p>
    P: <p>b3</p>

We can also use function rdr->rval to obtain the same data:

  my $rdr = XML::Reader->newhd(\$line2, {filter => 5},
    { root => 'customer',       branch => ['/@name', '/street', '/city'] },
    { root => 'p',              branch => '*' },
  );

  my $out0 = '';
  my $out1 = '';

  while ($rdr->iterate) {
      if ($rdr->rx == 0) {
          my @rv = $rdr->rval;
          $out0 .= sprintf "  Cust: Name = %-7s Street = %-12s City = %s\n", $rv[0], $rv[1], $rv[2];
      }
      elsif ($rdr->rx == 1) {
          $out1 .= "  P: ".$rdr->rval."\n";
      }
  }

  print "output0:\n$out0\n";
  print "output1:\n$out1\n";

This is the output:

  output0:
    Cust: Name = o'rob   Street = pod alley    City = no city
    Cust: Name = "sue"   Street = baker street City = sidney
    Cust: Name = <smith> Street = high street  City = boston
    Cust: Name = &jones  Street = maple street City = new york
    Cust: Name = stewart Street = ring road    City = "'&<A>'"

  output1:
    P: <p><p>b1</p><p>b2</p></p>
    P: <p>b3</p>

It is important to notice here that the case "root3" / "output1" { root => 'p', branch => '*' } clearly shows that always the
biggest possible XML subtree is matched for relative roots. In other words, the output of "P: <p>b1</p>" and "P:
<p>b2</p>" on its own line is not possible, because they are already part of the bigger line
"P: <p><p>b1</p><p>b2</p></p>".

=head1 EXAMPLES

Let's look at the following piece of XML from which we want to extract the values in <item>
(by that I mean only the first 'start...'-value, not the 'end...'-value), plus the attributes "p1"
and "p3". The item-tag must be exactly in the /start/param/data range (and *not* in the
/start/param/dataz range).

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

We expect exactly 4 output-lines from our parse (i.e. we don't expect the 'dataz' part -
'start9' - in the output):

  item = 'start1', p1 = 'a', p3 = 'c'
  item = 'start2', p1 = 'd', p3 = 'f'
  item = 'start3', p1 = 'g', p3 = 'i'
  item = 'start4', p1 = 'm', p3 = 'o'

=head2 Parsing XML with {filter => 2}

Here is a sample program to parse that XML with {filter => 2}. (Note how the prefix
'/start/param/data/item' is located in the {using =>} option of newhd). We need two
scalars ('$p1' and '$p3') to hold the parameters in '/@p1' and in '/@p3' and carry
them over to the $rdr->is_start section, where they can be printed.

  my $rdr = XML::Reader->newhd(\$text,
    {filter => 2, using => '/start/param/data/item'}) or die "Error: $!";

  my ($p1, $p3);

  while ($rdr->iterate) {
      if    ($rdr->path eq '/@p1') { $p1 = $rdr->value; }
      elsif ($rdr->path eq '/@p3') { $p3 = $rdr->value; }
      elsif ($rdr->path eq '/' and $rdr->is_start) {
          printf "item = '%s', p1 = '%s', p3 = '%s'\n",
            $rdr->value, $p1, $p3;
      }
      unless ($rdr->is_attr) { $p1 = undef; $p3 = undef; }
  }

=head2 Parsing XML with {filter => 3}

With {filter => 3} we can dispense with the two scalars '$p1' and '$p3', the code
becomes very simple:

  my $rdr = XML::Reader->newhd(\$text,
    {filter => 3, using => '/start/param/data/item'}) or die "Error: $!";

  while ($rdr->iterate) {
      if ($rdr->path eq '/' and $rdr->is_start) {
          printf "item = '%s', p1 = '%s', p3 = '%s'\n",
            $rdr->value, $rdr->att_hash->{p1}, $rdr->att_hash->{p3};
      }
  }

=head2 Parsing XML with {filter => 4}

With {filter => 4}, however, the code becomes slightly more complicated again: As already
shown for {filter => 2}, we need again two scalars ('$p1' and '$p3') to hold the parameters in
'/@p1' and in '/@p3' and carry them over. In addition to that, we also need a way to count
text-values (see scalar '$count'), so that we can distinguish between the first value 'start...'
(that we want to print) and the second value 'end...' (that we do not want to print).

  my $rdr = XML::Reader->newhd(\$text,
    {filter => 4, using => '/start/param/data/item'}) or die "Error: $!";

  my ($count, $p1, $p3);

  while ($rdr->iterate) {
      if    ($rdr->path eq '/@p1') { $p1 = $rdr->value; }
      elsif ($rdr->path eq '/@p3') { $p3 = $rdr->value; }
      elsif ($rdr->path eq '/') {
          if    ($rdr->is_start) { $count = 0; $p1 = undef; $p3 = undef; }
          elsif ($rdr->is_text) {
              $count++;
              if ($count == 1) {
                  printf "item = '%s', p1 = '%s', p3 = '%s'\n",
                    $rdr->value, $p1, $p3;
              }
          }
      }
  }

=head2 Parsing XML with {filter => 5}

You could combine {filter => 5} and regular expressions to parse the XML:

  my $rdr = XML::Reader->newhd(\$text, {filter => 5},
    { root => '/start/param/data/item', branch => '*' },
  ) or die "Error: $!";

  while ($rdr->iterate) {
      if ($rdr->rval =~ m{\A <item
          (?:\s+ p1='([^']*)')?
          (?:\s+ p2='([^']*)')?
          (?:\s+ p3='([^']*)')?
          \s* > ([^<]*) <}xms) {
          printf "item = '%s', p1 = '%s', p3 = '%s'\n", $4, $1, $3;
      }
  }

=head1 FUNCTIONS

=head2 Function slurp_xml

The function slurp_xml reads an XML file and slurps it into an array-ref. Here is an
example where we want to slurp the name, the street and the city of all customers in
the path '/data/order/database/customer' and we also want to slurp the supplier in
'/data/supplier':

  use XML::Reader qw(slurp_xml);

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
    { root => '/data/supplier',                branch => '*'                            },
  );

  for (@{$aref->[0]}) {
      printf "Cust: Name = %-7s Street = %-12s City = %s\n", $_->[0], $_->[1], $_->[2];
  }

  print "\n";

  for (@{$aref->[1]}) {
      printf "S: %s\n", $$_;
  }

The first parameter to slurp_xml is the filename (or scalar reference, or open filehandle) of the XML
that will be slurped. In this case we read from a scalar ref \$line2. The next parameter is a hash-ref
with the root of the sub-tree that we want to slurp (in our case that's '/data/order/database/customer')
and the branches, a list of the elements that we want to slurp, relative to the sub-tree. In this
case it is ['/@name', '/street', '/city']. The next parameter is our second root/branch definition, in
this case it is root => '/data/supplier' with branch => ['/'].

Here is the output:

  Cust: Name = smith   Street = high street  City = boston
  Cust: Name = jones   Street = maple street City = new york
  Cust: Name = stewart Street = ring road    City = dallas

  S: <supplier>ggg</supplier>
  S: <supplier>hhh</supplier>
  S: <supplier>iii</supplier>
  S: <supplier>jjj</supplier>

slurp_xml works similar to L<XML::Simple>, in that it reads all required information in one go into
an in-memory data structure. The difference, however, is that slurp_xml lets you be specific in what
you actually want before you do the slurping, so that in most cases your in-memory data structure is
smaller and less complicated.

=head1 AUTHOR

Klaus Eichner, March 2009

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Klaus Eichner

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms of the artistic license,
see http://www.opensource.org/licenses/artistic-license-1.0.php

=head1 RELATED MODULES

If you also want to write XML, have a look at XML::Writer. This module provides a simple interface for
writing XML. (If you are writing non-mixed content XML, consider setting DATA_MODE=>1 and
DATA_INDENT=>2, which allows for proper indentation in your XML-Output file)

=head1 SEE ALSO

L<XML::TokeParser>,
L<XML::Simple>,
L<XML::Parser>,
L<XML::Parser::Expat>,
L<XML::TiePYX>,
L<XML::Writer>.

=cut
