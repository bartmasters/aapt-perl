<?xml version="1.0" ?>
<!-- $Id: test.confirmation-password-txt.xsl,v 1.1 2005/01/21 00:25:27 sviles Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/data">
Dear <xsl:value-of select="customer_name"/>

Thank you for subscribing to AAPT's <xsl:value-of select="subscription_type"/>.

You can access your account. Just go to https://www.aapt.com.au/youraccount/
and type in your Account Number <xsl:value-of select="account_number"/> and password <xsl:value-of select="password"/>. 

If you have trouble logging in or if you have any questions regarding your 
bill, please call <xsl:value-of select="call_centre_phone_number"/>.

Please click here to view the Terms &amp; Conditions:
https://www.aapt.com.au/youraccount/youraccount_tc.asp

The team at AAPT

**This is an automatically generated email. Please do not respond**
	</xsl:template>
</xsl:stylesheet>
