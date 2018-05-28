#!/pkgs/bin/perl
######################################################
# monitor-oneoffice.pl - Monitor the list of customers
# who are flagged as being eligible for InfoVista 
# extract/reporting - check if any of these have One 
# Office services, and raise an error if they do.
# 
# Customers can only have InfoVista or One Office, not
# both.
#
# Created:      April 10, 2006
# Author:       Bart Masters
#
######################################################

use strict;		# Be good, lil program
use DBI;		# Database connection module
use Getopt::Std;	# Process command line options

# Global Variables

my $params = "f:";
my %cmds;
my $run_path;
my @poller_list = qw(glb hay);

#----------------------
# Main Processing
#----------------------

# Get command line options

getopts($params, \%cmds);

if (defined $cmds{f})
{
    $run_path = $cmds{f}
}
else
{
    $run_path = "..";
}

# Get email details

my $support_mail_filename = $run_path . "/files/support_email_addr";
open (SUPPORTFILE, "$support_mail_filename") or die "Error opening $support_mail_filename $!\n";

while (<SUPPORTFILE>)
{
    chomp;
    my $first_char = substr($_, 0, 1);
    if (($first_char eq "#") ||
	($first_char eq " ") ||
	($first_char eq ""))
    {
	next;
    }
    else
    {
	push (@support_mail_addr, $_);
    }
}
close (SUPPORTFILE);

# Connect to the database

my $dbh = dbconnect();

# Open the customer files, and work through them.

my $poller;
foreach $poller (@poller_list)
{
    my $filename =  $run_path . "/files/${poller}_customer.file";
    open (CUSTFILE, "$filename") or die "Error opening $filename $!\n";
    
    while <CUSTFILE>
    {
	# Check if a customer has a One Office service group.  If they do, sqwak.
	my $customer_id = $_;
	my $sql = "select count(*)
		   from	  customer_projects
		   where  cusp_mktp_product_type like 'ONE OFFICE%'
		   and    cusp_creq_csrfno = $customer_id";

	my @count = $dbh->selectrow_array($sql);
	
	if ($count[0] > 0)
	{
	    mailSupport($customer_id);
	}
    }

    close (CUSTFILE);
}

exit 0;

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
# First get the database config details

    my %db_details;
    my $config_filename = $run_path . "/files/dbase_config.file";
    open (CFGFILE, "$config_filename") or die "Error opening $config_filename $!\n";

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

    my $dbh = DBI->connect ($source, $userid, $password, { RaiseError => 1, AutoCommit => 0}) ||
	die "Error connecting to $oracle: $DBI::errstr\n";

    return $dbh;
}
# mailSupport	Mail Apps Support if customer needs to be modified
#
# Parameters:	Customer ID
#
# Returns:	None

sub mailSupport
{
    my $customer_id = shift;
    my $supportmailaddr = join (",", @support_mail_addr);

    my $mail = Mail::Mailer->new("sendmail") or die "Error trying to create mail: $!\n";
    $mail->open({
	    "From"	=> "IV/One Office Monitor",
	    "To"	=> $supportmailaddr,
	    "Subject"	=> "A customer has both Infovista and One Office - thats a no no"
	    })
		or die "Couldn't create mail: $!\n";

    my $error_string = "$customer_id is both on the list of customers who have Infovista reports, and they have at
    least one Service Group which has a One Office product (ie their Mkt Product field in the Service Group page
    contains ONE OFFICE of some form).  This shouldn't happen - customers can only have one or the other.\n";
		
    print $mail $error_string;
    $mail->close();
}
