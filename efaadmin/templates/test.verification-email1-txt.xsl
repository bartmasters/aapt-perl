<?xml version="1.0" ?>
<!-- $Id: test.verification-email1-txt.xsl,v 1.4 2005/01/21 00:25:27 sviles Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/data">
Dear <xsl:value-of select="customer_name"/>

Thank you for subscribing to AAPT's <xsl:value-of select="subscription_type"/>.

Please click on the following link to verify your email address. Once we 
receive your verification response, we will forward you the details on how 
to use the website.

VERIFY click here 
<xsl:value-of select="action_page"/>?<xsl:value-of select="verify_action"/>&amp;<xsl:value-of select="customer_key"/>

CANCEL your subscription click here 
<xsl:value-of select="action_page"/>?<xsl:value-of select="cancel_action"/>&amp;<xsl:value-of select="customer_key"/>

If you have troubles or if you have any questions please call <xsl:value-of select="call_centre_phone_number"/>.

The team at AAPT

**This is an automatically generated email. Please do not respond**
	</xsl:template>
</xsl:stylesheet>
