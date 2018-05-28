#!/pkgs/bin/perl -w
######################################################
# ivdaily.pl - Perform daily functions for InfoVista
#
# Created:      March 7, 2002
# Author:       Bart Masters
# Version:      2.0
#
# This program is the driving program for the daily 
# extracts that are performed for Infovista.  It 
# performs the following jobs:-
#
# Call gen-pword.pl to generate passwords for any
# 	new service orders which have been created
# 	today.
# Call atmfr.pl to extract all circuit details for
# 	atm/fr PVCs.
# Call custrouter.pl to extract all circuit and NE 
#       details for customer routers.
# Call ipvpn.pl to extract all circuit and NE 
#       details for IP-VPNs.
# Call saa.pm to extract all SAA circuit details. 
# Call wansw.pl to extract all WAN switch details.
# 
# These jobs are all run in the background, so they can
# run in parallel.  Another job ivdaily-monitor.pl is
# started then, which will run in daemon mode to pick
# up the output of these programs.
#
# Command line parms:
#
# -t	Test mode - Use the development files/paths.
#
######################################################

use strict;			# Be good, lil program
use Getopt::Std;		# Process command line options

# Global Variables

my %cmds;
my $command;
my $params = "t";
#my @poller_list = qw(glb hay sv8);
my @poller_list = qw(glb hay);
my $req_date;
my $rc;
my $run_path = "/export/home/infovista";
my $sero_id;
my @test_poller_list = qw(hvt);
my $test_run_path = "/home/bamaster/perl/infovista/glbncs4";
$ENV{"ORACLE_HOME"} = "/opt/oracle/product/8.1.6";
$ENV{"TNS_ADMIN"} = "/export/oracle/local/network/admin";

#----------------------
# Main Processing
#----------------------

# Get the command line options

getopts($params, \%cmds);

# Work out run time

my @local_time = (localtime)[0..5];
$local_time[4]++;
$local_time[5] += 1900;
my $run_date1 = sprintf("%02d%02d%04d", $local_time[3], $local_time[4], $local_time[5]);
my $run_date2 = sprintf("%02d%02d%02d", $local_time[2], $local_time[1], $local_time[0]);
my $run_date = $run_date1 . "-" . $run_date2;

$req_date = join ('-',@local_time[3..5]);

# Check if in test mode

if (defined $cmds{t})
{
    print "Entering TEST mode\n";
    $run_path = $test_run_path;
    @poller_list = @test_poller_list;
}

# We process separately for each Infovista poller

my $poller;
foreach $poller (@poller_list)
{
# Generate passwords.
    genPwords($poller);

# Extract all customer PVCs
    
    extractPVC($poller);

# Extract all gold reporting (Router based reporting) details

   extractGold($poller);

# Extract Metro Ethernet circuits

   extractEthLan($poller);

# Extract all customer IP-VPN circuits
    
   extractIPVPN($poller);

# Extract SAA

   extractSAA($poller);
}

# Extract all Infrastructure details

extractWANSW();

# Start up the monitoring daemon

startMonitor();

#-----------------------------
# Subroutines
#-----------------------------
# extractEthLan	Extract all customer Metro Ethernet details.
#
# Parameters:	Poller Name
#
# Returns:	None

sub extractEthLan
{
    my $poller = shift;
    my $output_file = $run_path . '/log/ethlan.file.' . $poller . '.' . $run_date;
    my $error_file = $run_path . '/log/ethlan.error.' . $poller . '.' . $run_date;
    my $end_file = $run_path . '/files/ethlan.end.' . $poller . '.' . $run_date;
	
    $command = "$run_path/bin/eth-lan.pl -p $poller -f $run_path -e $end_file > $output_file 2> $error_file &";
    system("$command");
}

# extractGold	Extract all Gold reporting details.
# We use the same product list and code as ATM/FR PVC, since
# 
#
# Parameters:	Poller Name
#
# Returns:	None

sub extractGold
{
    my $poller = shift;
    my $output_file = $run_path . '/log/custrouter.file.' . $poller . '.' . $run_date;
    my $error_file = $run_path . '/log/custrouter.error.' . $poller . '.' . $run_date;
    my $end_file = $run_path . '/files/custrouter.end.' . $poller . '.' . $run_date;
	
    $command = "$run_path/bin/custrouter.pl -p $poller -f $run_path -e $end_file > $output_file 2> $error_file &";
    
    system("$command");
}

# extractIPVPN	Extract all IP-VPN details.
#
# Parameters:	Poller Name
#
# Returns:	None

sub extractIPVPN
{
    my $poller = shift;
    my $output_file = $run_path . '/log/ipvpn.file.' . $poller . '.' . $run_date;
    my $error_file = $run_path . '/log/ipvpn.error.' . $poller . '.' . $run_date;
    my $end_file = $run_path . '/files/ipvpn.end.' . $poller . '.' . $run_date;
	
    $command = "$run_path/bin/ipvpn.pl -p $poller -f $run_path -e $end_file > $output_file 2> $error_file &";
    system("$command");
}

# extractSAA Extract all SAA NEs that RealTime or Interactive report required
# param: None
# returns: undef if failed.

sub extractSAA
{
    my $poller = shift;
    my $output_file = $run_path . '/log/saa.file.' . $poller . '.' . $run_date;
    my $error_file = $run_path . '/log/saa.error.' . $poller . '.' . $run_date;
    my $end_file = $run_path . '/files/saa.end.' . $poller . '.' . $run_date;

    $command = "$run_path/bin/saa.pl -p $poller -f $run_path -e $end_file -r $error_file > $output_file 2>> $error_file &";
    system("$command");
}

# extractPVC    Extract all ATM/FR PVCs
#
# Parameters:	Poller Name
#
# Returns:	None

sub extractPVC
{
    my $poller = shift;
 	
    my $output_file = $run_path . '/log/atmfr.file.' . $poller . '.' . $run_date;
    my $error_file = $run_path . '/log/atmfr.error.' . $poller . '.' . $run_date;
    my $end_file = $run_path . '/files/atmfr.end.' . $poller . '.' . $run_date;
	
    $command = "$run_path/bin/atmfr.pl -p $poller -f $run_path -e $end_file > $output_file 2> $error_file &";
    system("$command");
}

# extractWANSW	Extract all WAN Switch details.
#
# Parameters:	None
#
# Returns:	None

sub extractWANSW
{
    my $output_file = $run_path . '/log/wansw.file.' . $run_date;
    my $error_file = $run_path . '/log/wansw.error.' . $run_date;
    my $end_file = $run_path . '/files/wansw.end.' . $run_date;
	
    $command = "$run_path/bin/wansw.pl -f $run_path -e $end_file > $output_file 2> $error_file &";
    system("$command");
}

# genPwords	Generate passwords for any new service orders.
#
# Parameters:	Product List, Customer List, Poller
#
# Returns:	None

sub genPwords
{
    my $poller = shift;

# Create the userid/password for the customer
    my $output_file = $run_path . '/log/gen-pword.file.' . $poller . '.' . $run_date;
    my $error_file = $run_path . '/log/gen-pword.error.' . $poller . '.' . $run_date;
    my $end_file = $run_path . '/files/gen-pword.end.' . $poller . '.' . $run_date;
		
    $command = "$run_path/bin/gen-pword.pl -f $run_path -p $poller -e $end_file > $output_file 2> $error_file";
    system("$command");
}

# startMonitor	Start the monitoring program
#
# Parameters:	None
#
# Returns:	None

sub startMonitor
{
    my $output_file = "$run_path/log/ivdaily-mon.file.$run_date";
    my $error_file = "$run_path/log/ivdaily-mon.error.$run_date";
    
    my $test_flag = "";
    if (defined $cmds{t})
    {
	$test_flag = "-t ";
    }
    
    $command = "$run_path/bin/ivdaily-monitor.pl $test_flag -f $run_path -d $run_date > $output_file 2> $error_file &";
    system("$command");
}
