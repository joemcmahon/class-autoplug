package Vacuum::Plugin::Screamer;
use base qw(Class::AutoPlug::Plugin);
use Class::AutoPlug::ResultState;

# new method in Vacuum::Pluggable
sub foo :PluggedMethod(foo) {
  print "RUNNING!!!!!\n";
}

# Add prehook to get(), with "skip call" and "change params" behavior
sub starting :Prehook(get) {
  my ($self, $result) = @_;

  print "About to get ...\n";

  if ($result->at_under()->[0] eq "skip me") {
	$result->skip_method_call(1);
	$result->result(["Asked to skip\n"]);
  }
  return $result;
}

# add posthook, with "change result" behavior
sub stopping :Posthook(get) {
	my ($self, $result) = @_;
  
  print "After get...\n";
  if ($result->at_under()->[0] =~ /alter me/) {
    $result->result( ["This was changed\n"] );	
  }
  return $result;
}

"Vacuum::Plugin::Screamer defined";
