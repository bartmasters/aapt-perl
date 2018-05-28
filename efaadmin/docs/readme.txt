Overview
--------

The EFA is a relatively simple XML based email templating and delivery system.

For historic reasons it is composed of two main components distributed across
two separate hosts.  One host (efasrv.connect.com.au) and component (efa.py) is
dedicated to the parsing of batch requests, template expansion, sending of
email, and response creation.  The other (glbncs4.opseng.aapt.com.au) is tasked
with transport management for the requests and responses, alarming and 
reporting.

The efasrv.connect.com.au host is accessible over the network only by
certificated ssh, while Mega is currently incapable of supporting ssh.  The 
environment on efasrv.connect.com.au and its network locality (close to the
High Availability Mail infrastructure) made it the ideal choice for the EFA
core deployment, but unsuitable for easy integration with Mega, hence the
decision to utilise glbncs4.opseng.aapt.com.au as a gateway for EFA request and
response traffic.


The EFA (efasrv.connect.com.au)
-------------------------------

The Agent itself is implemented in Python as the script "efa.py".  It requires
the Pyana library for XSLT support.  It is deployed in /home/efa/bin on
efasrv.connect.com.au.  It is wrapped by a shell script "efa" which is invoked
from cron (currently every 5 minutes).

By default it consumes any waiting request files that might be sitting in
/var/spool/efa, it expects request files to begin with "data".  It will rename
this file to begin with "_data" and write the output response to a file where
the "data" part of the filename has been replaced with "report".

Templates, structures and other runtime loaded components, if specified as
relative URIs, will have the base of file:///var/spool/efa prepended.  Template
and other files can safely sit in /var/spool/efa provided they do not begin
with "report", "data", or "_data", these are the only filenames the EFA and the
transport scripts on glbncs4 will touch.

Documentation:

https://connectstore.connect.com.au/docushare/dsweb/Get/Document-15708/Email+Agent+Design.doc

Files:

/opt/efa/bin/efa.py
/opt/efa/bin/efa
/opt/efa/lib/python2.3/Pyana/_Pyana.so
/opt/efa/lib/python2.3/Pyana/__init__.py
/opt/efa/lib/python2.3/Pyana/__init__.pyc
/opt/efa/lib/libfrtbegin.a
/opt/efa/lib/libg2c.a
/opt/efa/lib/libg2c.la
/opt/efa/lib/libg2c.so.0.0.0
/opt/efa/lib/libgcc_s.so.1
/opt/efa/lib/libgcj.a
/opt/efa/lib/libgcj.la
/opt/efa/lib/libgcj.so.3.0.0
/opt/efa/lib/libgcj.spec
/opt/efa/lib/libiberty.a
/opt/efa/lib/libobjc.a
/opt/efa/lib/libobjc.la
/opt/efa/lib/libstdc++.a
/opt/efa/lib/libstdc++.la
/opt/efa/lib/libsupc++.a
/opt/efa/lib/libstdc++.so.5.0.0
/opt/efa/lib/libsupc++.la
/opt/efa/.forward
/opt/efa/.ssh/identity
/opt/efa/.ssh/identity.pub
/opt/efa/.ssh/authorized_keys

Crontab:

0,5,10,15,20,25,30,35,40,45,50,55 * * * * /opt/efa/bin/efa

Repository:

:ssh:cvstest@devups01.off.connect.com.au:/cvsroot
mail/efa


The Transport and Reporting Scripts (glbncs4.opseng.aapt.com.au)
----------------------------------------------------------------

The "sendData.sh" script is called from cron (currently every 5 minutes) to
poll the "incoming" directory for requests to send to the EFA. After ensuring
that the file is complete (by finding the closing </emailBatchRequest> tag), it
passes the file through the "strip.pl" filter to strip trailing spaces and 
canonicalises the file name to ensure it begins with data (and includes a 
timestamp). The original (unstripped) incoming file is moved to the "received"
directory. The script then uses scp to deliver the stripped-and-canonicalised 
file into the /var/spool/efa directory on efasrv.connect.com.au. Finally
the request file is moved into the "sent" directory. The daily log file
"~/tmp/log-YYYY-MM-DD.txt" is appended during this process.

To re-transfer a file to the EFA, simply move it from "received" to "incoming".
The next execution of the "sendData.sh" script will pick it up automatically.

The "getReports.sh" script is called from cron (currently every 15 minutes) to
poll the EFA spool directory for completed responses.  After ensuring that the 
file is complete (by finding the closing </emailBatchResponse> tag), the 
"fixEFAEntityBug.sh" script is invoked to escape < and > characters. If the 
matching emailBatchRequest file is found in the "sent" directory, it is moved 
to the "completed" directory, and then the "processReport.sh" script is invoked 
against the request and response files. The response is placed in the "reports"
directory where user agents can pick it up and do their own processing. The 
daily log file "~/tmp/log-YYYY-MM-DD.txt" is appended during this process.

To re-process an EFA report file, simply delete it from the "reports" directory.
The next execution of the "getReports.sh" script will re-transfer the file.

The "processReport.sh" script calls the "efaReportGenerator.jar" Java archive 
to generate a fixed-length report for upload to Mega. The report is placed in
both the "upload" directory and the "archive" directory. Mega is expected to 
transfer all files from the "upload" directory, and is expected to delete files
from the "upload" directory after successful transfer. If re-transfer is
required, the file can be copied from the "archive" directiory to "upload". The
"processReport.sh" script also calls the "efaReportGenerator.jar" Java archive 
to generate an email report on errors, which is sent using "sendmail -t". The 
daily log file "~/tmp/log-YYYY-MM-DD.txt" is appended during this process. If
the "efaReportGenerator.jar" Java archive exits with non-zero exit state, the
error output remains in the "~/tmp" directory and Operations is sent an email.

If efaReportGenerator finds any non-fatal errors, these are emails which are
bounced by our servers due to being non-existant addresses and the like (note
- we can only tell this for email addresses owned by aapt - ie aapt.com.au,
aapt.net.au, smartchat.net.au, stuff like that.  Other domains - eg
hotmail.com, we don't have any knowledge if the address is a real one or not).
These reports are put into a temporary file "~/tmp/bounced-email-$$" to be
processed by end-of-day processing.

To re-transfer a file to Mega, simply copy it from "archive" to "upload". Mega
is expected to poll the "upload" directory and to remove files after transfer.

The "processBouncedEmails.sh" script runs business days at just before
midnight - it collects all the bounced-email files, sorts them into account
number order, and sends them in one report to the support team.  Then it
deletes the temporary files.

The "findDelays.sh" script finds files in the temporary locations "incoming",
"sent" and "upload" that are more than 1 day old, and emails the operations
team with the list of old files and investigation instructions. The script
calls "lineCountAsExitState.pl" to detect the number of old files found.

The transport and reporting scripts rely on "mv" being atomic ie. another 
process will never read a partly moved file.  This is only guaranteed (by the 
POSIX specification) when the src and dest files are on the same file system.
This is why the ~/tmp directory is used, rather than /tmp, as /tmp is often a
memory file system on Solaris boxes.

Use the following procedure to deploy updated templates to the efasrv server:
1. Place the updated templates in the "templates/outgoing" directory.
2. Run the "sendTemplate.sh" script, which uses scp to deliver the templates
   to the /var/spool/efa directory on efasrv.connect.com.au. The templates are 
   then moved to the "templates/transferred" directory.
The daily log file "~/tmp/log-YYYY-MM-DD.txt" is appended during this process.

Files:

/export/home/efaadmin/incoming/
/export/home/efaadmin/received/
/export/home/efaadmin/sent/
/export/home/efaadmin/reports/
/export/home/efaadmin/completed/
/export/home/efaadmin/upload/
/export/home/efaadmin/archive/
/export/home/efaadmin/tmp/log-YYYY-MM-DD.txt
/export/home/efaadmin/templates/outgoing/
/export/home/efaadmin/templates/transferred/
/export/home/efaadmin/bin/sendData.sh
/export/home/efaadmin/bin/strip.pl
/export/home/efaadmin/bin/getReports.sh
/export/home/efaadmin/bin/fixEFAEntityBug.sh
/export/home/efaadmin/bin/processReport.sh
/export/home/efaadmin/bin/efaReportGenerator.jar
/export/home/efaadmin/bin/sendTemplate.sh
/export/home/efaadmin/bin/findDelays.sh
/export/home/efaadmin/bin/lineCountAsExitState.pl
/export/home/efaadmin/bin/hdump [executable - hex dump]
/export/home/efaadmin/.forward
/export/home/efaadmin/.ssh/known_hosts
/export/home/efaadmin/.ssh/identity
/export/home/efaadmin/.ssh/identity.pub

Crontab:

0,5,10,15,20,25,30,35,40,45,50,55 * * * *       /export/home/efaadmin/bin/sendData.sh
0,15,30,45 * * * *      /export/home/efaadmin/bin/getReports.sh
* 21 * * * /export/home/efaadmin/bin/findDelays.sh


Repository:

:pserver:anonymous@redfish.opseng.aapt.com.au:/home/cvs/src
efa
