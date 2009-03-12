package Class::AutoPlug::Plugin;
use strict;
# use Smart::Comments;

# Turn on warnings, except for redefinitions.
use warnings;
no warnings 'redefine';

use Attribute::Handlers;

our $VERSION = 0.02;
### Loaded Plugin base
# This attribute handler exports a plugin's method into the 
# corresponding ::Pluggable class.

sub PluggedMethod :ATTR(CODE, BEGIN) {
  	my ($package, $symbol, $referent, $attr, $data, $phase) = @_;
  	### PluggedMethod
  	_advertise("METHODS", $package, $symbol, $referent, $attr, $data);
  	return;
}

sub Prehook :ATTR(CODE,BEGIN) {
  	my ($package, $symbol, $referent, $attr, $data) = @_;
  	### Prehook
  	_advertise("PREHOOKS", $package, $symbol, $referent, $attr, $data);
}

sub Posthook :ATTR(CODE,BEGIN) {
  	my ($package, $symbol, $referent, $attr, $data) = @_;
	### Posthook
  	_advertise("POSTHOOKS", $package, $symbol, $referent, $attr, $data);
}

sub _advertise {
  	my ($queue_name, $package, $symbol, $referent, $attr, $data) = @_;
  	# Adds an item to the supplied queue.
  	no strict 'refs';
  	my $target_var = "${package}::$queue_name";
  	my $queue = *{$target_var}{ARRAY} || [];
  	push @$queue, $data=>$referent;
  	*{$target_var} = $queue;
}

"Class::AutoPlug::Plugin defined";

__END__

=head1 NAME

Class::AutoPlug::Plugin - base class for a Class::AutoPlug::Pluggable plugin

=head1 SYNOPSIS

	package Vacuum::Plugin::Screamer;
	use base qw(Class::AutoPlug::Plugin);

    # Defines a sub that will implement a new foo() method
	sub foo_impl :PluggedMethod(foo) {
  		print "RUNNING!!!!!\n";
	}

    # Defines a prehook for the bar() method in the Vacuum::Pluggable class.
	sub starting :Prehook(bar) {
  		my ($self, $args) = @_;
  		print "About to bar ...\n";

		# Bypass call to the real method.
		# Any other prehooks will still execute.
  		if ($args eq "skip me") {
    		print "Asked to skip\n";
    		return 1;
  		}
  		else {
			# Go ahead and call the original method.
    		return 0;
  		}
	}

	# Defines a posthook for the (pre-existing) bar() method.
	sub stopping :Posthook(bar) {
  		print "After get...\n";
	}

=head1 DESCRIPTION

C<Class::AutoPlug::Plugin> allows you to define methods and hooks using attributes. You
don't need to worry about how your code will access the base class; it'll just work.

=head1 ATTRIBUTES

This class has no callablel methods; everything's done as attributes. We'll use the 
B<local_impl()> sub for all our examples.

=head2 sub local_impl :PluggedMethod(method_name)

Causes the B<local_impl()> subroutine to be added as the method B<method_name> in the 
pluggable class. Note that the B<method_name> is a literal bareword!

The parameters it receives are a reference to the pluggable object and whatever other
parameters that were specified in the call. You can use last_method() and base_object() to help in
processing your method call; you may also store instance data in the pluggable object. 

Note that there is no protection from someone else using the same slot names as you in the 
hash that represents the pluggable object. This allows different plugins to communicate (pro),
but can lead to namespace conflicts if two plugins use the same key (con). It's suggested that you
add the name of your plugin to your keys to help keep them unique.

=head2 sub local_impl :Prehook(base_method_name)

Addes B<local_impl()> as a prehook to the I<base> class's B<base_method_name> method. Again,
the name is a literal bareword. You get a reference to the pluggable object and a 
Class::AutoPlug::ResultState object. You can alter the ResultState object to change the contents of
@_ and/or the result value.

=head2 sub local_impl :Posthook(base_method_name)

Exactly like :Prehook, except that the posthook gets the current return value and can alter it as
it chooses (or leave it alone). Again, you get a Class::AutoPlug::ResultState object, which you can 
alter to change AutoPlug@_ or the method result.