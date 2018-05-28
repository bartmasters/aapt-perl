<?xml version="1.0" ?>
<!-- $Id: market-initial-verif-txt.xsl,v 1.1 2005/03/31 01:50:16 bamaster Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/data">
Dear <xsl:value-of select="customer_name"/>,

Thank you for subscribing to receive the latest news, promotions and offers from AAPT via email.

All you need to do now is verify that we have your correct email address. To do this, go to: <xsl:value-of select="action_page"/>?<xsl:value-of select="verify_action"/>&amp;<xsl:value-of select="customer_key"/>

Once we've received your verification, you will begin receiving the latest updates from AAPT via email.

If you have difficulties or questions please email us at mailto:onlinebilling@aapt.com.au

	
Thanks,
The Team at AAPT



View our Terms and Conditions at http://www.aapt.com.au/youraccount/youraccount_tc.asp
To unsubscribe, please go to <xsl:value-of select="action_page"/>?<xsl:value-of select="cancel_action"/>&amp;<xsl:value-of select="customer_key"/>
	</xsl:template>
</xsl:stylesheet>
