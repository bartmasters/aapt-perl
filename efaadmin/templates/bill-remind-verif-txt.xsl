<?xml version="1.0" ?>
<!-- $Id: bill-remind-verif-txt.xsl,v 1.1 2005/03/31 01:50:16 bamaster Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/data">
Dear <xsl:value-of select="customer_name"/>,

Thank you for subscribing to AAPT's <xsl:value-of select="subscription_type"/> service.

This is a reminder to let you know that you have not yet verified your email address. You can do this by going to: <xsl:value-of select="action_page"/>?<xsl:value-of select="verify_action"/>&amp;<xsl:value-of select="customer_key"/>

Once we've received your verification, we'll forward you details on how to use your online account.

If you have any difficulties or questions, please email us at mailto:onlinebilling@aapt.com.au


Thanks,
The Team at AAPT



View our Terms and Conditions at http://www.aapt.com.au/youraccount/youraccount_tc.asp
	</xsl:template>
</xsl:stylesheet>
