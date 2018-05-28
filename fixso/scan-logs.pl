#!/pkgs/bin/perl -w
######################################################
# scan-logs.pl	Scan through all the jboss logs
#
# Created:      December 21, 2004
# Author:       Bart Masters
# Version:      1.0
#
######################################################

use strict;			# Be good, lil program

my @kernelList = (A..P);	# List of Kernels that need to be checked
my $baseDirectory = "/u01/gtxprod/";

#----------------------
# Main Processing
#----------------------

# Check we've had a pattern to search on passed in.

my $input_search = $ARGV[0];

unless ($input_search)
{
    print "Error - You need to enter a string to search on.\n";
    print "scan-logs.pl is now exiting.\n";
    exit 99;
}

# Now work through all the jboss logs

foreach (@kernelList)
{
    print "Searching Kernal $_\n";

    chdir "$baseDirectory/gtx_1.6.4_$_/bin/" or die "Can't change $!\n";
}
print $ARGV[0] . "\n";

