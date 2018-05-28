package Tables;

######################################################
# Tables.pm    - XYZ Tables Module
#
# Created:      August 13, 2001
# Author:       David Little
# Version:      1.0
#
# Uses tables hash-array to store table column information
# for use with the checker script...
######################################################

use strict;
use Utils;

#---
# new("classname", dbh)					- New Table ($tbl) Object
# $tbl->process(mailid, \@mail, dbh) 	- Process xyz mail
#


my $MAINTABLE = 'xyz_transaction';
my $MAPTABLE = 'xyz_mapping';
my $MAILTABLE = 'xyz_mail';

#---
# Information tables - get internal values and corresponding
# XYZ external values from mappings table in the database
my $tables = {
	$MAINTABLE    => [],
	$MAILTABLE 	  => [],
	'xyz_carrier' => [],
	'xyz_contact' => [],
	'xyz_site' 	  => [],
	'xyz_service' => [],
	'xyz_product' => [],
};

#---
# Update messages...	see updateMain below...
#
# Variations of XYZ Messages for 'non-error' status messages.  The
# date fields in the transaction table gets updated on receipt of 
# these messages...
#
#	ACK	- Order Acknowledgement 	(ackdate)
#	CFM	- Firm Order Confirmation  	(commitdate)
#	PLA - Service Installation Date (installdate)
#	INS - Installation Complete 	(installeddate)
#	MAN	- Maintenance Scheduled		(maintenancedate)
#
my $messages = {
	ACK	=>	{ status => '[Firm Order|Order|Receipt] Acknowledgment|Receipt',
			  date => 'ackdate'
			},
	CFM	=>	{ status  => '[Firm Order|Order] Confirmation|FOC|XYZed Firm Order',
			  date => 'commitdate'
			},
	PLA =>	{ status  => 'Service Installation Date|Installation Notification',
			  date => 'installdate'
			},
	INS	=>	{ status  => 'Installation Complete|Order Completion Advice|Completion',
			  date => 'installeddate'
			},
	MAN =>  { status  => 'Maintenance Scheduled|Maintenace Date Set',
			  date => 'maintenancedate'
			},
};

# new - Creates new Table object...
# Parameters: proto -	Associate with 'class' name
#	      dbh   -   Database handle
#	      params(opt) - Params to be added to self hash
#
# Returns:     new Table Object
#
# Creates a new table object.  This object contains all the 
# 'tables' information; name, type, length etc. for use with
# XYZ ULL processing.  The object requires a database 
# connection handle (dbh), it doesn't store this handle as
# we don't want to have a permanent DB connection!  
#
sub new {
        my $proto = shift || return;
        my $class = ref($proto) || $proto;
		my $dbh = shift || die "Need 'dbh' - database handle";

        my $self = { dbh => $dbh };
        bless($self, $class);
        $self->_init(@_);

        return $self;
}

# Internal
#
# Reconnect the passed database handle to internal
sub reconnect {
	my $self = shift;
	my $dbh  = shift || "";

	$self->{dbh} = $dbh;
}

# Internal
#
# Disconnect the internal database handle
sub disconnect {
	my $self = shift;

	$self->{dbh}->disconnect() if ($self->{dbh});
}

# Destroy
sub DESTROY {
	my $self = shift;
	
	$self->{dbh}->disconnect() if ($self->{dbh});
}

# Internal
#
# Initialize internal variables
sub _init {
	my $self = shift || return;

	if (@_) {
			my %extra = @_;
			@$self{keys %extra} = values %extra;
	}

	($self->{_scr}) = $0 =~ /[\.\/]*(.*?)\..*/;
	# @$self{keys %{$messages}} = values %$messages;
	$self->{messages} = $messages;
	
	$self->{tables} = $tables;
	
	$self->extract();
}

# Internal
#
# Extract Information from the database
sub extract {
	my $self = shift;
	my $dbh  = shift || $self->{dbh};
	
	my($row, $tbl);
	foreach $tbl ( keys %{$self->{tables}} ) {
		#----
		# Get the column names for each of the tables
		debug("Extracting '$tbl' table data\n");
		my $sql = " select C.* from COL C WHERE ";
 		$sql .= "C.TNAME='".uc($tbl)."'";

		my $sth = $self->{dbh}->prepare($sql);
		my $rv = $sth->execute;

		die "Table 'execute' problem with $tbl" unless ( $rv );

		ROW: while(($row) = $sth->fetchrow_hashref) {
			last ROW unless ($row);

			my $list = {};
			$list->{internal} = lc($row->{CNAME});
			$list->{type}     = lc($row->{COLTYPE});
			$list->{nulls}    = $row->{NULLS};
			$list->{width}    = $row->{WIDTH};
			$list->{key}	  = 0; 	# For Update Info...
			
			push @{$self->{tables}->{$tbl}}, $list;
		}
		die "Table '$tbl' doesn't exist in database!\n" 
				unless ( $#{$self->{tables}->{$tbl}} > -1 );

		debug( "(".$#{$self->{tables}->{$tbl}}.") row(s) read from $tbl\n\n" );
		$sth->finish;
	}

	#-----
	# Possible repetitions for external variants... Have 
	# we already processed this?
	my $sql2 = "select * from $MAPTABLE";
			
	my $sth2 = $self->{dbh}->prepare($sql2);
	$sth2->execute;
	MAP: while(($row) = $sth2->fetchrow_hashref) {
		last MAP unless ($row);
		$row->{TABLENAME} =~ s/\s*(.*)/$1/ if ($row->{TABLENAME});
		$row->{TABLENAME} = lc($row->{TABLENAME});
		# External - Internal Mapping
		$self->{_external}->{$row->{EXTERNAL}} = $row->{INTERNAL} 
			if ( ! $row->{TABLENAME} || $row->{TABLENAME} eq "%" );
		$self->{_external}->{"$row->{TABLENAME}$row->{EXTERNAL}"} = $row->{INTERNAL} 
			if ($row->{TABLENAME});
		# Internal - External Mapping
		$self->{_internal}->{"$row->{INTERNAL}"} = $row->{EXTERNAL} 
			unless ( exists($self->{_internal}->{"$row->{INTERNAL}"}) );
		$self->{_internal}->{"$row->{TABLENAME}$row->{INTERNAL}"} = $row->{EXTERNAL} 
			if ($row->{TABLENAME});
	}
	$sth2->finish;


	#-----
	# Now we have a $self->{tables} hash with keys as table names
	# and values as arrays, containing hash information for each
	# column in the table;
	#	internal - Internal name of field
	#	type	 - Type of field (e.g. varchar2, number)
	#       nulls	 - NULL, NOT NULL
	#
	# Also have $self->{_external} containing <table>external=internal mapping
	#
	if (Utils::debug()) {
	    print "Set up Tables Hash\n";
		my ($table, $values);
		while ( ($table, $values) = each %{$self->{tables}} ) {
			# sleep(1);
			print "$table: ($#{$values})\n=======\n";
			
			foreach ( @{$values} ) {
				print "$_->{internal}:\t$_->{type}($_->{width}) \n"; 
			}
			print "\n";
		}
	
		print "External\t\tInternal\n";
		my ($k, $v);

		while ( ($k, $v) = each %{$self->{_external}} ) {
			print "'$k':\t\t$v\n";
		}

		print "\nEnd Data Extraction!\n";
		# sleep(3);
	}	

	return $self;
}

# Internal
#
# Check and see if the row has been already been added
# to the database
sub alreadyadded {
	my $self = shift;
	my $tbl  = shift || return;
	my $list = shift || return;

	my $tblarray = $self->{tables}->{$tbl};

	foreach ( @{$tblarray} ) {
		if ( $_->{internal} eq $list->{internal} &&
		     $_->{nulls} eq $list->{nulls} &&
		     $_->{type} eq $list->{type} ) {
		     # list already exists...
		     return $_;
		}
	}
	
	return $list;
}

# process - Process the XYZ mail/message
# Parameters: 	self  -	Table object
#	      		dbh   -   Database handle
#	      		mail  -   mail array ref.
#	      		mailid  -   pop mail id
#
# Returns:     undef on success
#	       Error Message on failure
#
# Process the mail message - requires a dbh handle
# It updates status of 'transaction' table... along with
# order table (if xyz initial mail)
sub process {
	my $self = shift;
	my $mailid = shift || return "Error: Mail ID required!";
	my $mail = shift || return "Internal Error: No mail message supplied";
	my $dbh  = shift || $self->{dbh} || return "Internal Error: No database handle supplied";

	$self->{dbh} = $dbh;

	debug("Processing mail\n");

	my $success;

	my $status = $self->getStatus($mail);
	my $ref    = $self->getRef($mail);

	# Record mail message in xyzmail!!!
	my $ret = $self->xyzmail($ref, $status, $mailid, $mail);
	return $ret if ($ret);

	return "Couldn't extract Reference Number from mail!" unless ($ref);

	my $already = $self->alreadyIns($ref);

	if ($status =~ /order/) {
		# Is an intial order...
		return "Transaction (referenceno = $ref) already inserted into '$MAINTABLE' table" if ($already);
		$self->fillTables($mail);
		my $ans = $self->informWF($ref);
		return "Table inserted but WorkFlow stored procedure failure $ans\n" if ($ans);
	} else {
		# Is an update on a current order
		return "Couldn't find original (referenceno = $ref) transaction in '$MAINTABLE'!" unless ($already);
		my $s = $self->updateMain($ref, $status, $mailid, $mail);
		$success = "Update of transaction table (referenceno = '$ref' and status = '$status') unsuccessful!"
				unless ($s);
	}

	return $success;
}

#----
# xyxmail Fields:
#
#	mailid
#	referenceno
#	status
#	generated
#	description
#	updatedate
#	updatedby
#
sub xyzmail {
	my $self 	= shift;
	my $ref 	= shift;
	my $status	= shift;
	my $mailid	= shift;
	my $mail	= shift;

	my $already = $self->alreadyIns($mailid, 'mailid', $MAILTABLE);
	return "Mail (mailid = $mailid) already inserted into '$MAILTABLE' table!" if ($already);

	debug("Setting up $MAILTABLE information\n");
	$self->set($MAILTABLE, 'mailid', $mailid);
	$self->set($MAILTABLE, 'referenceno', $ref);
	$self->set($MAILTABLE, 'status', $status);
	# getIntData($mail, $get, $tbl)
	$self->set($MAILTABLE, 'generated', $self->getIntData($mail, "generated") );
	$self->set($MAILTABLE, 'description', $self->getData($mail, "Subject") );

	$self->set($MAILTABLE, 'updatedby', $self->{_scr} );
	$self->set($MAILTABLE, 'updatedate', Utils::date() );
		
	my $ret = $self->insert($MAILTABLE);
	return "Insertion Failure ($mailid) on 'xyzmail' table!" if ($ret < 0);
	return;
}

# Internal
#
# Call stored procdure to launch xyz process... see __END__
#
sub informWF {
	my $self = shift;
	my $ref  = shift;

	my $date = Utils::date();
	my $processname = "XYZ_DSL";

	my $str1 = "BEGIN wf_engine.CreateProcess($processname,$date,'DSL_EMAILS'); END;";
	my $str2 = "BEGIN wf_engine.SetItemAttrText($processname, $date, 'REF_NO', '$ref'); END;";
	my $str3 = "BEGIN wf_engine.SetItemOwner($processname, $date, 'DSL_PM'); END;";
	my $str4 = "BEGIN wf_engine.StartProcess($processname, $date); END;";

	debug("Executing Stored Procedures\n\t1) $str1\n\t2) $str2\n\t3) $str3\n\t4) $str4\n");
	my ($eff1, $eff2, $eff3, $eff4) = (0,0,0,0);

# Call Oracle Workflow to start a new XYZ_DSL procedure with
# $date as a unique key.

	$eff1 = $self->{dbh}->do($str1);	
	$eff2 = $self->{dbh}->do($str2);
	$eff3 = $self->{dbh}->do($str3);	
	$eff4 = $self->{dbh}->do($str4);
	
	return "CreateProcess"   if ( $eff1 == -1 );
	return "SetItemAttrText" if ( $eff2 == -1 );
	return "SetItemOwner"    if ( $eff3 == -1 ); 
	return "StartProcess"    if ( $eff4 == -1 );
	return;
}

# $table_object->alreadIns($id, $pk, $tbl) 
# Parameters:	id	-	id to check for
#				pk	-	column to check in
#				tbl	-	Table to check in
#
# Returns:		1 on found, undef if not found.
# Check and see if the id is in table. id should be
# a primary key.
#
sub alreadyIns {
	my $self = shift;
	my $id = shift || return;
	my $pk  = shift || "referenceno";
	my $tbl = shift || $MAINTABLE;
	
	my $sql = "select $pk FROM $tbl WHERE $pk = '$id'";

	debug("Checking for Insert: $sql\n"); 
	
	# sleep(1) if Utils::debug();

	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;

	my @row;
	while ((@row) = $sth->fetchrow_array) {
		debug("Found primary key ($pk): '@row'\n");
		return 1;
	}	

	$sth->finish;

	return;
}

# Internal
# updateMain($tbl, $ref, $status, $mailid, $mail)
# Parameters:	tbl - table object
#				ref - xyz refernece number
#				status - status of last mail
#				mailid - pop mail id
#				mail   - mail array ref.
#
# Update the status field in the transaction table
sub updateMain {
	my $self = shift;
	my $ref = shift || return;
	my $status = shift || "Unknown";
	my $mailid = shift || "";
	my $mail   = shift || "";

	my $date = Utils::date();

	my $sql = "update ".$MAINTABLE ." SET";
	$sql .= " status = '$status',";
	if ($mailid) {
		$sql .= " mailid = '$mailid',";
	} else {
		my $desc = $self->get($MAINTABLE, 'description') || "";
		$desc .= ";" if ($desc);
		$sql .= " description = '$desc SSR Update:$date'";
	}

	my @num = keys %$messages;
	debug("Processing ($#num) for message types\n");
	#----
	#	ACK	- Order Acknowledgement 	(ackdate)
	#	CFM	- Firm Order Confirmation  	(commitdate)
	#	PLA 	- Service Installation Date (installdate)
	#	INS 	- Installation Complete 	(installeddate)
	#	MAN	- Maintenance Scheduled		(maintenancedate)
	my $st = "";		# Which e-mail messages 'status'
	my ($m, $v);
	# Which Mail are we processing?
	#while ( ($m, $v) = each %{$self->{messages}} ) {
	while ( ($m, $v) = each %{$messages} ) {
		debug("Checking ($status =~ '/".$v->{status}."/i)'\n");
		$st = $m if ($status =~ /$v->{status}/i); 
		if ($st && length($st)>0) {
			debug("'$st' message!\n");
			last;
		}
	}

	if ($st) {
		# Set the transaction-date field for whatever message...
		my $dt = $self->getIntData($mail, $v->{date}, $MAINTABLE);
		
		unless ($dt && $st eq "INS") {
			# E-mails are d*** awkward - we can get; 
			#
			# We have successfully completed on:
			#		12/30/2001 12:33 PM
			my $i;
			for ($i=0; $i < $#{$mail}; $i++ ) {
				next unless ( $mail->[$i] =~ /complete[d{0,1}] on[:{0,1}]\b/i );
				debug("Got $& in mail...\n");
				do { ++$i; } until ( $mail->[$i] );  # skip blank lines
				debug("Using line $i: ". $mail->[$i] . " for date!?!\n");
				my $ext = $mail->[$i] if ( $mail->[$i] =~ /\d+\/d+|AM|PM/ );
			}
		}
 
		$dt ||= Utils::date(12) . " GMT";	# Default to now (GMT)!
		$sql .= $v->{date}."='$dt',"; 	# The appropriate date field

		if ($st eq "CFM") {
			$sql .= " serviceid='".$self->getIntData($mail, 'serviceid')."',";
		}

		$sql .= " xyzreferenceno='" .$self->getIntData($mail, 'xyzreferenceno')."',";
	}

	$sql .= " updatedby='". $self->{_scr} ."', updatedate='$date'"; 
	$sql .= " WHERE referenceno = '$ref'";
	debug("$sql\n\n");

	return $self->{dbh}->do($sql);
}

# Internal
#
# Fill the 'order' tables...
sub fillTables {
	my $self = shift;
	my $mail = shift;
	my $tbls = shift || [ keys %{$self->{tables}} ];

	debug("Processing mail ($#{$mail} line(s))\n\n");
	my $ln;
	my $table;
	#----
	# Set values for each table... that is, for each table
	# the mail lines will be cycled through and the line
	# will be fit to a table field!! (maybe!)
	# 
	#
	foreach $table ( @$tbls ) {
		debug("Mail Extraction ($table):\n");
		foreach $ln ( @$mail ) {
			next unless ($ln);
			next unless ($ln =~ /\w+\b/);
		
			$self->setValues($ln, $table) if ($table);
		}
		# sleep(2) if Utils::debug();
	}

	#----
	# Make sure the transaction params are set properly here!
	# $self->set($MAINTABLE, 'signeddate', $self->get("xyz_carrier", "signeddate"));

	my @tbls; 
	# Don't insert the xyz_mail - do that elsewhere (xyzmail())
	foreach ( keys %$tables ) { push @tbls, $_ unless (/$MAILTABLE/i); }
	$self->insertTables( \@tbls );
}

# Internal
# insertTables(tbls)
# Parameters:	tbls	-	Table array to insert defaults
#							to all the self->tables
#
# Returns:		<none>
#
# Move through tables hash and insert
sub insertTables {
	my $self = shift;
	my $tbls = shift || [ keys %{$self->{tables}} ];

	debug("Tables to Insert:\n @$tbls\n"); 
	# sleep(1);
	my $tbl;
	foreach $tbl ( @$tbls ) {
				next unless ( $self->{tables}->{$tbl} );
                $self->insert($tbl);
	}

}

# Internal
# get(tbl, fld)
#
# Get a value from the tables->transaction array
sub get {
	my $self = shift;
	my $tbl = shift;
	my $fld = shift;

	my $arref = $self->{tables}->{$MAINTABLE};
	my $f;
    foreach $f ( @$arref ) {
		  return $f->{value} if ($f->{internal} =~ /$fld/);
	}

	return;
}

# Internal
# set(tbl, fld, val)
#
# Set a value in the tables->transaction array 
sub set {
	my $self = shift;
	my $tbl = shift;
	my $fld = shift;
	my $val = shift;	
	
	my $trans = $self->{tables}->{$tbl};
	my $f;
	foreach $f ( @$trans ) {
		$f->{value} = $val if ($f->{internal} =~ /$fld/);
	}
}

# Internal
# insert(tbl, dbh)
#
# Return:	Number of rows effected.
# Insert into table sql 
sub insert {
	my $self = shift;
	my $tbl  = shift;
	my $dbh  = shift || $self->{dbh};


	my ($r, @vals, @flds);
	foreach $r ( @{$self->{tables}->{$tbl}} ) {
		my $v = $r->{value} || "";
		unless ($r->{type} =~ /number/) {
			push @vals, $dbh->quote($v);
		} else {
			$v ||= 0;
			push @vals, $v;
		}
		push @flds, $r->{internal};
	}
	
	my $ins = "INSERT INTO $tbl (";
	$ins .= join(",", @flds);
	$ins .= ") VALUES (".$self->format($tbl).")";

	my $sql = sprintf($ins, @vals);
	debug("$sql\n");

	my $ret = $self->{dbh}->do($sql);
	return $ret; 
}

sub insertsql {
	my $self = shift;
	my $tbl  = shift;
	my $flds = shift;
	my $vals = shift;

	my $ins = "INSERT INTO $tbl (";
	$ins .= join(",", @$flds);
	$ins .= ") VALUES (".$self->format($tbl).")";

	my $sql = sprintf($ins, @$vals);

	return $sql;
}

# Internal
# format(tbl)
#
# Set format for tables for insertion, returns
# a format for use with sprintf()
sub format {
	my $self = shift;
	my $tbl = shift;

	my $format = "";
	my $r;
	foreach $r ( @{$self->{tables}->{$tbl}} ) {
		my $w = $r->{width};
		$format .= "%".$w."s," if ($r->{type} =~ /^varchar/i);		
		$format .= "%".$w."d," if ($r->{type} =~ /^number/i);		
		$format .= "%".$w."c," if ($r->{type} =~ /^char/i);		
	}

	$format =~ s/(.*),$/$1/;
	debug("Table '$tbl' format: $format\n");

	return $format;
}

# Internal
#
# Set the values of all the passed table... 
# using the mail line
sub setValues {
	my $self = shift;
	my $ln   = shift;
	my $tbl  = shift;

	# Line should be Field: Value Format
	return unless($ln =~ /^(.*?)\s*:\s*(.*)/);
	my ($fld, $val) = $ln =~ /^(.*?)\s*:\s*(.*)/;

	#----
	# Mapping of internal to external from Mapping Table
	# Priority for tablefield then pure mapping...
	my $int = $self->{_external}->{"$tbl$fld"};  
	$int ||= $self->{_external}->{$fld};		  
	# If all else fails, default to the actual mail field, 
	# all lowercase and getting rid of spaces
	unless ($int) {
		$int = lc($fld);	# lowercase
		$int =~ s/\s//g;	# no spaces
		$int =~ s/(.*?)\(.*?\)(.*)/$1$2/; 	# no bracket info?
	}

	# debug(" ($int)", 1);
	# debug("\t'$fld'=\t'$val'\n", 1);
		
	my ($c);
	foreach $c (@{$self->{tables}->{$tbl}}) {
		if ($c->{internal} eq $int) {
			debug($c->{internal} . "(".$c->{width}.")"." set to '");
			$c->{value} = substr($val, $c->{width}, 0) 
				unless (length($val) < $c->{width});
			$c->{value} ||= $val;
			debug($c->{value}."' with width (".length($c->{value}).")\n", 1);
		} 
		# Not Null fields - fill here...
		$c->{value} = $self->{_scr} if ($c->{internal} =~ /updatedby/i);
		$c->{value} = Utils::date() if ($c->{internal} =~ /updatedate/i);
	}
}

# Internal
# getIntData($mail, $get, $tbl)
# Parameters:	mail - mail message
#				get	- internal data to get
# 				tbl - table object
#
# Get a particular piece of Data from the mail message...
# We know the internal name but don't know the external
# name...
sub	getIntData {
	my $self = shift;
	my $mail = shift;
	my $get  = shift || return;
	my $tbl  = shift || "";

	my $ext;
	$ext = $self->{_internal}->{"$tbl$get"} if ($tbl);  
	$ext ||= $self->{_internal}->{"$get"};  
	$ext ||= $get;

	debug("Parsing for '$ext' in mail! "); 
	my $ans = $self->getData($mail, $ext) || "";
	debug(" - retrieved: '$ans'\n", 1);
	# sleep(1) if Utils::debug();

	return $ans;
}

# Internal
# getData($tbl, $mail, $get)
# Parameters:	tbl - table object
#				mail - mail message
#				get	- data to get
#				dir - Which direction (1-from begin, 0-from end)
#
# Get a particular piece of Data from the mail message...
# Will Get the exact get, case sensitive
sub getData {
	my $self = shift;
	my $mail = shift;
	my $get  = shift || return;	# What are we looking for?
	my $dir  = shift || 0;		# 0 - normal, 1 - reverse

	my @list = ($dir) ? reverse @$mail : @$mail;

	# Cycle through mail rows and look for get!
	foreach ( @list ) {
			next unless (/^$get\s*:\s*(.*)/);
			return ($1);
	}

	return;
}

# Internal
#
# Get the referenceno from the mail - using several different
# External Fields
sub getRef {
	my $self = shift;
	my $mail = shift;
	my $no = "";
	
	$no = $self->getData($mail, "Your Reference"); 
	$no ||= $self->getData($mail, "Your Ref");
	$no ||= $self->getData($mail, $self->{_internal}->{"referenceno"});

	debug("Mail Reference: '$no'\n") if ($no);
	return $no;
}

# Internal
#
# Get the status from the mail using 'Status' or 'Subject' line!
sub getStatus {
	my $self = shift;
	my $mail = shift;

	my $st;
	# Mails have a Status: Field which implies we have two maybe!?!
	# If there is just one.  Skip it and get the Subject!!!
	$st = $self->getData($mail, "Status", 1);  # '1' starts at end...
	my $st2 = $self->getData($mail, "Status"); # Starts at beginning...
	$st = "" if ($st2 eq $st);		

	$st ||= $self->getData($mail, "Subject", 1);

	debug("Mail Status: '$st'\n");
	return $st;
}

# Internal
#
# Print only on CfgLoader::DEBUG
sub debug {
	my $msg = shift;
	my $extra = shift || 2;

	Utils::debug($msg, $extra);
}

	

1;

__END__

=head1 NAME

Tables	-	Tables Package

=head1 DESCRIPTION

B<Procedures>

You need to call several PL/SQL procedures to create and launch a Workflow process for XYZ DSL.  The first procedure creates the process :-

C<WF_ENGINE.CreateProcess (itemtype, itemkey, process)>

Where:

=over 3

=item	itemtype = XYZ_DSL
=item	itemkey = a unique key for each call of the process.  Currently we're using date/time
=item	process = the subprocess within XYZDSL that will be called.  This is DSL_EMAILS

=back

Once the Process has been created, the Reference Number of the DSL Order must be passed to the process.  This is stored as an attribute in the process, so you need to set the attribute's value.

C<WF_ENGINE.SetItemAttrText (itemtype, itemkey, aname, avalue)>

Where:

=over 4

=item	itemtype = XYZ_DSL
=item	itemkey = the unique date/time key
=item	aname = REF_NO
=item	avalue = the value of the reference number

=back

Next we set the owner of the process to DSL_PM.  This is the role assigned to the XYZ DSL Project Managers, so that they can monitor this process.

C<WF_ENGINE.SetItemOwner (itemtype, itemkey, owner)>

Where:

=over 3

=item	itemtype = XYZ_DSL
=item	itemkey = the unique date/time key
=item	owner = DSL_PM

=back

Finally we need to start the process, this will pass control to Workflow :-

C<WF_ENGINE.StartProcess(itemtype, itemkey)>

=over 2

=item	itemtype = XYZ_DSL
=item	itemkey = the unique date/time key

=back

=cut
