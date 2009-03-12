package Class::AutoPlug::Pluggable;
# AutoPluguse Smart::Comments;
use Class::AutoPlug::ResultState;
use Devel::Peek;
use Sub::Installer;

our $AUTOLOAD;
our $VERSION = 0.02;

# Methods to call for each plugin to finish initialization.
my @init_methods = qw(_load_methods _set_hooks);

sub new {
	my ($class, %args) = @_;
	(my $base_class = $class) =~ s/::Pluggable//;

  	# Must have a base class object to delegate to.
  	eval "use $base_class";
  	die "$base_class not loadable: $@\n" if $@;

  	my $pluggable_name = $class;
  	$pluggable_name =~ s/Pluggable$/Plugin/ 
    	or die qq(The module name "$class" is incorrect; it should end in "::Pluggable"\n);
  	# Create plugins() method in the proper class.
  	eval <<EOS;
package $class; 
use Module::Pluggable search_path=>[qw($pluggable_name)]
EOS

  	my $self = {};
  	bless $self, $class;

  	$self->{PreHooks} = {};
  	$self->{PostHooks} = {};

  	# Let the plugins look over the arguments
  	# initialize themselves, and use up arguments that they want.
  	local $_;
  	delete $args{$_} foreach $self->_init(%args);

  	# Read and act on all the "advertisements" from the plugins.
  	if (exists $args{consume} and ref $args{consume} eq 'ARRAY') {
		$self->_consume(@{ $args{consume} });
  	}
  	else {
		$self->_consume(@init_methods);	
  	}
  	$self->base_obj($base_class->new(%args));
  	return $self;
}
	
sub _init {
	my ($self, %args) = @_;
  	# call all the inits (if defined) in all our
  	# plugins so they can all set up their defaults
  	my @deletes;

  	foreach my $plugin ($self->plugins) {
    	eval "use $plugin";
    	if ($plugin->can('init')) {
      		push @deletes, $plugin->init($self, %args);
    	}
  	}
  	return @deletes;
}

sub _consume {
  	my ($self, @method_names) = @_;
  	foreach my $plugin ( $self->plugins) {
    	foreach my $method (@method_names) {
      		$self->$method($plugin);
    	}
  	}
}

sub _set_hooks {
  	my($self, $plugin) = @_;
  	my $class = ref $self;
  	foreach my $hook_type (qw(PRE POST)) {
     	# Find the hook queue for this plugin
		my @hook_queue;
     	{
			no strict 'refs';
     		@hook_queue = eval "\@${plugin}::${hook_type}HOOKS";
		}
     	my $method_name = lc($hook_type)."_hook";
     	while ( (my($hooked_method, $hook_sub), @hook_queue) = @hook_queue) {
       		# Install the hooks
       		$self->$method_name($hooked_method, $hook_sub);
     	}
  	}
}

sub _load_methods {
  	my ($self, $plugin) = @_;
  	my @methods = eval "\@${plugin}::METHODS";
  	while (@methods) {
    	(my($method_name, $method_code), @methods) = @methods;
    	if ($self->can($method_name)) {
      		warn "$method_name redefined by plugin\n";
    	}
		__PACKAGE__->install_sub( { $method_name => $method_code } );
   	}
}

sub remove_hook {
  	my ($self, $which, $method, $hook_sub) = @_;
  	$self->{$which}->{$method} = 
    	[grep { "$_" ne "$hook_sub"} @{$self->{$which}->{$method}}]
      		if defined $self->{$which}->{$method};
	return;
}

sub insert_hook {
  	my ($self, $which, $method, $hook_sub) = @_;
  	push @{$self->{$which}->{$method}}, $hook_sub;
	return;
}

sub pre_hook {
  	my $self = shift;
  	$self->insert_hook(PreHooks=>@_);
	return;
}

sub post_hook {
  	my $self = shift;
  	$self->insert_hook(PostHooks=>@_);
	return;
}

sub AUTOLOAD {
  	# don't shift; this might be a straight sub call!
  	my $self = $_[0];

  	# figure out what was supposed to be called.
  	(my $super_sub = $AUTOLOAD) =~ s/::Pluggable//;
  	my ($plain_sub) = ($AUTOLOAD =~ /.*::(.*)$/);

  	# Record the method name so plugins can check it.
  	# We check for $self being a ref because this could
  	# be a class method call. (Plugins won't be able to
  	# re-call class methods, but I can't think of a reason
  	# why we'd need that for now, so we'll skip it.)
  	$self->last_method($plain_sub) if ref $self;

  	# If this is a straight sub call, just do it. We don't
  	# try to hook these.
  	if (scalar @_ == 0 or !defined $_[0] or !ref $_[0]) {
    	no strict 'refs';
    	$super_sub->(@_);
  	}
  	else {
		my $result = 
			Class::AutoPlug::ResultState->new( 
				{ context => (wantarray ? 'list' : 'scalar') } 
			);
    	my ($ret, @ret);
    	shift @_;
    	my @incoming = @_;
		$result->at_under(\@incoming);
	
    	my $skip;
    	if (my $pre_hook = $self->{PreHooks}->{$plain_sub}) {
	  		# There has not yet been a replacement result from any hook.
      		my $replacing_hook = undef;
      		my $replacement_result;

      		# No hook has forced a skip.
      		$self->_clear_skipping_hooks();

	  		# Try all the hooks in the queue.
      		foreach my $hook (@$pre_hook) {
	    		# Save the hook's name for diagnostics.
	    		my $current_hook_name = _name_from_coderef($hook);
	
	    		# Call it; returns a (possibly altered) ResultState.
        		$result = $hook->($self, $result);

				# Replace @_ if the hook returns a replacement version.
        		if (my $at_under_ref = $result->at_under) {
          			@_ = @{ $at_under_ref };
          			# Warn if we're not going to call the method; this may mean
          			# that the @_ alteration won't take.
          			warn "\@_ alteration by $current_hook_name may be useless; method skip by " .
               		$self->_show_skipping_hooks()
                 		if $self->_skipping_hooks();
        		}

				if ($result->result) {
		  			# Warn if there's already a replacing result, and replace it again.
          			if (defined $replacement_result and
						$replacement_result ne $result->result() and 
						defined $replacing_hook)  {
						### pre-current: $current_hook_name
						### pre-replacing: $replacing_hook
	        			warn "Result replaced by $current_hook_name but already done by $replacing_hook";
	       			}
	       			# Replace the result, and record who last replaced it.
		   			$replacement_result = $result->result;
		   			$replacing_hook = $current_hook_name;
				}

        		# Record the name of this hook if it wanted to skip the method call.		
        		if ($result->skip_method_call) {
	      			$self->_add_skipping_hook($current_hook_name);
	    		}
      		}
    	}

		# If any hook requested a skip, there'll be something in _skipping_hooks.
    	unless ($self->_skipping_hooks) {
      		# Double-check: can we actually dispatch this?
      		if (! $self->base_obj->can($plain_sub) ) {
        		# We have absolutely no idea what to do.
        		die "$plain_sub() call unresolvable (did all your plugins load?)\n";
      		} 

      		# We can do it. Go ahead, in the right context.
      		# Save the current result in the ResultState object.
      		if (wantarray) {
        		@ret = $self->base_obj->$plain_sub(@_);	
				$result->result([@ret]);
      		}
      		else {
        		$ret = $self->base_obj->$plain_sub(@_);
				$result->result([$ret]);
      		}
    	}

    	# If we actually called the method and got a return value save it.
    	# Note that we will call the method unless we were told to skip it;
    	# we may want to take advantage of side effects even if we don't care about the return value.
    	if ($replacement_result and !$self->_skipping_hooks) {
	  		if (wantarray) {
	    		@ret = @{ $replacement_result};	
				$result->result([@ret]);
	  		}
	  		else {
				if (int @{ $replacement_result } == 1) {
					$ret = $replacement_result->[0];			
				}
				else {
					$ret = scalar @{ $replacement_result };
				}
				$result->result([$ret]);
	  		}
    	}

    	# On to the posthooks. The ResultState object has whatever result was determined to be
    	# 'the' result - whether this was what came back from the method call, or whether it was
    	# supplied by a pre-hook is now immaterial.

		# Already captured, so discard this.
		$replacement_result = undef;
    	if (my $post_hooks = $self->{PostHooks}->{$plain_sub}) {
      		foreach my $hook (@$post_hooks) {
	    		# Save the hook's name for diagnostics.
	    		my $current_hook_name = _name_from_coderef($hook);
	    		# Hook returns a ResultState.
	    		$result = $hook->($self, $result);
				# We only are concerned with whether a replacing result exists for a posthook.
				if ($result->result) {
		  			# Warn if there's already a replacing result, and replace it again.
          			if (defined $replacement_result and 
						$replacement_result ne $result->result() and 
						defined $replacing_hook)  {
						### post-current: $current_hook_name
						### post-replacing: $replacing_hook
	        			warn "Result replaced by $current_hook_name but already done by $replacing_hook";
	       			}
	       			# Replace the result, and record who last replaced it.
		   			$replacement_result = $result->result();
		   			$replacing_hook = $current_hook_name;
				}
      		}
    	}

    	# Again, replace the return value if we've got something to replace it with.
    	if ($replacement_result) {
	  		if (wantarray) {
	    		@ret = @{ $replacement_result };	
				$result->result([@ret]);
	  		}
	  		else {
				if (int @{ $replacement_result } == 1) {
					$ret = $replacement_result->[0];			
				}
				else {
					$ret = scalar @{ $replacement_result };
				}
				$result->result([$ret]);
	  		}
    	}

    	wantarray ? @ret : $ret;
  	}
}

sub base_obj {
  	my ($self, $value) = @_;
  	$self->{_base_obj} = $value if defined $value;
  	return $self->{_base_obj};
}

sub last_method {
  	my ($self, $value) = @_;
  	$self->{_last_method} = $value if defined $value;
  	return $self->{_last_method};
}

sub _clear_skipping_hooks {
	my($self) = @_;
	$self->{SkippingHooks} = [];
	return;
}

sub _add_skipping_hook {
	my ($self, $hook_name) = @_;
	push @{ $self->{SkippingHooks} }, $hook_name;
	return;
}

sub _skipping_hooks {
	my($self) = @_;
	return @{ $self->{SkippingHooks} };
}

sub _show_skipping_hooks {
	my ($self) = @_;
	my @hook_names = $self->_skipping_hooks;
	if (@hook_names == 1) {
		return $hook_names[0];
	}
	elsif (@hook_names == 2) {
        return "$hook_names[0] and $hook_names[1]";
    }
    else {
		my $result = '';
	    while (@hook_names > 2) {
			$result .= $hook_name[0].', ';
			shift @hook_names;
		}
		return $result . "$hook_names[0] and $hook_names[1]";
	}
}

sub _name_from_coderef {
  	my ($sub) = @_;
  	my $ini = $sub;
  	$sub = $1 if $sub =~ /^\{\*(.*)\}$/;
  	my $subref = defined $1 ? \&$sub : \&$ini;
  	$subref = \&$subref;                  # Hard reference...
  	my $gv = Devel::Peek::CvGV($subref) or return "CODE()";
  	'&' . *$gv{PACKAGE} . '::' . *$gv{NAME};
}

"Class::AutoPlug::Pluggable defined";

=head1 NAME

Class::AutoPlug::Pluggable  - automatically make a non-pluggable class pluggable

=head1 SYNOPSIS

  package Nonpluggable::Class::Pluggable;
  use base qw(Class::AutoPlug::Pluggable);
  1;

=head1 DESCRIPTION

C<Class::AutoPlug::Pluggable> provides a means to automatically add pluggability to any class
without it. The plugin modules can not only export methods into the new base pluggable class, but
can also define prehooks and posthooks for any method supported by the base class.

Prehooks get control before the method is called, and posthooks are called after the method.
You can bypass the call altogether or alter what the call does via these hooks. See
C<Class::AutoPlug::Plugin> for details on writing hooks.

This class simply sets up the necessary infrastructure; you need write no code whatsoever in
classes which use it.

=head1 METHODS

=head2 new(...)

The B<new> method takes exactly the parameters that the base class supports and passes them along
to its constructor. The resulting object is cached internall and is used to execute actual calls to
the base class's methods.

You may add extra parameters to be handled by your plugins; see C<Class::AutoPlug::Plugin> for
details on how to do this. The extra parameters can either be left in the parameter list or 
deleted by the plugins.

=head2 pre_hook($method_name, $hook_sub_ref)

The B<prehook> method adds a prehook to the named method. The order in which the hooks are added
is currently not directly controllable by the plugin writer (it's actually done in collation order
of the names of the plugins).

=head2 post_hook($method_name, $hook_sub_ref)

The B<posthook> method adds a posthook in much the same way as prehook() adds a prehook.

=head2 insert_hook($queue_name, $method_name, $hook_sub_ref)

Allows you to explicitly address a hook queue and add a hook to it; you probably don't want to 
use this unless you're creating a completely new queue for your own purposes. This method will
generally be called in a plugin because you need the address of a hook subroutine to use it.
(It's certainly possible to, for instance, only set up a hook in the module which uses 
C<Class::AutoPlug::Pluggable> and not use a plugin at all. This might be useful if you just want
to use this module to "front-end" a few method calls in another module.)

=head2 remove_hook($queue_name, $method_name, $hook_sub_ref)

Allows you to remove a hook from a hook queue. Very similar to insert_hook(). Note that as long as
you have a reference to a subroutine which is being used as a hook, you can remove it using this
method, ev en if the code doing the remove_hook() wasn't the one that set the hook in the first 
place!

=head2 base_obj

Returns a reference to the internally-cached base-class object. Makes it easy for plugins
to call methods directly without running any of the hooks.

=head2 last_method

The name of the last method called on this object. Can be useful if you want to be able to send
another message to the object from within a hook without losing track of what method was called.
