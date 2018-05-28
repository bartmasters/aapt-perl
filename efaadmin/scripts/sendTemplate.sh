#!/bin/sh
###
# sendTemplate.sh
#
#	Sends mail template files from glbncs4 to the EFA server in connect.
#
#	author:		Stephen Viles <stephen.viles@aapt.com.au>
#	version:	$Id: sendTemplate.sh,v 1.5 2005/05/06 01:47:01 bamaster Exp $
###

###
# Load config details
###
. $HOME/bin/config

###
# Paths of the files involved.
###
SOURCE_PATH=$HOME/templates/outgoing
SENT_PATH=$HOME/templates/transferred

###
# Process each waiting file...
###
echo "`date +%Y-%m-%dT%H:%M:%S` $$ *** `basename $0` starting run. ***" >> $LOGFILE
for file in `find $SOURCE_PATH -type f`; do
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ processing `basename $file`..." >> $LOGFILE

	###
	# Send it to the EFA.
	###
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ sending `basename $file` to $HOST..." >> $LOGFILE
	scp -q $file $USER@$HOST:$DROP
	if [ $? -ne 0 ] ; then 
		echo "`date +%Y-%m-%dT%H:%M:%S` $$ send failed miserably." >> $LOGFILE;
		exit 1;
	fi
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ send complete." >> $LOGFILE

	###
	# Then we clean up and remove the file.
	# Note: this isn't really concurrent execution safe!
	###
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ cleaning up..." >> $LOGFILE
	mv $file $SENT_PATH
	rm -f $file
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ clean complete." >> $LOGFILE

	echo "`date +%Y-%m-%dT%H:%M:%S` $$ process complete." >> $LOGFILE
done
echo "`date +%Y-%m-%dT%H:%M:%S` $$ *** run complete. ***" >> $LOGFILE
