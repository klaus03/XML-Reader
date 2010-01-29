use strict;
use warnings;
use 5.010;

use Module::Build;

Module::Build->new(
  module_name   => 'XML::Reader',
  license       => 'perl',
  requires      => { 'XML::Parser' => 1.00, 'Carp' => 0 },
  dist_abstract => 'Reading XML and providing path information based on a pull-parser',
)->create_build_script;
