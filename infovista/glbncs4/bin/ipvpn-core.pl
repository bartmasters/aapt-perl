#!/pkgs/bin/perl
    
######################################################
# ipvpn-core.pl - Build the topology file for the core
# ip vpn groups.
#
# Created:      December 2, 2002
# Author:       Bart Masters
# Version:      1.0
#
# IP-VPN core reporting is signified by producing
# IP2IP Group entries, consisting of the core IP2IP
# links.  These groups have to be assigned to the 
# various individual Edge IP2IP entries which have been
# extracted from Bioss by the program ipvpn.pl.
#
# This program takes output from ipvpn.pl, and creates
# the list of individual IP2IPs that each Core IP2IP
# Group has to be assigned to.  It then creates the 
# IP2IP Group topology file.
#
# The IP2IP Group topology will get merged in with the
# other topologies and loaded into IV as part of normal
# ivdaily.pl processing. 
######################################################
#       Network Application AAPT Limited
#
#       File:           $RCSfile: ipvpn-core.pl,v $
#       Source:         $Source: /pace/ProdSRC/infovista/cvs/glbncs4/bin/ipvpn-core.pl,v $
#
#       ChangedBy:      $Author: syang $
#       ChangedDate:    $Date: 2004/06/07 01:04:17 $
#
#       Version:        $Revision: 1.6 $
######################################################
#       RCS Log:        $Log: ipvpn-core.pl,v $
#       RCS Log:        Revision 1.6  2004/06/07 01:04:17  syang
#       RCS Log:        Delete pe_routers of CANB0001 RTRPE 001 upon request from BIOSS Ops
#       RCS Log:
######################################################


use strict;		# Be good, lil program
use DBI;		# Database connection module
use Getopt::Std;	# Process command line options

# Global Variables

my $params = "h:f:t:b:p:";
my %cmds;
my $hostname;
my $base_filename;
my $topology;
my $output_filename;
my %pe_routers;
my $run_path;

$pe_routers{"ADEL0001 RTRPE 001"} = "";
$pe_routers{"BRIS0001 RTRPE 001"} = "";
#$pe_routers{"CANB0001 RTRPE 001"} = "";
$pe_routers{"GLEB0001 RTRPE 001"} = "";
$pe_routers{"MELB0006 RTRPE 001"} = "";
$pe_routers{"PERT0005 RTRPE 001"} = "";

#----------------------
# Main Processing
#----------------------

# Get command line options

getopts($params, \%cmds);

if (defined $cmds{h})
{
    $hostname = $cmds{h};
}
else
{
    $hostname = "glb";
}

if (defined $cmds{b})
{
    $base_filename = $cmds{b};
}
else
{
    $base_filename = "../files/ipvpn-core-base";
}

if (defined $cmds{t})
{
    $topology = $cmds{t};
}
else
{
    $topology = "../files/glb_cust.tmp";
}

if (defined $cmds{f})
{
    $output_filename = $cmds{f};
}
else
{
    $output_filename = "glb-ipvpn-core.ready";
}

if (defined $cmds{p})
{
    $run_path = $cmds{p};
}
else
{
    $run_path = "..";
}


# Connect to the database

my $dbh = dbconnect();

# Firstly get the base IP2IP Groups file,
# and load it into a hash named by the state
# of each IP2IP Group.

my %base_layout;
open (BASEFILE, "$base_filename") or
	die "Error opening file $base_filename - $! \n";
while (<BASEFILE>)
{
    chomp;
    my @base_input = split(";", $_);
    my $base_details = join(";", @base_input[1,2,3,4]);
    $base_layout{$base_input[0]} = $base_details;
}

# Load up the PE Router details.
 
my $router;
foreach $router (keys (%pe_routers))
{
    my $details = getRouter($router);
    $pe_routers{$router} = ["N", $details];
}

# Create the hashes for each state, and load all
# the IP2IP tree details into their appropriate state.

# I can't work out a nice way to refer to hashes by
# a scalar's name, so I use the old ugly method.

my %act_tree;
my %nsw_tree;
my %qld_tree;
my %sa_tree;
my %vic_tree;
my %wa_tree;

open (INPUTTOPO, "$topology");
while (<INPUTTOPO>)
{
    my @input_line = split(";", $_);

# We only use IP2IPs that are IPVPN

    if (($input_line[0] eq "IP2IP") and
	($input_line[10] eq "IPVPN"))
    {
	my $report_tree = join ("\\", @input_line[3,4,5,6,7]);
	if ($input_line[5] =~ /ACT/)
	{
	    $act_tree{$report_tree}++;
	}
	elsif ($input_line[5] =~ /NSW/)
	{
	    $nsw_tree{$report_tree}++;
	}
	elsif ($input_line[5] =~ /QLD/)
	{
	    $qld_tree{$report_tree}++;
	}
	elsif ($input_line[5] =~ /SA/)
	{
	    $sa_tree{$report_tree}++;
	}
	elsif ($input_line[5] =~ /VIC/)
	{
	    $vic_tree{$report_tree}++;
	}
	elsif ($input_line[5] =~ /TAS/)
	{
	    $vic_tree{$report_tree}++;
	}
	elsif ($input_line[5] =~ /NT/)
	{
	    $sa_tree{$report_tree}++;
	}
	elsif ($input_line[5] =~ /WA/)
	{
	    $wa_tree{$report_tree}++;
	}
	else
	{
	    $nsw_tree{$report_tree}++;
	}
    }
# A second check that needs to be added.  Sometimes
# as part of QoS conformance reporting, one of the 
# five core PE routers will be created.  If they haven't
# been created, add them to output.

    elsif (($input_line[0] eq "ROUTER") and
	   ($input_line[1] =~ /RTRPE 001/))
    {
	foreach (keys %pe_routers)
	{
	    if ($input_line[1] eq $_)
	    {
		$pe_routers{$_}->[0] = "Y";
	    }
	}
    }
	
}

# Now extract the unique entries for each state, merge
# them with their base, and write out the new IP2IP Groups.

my $new_tree_layout = join(",", keys %act_tree);
my @new_group = split(";", $base_layout{"ACT"});
splice @new_group, 3, 0, $new_tree_layout;

my @output_array;
my $output_line;
$output_line = join(";", @new_group);
push(@output_array, $output_line);

# Now do the same for the other 5 states;

$new_tree_layout = join(",", keys %nsw_tree);
@new_group = split(";", $base_layout{"NSW"});
splice @new_group, 3, 0, $new_tree_layout;
$output_line = join(";", @new_group);
push(@output_array, $output_line);

$new_tree_layout = join(",", keys %qld_tree);
@new_group = split(";", $base_layout{"QLD"});
splice @new_group, 3, 0, $new_tree_layout;
$output_line = join(";", @new_group);
push(@output_array, $output_line);

$new_tree_layout = join(",", keys %sa_tree);
@new_group = split(";", $base_layout{"SA"});
splice @new_group, 3, 0, $new_tree_layout;
$output_line = join(";", @new_group);
push(@output_array, $output_line);

$new_tree_layout = join(",", keys %vic_tree);
@new_group = split(";", $base_layout{"VIC"});
splice @new_group, 3, 0, $new_tree_layout;
$output_line = join(";", @new_group);
push(@output_array, $output_line);

$new_tree_layout = join(",", keys %wa_tree);
@new_group = split(";", $base_layout{"WA"});
splice @new_group, 3, 0, $new_tree_layout;
$output_line = join(";", @new_group);
push(@output_array, $output_line);

# Finally, write the output.

open (OUTPUT, ">$output_filename") or
	die "Error opening file $output_filename - $! \n";
my $print_line;
foreach $print_line (@output_array)
{
    print OUTPUT $print_line . "\n";
}

foreach (keys %pe_routers)
{
    if ($pe_routers{$_}->[0] eq "N")
    {
	print OUTPUT $pe_routers{$_}->[1] . "\n";
    }
}

close OUTPUT;
#-----------------------------
# Subroutines
#-----------------------------
#
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

    my $dbh = DBI->connect($source, $userid, $password, { RaiseError => 1, AutoCommit => 0});
    return $dbh;
}
# getRouter	Get a router's details
#
# Parameters:	Router Name
#
# Returns:	Router Details

sub getRouter
{
    my $router = shift;
    my @router_split = split(" ", $router);

    my $sql =	"select	 equp_ipaddress
			,equp_cusr_abbreviation
			,cusr_name
			,equp_equm_model
		 from	 equipment
			,customer
		 where	 equp_locn_ttname = ?
		 and	 equp_equt_abbreviation = ?
		 and	 equp_index = ?
		 and	 equp_cusr_abbreviation = cusr_abbreviation";

    my $sth = $dbh->prepare($sql);
    $sth->execute($router_split[0], $router_split[1], $router_split[2]);
    my @router_row = $sth->fetchrow_array();

    $sql =	"select	 locn_state
		 from	 locations
		 where	 locn_ttname = ?";
    
    $sth = $dbh->prepare($sql);
    $sth->execute($router_split[0]);
    my $location = $sth->fetchrow_array();
    
    my @output;
    push (@output, "ROUTER");
    push (@output, $router);
    push (@output, "CISCO_ROUTER");
    push (@output, $router_row[2]);
    push (@output, $router_row[1]);
    push (@output, " ");
    push (@output, $location);
    push (@output, $router_split[0]);
    push (@output, "EQUIPMENT");
    my $temp = "AAPNET 1447091_$router_split[1]";
    push (@output, $temp);
    $temp = $temp . "_" . $location;
    push (@output, $temp);
    push (@output, $router_row[3]);
    push (@output, $router_row[0]);
    push (@output, "InfoVista");
    push (@output, "InfoVista");
    push (@output, $router);
    push (@output, "0");
    
    my $return_line = join (";", @output);
    $return_line .= "\n";

    return $return_line;
}

