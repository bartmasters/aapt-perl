#!/pkgs/bin/perl -w

######################################################
# xyzull.pl    -       Check incoming XYZ mails and fill tables
#                       when appropriate...
#
# Created:      August 13, 2001
# Author:       David Little
# Version:      1.1
#
# Use 'xyzull.pl -h' to get a list of command line args. and
# help on the script or use 'perldoc xyzull.pl'. The script
# should be run as a deamon process but will print debug
# information to STDOUT when (-d) command line option is used.
# (Its advisable to use this option for a test run!)
######################################################

use strict;
# use diagnostics;
use FindBin;		# Local (bin) dir. of script!!
use Getopt::Std;	# Process command line args.
use Net::POP3;		# POP mail
use DBI;			# Database connection module
use MD5;			# Encryption for POP login
# use DB_File;

#----
# Make sure we've got the full path to the perl script libs
use lib "$FindBin::Bin/../lib";	# Assuming we're using a lib directory

#----
# Homemade Modules!
use Log;
use CfgLoader;
use Tables;
use Utils;


#----
# Sort Cmd Line Args
my %cmds;
my $PARAMS = 'ho:s:u:p:c:l:f:dgm:S:U:P:';	# Command line options
&set($PARAMS, \%cmds);  		# Use help(-h) to get some info.!!!

$Utils::DEBUG = $cmds{d};  		# Print debug(-d) info.!?!

#----
# Generate def. config. file and exit if (-g)
generateCfg($cmds{g}) unless ($cmds{c} || ! $cmds{g});	

#----
#  Config Handle
debug("Processing Configuration Parameters:\n");
my $cfg = new CfgLoader($cmds{c});

#----
# Oracle
$cfg->ORACLE($cmds{o});  	# Oracle Host name
$cfg->SID($cmds{s});     	# Oracle SIG name
$cfg->USER($cmds{u});    	# Oracle user name
$cfg->PASSWORD($cmds{p});	# Oracle password name

#----
# Pop
$cfg->POP($cmds{P});  		# POP Server
$cfg->POPUSER($cmds{U});     	# POP login user
$cfg->POPPASSWORD($cmds{W});   	# POP login password

#----
# Script
$cfg->LOGHOME($cmds{l});	# Script Log Home
$cfg->FILE($cmds{f});		# i/p File to process (will ignore pop)
$cfg->MSGID($cmds{m});		# Message id to use for i/p file processing

#----
# Some private variables...

# Wait (secs) between syslog checks
$cfg->MONTIME(2)   unless ($cfg->MONTIME()); 
$cfg->MONTIME(10)  unless ($cfg->MONTIME() || Utils::debug()); 

# Wait (secs) for syslog to reappear (if has been moved/back'd up)
$cfg->WAIT(100)    unless ($cfg->WAIT()); 		

# Notify log every (WAIT*MONTIME see below) while checking syslog
$cfg->NOTIFY(20)   unless ($cfg->NOTIFY()); 
$cfg->NOTIFY(3600) unless ($cfg->NOTIFY() || Utils::debug()); 	

# DBM/File to record what pop msgids we've done
$cfg->DBM(".xyz.dbm");							

# Host Name
my $h = `hostname`; chomp($h);
$cfg->HOST($h) unless ($cfg->HOST());

debug("End Configuration\n");

#----
# Ensure we have all the required params 
debug("Ensuring correct arguments\n");
ensure($cmds{f});

#----
#  Log Object
debug("Log Object: " . $cfg->LOGHOME() . "\n");
my $log = new Log($cfg->LOGHOME());

# Will be a deamon run unless debug run...
$log->daemon() unless ($cmds{d});	

#----
# Table Object
#
# Just setting up tables hashes - will reconnect later
# on if we get input - don't want to keep the DB connection
# open all the time...
#
my $tbl = new Tables(&dbconnect());

#-----------------------------
# Processing
#-----------------------------

#----
# Catch Interupts...
$SIG{INT} = \&interupt;

#----
# Don't check syslog if user wants to use i/p file
unless ( $cfg->FILE() ) {
	$tbl->disconnect(); 

	my $hostname = $cfg->HOST();
	my $mon = $cfg->MONITOR();
	if (  $cfg->POP() =~ /$hostname/ ) {
		#----
		# We're on the pop server machine and can tail syslog
		# Initially, check to make sure the monitor file is around!
		ERROR("$mon File doesn't exist!\n") unless (-e $mon);
	}

	$log->log("Starting ($0) Deamon Loop");
	do {
		#----
		# Deamon Loop...
		my $addr = $cfg->MAILFROM();

		if ( $cfg->POP() =~ /$hostname/i ) {
			# Use the syslog to check for incoming e-mails
			$log->log("Running on '$hostname', scanning: $mon");
			sysscan($addr, $mon);
		} else {
			# Not running on the POP Server machine, just
			# pop the server every so often!
			$log->log("Running on '$hostname', using timed-pop");
			popscan($addr);
		}
	} while (1);
} else {
	#----
	# Process command line i/p file...
	#
	my $file = $cfg->FILE();
	print "---> Processing File $file\n\n";

	open(FILE, "<$file") or ERROR("Couldn't open file $file: $!\n");
		my @lines = <FILE>;
		print "---> Mail Message Contains ($#lines) lines\n";

		$cfg->MSGID(1) unless ($cfg->MSGID());

		my $uid = &uniqueid($cfg->MSGID(), "A");

		my $ret = $tbl->process($uid, \@lines);
		printf "\n---> Processing %s\n",
				($ret) ? "Failure: $ret" : "Finished";
	close(FILE);

	$tbl->disconnect();
}


#-----------------------------
# Subroutines
#-----------------------------

# popscan(addr)		- Pop server every so often!
# Parameters: 	$addr	-	Mail address we're using!
#
# Returns:     <none>
#
sub popscan {
		my $addr = shift || return;

		my $timeout = $cfg->WAIT(); 
		my $notify -= $cfg->NOTIFY();  # Every (secs. * MONTIME) notify log
		debug("Beginning popscan process!\n");
		LOOP: for(;;) {
			#----
			# Notify log that we're popping!
			if (++$notify > 0) {
				debug("Popping server after ". $cfg->NOTIFY()." secs idle time.\n");
				$notify -= $cfg->NOTIFY();
				procmail($addr);
			}

			sleep(1);
		}
}

# sysscan(addr, mon)	- Scan mon for addr!
# Parameters: 	$addr	-	Mail address to scan for..
#				$mon	-	Monitor file (i.e. syslog)
#
# Returns:     <none>
#
# We'll just keep a tail/watch on the syslog file until 
# we get a mail from $addr then we'll pop all messages 
# from server and cycle through any we haven't done 
# before. (The messages have a unique id in server!)
#
sub sysscan {
		my $addr = shift || return;
		my $mon  = shift || return;

		#----
		# Be aware the file could be removed/backed up, timeout 
		# if we can't access the syslog within a 'wait' period.
		my $timeout = $cfg->WAIT(); 
		do { 	
			if ($timeout < 0) {
				# Basically informing log that we're waiting for the 
				# monitor file to come back (every WAIT secs)
				$log->warn("Timeout waiting for $mon to exist");
				$timeout = $cfg->WAIT();
			}
			$timeout--;
			sleep(1);	
		} until ( -e $mon );	# Exists!?!

		#----
		# Check 'from=' mails from...
		$log->log("Scanning for '$addr' in  $mon");
		open(MON, "<$mon") or $log->warn("Couldn't open monitor file $mon: $!");
		seek(MON, 0, 1);	# End of MON file already popped!

		my $filesize = (stat(MON))[7]; # filesize in bytes
		my $notify -= $cfg->NOTIFY();  # Every (secs. * MONTIME) notify log

		LOOP: for (;;) {
			last LOOP unless(-e $mon);

			# Current position of file pointer...
			my $curp;
			for($curp = tell(MON); <MON>; $curp = tell(MON)) {
				chomp;
				if (/from=.{0,20}$addr/i && ! /$0/) {
					$log->log("Line $.: $&\n");
					procmail($addr);
				}
				last LOOP if ((stat(MON))[3] == 0 || ! -e $mon); # last if file has been removed?
			}

			#----
			# Notify log that we're still up and kickin' (NOTIFY*MONTIME)
			if (++$notify > 0) {
				$log->log("Waiting for '$addr' mails at ($curp):$mon");
				$notify -= $cfg->NOTIFY();
			}

			# File (hardlink) removed?  
			last LOOP if ((stat(MON))[3] == 0 	|| 
							! -e $mon 			|| 
							-s $mon < (stat(MON))[7]); 

			debug("Pausing, (".$cfg->MONTIME().") before monitor re-check\n");
			sleep($cfg->MONTIME());

			# Return to where we left off...
			seek(MON, $curp, 0);
		}

		close(MON);
		return;

}

# unique(start, del, pk, table) - Generate unique id (check database for..)
# Parameters: 	$start	-	Start number for unique id
#				$del	-	Delimitor for id
#				$pk		- 	Primary key in table
#				$table	-	Table to look in
#
# Returns:     <none>
#
# Checks the table for a unique id and if it already exists it
# increments the number until it creates a one...
sub uniqueid {
	my $start = shift;
	my $del	  = shift || "";
	my $pk    = shift || "mailid";
	my $table = shift || "xyz_mail";

	my $uid = $del . sprintf("%04d", $start) unless ($start =~ /^\D.*/);
	debug("Checking/Creating unique id: starting with ($uid)\n");

	#----
	# Need to 'create' a unique id for the file so that we can
	# put it into database table. 
	my $ans;
	do {
		$ans = $tbl->alreadyIns($uid, $pk, $table);
		$uid++ if ($ans);
	} until (! $ans);

	return $uid;
}

# ensure(file) - Make sure we have the correct vars...
# Parameters: 	$file - Seperate file processing with full syslog
#
# Returns:     <none>
#
# Dies unless we have all the required params for processing
# xyz mails...
sub ensure {
	my $file = shift || "";
	die "---> Need Oracle User Name(-u)\n" 	unless ($cfg->USER());
	die "---> Need Oracle Password(-p)\n" 	unless ($cfg->PASSWORD());
	die "---> Need Oracle Server(-o)\n" 	unless ($cfg->ORACLE());
	die "---> Need Oracle SID (Database)(-s)\n" 	unless ($cfg->SID());
	# Need the following if processing non-file
	unless ($file) {
		die "---> Need MONITOR File (i.e. syslog)\n" unless ($cfg->MAILFROM());
		die "---> Need MAILFROM Address\n" unless ($cfg->MAILFROM());
		die "---> Need POP Server\n" unless ($cfg->POP());
		die "---> Need POPUSER\n" unless ($cfg->POPUSER());
		die "---> Need POPPASSWORD\n" unless ($cfg->POPPASSWORD());
		die "---> Need SAVEHOME to save processed mails\n" unless ($cfg->SAVEHOME());
	}
}

# procmail($addr) - Extract mails
# Parameters: 	addr	-	address line we found!	
#
# Returns:     <none>
#
# Extract mails from POP server process mail and fill
# Tables...
#
sub procmail {
	#
	#  POP Handle
	#
	my $addr = shift || "";

	$tbl->reconnect(&dbconnect());

	my $server = $cfg->POP();

	# $log->log("Processing XYZ mail message from ($addr)\n");
	$log->log("POP Connecting: $server");
	my $pop = new Net::POP3($server, Timeout => 60) 
		or ERROR("Couldn't Connect to POP ($server): $!\n");

	# Use MD5 Module to encrypt login(user, pass) --> apop(user, pass) 
	debug("POP Login: ".$cfg->POPUSER()."\n");
	# defined($pop->apop($cfg->POPUSER(), $cfg->POPPASSWORD())) 
		# or ERROR("Couldn't Login to POP ($server)\n");
	defined($pop->login($cfg->POPUSER(), $cfg->POPPASSWORD())) 
		or ERROR("Couldn't Login to POP ($server)\n");

	# Get hash list of msgnum and unique Ids
	my $mails = $pop->uidl()
		or ERROR("Couldn't Extract message no. and unique ids from pop server: $!\n");  
	my @num = keys %$mails;
	#$log->log("(".($#num+1).") mail(s) to process");
	debug("(".($#num+1).") mail(s) to process");

	my ($msgn, $muid);
	while ( ($msgn, $muid) = sort each %$mails) {
		debug("\n#----\n", 1);
		debug("Processing Message: $msgn\n");
		my $uid = "";
		if ( $uid = &done($muid) ) { 	 # Record/Check what we've done!
			debug("Message ($msgn: $uid) already processed\n");
			next;
		} else {
			$uid = &uniqueid($msgn, "P"); # Get a unique id for msg
			done($muid, $uid);
		}
		$log->log("Message ($msgn: $uid) processing");
		my $msg;
		$msg = $pop->get($msgn)
		 	or ERROR("Couldn't pop $msgn ($uid) from pop server!", $uid);

		if ($msg) {
			my $from = $tbl->getData( $msg, "From" );
			
			# Make sure the message if from xyz and someone else!
			#my $ret = $tbl->process( $uid, $msg ) if ($from =~ /$addr/);
			my $ret = $tbl->process( $uid, $msg );

			my $savedt = &Utils::date(12);
			my $file = $cfg->SAVEHOME() .'/'. $cfg->SID() . ".$uid.$savedt"; 
			$log->log("Saving mail message ($uid) to: $file");
			my $res = Utils::save($file, $msg);
			$log->warn("Couldn't save mail message ($uid): $res\n") if ($res);
			
			# undef ret. on success else an error message!!
			if($ret) {
				xyzfailure("($msgn:$uid)", $ret, $msg); 
			} else {
				xyzsuccess($uid, $msg);
				# $pop->delete($msgn);
			}
		} else {
		# Failed...
				xyzfailure("($msgn:$uid)", "Failed to retrieve message from pop: $!\n");
		}
	}
	debug("POP quit\n");
	$pop->reset();	# Don't set mails as read!
	$pop->quit();
	
	$tbl->disconnect();
}

# done(puid, suid)	- Check and see if we've already processed mail!
# Parameters:  	puid	- 	Unique ID supplied by pop mail server...
#				suid	-	Script Unique id
#
# Returns:    Scirpt unique id if msgnum already exists, undef otherwise 
#
# Checks pop 'uid' in dbm file to see if we've already processed
# this message...if it hasn't add it.
#
sub done {
	my $puid = shift || return; # Unique Id from POP
	my $suid = shift || "";     # Our Unique Msg. Id

	my $exists;
	my %REC;

	debug("Checking to see if '$puid' has been processed?\n") unless ($suid);
	open(D, "+>>".$cfg->DBM()) or warn "Couldn't check ".$cfg->DBM()." for done mails: $!";
		foreach ( <D> ) { 
			chomp($_); 
			debug($_."\n") unless ($suid);
			/(.*)=(.*)/; 
			$REC{$1} = $2 || ""; 
		}
		if ( exists $REC{$puid} ) { $exists = 1; }
		else { print D "$puid=$suid\n" if ($suid); $exists = 0;  }
	close(D) or return $exists;

	debug("'$puid' exists\n") if ($exists);
	return $REC{$puid} if ($exists);
	return;
}

# recdone(uid)	- Appends the mail 'uid' to the dbm/file
# Parameters:  uid		- 	Unique ID supplied by pop mail server...
#
# Returns:    <none>
#
sub recdone {
	my $uid = shift;

	debug("Adding $uid");
	open(D, ">>".$cfg->DBM()) or warn "Couldn't check ".$cfg->DBM()." for done mails: $!";
		print D "$uid\n";
	close(D);

}

# dbconnect	- Connect to the Database
# Parameters:  <none>
#
# Returns:     Database handle
#
# Connects to db using configuration variables 
#
sub dbconnect {
	my $source = 'DBI:Oracle:host=' . $cfg->ORACLE();
	$source .= ';sid='. $cfg->SID();  

	#my $source = 'DBI:Oracle:host=haybioss1.opseng.aapt.com.au;sid=WFADSM';
	my $dbh = DBI->connect($source, $cfg->USER(), $cfg->PASSWORD(), 
			{ RaiseError => 1, AutoCommit => 0 }) || ERROR($DBI::errstr);

	return $dbh;
}

# ERROR(msg)	-	Prints msg and dies!!
# Parameters:  msg	- Message to print
#
# Returns:     <none>
#
# Logs ERROR message and dies...
#
sub ERROR {
	my $msg = shift;

	$log->error("$msg");
	$log->DESTROY();

	die "$msg";
}

# set   - Extract Command Line Arguements
# Parameters:   $get    - Command line (possible) for getopt
#               $cmdref - Commands Hash Ref. to store results
#
# Returns:              Nothing
#
# Get command line args and fill hash reference
#
sub set {
	my $get  = shift;
        my $cmdref = shift || {};
        my $line = join($", @ARGV);

        getopts($get, $cmdref);

		# foreach ( keys %$cmdref ) { debug(print "$_ = ".$cmdref->{$_} ."\n"); }
        	help() if ($cmdref->{h});
		
		return $cmdref;
}

# generateCfg - Generate Sample configuration file
# Parameters:   $gen   -  (-g flag) Generate config. file and exit! 
#				'name' -  Config file name... def: <script>.cfg
#
# Return:      Nothing
#
sub generateCfg {
	my $gen = shift || 0;
	my $name = shift || "";

	($name) = $0 =~ /[\.\/]*(.*?)\..*/ unless ($name);
	exit if (-e "$name.cfg" && $gen);
	open(C, ">$name.cfg") or ERROR("Couldn't create CFG $name: $!\n");
	print C "# This is a configuration file for $0 script.\n";
	print C "# These params can be entered through the command line\n\n";
	print C "#----\n";
	print C "# Oracle\n";
	print C "#----\n";
	print C "ORACLE = haybioss1.opseng.aapt.com.au # Oracle Server location\n";
	print C "SID 	= WFADSM\n";
	print C "USER = owf_mgr\n";
	print C "# PASSWORD = owf_mgr # Should enter password for each run!\n\n";
	print C "#----\n";
	print C "# POP Variables\n";
	print C "POP = glbncs4.opseng.aapt.com.au # Our pop server\n";
	print C "POPUSER = dlittle\n";
	print C "# POPPASSWORD = changeme\n";
	print C "#----\n";
	print C "#----\n";
	print C "# Script Variables\n";
	print C "#----\n";
	print C "# Monitor file for incoming mails!\n";
	print C "MAILFROM = xyzed.com.au # Monitor syslog for msgs. coming from...\n";
	print C "MONITOR = /var/log/syslog\n";
	print C "LOGHOME = /tmp\n";
	print C "# ADMIN = dlittle\@aapt.com.au # (comment if N/A) Mail messages on fail\n";
	close(C);

	print "\n Generated $name.cfg \n" if ($gen);
	exit if ($gen);
}

# help - Print Help
# Parameters:   $with   -  Help with 'what'. Default to die with info.
#
# Returns:      Nothing
#
sub help {
        my $with = shift || "";

        unless ($with) {
			print "$0\t[$PARAMS]\n";
			print "\nWhere:\n";
			print "\t-h\tPrints this help\n";
			print "\t-o\t[Oracle Server]\n";
			print "\t-s\t[Oracle SID]\n";
			print "\t-u\t[User]\n";
			print "\t-p\t[Password]\n";
			print "\t-c\t[Config File]\n";
			print "\t-f\t[Input Message - File to process instead of pops]\n";
			print "\t-m\t[Message Id for (-f) passed file]\n";
			print "\t-l\t[Log Location]\n";
			print "\t-d\tDebug Mode\n";
			print "\t-g\tGenerate Sample Config File\n\n";
			print "\t-S\t[POP Server]\n";
			print "\t-U\t[POP User]\n";
			print "\t-P\t[POP Password]\n";

			print "\tThe $0 script takes the above flags, with [] ";
			print "indicating required values. A configuration file "; 
			print "is/can be used instead/as well, through CfgLoader.  ";
			$0 =~ /(.*\.).*/;
			print "This config. file '$1cfg' is generated using default ";
			print "variables, on a script run or when using (-g) option. ";
			print "(unless the file is already in existance of course.) ";
			print "The script either reads the syslog file for incoming ";
			print "'xyz' messages or if the input file (-f) option is used ";
			print "the script tries to process the file and insert/update ";
			print "the xyz tables in the database.  The tables used ";
			print "are set in the Tables module (tables) and these ";
			print "should be updated when required.  The tables module ";
			print "loads the column information for each table into ";
			print "a hash (self) and will try to extract the values ";
			print "from the mail or passed file\n\n";
			exit;
        }
}

# interupt      - Interupt catcher!
#
# Catches any CTRL^C during processing...
#
sub interupt {
        my ($msg) = @_;

        ERROR("\n$msg Received - Ending Process\n");
}

# xyzfailure - Fail!
#
# If XYZ Returns Error Failure - E-Mail Appropriate
# persons
sub xyzfailure {
	my $msgn = shift || return;
	my $err  = shift || "";
	my $mail = shift || "";

	$log->warn("$0 Failure: $msgn\n\t$err\n");

	debug("XYZ Failure: $err\n");

	my $body = join("\n", @$mail)."\n";
	Utils::mail($cfg->ADMIN(), "XYZ Fail: $msgn", 
		"$err\n\nBody of message follows:\n----\n$body") if ($cfg->ADMIN()); 
	
}

# xyzsuccess - Interupt catcher!
#
# Catches any CTRL^C during processing...
#
sub xyzsuccess {
	my $uid = shift || "";
	my $mail = shift || "";


	$log->log("XYZ Success ($uid)\n");
	debug("XYZ Success ($uid)\n");
}

# debug      - Debug print, uses Utils::debug!
#
sub debug {
	my $msg = shift || "";
	my $docaller = shift || "";

	Utils::debug($msg, $docaller);
	# sleep(1);
}


__END__

=head1 NAME

xyzull.pl	-	Reads XYZ mails/file and fills xyz DB tables

=head1 SYNOPSIS

=over 4

=item B<-h>	-	Prints help

=item B<-o>	-	[Oracle Server]		Location of the Oracle Server

=item B<-s>	-	[Oracle SID]		Oracle SID (database) to use

=item B<-u>	-	[Oracle User]

=item B<-p>	-	[Oracle Password]		

=item B<-c>	-	[Config File]		Default parameters file

=item B<-f>	-	[Input File]		Mail Message to process

=item B<-m>	-	[Message Id]		Mail Message ID for File

=item B<-l>	-	[Log Location]		Where are we putting the logs?

=item B<-d>	-	Debug Mode			Debug info...

=item B<-g>	-	Create Config File	Create 'default' configuration file

=item B<-S>	-	[POP Server]

=item B<-U>	-	[POP User]

=item B<-P>	-	[POP Password]

=back

=head1 DESCRIPTION

The script takes the above flags, with [] indicating required values.  The script either reads the syslog file for incoming 'xyz' messages or if the input file (-f) option is used the script tries to process the file and insert or update the xyz tables in the database.  The tables used are set in the Tables module (tables) and these should be updated when required.  The tables module loads the column information for each table into a hash (self) and will try to extract the values from the mail or passed file.

B<Scanlog:> When we run on the same POP Server machine the host syslog is scanned.  Once a syslog message contains an apropriate incoming mail message address, the script I<pops> all the mails from a pop server and processes any mails that have arrived.  

B<Scanpop:> When we run on a machine other the the pop server the script uses a timeout mechanism to pop the server every I<set number> of seconds.  

The pop server maintains an B<unique id> for each mail, the script keeps track of done mails (through dbm file) using these ids and only processes I<new> mails. New mails will be recored in the xyzmail table using a generated unique id as the primary key(the Pop unique id is not very legible).  

Log information is written to I<syslog> using the AAPT Logging module and sql log information is written to a I<sqlnet.log> in the directory from which the script is run. The script is expected to run as a I<deamon> process.  Every 'NOTIFY' secs. the script will write a waiting message to syslog just to ensure that it is still up and kicking.

B<Note:> The script uses a configuration file (<script name>.cfg) which is automatically generated if NOT found.  The user should change the config. variables in this file to ensure full operation of script. (Use: -g flag to generate the file and exit!)

B<MAPPING>

The scirpt uses a Tables module to extract required database information.  Also in the extraction process, mapping table information is also extracted.  This table lists the mapping between xyz passed variables (i.e. in the e-mail) and aapt's internal variables.  If an entry isn't listed in the mapping's table the script will lowercase and remove spaces from the xyz field in an attempt to insert it into the appropriate table.  

=head1 AUTHOR

AAPT (c/o dlittle@aapt.com.au)

=cut
