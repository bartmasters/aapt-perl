#!/pkgs/bin/perl

######################################################
# Oneoff job to update service type attribute values
# to date format.
#
# Invalid values are spat out into a log file.
#
# By default it does not update, run with the -d flag
# to actually perform the update.
#
######################################################


use strict;		# Be good, lil program
use DBI;		# Database connection module
use Getopt::Std;	# Process command line options

# Global Variables

my %cmds;		# Command line options
my $params = "u:p:d:";	# Valid command line options
my $update = "no";
my $update_count = 0;
    
my $oracle   = "glbdap1.opseng.aapt.com.au";
my $sid	     = "bprod";
#my $oracle   = "glbncs5.opseng.aapt.com.au";
#my $sid	     = "buat";
my $userid;
my $password;

#----------------------
# Main Processing
#----------------------

# Get the command line options

getopts($params, \%cmds);

if (defined $cmds{u})
{
    $userid = $cmds{u};
}
if (defined $cmds{p})
{
    $password = $cmds{p};
}
if (defined $cmds{d})
{
    $update = "yes";
}

open (OUTPUTFILE, ">run-serv-type-output.txt") or
	die "Error opening file run-serv-type-output.txt - $!\n";
print OUTPUTFILE "*** Starting run ***\n\n";
    
# Connect to the database

my $dbh = dbconnect();
	
# Work through all service type attributes that are dates

my $sql =	"select	 seta_name
			,seta_sert_abbreviation
			,seta_description
		 from	 service_type_attributes
		 where	 seta_name like '%DATE%'
		 or 	 seta_description like '%date%'
		 or      seta_description like '%DDMM%'
		 order by seta_name asc, 
			  seta_sert_abbreviation asc";

my $sth = $dbh->prepare($sql);
$sth->execute();

my @seta_line;

while (@seta_line = $sth->fetchrow_array)
{
    my $seta_name = $seta_line[0];
    my $seta_sert_abbreviation = $seta_line[1];
    my $seta_description = $seta_line[2];
    $update_count++;
   
    if ($update eq "yes")
    {
	my $sql2 = "update service_type_attributes
		    set seta_defaultvalue = 'dd-mmm-yyyy'
		    where seta_name = '$seta_name'
		    and seta_sert_abbreviation = '$seta_sert_abbreviation'
		    and seta_defaultvalue in ('ddmmyy','ddmmyyyy')";
	$dbh->do($sql2);
	
	if ($seta_description =~ /DDMMYY/)
	{
	    my $seta_description_old = $seta_description;
	    $seta_description =~ s/DDMMYYYY/DD-MMM-YYYY/;
	    $seta_description =~ s/DDMMYY/DD-MMM-YYYY/;

	    $seta_description =~ s/'/''/;
	    print OUTPUTFILE "Updating date attribute - $seta_name, $seta_sert_abbreviation, $seta_description_old to $seta_description\n";
	    my $sql3 = "update service_type_attributes
			   	set seta_description = '$seta_description'
			   	where seta_name = '$seta_name'
			    and seta_sert_abbreviation = '$seta_sert_abbreviation'";
	    $dbh->do($sql3);
	}
	
	print OUTPUTFILE "Updating date attribute - $seta_name, $seta_sert_abbreviation, $seta_description\n";
	my $sql4 = "update service_type_attributes
		    set seta_datatype = 'DATE'
		    where seta_name = '$seta_name'
		    and seta_sert_abbreviation = '$seta_sert_abbreviation'";
	$dbh->do($sql4);
    }
    else
    {
	print OUTPUTFILE "Found date attribute - $seta_name, $seta_sert_abbreviation, $seta_description\n";
    }
}

# Finish up by disconnecting.

$dbh->disconnect();
   
print OUTPUTFILE "\n***Run finished - $update_count records updated\n";
close OUTPUTFILE or die "Error closing run-serv-type-output.txt - $!\n";

# dbconnect	- Connect to the Database
#
# Parameters:  None
#
# Returns:     Database handle

sub dbconnect
{
    my $source = 'DBI:Oracle:host=' . $oracle . ';sid=' . $sid;

    my $dbh = DBI->connect($source, $userid, $password, { RaiseError => 1, AutoCommit => 0});
    return $dbh;
}
