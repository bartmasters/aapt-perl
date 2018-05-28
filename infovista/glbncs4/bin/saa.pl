#!/pkgs/bin/perl
######################################################
# saa.pl - Extract config data to load a SAA agent
# into InfoVista
#
# Created:      August 21, 2003
# Author:       Bart Masters
# Version:      1.0
#
# This is primarily a shell to the Saa.pm module.
#
# Version History
# ---------------
# 1.0	Initial Release
#
######################################################

use strict;		# Be good, lil program
use Getopt::Std;	# Process command line options
use lib "/export/home/infovista/bin/";
use lib ".";
use Saa;

# Global Variables

my %cmds;		# Command line options
my $params = "p:f:e:r:";	# Valid command line options
my $poller;
my $run_path;
my $end_file_name;
my $error_file;

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
    $end_file_name = "../files/saa.end." . $poller;
}

if (defined $cmds{r})
{
    $error_file = $cmds{r};
}
else
{
    $error_file = "../log/saa.error." . $poller;
}

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
close(CFGFILE);

my $customer_file=$run_path."/files/".$poller."_customer.file";
my @custname;

open (CUSTFILE, "$customer_file") or die "Error opening $customer_file $!\n";
chomp (@custname = <CUSTFILE>);
close CUSTFILE;


my $userid	= $db_details{"USERID"};
my $sid		= $db_details{"SID"};
my $password	= $db_details{"PASSWORD"};

my %arg = ('run_path' => $run_path,
           'error_file' => $error_file,
           'poller' => $poller,
           'db_userid' => $userid,
           'db_pass' => $password,
           'db_sid' => $sid,
	   'customers' => \@custname);

my $saa = saa->new(\%arg);
die if !$saa;
die if !$saa->Run();

my $command = "touch $end_file_name";
system("$command");
exit 0;
