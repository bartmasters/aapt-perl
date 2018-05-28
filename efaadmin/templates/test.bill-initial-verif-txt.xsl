<?xml version="1.0" ?>
<!-- $Id: test.bill-initial-verif-txt.xsl,v 1.6 2005/03/30 07:50:00 bamaster Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/data">
Dear <xsl:value-of select="customer_name"/>,

Thank you for subscribing to AAPT's <xsl:value-of select="subscription_type"/> service.

All you need to do now is verify that we have your correct email address. You can do this simply by going to: <xsl:value-of select="action_page"/>?<xsl:value-of select="verify_action"/>&amp;<xsl:value-of select="customer_key"/>

Once we've received your verification, we'll forward you details on how to use your online account.

If you have any difficulties or questions, please email us at mailto:onlinebilling@aapt.com.au


Thanks,
The Team at AAPT



View our Terms and Conditions at http://www.aapt.com.au/youraccount/youraccount_tc.asp
	</xsl:template>
</xsl:stylesheet>
