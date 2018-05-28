#!/bin/sh
#
# Script to run fixso.pl multiple times,
# each time feeding it a new type of Speednet
#
# Running it with the -U switch will cause it
# to run against BUAT environment
#
# Usage of this script is 
# fixsouat.sh userid password
#
# where userid is the userid to connect to BUAT
# BIOSS, and password is its password

usage="Usage is $0 userid password"

if test -z "$2"
then echo $usage;
	 exit 1;
fi

echo "Starting run of fixsouat.sh"

fixso.pl -U -s speednet1 -u $1 -p $2
fixso.pl -U -s speednet2 -u $1 -p $2
fixso.pl -U -s speednet2x -u $1 -p $2
fixso.pl -U -s speednet3 -u $1 -p $2
fixso.pl -U -s speednet3x -u $1 -p $2
fixso.pl -U -s speednet4 -u $1 -p $2
fixso.pl -U -s speednet4x -u $1 -p $2

echo "Run completed successfully"
