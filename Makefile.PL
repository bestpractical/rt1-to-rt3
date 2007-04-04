use inc::Module::Install;

name ('RTx-Converter');
abstract('Convert RT1 installations to RT3');
all_from('lib/RTx/Converter.pm');
requires('Test::More');
requires('Class::Accessor::Fast');
requires('RT' => '3.6');

&WriteAll;
