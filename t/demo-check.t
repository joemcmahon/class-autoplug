use strict;
use warnings;

use Test::More tests => 1;
use Test::Differences;

my $expected = <<EOS;
RUNNING!!!!!
About to get ...
After get...
Got yadda in get
About to get ...
After get...
Asked to skip
About to get ...
After get...
This was changed
EOS

my $got = `perl -Iblib/lib -Iexample example/demo.pl`;
eq_or_diff $got, $expected;
