package aapt_iv;

use strict;
use DBI;
use Carp;
use Data::Dumper;

BEGIN
{
        die('Perl version 5.5 or greater is required') if ($] < 5.005);
        $! = 1;
}

sub new(){
        my $proto = shift;
        my $class = ref($proto) || $proto;
        my $self = {};

        bless($self,$class);

        return undef if ! $self->_init(@_);

        return $self;
}

#===========================================================
sub _init(){
	my $self = shift;
	my ($dbh,$poller,$run_path) =  @_;

	return undef if !$dbh || !$poller || !$run_path;
	$self->{TT_CirtType} = sub{'TTIP-WAN'};
	$self->{VarName}=sub{'F-CIRCUIT USE'};
	$self->{Primary_Str}=sub{'TT INTERCONNECT - PRIMARY'};
	$self->{Secondary_Str}=sub{'TT INTERCONNECT - SECONDARY'};	
	$self->{RT_Bandwidth}=sub{'REAL TIME BANDWIDTH (BPS)'};
	$self->{INT_Bandwidth}=sub{'INTERACTIVE BANDWIDTH (BPS)'};
	$self->{BUS_Bandwidth}=sub{'BUSINESS DATA BANDWIDTH (BPS)'};
	$self->{Cirt_Speed}=sub{'CIRCUIT SPEED (BPS)'};
	$self->{DBH}=$dbh;
	$self->{POLLER}=sub{$poller};
	$self->{RUN_PATH}=sub{$run_path};
	1;
}
#===========================================================
sub Get_SO_Info(){
	my $self= shift;
	my ($prod_list,$cusr_list) = @_;

	my @prod = split(';',$prod_list);
	my @cust = split(';',$cusr_list);

	my $prod_var = join(',', map{"?"} @prod);
	my $cust_var = join(',', map{"?"} @cust);

	my @data;	
	my $dbh = $self->{DBH};

	my $sql = qq{select  sero_id,sero_cirt_name,sero_sert_abbreviation,seoa_name,seoa_defaultvalue,cirt_sped_abbreviation \
		from     service_orders \
			,circuits \
			,service_order_attributes \
		where   sero_sert_abbreviation in ($prod_var) \
		and     sero_stas_abbreviation in ('APPROVED','CLOSED') \
		and     sero_cirt_name = cirt_name \
		and     cirt_status = 'INSERVICE' \
		and 	sero_id = seoa_sero_id \
		and     sero_cusr_abbreviation in ($cust_var) \
		order by sero_cirt_name asc, \
		sero_id desc};	

	my $sth = $dbh->prepare($sql);
	$sth->execute(@prod,@cust);

	my $data_struct;

	while(my @row = $sth->fetchrow_array){
		if($data_struct && 
			$row[0] eq $data_struct->{sero_id} &&
			$row[1] eq $data_struct->{cirt_name} &&
			$row[2] eq $data_struct->{sero_type}){

			$data_struct->{sero_attr}{$row[3]}=$row[4];
		}else{
			undef $data_struct;
			$data_struct->{sero_id}=$row[0];
			$data_struct->{cirt_name}=$row[1];
			$data_struct->{sero_type}=$row[2];
			$data_struct->{cirt_sped_type}=$row[5];
			$data_struct->{Path}=0;

			#get vars from circuit attributes
			$data_struct->{sero_attr}=$self->getBandwidth($row[0]);
			$data_struct->{sero_attr}{$row[3]}=$row[4];
			
			push @data,$data_struct;
		}
	}
	$sth->finish;
	
	@data = $self->Confirm_TTIP_Cirt(@data);
	@data;
}
#===========================================================
sub Confirm_TTIP_Cirt(){
	my $self = shift;
	
	my @data = @_;
	my $dbh = $self->{DBH};
	my $reverse;

	my $sql = qq{select port_cirt_name \
			from port_hierarchy,ports \
			where port_cirt_name is not null and 
			porh_childid=port_id and porh_parentid in \
			(select port_id from ports where port_cirt_name=?)};
		

	foreach my $item (@data){
		if($item->{sero_type} eq $self->{TT_CirtType}->()){
			my $cirt_name = $item->{cirt_name};
			my $sth = $dbh->prepare($sql);
			$sth->execute($cirt_name);
			while(my @row = $sth->fetchrow_array){
				$item->{ipvpn_cirt_name}=$row[0];
				$reverse->{$row[0]} +=1;
			}
			$sth->finish;
		}
	}

	#now we've got them all, then we walk back to see which one is missing
	#there should be 2 ttip-wan circuits only the linked to a single ipvpn circuit
	foreach my $ipvpn (keys %{$reverse}){
		if($reverse->{$ipvpn} != 2){
			for(my $index=0; $index<=$#data; $index++){
				my $item = $data[$index];

				if($item->{ipvpn_cirt_name} eq $ipvpn){
					$data[$index]=undef;
					#error message goes here, but continue on
					$self->_Set_Error("Circuit $ipvpn has ".$reverse->{$ipvpn}." TTIP-WAN circuits. Should only be two");
				}	
			}
		}else{	#if the number of circuits are correct then check the attributes
			my $pri=0;	#primary found flag
			my $secd=0;	#secondary found flag
			#tt circuits index marks
			my @marks;

			for(my $index=0;$index<=$#data;$index++){
				my $item = $data[$index];
						
				next if $item->{sero_type} ne $self->{TT_CirtType}->();
				next if $item->{ipvpn_cirt_name} ne $ipvpn;
					

				my $attr=$item->{sero_attr};

				my $name = $self->{VarName}->();
				
				if(uc($attr->{$name}) eq $self->{Primary_Str}->()){
					$item->{Path}=1;	#mark as primary
					$pri++;
					push @marks,$index;
				}
				if(uc($attr->{$name}) eq $self->{Secondary_Str}->()){
					$item->{Path}=2;	#mark as secondary
					$secd++;
					push @marks,$index;
				}

			}

			if($pri == 1 && $secd ==1){	#everything ok, then we need to check the parameters
				my $ip_cirt1 = $data[$marks[0]];
				my $ip_cirt2 = $data[$marks[1]];
				my $f_rt_name = $self->{RT_Bandwidth}->();
				my $f_int_name = $self->{INT_Bandwidth}->();
				my $f_bus_name = $self->{BUS_Bandwidth}->();

				if($ip_cirt1->{sero_attr}{$f_rt_name} ne $ip_cirt2->{sero_attr}{$f_rt_name}){
					$self->_Set_Error("The value of Service Attribute of $f_rt_name between $ip_cirt1->{cirt_name} and $ip_cirt2->{cirt_name} are different, should be same");
					foreach my $ind (@marks){
						$data[$ind]=undef;
					}
				}elsif($ip_cirt1->{sero_attr}{$f_int_name} ne $ip_cirt2->{sero_attr}{$f_int_name}){
					$self->_Set_Error("The value of Service Attribute of $f_int_name between $ip_cirt1->{cirt_name} and $ip_cirt2->{cirt_name} are different, should be same");
					foreach my $ind (@marks){
						$data[$ind]=undef;
					}
				}elsif($ip_cirt1->{sero_attr}{$f_bus_name} ne $ip_cirt2->{sero_attr}{$f_bus_name}){
					$self->_Set_Error("The value of Service Attribute of $f_bus_name between $ip_cirt1->{cirt_name} and $ip_cirt2->{cirt_name} are different, should be same");
					foreach my $ind (@marks){
						$data[$ind]=undef;
					}
				}elsif($ip_cirt1->{sero_attr}{$f_rt_name} eq '' || $ip_cirt2->{sero_attr}{$f_rt_name} eq '' ||
					$ip_cirt1->{sero_attr}{$f_int_name} eq ''|| $ip_cirt2->{sero_attr}{$f_int_name} eq '' ||
					$ip_cirt1->{sero_attr}{$f_bus_name} eq '' || $ip_cirt2->{sero_attr}{$f_bus_name}eq ''){

					$self->_Set_Error(qq{Service Attributes of $ip_cirt1->{cirt_name} or $ip_cirt2->{cirt_name} have not been created correctly, some required service attributes are missing});
					foreach my $ind (@marks){
						$data[$ind]=undef;
					}
				}
			}else{

				foreach my $ind (@marks){
					$data[$ind]=undef;
				}

				if($pri>1){
					$self->_Set_Error("Circuit $ipvpn has $pri TTIP-WAN circuit with Circuit Use=".$self->{Primary_Str}->().".Should only be one");
				}
				if($secd >1){
					$self->_Set_Error("Circuit $ipvpn has $secd TTIP-WAN circuit with Circuit Use=".$self->{Secondary_Str}->().".Should only be one");
				}

				if($pri == 0){
					$self->_Set_Error("Primary TTIP circuit missing for $ipvpn");
				}
				if($secd ==0){
					$self->_Set_Error("Secondary TTIP circuit missing for $ipvpn");
				}
				
			}
			my @temp_data;
			foreach my $item (@data){
				if($item != undef){
					push @temp_data,$item;
				}
			}
			@data=@temp_data;	
		}
			
	}

	@data;
}

sub _Set_Error(){
	my $self = shift;
	my $msg = shift;

	return if !$msg;
	$self->{Error} .= $msg."\n";
}
	

sub Check_TT_Error(){
	my $self = shift;
	$self->{Error};
}
# getInterface - Get the Interface name
#
# Parameters:  Circuit, Router Type
#
# Returns:     Interface name

sub getInterface()
{
	my $self = shift;
    my ($circuit,$router_type,$rtrce_port_name) = @_;

	my $dbh = $self->{DBH};
    my $sql =   "select  port_card_slot
                        ,port_id
                        ,port_name
                 from    ports
                        ,equipment
                 where   port_cirt_name = ?
                 and     port_status = 'INSERVICE'
                 and     port_equp_id = equp_id
                 and     equp_equt_abbreviation = ?";

    my $sth = $dbh->prepare($sql);
    $sth->execute($circuit, $router_type);
    my @port_dets = $sth->fetchrow_array;

    my $card_name = $port_dets[0];
    my $port_id = $port_dets[1];
    my $port_name = $port_dets[2];
    my @sp = split (" ", $port_name);
    $card_name =~ s/^\s*0+(\d)$/$1/;

# Get the parent port

    $sql =      "select  port_name
                        ,port_id
                        ,port_relation
                 from    ports
                        ,port_hierarchy
                 where   porh_childid = ?
                 and     port_id = porh_parentid";

    $sth = $dbh->prepare($sql);
    $sth->execute($port_id);
    my @parent_port_name = $sth->fetchrow_array;

    my $if_name;
    if ($parent_port_name[0] =~ /^SER/)
    {
# E3 links have a Serial port in the middle, but we need
# to format them different, so check if the parent port has
# a parent of its own.

        my $port_nbr = $sp[0];
        $port_nbr =~ s/^PVC-//;
        $port_nbr =~ s/^\s*0+(\d)/$1/;

        if ($parent_port_name[2] eq "BOTH")
        {
            my $grpdlci;

            if (defined $sp[1])
            {
                my @sp2 = split("/", $sp[1]);
                my $cgroup = $sp2[0];
                $cgroup =~ s/^\s*0+(\d)/$1/;
                my $dlci = $sp2[1];
                $dlci =~ s/^\s*0+(\d)/$1/;
                $grpdlci = ":" . $cgroup. "." . $dlci;
            }

            if ($card_name eq "NA")
            {
                $if_name = "Serial" . $port_nbr . $grpdlci;
            }
            else
            {
                $if_name = "Serial" . $card_name . "/" . $port_nbr . $grpdlci;
            }
        }
        else
        {
            my $dlci;
            if (defined $sp[1])
            {
                $dlci = "." . $sp[1];
            }

            if ($card_name eq "NA")
            {
                $if_name = "Serial" . $port_nbr . $dlci;
            }
            else
            {
                $if_name = "Serial" . $card_name . $dlci;
            }
        }
    }
    elsif ($parent_port_name[0] =~ /^(VC|T3)/)
    {
        my $vpivci;
        my $port_nbr = $sp[0];
        $port_nbr =~ s/^PVC-//;
        if (defined $sp[1])
        {
            my @sp2 = split("/", $sp[1]);
            my $vpi = $sp2[0];
            my $vci = $sp2[1];
            $vpi =~ s/^\s*0+(\d)/$1/;
            $vpivci = "." . $vpi . $vci;
        }

        if ($card_name eq "NA")
        {
            $if_name = "ATM" . $port_nbr . $vpivci;
        }
        else
        {
            $if_name = "ATM" . $card_name . "/" . $port_nbr . $vpivci;
        }

        if ($router_type eq "RTRPE")
        {
            $if_name = $if_name . "-aal5 layer";
        }
    }
    elsif ($parent_port_name[0] =~ /^ETH/)
    {
        $parent_port_name[0] =~ s/^ETH-LN//;

	if($card_name eq 'NA'){
		$if_name = "Ethernet" .$parent_port_name[0];
	}else{
		$if_name = "Ethernet" . $card_name ."/".$parent_port_name[0];
	}

    }
    elsif ($parent_port_name[0] =~ /^FA/)
    {
        $parent_port_name[0] =~ s/^FA-LN//;
        if (defined $parent_port_name[0])
        {
            $parent_port_name[0] =~ s/^\s*0+(\d)/$1/;
            my $vlanid = "";

            if ($router_type eq "RTRPE")
            {
                $parent_port_name[0] =~ s/^\s*0+(\d)/$1/;

                my @sp3 = split(" ", $rtrce_port_name);
                $vlanid = $sp3[1];
                $vlanid =~ s/^\s*0+(\d)/$1/;
                $vlanid = "." . $vlanid;
            }

            $parent_port_name[0] = $parent_port_name[0] . $vlanid;
        }

	if($card_name ne 'NA'){
        	$if_name = "FastEthernet" . $card_name ."/". $parent_port_name[0];
	}else{
		$if_name = "FastEthernet" .$parent_port_name[0];
	}

        if ($router_type eq "RTRPE")
        {
            $if_name = $if_name . "-802.1Q vLAN subif";
        }
    }
    elsif ($parent_port_name[0] =~ /^1GE/)
    {
        $parent_port_name[0] =~ s/^1GE-LN//;
        if (defined $parent_port_name[0])
        {
            $parent_port_name[0] =~ s/^\s*0+(\d)/$1/;
            my $vlanid = "";

            if ($router_type eq "RTRPE")
            {
                $parent_port_name[0] =~ s/^\s*0+(\d)/$1/;

                my @sp3 = split(" ", $rtrce_port_name);
                $vlanid = $sp3[1];
                $vlanid =~ s/^\s*0+(\d)/$1/;
                $vlanid = "." . $vlanid;
            }

            $parent_port_name[0] =  $parent_port_name[0] . $vlanid;
        }

	if($card_name ne 'NA'){
        	$if_name = "GigabitEthernet" . $card_name ."/". $parent_port_name[0];
	}else{
		$if_name = "GigabitEthernet" .$parent_port_name[0];
	}

        if ($router_type eq "RTRPE")
        {
            $if_name = $if_name . "-802.1Q vLAN subif";
        }
    }
    return ($if_name,$port_name);
}
#=============================================================================
sub getBandwidth
{
	my $self = shift;
	my ($sero_id,$format) = @_;
	return undef if !$sero_id;

	my $data;

	my $dbh = $self->{DBH};

    my $sql =   "select  seti_name
                        ,seti_value
                 from    service_template_instance
                        ,circuits
                 where   seti_tableid = cirt_name
                 and     seti_tablename = 'CIRCUITS'
                 and     cirt_sere_id = ?
                 and     upper(seti_name) in (?,?,?,?)";

    my $sth = $dbh->prepare($sql);
    $sth->execute($sero_id,$self->{RT_Bandwidth}->(),$self->{INT_Bandwidth}->(),$self->{BUS_Bandwidth}->(),$self->{Cirt_Speed}->());

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
	my $name = uc($bandwidth[0]);

        if ($name eq $self->{RT_Bandwidth}->())
        {
            $return[0] = $bandwidth[1];
		$data->{$name}=$bandwidth[1];
        }
        elsif ($name eq $self->{INT_Bandwidth}->())
        {
	
            $return[1] = $bandwidth[1];
		$data->{$name}=$bandwidth[1];
        }
        elsif ($name eq $self->{BUS_Bandwidth}->())
        {
            $return[2] = $bandwidth[1];
		$data->{$name}=$bandwidth[1];
        }elsif ($name eq $self->{Cirt_Speed}->())
	{
		$data->{$name}=$bandwidth[1];
	}

    }

    return @return if $format eq 'array';
	return $data;
}
#====================================================================
sub getSnmpString(){
	my $self = shift;
	my ($ne_id,$ne_type,$readname,$writename) = @_;

	my $dbh = $self->{DBH};
	my $data;

	return undef if !$ne_id || !$ne_type || !$readname || !$writename;

	        #---------find SNMP r/w community strings from equipment parameters table----
        my $sql = qq{select tefi_name,tefi_value from TECHNOLOGY_TEMPLATE_INSTANCE \
                        where tefi_tablename=? and tefi_tableid=? \
                        and tefi_name in (?,?)};

        my $para_sth = $dbh->prepare($sql);
        $para_sth->execute($ne_type,$ne_id,$readname,$writename);
        while(my @rows = $para_sth->fetchrow_array){
                $data->{$rows[0]} = $rows[1];
        }
        $para_sth->finish;

	$data;
}
#====================================================================
#Find the routers by circuit name
#Return error on undefined or 110. return router array as successful
sub getRouters(){
	my $self = shift;
	my $cirt_name = shift;

	return undef if !$cirt_name;

	my $dbh = $self->{DBH};

	my $sql =   "select  equp_locn_ttname
			,equp_index
			,equp_ipaddress
			,equp_manr_abbreviation
			,equp_equm_model
			,equp_id
			,cirt_sert_abbreviation
			,cirt_sped_abbreviation
			,equp_equt_abbreviation
		from    ports
			,equipment
			,circuits
		where   port_cirt_name = '$cirt_name'
		and     cirt_name = port_cirt_name
		and     port_status = 'INSERVICE'
		and     port_equp_id = equp_id
		and     equp_equt_abbreviation in ('RTRCE','RTRPE')";

	my $router_refs = $dbh->selectall_arrayref($sql);
	my @routers;
	foreach my $rref (@{$router_refs})
	{
		if(($rref->[8] eq 'RTRPE' &&
			$rref->[7] eq 'IP' &&
			$rref->[6] eq 'TTIP-WAN') || ($rref->[6] ne 'TTIP-WAN' && $rref->[8] eq 'RTRCE')){
			push(@routers, $rref);
		}
	}

	# Check how many routers we have - if we have zero or more
	# than two, error time.

	my $array_size = scalar(@routers);

	if (($array_size == 0) or
		($array_size > 2)){
		return 110;
	}else{
		return @routers;
	}
}
#====================================================================
# getRouterAddr - Get the address of a router.
#
# Parameters:   Router Reference
#
# Returns:      None

sub getRouterAddr
{
	my $self = shift;

    my $router_ref = shift;

	return undef if !$router_ref;

	my $dbh = $self->{DBH};
    my $router_locn = $router_ref->[0];

    my $sql =   "select  locn_number
                        ,locn_street
                        ,locn_strt_name
                        ,locn_suburb
                 from    locations
                 where   locn_ttname = ?";
  
    my $sth = $dbh->prepare($sql);
    $sth->execute($router_locn);
    my $locn_ref = $sth->fetchrow_arrayref();

    foreach my $lref (@$locn_ref)
    {
        unless (defined $lref)
        {
            $lref = " ";
        }
    }
    my $address = $locn_ref->[0] . " " . $locn_ref->[1] . " " . $locn_ref->[2] . ", " . $locn_ref->[3];

    return $address;
}

#====================================================================
sub getProjDetails(){
	my $self = shift;
	my $so_id = shift;

	return undef if !$so_id;

	my $proj_title;
	my $snumber;

	my $dbh = $self->{DBH};

	my $sql = qq{select cusp_projecttitle,cusp_projectnumber
		from service_orders,customer_projects
		where sero_id = ? and sero_cusp_projectid = cusp_projectid};

	my $sth = $dbh->prepare($sql);
	$sth->execute($so_id);

	while(my @rows = $sth->fetchrow_array){
		$proj_title=$rows[0];
		$snumber = $rows[1];
	}
	$sth->finish;	
	return ($proj_title,$snumber);
}
	
#====================================================================
sub createRouter
{
	my $self = shift;
    my ($router_ref,$cusr_abbr,$sero_id) = @_;
    my @router;

	return undef if !$router_ref || !$cusr_abbr || !$sero_id;
 
	my $router_addr = $self->getRouterAddr($router_ref);

	my ($proj_title,$snumber) = $self->getProjDetails($sero_id);

	my ($cust_name,$report_lvl) = $self->getCusr($cusr_abbr); 

    push (@router, "ROUTER");
    my $router_name = $router_ref->[0] . ' '.$router_ref->[8].' '. $router_ref->[1];
    push (@router, $router_name);
    my $temp = $router_ref->[3] . "_ROUTER";
    push (@router, $temp);
    push (@router, $cust_name);
    push (@router, $cusr_abbr);
    push (@router, $router_addr);
    my $state = $self->getState($router_ref->[0]);
    push (@router, $state);
    my $slocn = $proj_title . " - " . $snumber;
    push (@router, $router_ref->[0]);
    push (@router, "EQUIPMENT");
    $temp = $cusr_abbr . "_EQUIPMENT";
    push (@router, $temp);
    $temp = $temp . "_" . $state;
    push (@router, $temp);
    push (@router, $router_ref->[4]);

# If the IP Address doesn't exist, error it.

    if (defined ($router_ref->[2]))
    {
        push (@router, $router_ref->[2]);
    }
    else
    {
        return 113;
    }

    my ($snmprd, $snmpwr);


        my $snmp = $self->getSnmpString($router_ref->[5],'EQUIPMENT','SNMP_READ','SNMP_WRITE');
        my $snmp2 = $self->getSnmpString($router_ref->[5],'EQUIPMENT','SNMP READ String','SNMP WRITE String');
        if(!$snmp->{'SNMP_READ'}){
                if($snmp2->{'SNMP READ String'}){
                        $snmprd = $snmp2->{'SNMP READ String'};
                }else{
                        $snmprd = 'public';
                }
        }else{
                $snmprd = $snmp->{'SNMP_READ'};
        }

        if(!$snmp->{'SNMP_WRITE'}){
                if($snmp2->{'SNMP WRITE String'}){
                        $snmpwr = $snmp2->{'SNMP WRITE String'};
                }else{
                        $snmpwr = 'private';
                }
        }else{
                $snmpwr = $snmp->{'SNMP_WRITE'};
        }



  #  if (defined $snmp{$router_ref->[5]}[0])
  #  {
#       $snmprd = $snmp{$router_ref->[5]}[0];
#    }
#    else
#    {
#       $snmprd = "public";
#    }
#    if (defined $snmp{$router_ref->[5]}[1])
#    {
#       $snmpwr = $snmp{$router_ref->[5]}[1];
#    }
#    else
#    {
#       $snmpwr = "private";
#    }

    push (@router, $snmprd);
    push (@router, $snmpwr);
    push (@router, $router_name);
    push (@router, $report_lvl);

    my $temp_routername = $router_name;
    $temp_routername =~ s/\//\-/g;

	
    my $router_file_name = $self->{RUN_PATH}->() . "/files/serv-" . $self->{POLLER}->() . "-" . $temp_routername . ".router.ready";
    $router_file_name =~ s/ /\-/g;

    open (ROUTER, ">$router_file_name")
        or die "Error opening $router_file_name : $!\n";
    print ROUTER join(";", @router) . "\n";
    close (ROUTER);

    return 0;
}
#====================================================================
# getCusr - Get the Customer details
#
# Parameters:   Customer ID
#
# Returns:      Pointer to customer details

sub getCusr
{
	my $self = shift;
    my $cusr_abbr = shift;
    my @cusr_row;

	my $dbh = $self->{DBH};

    my $sql =   "select  cusr_name
                 from    customer
                 where   cusr_abbreviation = ?";

    my $sth = $dbh->prepare($sql);
    $sth->execute($cusr_abbr);
    my @result = $sth->fetchrow_array;

    if (defined $result[0])
    {
        my $name = $result[0];
        $name =~ s/,/ /g;
        $name =~ s/\(/ /g;
        $name =~ s/\)/ /g;
        $name =~ s/\s+$//;
        push (@cusr_row, $name);
    }

    $sql =      "select  conp_cont_abbreviation
                 from    contact_points
                 where   conp_cusr_abbreviation = ?
                 and     conp_cont_abbreviation like 'CRPTLVL%'";

    $sth = $dbh->prepare($sql);
    $sth->execute($cusr_abbr);
    my $report_lvl = $sth->fetchrow_array;

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
    push (@cusr_row, $report_lvl);
    return @cusr_row;
}
#====================================================================
# getState - Get a location's state.
#
# Parameters:   Location Name
#
# Returns:      State

sub getState
{
	my $self = shift;
    my $locn_name = shift;

	my $dbh = $self->{DBH};

    my $sql =   "select  locn_state
                 from    locations
                 where   locn_ttname = '$locn_name'";

    my $result = $dbh->selectrow_array($sql);
    return $result;
}

#====================================================================
# createWAN_IF - Create a WAN_IF instance.
#
# Parameters:   None
#
# Returns:      None

sub createWAN_IF()
{
# Work through the active cards for a router,
# ignore the Main Unit cards.

	my $self = shift;
    my ($router_ref,$cirt_name,$so_id,$cusr_abbr,$path) = @_;

	return undef if !$router_ref || !$cirt_name || !$so_id || !$cusr_abbr;

    my $router_locn = $router_ref->[0];
    my $router_equp_id = $router_ref->[5];
	my $dbh = $self->{DBH};
    my $pe_port_name;
	my $wanif_name;

    my $sql =   "select  card_slot
                 from    equipment
                        ,cards
                 where   equp_id = ?
                 and     card_equp_id = equp_id
                 and     card_status = 'INSERVICE'";
  
    my $sth = $dbh->prepare($sql);
    $sth->execute($router_equp_id);
    my $card_refs = $sth->fetchall_arrayref();

    foreach my $cref (@{$card_refs})
    {
        $sql =  "select  port_name
                        ,port_cirt_name
                 from    ports
                 where   port_equp_id = ?
                 and     port_cirt_name is not null
                 and     port_status = 'INSERVICE'
                 and     port_card_slot = ?";

        if($router_ref->[6] eq 'TTIP-WAN'){
                $sql .= qq{ and port_cirt_name = '$cirt_name'};
        }

        my $sth = $dbh->prepare($sql);
        my $card_slot = $cref->[0];
        $sth->execute($router_equp_id, "$card_slot");
        my $port_refs = $sth->fetchall_arrayref();

        foreach my $pref (@{$port_refs})
        {
            my $port_name = $pref->[0];
            my $alarm_port_name = $port_name;
            my $alarm_card_slot = $card_slot;
            my $parent_cirt_name = $pref->[1];
            my @wanif;
            my $if_name;
		my $card_nbr = $card_slot;
            #my $card_nbr = substr($card_slot, 1, 1);
            my $use_if_descr = "1";

# Work out the interface name.  Converting it is based
# on the port usage.

	    $card_nbr = sprintf("%d",$card_nbr) if $card_nbr =~ /^\d+$/;

	    if ($port_name =~ /DSL/)
	    {
		if (($port_name eq "DSL") or
		    ($port_name eq "ADSL"))
		{
		    $if_name = 'ATM0';
		}
		else
		{
		    $port_name =~ /DSL-LN(.*)/g;
		    my $subif = $1;

		    # Remove any leading zeroes from the subinterface

		    $subif *= 10;
		    $subif /= 10;

		    if ($card_nbr eq "NA")
		    {
			$if_name = "ATM$subif";
		    }
		    else
		    {
			# Remove any leading zeroes from the card number
		    
			$card_nbr *= 10;
			$card_nbr /= 10;

			$if_name = "ATM$card_nbr/$subif";
		    }
		}
	    }
            elsif ($port_name =~ /BRI/)
            {
                $port_name =~ s/\-LN//;
                $if_name = $port_name;
                $use_if_descr = "2";
            }
            elsif ($port_name =~ /SER/)
            {
                my @sp = split (" ", $port_name);
                my $port_nbr = $sp[0];
                my $channel_grp = $sp[1];
                $port_nbr =~ s/^SER\-//;
		$port_nbr =~ s/^\s*0+(\d)/$1/;
		$channel_grp =~ s/^\s*0+(\d)/$1/;

# If the SUBIF_NBR doesn't exist - we have a port name like
# SER-0 or something similar - so we use the small router
# routine.

		if ($card_nbr eq "NA"){
			$if_name = "Serial" . $port_nbr;

			if (defined ($channel_grp)){
				$if_name = $if_name . ":$channel_grp";
			}
		}else{
			$if_name = "Serial" . $card_nbr . "/$port_nbr";
		
			if (defined ($channel_grp)){
				$if_name = $if_name . ":$channel_grp";
			}
		} 

            }elsif($router_ref->[7] eq 'IP' &&
                        $router_ref->[6] eq 'TTIP-WAN'){

                ($if_name,$pe_port_name) = $self->getInterface($cirt_name,'RTRPE',$port_name);


            }else
            {
# If its an unknown port type - don't extract it.
                next;
            }

            push (@wanif, "WAN_IF");

            $sql =      "select  cirt_sped_abbreviation
                                ,sped_bitrate
                         from    circuits
                                ,speeds
                         where   cirt_name = ?
                         and     sped_abbreviation = cirt_sped_abbreviation";

            my $router_name = $router_ref->[0] . ' '.$router_ref->[8].' '. $router_ref->[1];
	    $wanif_name = $router_name . " " . $if_name;

            if($router_ref->[7] eq 'IP' && $router_ref->[6] eq 'TTIP-WAN'){
                $sql = qq{select 'IP',seti_value
                        from circuits,service_template_instance
                        where cirt_name = ? and cirt_name = seti_tableid
                        and seti_tablename = 'CIRCUITS' and upper(seti_name)='CIRCUIT SPEED (BPS)'};
		$wanif_name = $cirt_name;
	    }	

            $sth = $dbh->prepare($sql);
            $sth->execute($parent_cirt_name);
            my @cirt_speed = $sth->fetchrow_array();
            if($cirt_speed[1] !~ /^\d+$/){
                        #writeError(115);
                        next;
            }


		if($path){
            		$wanif_name .= " - $path";
		}
			

	    my ($cusr_name,$report_lvl) = $self->getCusr($cusr_abbr);
	    my ($proj_title,$snumber) = $self->getProjDetails($so_id);
	    my $router_addr = $self->getRouterAddr($router_ref);

		if($router_ref->[6] eq 'TTIP-WAN'){
			$router_addr = 'Trans-Tasman Interconnect';
		}
            push (@wanif, $wanif_name);
            push (@wanif, $router_name);
            push (@wanif, $cusr_name);
            push (@wanif, $cusr_abbr);
            push (@wanif, $router_addr);
            my $state = $self->getState($router_ref->[0]);
            push (@wanif, $state);
            my $slocn = $proj_title . " - " . $snumber;
            push (@wanif, $router_ref->[0]);
            push (@wanif, "ACCESS");
            my $temp = $cusr_abbr . "_ACCESS";
            push (@wanif, $temp);
            $temp = $temp . "_" . $state;
            push (@wanif, $temp);
		if($router_ref->[6] eq 'TTIP-WAN'){
			push (@wanif, "TTIP-WAN");
		}else{
            		push (@wanif, "");
		}
            push (@wanif, $use_if_descr);
            push (@wanif, "0");
            push (@wanif, $if_name);
            push (@wanif, $cirt_speed[0]);
            $cirt_speed[1] = $cirt_speed[1] * 1000;

            if ($cirt_speed[1] < 0 && $router_ref->[6] ne 'TTIP-WAN')
            {
                return 114;
            }
            push (@wanif, $cirt_speed[1]);
            push (@wanif, $router_name);
            push (@wanif, $alarm_card_slot);
            push (@wanif, $alarm_port_name);
            push (@wanif, $report_lvl);

            my $wanif_file_name = "serv-" . $self->{POLLER}->() . "-" . $wanif_name . ".wanif.ready";

# Remove some of the chars that dont fit into unix file names.

            $wanif_file_name =~ s/ /\-/g;
            $wanif_file_name =~ s/\//\-/g;
            $wanif_file_name =~ s/\:/\-/g;

            $wanif_file_name = $self->{RUN_PATH}->() . "/files/" . $wanif_file_name;

            open (WANIF, ">$wanif_file_name")
                or die "Error opening $wanif_file_name : $!\n";
            print WANIF join(";", @wanif) . "\n";

            close (WANIF)
        }
    }
	return $wanif_name;
}





1;
