package Class::AutoPlug::ResultState;
use strict;
use warnings;
use Carp;
our $VERSION = 0.01;

sub new {
	my($class, $arg_ref) = @_;
	my $self = {};
	bless $self, $class;
	
	croak 'Argument to new() must be a hash reference' unless ref $arg_ref eq 'HASH';
	
	foreach my $method (qw(at_under skip_method_call result context)) {
		if(exists $arg_ref->{$method} and defined $arg_ref->{$method}) {
			$self->$method($arg_ref->{$method});
		}
	}
	croak 'Must create with a context' unless $self->context();
	return $self;
}

sub at_under {
	my ($self, $value) = @_;
	if (defined $value and (ref $value) eq 'ARRAY') {
		$self->{replace_at_under} = $value;
	}
	else {
		croak 'New value for replace_at_under is not an array reference'
			if defined $value;
	}
	return $self->{replace_at_under};
}

sub result {
	my ($self, $value) = @_;
	if (defined $value and (ref $value) eq 'ARRAY') {
		$self->{replacement_result} = $value;
	}
	else {
		croak 'New value for replacement_result is not an array reference'
			if defined $value;
	}
	return $self->{replacement_result};
}

sub skip_method_call {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{skip_method_call} = $value;
	}
	return $self->{skip_method_call};
}

sub context {
	my ($self, $value) = @_;
	if (defined $value and (grep { $_ eq $value } qw(scalar list) ) ) {
		$self->{context} = $value;		
	}
	elsif (defined $value) {
		croak "context cannot be '$value'; must be 'scalar' or 'list'";
	}
	
	return $self->{context};
}

1;
__END__

=head1 NAME

Class::AutoPlug::ResultState - track the current state of a method call

=head1 SYNOPSIS

	# All at once:
	my $hook_result = Class::AutoPlug::ResultState->new( 
		{
			at_under           => [qw(replacement params)],  # use 1 element for scalar context
			skip_method_call   => 1,                         # true or false
			result             => [qw(some value here)],     # use 1 element for scalar context
			context            => 'list',
		} 
	);
	
	# Little by little:
	my $result = Class::AutoPlug::ResultState->new();
	$result->at_under([$value]);						# values in anonymous array
	$result->skip_method_call(0);
	$result->result([$some, $list, $of, $values]);	    # ditto
	$result->context('scalar');
	
=head1 DESCRIPTION

C<Class::AutoPlug::ResultState> allows C<Class::AutoPlug> to track the state of the results of
method calls, including pre- and post-hooks. Hooks receive and return the state of the current
method call via this object, thus vastly simplyfying the interface between the hooks and 
C<Class::AutoPlug::Pluggable>.

=head1 HOOK PARAMETERS AND ACTIIONS

On entry to your hook, context() will already be set. It is I<strongly> recommended that you
not change this value! Doing so will confuse things mightly if some other hook depends on
accurately determining the context in which the original method call was made.

=head2 Pre-hooks

For pre-hooks, you may do any or all of the following:

=over 4

=item * replace the contents of @_

This allows you to alter the parameters that will be passed to the hooked method when it is called.

=item * replace the result with one of your own

This allows you to override the result from the method by preemptively returning your own
value.

=item * skip the base method call

You can completely bypass the method call if you've already handled it.

=back

Prehooks receive @_ (either as passed in, or as modified by other hooks), and the current return
value. They should return I<only> a HookResult object.

=head2 Post-hooks

Post-hooks may alter @_ and the result, just like pre-hooks. @_ will not be used by the base
method, however, unless the post-hook explicitly makes its own call to the base method. Replacement
of the results is honored exactly as it would be for pre-hooks.

Post-hooks may set the "skip method call" flag, but it shoud be noted that unless a corresponding
pre-hook has also done so, it's too late - the method has already been called.

=head1 METHODS

=head2 new($hash_ref)

The new() call constructs a new HookResult object. You may provide @_ and result data if you
wish; you may also set skip_method_call. The default (if no parameters are supplied) has neither
kind of data, and skip_method_call is set to a false value.

=head2 at_under([zero or more items])

at_under allows your hook to see what was in @_ at the time the hook was called, and (optionally)
to modify or replace this data. You must pass an array I<reference> to this call; use an empty
anonymous array if you want to set @_ to undef.

=head2 result([zero or more items])

result allows you to set a (tentative) result for the method call. Note that if you do not set
skip_method_call() to a true value in a pre-hook, this value will be overwritten when the method
is called.

=head2 context('scalar' or 'list')

Sets/gets the context in which the original method call was made. Hooks will receive a 
ResultState object with this already set up; it is a bad idea to change it, as this will
cause other plugins to return values which may be useless in the true context.

Again, C<Class::AutoPLug::Pluggable> (and any derived classes) should set this; hooks should not.

=head2 skip_method_call(true or false)

Allows you to say whether or not you want the base method call to be skipped. Only useful in 
pre-hooks; in post-hooks, the call has already happened.