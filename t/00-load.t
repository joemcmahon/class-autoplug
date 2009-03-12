#!perl -T
use strict;
use warnings;

use Test::More tests => 3;

BEGIN {
	use_ok( 'Class::AutoPlug::Pluggable' );
	use_ok( 'Class::AutoPlug::Plugin');
	use_ok( 'Class::AutoPlug::ResultState');
}

diag( "Testing Class::AutoPlug::Pluggable $Class::AutoPlug::Pluggable::VERSION" );
diag( "Testing Class::AutoPlug::Plugin $Class::AutoPlug::Plugin::VERSION" );
diag( "Testing Class::AutoPlug::ResultState $Class::AutoPlug::ResultState::VERSION" );
diag( " Perl $], $^X" );
