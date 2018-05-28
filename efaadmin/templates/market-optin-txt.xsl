<?xml version="1.0" ?>
<!-- $Id: market-optin-txt.xsl,v 1.1 2005/03/31 01:50:17 bamaster Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/data">
Dear <xsl:value-of select="customer_name"/>,

We're pleased to confirm your subscription to receive the latest news, promotions and offers from AAPT via email. 

If you have difficulties or questions please email us at mailto:onlinebilling@aapt.com.au

	
Thanks,
The Team at AAPT



View our Terms and Conditions at http://www.aapt.com.au/youraccount/youraccount_tc.asp
To unsubscribe, please go to <xsl:value-of select="action_page"/>?<xsl:value-of select="cancel_action"/>&amp;<xsl:value-of select="customer_key"/>
	</xsl:template>
</xsl:stylesheet>
