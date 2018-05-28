#!/bin/sh
###
# processReport.sh
#
# Parse and report upon an emailBatchResponse file.
#
#	author:		Alan Yates <alan.yates@aapt.com.au>
#	version:	$Id: processReport.sh,v 1.10 2005/05/06 01:47:01 bamaster Exp $
###

###
# Load config details
###
. $HOME/bin/config

###
# First we see if we can read the file.
###
if [ -r $1 -a -r $2 ] ; then
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ processing `basename $1` and `basename $2`..." >> $LOGFILE

	###
	# Produce the MegaReport for upload to the mainframe, redirecting both stdout and stderr
	###
	TEMP_TO_MEGA_FILE=$TEMP/to-mega-$$.txt
	$JAVA -jar $HOME/bin/efaReportGenerator.jar au.com.aapt.efa.reports.MegaReport $1 $2 > $TEMP_TO_MEGA_FILE 2>&1
	if [ $? -gt 0 ] ; then
		echo "`date +%Y-%m-%dT%H:%M:%S` $$ trouble generating report, see $TEMP_TO_MEGA_FILE" >> $LOGFILE
		$SENDMAIL -t <<-EOF
			From: $FROM_EMAIL
			To: $ADMIN_EMAIL
			Subject: [EFA] Trouble generating report

			`cat $TEMP_TO_MEGA_FILE`
		EOF
		exit 1
	else
		UPLOAD_FILE=`basename $2 | sed s/report/to-mega/ | sed s/xml$/txt/`
		cp $TEMP_TO_MEGA_FILE $ARCHIVE_PATH/$UPLOAD_FILE
		mv $TEMP_TO_MEGA_FILE $UPLOAD_PATH/$UPLOAD_FILE		# Guaranteed atomic by POSIX specification
	fi

	###
	# If errors, produce the TeamReport and email to the Online Billing Team.
	###
	if [ `grep -c '<error' $2` -gt 0 ] ; then	
		TEMP_TO_TEAM_FILE=$TEMP/to-team-$$.txt
		BOUNCED_EMAIL_FILE=$TEMP/bounced-email-$$.txt
		$JAVA -jar $HOME/bin/efaReportGenerator.jar au.com.aapt.efa.reports.TeamReport $1 $2 > $TEMP_TO_TEAM_FILE 2>&1
		if [ $? -gt 0 ] ; then
			echo "`date +%Y-%m-%dT%H:%M:%S` $$ trouble generating report, see $TEMP_TO_TEAM_FILE" >> $LOGFILE
			$SENDMAIL -t <<-EOF
				From: $FROM_EMAIL
				To: $ADMIN_EMAIL
				Subject: [EFA] Trouble generating report

				`cat $TEMP_TO_TEAM_FILE`
			EOF
			exit 1
		else
			mv $TEMP_TO_TEAM_FILE $BOUNCED_EMAIL_FILE
		fi
	fi

	echo "`date +%Y-%m-%dT%H:%M:%S` $$ complete." >> $LOGFILE
else
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ invalid file $1 and/or $2" >> $LOGFILE
	exit 1
fi
