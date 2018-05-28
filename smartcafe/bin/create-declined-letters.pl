#!/pkgs/bin/perl58 -w

######################################################
# create-declined-letters.pl - Create a Declined for
# Credit letter for all declined applications in 
# Smartcafe.
#
# Created:      June 8, 2004
# Author:       Bart Masters
# Version:      1.0
#
# When a customer application for credit has been 
# declined, we need to send a letter to them informing
# them of this fact.
# This program scans through the Smartcafe database
# (Chubby) and looks for all Declined applications that
# have not had a letter sent to them already.  It gets
# the information required for the letter, formats the
# data, and ftps it to the LAN.  Our mailing house (SMS)
# then picks up that data and produces the actual letter.
#
# A final reconciliation count file is also produced.
#
######################################################

use strict;			# Be good, lil program
use Net::FTP;			# Required to FTP to LAN
use DBI;			# Database Interface
use Getopt::Std;		# Process command line variables

# Global Variables

my %cmds;			# Command line options
my $params = "f:";		# Valid command line options
my %credit_details;		# Store standard credit details
my $residential_count = 0;	# Count of residential letters created
my $business_count = 0;		# Count of business letters created
my $run_path;			# Path for files to be stored in

#----------------------
# Main Processing
#----------------------

# Get the command line options

getopts($params, \%cmds);

if (defined $cmds{f})
{
    $run_path = $cmds{f};
}
else
{
    $run_path = "..";
}

# Connect to the database

my $dbh = dbconnect();

# Load up the standard details

getStandardDetails();

# Create the main file

# Have to tweak the date because perl does funny things
# with January equalling month 0 and stuff like that.

my $day = sprintf "%02d", (localtime)[3];
my $month = sprintf "%02d", (localtime)[4];
my $year = sprintf "%04d", (localtime)[5];

$month++;
$year += 1900;

my $current_date = $year . $month . $day;
my $current_date_other_format = $day . "/" . $month . "/" . $year;
my $filename_mainfile = $run_path . "/files/CRCHK_CFE_DEC" . $current_date;
my $filename_checkfile = $run_path . "/files/CRCHK_CFE_DECREC" . $current_date;

open (OUTPUT, ">$filename_mainfile") or die "Error opening $filename_mainfile : $!\n";

# Work through Chubby and process all declined applications
# that haven't had a letter sent to them.

my $sql =	"select	 ca_header.ca_id
			,ca_header.application_id
			,nvl(addr.addr_line1, ' ')
			,nvl(addr.addr_line2, ' ')
			,nvl(addr.suburb, ' ')
			,addr.state
			,addr.postcode
		 from	 ca_header
			,addr
			,ca_status
		 where	 ca_header.bill_addr_id = addr.addr_id
		 and	 ca_header.ca_status_id = ca_status.ca_status_id
		 and	 ca_header.ca_status_id = ca_status.ca_status_id
		 and	 ca_header.customer_notified_date is null
		 and	 ca_status.ca_status_name = 'DECLINE'";

my $sth = $dbh->prepare($sql);
$sth->execute();

my @appl_details;
while (@appl_details = $sth->fetchrow_array)
{
    createLetter(\@appl_details);
}

# Create the check file

close OUTPUT or die "Error closing $filename_mainfile : $!\n";    

open (CHECK, ">$filename_checkfile") or die "Error opening $filename_checkfile : $!\n";
printf CHECK "%6d%3s  %05d\n", $current_date, "DA1", $residential_count;
printf CHECK "%6d%3s  %05d\n", $current_date, "DA2", $business_count;
close CHECK or die "Error closing $filename_checkfile : $!\n";    

# FTP the files to the LAN

ftpFiles($filename_mainfile, $filename_checkfile);

# And finish up

$dbh->commit;
$dbh->disconnect();
my $total_count = $residential_count + $business_count;
print "Program finished successfully - $total_count records processed\n";

#-----------------------------
# Subroutines
#-----------------------------
# createLetter - Create the declined letter
#
# Parameters:  Reference to header/address details
#
# Returns:     None

sub createLetter
{
    my $appl_details = shift;
    my $ca_id = $appl_details->[0];
    my $first_name;
    my $last_name;
    my $letter_type;
    my $business_name;
    my $title;

# Work out if the customer is business or residential, and
# process accordingly

    my $cust_segment = getSegment($ca_id);

    if ($cust_segment eq "R")
    {
    # Residential customer

	($first_name, $last_name, $title) = getResidentialDetails($ca_id);
	$letter_type = "DA1";
	$residential_count++;
	$business_name = " ";
    }
    else
    {
    # Business customer

	$first_name = " ";
	($last_name, $business_name) = getBusinessDetails($ca_id);
	$letter_type = "DA2";
	$business_count++;
	$title = " ";
    }

# Populate the type 10 record

    my @print_output;
    push (@print_output, "10");
    push (@print_output, $title);
    push (@print_output, $first_name);
    push (@print_output, $last_name);
    push (@print_output, $appl_details->[2]);
    push (@print_output, $appl_details->[3]);
    push (@print_output, $appl_details->[4]);
    push (@print_output, $appl_details->[5]);
    push (@print_output, $appl_details->[6]);
    push (@print_output, $appl_details->[1]);
    push (@print_output, $current_date_other_format);
    push (@print_output, $credit_details{"CREDIT_CONTACT_NBR"});
    push (@print_output, $letter_type);
    push (@print_output, " ");
    push (@print_output, 0);
    push (@print_output, " ");
    push (@print_output, "NNNNNN");

# Now print it out

    printf OUTPUT "%2s%-4s%-20s%-40s%-45s%-45s%-25s%-3s%-4s%-11s%-10s%-13s%-5s%-8s%011d%-15s%6s\n", @print_output
	or die "Error writing to $filename_mainfile : $!\n";

# Create the type 60 record

    @print_output = ();
    push (@print_output, "60");
    push (@print_output, $business_name);
    push (@print_output, $credit_details{"CREDIT_CONTACT_NAME"});
    push (@print_output, $credit_details{"CREDIT_CONTACT_TITLE"});
    push (@print_output, $credit_details{"CREDIT_BUREAU_CONTACT_NAME"});
    push (@print_output, $credit_details{"CREDIT_BUREAU_CONTACT_WEBSITE"});
    push (@print_output, $credit_details{"CREDIT_BUREAU_CONTACT_NBR"});
    push (@print_output, " ");

# And print it out

    printf OUTPUT "%2s%-40s%-45s%-30s%-40s%-45s%-13s%50s\n", @print_output
	or die "Error writing to $filename_mainfile : $!\n";
    
# Update database to say the letter has been created.
# In the event of a program crash during execution, AutoCommit
# has been turned off, so it will roll back.  We force a commit
# as one of the last tasks in this program.

    my $sql = 	"update	 ca_header
		 set	 customer_notified_date = sysdate
		 where	 ca_id = ?";
    
    my $sth = $dbh->prepare($sql);
    $sth->execute($ca_id);
}
# dbconnect - Connect to the database
#
# Parameters:  None
#
# Returns:     Database handle

sub dbconnect
{
# First get the database config details

    my %db_details;
    my $config_filename = $run_path . "/files/dbase_config.file";
    open (CFGFILE, $config_filename) or die "Error opening $config_filename $!\n";

    while (<CFGFILE>)
    {
	chomp;
	if ((/^\#/) or (/^ /))
	{
	    next;
	}

	my @sp = split ("=", $_);
	$db_details{$sp[0]} = $sp[1];
    }

    my $oracle		= $db_details{"ORACLEID"};
    my $sid		= $db_details{"SID"};
    my $userid		= $db_details{"USERID"};
    my $password 	= $db_details{"PASSWORD"};
    my $source 		= 'DBI:Oracle:host=' .
			    $oracle .
			    ';sid=' .
			    $sid;

    my $dbh = DBI->connect($source, $userid, $password, { RaiseError => 1, AutoCommit => 0});
    return $dbh;
}
# ftpFiles - ftp the output files
#
# Parameters:  File names
#
# Returns:     None

sub ftpFiles
{
# First we need to get the ftp details from the 
# appropriate file.

    my $mainfile = shift;
    my $checkfile = shift;
    
    my %ftp_details;
    my $ftp_config_filename = $run_path . "/files/ftp_config.file";
    open (FTPCFG, $ftp_config_filename) or die "Error opening $ftp_config_filename $!\n";

    while (<FTPCFG>)
    {
	chomp;
	if ((/^\#/) or (/^ /))
	{
	    next;
	}

	my @sp = split ("=", $_);
	$ftp_details{$sp[0]} = $sp[1];
    }
    
# Now connect to the server and send the files

    my $ftp = Net::FTP->new($ftp_details{"FTP_HOST_NAME"}) 
	or die "Error connecting to $ftp_details{'FTP_HOST_NAME'} : $@\n";
    $ftp->login($ftp_details{"USERNAME"},$ftp_details{"PASSWORD"})
	or die "Error logging onto ftp server : $ftp->message\n";
    $ftp->cwd($ftp_details{"DIRECTORY"})
	or die "Error moving to directory $ftp_details{'DIRECTORY'} : $ftp->message\n";
    
    $ftp->put($mainfile)
	or die "Error ftping $mainfile : $ftp->message\n";
    $ftp->put($checkfile)
	or die "Error ftping $checkfile : $ftp->message\n";

# And quit out to be nice

    $ftp->quit()
	or die "Error logging out of ftp server : $ftp->message\n";

    return;
}
# getBusinessDetails - Get the business customer's details
#
# Parameters:  Application ID
#
# Returns:     Business Name, Contact Name

sub getBusinessDetails
{
    my $ca_id = shift;

    my $sql =	"select	 contact_name
			,business_name
		 from	 ca_business
		 where 	 ca_id = ?";

    my $sth = $dbh->prepare($sql);
    $sth->execute($ca_id);
    my @busi_details = $sth->fetchrow_array();

    return @busi_details;
}
# getResidentialDetails - Get the residential customer's details
#
# Parameters:  Application ID
#
# Returns:     First Name, Last Name, Title

sub getResidentialDetails
{
    my $ca_id = shift;

    my $sql =	"select	 first_name
			,last_name
			,cust_title_short_name
		 from	 ca_residential
			,cust_title
		 where 	 ca_id = ?
		 and	 ca_residential.cust_title_id = cust_title.cust_title_id";
    
    my $sth = $dbh->prepare($sql);
    $sth->execute($ca_id);
    my @resi_details = $sth->fetchrow_array();
    
    return @resi_details;
}
# getSegment - Get the customer's segment
#
# Parameters:  Application ID
#
# Returns:     Segment Value

sub getSegment
{
    my $ca_id = shift;

    my $sql =	"select	 cust_type
		 from	 ca_header
			,cust_segment
		 where 	 ca_header.ca_id = ?
		 and	 ca_header.cust_segment_id = cust_segment.cust_segment_id";
   
    my $sth = $dbh->prepare($sql);
    $sth->execute($ca_id);
    my $cust_segment = $sth->fetchrow_array();

    return $cust_segment;
}
# getStandardDetails - Get the standard parameter details
#
# Parameters:  None
#
# Returns:     None

sub getStandardDetails
{
# There are 6 parameters that need to be read from the
# GT_CONFIG_PARAMETER table.  These get read in and stored
# in a hash.  Use a loop to read them to cut down on the
# amount of SQL we use.

    $credit_details{"CREDIT_CONTACT_NAME"} = "";
    $credit_details{"CREDIT_CONTACT_TITLE"} = "";
    $credit_details{"CREDIT_CONTACT_NBR"} = "";
    $credit_details{"CREDIT_BUREAU_CONTACT_NAME"} = "";
    $credit_details{"CREDIT_BUREAU_CONTACT_WEBSITE"} = "";
    $credit_details{"CREDIT_BUREAU_CONTACT_NBR"} = "";

    my $sql =	"select	 value
		 from	 gt_config_parameter
		 where 	 name = ?";

    my $sth = $dbh->prepare($sql);

    foreach (keys %credit_details)
    {
	$sth->execute($_);
	$credit_details{$_} = $sth->fetchrow_array();
    }
}
