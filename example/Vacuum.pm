package Vacuum;

sub new {
  bless {}, shift;
}

sub get {
  my ($self, $args) = @_;
  return "Got $args in get\n";
}

"Vacuum defined";

