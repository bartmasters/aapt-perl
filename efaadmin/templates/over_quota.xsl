<?xml version="1.0" ?> 
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <xsl:output method="text"/>
	<xsl:template match="/data">Subject: AAPT smartchat broadband usage update

This is a courtesy email to inform you that your smartchat broadband 
service has reached 80% of your monthly usage allowance.

What happens when I reach my monthly usage limit? 
When you reach your limit, your speed will be reduced to 64kbps 
for the remainder of the calendar month. On the 1st of the following
month your service will be returned to your normal broadband speed.

Please Note: You will not be charged for excess usage while your service
has been reduced.

How can I monitor my usage? You can check your usage by going to aapt.net.au
and selecting 'Manage Your service'.  When prompted simply enter your 
complete username (<xsl:value-of select="user_id"/>) and your password and click OK.

If you have any further questions please contact AAPT Customer Service on 
13 88 86 or email support@smartchat.net.au. Once again, thank you for 
choosing smartchat broadband and we hope you continue to enjoy the service.

Yours sincerely, 

Broadband Customer Service Team

</xsl:template>
</xsl:stylesheet>
