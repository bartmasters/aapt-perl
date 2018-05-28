#!/bin/sh
###
# $Id: findDelays.sh,v 1.3 2005/01/28 04:11:51 sviles Exp $
# Find delays in transferring files between source systems and the EFA server.
###

###
# Load config details, log start of run
###
source $HOME/bin/config
echo "`date +%Y-%m-%dT%H:%M:%S` $$ *** `basename $0` starting run. ***" >> $LOGFILE

###
# Look for files still in $SOURCE_PATH after 1 day
###
echo "`date +%Y-%m-%dT%H:%M:%S` $$ Finding old files still in $SOURCE_PATH" >> $LOGFILE
find $SOURCE_PATH/* -mtime +1 -type f -prune -exec basename {} \; > $TEMP/$$
$LINE_COUNT < $TEMP/$$
if [ $? -eq 0 ] ; then 
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ No old files found" >> $LOGFILE
else
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ Found old file(s), sending email" >> $LOGFILE
	$SENDMAIL -t <<-EOF
		From: $FROM_EMAIL
		To: $ADMIN_EMAIL
		Subject: [EFA] Old incoming files found

		Hi,
		
		This is the `basename $0` script on `hostname`.  I've found the following old 
		file(s) in the $SOURCE_PATH directory:

		`cat $TEMP/$$`
		
		There are at least two possible reasons for this:

		1. The file(s) don't contain the required closing </emailBatchRequest> tag.
		2. The "sendData.sh" script is not being executed from the crontab.
		
		Can you please log onto `hostname` as user `whoami` and investigate.  Thanks.
	EOF
fi

###
# Look for files still in $SENT_PATH after 1 day
###
echo "`date +%Y-%m-%dT%H:%M:%S` $$ Finding old files still in $SENT_PATH" >> $LOGFILE
find $SENT_PATH/* -mtime +1 -type f -prune -exec basename {} \; > $TEMP/$$
$LINE_COUNT < $TEMP/$$
if [ $? -eq 0 ] ; then 
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ No old files found" >> $LOGFILE
else
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ Found old file(s), sending email" >> $LOGFILE
	$SENDMAIL -t <<-EOF
		From: $FROM_EMAIL
		To: $ADMIN_EMAIL
		Subject: [EFA] Old sent files found

		Hi,
		
		This is the `basename $0` script on `hostname`.  I've found the following old 
		file(s) in the $SENT_PATH directory that don't have a matching 
		report file in the $REPORT_PATH directory:

		`cat $TEMP/$$`
		
		There are at least three possible reasons for this:

		1. SSH connectivity between `hostname` and $HOST is broken.
		2. The Email Fulfilment Agent (EFA) on $HOST is not running.
		3. The EFA on $HOST is not producing a report file 
		with a matching filename.
		
		Can you please log onto `hostname` as user `whoami`, then 
		"ssh -v $USER@$HOST". This will show whether SSH connectivity 
		between `hostname` and $HOST is broken.
		
		If SSH to $HOST is successful, please "ls $DROP" 
		and look for files as follows:
		
		a. Not processed by EFA -- EFA may not be running on $HOST:

		`cat $TEMP/$$`
		
		b. Processed by EFA -- emails should have been sent to recipients:

		`cat $TEMP/$$ | sed s/^data/_data/g`
		
		c. Report produced by EFA, should be transferred to `hostname` by getReports.sh:

		`cat $TEMP/$$ | sed s/^data/report/g`
		
		I hope this helps sort out the problem.  Thanks.
	EOF
fi

###
# Look for files still in $UPLOAD_PATH after 1 day
###
echo "`date +%Y-%m-%dT%H:%M:%S` $$ Finding old files still in $UPLOAD_PATH" >> $LOGFILE
find $UPLOAD_PATH/* -mtime +1 -type f -prune -exec basename {} \; > $TEMP/$$
$LINE_COUNT < $TEMP/$$
if [ $? -eq 0 ] ; then 
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ No old files found" >> $LOGFILE
else
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ Found old file(s), sending email" >> $LOGFILE
	$SENDMAIL -t <<-EOF
		From: $FROM_EMAIL
		To: $ADMIN_EMAIL
		Subject: [EFA] Old upload files found

		Hi,
		
		This is the `basename $0` script on `hostname`.  I've found the following old 
		file(s) in the $UPLOAD_PATH directory:

		`cat $TEMP/$$`
		
		The most likely reason is that the Mega job is not transferring the files to
		Mega, or the Mega job is not deleting the files after the transfer.

		Can you please follow this up with Mega Applications Support. Thanks.
	EOF
fi

###
# Delete temporary file and log end of run
###
rm $TEMP/$$
echo "`date +%Y-%m-%dT%H:%M:%S` $$ *** `basename $0` run complete. ***" >> $LOGFILE
