#!/bin/sh
###
# sendData.sh
#
#	Sends emailBatchRequest files to the EFA server in connect.
#
#	author:		Alan Yates <alan.yates@aapt.com.au>
#	version:	$Id: sendData.sh,v 1.7 2005/05/05 05:57:40 bamaster Exp $
###

###
# Load config details
###
. $HOME/bin/config

###
# Process each waiting file...
###
# echo "`date +%Y-%m-%dT%H:%M:%S` $$ *** `basename $0` starting run. ***" >> $LOGFILE
for file in `find $SOURCE_PATH -type f`; do
	###
	# Hack:  Make sure the entire file is there.
	# Works around clients that don't drop the file atomically.
	###
	if [ `grep -c '</emailBatchRequest>' $file` = 1 ] ; then
		TMPFILE=$TEMP/data-`date +%Y-%m-%dT%H-%M-%S`-`basename $file`
		echo "`date +%Y-%m-%dT%H:%M:%S` $$ processing `basename $file`..." >> $LOGFILE
		###
		# First we run the cleanup process across the source file.
		###
		echo "`date +%Y-%m-%dT%H:%M:%S` $$ converting to `basename $TMPFILE`..." >> $LOGFILE
		$BATCH_CLEANUP < $file > $TMPFILE
		echo "`date +%Y-%m-%dT%H:%M:%S` $$ convert complete." >> $LOGFILE
		
		###
		# Then we move the source file out of the source directory,
		# so that the next execution of this script does not find it there.
		###
		mv $file $RECEIVED_PATH

		###
		# Then we send the cleaned-up source file to the EFA.
		###
		echo "`date +%Y-%m-%dT%H:%M:%S` $$ sending `basename $TMPFILE` to $HOST..." >> $LOGFILE
		scp -q $TMPFILE $USER@$HOST:$DROP
		if [ $? -ne 0 ] ; then 
			echo "`date +%Y-%m-%dT%H:%M:%S` $$ send failed, aborting." >> $LOGFILE;
			exit 1;
		fi
		echo "`date +%Y-%m-%dT%H:%M:%S` $$ send complete." >> $LOGFILE

		###
		# Then we move the sent file to the dump location.
		###
		echo "`date +%Y-%m-%dT%H:%M:%S` $$ moving to dump location..." >> $LOGFILE
		mv $TMPFILE $SENT_PATH
		echo "`date +%Y-%m-%dT%H:%M:%S` $$ move complete." >> $LOGFILE

		echo "`date +%Y-%m-%dT%H:%M:%S` $$ process complete." >> $LOGFILE
		sleep 1
	fi
done
# echo "`date +%Y-%m-%dT%H:%M:%S` $$ *** run complete. ***" >> $LOGFILE
