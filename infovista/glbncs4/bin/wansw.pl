#!/pkgs/bin/perl

######################################################
# wansw.pl - Extract config data to load
# WAN Switches into into InfoVista
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
#
######################################################

use strict;		# Be good, lil program
use DBI;		# Database connection module
use Getopt::Std;	# Process command line options

# Global Variables

my $ne_total_count;	# Total no of NEs extracted
my $WAN_switch_count;	# No. of WAN switches extracted
my $Router_count;       # Number of routers extracted
my $params = "f:e:";
my %cmds;
my $filename;
my $end_file_name;
my $run_path;

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

if (defined $cmds{e})
{
    $end_file_name = $cmds{e};
}
else
{
    $end_file_name = "../files/wansw.end.";
}

# Connect to the database

my $dbh = dbconnect();

# Open the topology file

$filename = $run_path . "/files/wansw.tmp";
open (TOPFILE, ">$filename") or
	die "Error opening file $filename - $! \n";

# Process BPX/IGX Switches.

my $num_BPX = extractBPXIGX();

# MGX require seperate processing.

my $num_MGX = extractMGX();

# Finish up by disconnecting and creating the file to say so.

$dbh->disconnect();

$WAN_switch_count = $num_BPX + $num_MGX;
print "Processing completed successfully - $WAN_switch_count switches extracted\n";

close (TOPFILE);
my $command = "touch $end_file_name";
my $rc = system("$command");
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
			,equp_index
		 from	 equipment
	 		,technology_template_instance
			,locations
		 where	 equp_equt_abbreviation in ('BPX', 'IGX')
		 and	 equp_status = 'INSERVICE'
		 and	 equp_id = tefi_tableid
		 and 	 tefi_tablename='EQUIPMENT'
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
	my $equip_index = $swdets[5];
	my $alarm_name = $locn_name . " " . $equip_type . " " . $equip_index;

	#print TOPFILE "WAN_SWITCH;$equip_dns;$equip_type;zNETOPS;zNETOPS-NET MGMT;$locn_region;$locn_name;EQUIPMENT;$ip_addr;public;$alarm_name;;4\n";
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
			,equp_index
		 from	 equipment
	 		,technology_template_instance
			,locations
		 where	 equp_equt_abbreviation = 'MGX'
		 and	 equp_status = 'INSERVICE'
		 and	 equp_id = tefi_tableid
		 and 	 tefi_tablename='EQUIPMENT'
		 and	 equp_locn_ttname = locn_ttname
		 and	 tefi_name = 'DNS'";
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @swdets;
    while ((@swdets) = $sth->fetchrow_array)
    {
# IV doesnt like invalid IP Addresses, so if its not valid,
# stick in 1.1.1.1

	unless (defined ($swdets[0]))
	{
	    $swdets[0] = "1.1.1.1";
	}
	
	unless ($swdets[0] =~ /^(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])\.(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])\.(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])\.(\d|[0-1]?\d\d|2[0-4]\d|25[0-5])$/)
	{
	    $swdets[0] = "1.1.1.1";
	}
# For each MGX, we have to print a row for each card in the MGX.

	my $ip_addr 	= $swdets[0];
	my $equip_abbr 	= $swdets[1];
	my $equip_dns 	= $swdets[2];
	my $equp_id 	= $swdets[3];
	my $locn_name 	= $swdets[4];
	my $locn_region = $swdets[5];
	my $equip_index = $swdets[6];
	my $alarm_name 	= $locn_name . " " . $equip_abbr . " " . $equip_index;

	#print TOPFILE "WAN_SWITCH;$equip_dns;$equip_abbr;zNETOPS;zNETOPS-NET MGMT;$locn_region;$locn_name;EQUIPMENT;$ip_addr;public;$alarm_name;;4\n";
	print TOPFILE "WAN_SWITCH;$equip_dns;$equip_abbr;zNETOPS;zNETOPS-NET MGMT;$locn_region;$locn_name;EQUIPMENT;$ip_addr;public;4\n";

	my $sql1 = 	"select  card_slot
				,card_name
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
	    my $slot_no 	= $carddets[0];
	    my $swcard_name 	= $swdets[2] . "-" . "SM" . "_" . $slot_no;
	    my $type 		= $swdets[1] . "_SLOT_" . $carddets[1];
	    my $password 	= "POPEYE\@SM_" . $slot_no;
	    #print TOPFILE "WAN_SWITCH;$swcard_name;$type;zNETOPS;zNETOPS-NET MGMT;$locn_region;$locn_name;EQUIPMENT;$ip_addr;$password;$alarm_name;$slot_no;4\n";
	    print TOPFILE "WAN_SWITCH;$swcard_name;$type;zNETOPS;zNETOPS-NET MGMT;$locn_region;$locn_name;EQUIPMENT;$ip_addr;$password;4\n";
	}
    }
    return $no_switch;
}
