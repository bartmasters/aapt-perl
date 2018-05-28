package CfgLoader;

######################################################
# CfgLoader.pm    - Loader Module, load config variables
#					and process any command line args...
#
# Created:      August 19, 2001
# Author:       David Little
# Version:      1.0
#
######################################################
use Utils;

#----
#	new("classname", file)	-	New CfgLoader Object		
#	$cfg_obj-><VAR>(<VALUE>) - Set/Get VAR
#
#	Note:
#	  <VAR>	  -	configloader object variable
#	  <VALUE> -	sets VAR=VALUE or returns VAR value if blank
#   (Can also use $cfg_obj->get(VAR) or $cfg_obj->set(VAR, VALUE) )
#	E.G.
#		$cfg_obj->LOGHOME("/tmp")	- Sets LOGHOME var. to '/tmp'
#		$cfg_obj->LOGHOME()			- Returns value of LOGHOME
#


# new - Creates new ConfigLoader object...
# Parameters: proto -	Associate with 'class' name
#			  file  -	Config file (Field = Value Type)
#
# Returns:     new Table Object
#
# Creates a new configloader object.  This object contains all the 
# 'config' information; loaded from the configuration file (see _init)
# below.  This file should be of a 'field = value' format and 
# may also have '#' comments...
#
sub new {
	my $proto = shift || return;
	my $class = ref($proto) || $proto;

	my $self = {};

	# If not supplied will default to $0.cfg
	$self->{"_cfg"} = shift || ""; 

	bless($self, $class);
	$self->_init(@_);
	return $self;
}

# AUTOLOAD($config_object, @_) - A quick way of setting
# retriveing config params.
#
# $config_object->get(VAR) 	- Returns value of VAR
# $config_object->set(VAR, VAL) - Sets VAR to new VAL
# $config_object->VAR()		- Returns value of VAR
# $config_object->VAR(VAL)	- Sets VAR to new VAL
#
# Added optional Tag... can use ensure() to make sure
# that all tagged variables have been set!
#
sub AUTOLOAD {
	my $self = shift;
	my $info = shift;
	my $tag  = shift;  # Is this vital?

	my ($fname) = $AUTOLOAD =~ /.*::(.*)/;

	if ($fname =~ /get/) {
		return $self->{VARS}->{$info};
	} elsif ($fname =~ /set/) {
		$self->{VARS}->{$info} = shift;
	} else {
		if (!($info) && exists($self->{VARS}->{$fname})) {
			return $self->{VARS}->{$fname};
		} else {
			$self->{VARS}->{$fname} = "";
			$self->{VARS}->{$fname} = $info if ($info);
			$self->{REQD}->{$fname} = $tag  if ($tag);
		}
	}

	return;
}

# enusure() - Checks variables for 'required' and dies with
# error message unless variable exists...
#
sub ensure {
	my $self = shift;

	Utils::debug("Ensuring all required values available\n");
	my ($k, $v) = ("", "");
	while ( ($k, $v) = each %{$self->{VARS}} ) {
		if ( $self->{REQD}->{$k} && 
			 $self->{REQD}->{$k} == 1 &&
			 length($v) <= 0 ) {
			die "----> Script Requires '$k' Value\n";
		}
	}
}

# Internal
#
# Initialize internal variables - this loads the config.
# file into the object hash {VARS} using Field = Value format.
# If no config. file is passed to object creation then the 
# default is the caller script with '.cfg' appended E.G.
# 	./checker.pl --> ./checker.cfg
#
sub _init {
	my $self = shift || return;

	if (@_) {
		my %extra = @_;
		@$self{keys %extra} = values %extra;
	}

	($self->{_scr}) = $0 =~ /[\.\/]*(.*?)\..*/;
	unless (exists ($self->{_cfg}) && ($self->{_cfg})) {
		$self->{_cfg} = $self->{_scr}.".cfg";
	} 

	$self->{_cfg} = "../cfg/$self->{_cfg}" unless (-e $self->{_cfg});

	if (-e "$self->{_cfg}") {
	  Utils::debug("Loading $self->{_cfg}\n");
	  open(CFG, "<$self->{_cfg}") or die "Couldn't open $self->{_cfg}: $!";
	  my $ln;
	  while($ln = <CFG>) {
		next unless $ln;
		next unless $ln !~ /^#|^\n/;   # Skip comment/blank lines
		chomp($ln);
	
		# Line should be field=value format (ignore any # after this)
		$ln =~ s/^(.*?)\s*?=\s*?(.*?)\s*#*/$1=$2/;
		Utils::debug("$ln\n");
		my @sp = split(/=/, $ln);
		$sp[1] =~ s/(.*?)\s*#.*/$1/;
		$self->{VARS}->{$sp[0]} = $sp[1] if ($sp[0]);
	  }
	  close (CFG);
	} else {
		die "Couldn't load config. file: ".$self->{_cfg}."\n";
	}
	
	return $self;
}	

1;
	
