#!/pkgs/bin/perl
######################################################
# ams-trap.pl - Accept traps from InfoVista and 
# forward them onto AMS.
#
# Created:      February 6, 2003
# Author:       Bart Masters
# Version:      0.1
#
# InfoVista can raise snmp traps if various criteria
# is met in reports that are being monitored.  However
# the standard IV trap MIB doesn't contain all the info
# AMS requries to log a trap.  This program will read
# in the IV trap, work out what extra info is needed,
# and then create a new trap in the format AMS 
# requires.
#
######################################################

use strict;			# Be good, lil program
use Mon::SNMP;			# SNMP Monitorer
use IO::Socket;
use aapt::Snmp;
use Data::Dumper;

# Global Variables

#----------------------
# Main Processing
#----------------------

# First, listen to Trap port (162)

my $port = 162;
my $server = IO::Socket::INET->new(LocalPort=> $port, Proto=>"udp");
unless ($server)
{
    print "Error finding port: $@\n";
    exit;
}

my $trap = new Mon::SNMP; 

while()
{
    print "---\n";
    $trap->{"BER"}->recv($server);
    my $hash = decode($trap);
    print Dumper($hash);

}

sub decode {
    my $trap = shift;
    my ($oid, $val);
	
    my $output=undef;
    $trap->{"ERROR"} = undef;

    if (! $trap->{"BER"}->decode (
                SEQUENCE => [
                    INTEGER => \$output->{"version"},
                    STRING => \$output->{"community"},
                    Trap_PDU => [
                        OBJECT_ID => \$output->{"ent_OID"},
                        IpAddress => \$output->{"agentaddr"},
                        INTEGER => \$output->{"generic_trap"},
                        INTEGER => \$output->{"specific_trap"},
                        TimeTicks => \$output->{"timeticks"},
	              	SEQUENCE => \$output->{"ber_varbindlist"},
                    ],
                ],
            )) {

        print("problem decoding BER\n");
        return ();
    }

   while ($output->{"ber_varbindlist"}->decode (
                SEQUENCE => [
                        OBJECT_ID => \$oid,
                        ANY => \$val,
                ]
                                )) {
	my $rv;

	#decode the value according to it's own type

	#$val=$rv if $val->decode(STRING => \$rv) ||
	#	 $val->decode(INTEGER => \$rv) ||
	#	 $val->decode(BOOLEAN => \$rv);
	$val=$rv if $val->decode(STRING => \$rv) ||
		 $val->decode(INTEGER => \$rv) ||
		 $val->decode(APPLICATION => \$rv);

	$val=$rv if $rv;
			
        $output->{"varbindlist"}->{$oid} = $val;
   }
	#pass out the hash structure instead of %
   return (
	{
        version         =>      $output->{"version"},
        community       =>      $output->{"community"},
        ent_OID         =>      $output->{"ent_OID"},
        agentaddr       =>      inet_ntoa ($output->{"agentaddr"}),	#should use inet_ntoa not the inet_aton as in the module
        generic_trap    =>      $output->{"generic_trap"},	#just a digit, don't muck around with it 
        specific_trap   =>      $output->{"specific_trap"},
        timeticks       =>      $output->{"timeticks"},
        varbindlist     =>      $output->{"varbindlist"},
	}
   );
}
