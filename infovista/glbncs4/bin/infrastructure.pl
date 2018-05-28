#!/pkgs/bin/perl -w

######################################################
# infrastructure.pl - Extract config data to load
# infrastructure into InfoVista
#
# Created:      February 19, 2002
# Author:       Bart Masters
# Version:      0.2
#
# Updated:      December 2, 2002
# By:           Adam Booth
# Reason:       Router Collection Added
#
# This program is used to load config data from BIOSS
# into InfoVista.  It will get all WAN Switches (ie
# BPX, MGX and IGXes) and all Routers, get all their
# appropriate details, and produce WAN_SWITCH details
# to load into InfoVista.
#
# If a piece of equipment is missing some data, it will
# be listed in an error report for chasing up.
######################################################

use strict;		# Be good, lil program
use DBI;		# Database connection module
use Getopt::Std;	# Process command line options

# Global Variables

my $ne_total_count;	# Total no of NEs extracted
my $WAN_switch_count;	# No. of WAN switches extracted
my $Router_count;       # Number of routers extracted
my $params = "f:";
my %cmds;
my $filename;

#----------------------
# Main Processing
#----------------------

print "Starting processing\n";

# Connect to the database

my $dbh = dbconnect();

# Get command line options

getopts($params, \%cmds);
if (defined $cmds{f})
{
	$filename = $cmds{f}
}
else
{
	$filename = 'infra.tmp';
}

# Open the topology file

open (TOPFILE, ">$filename") or
	die "Error opening file $filename - $! \n";

# Process BPX/IGX Switches.

my $num_BPX = extractBPXIGX();

# MGX require seperate processing.

my $num_MGX = extractMGX();

my $num_RTR;
#my $num_RTR = extractRTR();

# Finish up by printing nice message and disconnecting.
$WAN_switch_count = $num_BPX + $num_MGX;
$dbh->disconnect();
print "Processing completed successfully - $WAN_switch_count switches, $num_RTR routers extracted\n";

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
    my $oracle 		= 'glbncs4.opseng.aapt.com.au';
    my $sid 		= 'bprod';
    my $userid		= 'infovista';
    my $password 	= 'appl3s';
    my $source 		= 'DBI:Oracle:host=' .
			    $oracle .
	   		    ';sid=' .
			    $sid;

    my $dbh = DBI->connect ($source, $userid, $password, { RaiseError => 1, AutoCommit => 0}) ||
	die "Error connecting to $oracle: $DBI::errstr\n";

    return $dbh;
}
# extractBPXIGX - Extract all BPX and IGX details.
#
# Parameters:	None
#
# Returns:	No of switches extracted

sub extractBPXIGX
{
    my $no_switch = 0;
    my $sql = 	"select  equp_ipaddress
			,equp_equt_abbreviation
			,tefi_value
			,equp_locn_ttname
			,locn_ttregion
		 from	 equipment
	 		,technology_template_instance
			,locations
		 where	 equp_equt_abbreviation in ('BPX', 'IGX')
		 and	 equp_status = 'INSERVICE'
		 and	 equp_id = tefi_tableid
		 and	 tefi_tablename='EQUIPMENT'
		 and	 equp_locn_ttname = locn_ttname
		 and	 tefi_name = 'DNS'";
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @swdets;
    while ((@swdets) = $sth->fetchrow_array)
    {
# IV doesnt like null IP Addresses, so stick in 1.1.1.1
	unless (defined $swdets[0])
	{
	    $swdets[0] = '1.1.1.1';
	}

	my $ip_addr = $swdets[0];
	my $equip_type = $swdets[1];
	my $equip_dns = $swdets[2];
	my $locn_name = $swdets[3];
	my $locn_region = $swdets[4];

	print TOPFILE "WAN_SWITCH;$equip_dns;$equip_type;zNETOPS;zNETOPS-NET MGMT;$locn_region;$locn_name;EQUIPMENT;$ip_addr;public;4\n";
	$no_switch++;
    }
    return $no_switch;
}
# extractMGX - Extract all MGX details.
#
# Parameters:	None
#
# Returns:	No of MGX switches and cards extracted

sub extractMGX
{
    my $no_switch = 0;
    my $sql = 	"select  equp_ipaddress
			,equp_equt_abbreviation
			,tefi_value
			,equp_id
			,equp_locn_ttname
			,locn_ttregion
		 from	 equipment
	 		,technology_template_instance
			,locations
		 where	 equp_equt_abbreviation = 'MGX'
		 and	 equp_status = 'INSERVICE'
		 and	 equp_id = tefi_tableid
		 and	 tefi_tablename='EQUIPMENT'
		 and	 equp_locn_ttname = locn_ttname
		 and	 tefi_name = 'DNS'";
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @swdets;
    while ((@swdets) = $sth->fetchrow_array)
    {
# IV doesnt like invalid IP Addresses, so if its not valid,
# stick in 1.1.1.1
	unless ($swdets[0] =~ /^(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])\.(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])\.(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])\.(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])$/)
	{
	    $swdets[0] = '1.1.1.1';
	}
# For each MGX, we have to print a row for each card in the MGX.

	my $ip_addr = $swdets[0];
	my $equip_abbr = $swdets[1];
	my $equip_dns = $swdets[2];
	my $equp_id = $swdets[3];
	my $locn_name = $swdets[4];
	my $locn_region = $swdets[5];

	print TOPFILE "WAN_SWITCH;$equip_dns;$equip_abbr;zNETOPS;zNETOPS-NET MGMT;$locn_region;$locn_name;EQUIPMENT;$ip_addr;public;4\n";

	my $sql1 = 	"select  card_slot
			 from	 equipment
				,cards
			 where	 equp_id = '$equp_id'
			 and	 equp_id = card_equp_id
			 and	 card_slot != 'NA'
			 order by card_slot";
	my $sth1 = $dbh->prepare($sql1);
	$sth1->execute();

	my @carddets;
	while ((@carddets) = $sth1->fetchrow_array)
	{
	    $no_switch++;
	    my $slot_no = $carddets[0];
	    my $swcard_name = $swdets[2] . "-" . "SM" . "_" . $slot_no;
	    my $type = $swdets[1] . "_SLOT";
	    my $password = "POPEYE\@SM_" . $slot_no;
	    print TOPFILE "WAN_SWITCH;$swcard_name;$type;zNETOPS;zNETOPS-NET MGMT;$locn_region;$locn_name;EQUIPMENT;$ip_addr;$password;4\n";
	}
    }
    return $no_switch;
}

# extractRTR - Extract all RTR details (Currently RTRCE, RTRRA)
# RTRPE routers are not extracted currently due to issues with their
# IP Addresses - they are manually added to the topology file.
#
# Parameters:   None
#
# Returns:      No of routers extracted

sub extractRTR
{
       my $routcount = 0; # number of routers
       # Dig out all the routers that are RTRCE/RTRPE/RTRRA that have IP Addresses and are in Service
       my $sql = "SELECT equp_equt_abbreviation, equp_locn_ttname,
                      equp_index, equp_ipaddress,
                      equp_manr_abbreviation, equp_equm_model,
                      equp_cusr_abbreviation, cusr_name, locn_ttregion
               FROM equipment, locations, customer
               WHERE equp_equt_abbreviation in ('RTRCE','RTRRA')
               AND equp_status = 'INSERVICE'
               AND locn_ttname = equp_locn_ttname
               AND equp_cusr_abbreviation = cusr_abbreviation
               AND equp_ipaddress IS NOT NULL
               ORDER BY locn_ttregion, equp_locn_ttname";

       my $ath = $dbh->prepare($sql);
       $ath->execute();
       my @dat;
       while ((@dat) = $ath->fetchrow_array)
        {
               if($dat[0]){
                         my $RTR_Name = $dat[1]." ".$dat[0]." ".$dat[2];
                         my $RTR_IP = $dat[3];
# IV doesnt like invalid IP Addresses, so if its not valid,
# stick in 1.1.1.1
			unless ($RTR_IP =~ /^(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])\.(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])\.(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])\.(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])$/)
			{
			    $RTR_IP = '1.1.1.1';
			}
                         my $RTR_Locn = $dat[1];
                         my $RTR_Desc = $dat[4]." ".$dat[5];
                         my $RTR_custid = $dat[6];
                         my $RTR_CustName = $dat[7];
                         my $RTR_region = $dat[8];
                         my $RTR_custidtype = $RTR_custid."_".$dat[0];
                         my $RTR_custidtype_domain = $RTR_custidtype."_".$RTR_region;
                         print TOPFILE "ROUTER;$RTR_Name;CISCO_ROUTER;$RTR_CustName;";
                         print TOPFILE "$RTR_custid;$RTR_region;$RTR_Locn;EQUIPMENT;";
                         print TOPFILE "$RTR_custidtype;$RTR_custidtype_domain;";

# BM - Short term all Routers are created with a reporting level of 0.
# Once we work out how we're doing internal router reporting, this will
# get changed to whatever is appropriate.

                         print TOPFILE "$RTR_Desc;$RTR_IP;InfoVista;InfoVista;0\n";
                         $routcount++;
               }
       }
       return $routcount;
}
