use strict;
use warnings;
use 5.008;

use Module::Build;

Module::Build->new(
  module_name        => 'XML::Reader',
  license            => 'perl',
  configure_requires => { 'Module::Build' => 0.30 },
  requires           => { 'XML::Parser' => 1.00, 'Carp' => 0, 'XML::Parsepp' => 0.04 },
  dist_abstract      => 'Reading XML and providing path information based on a pull-parser',
)->create_build_script;
