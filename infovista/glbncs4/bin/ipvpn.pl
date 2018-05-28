#!/pkgs/bin/perl 
######################################################
#
# ipvpn.pl
#
# Dig through a service order type VVC-IP or PVC-IP
# to add ROUTER and IP2IP details to an infovista topology
# file for customer latency reporting
#
# Created:      November 23, 2002
# Author:       Adam Booth
# Version:      1.0 
#
######################################################
#	Network Application AAPT Limited
#
#	File:		$RCSfile: ipvpn.pl,v $
#	Source:		$Source: /pace/ProdSRC/infovista/cvs/glbncs4/bin/ipvpn.pl,v $
#
#	Change By:	$Author: bamaster $
#	Last Changed:	$Date: 2006/03/29 00:12:48 $
#
#	Version:	$Revision: 1.34 $
######################################################
#	RCS Log:	$Log: ipvpn.pl,v $
#	RCS Log:	Revision 1.34  2006/03/29 00:12:48  bamaster
#	RCS Log:	Remove call to temp module
#	RCS Log:	
#	RCS Log:	Revision 1.33  2006/03/27 03:17:19  bamaster
#	RCS Log:	Changes for Bioss Upgrades project
#	RCS Log:	
#	RCS Log:	Revision 1.32  2005/11/24 03:26:36  syang
#	RCS Log:	Changes to handle cisco 1841 routers. ipvpn.pl, aapt_iv.pm, and custrouter.pl
#	RCS Log:	
#	RCS Log:	Revision 1.31  2005/08/16 00:14:11  syang
#	RCS Log:	Production version, don't use previous version as bug within the ip checking. Full working version!!!
#	RCS Log:	
#	RCS Log:	Revision 1.29  2004/11/22 00:11:50  syang
#	RCS Log:	Final solution for TTIP to be reported on Qos group, WANIF group, and Router reports. Router would be created on demain
#	RCS Log:	
#	RCS Log:	Revision 1.1  2004/11/10 07:14:34  syang
#	RCS Log:	Initial revision
#	RCS Log:
#	RCS Log:	Revision 1.27  2004/09/24 05:05:29  syang
#	RCS Log:	Random Detect object index not longer required, 2 output fields deleted from Qos output
#	RCS Log:	
#	RCS Log:	Revision 1.26  2004/09/17 06:30:24  syang
#	RCS Log:	changed to fix BRI dialer to use use_ifdesc 2. changes also made to output additional fields for Qos
#	RCS Log:	
#	RCS Log:	Revision 1.25  2004/09/02 06:34:45  syang
#	RCS Log:	Add charater filter to GetCustName to be consistent with custrouter.pl
#	RCS Log:	
#	RCS Log:	Revision 1.24  2004/06/16 04:28:23  syang
#	RCS Log:	Added seti_tablename on sql statements to enhance sql performance
#	RCS Log:	
#	RCS Log:	Revision 1.23  2004/06/07 00:53:18  syang
#	RCS Log:	Clean up conflict code a bit
#	RCS Log:	
#	RCS Log:	Revision 1.22  2004/06/07 00:49:55  syang
#	RCS Log:	Code changed to handle Unmanged NE, Bug fix on IP calculation
#	RCS Log:	
######################################################

use strict;		# Be good, lil program
use DBI;		# Database connection module
use Getopt::Std;	# Process command line options
use Data::Dumper;	# debugging purpose
use Net::Netmask;	# For Network ip mask calculation
use lib "/export/home/infovista/bin/";
use lib './';
use aapt_iv;

# Global Variables

my %cmds;		# Command line options
my $params = "f:p:e:";	# Valid command line options
my $sero_id;		# Service Order to process
my $run_path;
my $poller;
my $DEBUG = 0;          # Set to 1 to use hard coded IP Addresses
my $end_file_name;
my $aapt_iv;

#----------------------
# Main Processing
#----------------------

getopts($params, \%cmds);
    
my ($rtrce_name, $rtrce_locn, $rtrce_descr, $rtrpe_name, $rtrpe_locn,
    $rtrce_ip, $rtrpe_ip, $custname, $custid, $ServiceOrderID, $type,
    $CE_reportinglevel, $router_custidtype, $router_custidtypedomain,
    $CE_Location, $PE_Location, $ServiceSpeed, $router_domain, $transport,
    $slocn, $proj_title, $snumber, $rtrpe_ping_ip, $circuit, $PE_domain,
    $circuit_domain, $circuit_serv_group,$des_ip);
	
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
    $end_file_name = "../files/ipvpn.end." . $poller;
}

# Connect to the database

my $dbh = dbconnect();

# Get the list of product types

my $filename = $run_path . "/files/ipvpn-prod-type.file";
open (PRODFILE, "$filename") or die "Error opening $filename $!\n";
chomp (my @prod_type = <PRODFILE>);
close PRODFILE;
#my $prod_list = join (',', map {"?"} @prod_type);
my $prod_list = join(';',@prod_type);

# Get the list of customers to process

$filename = $run_path . "/files/${poller}_customer.file";
open (CUSTFILE, "$filename") or die "Error opening $filename $!\n";
chomp (my @custname = <CUSTFILE>);
close CUSTFILE;
#my $cusr_list = join (',', map {"?"} @custname);
my $cust_list = join(';',@custname);

$aapt_iv = aapt_iv->new($dbh,$poller,$run_path);

my @data = $aapt_iv->Get_SO_Info($prod_list,$cust_list);

if($aapt_iv->Check_TT_Error()){
	IPVPNError(115,$aapt_iv->Check_TT_Error());
}
my $Qos_Group;	#qos group data

foreach my $item (@data){
	$circuit = $item->{cirt_name};
	$sero_id=$item->{sero_id};
	my $sero_type = $item->{sero_type};

	# Create the output file
	
	$filename =  $run_path . '/files/serv-'. $poller . '-' . $sero_id . '.ipvpn.ready'; 
    	open (FILEHANDLE,">$filename") or
    		die "Unable to write to $filename\n";
	*STDOUT = *FILEHANDLE;

   	# Get the initial router details on the VVC-IP or PVC-IP circuit
   	# hardcode something till service orders are available

	# Stop if we have problems digging up the circuit
    	if(!$circuit)
    	{
		IPVPNError(111, "Unknown Customer", "Not Found");
		next;
    	}
    	my $snmp_comstring;	#snmp community string settings from DB
    	my $snmp_read;
    	my $snmp_write;

    	($rtrce_name, $rtrce_locn, $rtrce_descr, $rtrpe_name, $rtrpe_locn, $rtrce_ip, $rtrpe_ip,$snmp_comstring,$des_ip) = FindRouters($circuit);	
    unless (defined $rtrce_name)
    {
	next;
    }
    
# Calculate the PE IP Address based on the CE IP Address (PE Router Details are customer install specific)

    unless($DEBUG)
    {

	if($des_ip){
		$rtrpe_ping_ip = $des_ip;
	}elsif( $sero_type ne 'TTIP-WAN' && (($rtrpe_ping_ip = CalcPE_IP($rtrce_ip)) eq "-1"))
	{
	    IPVPNError (112, "NA" , $circuit);	   # log error
		next;
	};
    }
	if($rtrce_name =~ /RTRUM/ || $sero_type eq 'TTIP-WAN'){
		my $result = handleRTRUM($dbh,$rtrce_name,$item,$snmp_comstring);
		if($result != 1){
			IPVPNError(115,$result);
		}
	}
# There are a few circuits which don't have CE routers - don't extract them.

	#to ensure in a circuit we have one end with RTRPE and other end with either RTRUM or RTRCE
	if($sero_type eq 'TTIP-WAN'){

		if(!$rtrce_name || !$rtrpe_name){
			IPVPNError(115,"TTIP-WAN circuit $circuit should have one RTRPE and a NE with type either RTRUM or RTRCE");
		}
		my $ipvpn = $item->{ipvpn_cirt_name};
		next if $ipvpn eq '';

		my $path = $item->{Path};

		$Qos_Group->{$ipvpn}{$path}=$item;
		if(defined $Qos_Group->{$ipvpn}{1} && defined $Qos_Group->{$ipvpn}{2}){

			Build_Qos_Group($Qos_Group);
			Build_WANIF_Group($Qos_Group);
			delete $Qos_Group->{$ipvpn};
		}

		next;
	}

   #Get the Customer Name using the $sero_id
    ($custid, $custname) = GetCustName($sero_id);

   #Get the equipment domain for the CE router
    $router_domain = GetDomain($rtrce_locn);
    
    $router_custidtype = $custid."_RTRCE";
    $router_custidtypedomain = $custid."_RTRCE_$router_domain";

    $CE_reportinglevel = getReportLvl($sero_id) || 0;
    $CE_Location = FullLocation($rtrce_locn);
    $PE_Location = "AAPT ".CityLocation($rtrpe_locn);

    my @bandwidth = getBandwidth();
    $ServiceSpeed = $bandwidth[0] + $bandwidth[1] + $bandwidth[2];   
    my $ip2ipdesc = "Latency between $CE_Location and $PE_Location Speed:$ServiceSpeed Kbps";
    ($circuit_domain, $circuit_serv_group) = circuitDomain($circuit);
    
# Bugfix - international routers have a / in their name - eg AUC/M - this causes the extract
# to die because we create files with the router name in their filename, thus solaris gets confused and
# thinks its a subdirectory.  Therefore, change all router names with / to a -

# Create the CE Router file - we create the file by router name to stop duplicates
# where multiple IP-VPNs run over the same router.

	my $rtrce_file = $rtrce_name;
	$rtrce_file =~ s/\//\-/g;

    my $router_filename =  $run_path . '/files/serv-'. $poller . '-' . $rtrce_file . '.router.ready';
    $router_filename =~ s/ /\-/g;

    open (ROUTER, ">$router_filename") 
	or die "Error opening $router_filename : $!\n";
   
	if($snmp_comstring->{$rtrce_ip}{'SNMP_READ'} && $snmp_comstring->{$rtrce_ip}{'SNMP_READ'} ne ''){
		$snmp_read=$snmp_comstring->{$rtrce_ip}{'SNMP_READ'};
	}else{
		$snmp_read='InfoVista';
	}
	
	if($snmp_comstring->{$rtrce_ip}{'SNMP_WRITE'}&& $snmp_comstring->{$rtrce_ip}{'SNMP_WRITE'} ne ''){
		$snmp_write=$snmp_comstring->{$rtrce_ip}{'SNMP_WRITE'};
	}else{
		$snmp_write='InfoVista';
	}
 
    print ROUTER "ROUTER;$rtrce_name;CISCO_ROUTER;$custname;$custid;$CE_Location;$router_domain;";
    print ROUTER "$rtrce_locn;EQUIPMENT;$router_custidtype;$router_custidtypedomain;$rtrce_descr;";
    print ROUTER "$rtrce_ip;$snmp_read;$snmp_write;$rtrce_name;$CE_reportinglevel\n";
	
    close ROUTER;

# Create the PE Router file - create its reportinglevel as 0 so the customer won't see
# performance reports.

    if (defined $rtrpe_name)
    {
	my $rtrpe_file = $rtrpe_name;
	$rtrpe_file =~ s/\//\-/g; 

	$router_filename =  $run_path . '/files/serv-'. $poller . '-' . $rtrpe_file . '.router.ready';
        $router_filename =~ s/ /\-/g;
	$PE_domain = GetDomain ($rtrpe_locn);

	open (ROUTER, ">$router_filename") 
	    or die "Error opening $router_filename : $!\n";

	if($snmp_comstring->{$rtrpe_ip}{'SNMP_READ'} && $snmp_comstring->{$rtrpe_ip}{'SNMP_READ'} ne ''){
		$snmp_read=$snmp_comstring->{$rtrpe_ip}{'SNMP_READ'};
	}else{
		$snmp_read='InfoVista';
	}

	if($snmp_comstring->{$rtrpe_ip}{'SNMP_WRITE'} && $snmp_comstring->{$rtrpe_ip}{'SNMP_WRITE'} ne ''){
		$snmp_write=$snmp_comstring->{$rtrpe_ip}{'SNMP_WRITE'};
	}else{
		$snmp_write='InfoVista';
	}    
        print ROUTER "ROUTER;$rtrpe_name;CISCO_ROUTER;AAPT;AAPT;$PE_Location;$PE_domain;";
	print ROUTER "$rtrpe_locn;EQUIPMENT;AAPT_RTRPE;AAPT_RTRPE_DOMAIN;$rtrce_descr;";
        print ROUTER "$rtrpe_ip;$snmp_read;$snmp_write;$rtrpe_name;4\n";
	
	close ROUTER;
    }

#Select the right transport for the IP2IP
    if ($circuit =~ m/VVC/)
    {
	$transport = "ETHERNET";
    }
    elsif($circuit =~ m/PVC/)
    {
	$transport = "PVC";
    }
    elsif($circuit =~ m/CORE/)
    {
	$transport = "CORE";
    }

   #This flag is to tell the difference between ip-vpn and 'normal' IP2IPs
    $type = "IPVPN";

# Don't produce an IP2IP entry if the PE IP address is wrong.
    unless ($rtrpe_ping_ip eq "-1" && $sero_type eq 'TTIP-WAN')
    {
   #toplogy output for IP2IP (uses mainly customer data except for RTRPE IP Address
   #and link description

	#find out the equipment type
	my $etype;

	if($rtrce_name){
		$etype = (split(/\s+/,$rtrce_name))[1];
	}elsif($rtrpe_name){
		$etype= (split(/\s+/,$rtrpe_name))[1];
	}else{
		IPVPNError(115,"Failed to get equipment type");
		next;
	}

	my $ifname=GetifDesc($circuit,$etype);
	if(!$ifname){
		IPVPNError(115,"Failed to get ifDescr for $circuit as $etype equipment type");
		next;
	}

	my $latency_thresh = getLatencyThresh($circuit);

	#setting the use ifdesc flag, mainly for the BRI reporting
	my $useifdesc;
	if($ifname =~ /BRI/){
		$useifdesc=2;
	}else{
		$useifdesc=1;
	}
	
        print "IP2IP;$circuit;$rtrce_name;$custname;$custid;$circuit_domain;$circuit_serv_group;";
	print "$transport;".$custid."_$transport;".$custid."_".$transport."_$circuit_domain;$type;$rtrpe_ping_ip;$ip2ipdesc;";
        print "$rtrce_name;$ifname;$latency_thresh;$CE_reportinglevel;$useifdesc\n";
    }

    # Check if the circuit has Realtime or Interactive QoS - if it does
    # we need to create a QoS_CLASS entry.
    
    my $sql =	"select	 seti_name
		 from	 service_template_instance
			,circuits
		 where	 seti_tableid = cirt_name
		 and	 seti_tablename = 'CIRCUITS'
		 and	 cirt_sere_id = ?
		 and	 upper(seti_name) in ('INTERACTIVE BANDWIDTH (BPS)','REAL TIME BANDWIDTH (BPS)')
		 and	 seti_value != '0'";

    my $sth2 = $dbh->prepare($sql);
    $sth2->execute($sero_id);

    if (defined $sth2->fetchrow_array)
    {
# We have a QoS, so we have to set up the QoS parms.  First get the
# threshold speeds purchased by the customer.

	my @bandwidth = getBandwidth($sero_id);

	unless (defined $bandwidth[0])
	{
	    $bandwidth[0] = 0;
	}
	unless (defined $bandwidth[1])
	{
	    $bandwidth[1] = 0;
	}
	unless (defined $bandwidth[2])
	{
	    $bandwidth[2] = 0;
	}

	my ($if_name, $rtrce_port_name) = $aapt_iv->getInterface($circuit, "RTRCE", "");

	my $ce_class_name = $circuit . " - CE";
	my $report_type = "Traffic Class Report - From Customer";

	if($rtrce_name){
		print
		"QOS_CLASS;$ce_class_name;$rtrce_name;$custname;$custid;$circuit_domain;$circuit_serv_group;";
		print "$transport;".$custid."_$transport;".$custid."_".$transport."_$circuit_domain;$if_name;0;0;0;0;0;0;0;$bandwidth[0];$bandwidth[1];$report_type;$CE_Location;$CE_reportinglevel;;;0;0;0;0;0;0\n";
	}
	
	my $rtrpe_port_name;
	($if_name, $rtrpe_port_name) = $aapt_iv->getInterface($circuit, "RTRPE", $rtrce_port_name);
	$report_type = "Traffic Class Report - To Customer";
	my $pe_class_name = $circuit . " - PE";

	if($rtrpe_name){

		print
		"QOS_CLASS;$pe_class_name;$rtrpe_name;$custname;$custid;$circuit_domain;$circuit_serv_group;";
		print "$transport;".$custid."_$transport;".$custid."_".$transport."_$circuit_domain;$if_name;0;0;0;0;0;0;0;$bandwidth[0];$bandwidth[1];$report_type;$PE_Location;$CE_reportinglevel;;;0;0;0;0;0;0\n";
	}
    }

    close FILEHANDLE;
}

# Finish up by disconnecting and creating the file to say so.

$dbh->disconnect();

my $command = "touch $end_file_name";
my $rc = system("$command");
exit 0;

#============================================================
sub Build_WANIF_Group(){
	my $data = shift;

	return undef if !$data;

	foreach my $ipvpn (keys %{$data}){
		if($data->{$ipvpn}{1} && $data->{$ipvpn}{2}){
			#ttip circuits
			my $primary = $data->{$ipvpn}{1};
			my $secondary = $data->{$ipvpn}{2};

			my $wanif_name1 = $primary->{wan_if}{name};
			my $wanif_name2 = $secondary->{wan_if}{name};
			
			my @wanif_grp;

			push (@wanif_grp,'WAN_IF_GROUP');
			
			push(@wanif_grp,$ipvpn.' - TTIP');

			push(@wanif_grp,qq{$wanif_name1#$wanif_name2});	
			push(@wanif_grp,qq{Trans-Tasman Interconnect});

			my $cirt_sped_name = $aapt_iv->{Cirt_Speed}->();

			push(@wanif_grp,$primary->{sero_attr}{$cirt_sped_name});

			my $wanif_grp_filename = 'serv-'.$aapt_iv->{POLLER}->().'-'.$ipvpn.'-wanif-group.ready';
			$wanif_grp_filename =~ s/ /\-/g;
			$wanif_grp_filename =~ s/\//\-/g;
			$wanif_grp_filename =~ s/\:/\-/g;

			$wanif_grp_filename = $aapt_iv->{RUN_PATH}->() . "/files/" . $wanif_grp_filename;

			open(WANIFGRP,">$wanif_grp_filename") or die "Error opening $wanif_grp_filename";
			print WANIFGRP join(';',@wanif_grp)."\n";
			close(WANIFGRP);
		}
	}
}
			
#============================================================
sub Build_Qos_Group(){
	my $data = shift;

	return undef if !$data;

	foreach my $ipvpn (keys %{$data}){

		if($data->{$ipvpn}{1} && $data->{$ipvpn}{2}){
			#ttip circuits
			my $primary = $data->{$ipvpn}{1};
			my $secondary = $data->{$ipvpn}{2};


			my $instance_name1=$primary->{qos_group}{inbound}{instance_name};
			my $instance_name2=$secondary->{qos_group}{inbound}{instance_name};
			my $router_addr = $primary->{qos_group}{inbound}{router_addr};
			my $report_type = $primary->{qos_group}{inbound}{report_type};

			my $inbound_str = qq{QOS_CLASS_GROUP;$ipvpn - TTIP - Inbound;$instance_name1#$instance_name2;$router_addr;$report_type\n};
			$instance_name1=$primary->{qos_group}{outbound}{instance_name};
			$instance_name2=$secondary->{qos_group}{outbound}{instance_name};
			$router_addr = $primary->{qos_group}{outbound}{router_addr};
			$report_type = $primary->{qos_group}{outbound}{report_type};

			my $outbound_str = qq{QOS_CLASS_GROUP;$ipvpn - TTIP - Outbound;$instance_name1#$instance_name2;$router_addr;$report_type\n};

			print $inbound_str;
			print $outbound_str;
			
		}else{
			next;
		}
	}
	1;
}
#============================================================
#Get router interface description
#Param:	1. circuit name 2. customer id 3. router type
#Rtn:	IF description as in Bioss form
#============================================================

sub GetifDesc(){
	my ($cirt_name,$rtype) =@_;

	return undef if !$cirt_name || !$rtype;

	my $sql1 = qq{select port_id,port_name,port_card_slot,card_name from ports,equipment,cards \
		where port_cirt_name=? and equp_id=port_equp_id  \
		and card_equp_id=port_equp_id and port_card_slot = card_slot \
		and port_status='INSERVICE' \
		and EQUP_EQUT_ABBREVIATION=?};

	my $sql2 = qq{select port_id,port_name,port_card_slot,card_name from ports,port_hierarchy,cards \
		where port_id=porh_parentid and porh_childid =? \
		and card_equp_id=port_equp_id and port_card_slot=card_slot};

	my $result;
	my $card_nbr;
	eval{
		my $pportid;	#first set of port name and id
		my $pport_name;
		my $pport_card_slot;
		my $pcard_name;

		my $sth = $dbh->prepare($sql1);
		$sth->execute($cirt_name,$rtype);
		while(my @rows = $sth->fetchrow_array){
			$pportid=$rows[0];
			$pport_name=$rows[1];
			$pport_card_slot=$rows[2];
			$pcard_name=$rows[3];
		}
		my $count1=$sth->rows;
		$sth->finish;
		my $sportid=$pportid;
		my $sport_name = $pport_name;
		my $sport_card_slot=$pport_card_slot;
		my $scard_name=$pcard_name;

		while($sport_name !~ /FA-LN/ && $sport_name !~ /DSL/ && $sport_name !~ /1GE/ && $sport_name !~ /ETH/ && 
			$sport_name !~ /BRI/ && $sport_name !~ /^SER.+/){
			my $localid;
			$sth=$dbh->prepare($sql2);
			$sth->execute($sportid);
			while(my @rows=$sth->fetchrow_array){
				$localid=$rows[0];
				$sport_name=$rows[1];
				$sport_card_slot=$rows[2];
				$scard_name=$rows[3];
			}

			$sth->finish;
			return undef if !$localid;
			$sportid=$localid;
		}
		$card_nbr = $sport_card_slot;
		$result=$sport_name;
	};

	if($@){
		IPVPNError(115,$@);
		return undef;
	}
	#logic copied from custrouter.pl
	$card_nbr = sprintf("%d",$card_nbr) if $card_nbr=~/^\d+$/;

	my $port_nbr = $result;
	
	if ($port_nbr =~ /DSL/)
	{
	    if (($port_nbr eq "DSL") or
		($port_nbr eq "ADSL"))
	    {
		$result = "ATM0";
	    }
	    else
	    {
		$port_nbr =~ /DSL-LN(.*)/g;
		my $subif = $1;

		# Remove any leading zeroes from the subinterface

		$subif *= 10;
		$subif /= 10;

		if ($card_nbr eq "NA")
		{
		    $result = "ATM$subif";
		}
		else
		{
		    # Remove any leading zeroes from the card number
		    
		    $card_nbr *= 10;
		    $card_nbr /= 10;

		    $result = "ATM$card_nbr/$subif";
		}
	    }
	}
	elsif ($port_nbr =~ /1GE/)
	{
	    if ($port_nbr eq '1GE')
	    {
		if ($card_nbr eq "NA")
		{
		    $result = "GigabitEthernet0/0";
		}
		else
		{
		    $card_nbr *= 10;
		    $card_nbr /= 10;

		    $result = "GigabitEthernet$card_nbr/0";
		}
	    }
	    else
	    {
		$port_nbr =~ /1GE-LN(.*)/g;
		my $subif = $1;

		if ($card_nbr eq "NA")
		{
		    $result = "GigabitEthernet0/$subif";
		}
		else
		{
		    $card_nbr *= 10;
		    $card_nbr /= 10;

		    $result = "GigabitEthernet$card_nbr/$subif";
		}
	    }
	}
	elsif ($port_nbr =~ /ETH/)
	{
	    if ($port_nbr eq "ETH")
	    {
		if ($card_nbr eq "NA")
		{
		    $result = "Ethernet0/0";
		}
		else
		{
		    $card_nbr *= 10;
		    $card_nbr /= 10;

		    $result = "Ethernet$card_nbr/0";
		}
	    }
	    else
	    {
		$port_nbr =~ /ETH-LN(.*)/g;
		my $subif = $1;

		if ($card_nbr eq "NA")
		{
		    $result = "Ethernet0/$subif";
		}
		else
		{
		    $card_nbr *= 10;
		    $card_nbr /= 10;

		    $result = "Ethernet$card_nbr/$subif";
		}
	    }
	}
	elsif ($port_nbr =~ /FA-LN/)
	{
	    $port_nbr =~ /FA-LN(.*)/g;
	    my $subif = $1;

	    if ($card_nbr eq "NA")
	    {
		$result = "FastEthernet0/$subif";
	    }
	    else
	    {
	        $card_nbr *= 10;
	        $card_nbr /= 10;

	        $result = "FastEthernet$card_nbr/$subif";
	    }
	}
	elsif ($result =~ /BRI/)
	{
	    $result=~ s/\-//;
	}
	elsif($result =~ /SER/)
	{
	    my @sp = split (" ", $result);
	    my $port_nbr = $sp[0];
	    my $channel_grp = $sp[1];
	    $port_nbr =~ s/^SER\-//;
	    $port_nbr =~ s/^\s*0+(\d)/$1/;
	    $channel_grp =~ s/^\s*0+(\d)/$1/;

	    if ($card_nbr eq "NA"){
	        $result = "Serial" . $port_nbr;
	        
	        if (defined ($channel_grp)){
	    	$result = $result . ":$channel_grp";
	        }
	    }else{
	        $result = "Serial" . $card_nbr . "/$port_nbr";

		if (defined ($channel_grp)){
    		$result = $result . ":$channel_grp";
		}
	    }
	
    	}
	else
	{
	    $result = "";
	}

	$result;	
}
				

#-----------------------------
# Subroutines
#-----------------------------
#
# CalcPE_IP	- PE IP Addresses are calculated from the CE IP Address
#
# Parameters:  CE_IP
#
# Returns:     PE_IP or -1 if the CE_IP is invalid

sub CalcPE_IP
{
   my $CE_IP = shift;


   # Match for CE IP Addresses that are in the form 10.255.$1.$2
   if ($CE_IP =~ m/^10\.255\.(\d+)\.(\d+)/){
       if ( $1<0 || $1>47 || $2<0 || $2>255){
            # Valid ranges are CE IP Addresses are 10.255.0.0 to 10.255.47.255
            # return an error if invalid
            return -1;
       }
       # Use Paresh's formula for calculating the PE IP for that CE
       $a = sprintf ("%d",( (( ($1 * 256) + $2) * 4) / 256)) + 64;
       $b = ( ($1 * 256 + $2) * 4 ) % 256 + 1;

       return "10.255.$a.$b";
   }

   # Alternative address range: Match for CE IP Addresses that are in the form 172.21.$1.$2
   if ($CE_IP =~ m/^172\.21\.(\d+)\.(\d+)/){
       if ( $1<0 || $1>1 || $2<0 || $2>127){
            # Valid ranges are CE IP Addresses are 172.21.0.0 to 172.21.1.127 
            # return an error if invalid
            return -1;
       }
       # Use Paresh's formula for calculating the PE IP for that CE
       $a = sprintf ("%d",( (( ($1 * 256) + $2) * 4) / 256)) + 2;
       $b = ( ($1 * 256 + $2) * 4 ) % 256 + 1;

       return "172.21.$a.$b";
   }

   # OPS Mgmt address range: Match for CE IP Addresses that are in the form 10.129.244.$1
   if ($CE_IP =~ m/^10\.129\.244\.(\d+)/){
       if ( $1<0 || $1>191){
            # Valid ranges are CE IP Addresses are 10.129.244.0 to 10.129.244.191 
            # return an error if invalid
            return -1;
       }
       # Use formula for calculating the PE IP for that CE
       $a = sprintf ("%d",(($1 * 4) / 256)) + 245;
       $b = ($1 * 4) % 256 + 1;

       return "10.129.$a.$b";
   }


   # if we got this far, the CE IP Address must be wrong
   return -1;
}
# circuitDomain    Get the circuit's domain
#
# Parameters:  circuit name 
#
# Returns:     The domain(s) that the circuit will appear in.
#
sub circuitDomain
{
# Service group determination is different from other report types
# Metro Ethernet reports use the location types from the circuit
# name to work out where to put the report.  Reports are to be 
# located at the customer location, not the location of the switch.

    my $circuit = shift;

    my @cirt_split = split (" ", $circuit);
    my $aend = $cirt_split[0];
    my $bend = $cirt_split[2];
    
    my $sql =	"select	 locn_state
			,locn_loct_abbreviation
		 from	 locations
		 where	 locn_ttname = ?";

    my $sth = $dbh->prepare($sql);
    $sth->execute($aend);
    my $aend_details = $sth->fetchrow_arrayref;
    
    my $sth2 = $dbh->prepare($sql);
    $sth2->execute($bend);
    my $bend_details = $sth2->fetchrow_arrayref;

    my $agg_count  = 0;
    my $co_count   = 0;
    my $cust_count = 0;
    my $pop_count  = 0;
    my $domain;
    my $serv_group;

# First see how many of each type of site we have in the
# circuit.

    if ($aend_details->[1] eq "AAPT AGG SITE")
    {
	$agg_count++;
    }
    if ($bend_details->[1] eq "AAPT AGG SITE")
    {
	$agg_count++;
    }
    if ($aend_details->[1] eq "AAPT CO SITE")
    {
	$co_count++;
    }
    if ($bend_details->[1] eq "AAPT CO SITE")
    {
	$co_count++;
    }
    if ($aend_details->[1] eq "AAPT POP SITE")
    {
	$pop_count++;
    }
    if ($bend_details->[1] eq "AAPT POP SITE")
    {
	$pop_count++;
    }
    if ($aend_details->[1] eq "CUSTOMER SITE")
    {
	$cust_count++;
    }
    if ($bend_details->[1] eq "CUSTOMER SITE")
    {
	$cust_count++;
    }

# If we have any customer locations, put the report
# under them.
# If we have 2 customer locations, put the report under
# both of them.  !! is used as a delimiter between the
# two locations, report.pl will split them up.

    if ($cust_count == 1)
    {
	if ($aend_details->[1] eq "CUSTOMER SITE")
	{
	    $domain = $aend_details->[0];
	    $serv_group = $aend;
	}
	else
	{
	    $domain = $bend_details->[0];
	    $serv_group = $bend;
	}
    }
    elsif ($cust_count == 2)
    {
	$domain = $aend_details->[0] . "!!" . $bend_details->[0];
	$serv_group = $aend . "!!" . $bend;
    }

# If we don't have any customer locations, have to 
# place them under the appropriate AAPT location.

# If we have 1 CO Site, put the report under the
# other end.

    elsif ($co_count == 1)
    {
	if ($aend_details->[1] eq "AAPT CO SITE")
	{
	    $domain = $bend_details->[0];
	    $serv_group = $bend;
	}
	else
	{
	    $domain = $aend_details->[0];
	    $serv_group = $aend;
	}
    }

# If 2 CO Sites, put it under both.

    elsif ($co_count == 2)
    {
	$domain = $aend_details->[0] . "!!" . $bend_details->[0];
	$serv_group = $aend . "!!" . $bend;
    }

# If 0 CO sites, continue checking through AGG and
# POP sites, using the same logic.

    elsif ($agg_count == 1)
    {
	if ($aend_details->[1] eq "AAPT AGG SITE")
	{
	    $domain = $bend_details->[0];
	    $serv_group = $bend;
	}
	else
	{
	    $domain = $aend_details->[0];
	    $serv_group = $aend;
	}
    }
    elsif ($agg_count == 2)
    {
	$domain = $aend_details->[0] . "!!" . $bend_details->[0];
	$serv_group = $aend . "!!" . $bend;
    }
    
    elsif ($pop_count == 1)
    {
	if ($aend_details->[1] eq "AAPT POP SITE")
	{
	    $domain = $bend_details->[0];
	    $serv_group = $bend;
	}
	else
	{
	    $domain = $aend_details->[0];
	    $serv_group = $aend;
	}
    }
    else
    {
	$domain = $aend_details->[0] . "!!" . $bend_details->[0];
	$serv_group = $aend . "!!" . $bend;
    }
    
    return ($domain, $serv_group);
}
# CityLocation - find the city/suburb of a location
#
# Parameters:  Location ID
#
# Returns:     Suburb

sub CityLocation()
{
    my $locn = shift;
    
    my $sql =   "select  locn_suburb
                 from    locations
                 where   locn_ttname = '$locn'";
    my $result = $dbh->selectrow_array($sql);
    return $result;
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
# FindRouters - find the Associated CE and PE from the Circuit Name
#
# Parameters:  Circuit
#
# Returns:     CE_Name, CE_Locn, CE_Desc, PE_Name, PE_Locn, CE_IPAddress;

sub FindRouters()
{
  my $cct = shift;
  
  my ($data, $CE_Name, $CE_Locn, $CE_Desc, $PE_Name, $PE_Locn, $CE_IPAddress, $PE_IPAddress, $CE_, $para, $port_ip);

   # First lets find the ports that the circuit is connected to
   my $sql = "SELECT port_equp_id
           FROM ports
           WHERE port_cirt_name = '$cct'";
   my $sth = $dbh->prepare($sql);
   $sth->execute();
    
   # Now lets find the Network Elements that the port belongs to
   while (my @data = $sth->fetchrow_array()){
       my $NE =  $data[0];
	my $NE_ip;

       # Only interested in RTRPE/RTRCEs for customer service orders
       if ($sero_id =~ m/CUST/){
           $sql = "SELECT equp_equt_abbreviation, equp_locn_ttname,
                          equp_index, equp_ipaddress, 
                          equp_manr_abbreviation, equp_equm_model 
                   FROM equipment
                   WHERE equp_EQUT_abbreviation in ('RTRCE','RTRPE','RTRUM')
                   AND equp_id = $NE";
       }
       else{
           $sql = "SELECT equp_equt_abbreviation, equp_locn_ttname,
                          equp_index, equp_ipaddress,
                          equp_manr_abbreviation, equp_equm_model
                   FROM equipment
                   WHERE equp_EQUT_abbreviation in ('RTRCE','RTRPE','RTRRA','RTRUM')
                   AND equp_id = $NE";
       }
       my $ath = $dbh->prepare($sql);
       $ath->execute();
       if ($sth->rows != 0){
               my @dat = $ath->fetchrow_array;
               if($dat[0]){
                     if($dat[0] eq "RTRCE" || $dat[0] eq "RTRRA" || $dat[0] eq 'RTRUM'){
                         $CE_Name = $dat[1]." ".$dat[0]." ".$dat[2];
                         $CE_IPAddress = $dat[3];
                         $CE_Locn = $dat[1];
                         $CE_Desc = $dat[4]." ".$dat[5];
                      }
                      elsif($dat[0] eq "RTRPE"){
                         $PE_Name = $dat[1]." ".$dat[0]." ".$dat[2];
                         $PE_Locn = $dat[1];
                         $PE_IPAddress = $dat[3];
                      }
			$NE_ip=$dat[3]; #hold it for snmp hash regardless what type of ne

			#looking for port parameter IP
			my $ip_sql = qq{select tefi_name,tefi_value from technology_template_instance \
					where tefi_name in (?,?) and tefi_tablename=? and \
					tefi_tableid in ( select port_id from ports \
					where port_cirt_name=? and port_equp_id=?)};

			my $ipsth = $dbh->prepare($ip_sql);
			$ipsth->execute('IP','GW','PORTS',$cct,$NE);
			while(my @rows = $ipsth->fetchrow_array){
				$port_ip->{$dat[0]}{$rows[0]}=$rows[1];
			}
			$ipsth->finish;
		}
       }
	
	#---------find SNMP r/w community strings from equipment parameters table----
	$sql = qq{select tefi_name,tefi_value from TECHNOLOGY_TEMPLATE_INSTANCE \
			where tefi_tablename=? and tefi_tableid=? \
			and tefi_name in (?,?)};

	my $para_sth = $dbh->prepare($sql);
	$para_sth->execute('EQUIPMENT',$NE,'SNMP_READ','SNMP_WRITE');	
	while(my @rows = $para_sth->fetchrow_array){
		$para->{$NE_ip}{$rows[0]} = $rows[1];
	}
	$para_sth->finish;
	
	
    }

    my $ip_final = Find_DesIP($CE_IPAddress,$port_ip);

    return $CE_Name, $CE_Locn, $CE_Desc, $PE_Name, $PE_Locn, $CE_IPAddress, $PE_IPAddress,$para,$ip_final;
}

#=============================================================================
#Task:	Try to derive destination address from port parameters on NE
#By:	Sam Yang
sub Find_DesIP(){
	my ($ceip,$data) = @_;

	return undef if !$data;
	return undef if !$ceip;

	my $isinrange;

	my $gate1 = new Net::Netmask('10.255.0.0/18');
	my $gate2 = new Net::Netmask('172.21.0.0/23');
	my $gate3 = new Net::Netmask('10.129.244.0/24');

	return undef if !$gate1 || !$gate2 || !$gate3;

	if($gate1->match($ceip)){
		$isinrange=1;
	}elsif($gate2->match($ceip)){
		$isinrange=2;
	}elsif($gate3->match($ceip)){
		$isinrange=3;
	}else{
		return undef;
	}

	my $pe = $data->{RTRPE};
	my $ce = $data->{RTRCE};
	$ce = $data->{RTRRA} if !$ce;
	$ce = $data->{RTRUM} if !$ce;

	return undef if !$ce;

	my $ceobj;
	my $ce_mask;

	my $peobj;
	my $pe_mask;
		

	if($ce->{IP} && $pe->{IP}){	#if both ends have ip assigned to port parameters
		$ceobj = new Net::Netmask($ce->{IP});
		$peobj = new Net::Netmask($pe->{IP});
		return undef if !$ceobj || !$peobj;
			
		my $cebase = $ceobj->base;
		my $pebase = $peobj->base;

		return undef if $cebase ne $pebase;	#if they are not under same subnet

		return $1 if $pe->{IP} =~ /^(\d+\.\d+\.\d+\.\d+)\/\d+$/;	#use pe ip to ping
	}elsif($ce->{IP} && $ce->{GW} && !$pe->{IP}){ #if ce has ip, and GW, but not ip assigned to PE
		$ceobj = new Net::Netmask($ce->{IP});
		return undef if !$ceobj;
			

		if($ceobj->match($ce->{GW})){	#if GW ip is in CE ip ranges
			return $ce->{GW};
		}
		return undef;
	}elsif($ce->{IP} && !$pe->{IP} && !$ce->{GW}){

		$ceobj = new Net::Netmask($ce->{IP});
		return undef if !$ceobj;

		my $current_ceip = $1 if $ce->{IP} =~ /^(\d+\.\d+\.\d+\.\d+)\/\d+/;
	
		my $bits = $ceobj->bits;	#get the bit value of mask

		foreach my $ip ($ceobj->enumerate()){ #foreach ip addr
			if($bits == 31){
				next if $ip eq $current_ceip;
			}elsif($bits == 30){
				next if $ip eq $ceobj->base;	#skip the base ip
				next if $ip eq $ceobj->broadcast; #skip the broadcast addr
				next if $ip eq $current_ceip;	#skip the current ce ip
			}else{
				return undef;
			}

			return $ip;	#pick anyone then
		}
	}
	return undef;

}
#=============================================================================
# FullLocation - Get the full address of a location
#
# Parameters:  Location ID
#
# Returns:     Full address
        
sub FullLocation()
{
    my $locn = shift;

    my $sql =   "select  locn_number, locn_street, locn_strt_name,
                         locn_suburb, locn_state
                 from    locations
                 where   locn_ttname = '$locn'";
   my $sth = $dbh->prepare($sql);
   $sth->execute();
   my @data = $sth->fetchrow_array();
   return $data[0]." ".$data[1]." ".$data[2].", ".$data[3].". ".$data[4];
}
# getBandwith - Get the bandwidths purchased by the customer
#
# Parameters:  Circuit
#
# Returns:     Bandiwdth values
        
sub getBandwidth
{
    my $sql =	"select	 seti_name
			,seti_value
		 from	 service_template_instance
			,circuits
		 where	 seti_tableid = cirt_name
		 and	 seti_tablename = 'CIRCUITS'
		 and	 cirt_sere_id = ?
		 and	 upper(seti_name) in ('REAL TIME BANDWIDTH (BPS)','INTERACTIVE BANDWIDTH (BPS)',
						'BUSINESS DATA BANDWIDTH (BPS)')";

    my $sth = $dbh->prepare($sql);
    $sth->execute($sero_id);

    my @bandwidth;
    my @return;
    while (@bandwidth = $sth->fetchrow_array)
    {
# The bandwidth can be stored either as bits, kbits or mbits
# per sec.  We want to store kbits per sec on IV, so convert
# from whatever has been stored to kbits.

	if ($bandwidth[1] =~ /k/i)
	{
	    $bandwidth[1] =~ s/(\d+)\D*/$1/;
	}
	elsif ($bandwidth[1] =~ /m/i)
	{
	    $bandwidth[1] =~ s/(\d+)\D*/$1/;
	    $bandwidth[1] *= 1000;
	}
	else
	{
	    $bandwidth[1] /= 1000;
	}

	if (uc($bandwidth[0]) eq "REAL TIME BANDWIDTH (BPS)")
	{
	    $return[0] = $bandwidth[1];
	}
	elsif (uc($bandwidth[0]) eq "INTERACTIVE BANDWIDTH (BPS)")
	{
	    $return[1] = $bandwidth[1];
	}
	elsif (uc($bandwidth[0]) eq "BUSINESS DATA BANDWIDTH (BPS)")
	{
	    $return[2] = $bandwidth[1];
	}
    }
    return @return;
}
# GetCctFrom SO - Get the CircuitName from the Service Order 
#
# Parameters:   Service Order ID
#
# Returns:      The Circuit Name

sub GetCctFromSO
{
    my $sql = "SELECT sero_cirt_name
               FROM service_orders, circuits
               WHERE sero_id = '$sero_id'";
    my $result = $dbh->selectrow_array($sql);
    return $result;
}
# GetCustName     - get the complete customer name
#
# Parameters: serviceorder 
#
# Returns:     custid, custname
        
sub GetCustName
{
   my $SID = shift;
   my $CID;
   my $sql = "SELECT sero_cusr_abbreviation FROM service_orders
              WHERE sero_id LIKE '$SID'";
   my $sth = $dbh->prepare($sql);
   $sth->execute();

   while (my @data = $sth->fetchrow_array()){
    $CID = $data[0];
   }
   $sql = "SELECT cusr_name FROM customer WHERE cusr_abbreviation LIKE '$CID'";
   $sth = $dbh->prepare($sql);
   $sth->execute();

   while (my @data = $sth->fetchrow_array()){
    my $fullname = $data[0];
	$fullname =~ s/,/ /g;
        $fullname =~ s/\(/ /g;
        $fullname =~ s/\)/ /g;
        $fullname =~ s/\s+$//;
   return $CID, $fullname;
   }
}
# GetDomain     - get the equipment domain
#
# Parameters:  locn_ttname
#
# Returns:     state that the equipment resides in
sub GetDomain
{
    my $locn = shift;
 
    my $sql =   "select  locn_state
                 from    locations
                 where   locn_ttname = '$locn'";
    my $result = $dbh->selectrow_array($sql);
    return $result;
}
# getLatencyThresh - Get the Latency Threshold
#
# Parameters:  Circuit
#
# Returns:     Threshold
        
sub getLatencyThresh
{
    my $circuit = shift;
 
    my $sql =	"select	 seti_value
		 from	 service_template_instance
			,circuits
		 where	 seti_tableid = cirt_name
		 and	 seti_tablename = 'CIRCUITS'
		 and	 cirt_name = ?
		 and	 upper(seti_name) = 'LATENCY THRESHOLD'";

    my $sth = $dbh->prepare($sql);
    $sth->execute($circuit);
    my $threshold = $sth->fetchrow_array;
    
# If the threshold contains non-numeric chars, log an error,
# set the threshold to 0 and continue processing.

    if ($threshold =~ /\D/)
    {
	IPVPNError("116", $custid, $circuit);
	$threshold = 0;
    }

    unless (defined $threshold)
    {
	$threshold = 0;
    }

    return $threshold;
}
# getReportLvl - Get the Reporting Level
# 
# Parameters:   Service Order ID
# 
# Returns:      Reporting Level

sub getReportLvl
{
    my $sero_id = shift;  
    my $sql =   "select  conp_cont_abbreviation
                 from    service_orders
                        ,contact_points
                 where   sero_id = '$sero_id'
                 and     conp_cusr_abbreviation = sero_cusr_abbreviation
                 and     conp_cont_abbreviation like 'CRPTLVL%'";
    my $result = $dbh->selectrow_array($sql);
 
    return $result;
}
# IPVPNError - Writes to the error file
#
# Parameters:   Error Number, Customer ID, Circuit, Error
#
# Returns:      Nothing

sub IPVPNError
{
    my $error_nbr = shift;
    my $cusr_abbr = shift;
    my $cirt_name = shift;
    my $reason = "fd";

    if ($error_nbr == 111)
    {
        $reason = 'Service Order Not Valid or Circuit not in Service';
    }
    elsif ($error_nbr == 112)
    {
        $reason = 'RTRCE IP Address not valid - unable to compute RTRPE IP Address';
    }elsif($error_nbr == 115){	#free text error, just hacked it in
	$reason = $cusr_abbr;
    }elsif($error_nbr == 116){
	$reason = 'Circuit has a non-numeric value for Latency Threshold';
    }else{
        $reason = "unknown error code - $error_nbr";
    }
    
    my $error_filename =  $run_path . '/files/serv-'. $poller . '-' . $sero_id . '.ipvpn.error';
    open (ERRORFILE, ">$error_filename") or
        die "Error opening file $error_filename - $!\n";
	if($error_nbr == 115){
		print ERRORFILE "Application Error:$reason\n";
	}else{
		print ERRORFILE "Error $error_nbr for $cusr_abbr, circuit $cirt_name - $reason\n";
	}

    close ERRORFILE or
        die "Error closing $error_filename - $!\n";
}
#===================================================================
sub handleRTRUM(){
	my ($dbh,$rtrce_name,$item,$snmp_str) = @_;

	return undef if !$dbh || !$rtrce_name || !$item;

	my ($rname,$rtype,$rindex) = split(/\s+/,$rtrce_name);

	my ($so_id,$cirt_name,$ce_ipaddress,$port_name,$pe_index,$pe_locn_ttname,$pe_ip,$cust_id,$cust_name,$pe_equp_id);

	my $sql = qq{select cirt_sere_id,cirt_name,equp_ipaddress \
		from circuits,ports,equipment \
		where cirt_sert_abbreviation = ? \
		and cirt_sped_abbreviation = ? \
		and cirt_name = port_cirt_name and trim(' ' from port_cirt_name) is not NULL \
		and port_equp_id = equp_id and equp_locn_ttname=? \
		and equp_equt_abbreviation=? and equp_index=?};

	eval{
		if($item->{sero_type} eq 'TTIP-WAN'){
			$sql .= qq{ and port_id in (select porh_parentid from port_hierarchy,ports p2 \
			where porh_childid = p2.port_id and \
			p2.port_cirt_name='$item->{ipvpn_cirt_name}')};
		}

	my $sth = $dbh->prepare($sql);
	$sth->execute($item->{sero_type},$item->{cirt_sped_type},$rname,$rtype,$rindex);

	while(my @rows = $sth->fetchrow_array){
		$so_id=$rows[0];
		$cirt_name=$rows[1];
		$ce_ipaddress = $rows[2];
	}
	$sth->finish;

	if($so_id && $cirt_name){
		my $pe_sql = qq{select port_id,port_card_slot,port_name,equp_index,equp_locn_ttname,equp_ipaddress, equp_id \
			from equipment,ports \
			where port_cirt_name=? \
			and port_equp_id=equp_id and equp_equt_abbreviation='RTRPE'};

		$sth=$dbh->prepare($pe_sql);
		$sth->execute($cirt_name);

		while(my @rows = $sth->fetchrow_array){
			$port_name=$rows[2];
			$pe_index=$rows[3];
			$pe_locn_ttname=$rows[4];
			$pe_ip=$rows[5];
			$pe_equp_id = $rows[6];
		}
		$sth->finish;
	}else{
		return undef;
	}
	};
	return $@ if $@;

	($cust_id,$cust_name) = GetCustName($so_id);

	my $transport;

	if($cirt_name =~ m/VVC/){
		$transport = 'ETHERNET';
	}elsif( $cirt_name =~ m/PVC/){
		$transport = 'PVC';
	}elsif($cirt_name =~ m/CORE/){
		$transport = 'CORE';
	}elsif( $cirt_name =~ m/IP/){
		$transport = 'PVC';
	}

	my @bandwidth = getBandwidth($so_id);

	unless (defined $bandwidth[0])
        {
            $bandwidth[0] = 0;
        }
        unless (defined $bandwidth[1])
        {
            $bandwidth[1] = 0;
        }
        unless (defined $bandwidth[2])
        {
            $bandwidth[2] = 0;
        }

	my ($if_name, $rtrpe_port_name) = $aapt_iv->getInterface($circuit, "RTRPE", $port_name);
	my ($cirt_domain,$cirt_serv_group) = circuitDomain($cirt_name);
	my $reportlevel = getReportLvl($so_id) || 0;

	my $path='';
	if($item->{Path} == 1){
		$path='Primary';
	}elsif($item->{Path} ==2){
		$path ='Secondary';
	}

	my $reportWho = 'Customer';
	my $ipvpn_cirt_name;
	my $ttip_cirt_name;
	if($item->{sero_type} eq 'TTIP-WAN'){
		$reportWho = 'New Zealand';
		$ttip_cirt_name = $cirt_name;
		$cirt_name .= qq{ - $path};
		$ipvpn_cirt_name = $item->{ipvpn_cirt_name};
		$cirt_domain = 'NSW';
		$cirt_serv_group = $pe_locn_ttname;
	}
	
	if($cirt_name && $pe_locn_ttname && $pe_index && $cust_name && $cust_id && $if_name){
		my $inbound = qq{QOS_CLASS;$cirt_name - UM - PE - Inbound;};
		my $outbound = qq{QOS_CLASS;$cirt_name - UM - PE - Outbound;};

		my $details = qq{$pe_locn_ttname RTRPE $pe_index;$cust_name;$cust_id;$cirt_domain;$cirt_serv_group;};
		$details .= $transport.';'.$cust_id.'_'.$transport.';'.$cust_id.'_'.$transport.'_'.$cirt_domain.';'.$if_name.qq{;0;0;0;0;0;0;0;}.$bandwidth[0].';'.$bandwidth[1].';';
		
		if($item->{sero_type} eq 'TTIP-WAN'){
			$pe_locn_ttname = 'Traffic from New Zealand to Australia';
			$item->{qos_group}{inbound}{instance_name}=qq{$cirt_name - UM - PE - Inbound};
			$item->{qos_group}{inbound}{router_addr}=$pe_locn_ttname;
			$item->{qos_group}{inbound}{report_type}=qq{Traffic Class Report - From $reportWho};
		}
		print $inbound.$details.qq{Traffic Class Report - From $reportWho;$pe_locn_ttname;$reportlevel;$path;$ipvpn_cirt_name;0;0;0;0;0;0\n};
		
		if($item->{sero_type} eq 'TTIP-WAN'){
			$pe_locn_ttname = 'Traffic from Australia to New Zealand';
			$item->{qos_group}{outbound}{instance_name}=qq{$cirt_name - UM - PE - Outbound};
			$item->{qos_group}{outbound}{router_addr}=$pe_locn_ttname;
			$item->{qos_group}{outbound}{report_type}=qq{Traffic Class Report - To $reportWho};
		}
		print $outbound.$details.qq{Traffic Class Report - To $reportWho;$pe_locn_ttname;$reportlevel;$path;$ipvpn_cirt_name;0;0;0;0;0;0\n};

		#create ROUTER, WAN_IF and WAN_IF_GROUP for ttip wan circuits
		if($item->{sero_type} eq 'TTIP-WAN'){
			my @routers = $aapt_iv->getRouters($ttip_cirt_name);
			foreach my $router_ref (@routers){
				my $rc = $aapt_iv->createRouter($router_ref,$cust_id,$so_id);
				if($rc ==0){
					
					my $rc=$aapt_iv->createWAN_IF($router_ref,$ttip_cirt_name,$so_id,$cust_id,$path);
					if($rc !~ /^\d+$/){
						$item->{wan_if}{name}=$rc;
					}
				}
			}
		}

		return 1;
	}

	return "There was an error extracting details of an Unmanaged Router.  One or more of the following fields was not able to be extracted, and they are all mandatory fields :-\n\tCircuit Name: $cirt_name \t\t PE router Name: $pe_locn_ttname $pe_index\n\tCustomer Name: $cust_name \t Customer ID: $cust_id\tInterface Name: $if_name\n";
}	
#================================================================================================
#This function has not been used by any. in here just a mistake that the ttip would create wan_switch before.

sub MakeTTIPWanReport(){
	my ($dbh,$equp_id,$item,$cust_id,$cust_name,$snmp_str) = @_;

	return undef if !$dbh || !$equp_id || !$item || !$cust_id || !$cust_name;

	my $sql = qq{select	equp_ipaddress
				,equp_equt_abbreviation
				,tefi_value
				,equp_locn_ttname
				,locn_ttregion
				,equp_index
			from    equipment
				,technology_template_instance
				,locations
			where 	equp_id = ?	
				and	equp_status = 'INSERVICE'
				and     equp_id = tefi_tableid	
				and     tefi_tablename='EQUIPMENT'
				and     equp_locn_ttname = locn_ttname
				and     tefi_name = 'DNS'};
	my $sth = $dbh->prepare($sql);
	$sth->execute($equp_id);

	my $wan_name = $item->{ipvpn_cirt_name};

	if($item->{Path} == 1){
		$wan_name .= ' - Primary';
	}elsif($item->{Path} == 2){
		$wan_name .= ' - Secondary';
	}

	while(my @rows = $sth->fetchrow_array){
		my $ip_addr = $rows[0];
		my $equip_type = $rows[1];
		my $equip_dns = $rows[2];
		my $locn_name = $rows[3];
		my $locn_region = $rows[4];
		my $equip_index = $rows[5];
		my $snmp_read = $snmp_str->{$ip_addr}{'SNMP_READ'} || 'public';

		$locn_region = 'NSW!!Trans-Tasman';

		print "WAN_SWITCH;$wan_name;$equip_type;$cust_name;$cust_id;$locn_region;$locn_name;EQUIPMENT;$ip_addr;$snmp_read;4\n";
	}
	$sth->finish;
	1;
}
			
	
