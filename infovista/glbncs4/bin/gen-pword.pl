#!/pkgs/bin/perl
######################################################
# gen-pword.pl - Generate InfoVista Password
#
# Created:      February 19, 2002
# Author:       Bart Masters
# Version:      1.1
#
# This program will produce InfoVista userids and passwords
# for a particular service order, which is passed in as a 
# command line parameter.
#
# It will check their customer/domain and service order
# levels, and if there is no password for the levels,
# will produce one, and store it within the comment fields
# at the customer level.
######################################################

use strict;		# Be good, lil program
use DBI;		# Database connection module
use Getopt::Std;	# Process command line options

# Global Variables

my $params = "p:f:e:";	# Valid command line options
my %cmds;		# Command line options
my $run_path;
my $poller;
my $end_file_name;

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

if (defined $cmds{p})
{
    $poller = $cmds{p};
}
else
{
    $poller = "glb";
}

if (defined $cmds{e})
{
    $end_file_name = $cmds{e};
}
else
{
    $end_file_name = "../files/gen-pword.end." . $poller;
}

# Seed the random number generator

srand(time ^ $$ ^ unpack "%32L*", `ps -elaf | /pkgs/bin/gzip`);

# Connect to the database

my $dbh = dbconnect();

# Get the list of valid product types

my $filename = $run_path . "/files/pvc-prod-type.file";
open (PRODFILE, "$filename") or die "Error opening $filename $!\n";
chomp (my @prod_type = <PRODFILE>);
close PRODFILE;

$filename = $run_path . "/files/gold-prod-type.file";
open (PRODFILE, "$filename") or die "Error opening $filename $!\n";
while (<PRODFILE>)
{
    chomp;
    push (@prod_type, $_);
}
close PRODFILE;

$filename = $run_path . "/files/ethlan-prod-type.file";
open (PRODFILE, "$filename") or die "Error opening $filename $!\n";
while (<PRODFILE>)
{
    chomp;
    push (@prod_type, $_);
}
close PRODFILE;

$filename = $run_path . "/files/ipvpn-prod-type.file";
open (PRODFILE, "$filename") or die "Error opening $filename $!\n";
while (<PRODFILE>)
{
    chomp;
    push (@prod_type, $_);
}
close PRODFILE;

my $prod_list = join (',', map {"?"} @prod_type);

# Get the customer list

$filename = $run_path . "/files/${poller}_customer.file";
open (CUSTFILE, "$filename") or die "Error opening $filename $!\n";
chomp (my @custname = <CUSTFILE>);
close CUSTFILE;
my $cusr_list = join (',', map {"?"} @custname);

# Work through the list of products/customers

my $sql =	"select  cusr_abbreviation
			,cusr_mega_identifier
			,sero_locn_id_aend
			,sero_locn_id_bend
		 from	 service_orders
	 		,customer
		 where	 sero_sert_abbreviation in ($prod_list)
		 and	 sero_stas_abbreviation in ('APPROVED','CLOSED')
		 and	 sero_cusr_abbreviation = cusr_abbreviation
		 and	 sero_cusr_abbreviation in ($cusr_list)
		 and	 sero_ordt_type = 'CREATE'";

my $sth = $dbh->prepare($sql);
$sth->execute(@prod_type, @custname);

my @cusr_details;
while (@cusr_details = $sth->fetchrow_array)
{
# Process the customer

    processCustomer(\@cusr_details);
}

# Finish up by disconnecting and creating the file to say so.

$dbh->disconnect();

my $command = "touch $end_file_name";
my $rc = system("$command");

#-----------------------------
# Subroutines
#-----------------------------

# checkDomain - Check if a domain has a userid, and 
# create one if it doesn't.
#
# Parameters:	Customer ID, Region ID, Mega ID
#
# Returns:	Domain ID

sub checkDomain
{
    my $cusr_abbr = shift;
    my $region_id = shift;
    my $megaid = shift;
	
    my $sql =	"select	 conp_number
		 from 	 contact_points
		 where	 conp_cusr_abbreviation = '$cusr_abbr'
		 and	 conp_cont_abbreviation = 'DOMAIN_REPORT'
		 and	 conp_usage = '$region_id'";
    my $userid = $dbh->selectrow_array($sql);
    my $domain_id;

# If nothing exists, create a userid and password for the domain.
    if (defined $userid)
    {
	$userid =~ /^User Name = (\d+-\d+)/;
	$domain_id = $1;
    }
    else
    {
    	$domain_id = createDomain($cusr_abbr, $megaid, $region_id);
    }
return $domain_id;
}
# checkServGroup - Check if a service group has a userid,
# and create one if it doesn't.
#
# Parameters:	Customer Abbr, Location Name,
#		Domain ID
#
# Returns:	None

sub checkServGroup
{
    my $cusr_abbr = shift;
    my $locn_name = shift;
    my $domain_id = shift;

# Inspect $locn_name, and if you find an apostraphe, make it
# two apostraphes, else Oracle gets confused.
# This is to cover for places like O'Briens beach.

    $locn_name =~ s/'/''/;

    my $sql =	"select	 conp_number
		 from 	 contact_points
		 where	 conp_cusr_abbreviation = '$cusr_abbr'
		 and	 conp_cont_abbreviation = 'SERVGRP_REPORT'
		 and	 conp_usage = '$locn_name'";
    my $contact_id = $dbh->selectrow_array($sql);

# If nothing exists, create a userid and password for the service
# group.
	
    unless (defined $contact_id)
    {
    	createServGroup($cusr_abbr, $locn_name, $domain_id);
    }
}
# createCustUser - Create a userid for the customer.
#
# Parameters:	Customer ID, Customer Mega ID
#
# Returns:	None

sub createCustUser
{
# Call the password function, to get a password.

    my $cusr_abbr = shift;
    my $megaid = shift;

    my $pword = genPassword();
	
# Insert the userid/password into the contacts table

    my $userid = "User Name = " . $megaid . " Password = " . $pword;
    insertTable($cusr_abbr, 'CUST_REPORT', $userid, '0', 'MASTER');	
}
# createDomain - Create a userid/password for
# the domain.
#
# Parameters:	Customer ID, Customer Mega ID
#
# Returns:	None

sub createDomain
{
# Get the greatest domain reporting number for that customer, and 
# add 1 to it.

    my $cusr_abbr = shift;
    my $megaid = shift;
    my $region_id = shift;

    my $sql =	"select	 max(to_number(conp_hours))
    		 from 	 contact_points
		 where	 conp_cusr_abbreviation = '$cusr_abbr'
		 and	 conp_cont_abbreviation = 'DOMAIN_REPORT'";
    my $conp_hours = $dbh->selectrow_array($sql);
    my $conp_index;

    if (defined $conp_hours)
    {
	$conp_index = $conp_hours;
	$conp_index++;
    }
    else
    {
	$conp_index = 1;
    }

# Call the password function, to get a password.
    my $domain_id = $megaid . "-" . $conp_index;
    my $pword = genPassword();
	
# Insert the userid/password into the contacts table

    my $userid = "User Name = " . $domain_id . " Password = " . $pword;
    insertTable($cusr_abbr, 'DOMAIN_REPORT', $userid, $conp_index, $region_id);

    return $domain_id;
}
# createServGroup - Create a userid/password for
# the service group. 
#
# Parameters:	Customer ID, Location Name,
#		Domain ID
#
# Returns:	None

sub createServGroup
{
    my $cusr_abbr = shift;
    my $locn_name = shift;
    my $domain_id = shift;
    my $domain_userid = "User Name = $domain_id";
	
    my $sql =	"select	 max(to_number(conp_hours))
    		 from 	 contact_points
		 where	 conp_cusr_abbreviation = '$cusr_abbr'
		 and	 conp_cont_abbreviation = 'SERVGRP_REPORT'
		 and	 conp_number like '$domain_userid%'";
     
    my $conp_hours = $dbh->selectrow_array($sql);
    my $conp_index;

    if (defined $conp_hours)
    {
	$conp_index = $conp_hours;
	$conp_index++;
    }
    else
    {
	$conp_index = 1;
    }

# Call the password function, to get a password.
    my $user = $domain_userid . "-" . $conp_index;
    my $pword = genPassword();
	
# Insert the userid/password into the contacts table

    my $userid = $user . " Password = " . $pword;
    insertTable($cusr_abbr, 'SERVGRP_REPORT', $userid, $conp_index, $locn_name);	
}
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

    my $dbh = DBI->connect ($source, $userid, $password, { RaiseError => 1, AutoCommit => 0});	
    return $dbh;
}
# genPassword - Generate a password.
#
# Parameters:	None	
#
# Returns:	Password

sub genPassword
{
    my @chars = ("a" .. "z",
		 "0" .. "9");

    my $password = join ("", @chars[map {rand @chars} (1 .. 8)]);
    return $password;
}
# getDomain - Get the domain and location of an end of
# the circuit.
#
# Parameters:	Location ID
#
# Returns:	Region, Location Name.

sub getDomain
{
    my $locn_id = shift;

    my $sql =	"select	 locn_ttregion
			,locn_ttname
		 from	 locations
		 where	 locn_id = '$locn_id'";

    my @result = $dbh->selectrow_array($sql);
    return @result[0,1];
}
# insertTable - Insert a row into the contacts table.
#
# Parameters:	Customer ID, type of contact, message,
# usage.
#
# Returns:	None

sub insertTable
{
    my $cusr_abbr = shift;
    my $contact_type = shift;
    my $insert_message = shift;
    my $conp_index = shift;
    my $usage = shift;

    my $sql =	"select  conp_id_seq.nextval
		 from	 dual"; 
    my $max_contact_id = $dbh->selectrow_array($sql);

    $sql = 	"insert
		 into 	 contact_points
		 values	('$max_contact_id'
	 		,NULL
			,'$cusr_abbr'
			,NULL
			,'$contact_type'
			,'$insert_message'
			,'$conp_index'
			,'$usage')";
			
    $dbh->do($sql);
}
# processCustomer - Produce any userids/passwords
# for the customer.  Check if a userid/pw has been
# produced for a particular level in the tree first.
#
# Parameters:	Customer ID, Customer Mega ID,
#		A End, B End
#
# Returns:	None

sub processCustomer
{
# Check if a userid/password already exists for the 
# customer.

    my $cust_ref = shift;
    my $cusr_abbr = $cust_ref->[0];
    my $megaid = $cust_ref->[1];
    my $aend = $cust_ref->[2];
    my $bend = $cust_ref->[3];
	
    my $sql = 	"select	 conp_id
		 from 	 contact_points
		 where	 conp_cusr_abbreviation = '$cusr_abbr'
		 and 	 conp_cont_abbreviation = 'CUST_REPORT'";
    my $contact_id = $dbh->selectrow_array($sql);

# If nothing exists, create a userid and password for the customer.

    unless (defined $contact_id)
    {
	createCustUser($cusr_abbr, $megaid);
    }

# Check if the domains need a userid.  First, get the regions
# of A end and B end.

    my ($aend_region, $aend_name) = getDomain($aend);
    my ($bend_region, $bend_name) = getDomain($bend);

# We don't do reporting on INTERNATIONAL ends of circuits, so there
# is no need to create passwords for them.

    unless ($aend_region eq 'INTERNATL')
    {
	my $a_domain_id = checkDomain($cusr_abbr, $aend_region, $megaid);

# Finally, check if the service groups need a userid.  If they do,
# create em.

	checkServGroup($cusr_abbr, $aend_name, $a_domain_id);
    }

    unless ($bend_region eq 'INTERNATL')
    {
        my $b_domain_id = checkDomain($cusr_abbr, $bend_region, $megaid);

# Finally, check if the service groups need a userid.  If they do,
# create em.
	
	checkServGroup($cusr_abbr, $bend_name, $b_domain_id);
    }
}
