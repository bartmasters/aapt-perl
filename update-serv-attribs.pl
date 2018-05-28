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

open (OUTPUTFILE, ">>run-serv-attribs-output.txt") or
	die "Error opening file run-serv-attribs-output.txt - $!\n";
print OUTPUTFILE "*** Starting run ***\n\n";
open (ERRORFILE, ">>run-serv-attribs-error.txt") or
	die "Error opening file run-serv-attribs-error.txt - $!\n";
    
# Connect to the database

my $dbh = dbconnect();
	
# Work through all service type attributes that are dates

my $sql =	"select	 seta_name
			,seta_sert_abbreviation
			,seta_description
		 from	 service_type_attributes
		 where	 seta_datatype = 'DATE'";

my $sth = $dbh->prepare($sql);
$sth->execute();

my @seta_line;

while (@seta_line = $sth->fetchrow_array)
{
    my $seta_name = $seta_line[0];
    my $seta_sert_abbreviation = $seta_line[1];
    my $seta_description = $seta_line[2];
 
    $seta_description =~ s/'/''/;
    # Update the service order attribute descriptions first
    
    my $sql2 = "update service_order_attributes
		    set seoa_description = '$seta_description'
		    where seoa_name = '$seta_name'
		    and seoa_sert_abbreviation = '$seta_sert_abbreviation'";
    if ($update eq "yes")
    {
	$dbh->do($sql2);
	print OUTPUTFILE "Updating $seta_name and $seta_sert_abbreviation description to $seta_description\n";
    }
    else
    {
	print OUTPUTFILE "Found $seta_name and $seta_sert_abbreviation description to $seta_description\n";
    }
    
    # Now work through the service order attributes for this particular type
    
    my $sql3 = "select seoa_id, seoa_defaultvalue, seoa_sero_id
		from service_order_attributes
		where seoa_name = '$seta_name'
		    and seoa_sert_abbreviation = '$seta_sert_abbreviation'
		order by seoa_sero_id";
    my $sth2 = $dbh->prepare($sql3);
    $sth2->execute();

    my @seoa_line;
    while (@seoa_line = $sth2->fetchrow_array)
    {
        my $seoa_id = $seoa_line[0];
        my $seoa_defaultvalue = $seoa_line[1];
        my $seoa_sero_id = $seoa_line[2];
	
	# Attempt to update the value from DD-MM-YY format

	if ($seoa_defaultvalue =~ /^\d{1,2}-\d{1,2}-\d{1,4}$/)
	{
	    eval
	    {
		my $sql4 = "update service_order_attributes
			    set seoa_defaultvalue = 
			    (select to_char((select to_date('$seoa_defaultvalue', 'DD-MM-RR') from dual), 'DD-MON-YYYY') from dual)
			where seoa_id = '$seoa_id'";
		if ($update eq "yes")
		{
		    print OUTPUTFILE "Updating Service Order $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
		    $dbh->do($sql4);
		}
		else
		{
		    print OUTPUTFILE "Found Service Order $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
		}
	    };
	    if ($@)
	    {
		print ERRORFILE "Error updating $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
	    }
	    else
	    {
		$update_count++;
	    }
	}

	# Attempt to update the value from DD/MM/YY format
	
	elsif ($seoa_defaultvalue =~ /^\d{1,2}\/\d{1,2}\/\d{1,4}$/)
	{
	    eval
	    {
		my $sql4 = "update service_order_attributes
			    set seoa_defaultvalue = 
			    (select to_char((select to_date('$seoa_defaultvalue', 'DD/MM/RR') from dual), 'DD-MON-YYYY') from dual)
			where seoa_id = '$seoa_id'";
		if ($update eq "yes")
		{
		    print OUTPUTFILE "Updating Service Order $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
		    $dbh->do($sql4);
		}
		else
		{
		    print OUTPUTFILE "Found Service Order $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
		}
	    };
	    if ($@)
	    {
		print ERRORFILE "Error updating $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
	    }
	    else
	    {
		$update_count++;
	    }
	}
	# Attempt to update the value from DD-MON-YY format
	
	elsif ($seoa_defaultvalue =~ /^\d{1,2}-\w{3}-\d{1,4}$/)
	{
	    eval
	    {
		my $sql4 = "update service_order_attributes
			    set seoa_defaultvalue = 
			    (select to_char((select to_date('$seoa_defaultvalue', 'DD-MM-RR') from dual), 'DD-MON-YYYY') from dual)
			where seoa_id = '$seoa_id'";
		if ($update eq "yes")
		{
		    print OUTPUTFILE "Updating Service Order $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
		    $dbh->do($sql4);
		}
		else
		{
		    print OUTPUTFILE "Found Service Order $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
		}
	    };
	    if ($@)
	    {
		print ERRORFILE "Error updating $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
	    }
	    else
	    {
		$update_count++;
	    }
	}
	# Attempt to update the value from DD.MON.YY format
	
	elsif ($seoa_defaultvalue =~ /^\d{1,2}\.\w{3}\.\d{1,4}$/)
	{
	    eval
	    {
		my $sql4 = "update service_order_attributes
			    set seoa_defaultvalue = 
			    (select to_char((select to_date('$seoa_defaultvalue', 'DD.MM.RR') from dual), 'DD-MON-YYYY') from dual)
			where seoa_id = '$seoa_id'";
		if ($update eq "yes")
		{
		    print OUTPUTFILE "Updating Service Order $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
		    $dbh->do($sql4);
		}
		else
		{
		    print OUTPUTFILE "Found Service Order $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
		}
	    };
	    if ($@)
	    {
		print ERRORFILE "Error updating $seoa_sero_id, $seta_name value $seoa_defaultvalue - $@\n";
	    }
	    else
	    {
		$update_count++;
	    }
	}
	
	# Try it in the default format
	else
	{
	    eval
	    {
		my $sql4 = "update service_order_attributes
			    set seoa_defaultvalue = 
			    (select to_char((select to_date('$seoa_defaultvalue', 'DDMMRR') from dual), 'DD-MON-YYYY') from dual)
			where seoa_id = '$seoa_id'";
		if ($update eq "yes")
		{
		    print OUTPUTFILE "Updating Service Order $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
		    $dbh->do($sql4);
		}
		else
		{
		    print OUTPUTFILE "Found Service Order $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
		}
	    };
	    if ($@)
	    {
		print ERRORFILE "Error updating $seoa_sero_id, $seta_name value $seoa_defaultvalue\n";
	    }
	    else
	    {
		$update_count++;
	    }	
	}
    }    
}

# Finish up by disconnecting.

$dbh->disconnect();
   
print OUTPUTFILE "\n***Run finished - $update_count records updated\n";
close OUTPUTFILE or die "Error closing run-serv-type-output.txt - $!\n";
print ERRORFILE "\n***Run finished ***\n";
close ERRORFILE or die "Error closing run-serv-type-error.txt - $!\n";

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
