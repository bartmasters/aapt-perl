<?xml version="1.0" ?>
<!-- $Id: test.confirmation-password-html.xsl,v 1.1 2005/01/21 00:25:27 sviles Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html"/>
	<xsl:template match="/data"><xsl:text>

</xsl:text>
<!-- efa.py requires above to contain header field(s) followed by a blank line with no leading whitespace -->
<!-- we use xsl:text to preserve the blank line, otherwise <xsl:output method="html"> will strip it -->
		<html>
			<head>
				<title><xsl:value-of select="subscription_type"/> Confirmation</title>
				<style type="text/css">
				body	{ background: white; color: black; font-family: Arial, sans-serif; }
				p	{ background: white; color: black; font-family: Arial, sans-serif; }
				</style>
			</head>
			<body>
				<p>Dear <xsl:value-of select="customer_name"/></p>

				<p>Thank you for subscribing to AAPT's <xsl:value-of select="subscription_type"/>.</p>

				<p>You can access your account. Just go to 
				<a href="https://www.aapt.com.au/youraccount/">
				https://www.aapt.com.au/youraccount/</a>
				and type in your Account Number 
				<xsl:value-of select="account_number"/> 
				and password <xsl:value-of select="password"/>.</p>

				<p>If you have trouble logging in or if you have any questions regarding 
				your bill, please call <xsl:value-of select="call_centre_phone_number"/>.</p>

				<p>Please click here to view the Terms &amp; Conditions:
				<a href="https://www.aapt.com.au/youraccount/youraccount_tc.asp">
				https://www.aapt.com.au/youraccount/youraccount_tc.asp</a></p>

				<p>The team at AAPT</p>

				<p>**This is an automatically generated email. Please do not respond**</p>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
