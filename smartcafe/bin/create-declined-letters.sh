#!/usr/bin/bash
#
# create-declined-letters.sh - Create declined letters
#
# This script runs once a day to create letters for
# customers that have been declined for credit in 
# the Smartcafe system.
# It will 
#	* Backup the current letter files
#	* Run the perl script to create the files
#         and FTP them to the LAN

run_date=`eval date +%d%m%y-%T`
file_path=/export/home/gtxtest/create-declined-letters/
export ORACLE_HOME=/export/oracle/product/9.0.1

# Backup the current file

cd $file_path
mv files/CRCHK* backup/

# Run the creation script

/pkgs/bin/perl58 $file_path/bin/create-declined-letters.pl -f $file_path > $file_path/log/log.$run_date 2>> $file_path/log/log.$run_date
