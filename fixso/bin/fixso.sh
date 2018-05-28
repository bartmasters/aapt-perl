#!/bin/sh
#
# Script to run fixso.pl multiple times,
# each time feeding it a new type of Speednet
#
# Usage of this script is 
# fixso.sh userid password
#
# where userid is the userid to connect to prod 
# BIOSS, and password is its password

usage="Usage is $0 userid password"

if test -z "$2"
then echo $usage;
	 exit 1;
fi

echo "Starting run of fixso.sh"

fixso.pl -s speednet1 -u $1 -p $2
fixso.pl -s speednet2 -u $1 -p $2
fixso.pl -s speednet2x -u $1 -p $2
fixso.pl -s speednet3 -u $1 -p $2
fixso.pl -s speednet3x -u $1 -p $2
fixso.pl -s speednet4 -u $1 -p $2
fixso.pl -s speednet4x -u $1 -p $2

echo "Run completed successfully"
