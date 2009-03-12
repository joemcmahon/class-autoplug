use Test::More tests=>23;
use Class::AutoPlug::ResultState;
use Test::Exception;
use strict;
use warnings;

dies_ok { my $obj = Class::AutoPlug::ResultState->new() } 'die with no context';
dies_ok { my $obj = Class::AutoPlug::ResultState->new(context => 'scalar') } 'arg not hashref';

my $obj = Class::AutoPlug::ResultState->new( { context => 'scalar'} );
is $obj->at_under(), undef, 'no replacement @_ by default';
is $obj->result(), undef, 'no replacement result by default';
ok !$obj->skip_method_call(), 'not skipping by default';
is $obj->context, 'scalar', 'expected context';

lives_ok { $obj->at_under([qw(this is a test)]) } 
	'setting at_under to array ref works';
ok $obj->at_under(), 'there is an @_ replacement now';
ok !$obj->skip_method_call(), 'but still call the method';
is_deeply $obj->at_under, [qw(this is a test)], 'right value for @_';

dies_ok { $obj->at_under(qw(just a list)) } 'not a ref';
dies_ok { $obj->result(qw(also just a list))} 'not a ref either';

$obj = Class::AutoPlug::ResultState->new( {context => 'list'} );
lives_ok { $obj->skip_method_call(1) } 'setting skip_method_call works';
ok $obj->skip_method_call(), 'successfully set';
ok !$obj->result(), 'no replacement result';
ok !$obj->at_under(), 'no replacement @_';

$obj = Class::AutoPlug::ResultState->new( {context => 'scalar'} );
lives_ok { $obj->result( [ qw(more data) ] ) } 'setting replacement result works';
ok !$obj->skip_method_call(), 'not skipping method call';
ok !$obj->at_under(), 'not replacing @_';

lives_ok {
	$obj = Class::AutoPlug::ResultState->new(
			{
				skip_method_call => 1,
				at_under => [qw(replaced)],
				result => [qw(different)],
				context => 'list',
			}
		);
} 'new() with parameters works';
ok $obj->skip_method_call, 'skip_method_call right';
is_deeply $obj->at_under, [qw(replaced)], '@_ replacement right';
is_deeply $obj->result, [qw(different)], 'result right';
