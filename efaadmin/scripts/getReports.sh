#!/bin/sh
###
# getReports.sh
#
# Fetches report files from the EFA in connect.
#
#	author:		Alan Yates <alan.yates@aapt.com.au>
#	version:	$Id: getReports.sh,v 1.6 2005/05/05 05:57:39 bamaster Exp $
###

###
# Load config details
###
. $HOME/bin/config

###
# Process each file in the spool...
###
echo "`date +%Y-%m-%dT%H:%M:%S` $$ *** `basename $0` starting run. ***" >> $LOGFILE
for file in `ssh $USER@$HOST ls $DROP`; do
	case $file in
		###
		# Report files always begin with 'report-'.
		###
		report-*)
			###
			# If we don't already have the file
			###
			if [ ! -f $REPORT_PATH/$file ] ; then
				###
				# Snarf the file.
				###
				echo "`date +%Y-%m-%dT%H:%M:%S` $$ fetching $file from $HOST..." >> $LOGFILE
				scp -q $USER@$HOST:$DROP/$file $TEMP/$file
				echo "`date +%Y-%m-%dT%H:%M:%S` $$ fetch complete." >> $LOGFILE

				###
				# Hack:  Check the file for completeness.
				###
				if [ `grep -c '</emailBatchResponse>' $TEMP/$file` = 1 ] ; then
					###
					# Work around EFA entity escaping bug
					###
					echo "`date +%Y-%m-%dT%H:%M:%S` $$ working around EFA entity escaping bug..." >> $LOGFILE
					$ENTITY_FIX $TEMP/$file
					echo "`date +%Y-%m-%dT%H:%M:%S` $$ work around complete." >> $LOGFILE

					###
					# Find matching sent data file, move to completed directory, process report.
					###
					echo "`date +%Y-%m-%dT%H:%M:%S` $$ file looks OK, processing..." >> $LOGFILE
					mv $TEMP/$file $REPORT_PATH/$file
					SENT_FILE=`echo $file | sed s/report/data/`
					if [ ! -r $SENT_PATH/$SENT_FILE ] ; then
						echo "`date +%Y-%m-%dT%H:%M:%S` $$ request $SENT_FILE not found!" >> $LOGFILE
					else
						echo "`date +%Y-%m-%dT%H:%M:%S` $$ request file found." >> $LOGFILE
						mv $SENT_PATH/$SENT_FILE $COMPLETED_PATH
						$REPORT_PROCESSOR $COMPLETED_PATH/$SENT_FILE $REPORT_PATH/$file
						echo "`date +%Y-%m-%dT%H:%M:%S` $$ process complete." >> $LOGFILE
					fi

					###
					# Clean-up file on EFA spool.
					###
					DATAFILE=`echo $file | sed s/report/_data/`
#					echo "`date +%Y-%m-%dT%H:%M:%S` $$ deleting report and data files from $HOST..." >> $LOGFILE
#					ssh $USER@$HOST rm -f $DROP/$file $DROP/$DATAFILE
#					echo "`date +%Y-%m-%dT%H:%M:%S` $$ delete complete." >> $LOGFILE
				else
					###
					# File is incomplete, delete local copy.
					###
					echo "`date +%Y-%m-%dT%H:%M:%S` $$ incomplete file, ignoring!" >> $LOGFILE
					rm -f $TEMP/$file
				fi
			fi
		;;
	esac
done
echo "`date +%Y-%m-%dT%H:%M:%S` $$ *** run complete. ***" >> $LOGFILE
