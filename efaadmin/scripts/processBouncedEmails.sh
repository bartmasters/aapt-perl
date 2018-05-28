#!/bin/sh
###
# processBouncedEmails.sh
#
# Collate all bounced email details and produce a single report to email to Online Billing support.
#
#	author:		Bart Masters <bart.masters@aapt.com.au>
###

###
# Load config details
###
. $HOME/bin/config

###
# Produce the header lines
###

echo "`date +%Y-%m-%dT%H:%M:%S` $$ *** `basename $0` starting run. ***" >> $LOGFILE
TEMP_REPORT_FILE=$TEMP/temp-bounced-email-report-`date +%Y-%m-%dT%H-%M-%S`
TEMP_DETAIL_FILE=$TEMP/temp-bounced-email-details-`date +%Y-%m-%dT%H-%M-%S`
echo "Customer Number     Email Address                                     Description" >> $TEMP_REPORT_FILE

###
# If there are no bounced emails, say so.
# Else work through the list of bounced email files, copy their
# details into the Report file, back the individual files up,
# and then delete them.
###
if [ `find $TEMP -type f -name bounced-email* | wc -l` = 0 ] ; then
    echo "\nNo bounced emails today" >> $TEMP_REPORT_FILE
    echo "No bounced emails processed" >> $LOGFILE
else
    for FILE in `find $TEMP -type f -name bounced-email*`; do
	cat $FILE >> $TEMP_DETAIL_FILE
	FILE_BACKUP=$FILE-bak
	mv $FILE $FILE_BACKUP
    done
fi

###
# Now sort the details, so it looks pretty
###
sort $TEMP_DETAIL_FILE -o $TEMP_DETAIL_FILE
cat $TEMP_DETAIL_FILE >> $TEMP_REPORT_FILE

###
# Write the footer for the report, and email the report
# to the appropriate folks.
###
echo "\nRegards,\nIS Apps Support" >> $TEMP_REPORT_FILE

$SENDMAIL -t <<-EOF
From: $FROM_EMAIL
To: $ONLINE_BILLING_EMAIL
Subject: [EFA] Bounced Email Notifications

`cat $TEMP_REPORT_FILE`
EOF

###
# Clean up the temporary files - we don't need them any more
###

for FILE in `find $TEMP -type f -name bounced-email*bak`; do
    rm $FILE
done
rm $TEMP_REPORT_FILE
rm $TEMP_DETAIL_FILE

echo "`date +%Y-%m-%dT%H:%M:%S` $$ *** run complete. ***" >> $LOGFILE
