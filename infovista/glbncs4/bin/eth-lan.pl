#!/pkgs/bin/perl

######################################################
# eth-lan.pl - Extract config data to load a Metro
# Ethernet Lan switch Service Order into InfoVista.
#
# Created:      December 19, 2002
# Author:       Bart Masters
# Version:      1.0
#
# This program is used to load config data from BIOSS
# into InfoVista.  It is called with a Service Order 
# ID, and it will scan through the circuits table for 
# the LAN or MAN switch that belong to that SO.
#
# If the circuit is missing some data, it will be
# listed in an error report for chasing up.
#
# Version History
# ---------------
# 0.1	Initial Release
#
######################################################

use strict;		# Be good, lil program
use DBI;		# Database connection module
use Getopt::Std;	# Process command line options

# Global Variables

my %cmds;		# Command line options
my $params = "f:p:e:";	# Valid command line options
my $sero_id;		# Service Order to process
my $sero_cirt_name;	# Service Order name
my $cusr_name;		# Customer name
my $cusr_abbr;		# Customer's BIOSS abbreviation
my $serv_type = "ETHERNET";	# Type of service
my $report_lvl;		# Overall reporting level
my $switch_type;	# Type of switch (LAN or MAN)
my $equp_locn_ttname;	# Switch location
my $equp_ipaddress;	# Switch IP address
my $port_name;		# Port's name
my $domain;		# Switch domain
my $serv_group;		# Service group to be displayed under
my $port_speed;		# Port max speed
my $snmprd = "InfoVista";	# SNMP Read string
my $bit_flag;		# 32 or 64 bit processing flag
my @sql_read;		# Variable for SQL reads
my $run_path;
my $poller;
my $alarm_port_no;
my $alarm_card_no;
my $alarm_switch;
my $switch_index;
my $slocn;
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
    $end_file_name = "../files/ethlan.end." . $poller;
}

# Connect to the database

my $dbh = dbconnect();
	
# Get the list of product types

my $filename = $run_path . "/files/ethlan-prod-type.file";
open (PRODFILE, "$filename") or die "Error opening $filename $!\n";
chomp (my @prod_type = <PRODFILE>);
close PRODFILE;
my $prod_list = join (',', map {"?"} @prod_type);

# Get the list of customers to process

$filename = $run_path . "/files/${poller}_customer.file";
open (CUSTFILE, "$filename") or die "Error opening $filename $!\n";
chomp (my @custname = <CUSTFILE>);
close CUSTFILE;
my $cusr_list = join (',', map {"?"} @custname);
  
# Work through the list of customers/products

my $sql =	"select	 sero_id
			,sero_cirt_name	
		from	 service_orders
	 		,circuits
		 where	 sero_sert_abbreviation in ($prod_list)
		 and	 sero_stas_abbreviation in ('APPROVED','CLOSED')
		 and	 sero_cirt_name = cirt_name
		 and	 cirt_status = 'INSERVICE'
		 and	 sero_cusr_abbreviation in ($cusr_list)
		 order by sero_cirt_name asc, 
			  sero_id desc";

my $sth = $dbh->prepare($sql);
$sth->execute(@prod_type, @custname);

my @cust_info;
while (@cust_info = $sth->fetchrow_array)
{
    $sero_id = $cust_info[0];
    $sero_cirt_name = $cust_info[1];
    my $rc = extractSwitch();
}

# Finish up by disconnecting and creating the file to say so.

$dbh->disconnect();

my $command = "touch $end_file_name";
my $rc = system("$command");

#-----------------------------
# Subroutines
#-----------------------------
# currdate - Get the current date and massage it into a nice
# format for creating the output files.
#
# Parameters:	None
#
# Returns:	Current Date

sub currdate
{
    my ($m, $d, $h, $mi, $se) = (localtime)[4,3,2,1,0];
    $m += 1;

    my $date = sprintf("%02d%02d%02d%02d%02d", $d, $m, $h, $mi, $se);

    return $date;
}
# customerDomain - Work out the domain the report
# has to be placed under.
#
# Parameters:	Circuit
#
# Returns:	Domain, Service Group

sub customerDomain
{
# Service group determination is different from other report types
# Metro Ethernet reports use the location types from the circuit
# name to work out where to put the report.  Reports are to be 
# located at the customer location, not the location of the switch.

    my $circuit = shift;

    my @cirt_split = split (" ", $circuit);
    my $aend = $cirt_split[0];
    my $bend = $cirt_split[2];
    
    $sql =	"select	 locn_state
			,locn_loct_abbreviation
		 from	 locations
		 where	 locn_ttname = ?";

    my $sth = $dbh->prepare($sql);
    $sth->execute($aend);
    my $aend_details = $sth->fetchrow_arrayref;
    
    my $sth2 = $dbh->prepare($sql);
    $sth2->execute($bend);
    my $bend_details = $sth2->fetchrow_arrayref;

    my $agg_count  = 0;
    my $co_count   = 0;
    my $cust_count = 0;
    my $pop_count  = 0;

# First see how many of each type of site we have in the
# circuit.

    if ($aend_details->[1] eq "AAPT AGG SITE")
    {
	$agg_count++;
    }
    if ($bend_details->[1] eq "AAPT AGG SITE")
    {
	$agg_count++;
    }
    if ($aend_details->[1] eq "AAPT CO SITE")
    {
	$co_count++;
    }
    if ($bend_details->[1] eq "AAPT CO SITE")
    {
	$co_count++;
    }
    if ($aend_details->[1] eq "AAPT POP SITE")
    {
	$pop_count++;
    }
    if ($bend_details->[1] eq "AAPT POP SITE")
    {
	$pop_count++;
    }
    if ($aend_details->[1] eq "CUSTOMER SITE")
    {
	$cust_count++;
    }
    if ($bend_details->[1] eq "CUSTOMER SITE")
    {
	$cust_count++;
    }

# If we have any customer locations, put the report
# under them.
# If we have 2 customer locations, put the report under
# both of them.  !! is used as a delimiter between the
# two locations, report.pl will split them up.

    if ($cust_count == 1)
    {
	if ($aend_details->[1] eq "CUSTOMER SITE")
	{
	    $domain = $aend_details->[0];
	    $serv_group = $aend;
	}
	else
	{
	    $domain = $bend_details->[0];
	    $serv_group = $bend;
	}
    }
    elsif ($cust_count == 2)
    {
	$domain = $aend_details->[0] . "!!" . $bend_details->[0];
	$serv_group = $aend . "!!" . $bend;
    }

# If we don't have any customer locations, have to 
# place them under the appropriate AAPT location.

# If we have 1 CO Site, put the report under the
# other end.

    elsif ($co_count == 1)
    {
	if ($aend_details->[1] eq "AAPT CO SITE")
	{
	    $domain = $bend_details->[0];
	    $serv_group = $bend;
	}
	else
	{
	    $domain = $aend_details->[0];
	    $serv_group = $aend;
	}
    }

# If 2 CO Sites, put it under both.

    elsif ($co_count == 2)
    {
	$domain = $aend_details->[0] . "!!" . $bend_details->[0];
	$serv_group = $aend . "!!" . $bend;
    }

# If 0 CO sites, continue checking through AGG and
# POP sites, using the same logic.

    elsif ($agg_count == 1)
    {
	if ($aend_details->[1] eq "AAPT AGG SITE")
	{
	    $domain = $bend_details->[0];
	    $serv_group = $bend;
	}
	else
	{
	    $domain = $aend_details->[0];
	    $serv_group = $aend;
	}
    }
    elsif ($agg_count == 2)
    {
	$domain = $aend_details->[0] . "!!" . $bend_details->[0];
	$serv_group = $aend . "!!" . $bend;
    }
    
    elsif ($pop_count == 1)
    {
	if ($aend_details->[1] eq "AAPT POP SITE")
	{
	    $domain = $bend_details->[0];
	    $serv_group = $bend;
	}
	else
	{
	    $domain = $aend_details->[0];
	    $serv_group = $aend;
	}
    }
    else
    {
	$domain = $aend_details->[0] . "!!" . $bend_details->[0];
	$serv_group = $aend . "!!" . $bend;
    }
    
    return ($domain, $serv_group);
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

    my $dbh = DBI->connect($source, $userid, $password, {RaiseError => 1, AutoCommit => 0});
    return $dbh;
}
# extractSwitch - Extract all the details for a
# particular Switch.
#
# Parameters:	Circuit Name
#		Service Order ID
#		Service Order Type
#
# Returns:	Return Code

sub extractSwitch
{
# Get the various data required

    ($cusr_name, $cusr_abbr) = getCustName($sero_id);
    $report_lvl = getReportLvl($sero_id);

# Now find the Switch in the circuit

    my $rc = getSwitch();

# If getSwitch returns an error - produce error message - we can't load it
# into Infovista.

    if ($rc != 0)
    {
	printError($rc);
	return $rc;
    }
    else
    {
	printGood();
	return 0;
    }
}
# getCustName - Get the Customer Name/ID.
#
# Parameters:	Service Order ID
#
# Returns:	Customer Name, Customer ID

sub getCustName
{
    my $sero_id = shift;
    my $sql = 	"select	 cusr_name,
			 cusr_abbreviation
		 from 	 service_orders
	 		,customer
		 where 	 sero_id = '$sero_id'
		 and	 cusr_abbreviation = sero_cusr_abbreviation";

    my @result = $dbh->selectrow_array($sql);

    if (defined $result[0])
    {
	my $cusr_name = $result[0];
	my $cusr_abbreviation = $result[1];
	$cusr_name =~ s/,/ /g;
	$cusr_name =~ s/\(/ /g;
	$cusr_name =~ s/\)/ /g;
	$cusr_name =~ s/\s+$//;
	return $cusr_name, $cusr_abbreviation;
    }
    else
    {
	return;
    }
}
# getReportLvl - Get the Reporting Level
#
# Parameters:	Service Order ID
#
# Returns:	Reporting Level

sub getReportLvl
{
    my $sero_id = shift;
    my $sql = 	"select	 conp_cont_abbreviation
		 from 	 service_orders
	 		,contact_points
		 where 	 sero_id = '$sero_id'
		 and	 conp_cusr_abbreviation = sero_cusr_abbreviation
		 and	 conp_cont_abbreviation like 'CRPTLVL%'";

    my $report_lvl = $dbh->selectrow_array($sql);
    
    if (defined $report_lvl)
    {
	$report_lvl =~ s/CRPTLVL_//;
	$report_lvl = uc($report_lvl);
    }
    else
    {
	$report_lvl = " ";
    }

    if ($report_lvl eq "SILVER")
    {
	$report_lvl = "1";
    }
    elsif ($report_lvl eq "GOLD")
    {
	$report_lvl = "2";
    }
    elsif ($report_lvl eq "PLAT")
    {
	$report_lvl = "3";
    }
    else
    {
	$report_lvl = "0";
    }
    return $report_lvl;
}
# getSwitch - Get the details of a switch.
#
# Parameters:	Circuit Name
#
# Returns:	None

sub getSwitch
{
    my $sql =	"select	 equp_locn_ttname
			,equp_ipaddress
			,port_card_slot
			,port_name
			,equp_equt_abbreviation
			,equp_index
		 from	 equipment
			,ports
		 where 	 port_cirt_name = '$sero_cirt_name'
		 and	 port_status = 'INSERVICE'
		 and	 port_equp_id = equp_id
		 and	 equp_equt_abbreviation in ('LANSW', 'MANSW')";
    my $switch_dets = $dbh->selectall_arrayref($sql);
    my @switch_count;

    foreach (@{$switch_dets})
    {
	push(@switch_count, $_->[0]);
    }

# Check how many switches we have.  If its not 1, we
# have an error.
    
    if (@switch_count != 1)
    {
	return 108;
    }

    $equp_locn_ttname = $switch_dets->[0]->[0];
    $equp_ipaddress = $switch_dets->[0]->[1];
    my $card_no = $switch_dets->[0]->[2];
    my $port_no = $switch_dets->[0]->[3];
    $switch_type = $switch_dets->[0]->[4];
    $switch_index = $switch_dets->[0]->[5];
    
    $alarm_switch = $equp_locn_ttname . " " . $switch_type . " " . $switch_index;
    $alarm_port_no = $port_no;
    $port_no =~ /^(.+)\-LN(\d+)$/;
    
    $alarm_card_no = $card_no;
    my $card_type = $1;
    $port_no = $2;
    
    $card_no =~ s/^0*//;
    $port_no =~ s/^0*//;
    
    if ($card_no eq "NA")
    {
	if ($card_type eq "1GE")
	{
	    $card_no = "Gi0";
	}
	else
	{
	    $card_no = "Fa0";
	}
    }

    $port_name = $card_no . "/" . $port_no;

    ($domain, $serv_group) = customerDomain($sero_cirt_name);
    
    if ($serv_group eq "Error")
    {
	return $domain;
    }

# Finally get the max speed from the service order

    $sql =	"select	 cirt_sped_abbreviation
		 from	 circuits
		 where	 cirt_name = '$sero_cirt_name'";
		 
    my $cirt_sped_abbreviation = $dbh->selectrow_array($sql);

# We have to check it, since its a freeform field

    $cirt_sped_abbreviation =~ /^(\d+)(\w+)$/;
    my $bad_speed;
    
    if ((defined ($1)) and
	(defined($2)))
    {
	$bad_speed = "yes";
    }

    unless (defined ($2))
    {
	$bad_speed = "yes";
    }

    if (($2 eq "G") or
	($2 eq "GE") or 
	($2 eq "K") or
	($2 eq "M"))
    {
	$bad_speed = "no";
    }
    else
    {
	$bad_speed = "yes";
    }

    if ($bad_speed eq "yes")
    {
	return 109;
    }
    else
    {
	$port_speed = $1;
	if (($2 eq "G") or
	    ($2 eq "GE"))
	{
	    $port_speed = $port_speed * 1000;
	}
	elsif ($2 eq "K")
	{
	    $port_speed = $port_speed / 1000;
	}
    }

# Set bit flag to 1 (64-bit processing).  Gigabit ethernet
# switches need all 64 bits to process throughput.

    $bit_flag = "1";

    return 0;
}
# printError - Print an error.
#
# Parameters:	Error #, Circuit Name
#
# Returns:	None

sub printError
{
    my $error_nbr = shift;
    my $cirt_name = shift;
    my $reason;
	
    if ($error_nbr == 105)
    {
	$reason = "could not find a valid Customer site in the circuit";
    }
    elsif ($error_nbr == 108)
    {
	$reason = "could not find an eligible LAN or MAN switch";
    }
    elsif ($error_nbr == 109)
    {
	$reason = "the Circuit Speed is an invalid value";
    }
    else
    {
	$reason = "unknown error code - $error_nbr - contact InfoVista support";
    }
    
    my $error_filename = $run_path . '/files/serv-' . $poller . '-' . $sero_id . '.ethlan.error';
    open (ERRORFILE, ">$error_filename") or
	die "Error opening file $error_filename - $!\n";
    print ERRORFILE "Error $error_nbr for $cusr_abbr, circuit $cirt_name - $reason\n";
    
    close ERRORFILE or
	die "Error closing $filename - $!\n";
}
# printGood - Print a Switch when its good.
#
# Parameters:	None
#
# Returns:	None

sub printGood
{
    my $filename =  $run_path . '/files/serv-'. $poller . '-' . $sero_id . '.ethlan.ready';
    open (TOPFILE, ">$filename") or
	die "Error opening file $filename - $!\n";
    print TOPFILE "LAN_SW;$sero_cirt_name;$cusr_name;$cusr_abbr;$domain;$serv_group;$serv_type;$switch_type;$equp_ipaddress;$snmprd;$port_speed;$port_name;$bit_flag;$alarm_switch;$alarm_card_no;$alarm_port_no;$report_lvl\n";

    close TOPFILE or
	die "Error closing $filename - $!\n";
}	
