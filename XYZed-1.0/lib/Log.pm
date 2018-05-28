package Log;
use FileHandle;
use Utils;

sub new {
	my $proto = shift || return;
	my $class = ref($proto) || $proto;

	my $self = {};
	$self->{_log} = shift || "";

	bless($self, $class);
	$self->_init(@_);
	return $self;
}

sub DESTROY {
	close($self->{_logh}) if ($self->{_logh});
	close($self->{_errh}) if ($self->{_errh});
}

sub AUTOLOAD {
	my $self = shift;
	my $msg = shift;

	my $date = &date(0);

	my ($fname) = $AUTOLOAD =~ /.*::(.*)/;

	if (exists($self->{_logh})) {
		_printfh($self->{_logh}, "$date ". uc($fname) .":\t$msg");
		_printfh($self->{_errh}, "$date ERROR:\t$msg") if ($fname =~ /error/i);	
	}

	$self->print("$date $fname:\t$msg");
}

sub daemon {
	my $self = shift;
	my $set = shift || 1;

	$self->{_daemon} = $set;
}

sub print {
	my $self = shift;
	my $msg = shift || "";
	
	if ( -t STDOUT && -t STDIN && Utils::debug()) {
		print STDOUT "$msg\n" unless ($self->{_daemon});
	}
}

sub _printfh {
	my $fh = new FileHandle;

	$fh      = shift || "";
	my $msg  = shift || "";

	print $fh "$msg\n" if ($fh);
	$| = 1;		# $AUTOFLUSH !!!
}

sub _init {
	my $self = shift || return;
	
	if (@_) {
		my %extra = @_;
		@$self{keys %extra} = values %extra;
	}

	$self->daemon();
	($self->{_scr}) = $0 =~ /[\.\/]*(.*?)\..*/;
	$self->{_log} ||= "/tmp";

	my $date = &date();
	unless (exists ($self->{logname})) {
		$self->{logname} = "$self->{_log}/$self->{_scr}.log.$date";
		$self->{errname} = "$self->{_log}/$self->{_scr}.err.$date";
	} else {
		$self->{logname} .= $date;
		$self->{errname} .= $date;
	}
	
	Utils::debug("Log is " . $self->{logname}."\n");
	$self->{_logh} = new FileHandle;
	$self->{_errh} = new FileHandle;

	open($self->{_logh}, ">>$self->{logname}") or Error("Unable to open LOG: $self->{logname}: $!");
	open($self->{_errh}, ">>$self->{errname}") or Error("Unable to open ERR: $self->{errname}: $!");

	$self->log("Started: $date");
	
	return $self;
}	

sub date {
        my $self = shift;

        my ($y, $m, $d, $h, $mi, $se) = (localtime)[5,4,3,2,1,0];
        $y += 1900;

        my $date = sprintf("%4d%02d%02d%02d%02d%02d%02d", $y, $m, $d, $h, $mi, $se);

        return $date;
}

sub Error {
	my $msg = shift;

	die "$msg\n";
}

1;
	
