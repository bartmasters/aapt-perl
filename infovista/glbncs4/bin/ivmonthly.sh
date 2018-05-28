#!/bin/sh
#
# ivmonthly.sh - Monthly backup of Infovista files
#
# Bart Masters - 6 May 2002 - bamaster@aapt.com.au
#
# This script runs once a month to back up the 
# Infovista files.

run_date=`eval date +%m%y`
iv_file_path=/export/home/infovista/files/backup
iv_log_path=/export/home/infovista/log

# Tar up the files - exit out if there is an error

cd $iv_file_path
tar cf backup.$run_date.tar cust.*

if [ $? -ne 0 ]
then
    exit 99
fi

tar rf backup.$run_date.tar glb_topology.*

if [ $? -ne 0 ]
then
    exit 99
fi

tar rf backup.$run_date.tar hay_topology.*

if [ $? -ne 0 ]
then
    exit 99
fi

tar rf backup.$run_date.tar infra.*

if [ $? -ne 0 ]
then
    exit 99
fi

tar rf backup.$run_date.tar password.*

if [ $? -ne 0 ]
then
    exit 99
fi

# Zip up the backup file

/pkgs/bin/gzip backup.$run_date.tar

# And clean up the files that have now been backed up

rm cust.*
rm glb_topology.*
rm hay_topology.*
rm infra.*
rm password.*

# Now backup the log files

cd $iv_log_path
tar cf backup.$run_date.tar *.error.*

if [ $? -ne 0 ]
then
    exit 99
fi

tar rf backup.$run_date.tar *.file.*

if [ $? -ne 0 ]
then
    exit 99
fi

/pkgs/bin/gzip backup.$run_date.tar

if [ $? -ne 0 ]
then
    exit 99
fi

rm -f *.error.*
rm -f *.file.*
