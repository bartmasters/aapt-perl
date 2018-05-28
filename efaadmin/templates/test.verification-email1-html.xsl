<?xml version="1.0" ?>
<!-- $Id: test.verification-email1-html.xsl,v 1.3 2005/01/21 00:25:27 sviles Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html"/>
	<xsl:template match="/data"><xsl:text>

</xsl:text>
<!-- efa.py requires above to contain header field(s) followed by a blank line with no leading whitespace -->
<!-- we use xsl:text to preserve the blank line, otherwise <xsl:output method="html"> will strip it -->
		<html>
			<head>
				<title><xsl:value-of select="subscription_type"/> Verification</title>
				<style type="text/css">
				body	{ background: white; color: black; font-family: Arial, sans-serif; }
				p	{ background: white; color: black; font-family: Arial, sans-serif; }
				</style>
			</head>
			<body>
			<p>Dear <xsl:value-of select="customer_name"/></p>
			
			<p>Thank you for subscribing to AAPT's <xsl:value-of select="subscription_type"/>.</p>
			
			<p>Please click on the following link to verify your email address. Once we receive your verification response, we will forward you the details on how to use the website.</p>
			
			<p>VERIFY click here 
			<a href="{action_page}?{verify_action}&amp;{customer_key}">
			<xsl:value-of select="action_page"/>?<xsl:value-of select="verify_action"/>&amp;<xsl:value-of select="customer_key"/>
			</a></p>
			
			<p>CANCEL your subscription click here 
			<a href="{action_page}?{cancel_action}&amp;{customer_key}">
			<xsl:value-of select="action_page"/>?<xsl:value-of select="cancel_action"/>&amp;<xsl:value-of select="customer_key"/>
			</a></p>
			
			<p>If you have troubles or if you have any questions please call <xsl:value-of select="call_centre_phone_number"/>.</p>
			
			<p>The team at AAPT</p>
			
			<p>**This is an automatically generated email. Please do not respond**</p>

			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
