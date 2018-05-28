#!/pkgs/bin/perl

######################################################
# atmfr.pl - Extract config data to load a ATM/FR PVC
# Service Order into InfoVista
#
# Created:      February 18, 2002
# Author:       Bart Masters
# Version:      1.6
#
# This program is used to load config data from BIOSS
# into InfoVista.  It is called with a Service Order 
# ID, and it will scan through the circuits table for 
# all Frame Relay and ATM PVCs that belong to that SO.
#
# If a PVC is missing some data, it will be listed in
# an error report for chasing up.
#
# Version History
# ---------------
# 0.1	Initial Release
# 1.0	Production release
# 1.1	Enable extractions of bpx-bpx circuits
# 1.2   Bug fix in extraction of bpxes in getEndPorts
# 1.3	Remove () and , from customer names to enable
#	VPSE export to run faster
# 1.4	Fix bug with extraction of IGX FR PVCs.
# 1.5	Renamed from servorder.pl to atmfr.pl to 
#	emphasise its change in function from generic
#	service orders to ATM/FR PVCs specifically
# 1.6	Added in ability to recognise a PVC that is
#	accessed via a POP router, and trace the PVC
#	all the way to the A/B end.
#
######################################################
#	Network Application AAPT Limited
#
#	File:		$RCSfile: atmfr.pl,v $
#	Source:		$Source: /pace/ProdSRC/infovista/cvs/glbncs4/bin/atmfr.pl,v $
#
#	ChangedBy:	$Author: bamaster $
#	ChangedDate:	$Date: 2006/03/30 03:53:36 $
#
#	Version:	$Revision: 1.15 $
######################################################
#	RCS Log:	$Log: atmfr.pl,v $
#	RCS Log:	Revision 1.15  2006/03/30 03:53:36  bamaster
#	RCS Log:	Remove One Office changes - no longer required
#	RCS Log:	
#	RCS Log:	Revision 1.14  2006/03/27 03:40:29  bamaster
#	RCS Log:	Remove Oneoffice processing until its tested
#	RCS Log:	
#	RCS Log:	Revision 1.13  2006/03/27 03:17:19  bamaster
#	RCS Log:	Changes for Bioss Upgrades project
#	RCS Log:	
#	RCS Log:	Revision 1.12  2004/06/24 04:16:51  bamaster
#	RCS Log:	Introducing Platinum reporting
#	RCS Log:	
#	RCS Log:	Revision 1.11  2004/06/16 04:30:22  syang
#	RCS Log:	added tefi_tablename and restructure sql conditions to enhance the sql performance
#	RCS Log:	
#	RCS Log:	Revision 1.10  2004/06/07 01:00:45  syang
#	RCS Log:	Reuse output format that defined for extra circuit info for SNMP Trap
#	RCS Log:	
######################################################

use strict;		# Be good, lil program
use DBI;		# Database connection module
use Getopt::Std;	# Process command line options

# Global Variables

my %cmds;		# Command line options
my $params = "p:f:e:";	# Valid command line options
my $sero_id;		# Service Order to process
my $run_path;
my $poller;
my $sero_cirt_name;
my $end_file_name;
my $debugging_info;	# String for storing debugging information

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

if (defined $cmds{p})
{
    $poller = $cmds{p};
}
else
{
    $poller = "glb";
}

if (defined $cmds{e})
{
    $end_file_name = $cmds{e};
}
else
{
    $end_file_name = "../files/atmfr.end." . $poller;
}

# Connect to the database

my $dbh = dbconnect();
	
# Get the list of product types

my $filename = $run_path . "/files/pvc-prod-type.file";
open (PRODFILE, "$filename") or die "Error opening $filename $!\n";
chomp (my @prod_type = <PRODFILE>);
close PRODFILE;
my $prod_list = join (',', map {"?"} @prod_type);

# Get the list of customers to process

$filename = $run_path . "/files/${poller}_customer.file";
open (CUSTFILE, "$filename") or die "Error opening $filename $!\n";
chomp (my @custname = <CUSTFILE>);
close CUSTFILE;
my $cusr_list = join (',', map {"?"} @custname);
  
# Work through the list of customers/products

my $sql =	"select	 sero_id
			,sero_cirt_name	
		 from	 service_orders
	 		,circuits
		 where	 sero_cirt_name like '%PVC%'
		 and	 sero_sert_abbreviation in ($prod_list)
		 and	 sero_stas_abbreviation in ('APPROVED','CLOSED')
		 and	 sero_cirt_name = cirt_name
		 and	 cirt_status = 'INSERVICE'
		 and	 sero_cusr_abbreviation in ($cusr_list)
		 order by sero_cirt_name asc, 
			  sero_id desc";

my $sth = $dbh->prepare($sql);
$sth->execute(@prod_type, @custname);

my @cust_info;
my $last_processed_circuit = "";

while (@cust_info = $sth->fetchrow_array)
{
    $sero_id = $cust_info[0];
    $sero_cirt_name = $cust_info[1];
   
# Firstly check if we've already processed this circuit.  Since we don't check the 
# service order type - we could get duplicate circuits.  This way we only process
# the most recent service order/circuit.

    if ($sero_cirt_name eq $last_processed_circuit)
    {
	next;
    }

    $last_processed_circuit = $sero_cirt_name;

# If the circuit name has apostraphes, turn them into double apostraphes - otherwise
# Oracle cries.

    my $sql_cirt_name = $sero_cirt_name;
    $sql_cirt_name =~ s/'/''/;
	
    my $sql =	"select	 seti_value
		 from	 circuits
			,service_template_instance
		 where	 cirt_name = ?
		 and	 seti_tablename = 'CIRCUITS'
		 and	 seti_name = ?
		 and	 seti_tableid = cirt_name";

    my $lci = 'L CIR';
    my $rci = 'R CIR';
    my $sth;
    my $l_cir;
    my $r_cir;

    $sth = $dbh->prepare($sql);
    $sth->execute($sql_cirt_name,$lci);
    $l_cir = $sth->fetchrow_array;
    $sth->execute($sql_cirt_name,$rci);
    $r_cir = $sth->fetchrow_array;

# If theres nothing in L or R CIR, set them to 0.  Just to stop those annoying
# undefined field error messages.

    unless (defined $l_cir)
    {
        $l_cir = 0;
    }
    unless (defined $r_cir)
    {
        $r_cir = 0;
    }
    if (($l_cir == 4) and
        ($r_cir == 4))
    {
# We don't process circuits with CIR of 4 - they are management circuits
   	next
    }

# Finally, process the PVCs
    processPVC($sero_cirt_name, $sero_id);
}

# Finish up by disconnecting and creating the file to say so.

$dbh->disconnect();

my $command = "touch $end_file_name";
my $rc = system("$command");
exit 0;

#-----------------------------
# Subroutines
#-----------------------------
# checkForIPVPN - Check if a Circuit is an IP-VPN.
#
# Parameters:	Circuit Name
#
# Returns:	Yes, No or Error.

sub checkForIPVPN
{
    my $sero_cirt_name = shift;

# IP-VPN circuits that don't terminate on a Stratacom
# switch (ie a BPX, IGX or MGX) are valid circuits that
# do not need to be extracted and processed by this
# program.  So check all the ports which can be found on
# the circuit being processed - if none of them are 
# Stratacome ports, and we have 1 PE port, and a 
# CE or UM router - its a valid IP-VPN circuit, so don't
# process it, but continue onto the next circuit.

    my $sql = 	"select  port_id
			,equp_equt_abbreviation
		 from 	 ports
			,equipment
		 where	 port_cirt_name = '$sero_cirt_name'
		 and	 port_status = 'INSERVICE'
		 and	 port_equp_id = equp_id";
    my $port_list_refs = $dbh->selectall_arrayref($sql);

    my $stratacom_found_flag = "NO";
    my $rtrpe_found_flag = "NO";
    my $rtrceum_found_flag = "NO";

    $debugging_info .= "\tChecking if the circuit is an IPVPN\n";

    foreach (@{$port_list_refs})
    {
	my $port_dets = getPortDetails($_->[0]);
	if (($_->[1] eq "BPX") or
	    ($_->[1] eq "IGX") or
	    ($_->[1] eq "MGX"))
	{
	    $debugging_info .= "\tFound a Stratacom port $port_dets\n";
	    $stratacom_found_flag = "YES";
	    last;
	}
	elsif ($_->[1] eq "RTRPE")
	{
	    $debugging_info .= "\tFound a RTRPE port $port_dets\n";
	    $rtrpe_found_flag = "YES";
	}
	elsif (($_->[1] eq "RTRCE") or
		($_->[1] eq "RTRUM"))
	{
	    $debugging_info .= "\tFound a CE or UM port $port_dets\n";
	    $rtrceum_found_flag = "YES";
	}

    }

    if ($stratacom_found_flag eq "YES")
    {
	$debugging_info .= "\tAt least one Port is a Stratacom, so treating this as a FR/ATM circuit.\n";
	return "NO";
    }
    if ($rtrpe_found_flag eq "YES")
    {
	if ($rtrceum_found_flag eq "YES")
	{
	    $debugging_info .= "\tDidnt find any Stratacom ports, and found a PE port and a CE or UM port, so treating this as a IP-VPN circuit and skipping extraction of this circuit.\n";
	    return "YES";
	}
	else
	{
	    $debugging_info .= "\tCouldn't find any Stratacom ports, found a PE port, but couldnt find a CE or UM port.  Rejecting this circuit.\n";
	    return "ERROR";
	}
    }
    
# If we've got this far, we can't find any Stratacom
# ports, and we cant find 1 PE and 1 CE or UM port, so
# this circuit is invalid.

    $debugging_info .= "\tCouldn't find any Stratacom ports and couldnt find any PE ports.  Rejecting this circuit.  Examine the crossconnect ports that you believe are valid end points - check the port definition on the Network Element - both that the port is in service, and that the circuit name is $sero_cirt_name\n";
    return "ERROR";
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

    my $dbh = DBI->connect($source, $userid, $password, { RaiseError => 1, AutoCommit => 0});
    return $dbh;
}
# currdate - Get the current date and massage it into a nice
# format for creating the output files.
#
# Parameters:	None
#
# Returns:	Current Date

sub currdate
{
    my ($m, $d, $h, $mi, $se) = (localtime)[4,3,2,1,0];
    $m += 1;

    my $date = sprintf("%02d%02d%02d%02d%02d", $d, $m, $h, $mi, $se);

    return $date;
}
# followBearers - Follow the path of a circuit's bearers until
# we get to the end of the circuit.
#
# Parameters:	Port ID, Circuit Name, A end, B end
#
# Returns:	Found Flag, Port ID

sub followBearers
{
    my $start_port_id = shift;
    my $sero_cirt_name = shift;
    my $aend_locn = shift;
    my $bend_locn = shift;

# First get the parent circuit/bearer.

    my ($bearer_orig_port,$bearer) = getParentCircuit($start_port_id);

# Get all the ports on that bearer.
    
    my $sql = 	"select	 port_id
		 from 	 ports
		 where 	 port_cirt_name = '$bearer'";

    my $ports_ref = $dbh->selectall_arrayref($sql);

# Now get all ports on the bearer which aren't our original
# end/port.

    my @bearer_ports;
    foreach (@{$ports_ref})
    {
	unless ($_->[0] == $bearer_orig_port)
	{
	    push (@bearer_ports, $_->[0]);
	}
    }

# Now we have to get the other end of the bearer - first see
# how many ports are left.  If theres only one, we have it.

    my $bearer_child_port;
    if (@bearer_ports == 1)
    {
	$bearer_child_port = getChildPort($bearer_ports[0], $sero_cirt_name);
    }
    else
    {
# We have more than one port, see if we can narrow this down to one.
# Work through the array, and get the child port for each port on
# the bearer.  If it doesn't have a child, its an intermediate port,
# so remove it from the array.

	my @new_bearer_ports;
	foreach (@bearer_ports)
	{
	    if (getChildPort($_, $sero_cirt_name))
	    {
		push (@new_bearer_ports, $_);
	    }
	}
   
	if (@new_bearer_ports == 1)
	{
	    $bearer_child_port = getChildPort($new_bearer_ports[0], $sero_cirt_name);
	}
	else
	{
# All righty, we've still got multiple ports.  Lets now match on 
# vci/dlci numbers.  The two 'true' end ports of the bearer have the same
# vci/dlci - lets match based on that.

	    $sql =	"select	 port_name
			 from	 ports
			 where	 port_id = ?";

	    my $sth = $dbh->prepare($sql);
	    $sth->execute($start_port_id);
	    my $result = $sth->fetchrow_array;

	    $result =~ /(^.*\b)(\d+)\/(\d+)/;
	    my $orig_dlci = $3;

	    foreach (@new_bearer_ports)
	    {
		my $new_child = getChildPort($_, $sero_cirt_name);
		
		$sth->execute($new_child);
		my $bearer_result = $sth->fetchrow_array;
		
		$bearer_result =~ /(^.*\b)(\d+)\/(\d+)/;
		my $bearer_dlci = $3;

		if ($orig_dlci == $bearer_dlci)
		{
		    $bearer_child_port = $new_child;
		    last;
		}
	    }
# If we still can't work em out after all that, give up.

	    unless (defined $bearer_child_port)
	    {
		return "N";
	    }
	}
    }

# We finally have the child port on the other end of the bearer.
# Check if its at the end of the circuit.

    $sql =	"select	 locn_ttname
		 from	 ports
	 		,equipment
	 		,locations
		 where	 port_id = '$bearer_child_port'
		 and	 port_equp_id = equp_id
		 and	 equp_locn_ttname = locn_ttname";
    
    my $aend_locn_name = getLocnName($aend_locn);
    my $bend_locn_name = getLocnName($bend_locn);
    
    my @end_port_locn = $dbh->selectrow_array($sql);
    if ($end_port_locn[0] eq $aend_locn_name)
    {
	return "A";
    }
    elsif ($end_port_locn[0] eq $bend_locn_name)
    {
	return "B";
    }
    else
    {
# This port isn't at an end, get the other side of the cross-
# connect, and return its port ID, so we can do this all again.

	$sql =	"select	 polp_porl_id
		 from	 port_link_ports
		 where	 polp_port_id = '$bearer_child_port'";

        my $polp_porl_id = $dbh->selectrow_array($sql);

	$sql = "select	 polp_port_id
		from	 port_link_ports
		where	 polp_porl_id = '$polp_porl_id'
		and	 polp_port_id != '$bearer_child_port'";
	
	my $polp_port_id = $dbh->selectrow_array($sql);
        return "0", $polp_port_id;
    }
}
# getAddr - Get an address.
# Use number, street and suburb.
#
# Parameters:	Location ID
#
# Returns:	Address.

sub getAddr
{
    my $locn_id = shift;

    my $sql =	"select	 nvl(locn_number, ' ')
			,nvl(locn_street, ' ')
			,nvl(locn_strt_name, ' ')
			,nvl(locn_suburb, ' ')
		 from	 locations
		 where	 locn_id = '$locn_id'";

    my @result = $dbh->selectrow_array($sql);
    my $address = $result[0] . " " . $result[1] . " " . $result[2] . ", " . $result[3];
    return $address;
}
# getCardNo - Get the Card Number for a Port.
#
# Parameters:	Port ID
#
# Returns:	Card Number

sub getCardNo
{
    my $port_id = shift;
    my $sql =	"select	 port_card_slot
		 from	 ports
		 where	 port_id = '$port_id'";

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my $card_no = $sth->fetchrow_array;

    return $card_no;
}
# getChildPort - Get a Child Port.
#
# Parameters:	Port ID
#
# Returns:	Card Number

sub getChildPort
{
    my $port_id = shift;
    my $sero_cirt_name = shift;
    
    my	$sql =	"select  porh_childid
		 from	 ports
			,port_hierarchy
		 where	 porh_parentid = '$port_id'
		 and	 port_id = porh_childid
		 and	 port_cirt_name = '$sero_cirt_name'";

    my $return = $dbh->selectrow_array($sql);

    return $return;
}
# getCustName - Get the Customer Name/ID.
#
# Parameters:	Service Order ID
#
# Returns:	Customer Name, Customer ID

sub getCustName
{
    my $sero_id = shift;
    my $sql = 	"select	 cusr_name,
			 cusr_abbreviation
		 from 	 service_orders
	 		,customer
		 where 	 sero_id = '$sero_id'
		 and	 cusr_abbreviation = sero_cusr_abbreviation";

    my @result = $dbh->selectrow_array($sql);

    if (defined $result[0])
    {
	my $cusr_name = $result[0];
	my $cusr_abbreviation = $result[1];
	$cusr_name =~ s/,/ /g;
	$cusr_name =~ s/\(/ /g;
	$cusr_name =~ s/\)/ /g;
	$cusr_name =~ s/\s+$//;
	return $cusr_name, $cusr_abbreviation;
    }
    else
    {
	return;
    }
}
# getDLCI - Get the Port's DLCI.
#
# Parameters:	Port ID
#
# Returns:	DLCI

sub getDLCI
{
    my $port_id = shift;
    my $sql =	"select	 port_name
		 from	 ports
		 where	 port_id = '$port_id'";

    my $result = $dbh->selectrow_array($sql);

# Port name is in the format aaa-n xxx/yyy - we only want
# the yyy bit with no leading zeroes.

    my $sp = $result;
    $sp =~ /(^.*\b)(\d+)\/(\d+)/;
    my $dlci = $3;

# We do the sillybuggers with the numbers to strip any leading zeroes
# from the DLCI.

    $dlci *= 10;
    $dlci /= 10;

    return $dlci;
}
# getABEnd - Get the A and B end address locations
# from a service order.
#
# Parameters:	Service Order ID
#
# Returns:	A end Location ID
#		B end Location ID

sub getABEnd
{
    my $sero_id = shift;
    my $sql = 	"select	 sero_locn_id_aend
			,sero_locn_id_bend
		 from 	 service_orders
		 where 	 sero_id = '$sero_id'";

    my @result = $dbh->selectrow_array($sql);
    return @result[0,1];
}
# getEndPorts - Get the ends of a circuit.
#
# Parameters:	Circuit Name
#
# Returns:	Array that lists all the
# available ends.

sub getEndPorts
{
    my $sero_cirt_name = shift;
    my @end_ports;
    my @debugging_port_array;

# First check if the circuit being processed is a
# IP/VPN - if it is stop processing it.

    my $is_a_IPVPN = checkForIPVPN($sero_cirt_name);
    if ($is_a_IPVPN eq "YES")
    {
	push (@end_ports, "SKIP");
	return \@end_ports;
    }
    elsif ($is_a_IPVPN eq "ERROR")
    {
	push (@end_ports, "ERROR");
	return \@end_ports;
    }

# Get all the PVC ports

    $debugging_info .= "\tGetting all the end points of the circuit.  \n\tFirst getting all inservice PVC and DLCI circuits that are on an IGX or MGX.\n";

    my $sql =	"select	 port_id
		 from	 ports
	 		,equipment
		 where 	 port_cirt_name = '$sero_cirt_name'
		 and	 port_usage in ('PVC','DLCI')
		 and	 port_status = 'INSERVICE'
		 and	 port_equp_id = equp_id
		 and	 equp_equt_abbreviation in ('IGX','MGX')";
    my $port_refs = $dbh->selectall_arrayref($sql);

    foreach (@{$port_refs})
    {
	my $port_dets = getPortDetails($_->[0]);
	push (@debugging_port_array, $port_dets . "\n");
	$debugging_info .= "\t\tFound the following PVC or DLCI port, treating it as an end point of the circuit - $port_dets.\n";
	push(@end_ports, $_->[0]);
    }

# Get all the VCI ports.

    $debugging_info .= "\tNow getting all inservice VCI ports.\n";

    $sql =	"select	 port_id
			,card_name
			,equp_equt_abbreviation
			,port_name
		 from	 ports
	 		,equipment
	 		,cards
		 where	 port_cirt_name = '$sero_cirt_name'
		 and	 port_usage = 'VCI'
		 and	 port_status = 'INSERVICE'
		 and	 port_card_slot = card_slot
		 and	 card_equp_id = equp_id
		 and	 port_equp_id = equp_id";
    my $VCI_refs = $dbh->selectall_arrayref($sql);

    foreach (@{$VCI_refs})
    {
	my @VCI_port = @{$_};

# A VCI that terminates on a RPM card is a valid end
# point.

	if ($VCI_port[1] eq 'RPM')
    	{
	    my $port_dets = getPortDetails($_->[0]);
	    push (@debugging_port_array, $port_dets . "\n");
	    $debugging_info .= "\t\tFound the following VCI port terminating on a RPM card, treating it as an end point of the circuit - $port_dets.\n";
	    push(@end_ports, $VCI_port[0]);
	}

# A VCI that terminated on an A1/A3 ATM Interface on a
# BRAS is a valid end point.

	if ($VCI_port[2] eq 'BRAS' &&
		$VCI_port[3] =~ /^(A1|A3)/)
	{
	    my $port_dets = getPortDetails($_->[0]);
	    push (@debugging_port_array, $port_dets . "\n");
	    $debugging_info .= "\t\tFound the following VCI port terminating on a BRAS card and its an A1 or A3 port, so treating it as an end point of the circuit - $port_dets.\n";
	    push(@end_ports, $VCI_port[0]);
	}
    }

# Check how many ports we have - if we have zero or one, 
# lets check and see if theres a BPX involved. 

    my $array_size = scalar(@end_ports);

    if ($array_size == 0)
    {
	$debugging_info .= "\tNo valid PVC or DLCI ports have been found, so checking BPX ports to see if any of these are valid points of the circuit.  For a BPX port to be valid it must be Inservice and have a usage of VCI.\n";
# We can't find any valid points.  Lets see if we can find
# 2 valid BPX points.

# Get all the BPX ports.

        $sql =	"select	 port_id
		 from	 ports
	 		,equipment
		 where	 port_cirt_name = '$sero_cirt_name'
		 and	 port_usage = 'VCI'
		 and	 port_status = 'INSERVICE'
		 and	 port_equp_id = equp_id
		 and	 equp_equt_abbreviation = 'BPX'";
	my $BPX_refs = $dbh->selectall_arrayref($sql);
        foreach (@{$BPX_refs})
	{
	    my $port_dets = getPortDetails($_->[0]);
	    push (@debugging_port_array, $port_dets . "\n");
	    $debugging_info .= "\t\tFound the following VCI port on a BPX, so treating it as an end point of the circuit - $port_dets.\n";
	    push(@end_ports, $_->[0]);
        }
    }
    elsif ($array_size == 1)
    {
	$debugging_info .= "\tOnly one PVC or DLCI port has been found, attempting to find a BPX port on the other end of the circuit.  It must be inservice and on a BPX to be valid.\n";
# We found only one port - lets see if we can find a BPX at
# the other end.

# First get the sequence number of the one port we've got.
# We then get the smallest squence number less than that
# port, or the largest sequence number greater than that
# port.  That make sense?

        $sql =	"select	 porl_sequence
		 from	 port_link_ports
			,port_links
		 where	 polp_port_id = '$end_ports[0]'
		 and	 porl_id = polp_porl_id";
		 
	my $curr_port_seq = $dbh->selectrow_array($sql);
    
        $sql =	"select  min(porl_sequence)
		 from	 ports
			,port_link_ports
			,port_links
			,equipment
		 where	 port_cirt_name = '$sero_cirt_name'
		 and	 port_status = 'INSERVICE'
		 and	 porl_sequence < '$curr_port_seq'
		 and	 port_id = polp_port_id
		 and	 porl_id = polp_porl_id
		 and	 port_equp_id = equp_id
		 and	 equp_equt_abbreviation = 'BPX'";
		 
	my $seq_nbr = $dbh->selectrow_array($sql);

        my $port_sql =	"select	 port_id
			 from	 ports
				,port_link_ports
				,port_links
				,equipment
			 where	 port_cirt_name = '$sero_cirt_name'
			 and	 port_status = 'INSERVICE'
			 and	 port_equp_id = equp_id
			 and	 equp_equt_abbreviation = 'BPX'
			 and	 port_id = polp_port_id
			 and	 porl_id = polp_porl_id
			 and	 porl_sequence = ?";

        my $sth = $dbh->prepare($port_sql);
	$sth->execute($seq_nbr);
        my $bpx_port_id = $sth->fetchrow_array;

# If the min BPX port exists, add it to the array, and return.

        if (defined $bpx_port_id)
	{
	    my $port_dets = getPortDetails($bpx_port_id);
	    push (@debugging_port_array, $port_dets . "\n");
	    $debugging_info .= "\t\tFound the following port on a BPX, so treating it as an end point of the circuit - $port_dets.\n";
	    push(@end_ports, $bpx_port_id);
	    return \@end_ports;
        }

# Min doesn't exist, so try max sequence.
	
	$sql =	"select  max(porl_sequence)
		 from	 ports
			,port_link_ports
			,port_links
			,equipment
		 where	 port_cirt_name = '$sero_cirt_name'
		 and	 port_status = 'INSERVICE'
		 and	 porl_sequence > '$curr_port_seq'
		 and	 port_id = polp_port_id
		 and	 porl_id = polp_porl_id
		 and	 port_equp_id = equp_id
		 and	 equp_equt_abbreviation = 'BPX'";
		 
        $seq_nbr = $dbh->selectrow_array($sql);

	$port_sql =	"select	 port_id
			 from	 ports
				,port_link_ports
				,port_links
				,equipment
			 where	 port_cirt_name = '$sero_cirt_name'
			 and	 port_status = 'INSERVICE'
			 and	 port_equp_id = equp_id
			 and	 equp_equt_abbreviation = 'BPX'
			 and	 port_id = polp_port_id
			 and	 porl_id = polp_porl_id
			 and	 porl_sequence = ?";
        
	$sth = $dbh->prepare($port_sql);
	$sth->execute($seq_nbr);
        $bpx_port_id = $sth->fetchrow_array;

# If the max BPX port exists, add it to the array.

	if (defined $bpx_port_id)
        {
	    my $port_dets = getPortDetails($bpx_port_id);
	    push (@debugging_port_array, $port_dets . "\n");
	    $debugging_info .= "\t\tFound the following port on a BPX, so treating it as an end point of the circuit - $port_dets.\n";
	    push(@end_ports, $bpx_port_id);
        }
    }

# And thats all the valid end points, so return what
# port IDs we have.

    $debugging_info .= "\n\tFinished checking end ports - the following ports have been found - if there are not 2 ports here we have an error:\n";
    foreach (@debugging_port_array)
    {
	$debugging_info .= "\t\t" . $_;
    }
    
    return \@end_ports;
}
# getLocnName - Get a location's name.
#
# Parameters:	Location ID
#
# Returns:	Location name.

sub getLocnName
{
    my $locn_id = shift;
    my $sql =	"select	 locn_ttname
		 from	 locations
		 where	 locn_id = '$locn_id'";

    my $result = $dbh->selectrow_array($sql);
    return $result;
}
# getParentCircuit - Get a port's parent circuit.
#
# Parameters:	Port ID
#
# Returns:	Parent Circuit Port ID, Circuit Name

sub getParentCircuit
{
    my $port_id = shift;
    my $sql = 	"select	 port_id
			,port_cirt_name
		 from 	 ports
	 		,port_hierarchy
		 where 	 porh_childid = ?
		 and	 port_id = porh_parentid";

    my $sth = $dbh->prepare($sql);
    my @result;

# Logical ports can be defined as not having a circuit.  In
# this case, get their parent.  Keep going til we get a circuit.

    until (defined ($result[1]))
    {
	$sth->execute($port_id);
	@result = $sth->fetchrow_array();
	$port_id = $result[0];

# If the port_id doesn't exist, we've got to the top of the
# port hierarchy without finding a circuit, so exit.
	unless (defined $port_id)
	{
	    last;
	}
    }
    return $result[0], $result[1];
}
# getPortID - Get the two Port IDs for a circuit.
#
# Due to the way BIOSS stores the ends of a PVC, this
# is a reasonably tortuous process - there is no simple
# way of storing the end ports of a circuit.
#
# Parameters:	Circuit Name, A and B end locations
#
# Returns:	A end and B end Port IDs

sub getPortID
{
    my $sero_cirt_name = shift;
    my $aend_locn = shift;
    my $bend_locn = shift;

    my $aend_port_id;
    my $bend_port_id;

    my $end_port_id = getEndPorts($sero_cirt_name);

# Check if there was an error getting the end points for the circuit.

    if ($end_port_id->[0] eq 'SKIP')
    {
	return 'SKIP';
    }
    elsif ($end_port_id->[0] eq 'ERROR')
    {
	return 'ERROR', '103';
    }

# Check how many end ports we have.  If its not 2, we
# have an error.

    if (@$end_port_id != 2)
    {
	return 'ERROR', 103;
    }

    my $end_port_one = $end_port_id->[0];
    my $end_port_two = $end_port_id->[1];

# Time to work out which port belongs to which end of
# the circuit.  First, try to find an access bearer to
# connect to one port.  Get the parent circuit for a 
# particular port, if it contains the A or B end, then that
# port is the appropriate end, and the other port is the
# other end.

# $blank is a blank scalar, we don't need it here.

    my $aend_locn_name = getLocnName($aend_locn);
    my $bend_locn_name = getLocnName($bend_locn);
    my ($blank, $parent_circuit) = getParentCircuit($end_port_one);

    my $sql =	"select	 locn_ttname
			,locn_state
		 from	 ports
	 		,equipment
	 		,locations
		 where	 port_id = ?
		 and	 port_equp_id = equp_id
		 and	 equp_locn_ttname = locn_ttname";
    my $sth = $dbh->prepare($sql);
    $sth->execute($end_port_one);
    my @end_port_one_locn = $sth->fetchrow_array;
	
    $sth->execute($end_port_two);
    my @end_port_two_locn = $sth->fetchrow_array;
	
    unless (defined $end_port_one_locn[0] &&
		defined $end_port_two_locn[0])
    {
	return 'ERROR', 104;
    }
    
# Once we have the parent circuit, remove the end port's location from it.
# This means we are left with the other end of the parent circuit.  If the
# other end is the A or B end, then that is a match.

    $parent_circuit =~ s/$end_port_one_locn[0]//;

    if ($parent_circuit =~ /$aend_locn_name/)
    {
	$aend_port_id = $end_port_one;
	$bend_port_id = $end_port_two;
    }
    elsif ($parent_circuit =~ /$bend_locn_name/)
    {
	$bend_port_id = $end_port_one;
	$aend_port_id = $end_port_two;
    }
    else
    {
	($blank, $parent_circuit) = getParentCircuit($end_port_two);
	$parent_circuit =~ s/$end_port_two_locn[0]//;

	if ($parent_circuit =~ /$aend_locn_name/)
	{
	    $aend_port_id = $end_port_two;
	    $bend_port_id = $end_port_one;
	}
	elsif ($parent_circuit =~ /$bend_locn_name/)
	{
	    $bend_port_id = $end_port_two;
	    $aend_port_id = $end_port_one;
	}
    }

    if (defined $aend_port_id)
    {
	return $aend_port_id, $bend_port_id;
    }

# Since we can't get the bearer, lets check if they're in
# different states.  If they are, then we can use that.

    if ($end_port_one_locn[1] ne $end_port_two_locn[1])
    {
# The states are different, so we can work out which end of the
# circuit belongs to which port, by matching the states.

	my $aend_state = getState($aend_locn);
	my $bend_state = getState($bend_locn);

	if ($aend_state eq $end_port_one_locn[1])
	{
	    $aend_port_id = $end_port_one;
	    $bend_port_id = $end_port_two;
	}
	elsif ($aend_state eq $end_port_two_locn[1])
	{
	    $aend_port_id = $end_port_two;
	    $bend_port_id = $end_port_one;
    	}
	else
	{
# The A end state doesn't match either port's state,
# so raise an error.
	    return 'ERROR', 106;
	}
    }

    if (defined $aend_port_id)
    {
	return $aend_port_id, $bend_port_id;
    } 

# Next step is to work our way along the bearers.  This happens
# when an end point isn't directly connected to a MGX, but 
# connects via a POP router or the like.  First check end port one.

    my $searched_port_id = $end_port_one;
    my $got_end_point = "0";

# We put the stop loop bit in to stop endless loops - just in case
# there is an unknown weird combination of bearers in the database.

    my $stop_loop = 0;
    until ($got_end_point)
    {
        ($got_end_point, $searched_port_id) = followBearers($searched_port_id, $sero_cirt_name, $aend_locn, $bend_locn);
	
	$stop_loop++;
	if ($stop_loop > 20)
	{
	    $got_end_point = "N";
	}
    }
    
    if ($got_end_point eq "A")
    {
        $aend_port_id = $end_port_one;
        $bend_port_id = $end_port_two;
    }
    elsif ($got_end_point eq "B")
    {
        $bend_port_id = $end_port_one;
        $aend_port_id = $end_port_two;
    }
    else
    {
	$searched_port_id = $end_port_two;
	$got_end_point = "0";
	    
	$stop_loop = 0;
	until ($got_end_point)
	{
	    ($got_end_point, $searched_port_id) = followBearers($searched_port_id, $sero_cirt_name, $aend_locn, $bend_locn);
	    
	    $stop_loop++;
	    if ($stop_loop > 20)
	    {
		$got_end_point = "N";
	    }
	}
	
	if ($got_end_point eq "A")
	{
	    $aend_port_id = $end_port_two;
	    $bend_port_id = $end_port_one;
	}
	elsif ($got_end_point eq "B")
	{
	    $bend_port_id = $end_port_two;
	    $aend_port_id = $end_port_one;
	}
	else
	{
# We can't work out which end is which, so we have to create error
	    return 'ERROR', 107;
	}
    }

    return $aend_port_id, $bend_port_id;
}
# getPortDetails - Get some port details.
#
# Parameters:	Port ID
#
# Returns:	Equipment Location, 
#		Equipment Type,
#		Equipment Index,
#		Port Card Slot,
#		Port Name.

sub getPortDetails
{
    my $port_id = shift;

    my $sql =	"select	 equp_locn_ttname
			,equp_equt_abbreviation
			,equp_index
			,port_card_slot
			,port_name
		 from	 equipment
			,ports
			,locations
		 where	 equp_id = port_equp_id
		 and	 equp_status = 'INSERVICE'
		 and	 equp_locn_ttname = locn_ttname
		 and	 port_id = '$port_id'";

    my @selection = $dbh->selectrow_array($sql);
    my $result = @selection[0] . " " .
		 @selection[1] . " " .
		 @selection[2] . " " .
		 @selection[3] . " " .
		 @selection[4];
    return $result;
}
# getPortLocn - Get a port's location.
#
# Parameters:	Port ID
#
# Returns:	Location ID.

sub getPortLocn
{
    my $port_id = shift;

    my $sql =	"select	 locn_id
		 from	 equipment
			,ports
			,locations
		 where	 equp_id = port_equp_id
		 and	 equp_status = 'INSERVICE'
		 and	 equp_locn_ttname = locn_ttname
		 and	 port_id = '$port_id'";

    my $result = $dbh->selectrow_array($sql);
    return $result;
}
# getPortNo - Get the Port's Number.
#
# Parameters:	Port ID
#
# Returns:	Port Number

sub getPortNo
{
    my $port_id = shift;
    my $sql =	"select	 port_name
		 from	 ports
		 where	 port_id = '$port_id'";

    my $result = $dbh->selectrow_array($sql);

# Port name is in the format aaa-n xxx/yyy - we only want
# the xxx bit with no leading zeroes.

    my $sp = $result;
    $sp =~ /(^.*\b)(\d+)\/(\d+)/;
    my $port_no = $2;

# We do the sillybuggers with the numbers to strip any leading zeroes
# from the port index.

    $port_no *= 10;
    $port_no /= 10;

    return $port_no;
}
# getPortType - Get the Port's Type (dedicated or shared).
#
# Parameters:	Port ID
#
# Returns:	Port Type

sub getPortType
{
    return "Dedicated";
}
# getPVCNo - Get the PVC's Number.
#
# Parameters:	Port ID
#
# Returns:	PVC Number

sub getPVCNo
{
    my $port_id = shift;
    my $sql =	"select	 port_name
		 from	 ports
		 where	 port_id = '$port_id'";

    my $result = $dbh->selectrow_array($sql);

# Port name is in the format aaa-n xxx/yyy - we only want
# the -n bit with no leading zeroes.

    my $sp = $result;
    $sp =~ /(^.*)\-(\d+) (\d+)\/(\d+)/;
    my $pvc_no = $2;

# We do the sillybuggers with the numbers to strip any leading zeroes
# from the pvc number.

    $pvc_no *= 10;
    $pvc_no /= 10;
    
    return $pvc_no;
}
# getState - Get a location's state.
#
# Parameters:	Location ID
#
# Returns:	State

sub getState
{
    my $locn_id = shift;

    my $sql =	"select	 locn_state
		 from	 locations
		 where	 locn_id = '$locn_id'";

    my $result = $dbh->selectrow_array($sql);

    if (defined $result)
    {
	return $result;
    }
    else
    {
	return "";
    }
}
# getReportLvl - Get the Reporting Level
#
# Parameters:	Service Order ID
#
# Returns:	Reporting Level

sub getReportLvl
{
    my $sero_id = shift;
    my $sql = 	"select	 conp_cont_abbreviation
		 from 	 service_orders
	 		,contact_points
		 where 	 sero_id = '$sero_id'
		 and	 conp_cusr_abbreviation = sero_cusr_abbreviation
		 and	 conp_cont_abbreviation like 'CRPTLVL%'";

    my $result = $dbh->selectrow_array($sql);

    return $result;
}
# getServGrp - Get the Service Group Name, ie
# the port's location.
#
# Parameters:	Port ID
#
# Returns:	Service Group Name

sub getServGrp
{
    my $port_id = shift;

    my $sql =	"select	 equp_locn_ttname
		 from	 equipment
			,ports
		 where	 equp_id = port_equp_id
		 and	 equp_status = 'INSERVICE'
		 and	 port_id = '$port_id'";

    my $result = $dbh->selectrow_array($sql);
    return $result;
}
# getServTyp - Get the Service Type by getting the
# service order's Type, and comparing it to a hard
# coded list of InfoVista Types.
#
# Parameters:	Service Order ID
#
# Returns:	Service Type.

sub getServTyp
{
    my $sero_id = shift;
    my @access_list = qw(
    DAB-DAR		DAB-DSLX	DAB-LMDS
    DAB-MICW		DAB-ON2		DAB-ON30
    DAB-SE1		DAB-TIECB	DAM-DAR
    DAM-DSLM		DAM-LMDS	DAM-LOCAL
    DAM-MICW		DAM-ON2		DAM-ON30
    DAM-SE1		DAM-TIECB	HSIM-DSL
    HSIM-DSLX		DAM		DAR
    DAB);
    my @internal_list = qw(
    INF-DAB-DAR		INF-PLAT-NODE);
    my @pvc_list = qw(
    PVC-INTERNET	PVC-INTNL	PVC-MGT
    PVC-WAN		PVC);

    my $sql = 	"select	 sero_cirt_name
		 from 	 service_orders
		 where 	 sero_id = '$sero_id'";
    my $serv_abbr = $dbh->selectrow_array($sql);

    $serv_abbr =~ /^(\w+ - \w+) (\w+) \d+/;
    $serv_abbr = $2;

# Find the service type abbreviation in the appropriate
# array, and return it.

    my (%in_access, %in_internal, %in_pvc);
    for (@access_list)
    {
	$in_access{$_} = 1;
    }
    for (@internal_list)
    {
	$in_internal{$_} = 1;
    }
    for (@pvc_list)
    {
	$in_pvc{$_} = 1;
    }

    if ($in_access{$serv_abbr})
    {
	return "Access";
    }
    elsif ($in_internal{$serv_abbr})
    {
	return "Internal";
    }
    elsif ($in_pvc{$serv_abbr})
    {
	return "PVC";
    }
}
# getWANSwitch - Get the WAN Switch name associated with
# a particular port.
#
# Parameters:	Port ID
#
# Returns:	WAN Switch Name, WAN Switch Type

sub getWANSwitch
{
    my $port_id = shift;
    my $sql =	"select	 tefi_value
			,equp_equt_abbreviation
		 from	 equipment
	 		,technology_template_instance
			,ports
		 where	 tefi_tableid = equp_id
		 and	 tefi_tablename='EQUIPMENT'
		 and	 tefi_name = 'DNS'
		 and	 equp_id = port_equp_id
		 and	 equp_status = 'INSERVICE'
		 and	 port_id = '$port_id'";

    my @result = $dbh->selectrow_array($sql);
    return @result[0,1];
}
# printPVCError - Print a PVC when theres an error.
#
# Parameters:	Error #, Circuit Name, Customer Abbr
#
# Returns:	None

sub printPVCError
{
    my $error_nbr = shift;
    my $cirt_name = shift;
    my $cusr_abbr = shift;
    my $reason;
	
    if ($error_nbr == 103)
    {
	$reason = "could not find two end ports eligible for carrying a PVC - debugging information follows:\n" . $debugging_info;
    }
    elsif ($error_nbr == 104)
    {
	$reason = 'the end ports were defined with an invalid state';
    }
    elsif ($error_nbr == 106)
    {
	$reason = 'the A end location is in a different state to the end ports';
    }
    elsif ($error_nbr == 107)
    {
	$reason = 'there is no way of determining which port belongs to which end of the PVC';
    }
    else
    {
	$reason = "unknown error code - $error_nbr";
    }
   
    my $error_filename =  $run_path . '/files/serv-'. $poller . '-' . $sero_id . '.atmfr.error';
    open (ERRORFILE, ">$error_filename") or
	die "Error opening file $error_filename - $!\n";
    print ERRORFILE "Error $error_nbr for $cusr_abbr, circuit $cirt_name - $reason\n";
    
    close ERRORFILE or
	die "Error closing $error_filename - $!\n";
}
# printPVCGood - Print a PVC when its good.
#
# Parameters:	PVC, Port A Id, Port B Id
#
# Returns:	None

sub printPVCGood
{
    my (%pvca, %pvcb);
    my $pvc_ref = shift;
    my %pvc = %$pvc_ref;
    $pvca{'port_id'} = shift;
    $pvcb{'port_id'} = shift;

# Now that we have the IDs of the ports at each end of the
# PVC, we can go through and get the details for each end.

    $pvca{'pvc_name'} 	= $sero_cirt_name . " - A";
    ($pvca{'WAN_switch'}, $pvca{'WAN_SW_type'})	= getWANSwitch($pvca{'port_id'});
    $pvca{'domain'}	= getState($pvc{'aend'});
    $pvca{'serv_grp'}	= getLocnName($pvc{'aend'});
    $pvca{'from_addr'}	= getAddr($pvc{'aend'});
    $pvca{'to_addr'}	= getAddr($pvc{'bend'});
    $pvca{'dlci'}	= getDLCI($pvca{'port_id'});
    $pvca{'port_type'}	= getPortType($pvca{'port_id'});
    $pvca{'port_locn'}	= getPortLocn($pvca{'port_id'});
    $pvca{'port_addr'}	= getAddr($pvca{'port_locn'});
    $pvca{'card_no'}	= getCardNo($pvca{'port_id'});
    $pvca{'port_no'}	= getPortNo($pvca{'port_id'});
    $pvca{'port_name'}	= $pvca{'WAN_switch'} . "_" . $pvca{'card_no'} . "." . $pvca{'port_no'};
    $pvca{'port_desc'}	= $pvca{'port_name'};
    $pvca{'concat1'}	= $pvc{'cusr_abbr'} . "_" . $pvca{'WAN_SW_type'};
    $pvca{'concat2'}	= $pvc{'cusr_abbr'} . "_" . $pvca{'WAN_SW_type'} . "_" . $pvca{'domain'}; 

	#capture the NE id for snmp alarm
	$pvca{'alm_WAN_sw'} = $pvca{'WAN_switch'};
	$pvca{'alm_card_no'} = $pvca{'card_no'};
	$pvca{'alm_port_no'} = $pvca{'port_no'};
	$pvca{'alm_dlci'} = $pvca{'dlci'};
	$pvca{'alm_line'} = getPVCNo($pvca{'port_id'});	#get the line number

# Produce details based on the Switch type.

    if ($pvca{'WAN_SW_type'} eq 'MGX')
    {
	$pvca{'WAN_switch'} = $pvca{'WAN_switch'} . '-SM_' . $pvca{'card_no'};
	$pvca{'pvc_desc'} = "";
	$pvca{'card_no'} = "";
	$pvca{'mgx_port'} = $pvca{'port_no'};
	$pvca{'port_no'} = "";
	$pvca{'bpxigxdesc'} = 1;
    }
    else
    {
	$pvca{'desc_card_no'} = $pvca{'card_no'};

# We do the sillybuggers with the numbers to strip any leading zeroes
# from the card no for the PVC description.

        $pvca{'desc_card_no'} *= 10;
	$pvca{'desc_card_no'} /= 10;
	
	$pvca{'mgx_port'} = "";
	
	if ($pvca{'WAN_SW_type'} eq 'BPX')
	{
	    $pvca{'pvc_no'} = getPVCNo($pvca{'port_id'});
	    $pvca{'bpxigxdesc'} = 1;
	    $pvca{'pvc_desc'} = "D1" . "." . $pvca{'WAN_switch'} . "." . $pvca{'desc_card_no'} . "." . $pvca{'pvc_no'} . "." . $pvca{'port_no'} . "." . $pvca{'dlci'};
	}
	else
	{
	    $pvca{'bpxigxdesc'} = 1;
	    $pvca{'pvc_desc'} = "D1" . "." . $pvca{'WAN_switch'} . "." . $pvca{'desc_card_no'} . "." . $pvca{'port_no'} . "." . $pvca{'dlci'};
	}
	$pvca{'dlci'} = "";
    }
    
    my $filename =  $run_path . '/files/serv-'. $poller . '-' . $sero_id . '.atmfr.ready';
    open (TOPFILE, ">$filename") or
	die "Error opening file $filename - $!\n";

# If the PVC is terminating on a BPX, create an ATM PVC, else create a Frame.

    if ($pvca{"WAN_SW_type"} eq "BPX")
    {
        print TOPFILE "ATM_PVC;$pvca{'pvc_name'};$pvca{'WAN_switch'};$pvc{'cusr_name'};$pvc{'cusr_abbr'};$pvca{'domain'};$pvca{'serv_grp'};$pvc{'serv_typ'};$pvca{'concat1'};$pvca{'concat2'};$pvca{'from_addr'};$pvca{'to_addr'};$pvca{'bpxigxdesc'};$pvca{'index'};$pvca{'pvc_desc'};$pvca{'alm_WAN_sw'};$pvca{'alm_card_no'};$pvca{'alm_port_no'};$pvca{'alm_dlci'};$pvca{'alm_line'};$pvc{'report_lvl'}\n";
        #print TOPFILE "ATM_PVC;$pvca{'pvc_name'};$pvca{'WAN_switch'};$pvc{'cusr_name'};$pvc{'cusr_abbr'};$pvca{'domain'};$pvca{'serv_grp'};$pvc{'serv_typ'};$pvca{'concat1'};$pvca{'concat2'};$pvca{'from_addr'};$pvca{'to_addr'};$pvca{'bpxigxdesc'};$pvca{'index'};$pvca{'pvc_desc'};$pvc{'report_lvl'}\n";
    }
    else
    {
       print TOPFILE "FR_PVC;$pvca{'pvc_name'};$pvca{'WAN_switch'};$pvc{'cusr_name'};$pvc{'cusr_abbr'};$pvca{'domain'};$pvca{'serv_grp'};$pvc{'serv_typ'};$pvca{'concat1'};$pvca{'concat2'};$pvca{'from_addr'};$pvca{'to_addr'};$pvca{'bpxigxdesc'};$pvca{'index'};$pvca{'pvc_desc'};$pvca{'dlci'};$pvca{'mgx_port'};$pvca{'formula_type'};;$pvca{'alm_WAN_sw'};$pvca{'alm_card_no'};$pvca{'alm_port_no'};$pvca{'alm_dlci'};$pvca{'alm_line'};$pvc{'report_lvl'}\n";
       #print TOPFILE "FR_PVC;$pvca{'pvc_name'};$pvca{'WAN_switch'};$pvc{'cusr_name'};$pvc{'cusr_abbr'};$pvca{'domain'};$pvca{'serv_grp'};$pvc{'serv_typ'};$pvca{'concat1'};$pvca{'concat2'};$pvca{'from_addr'};$pvca{'to_addr'};$pvca{'bpxigxdesc'};$pvca{'index'};$pvca{'pvc_desc'};$pvca{'dlci'};$pvca{'mgx_port'};$pvca{'formula_type'};;$pvc{'report_lvl'}\n";
    }

# Now do the same for the other end.

    $pvcb{'pvc_name'} = $sero_cirt_name . " - B";

    ($pvcb{'WAN_switch'}, $pvcb{'WAN_SW_type'})	= getWANSwitch($pvcb{'port_id'});
    $pvcb{'domain'}	= getState($pvc{'bend'});
    $pvcb{'serv_grp'}	= getLocnName($pvc{'bend'});
    $pvcb{'from_addr'}	= getAddr($pvc{'bend'});
    $pvcb{'to_addr'}	= getAddr($pvc{'aend'});
    $pvcb{'dlci'}	= getDLCI($pvcb{'port_id'});
    $pvcb{'port_type'}	= getPortType($pvcb{'port_id'});
    $pvcb{'port_locn'}	= getPortLocn($pvcb{'port_id'});
    $pvcb{'port_addr'}	= getAddr($pvcb{'port_locn'});
    $pvcb{'card_no'}	= getCardNo($pvcb{'port_id'});
    $pvcb{'port_no'}	= getPortNo($pvcb{'port_id'});
    $pvcb{'port_name'}	= $pvcb{'WAN_switch'} . "_" . $pvcb{'card_no'} . "." . $pvcb{'port_no'};
    $pvcb{'port_desc'}	= $pvcb{'port_name'};
    $pvcb{'concat1'}	= $pvc{'cusr_abbr'} . "_" . $pvcb{'WAN_SW_type'};
    $pvcb{'concat2'}	= $pvc{'cusr_abbr'} . "_" . $pvcb{'WAN_SW_type'} . "_" . $pvcb{'domain'};

	#capture the NE id for snmp alarm
	$pvcb{'alm_WAN_sw'} = $pvcb{'WAN_switch'};
	$pvcb{'alm_card_no'} = $pvcb{'card_no'};
	$pvcb{'alm_port_no'} = $pvcb{'port_no'};
	$pvcb{'alm_dlci'} = $pvcb{'dlci'};
	$pvcb{'alm_line'} = getPVCNo($pvcb{'port_id'});

# Produce details based on the Switch type.

    if ($pvcb{'WAN_SW_type'} eq 'MGX')
    {
	$pvcb{'WAN_switch'} = $pvcb{'WAN_switch'} . '-SM_' . $pvcb{'card_no'};
	$pvcb{'pvc_desc'} = "";
	$pvcb{'card_no'} = "";
	$pvcb{'mgx_port'} = $pvcb{'port_no'};
	$pvcb{'port_no'} = "";
	$pvcb{'bpxigxdesc'} = 1;
    }
    else
    {
	$pvcb{'desc_card_no'} = $pvcb{'card_no'};

# We do the sillybuggers with the numbers to strip any leading zeroes
# from the card no for the PVC description.

        $pvcb{'desc_card_no'} *= 10;
	$pvcb{'desc_card_no'} /= 10;
	
	$pvcb{'mgx_port'} = "";

	if ($pvcb{'WAN_SW_type'} eq 'BPX')
	{
	    $pvcb{'pvc_no'} = getPVCNo($pvcb{'port_id'});
	    $pvcb{'bpxigxdesc'} = 1;
	    $pvcb{'pvc_desc'} = "D1" . "." . $pvcb{'WAN_switch'} . "." . $pvcb{'desc_card_no'} . "." . $pvcb{'pvc_no'} . "." . $pvcb{'port_no'} . "." . $pvcb{'dlci'};
	}
	else
	{
	    $pvcb{'bpxigxdesc'} = 1;
	    $pvcb{'pvc_desc'} = "D1" . "." . $pvcb{'WAN_switch'} . "." . $pvcb{'desc_card_no'} . "." . $pvcb{'port_no'} . "." . $pvcb{'dlci'};
	}
	$pvcb{'dlci'} = "";
    }

# If the PVC is terminating on a BPX, create an ATM PVC, else create a Frame.

    if ($pvcb{"WAN_SW_type"} eq "BPX")
    {
	print TOPFILE "ATM_PVC;$pvcb{'pvc_name'};$pvcb{'WAN_switch'};$pvc{'cusr_name'};$pvc{'cusr_abbr'};$pvcb{'domain'};$pvcb{'serv_grp'};$pvc{'serv_typ'};$pvcb{'concat1'};$pvcb{'concat2'};$pvcb{'from_addr'};$pvcb{'to_addr'};$pvcb{'bpxigxdesc'};$pvcb{'index'};$pvcb{'pvc_desc'};$pvcb{'alm_WAN_sw'};$pvcb{'alm_card_no'};$pvcb{'alm_port_no'};$pvcb{'alm_dlci'};$pvcb{'alm_line'};$pvc{'report_lvl'}\n";
	#print TOPFILE "ATM_PVC;$pvcb{'pvc_name'};$pvcb{'WAN_switch'};$pvc{'cusr_name'};$pvc{'cusr_abbr'};$pvcb{'domain'};$pvcb{'serv_grp'};$pvc{'serv_typ'};$pvcb{'concat1'};$pvcb{'concat2'};$pvcb{'from_addr'};$pvcb{'to_addr'};$pvcb{'bpxigxdesc'};$pvcb{'index'};$pvcb{'pvc_desc'};$pvc{'report_lvl'}\n";
    }
    else
    {
	print TOPFILE "FR_PVC;$pvcb{'pvc_name'};$pvcb{'WAN_switch'};$pvc{'cusr_name'};$pvc{'cusr_abbr'};$pvcb{'domain'};$pvcb{'serv_grp'};$pvc{'serv_typ'};$pvcb{'concat1'};$pvcb{'concat2'};$pvcb{'from_addr'};$pvcb{'to_addr'};$pvcb{'bpxigxdesc'};$pvcb{'index'};$pvcb{'pvc_desc'};$pvcb{'dlci'};$pvcb{'mgx_port'};$pvcb{'formula_type'};;$pvcb{'alm_WAN_sw'};$pvcb{'alm_card_no'};$pvcb{'alm_port_no'};$pvcb{'alm_dlci'};$pvcb{'alm_line'};$pvc{'report_lvl'}\n";
	#print TOPFILE "FR_PVC;$pvcb{'pvc_name'};$pvcb{'WAN_switch'};$pvc{'cusr_name'};$pvc{'cusr_abbr'};$pvcb{'domain'};$pvcb{'serv_grp'};$pvc{'serv_typ'};$pvcb{'concat1'};$pvcb{'concat2'};$pvcb{'from_addr'};$pvcb{'to_addr'};$pvcb{'bpxigxdesc'};$pvcb{'index'};$pvcb{'pvc_desc'};$pvcb{'dlci'};$pvcb{'mgx_port'};$pvcb{'formula_type'};;$pvc{'report_lvl'}\n";
    }
    
    close TOPFILE or
	die "Error closing $filename - $!\n";
}	
# processPVC - Extract all the details for a
# particular PVC.
#
# Parameters:	Circuit Name
#		Service Order ID
#
# Returns:	Return Code

sub processPVC
{
    my $sero_cirt_name = shift;
    my $sero_id = shift;

    $debugging_info = "";

# We have to export the PVC twice, once for each
# end of it.  Therefore, first get the data which
# is common for each end.

    my ($cusr_name, $cusr_abbr) = getCustName($sero_id);

# Get the service type details.

    my $serv_typ = getServTyp($sero_id);
    my $report_lvl = getReportLvl($sero_id);

# Reporting level is based on the type
   
    unless (defined $report_lvl)
    {
	$report_lvl = "";
    }
    $report_lvl =~ s/CRPTLVL_//;
    $report_lvl = uc($report_lvl);

    if ($report_lvl eq "SILVER")
    {
	$report_lvl = "1";
    }
    elsif ($report_lvl eq "GOLD")
    {
	$report_lvl = "2";
    }
    elsif ($report_lvl eq "PLAT")
    {
	$report_lvl = "3";
    }
    else
    {
	$report_lvl = "0";
    }

    my %pvc;
    my ($pvca_port_id, $pvcb_port_id);

# First populate them with the common items.

    $pvc{'cusr_name'} = $cusr_name;
    $pvc{'cusr_abbr'} = $cusr_abbr;
    $pvc{'serv_typ'} = $serv_typ;
    $pvc{'report_lvl'} = $report_lvl;
    ($pvc{'aend'},$pvc{'bend'}) = getABEnd($sero_id);

# Get the ID of the two ports at each end of the PVC.

    ($pvca_port_id, $pvcb_port_id) = getPortID($sero_cirt_name,$pvc{'aend'},$pvc{'bend'});

# If getPortID returns an error - produce error message - we can't load it
# into Infovista.

    if ($pvca_port_id eq 'ERROR')
    {
	printPVCError($pvcb_port_id, $sero_cirt_name, $cusr_abbr);
	return $pvcb_port_id;
    }

    if ($pvca_port_id eq 'SKIP')
    {
	return 0;
    }
    else
    {
	printPVCGood(\%pvc, $pvca_port_id, $pvcb_port_id);
	return 0;
    }
}
