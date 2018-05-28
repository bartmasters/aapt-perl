#######################<< COPY RIGHT >>###################################
#       Network Application     AAPT Limited
#
#       File:           $RCSfile: Saa.pm,v $      
#
#       Source:         $Source: /pace/ProdSRC/infovista/cvs/glbncs4/bin/Saa.pm,v $       
#
#       Author:         Sam G.L YANG
#       Email:          syang@aapt.com.au 
#
#       Version:        $Revision: 1.8 $
#       Date:           1 August 2003
#       Last Changes:   $Date: 2006/03/27 03:17:18 $
#
###########################################################################
#       RCS Log:        $Log: Saa.pm,v $
#       RCS Log:        Revision 1.8  2006/03/27 03:17:18  bamaster
#       RCS Log:        Changes for Bioss Upgrades project
#       RCS Log:
#       RCS Log:        Revision 1.7  2004/09/17 06:23:41  syang
#       RCS Log:        Fixed bug that dual load data
#       RCS Log:
#       RCS Log:        Revision 1.6  2004/08/12 23:46:39  syang
#       RCS Log:        Fixed a bug to ensure tail conformance flag always set for SAA output data
#       RCS Log:
###########################################################################

package saa;

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

	return undef if ! $self->_init(shift @_);

	return $self;
}

#============================================================================================
sub _init(){
	my $self = shift;
	my $arg = shift @_;

	if(!$arg){
		my $msg = qq{Initiate object with following arguments:\n\
				new( {'poller' => 'hvt', 'run_path' => './', \n \
				'error_file' => 'error.log', 'db_userid' => 'scott',\n\
				'db_pass' => 'tiger', 'db_sid' => 'mydb','customer'=>(a,b,c)});\n};
		croak $msg;
	}


	if($arg->{poller}){
		$self->{poller} = $arg->{poller};
	}else{
		croak "poller argument missing\n";
	}

	if($arg->{run_path}){
		$self->{run_path} = $arg->{run_path};
	}else{
		croak "run_path argument missing\n";
	}

	if($arg->{error_file}){
		$self->{error_file}=$arg->{error_file};
	}else{
		croak "error_file argument missing\n";
	}
	
	if(!$arg->{db_userid}){
		croak "db_userid argument missing\n";
	}

	if(!$arg->{db_pass}){
		croak "db_pass argument missing\n";
	}

	if(!$arg->{db_sid}){
		croak "db_sid argument missing\n";
	}

	if($arg->{customers}){
		$self->{customers}=\@{$arg->{customers}};
	}else{
		croak "customer list missing\n";
	}

	$self->{CONSTANT}{Cust_RT_bandwidth_name}=sub {qq{REAL TIME BANDWIDTH (BPS)}};
	$self->{CONSTANT}{Cust_IA_bandwidth_name} = sub {qq{INTERACTIVE BANDWIDTH (BPS)}};
	$self->{CONSTANT}{Cust_Tail_Conformance} = sub {qq{TAIL CONFORMANCE}};
	$self->{CONSTANT}{Cust_FIP_SOA_Config_name}=sub {qq{T-CW2000 ROUTER CONFIG FILE NAME}};
	$self->{CONSTANT}{Cust_FIP_SOA_IP_name}=sub {qq{T-ETHERNET IP ADDRESS}};
	
	open(ERR,">$self->{error_file}") || croak "Failed to open $self->{error_file}";
	$self->{error_fh}=*ERR;

	my $dbh=$self->_db_connect($arg->{db_userid},$arg->{db_pass},$arg->{db_sid});
	return undef if !$dbh;
	$self->{dbh}=$dbh;

	$self->{data}=undef;

	$arg;
}
#============================================================================================
sub Run(){
	my $self=shift;

	return undef if !$self->_get_xconnects();

	#start to get end node bandwidths
	return undef if !$self->_get_bandwidth();

	return undef if !$self->_create_output();

	1;
}
#============================================================================================
sub DESTROY(){
	my $self = shift;

	my $dbh = $self->{dbh};
	$dbh->disconnect if $dbh;
	$self->{dbh}=undef;
	my $fh = $self->{error_fh};
	close($fh) if $fh;
}
#============================================================================================
sub _create_output(){
	my $self = shift;

	my $poller = $self->{poller};
	my $data = $self->{data};

	return undef if !$poller || !$data;

	my $run_path=$self->{run_path};
	my $filename;
	my $entry;
	
	foreach my $lev1 (sort keys(%{$data})){
		next if !defined($data->{$lev1}{'host_nodes'}) || !defined($data->{$lev1}{'end_nodes'});

		##work on host node##

		my $host=$data->{$lev1}{'host_nodes'};
		my $host_node;
				
		##work on end node##			
		foreach my $lev2 (sort keys(%{$data->{$lev1}{'end_nodes'}})){
			my $end_node = $data->{$lev1}{end_nodes}{$lev2};
			if(defined $end_node->{'interactive_report'} || defined $end_node->{'realtime_report'}){

				my $snmpread;
				my $snmpwrite;

				#create host node router entry only once for this level
				foreach my $hnode (keys %{$host}){
					last if $host_node;

					$filename=$hnode;
					$filename =~s/\s/-/g;
					$filename =~s/\//-/g;
					if(!open(RTR,">$run_path/files/serv-$poller-$filename.router.ready")){
						$self->_error(qq{Failed to open output file: $run_path/files/serv-$poller-$filename.router.ready});
						return undef;
					}
					$entry = qq{ROUTER;$hnode;CISCO_ROUTER;$host->{$hnode}{'cust_name'};};
					$entry.=qq{$host->{$hnode}{'cust_id'};$host->{$hnode}{address};};
					$entry.=qq{$host->{$hnode}{domain};$host->{$hnode}{locn_ttname};};
					$entry.=qq{EQUIPMENT;$host->{$hnode}{cust_id}_EQUIPMENT;};
					$entry.=qq{$host->{$hnode}{cust_id}_EQUIPMENT_$host->{$hnode}{domain};};

					$snmpread='InfoVista';
					$snmpwrite='InfoVista';
					if($host->{$hnode}{equipment_id}){
						my $snmp = $self->_get_snmp_string($host->{$hnode}{equipment_id});
						if($snmp->{SNMP_READ}){
							$snmpread = $snmp->{SNMP_READ};
						}

						if($snmp->{SNMP_WRITE}){
							$snmpwrite=$snmp->{SNMP_WRITE};
						}
					}
					$entry.=qq{$host->{$hnode}{equipment_model};$host->{$hnode}{equipment_ip};$snmpread;$snmpwrite;$hnode;0\n};
					print RTR $entry;
					close(RTR);
					$host_node=$host->{$hnode};
				}
				
				#END NODEs	
				#create an router entry

				$filename=$lev2;
				$filename=~ s/\s/-/g;	
				$filename=~ s/\//-/g;
				if(!open(RTR,">$run_path/files/serv-$poller-$filename.router.ready")){
					$self->_error(qq{Failed to open output file: $run_path/files/serv-$poller-$filename.router.ready});
					return undef;
				}

				$entry=qq{ROUTER;$lev2;CISCO_ROUTER;$end_node->{'cust_name'};};
				$entry.=qq{$end_node->{'cust_id'};$end_node->{address};};
				$entry.=qq{$end_node->{domain};$end_node->{locn_ttname};};
				$entry.=qq{EQUIPMENT;$end_node->{cust_id}_EQUIPMENT;};
				$entry.=qq{$end_node->{cust_id}_EQUIPMENT_$end_node->{domain};};

				$snmpread='InfoVista';
				$snmpwrite='InfoVista';

				if($end_node->{equipment_id}){
					my $snmp=$self->_get_snmp_string($end_node->{equipment_id});
					if($snmp->{SNMP_READ}){
						$snmpread=$snmp->{SNMP_READ};
					}
					if($snmp->{SNMP_WRITE}){
						$snmpwrite=$snmp->{SNMP_WRITE};
					}
				}
				$entry.=qq{$end_node->{equipment_model};$end_node->{equipment_ip};$snmpread;$snmpwrite;$lev2;0\n};

				print RTR $entry;
				close(RTR);

				#create SA Agent entry

				if(!open(SAA,">$run_path/files/serv-$poller-$filename.saa.ready")){
					$self->_error("Failed to open $run_path/files/serv-$poller-$filename.saa.ready");
					next;
				}

				if($end_node->{'realtime_report'}){
					#Instance type
					$entry= qq{SA_AGENT;};
					
					#Instance name
					$entry.= qq{RealTime-$end_node->{locn_ttname} $end_node->{equipment_type}$end_node->{equipment_index}-$host_node->{locn_ttname} $host_node->{equipment_type}$host_node->{equipment_index};};
		
					#router name
					$entry.= qq{$end_node->{locn_ttname} $end_node->{equipment_type} $end_node->{equipment_index};};
				
					#customer ID_type and Customer ID_type domain
					$entry .= qq{$end_node->{cust_id}_SAA;$end_node->{cust_id}_SAA_$end_node->{domain};};

					#end node to host node path
					$entry .= qq{$end_node->{cust_name}\\$end_node->{cust_id}\\$end_node->{domain}\\$end_node->{locn_ttname}\\SAA,};

					#host node to end node path
					$entry .= qq{$end_node->{cust_name}\\$end_node->{cust_id}\\$host_node->{domain}\\$host_node->{locn_ttname}\\SAA;};

					#NE id
					$entry .= qq{$end_node->{locn_ttname} $end_node->{equipment_type} $end_node->{equipment_index};};

					#Description
					$entry .= qq{RealTime Report between $end_node->{address} and $host_node->{address};};

					#prob entry 20 - realtime
					$entry .= qq{20;};
			
					#threshold setting - boolean
					$entry .= qq{$end_node->{tail_conformance}\n};
					print SAA $entry;
				}

				if($end_node->{'interactive_report'}){
					#Instance type
					$entry = qq{SA_AGENT;};
					
					#Instance name
					$entry.= qq{Interactive-$end_node->{locn_ttname} $end_node->{equipment_type}$end_node->{equipment_index}-$host_node->{locn_ttname} $host_node->{equipment_type}$host_node->{equipment_index};};
		
					#router name
					$entry.= qq{$end_node->{locn_ttname} $end_node->{equipment_type} $end_node->{equipment_index};};
				
					#customer ID_type and Customer ID_type domain
					$entry .= qq{$end_node->{cust_id}_SAA;$end_node->{cust_id}_SAA_$end_node->{domain};};

					#end node to host node path
					$entry .= qq{$end_node->{cust_name}\\$end_node->{cust_id}\\$end_node->{domain}\\$end_node->{locn_ttname}\\SAA,};

					#host node to end node path
					$entry .= qq{$end_node->{cust_name}\\$end_node->{cust_id}\\$host_node->{domain}\\$host_node->{locn_ttname}\\SAA;};

					#NE id
					$entry .= qq{$end_node->{locn_ttname} $end_node->{equipment_type} $end_node->{equipment_index};};

					#Description
					$entry .= qq{Interactive Report between $end_node->{address} and $host_node->{address};};

					#prob entry 10 - realtime
					$entry .= qq{10;};

					#threshold setting - boolean
					$entry .= qq{$end_node->{tail_conformance}\n};

					print SAA $entry;
				}

				close(SAA);
						
			}
		}
	}
	1;
}	

#============================================================================================
sub _get_snmp_string(){
	my ($self,$equp_id) = @_;

	return undef if !$equp_id;

	my $dbh = $self->{dbh};

	my $sql = qq{select tefi_name,tefi_value from TECHNOLOGY_TEMPLATE_INSTANCE \
			where tefi_tablename=? and tefi_tableid=? \
			and tefi_name in (?,?)};

	my $para;

	eval{
		my $para_sth = $dbh->prepare($sql);
		$para_sth->execute('EQUIPMENT',$equp_id,'SNMP_READ','SNMP_WRITE');
		while(my @rows = $para_sth->fetchrow_array){
               		$para->{$rows[0]} = $rows[1];
        	}
        	$para_sth->finish;
	};

	if($@){
		$self->_error($@);
		return undef;
	}
	$para;
}
#============================================================================================
sub _get_bandwidth(){
	my $self = shift;
	my $dbh = $self->{dbh};

	my $data = $self->{data};

	return undef if !$dbh || !$data;
	my $sql = qq{select port_card_slot,port_cirt_name, cirt_sped_abbreviation,cirt_sere_id, \
			seti_name,seti_value \
		from ports,equipment,circuits,service_template_instance \
		where port_equp_id=equp_id \
		and equp_equt_abbreviation=? \
		and equp_locn_ttname=? \
		and equp_index =? \
		and equp_aapt_status=? \
		and port_cirt_name = cirt_name \
		and cirt_aapt_status = ? \
		and seti_tableid =cirt_name \
		and seti_tablename=? \
		and upper(seti_name) in (?,?,?) \
		and cirt_sert_abbreviation in (?,?)};


	my $fcip_sql = qq{select seoa_name,seoa_defaultvalue \
			from service_order_attributes,service_orders,circuits,locations \
			where seoa_sero_id=sero_id \
			and locn_ttname=?
			and SERO_LOCN_ID_AEND=locn_id \
			and SERO_LOCN_ID_BEND=SERO_LOCN_ID_AEND \
			and SERO_SERT_ABBREVIATION=? \
			and cirt_aapt_status=? \
			and SERO_CIRT_NAME=cirt_name \
			and SEOA_SERO_ID=SERO_ID \
			and seoa_name in (?,?)}; 
			

	foreach my $cirt (sort keys %{$data}){
		foreach my $type (sort keys %{$data->{$cirt}}){
			my $lev2=$data->{$cirt}{$type};	#level 2
			foreach my $node (sort keys %{$lev2}){
				my $lev3=$lev2->{$node};	#level 3
				eval{
					my $sth = $dbh->prepare($sql);

					$sth->execute($lev3->{equipment_type},$lev3->{locn_ttname},
						$lev3->{equipment_index},'INSERVICE','INSERVICE','CIRCUITS',
							$self->{CONSTANT}{Cust_IA_bandwidth_name}->(),
							$self->{CONSTANT}{Cust_RT_bandwidth_name}->(),
							$self->{CONSTANT}{Cust_Tail_Conformance}->(),
							'PVCIP-WAN','VVCIP-MAN');

					my $d;
					while(my @rows = $sth->fetchrow_array){
						$d->{$rows[1]}{card_slot}=$rows[0];
						$d->{$rows[1]}{speed}=$rows[2];
						$d->{$rows[1]}{sero_id}=$rows[3];
						$d->{$rows[1]}{$rows[4]}=$rows[5];
						if(uc($rows[4]) eq $self->{CONSTANT}{Cust_IA_bandwidth_name}->() && $rows[5] > 0){
							$lev3->{interactive_report}=1;
						}elsif(uc($rows[4]) eq $self->{CONSTANT}{Cust_RT_bandwidth_name}->() && $rows[5] >0){
							$lev3->{realtime_report}=1;
						}elsif(uc($rows[4]) eq $self->{CONSTANT}{Cust_Tail_Conformance}->()){
							if(uc($rows[5]) eq 'NON-CONFORMING'){
								$lev3->{tail_conformance}=0;
							}else{
								$lev3->{tail_conformance}=1;
							}
						}else{	#if there is not Tail Conformance attribute default is set threshold
							$lev3->{tail_conformance}=1;
						}	
					}
					$lev3->{tail_conformance}=1 if !defined $lev3->{tail_conformance};

					$lev3->{carry_cirts}=$d if $d;
					$sth->finish;

					##Customer facing ip ommitted from specs##	

					#to find out the Customer facing IP address for this NE
					#next if !$lev3->{interactive_report} && !$lev3->{realtime_report};	#if not report needed
					
					#my $sth2 = $dbh->prepare($fcip_sql);

					#$sth2->execute($lev3->{locn_ttname},'CPE-ROUTER','INSERVICE',$self->{CONSTANT}{Cust_FIP_SOA_Config_name}->(),
					#	$self->{{CONSTANT}{Cust_FIP_SOA_IP_name}->());

					#my $matched;
					#my $ip;
					#while(my @rows = $sth2->fetchrow_array){
					#	if($rows[0] eq $self->{CONSTANT}{Cust_FIP_SOA_Config_name}->() &&
					#		$rows[1] eq qq{$lev3->{equipment_type}$lev3->{locn_ttname}$lev3->{equipment_index}}){
					#		$matched=1;
					#	}

					#	if($rows[0] eq $self->{CONSTANT}{Cust_FIP_SOA_IP_name}->()){
					#		$ip=$rows[1];
					#	}
					#	last if $matched && $ip;
					#}
					#$sth2->finish;
					#if($matched && $ip){
					#	$lev3->{cust_facing_ip}=$ip;
					#}

					
				};
				if($@){
					$self->_error($@);
					next;
				}
			}
		}
	}
	#print Dumper($data);
	$data;
}		

	
#============================================================================================
sub _get_xconnects(){
	my $self = shift;
	my $dbh = $self->{dbh};

	my $data;
	my $rec_count=0;

	return undef if !$dbh;
	my $cusr_list = join (',', map {"?"} @{$self->{customers}});

	my $sql = qq{select SERO_CIRT_NAME,porl_sequence,port_id,equp_locn_ttname,\
		equp_equt_abbreviation,equp_index,equp_ipaddress,sero_cusr_abbreviation,cusr_name,sero_acct_number, \
		LOCN_NUMBER || ',' || LOCN_STREET || ',' || LOCN_SUBURB || ',' || LOCN_CITY || ',' || LOCN_STATE address, \
		locn_state,equp_equm_model, equp_id \
		from ports,port_links,port_link_ports,equipment,service_orders,customer,locations \
		where SERO_SERT_ABBREVIATION=? \
		and SERO_CIRT_NAME like ? \
		and porl_cirt_name = SERO_CIRT_NAME \
		and sero_cusr_abbreviation = cusr_abbreviation \
		and port_id=polp_port_id \
		and polp_porl_id = porl_id \
		and port_equp_id=equp_id \
		and equp_equt_abbreviation=? \
		and equp_locn_ttname = locn_ttname \
		and sero_cusr_abbreviation in ($cusr_list) \
		order by porl_sequence};


	eval{
		my $sth = $dbh->prepare($sql);
		$sth->execute('IP-VPN','%-%IPVPN%','RTRCE',@{$self->{customers}});
		my $host;
		my $cirt_name;
		
		while(my @rows = $sth->fetchrow_array){
			#data contains keys format of SYDN1193 RTRCE 006
			#Logic:
			#For Host node, only pick first one, and regardless
			#if there is any other with different equipment index or not
			#For End nodes, if location name, equipment type and equipment
			#index are same, pick the lowest sequence one
			my $type;
			my $name = qq{$rows[3] $rows[4] $rows[5]};

			$host=undef if $cirt_name && $cirt_name ne $rows[0];	#if this is new ipvpn circuit
	
			if($rows[0] =~ /$rows[3]/){	
				$type='host_nodes';
				next if($data->{$rows[0]}{$type});	#skip next host name for current cirt
			}else{
				$type='end_nodes';
			}

			if($data->{$rows[0]}{$type}{$name} &&
				$data->{$rows[0]}{$type}{$name}{port_sequence}<$rows[1]){
					next;
			}
			
			$data->{$rows[0]}{$type}{$name}{port_sequence}=$rows[1];
			$data->{$rows[0]}{$type}{$name}{port_id}=$rows[2];
			$data->{$rows[0]}{$type}{$name}{locn_ttname}=$rows[3];
			$data->{$rows[0]}{$type}{$name}{equipment_type}=$rows[4];
			$data->{$rows[0]}{$type}{$name}{equipment_index}=$rows[5];
			$data->{$rows[0]}{$type}{$name}{equipment_ip}=$rows[6];
			$data->{$rows[0]}{$type}{$name}{cust_id}=$rows[7];
			$data->{$rows[0]}{$type}{$name}{cust_name}=$rows[8];
			$data->{$rows[0]}{$type}{$name}{cirt_acct_number}=$rows[9];
			$rows[10] =~ s/^\,//g;
			$rows[10] =~ s/\,\,/\,/g;
			$data->{$rows[0]}{$type}{$name}{address}=$rows[10];
			$data->{$rows[0]}{$type}{$name}{domain}=$rows[11];
			$data->{$rows[0]}{$type}{$name}{equipment_model}=$rows[12];
			$data->{$rows[0]}{$type}{$name}{equipment_id}=$rows[13];
			$cirt_name=$rows[0];
		}
		$rec_count=$sth->rows;
		$sth->finish;
	};
	if($@){
		$self->_error($@);
		return undef;
	}
	$self->{data}=$data;
}
#============================================================================================
sub _error(){
	my $self = shift;
	my $msg = shift @_;
	my $datetime = gmtime(time);

	return if !$msg;

	my $fh = $self->{error_fh};
	print $fh "$datetime :$msg\n";
}
#============================================================================================
sub _db_connect(){
	my $self = shift;
        my ($dbuser,$dbpass,$dns) = @_;

        return undef if !$dbuser;
        return undef if !$dbpass;
        return undef if !$dns;

        my $dbh;

        eval{
                $dbh = DBI->connect("dbi:Oracle:$dns","$dbuser","$dbpass",
                        {RaiseError => 1, AutoCommit => 1});
        };

        if($@){
                $self->_error($@);
                return undef;
        }
        $dbh;
}

1;
