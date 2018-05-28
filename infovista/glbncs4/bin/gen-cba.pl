#!/pkgs/bin/perl -w
######################################################
# gen-cba.pl - Generate service order extracts for CBA
#
# Created:      December 11, 2002
# Author:       Bart Masters
# Version:      1.0
#
# This program reads in a list of CBA core PVCs, and 
# calls atmfr.pl to extract their details for loading
# into Infovista.
######################################################

use strict;			# Be good, lil program
use Getopt::Std;		# Process command line options

# Global Variables

my $params = "f:";
my %cmds;
my $filename;
my $run_path = "/export/home/infovista";
my $poller = "glb";

#----------------------
# Main Processing
#----------------------

# Get the command line options

getopts($params, \%cmds);

# Get the processing date

if (defined $cmds{f})
{
    $filename = $cmds{f};
}
else
{
    $filename = "cba_core_pvcs";
}

# Work out run time

my @local_time = (localtime)[0..5];
$local_time[4]++;
$local_time[5] += 1900;
my $run_date1 = sprintf("%02d%02d%04d", $local_time[3], $local_time[4], $local_time[5]);
my $run_date2 = sprintf("%02d%02d%02d", $local_time[2], $local_time[1], $local_time[0]);
my $run_date = $run_date1 . "-" . $run_date2;

# Read input

open (INPUT, "$filename") or
    die "Error opening $filename $!\n";

while (<INPUT>)
{
    my $sero_id = $_;
    chomp ($sero_id);
    
    my $filename =  $run_path . "/files/serv-". $poller . "-" . $sero_id . ".ready";
    my $error_filename =  $run_path . "/files/serv-". $poller . "-" . $sero_id . ".error";
    my $error_file = $run_path . "/log/atmfr.error." . $run_date;
	
    my $command = "$run_path/bin/atmfr.pl -s $sero_id -f $filename -e $error_filename 2>>$error_file";
    my $rc = system("$command");
}
