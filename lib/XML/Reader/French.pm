package XML::Reader::French;

print "\n";
print "This document is the French translation from English of the module XML::Reader.\n";
print "In order to get the Perl source code of the module, please see file XML/Reader.pm\n";
print "\n";
print "Ce document est une traduction Francaise de l'Anglais du module XML::Reader.\n";
print "Pour obtenir la source Perl du module, consultez le fichier XML/Reader.pm\n";
print "\n";

=pod

=head1 NAME

XML::Reader - Lire du XML avec des informations du chemin, conduit par un parseur d'extraction.

=head1 TRADUCTION

This document is the French translation from English of the module XML::Reader. In order to
get the Perl source code of the module, please see file XML/Reader.pm

Ce document est une traduction FranE<ccedil>aise de l'Anglais du module XML::Reader. Pour
obtenir la source Perl du module, consultez le fichier XML/Reader.pm

=head1 SYNOPSIS

  use XML::Reader;

  my $text = q{<init>n <?test pi?> t<page node="400">m <!-- remark --> r</page></init>};

  my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";
  while ($rdr->iterate) {
      printf "Path: %-19s, Value: %s\n", $rdr->path, $rdr->value;
  }

Ce programme crE<eacute>e le rE<eacute>sultat suivant:

  Path: /init              , Value: n t
  Path: /init/page/@node   , Value: 400
  Path: /init/page         , Value: m r
  Path: /init              , Value:

=head1 DESCRIPTION

XML::Reader est un module simple et facile E<agrave> utiliser pour parser des fichiers XML de maniE<egrave>re sE<eacute>quentielle
(aussi appellE<eacute> parseur guidE<eacute> par l'extraction) et, en mE<ecirc>me temps, il enregistre le chemin complet du XML.

Il a E<eacute>tE<eacute> dE<eacute>veloppE<eacute> comme une couche sur XML::Parser (quelques fonctionalitE<eacute>s basiques ont E<eacute>tE<eacute> copiE<eacute> de
XML::TokeParser). XML::Parser et XML::TokeParser utilisent chacun une mE<eacute>thode d'extraction sE<eacute>quentielle,
mais ils n'enregistrent pas le chemin du XML.

De plus, avec les interfaces de XML::Parser et XML::TokeParser, on est obligE<eacute> de sE<eacute>parer les balises de dE<eacute>but,
les balises de fin et du texte, ce qui, E<agrave> mon avis, rend l'utilisation assez compliquE<eacute>. (par contre, si on le
souhaite, XML::Reader peut agir d'une maniE<egrave>re E<agrave> ce que les balises de dE<eacute>but, les balises de fin et du texte
sont sE<eacute>parE<eacute>s, par l'option {filter => 4}).

Il y a aussi XML::TiePYX, qui permet de parser des fichiers XML de maniE<egrave>re sE<eacute>quentielle (voir
L<http://www.xml.com/pub/a/2000/03/15/feature/index.html> pour consulter une introduction E<agrave> PYX).
Mais mE<ecirc>me avec XML::TiePYX, il faut sE<eacute>parer les balises de dE<eacute>but, les balises de fin et le texte, et il n'y a
pas de chemin disponible.

Par contre, avec XML::Reader, les les balises de dE<eacute>but, les balises de fin et le texte sont traduits en
expressions similaires E<agrave> XPath. En consE<eacute>quence, il est inutile de compter des balises individuelles, on a
un chemin et une valeur, et E<ccedil>a suffit. (par contre, au cas oE<ugrave> on veut opE<eacute>rer XML::Reader en fonctionnement
compatible E<agrave> PYX, il y a toujours option {filter => 4}, comme dE<eacute>jE<agrave> mentionnE<eacute> ci-dessus).

Mais revenons-nous au fonctionnement normal de XML::Reader, voici un exemple XML dans la variable '$line1':

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

Cet exemple peut E<ecirc>tre parsE<eacute> avec XML::Reader en utilisant les mE<eacute>thodes C<iterate> pour lire sE<eacute>quentiellement
les donnE<eacute>es XML, et en utilisant les mE<eacute>thodes C<path> et C<value> pour extraire le chemin et la valeur E<agrave> un
endroit prE<eacute>cis dans le fichier XML.

Si nE<eacute>cessaire, on peut E<eacute>galement identifier les balises individuelles de dE<eacute>but et de fin: Il y a une mE<eacute>thode
C<is_start>, qui donne 1 ou 0 (c'est E<agrave> dire: 1, s'il y a une balise de dE<eacute>but E<agrave> la position actuelle, sinon 0).
Il y a E<eacute>galement la mE<eacute>thode E<eacute>quivalente C<is_end>.

En plus, il y a les mE<eacute>thodes C<tag>, C<attr>, C<type> and C<level>. C<tag> retourne le nom de la balise
en cours, C<attr> retourne l'identifiant d'un attribut, C<type> retourne 'T' s'il y a du texte, ou '@' s'il y
a des attributs et C<level> indique le niveau de cascadage (un nombre >= 0)

Voici un programme qui lit le XML dans la variable '$line1' (voir ci-dessus) pour montrer le principe...

  use XML::Reader;

  my $rdr = XML::Reader->newhd(\$line1) or die "Error: $!";
  my $i = 0;
  while ($rdr->iterate) { $i++;
      printf "%3d. pat=%-22s, val=%-9s, s=%-1s, e=%-1s, tag=%-6s, atr=%-6s, t=%-1s, lvl=%2d\n", $i,
        $rdr->path, $rdr->value, $rdr->is_start, $rdr->is_end, $rdr->tag, $rdr->attr, $rdr->type, $rdr->level;
  }

...et voici le rE<eacute>sultat:

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

=head2 CrE<eacute>ation d'un objet

Pour crE<eacute>er un objet, on utilise la syntaxe suivante:

  my $rdr = XML::Reader->newhd($data,
    {strip => 1, filter => 2, using => ['/path1', '/path2']})
    or die "Error: $!";

L'E<eacute>lE<eacute>ment $data est obligatoire, il est le nom d'un fichier XML, ou la rE<eacute>fE<eacute>rence E<agrave> une chaE<icirc>ne de
caractE<egrave>res, dans ce cas le contenu de cette chaE<icirc>ne de caractE<egrave>res est acceptE<eacute> comme XML.

Sinon, $data peut E<eacute>galement E<ecirc>tre une rE<eacute>fE<eacute>rence E<agrave> un fichier, comme par exemple \*STDIN. Dans ce cas,
la rE<eacute>fE<eacute>rence de fichier est utiliser pour lire le XML.

Voici un exemple pour crE<eacute>er un objet XML::Reader avec un fichier:

  my $rdr = XML::Reader->newhd('input.xml') or die "Error: $!";

Voici un autre exemple pour crE<eacute>er un objet XML::Reader avec une rE<eacute>fE<eacute>rence E<agrave> une chaE<icirc>ne de caractE<egrave>res:

  my $rdr = XML::Reader->newhd(\'<data>abc</data>') or die "Error: $!";

Voici un exemple pour crE<eacute>er un objet XML::Reader avec une rE<eacute>fE<eacute>rence E<agrave> un fichier:

  open my $fh, '<', 'input.xml' or die "Error: $!";
  my $rdr = XML::Reader->newhd($fh);

Voici un exemple pour crE<eacute>er un objet XML::Reader avec \*STDIN:

  my $rdr = XML::Reader->newhd(\*STDIN);

On peut ajouter un ou plusieurs options dans une rE<eacute>fE<eacute>rence E<agrave> un hashage:

=over

=item option {parse_ct => }

Option {parse_ct => 1} permet de lire les commentaires, le defaut est {parse_ct => 0}

=item option {parse_pi => }

Option {parse_pi => 1} permet de lire les processing-instructions et les XML-declarations,
le dE<eacute>faut est {parse_pi => 0}

=item option {using => }

Option {using => } permet de sE<eacute>lectionner un arbre prE<eacute>cis dans le XML.

La syntaxe est {using => ['/path1/path2/path3', '/path4/path5/path6']}

=item option {filter => }

Option {filter => 2} affiche tous les E<eacute>lE<eacute>ments, y compris les attributs.

Option {filter => 3} supprime les attributs (c'est E<agrave> dire il supprime toutes les lignes qui
sont $rdr->type eq '@'). En revanche, le contenu des attributs sont retournE<eacute> dans le hashage
$rdr->att_hash.

Option {filter => 4} crE<eacute>e une ligne individuel pour chaque balise de dE<eacute>but, de fin, pour chaque
attribut, pour chaque commentaire et pour chaque processing-instruction. Ce fonctionnement
permet, en effet, de gE<eacute>nE<eacute>rer un format PYX.

La syntaxe est {filter => 2|3|4}, le dE<eacute>faut est {filter => 2}

=item option {strip => }

Option {strip => 1} supprime les caractE<egrave>res blancs au dE<eacute>but et E<agrave> la fin d'un texte ou d'un commentaire.
(les caractE<egrave>res blancs d'un attribut ne sont jamais supprimE<eacute>). L'option {strip => 0} laisse le texte ou
commentaire intacte.

La syntaxe est {strip => 0|1}, le dE<eacute>faut est {strip => 1}

=back

=head2 ME<eacute>thodes

Un objet du type XML::Reader a des mE<eacute>thodes suivantes:

=over

=item iterate

La mE<eacute>thode C<iterate> lit un E<eacute>lE<eacute>ment XML. Elle retourne 1, si la lecture a E<eacute>tE<eacute> un succE<egrave>s, ou undef E<agrave> la fin
du fichier XML.

=item path

La mE<eacute>thode C<path> retourne le chemin complet de la ligne en cours, les attributs sont rE<eacute>prE<eacute>sentE<eacute>s avec des
caractE<egrave>res '@'.

=item value

La mE<eacute>thode C<value> retourne la valeur de la ligne en cours (c'est E<agrave> dire le texte ou l'attribut).

Conseil: en cas de {filter => 2 ou 3} avec une dE<eacute>claration-XML (c'est E<agrave> dire $rdr->is_decl == 1),
il vaut mieux ne pas prendre compte de la valeur (elle sera vide, de toute faE<ccedil>on). Un bout de programme:

  print $rdr->value, "\n" unless $rdr->is_decl;

Le programme ci-dessus ne s'applique *pas* E<agrave> {filter => 4}, dans ce cas un simple "print $rdr->value;"
est suffisant:

  print $rdr->value, "\n";

=item comment

La mE<eacute>thode C<comment> retourne le commentaire d'un fichier XML. Il est conseillE<eacute> de tester $rdr->is_comment
avant d'accE<eacute>der E<agrave> la mE<eacute>thode C<comment>.

=item type

La mE<eacute>thode C<type> retourne 'T' quand il y a du texte dans le XML, et '@' quand il y a un attribut.

Si l'option {filter => 4} est active, les possibilitE<eacute>s sont: 'T' pour du texte, '@' poir un attribut,
'S' pour une balise de dE<eacute>but, 'E' pour une balise de fin, '#' pour un commentaire, 'D' pour une
dE<eacute>claration-XML, '?' pour une processing-instruction.

=item tag

La mE<eacute>thode C<tag> retourne le nom de la balise en cours.

=item attr

La mE<eacute>thode C<attr> retourne le nom de l'attribut en cours (elle retourne une chaE<icirc>ne de caractE<egrave>res
vide si l'E<eacute>lE<eacute>ment en cours n'est pas un attribut)

=item level

La mE<eacute>thode C<level> retourne le niveau de cascadage (un nombre > 0)

=item prefix

La mE<eacute>thode C<prefix> retourne le prE<eacute>fixe du chemin (c'est la partie du chemin qui a E<eacute>tE<eacute> supprimE<eacute> dans
l'option {using => ...}). Elle retourne une chaE<icirc>ne de caractE<egrave>res vide au cas oE<ugrave> l'option {using => ...}
n'a pas E<eacute>tE<eacute> specifiE<eacute>e.

=item att_hash

La mE<eacute>thode C<att_hash> retourne une rE<eacute>fE<eacute>rence E<agrave> l'hachage des attributs de la balise de dE<eacute>but en cours
(au cas oE<ugrave> l'E<eacute>lE<eacute>ment en cours n'est pas une balise de dE<eacute>but, un hachage vide est retournE<eacute>)

=item dec_hash

La mE<eacute>thode C<dec_hash> retourne une rE<eacute>fE<eacute>rence E<agrave> l'hachage des attributs de la XML-declaration en cours
(au cas oE<ugrave> l'E<eacute>lE<eacute>ment en cours n'est pas une XML-declaration, un hachage vide est retournE<eacute>)

=item proc_tgt

La mE<eacute>thode C<proc_tgt> retourne la partie cible (c'est E<agrave> dire la premiE<egrave>re partie) de la processing-instruction
(au cas oE<ugrave> l'E<eacute>lE<eacute>ment en cours n'est pas une processing-instruction, une chaE<icirc>ne de caractE<egrave>res vide est retournE<eacute>)

=item proc_data

La mE<eacute>thode C<proc_data> retourne la partie donnE<eacute>e (c'est E<agrave> dire la deuxiE<egrave>me partie) de la processing-instruction
(au cas oE<ugrave> l'E<eacute>lE<eacute>ment en cours n'est pas une processing-instruction, une chaE<icirc>ne de caractE<egrave>res vide est retournE<eacute>)

=item pyx

La mE<eacute>thode C<pyx> retourne la chaE<icirc>ne de caractE<egrave>res format "PYX" de l'E<eacute>lE<eacute>ment XML en cours.

La chaE<icirc>ne de caractE<egrave>res format "PYX" est une chaE<icirc>ne de caractE<egrave>res avec un premier caractE<egrave>re spE<eacute>cifique. Ce
premier caractE<egrave>re de chaque ligne "PYX" dE<eacute>termine le type: si le premier caractE<egrave>re est un '(', alors E<ccedil>a signifie
une balise de dE<eacute>but. Si le premier caractE<egrave>re est un ')', alors E<ccedil>a signifie une balise de fin. Si le premier
caractE<egrave>re est un 'A', alors E<ccedil>a signifie un attribut. Si le premier caractE<egrave>re est un '-', alors E<ccedil>a signifie un
texte. Si le premier caractE<egrave>re est un '?', alors E<ccedil>a signifie une processing-instruction. (voir
L<http://www.xml.com/pub/a/2000/03/15/feature/index.html> pour une introduction E<agrave> PYX)

La mE<eacute>thode C<pyx> n'est utile que pour l'option {filter => 4}, sinon, pour un {filter => } diffE<eacute>rent de 4, on
retourne undef.

=item is_start

La mE<eacute>thode C<is_start> retourne 1, si l'E<eacute>lE<eacute>ment en cours est une balise de dE<eacute>but, sinon 0 est retournE<eacute>.

=item is_end

La mE<eacute>thode C<is_end> retourne 1, si l'E<eacute>lE<eacute>ment en cours est une balise de fin, sinon 0 est retournE<eacute>.

=item is_decl

La mE<eacute>thode C<is_decl> retourne 1, si l'E<eacute>lE<eacute>ment en cours est une XML-declaration, sinon 0 est retournE<eacute>.

=item is_proc

La mE<eacute>thode C<is_proc> retourne 1, si l'E<eacute>lE<eacute>ment en cours est une processing-instruction, sinon 0 est retournE<eacute>.

=item is_comment

La mE<eacute>thode C<is_comment> retourne 1, si l'E<eacute>lE<eacute>ment en cours est un commentaire, sinon 0 est retournE<eacute>.

=item is_text

La mE<eacute>thode C<is_text> retourne 1, si l'E<eacute>lE<eacute>ment en cours est un texte, sinon 0 est retournE<eacute>.

=item is_attr

La mE<eacute>thode C<is_attr> retourne 1, si l'E<eacute>lE<eacute>ment en cours est un attribut, sinon 0 est retournE<eacute>.

=item is_value

La mE<eacute>thode C<is_attr> retourne 1, si l'E<eacute>lE<eacute>ment en cours est un texte ou un attribut, sinon 0 est retournE<eacute>. Cette
mE<eacute>thode est plutE<ocirc>t utile pour l'option {filter => 4}, oE<ugrave> on peut tester l'utilitE<eacute> de la mE<eacute>thode C<value>.

=back

=head1 OPTION USING

L'option {using => ...} permet de sE<eacute>lectionner un sous-arbre du XML.

Voici comment E<ccedil>a fonctionne en dE<eacute>tail...

L'option {using => ['/chemin1/chemin2/chemin3', '/chemin4/chemin5/chemin6']} d'abord elimine toutes les lignes
oE<ugrave> le chemin ne commence pas avec '/chemin1/chemin2/chemin3' ou '/chemin4/chemin5/chemin6'.

Les lignes restantes (ceux qui n'ont pas E<eacute>tE<eacute> eliminE<eacute>) ont un chemin plus court. En fait le prE<eacute>fixe
'/chemin1/chemin2/chemin3' (ou '/chemin4/chemin5/chemin6') a E<eacute>tE<eacute> supprimE<eacute>. En revanche, ce prE<eacute>fixe supprimE<eacute>
apparaE<icirc>t dans la mE<eacute>thode C<prefix>.

On dit que '/chemin1/chemin2/chemin3' (ou '/chemin4/chemin5/chemin6') sont "absolu" et "complE<egrave>t". Le mot "absolu"
signifie que chaque chemin commence forcement par un caractE<egrave>re '/', et le mot "complE<egrave>t" signifie que
la derniE<egrave>re partie 'chemin3' (ou 'chemin6') sera suivi implicitement par un caractE<egrave>re '/'.

=head2 Un exemple avec option 'using'

Le programme suivant prend un fichier XML et le parse avec XML::Reader, y compris l'option 'using' pour
cibler des E<eacute>lE<eacute>ments spE<eacute>cifiques:

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

Voici le rE<eacute>sultat de ce programme:

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

=head2 Un example sans option 'using'

Le programme suivant prend un fichier XML et le parse avec XML::Reader, mais sans option 'using':

  use XML::Reader;

  my $rdr = XML::Reader->newhd(\$line2);
  my $i = 0;
  while ($rdr->iterate) { $i++;
      printf "%3d. prf=%-1s, pat=%-37s, val=%-6s, tag=%-11s, t=%-1s, lvl=%2d\n",
       $i, $rdr->prefix, $rdr->path, $rdr->value, $rdr->tag, $rdr->type, $rdr->level;
  }

Comme on peut constater dans le rE<eacute>sultat suivant, il y a beaucoup plus de lignes, le prE<eacute>fixe est vide et
le chemin est beaucoup plus longue par rapport au programme prE<eacute>cE<eacute>dent:

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

L'option {parse_ct => 1} permet de parser les commentaires (normalement, les commentaires ne sont
pas pris en compte par XML::Reader, le dE<eacute>faut est {parse_ct => 0}.

Voici un exemple oE<ugrave> les commentaires ne sont pas pris en compte par dE<eacute>faut:

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

Voici le rE<eacute>sultat:

  Text 'xyz stu test'

Ensuite, les mE<ecirc>mes donnE<eacute>es XML et le mE<ecirc>me algorithme, sauf l'option {parse_ct => 1}, qui est maintenant active:

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

Voici le rE<eacute>sultat:

  Text 'xyz'
  Found comment   remark
  Text 'stu test'

=head1 OPTION PARSE_PI

L'option {parse_pi => 1} permet de parser les processing-instructions et les XML-Declarations (normalement,
ni les processing-instructions, ni les XML-Declarations ne sont pris en compte par XML::Reader, le dE<eacute>faut
est {parse_pi => 0}.

Comme exemple, on prend exactement les mE<ecirc>mes donnE<eacute>es XML et le mE<ecirc>me algorithme du paragraphe prE<eacute>cE<eacute>dent, sauf
l'option {parse_pi => 1}, qui est maintenant active (avec l'option {parse_ct => 1}):

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

Notez le "unless $rdr->is_decl" dans le programme ci-dessus. C'est pour E<eacute>viter le texte vide aprE<egrave>s la XML-dE<eacute>claration.

Voici le rE<eacute>sultat:

  Found decl      version='1.0'
  Text 'xyz'
  Found comment   remark
  Text 'stu'
  Found proc      t=ab, d=cde
  Text 'test'

=head1 OPTION FILTER

L'option {filter => } permet de sE<eacute>lectionner des diffE<eacute>rents modes d'opE<eacute>ratoires pour le traitement du XML.

=head2 Option {filter => 2}

Avec option {filter => 2}, XML::Reader gE<eacute>nE<egrave>re une ligne pour chaque morceau de texte. Si la balise prE<eacute>cE<eacute>dente
est une balise de dE<eacute>but, alors la mE<eacute>tode C<is_start> retourne 1. Si la balise suivante est une balise de fin,
alors la mE<eacute>tode C<is_end> retourne 1. Si la balise prE<eacute>cE<eacute>dente est une balise de commentaire, alors la mE<eacute>thode
C<is_comment> retourne 1. Si la balise prE<eacute>cE<eacute>dente est une balise de XML-declaration, alors la mE<eacute>thode C<is_decl>
retourne 1. Si la balise prE<eacute>cE<eacute>dente est une balise de processing-instruction, alors la
mE<eacute>thode C<is_decl> retourne 1.

De plus, les attributs sont reprE<eacute>sentE<eacute>s par des lignes supplE<eacute>mentaires avec la syntaxe '/@...'.

Option {filter => 2} est le dE<eacute>faut.

Voici un exemple...

  use XML::Reader;

  my $text = q{<root><test param="v"><a><b>e<data id="z">g</data>f</b></a></test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";
  while ($rdr->iterate) {
      printf "Path: %-24s, Value: %s\n", $rdr->path, $rdr->value;
  }

Le programme (avec l'option {filter => 2} implicitement par dE<eacute>faut) gE<eacute>nE<egrave>re le rE<eacute>sultat suivant:

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


L'option (implicite) {filter => 2} permet E<eacute>galement de reconstruire la structure du XML avec l'assistance
des mE<eacute>thodes C<is_start> and C<is_end>. Notez que dans le rE<eacute>sultat ci-dessus, la premiE<egrave>re ligne
("Path: /root, Value:") est vide, mais elle est importante pour la structure du XML.

Prenons-nous le mE<ecirc>me exemple {filter => 2} avec un algorithme pour reconstruire la structure originale
du XML:

  use XML::Reader;

  my $text = q{<root><test param="v"><a><b>e<data id="z">g</data>f</b></a></test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->newhd(\$text) or die "Error: $!";

  my %at;

  while ($rdr->iterate) {
      my $indentation = '  ' x ($rdr->level - 1);

      if ($rdr->type eq '@')  { $at{$rdr->attr} = $rdr->value; }

      if ($rdr->is_start) {
          print $indentation, '<', $rdr->tag, join('', map{" $_='$at{$_}'"} sort keys %at), '>', "\n";
      }

      unless ($rdr->type eq '@') { %at = (); }

      if ($rdr->type eq 'T' and $rdr->value ne '') {
          print $indentation, '  ', $rdr->value, "\n";
      }

      if ($rdr->is_end) {
          print $indentation, '</', $rdr->tag, '>', "\n";
      }
  }

...voici le rE<eacute>sultat:

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

...ce qui donne preuve que la structure originale du XML n'est pas perdu.

=head2 Option {filter => 3}

Pour la plupart, l'option {filter => 3} fonctionne comme l'option {filter => 2}.

Mais il y a une diffE<eacute>rence: avec l'option {filter => 3}, les attributs sont supprimE<eacute>es et E<agrave> la place,
les attributs sont prE<eacute>sentE<eacute>s dans un hashage "$rdr->att_hash()" pour chaque balise de dE<eacute>but.

Ainsi, dans l'algorithme prE<eacute>cE<eacute>dent, on peut supprimer la variable globale "%at" et la remplacer par
%{$rdr->att_hash}:

  use XML::Reader;

  my $text = q{<root><test param="v"><a><b>e<data id="z">g</data>f</b></a></test>x <!-- remark --> yz</root>};

  my $rdr = XML::Reader->newhd(\$text, {filter => 3}) or die "Error: $!";

  while ($rdr->iterate) {
      my $indentation = '  ' x ($rdr->level - 1);

      if ($rdr->is_start) {
          print $indentation, '<', $rdr->tag,
            join('', map{" $_='".$rdr->att_hash->{$_}."'"} sort keys %{$rdr->att_hash}),
            '>', "\n";
      }

      if ($rdr->type eq 'T' and $rdr->value ne '') {
          print $indentation, '  ', $rdr->value, "\n";
      }

      if ($rdr->is_end) {
          print $indentation, '</', $rdr->tag, '>', "\n";
      }
  }

...le rE<eacute>sultat de {filter => 3} est identique au rE<eacute>sultat de {filter => 2}:

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

=head2 Option {filter => 4}

ME<ecirc>me si ce n'est pas la raison principale de XML::Reader, l'option {filter => 4} permet de gE<eacute>nE<eacute>rer des
lignes individuelles pour chaque balise de dE<eacute>but, de fin, commentaires, processing-instruction et XML-Declaration.
Le but est de gE<eacute>nE<eacute>rer une chaE<icirc>ne de caractE<egrave>res du modE<egrave>le "PYX" pour l'analyse par la suite.

Voici un exemple:

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

et voici le rE<eacute>sultat:

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

Il faut dire que les commentaires, qui sont gE<eacute>nE<eacute>rE<eacute>s avec l'option {parse_ct => 1}, ne font pas partie du standard "PYX".
En fait, les commentaires sont gE<eacute>nE<eacute>rE<eacute>s avec un caractE<egrave>re '#' qui n'existe pas dans le standard. Voici un exemple:

  use XML::Reader;

  my $text = q{
    <delta>
      <!-- remark -->
    </delta>};

  my $rdr = XML::Reader->newhd(\$text, {filter => 4, parse_ct => 1}) or die "Error: $!";

  while ($rdr->iterate) {
      printf "Type = %1s, pyx = %s\n", $rdr->type, $rdr->pyx;
  }

Voici le rE<eacute>sultat:

  Type = S, pyx = (delta
  Type = #, pyx = #remark
  Type = E, pyx = )delta

Avec l'option {filter => 4}, les mE<eacute>thodes habituelles restent accessibles: C<value>, C<attr>, C<path>, C<is_start>,
C<is_end>, C<is_decl>, C<is_proc>, C<is_comment>, C<is_attr>, C<is_text>, C<is_value>, C<comment>, C<proc_tgt>,
C<proc_data>, C<dec_hash> or C<att_hash>. Voici un exemple:

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

Voici le rE<eacute>sultat:

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

Notez que "v=1" (c'est E<agrave> dire $rdr->is_value == 1) pour tous les textes et pour tous les attributs.

=head1 EXEMPLES

Examinons-nous le XML suivant, oE<ugrave> nous souhaitons extraire les valeurs dans la balise <item>
(c'est la premiE<egrave>re partie 'start...', et non pas la partie 'end...' qui nous intE<eacute>resse), ensuite
les attributs "p1" et "p3". La balise <item> doit E<ecirc>tre dans le chemin '/start/param/data (et
non pas dans le chemin /start/param/dataz).

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

Nous expectons exactement 4 lignes de sortie dans le rE<eacute>sultat (c'est E<agrave> dire la ligne 'dataz' / 'start9'
ne fait pas partie du rE<eacute>sultat):

  item = 'start1', p1 = 'a', p3 = 'c'
  item = 'start2', p1 = 'd', p3 = 'f'
  item = 'start3', p1 = 'g', p3 = 'i'
  item = 'start4', p1 = 'm', p3 = 'o'

=head2 Parser l'exemple XML avec l'option {filter => 2}

Ci-dessous un programme pour parser le XML avec l'option {filter => 2}. (Notez que le prE<eacute>fixe
'/start/param/data/item' est renseignE<eacute> dans l'option {using =>} de la fonction newhd). En plus,
nous avons besoins de 2 variables scalaires '$p1' et '$p3' pour enregistrer les paramE<egrave>tres '/@p1'
et '/@p3' et les transfE<eacute>rer dans la partie '$rdr->is_start' du programme, oE<ugrave> on peut les afficher.

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

=head2 Parser l'exemple XML avec l'option {filter => 3}

Avec l'option {filter => 3}, nous pouvons annuler les deux variables '$p1' et '$p3'. Le
programme devient assez simple:

  my $rdr = XML::Reader->newhd(\$text,
    {filter => 3, using => '/start/param/data/item'}) or die "Error: $!";

  while ($rdr->iterate) {
      if ($rdr->path eq '/' and $rdr->is_start) {
          printf "item = '%s', p1 = '%s', p3 = '%s'\n",
            $rdr->value, $rdr->att_hash->{p1}, $rdr->att_hash->{p3};
      }
  }

=head2 Parser l'exemple XML avec l'option {filter => 4}

Avec l'option {filter => 4}, par contre, le programme devient plus compliquE<eacute>: Comme dE<eacute>jE<agrave>
montrE<eacute> dans l'exemple {filter => 2}, nous avons besoin de deux variables scalaires ('$p1' et
'$p3') pour enregistrer les paramE<egrave>tres '/@p1' et '/@p3' et les transfE<eacute>rer E<agrave> l'endoit oE<ugrave> on peut
les afficher. En plus, nous avons besoin de compter les valeurs de texte (voir variable '$count'
ci-dessous), afin d'identifier la premiE<egrave>re partie du texte 'start...' (ce que nous voulons afficher)
et supprimer la deuxiE<egrave>me partie du texte 'end...' (ce que nous ne voulons pas afficher).

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

=head1 AUTEUR

Klaus Eichner, Mars 2009

=head1 COPYRIGHT ET LICENSE

Voici le texte original en Anglais:

Copyright (C) 2009 by Klaus Eichner.

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms of the artistic license,
see L<http://www.opensource.org/licenses/artistic-license-1.0.php>

=head1 MODULES ASSOCIES

Si vous souhaitez E<eacute>crire du XML, je propose d'utiliser une autre module "XML::Writer". Ce module
se prE<eacute>sente avec une interface simple pour E<eacute>crire un fichier XML. Si vous ne mE<eacute>langez pas le texte et les
balises (ce qu'on appelle en Anglais "non-mixed content XML"), je propose de mettre les options DATA_MODE=>1
et DATA_INDENT=>2, ainsi votre rE<eacute>sultat sera proprement formatE<eacute> selon les rE<egrave>gles XML.

=head1 REFERENCES

L<XML::TokeParser>,
L<XML::Parser>,
L<XML::Parser::Expat>,
L<XML::TiePYX>,
L<XML::Writer>.

=cut
