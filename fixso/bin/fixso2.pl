#!/pkgs/bin/perl -w
######################################################
# fixso2.pl - the son of fixso.pl
#				Same as fixso.pl - we just changing ddmmyy
#				to ddmmccyy.  Thats all.
#
# Created:      4 December, 2001
# Author:       Bart Masters
# Version:      0.1
#
######################################################

use strict;				# Be good, lil program
use FindBin;			# To find our locally developed modules
use DBI;				# Database connection module
use Getopt::Std;		# Process command line options
use aapt::log;

# Make sure we've got the full path to the perl script libs

use lib "$FindBin::Bin/../lib";	# Assuming we're using a lib directory

# Locally developed modules

use CfgLoader;			# Loads up Configs

# Global Variables

my $socount;			# Number of Service Orders processed
my @seroid;				# Array of the Service Order IDs processed
my $errorcount;			# Number of invalid attributes found
my $servicetype;		# Service Order Type we are processing
my $attributename;		# Attribute name
my $attributevalue;		# Attribute's current value 
my $attributepattern;	# Formatting pattern for the attribute
my $serviceorderid;		# ID of the Service Order being processed
my $serviceorderstatus;	# Status of the Service Order being processed
my $userid;				# Userid to connect to Oracle
my $password;			# Password to connect to Oracle

my $recordcount = 0;	# Number of Service Orders processed
my $params = "Us:u:p:";	# Valid command line options
my $mailadmin = 0;		# Email the admin if there's a problem during the run

# Arrays n hashes n stuff

my @logfile;			# The log body
my %standpatt;			# The 'standard' formatting patterns
my %servlayout;			# The layout and patterns for the service type
my %cmds;				# Command line options

#----------------------
# Main Processing
#----------------------

# Get the command line options

getopts($params, \%cmds);

# Load up Config files - if -s has been used in 
# command line (ie Service Type) use that, else get
# Service Type from fixso2.cfg file

my $cfg = new CfgLoader();
if (exists $cmds{s})
{
	$servicetype = $cmds{s};
}
else
{
	$servicetype = $cfg->SERVICETYPE();
}

# Get the oracle userid/password

if (exists $cmds{u})
{
	$userid = $cmds{u};
}
else
{
	die "Userid is required using the -u parameter\n";
}

if (exists $cmds{p})
{
	$password = $cmds{p};
}
else
{
	die "Password is required using the -p parameter\n";
}

# Load the service type's patterns.

my $layoutname = $servicetype . ".cfg";
%servlayout = loadfile("\L$layoutname");

# Load up the standard pattern descriptions

%standpatt = loadfile("pattern.cfg");

# Connect to the database

my $dbh = dbconnect();

# Open up the logfile

my $date = currdate();
my $logname = $servicetype . $date;
new aapt::log(
			'To' =>	'bamaster@aapt.com.au',
			'WantEmail' => 0,
			'Logbase' => "../log",
			'Logfile' => $logname);
			
info("Started processing for service type $servicetype\n");

# Loop through Service Orders

$socount = process();

# Now lets spit out the output 

produceoutput();

# If there's been an error in running, email the admin to check it out

if ($mailadmin)
{
	mailadmin();
}

# Finish up by printing nice message and disconnecting.

print "Everything successfully completed for $servicetype - $socount records processed\n";
print "$recordcount records updated\n";
info("Everything successfully completed for $servicetype - $socount records processed\n");
info("$recordcount records updated\n");

$dbh->disconnect();

#-----------------------------
# Subroutines
#-----------------------------
# dbconnect	- Connect to the Database
#
# Parameters:  None
#
# Returns:     Database handle

sub dbconnect
{
	my $oracle;
	my $sid;

	if ($cmds{U})
	{
		$oracle 	= $cfg->UATORACLE();
		$sid		= $cfg->UATSID();
	}
	else
	{
		$oracle 	= $cfg->ORACLE();
		$sid	 	= $cfg->SID();
	}
	my $source 		= 	'DBI:Oracle:host=' .
						$oracle .
						';sid=' .
						$sid;

	print "Connecting to $oracle $sid as userid $userid\n";
	my $dbh = DBI->connect ($source, $userid, $password, { RaiseError => 1, AutoCommit => 0}) 
		|| die "Error connecting to $oracle: $DBI::errstr\n";
	
	return $dbh;
}

# loadfile - Load up a config file into a has for use
# later in the program.
# The config files are expected to be in the format
#
# FIELD NAME == DETAILS == ENGLISH DESCRIPTION
#
# Two ='s are used as field delimiters since a single =
# could be used as field data.
#
# Parameters:	$filename - name of the config file	
#
# Returns:		%hash - the hash data is loaded into

sub loadfile
{
	
# Firstly, load up the file

	my $filename = shift;
	open (CONFIGFILE, "../cfg/$filename")
		|| die "Error opening $filename file $!\n";
	my $line;
	my %hash;
	while ($line = <CONFIGFILE>)
	{
		next unless $line;
		next unless $line !~ /^#|^\n/;
		chomp ($line);
		my @sp = split (/==/, $line);

# Strip off excess leading and trailing spaces

		$sp[0] =~ s/^\s+//;
		$sp[0] =~ s/\s+$//;
		$sp[1] =~ s/^\s+//;
		$sp[1] =~ s/\s+$//;

# Sometimes we'll only have a format of 
# FIELD NAME == DETAILS 
# ie no description.  If thats so, set up the 2nd entry
# in the hash as blank.

		unless (defined($sp[2]))
		{
			$hash{$sp[0]} = [$sp[1], " "];
		}
		else
		{
			$sp[2] =~ s/^\s+//;
			$sp[2] =~ s/\s+$//;
			$hash{$sp[0]} = [$sp[1], $sp[2]];
		}
	}
	close(CONFIGFILE) 
		|| die "Error closing $filename file $!";

return %hash;
}

# process - Work through the full list of
# service orders that have the same type as
# the service type either passed in config file, or
# in command line options.
# Each service order pass to fixattribute() for 
# checking/fixing their attributes.
#
# Parameters:	None
#
# Returns:		Total number of records retrieved

sub process
{

# First, get all the service orders of the type passed
# to us in the config file. 

	my $recordcount = 0;
	my $sql = 	"select sero_id
				 from service_orders
				 where sero_sert_abbreviation = ?";

	my $sth = $dbh->prepare($sql);
	$sth->execute("\U$servicetype") ||
		die "Error reading service_orders: $DBI::errstr\n";

# For each of these Service Orders check their appropriate
# attributes, and fix if required.

	while ((@seroid) = $sth->fetchrow_array)
	{
		++$recordcount;
		fixattribute(@seroid);
	};
	
	return $recordcount;
}

# fixattribute - Check if an attribute is dodgy, and
# if so, fix it. 
#
# Parameters:	Service Order ID
#
# Returns:		Total number of records retrieved

sub fixattribute
{
	$serviceorderid = shift;
	my @attribute;
	my $sql =	"select seoa_name, seoa_defaultvalue
				 from service_order_attributes
				 where seoa_sero_id = ?";

	my $lth = $dbh->prepare($sql);
	$lth->execute($serviceorderid) ||
		die "Error reading service_type_attributes: $DBI::errstr\n";

# Loop through the attributes and check each one

	while ((@attribute) = $lth->fetchrow_array)
	{
		$attributename = $attribute[0];
		$attributevalue = $attribute[1];
		$attributepattern = $servlayout{$attributename}[0];

# Now that we've got the attribute and its pattern, lets check
# the attribute matches the pattern.

		if (defined($attributevalue) and
		    defined($attributepattern))
		{
			if ($attributepattern eq ":DATE")
			{
				fixdate($attributevalue);
			}
		}
	}
}

# fixdate - Fix dates. 
#
# Parameters:	None
#
# Returns:		None	

sub fixdate
{
	my $olddate = shift;

# If the date matches the format dd/mm/yy - convert it to 
# dd-mm-yyyy.
	
	if ($olddate =~ /^\d{6}$/)
	{
		my $newdate = $olddate;
		substr($newdate, 4,2) += 2000;
		updatedb($newdate, $olddate, $serviceorderid, $attributename);
	}
}
# updatedb - Update the database. 
#
# Parameters:	$newvalue - New value
#				$oldvalue - Old value
#				$updateid - Service Order to be updated
#				$updatename - Attribute to be updated
#
# Returns:		None	

sub updatedb
{
	my $newvalue = shift;
	my $oldvalue = shift;
	my $updateid = shift;
	my $updatename = shift;

#	my $sth = $dbh->prepare("update service_order_attributes
#						 set seoa_defaultvalue = ?
#						 where seoa_sero_id = ?
#						 and seoa_name = ?");
#	my $rc = $sth->execute($newvalue, $updateid, $updatename) ||
#		die "Error updating service_order_attribtues: $DBI::errstr\n";

	push (@logfile, "Service Order $updateid attribute $updatename \t is being changed	from $oldvalue to $newvalue\n");
	++$recordcount;
}
# produceoutput - Spit out the output
#
# Parameters:	None
#
# Returns:		None

sub produceoutput 
{
	for (@logfile)
		{
			info($_);
		}
}
# currdate - Get the current date and massage it into a nice
# format for creating the log file.
#
# Parameters:	None
#
# Returns:		Current Date	

sub currdate
{
	my ($y, $m, $d, $h, $mi, $se) = (localtime)[5,4,3,2,1,0];
	$y += 1900;
	$m += 1;

	my $date = sprintf("%4d%02d%02d%02d%02d%02d%02d", $y, $m, $d, $h, $mi, $se);

	return $date;
}
# mailadmin - Send email to the administrator
#
# Parameters:	None
#
# Returns:		None

sub mailadmin
{
	my $adminmailaddr = 'bamaster@aapt.com.au';
	my $mail = Mail::Mailer->new("sendmail") || die "Error trying to create mail: $!\n";
	$mail->open({
		"From"		=> "BIOSS Big Brother",
		"To"		=> $adminmailaddr,
		"Subject"	=> "Problem running fixso2.pl"
			})
			|| die "Couldn't create mail: $!\n";
		
	print $mail "Error processing $servicetype - check it out k plz thx";
	$mail->close();
}
