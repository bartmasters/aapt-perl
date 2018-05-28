#!/pkgs/bin/perl
######################################################
# custrouter.pl - Extract config data to load a
# customer router and WAN Interface Service Order into 
# InfoVista
#
# Created:      January 10, 2003
# Author:       Bart Masters
#
# This program is used to load config data from BIOSS
# into InfoVista.  It is called with a Service Order 
# ID, and it will scan through the circuits table for 
# all Customer Edge Router (RTRCE) details that belong
# to that SO.
#
# Upon finding a router, it extracts the router's 
# details for loading into IV.  It will also extract
# all the interface details from a router and produce
# a WAN_IF entry for each interface
#
# If a PVC is missing some data, it will be listed in
# an error report for chasing up.
#
######################################################


use strict;		# Be good, lil program
use DBI;		# Database connection module
use Getopt::Std;	# Process command line options

use lib './';
use aapt_iv;

# Global Variables

my %cmds;		# Command line options
my $params = "p:f:e:";	# Valid command line options
my $sero_id;		# Service Order to process
my $cirt_name;		# Circuit name
my @routers;		# Routers for the circuit
my %cusr;		# Common customer details
my $poller;		# InfoVista poller to process
my $run_path;
my $router_addr;
my $report_lvl;
my $cusr_abbr;
my $rc;
my $proj_title;
my $snumber;
my @times;
my %error_desc;
my $end_file_name;
my %snmp;

$error_desc{"110"} = "Invalid number of RTRCEs in the circuit";
$error_desc{"113"} = "Invalid IP address on the RTRCE";
$error_desc{"114"} = "Access circuit has an invalid speed";
$error_desc{'115'} = 'Invalid circuit speed in F-CIRCUIT SPEED in Service Order Attributes';

#----------------------
# Main Processing
#----------------------

# Get the command line options

getopts($params, \%cmds);

if (exists $cmds{p})
{
    $poller = $cmds{p};
}
else
{
    $poller = "glb";
}

if (defined $cmds{f})
{
    $run_path = $cmds{f};
}
else
{
    $run_path = "..";
}

if (defined $cmds{e})
{
    $end_file_name = $cmds{e};
}
else
{
    $end_file_name = "../files/custrouter.end." . $poller;
}

# Connect to the database

my $dbh = dbconnect();
my $aapt_iv=aapt_iv->new($dbh,$poller,$run_path);

if(!$aapt_iv){
	die "Failed to locate main library aapt_iv";
}

# Get the list of product types

my $filename = $run_path . "/files/gold-prod-type.file";
open (PRODFILE, "$filename") or die "Error opening $filename $!\n";
chomp (my @prod_type = <PRODFILE>);
close PRODFILE;
my $prod_list = join (',', map {"?"} @prod_type);

# Get the list of customers to process

$filename = $run_path . "/files/${poller}_customer.file";
open (CUSTFILE, "$filename") or die "Error opening $filename $!\n";
chomp (my @custname = <CUSTFILE>);
close CUSTFILE;

# Load up all the SNMP Read strings into memory.  We do this
# because the table that contains them runs really slowly.

loadSNMP();

# Now get the details for each customer - this will affect
# what customers get processed

my %process_cusr_list;
foreach my $name (@custname)
{
    my ($cust_name,$report_lvl) = $aapt_iv->getCusr($name);

# We only produce reports for customers with gold or 
# better reporting level

    if (defined $report_lvl)
    {
	if ($report_lvl >= "2")
	{
	   $process_cusr_list{$name} = $report_lvl;
	}
    }
}

my $processed_customer;
foreach $processed_customer (keys (%process_cusr_list))
{
# Work through the list of customers/products

    my $sql =	"select	 sero_id
			,sero_cirt_name
			,sero_cusr_abbreviation
			,cusp_projecttitle
			,cusp_projectnumber
		 from	 service_orders
	 		,circuits
			,customer_projects
		 where	 sero_sert_abbreviation in ($prod_list)
		 and	 sero_stas_abbreviation in ('APPROVED','CLOSED')
		 and	 sero_cirt_name = cirt_name
		 and	 cirt_status = 'INSERVICE'
		 and	 sero_cusr_abbreviation = ?
		 and	 sero_cusp_projectid = cusp_projectid
		 order by sero_cirt_name asc, 
			  sero_id desc";

    my $sth = $dbh->prepare($sql);
    $sth->execute(@prod_type, $processed_customer);

# We shouldn't need a while loop here, we're only expecting 1 line - its just to 
# cover in case nothing gets returned for some reason.

    while (($sero_id, $cirt_name, $cusr_abbr, $proj_title, $snumber) = $sth->fetchrow_array)
    {
# Get the router details.
	my @routers = $aapt_iv->getRouters($cirt_name);

        if ($routers[0] == 110 )
	{
	    writeError(110);
	}
	else
	{

# Create Router, WAN IF and IP2IP details for each
# router.

	    my $router_ref;
	    foreach $router_ref (@routers)
	    {
		$rc = $aapt_iv->createRouter($router_ref,$cusr_abbr,$sero_id);
	
		unless ($rc)
		{
		    $aapt_iv->createWAN_IF($router_ref,$cirt_name,$sero_id,$cusr_abbr);
		}

		if ($rc)
		{
		    writeError($rc);
		}
#	    	createIP2IP($router_ref);

# If the customer has platinum reporting, create their
# LAN Port details.

		if ($process_cusr_list{$processed_customer} >= 3)
		{
		    createLAN($router_ref);
		}
	    }
	}
   } 
}
# Finish up by disconnecting and creating the file to say so.

$dbh->disconnect();

my $command = "touch $end_file_name";
$rc = system("$command");
exit 0;

#-----------------------------
# Subroutines
#-----------------------------
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

    my $dbh = DBI->connect($source, $userid, $password, { RaiseError => 1, AutoCommit => 0});
	close(CFGFILE);
    return $dbh;
}
# createIP2IP - Create an IP2IP instance.
#
# Parameters:	None
#
# Returns:	None

sub createIP2IP
{
# Create two IP2IP instances, one pinging from A
# end of circuit to B end, and vice versa.

    my $router_ref = shift;

    my @ip2ip;
    my $temp;
    my $ip2ipname;
    
    push (@ip2ip, "IP2IP");
    $temp = $router_ref->[0];
    if ($cirt_name =~ /$temp \- \w+/)
    {
	$ip2ipname = $cirt_name . " - ACE Latency";
    }
    else
    {
	$ip2ipname = $cirt_name . " - BCE Latency";
    }
	my ($cust_name,$report_lvl) = $aapt_iv->getCusr($cusr_abbr);

    push (@ip2ip, $ip2ipname);
    my $router_name = $router_ref->[0] . " RTRCE " . $router_ref->[1];
    push (@ip2ip, $router_name);
    push (@ip2ip, $cust_name);
    push (@ip2ip, $cusr_abbr);
    my $state = $aapt_iv->getState($router_ref->[0]);
    push (@ip2ip, $state);
    push (@ip2ip, $router_ref->[0]);
    push (@ip2ip, "LATENCY");
    $temp = $cust_name . "_LATENCY";
    push (@ip2ip, $temp);
    $temp = $temp . "_" . $state;
    push (@ip2ip, $temp);
    push (@ip2ip, "STANDARD");

# There needs to be some work to get other end IP Address
    push (@ip2ip, "1.2.3.4");
    push (@ip2ip, "");
    push (@ip2ip, $report_lvl);

# Tweak with the file name to get it in a nice format

    my $temp_ip2ipname = $ip2ipname;
    $temp_ip2ipname =~ s/\//\-/g;
    
    my $ip2ip_file_name =  $run_path . "/files/serv-" . $poller . "-" . $temp_ip2ipname . ".ip2ip.ready";
    $ip2ip_file_name =~ s/\(/ /g;
    $ip2ip_file_name =~ s/\)/ /g;
    $ip2ip_file_name =~ s/ /\-/g;

    open (IP2IP, ">$ip2ip_file_name") 
        or die "Error opening $ip2ip_file_name : $!\n";

    close (IP2IP)    
}
# createLAN - Create a LAN Port topology entry.
#
# Parameters:	Router Reference
#
# Returns:	None

sub createLAN
{
# Work through the active cards for a router.

    my $router_ref = shift;
    my $router_locn = $router_ref->[0];
    my $router_equp_id = $router_ref->[5];

    my $sql =	"select	 card_slot
		 from	 equipment
			,cards
		 where	 equp_id = ?
		 and	 card_equp_id = equp_id
		 and	 card_status = 'INSERVICE'";
     
    my $sth = $dbh->prepare($sql);
    $sth->execute($router_equp_id);
    my $card_refs = $sth->fetchall_arrayref();

    foreach my $cardref (@{$card_refs})
    {
	$sql =	"select	 port_name
			,port_cirt_name
		 from	 ports
		 where 	 port_equp_id = ?
		 and	 port_status = 'INSERVICE'
		 and	 port_card_slot = ?";

	my $sth = $dbh->prepare($sql);
	my $card_slot = $cardref->[0];
	$sth->execute($router_equp_id, "$card_slot");
	my $port_refs = $sth->fetchall_arrayref();
	
	foreach my $pref (@{$port_refs})
	{
	    my $port_name = $pref->[0];
	    my $alarm_port_name = $port_name;
	    my $alarm_card_slot = $card_slot;
	    my $parent_cirt_name = $pref->[1];
	    my @wanif;
	    my $if_name;
 	    #my $card_nbr = substr($card_slot, 1, 1);
		my $card_nbr = $card_slot;
	    my $use_if_descr = "1";

# Work out the interface name.  For now we only care about
# FastEthernet interfaces.

	    if ($port_name =~ /^FA\-LN(\d+)$/)
	    {
		my $port_nbr = $1;

# Remove any leading zeroes
		if($card_nbr =~ /^\d+$/){
			$card_nbr *= 10;
			$card_nbr /= 10;
		}
		
		$port_nbr *= 10;
		$port_nbr /= 10;

		if($card_nbr eq 'NA'){
			$if_name = "FastEthernet" . $port_nbr;
		}else{
			$if_name = "FastEthernet".$card_nbr."/".$port_nbr;
		}

		#if ($card_nbr == 0)
		#{
		#    $if_name = "FastEthernet" . $port_nbr;
		#}
		#else
		#{
# Yes, even though we have a card number, you have to name it
# FastEthernet0/whatever.  Don't ya love Cisco?
		#    $if_name = "FastEthernet0/" . $port_nbr;
		#}
	    }
	    else
	    {
# Non-FastEthernet ports we ignore.
		next;
	    }
	    
	    push (@wanif, "WAN_IF");
	    
	    $sql =	"select	 cirt_sped_abbreviation
				,sped_bitrate
			 from	 circuits
				,speeds
			 where 	 cirt_name = ?
			 and	 sped_abbreviation = cirt_sped_abbreviation";

	    $sth = $dbh->prepare($sql);
	    $sth->execute($parent_cirt_name);
	    my @cirt_speed = $sth->fetchrow_array();	    
	    my ($cust_name,$report_lvl) = $aapt_iv->getCusr($cusr_abbr);
 
	    my $router_name = $router_ref->[0] . " RTRCE " . $router_ref->[1];
	    my $wanif_name = $router_name . " " . $if_name;
	    push (@wanif, $wanif_name);
	    push (@wanif, $router_name);
	    push (@wanif, $cust_name);
	    push (@wanif, $cusr_abbr);
	    push (@wanif, $router_addr);
	    my $state = $aapt_iv->getState($router_ref->[0]);
	    push (@wanif, $state);
	    my $slocn = $proj_title . " - " . $snumber;
	    push (@wanif, $router_ref->[0]);
	    push (@wanif, "ACCESS");
	    my $temp = $cusr_abbr . "_ACCESS";
	    push (@wanif, $temp);
	    $temp = $temp . "_" . $state;
	    push (@wanif, $temp);
	    push (@wanif, "");
	    push (@wanif, $use_if_descr);
	    push (@wanif, "0");
	    push (@wanif, $if_name);
# We default circuit speed for FastEthernet to 10Mbits.
	    push (@wanif, "10M");
	    push (@wanif, "10000000");
	    push (@wanif, $router_name);
	    push (@wanif, $alarm_card_slot);
	    push (@wanif, $alarm_port_name);
	    push (@wanif, $report_lvl);
	    
	    my $wanif_file_name = "serv-" . $poller . "-" . $wanif_name . ".wanif.ready";

# Remove some of the chars that dont fit into unix file names.

	    $wanif_file_name =~ s/ /\-/g;
	    $wanif_file_name =~ s/\//\-/g;
	    $wanif_file_name =~ s/\:/\-/g;

	    $wanif_file_name = $run_path . "/files/" . $wanif_file_name;

	    open (WANIF, ">$wanif_file_name") 
		or die "Error opening $wanif_file_name : $!\n";
	    print WANIF join(";", @wanif) . "\n";
	    close (WANIF)
	}	
    }
}
# loadSNMP - Load snmprd/wr strings into memory
#
# Parameters:	None
#
# Returns:	None

sub loadSNMP
{
    my $sql =	"select	 tefi_tableid
			,tefi_value
		 from	 technology_template_instance
		 where	 tefi_name = ?";

# As a temporary measure we store Read and Write strings
# in different format - come January 2004 this will get
# fixed up.

    my $sth = $dbh->prepare($sql);
    $sth->execute("SNMP READ String");

    my @row;
    while (@row = $sth->fetchrow_array)
    {
	$snmp{$row[0]} = [$row[1]];
    }

    $sth->execute('SNMP_WRITE');
    while (@row = $sth->fetchrow_array)
    {
	push (@{$snmp{$row[0]}}, $row[1]);
    }
}
# writeError - Write an error message if a router
# is configured incorrectly
#
# Parameters:	Return Code
#
# Returns:	None

sub writeError
{
    my $code = shift;
    
    my $error_filename = $run_path . "/files/serv-" . $poller . "-" . $sero_id . ".custrtr.error";
# Remove some of the chars that dont fit into unix file names.

    $error_filename =~ s/ /\-/g;
    
    open (ERRORFILE, ">$error_filename") or
	die "Error opening file $error_filename - $!\n";
    print ERRORFILE "Error $code for $cusr_abbr, circuit $cirt_name - $error_desc{$code}\n";
    close ERRORFILE or 
	die "Error closing $error_filename - $!\n";
}
