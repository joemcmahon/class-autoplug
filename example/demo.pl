use Data::Dumper;
$|++;
use Vacuum::Pluggable;

my $obj = new Vacuum::Pluggable;

$obj->foo();

print $obj->get('yadda');
print $obj->get('skip me');
print $obj->get('alter me');
exit 0;


