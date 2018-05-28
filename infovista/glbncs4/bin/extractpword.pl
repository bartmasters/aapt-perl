#!/pkgs/bin/perl -w
########################################################
# extractpword.pl - Generate Extract InfoVista Password
#
# Created:      March 21, 2002
# Author:       Bart Masters
# Version:      1.1
#
# Extract the password.  Good, eh?
#
########################################################

use strict;		# Be good, lil program
use DBI;		# Database connection module
use Getopt::Std;	# Process command line options

my $params = "f:";
my %cmds;
my $cusr_abbr;
my $run_path;
my $filename;

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

# Connect to the database

my $dbh = dbconnect();
$filename = $run_path . "/files/password.tmp";
open (PASSFILE, ">$filename") or die "Error creating file $filename - $!\n";

# Work through the list of customers

my $sql =	"select  distinct(conp_cusr_abbreviation)
		 from	 contact_points
		 where	 conp_cont_abbreviation in ('CUST_REPORT', 
						    'DOMAIN_REPORT',
						    'SERVGRP_REPORT')";

my $sth = $dbh->prepare($sql);
$sth->execute();

while ($cusr_abbr = $sth->fetchrow_array)
{

# Process the customer

    processCustomer($cusr_abbr);
}

# Finish up by disconnecting and creating the file to say so.

$sth->finish();
$dbh->disconnect();

close PASSFILE or die "Error closing file $filename - $!\n";

exit 0;

#-----------------------------
# Subroutines
#-----------------------------
# processCustomer - Extract passwords for a customer.
#
# Parameters:	Customer ID
#
# Returns:	None

sub processCustomer
{
    my $cusr_abbr = shift;
    my $sql =	"select	 conp_cont_abbreviation
			,conp_number
			,conp_usage
			,cusr_name
		from 	 contact_points
			,customer
		where	 conp_cusr_abbreviation = '$cusr_abbr'
		 and	 conp_cusr_abbreviation = cusr_abbreviation
		 and	 conp_cont_abbreviation in ('CUST_REPORT',
						    'DOMAIN_REPORT',
						    'SERVGRP_REPORT')
		 order by conp_number";
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my @contact;
    my $state;

    while (@contact = $sth->fetchrow_array)
    {
# VPSE gets confused if the customer name contains commas or parentheses, so
# remove those customer names completely.
	my $output;
	my $cusr_name = $contact[3];
	$cusr_name =~ s/\(/ /g;
	$cusr_name =~ s/\)/ /g;
	$cusr_name =~ s/,/ /g;
	$cusr_name =~ s/\s+$//;
	$contact[1] =~ /^User Name = (.+) Password = (.+)/;
	my $partone = $1 . ";" . $2 . ";$cusr_name\\\\" . $cusr_abbr;
		
	if ($contact[0] eq 'CUST_REPORT')
	{
	    $output = $partone;
	}
	elsif ($contact[0] eq 'DOMAIN_REPORT')
	{
	    $output = $partone . "\\\\" . $contact[2];
	    $state = $contact[2];			
	}
	else
	{
	    $output = $partone . "\\\\" . $state . "\\\\" . $contact[2];
	}
	print PASSFILE "$output\n";	
    }
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
