<?xml version="1.0" ?>
<!-- $Id: test.billing-confirmation-password-html.xsl,v 1.1 2004/12/16 05:50:47 sviles Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html"/>
	<xsl:template match="/data"><xsl:text>

</xsl:text>
<!-- efa.py requires above to contain header field(s) followed by a blank line with no leading whitespace -->
<!-- we use xsl:text to preserve the blank line, otherwise <xsl:output method="html"> will strip it -->
		<html>
			<head>
				<title>Online Billing Confirmation - <xsl:value-of select="account_number"/></title>
				<style type="text/css">
				body	{ background: white; color: black; font-family: Arial, sans-serif; }
				p	{ background: white; color: black; font-family: Arial, sans-serif; }
				</style>
			</head>
			<body>
				<p>Dear <xsl:value-of select="customer_name"/></p>

				<p>Thank you for subscribing to AAPT's Online Billing.</p>

				<p>You can access your account. Just go to 
				<a href="https://www.aapt.com.au/youraccount/">
				https://www.aapt.com.au/youraccount/</a>
				and type in your Account Number 
				<xsl:value-of select="account_number"/> 
				and password <xsl:value-of select="password"/>.</p>

				<p>Please click here to view the Terms &amp; Conditions:
				<a href="https://www.aapt.com.au/youraccount/youraccount_tc.asp">
				https://www.aapt.com.au/youraccount/youraccount_tc.asp</a></p>

				<p>If you have troubles or if you have any questions please call 
				<xsl:value-of select="call_centre_phone_number"/>.</p>

				<p>The team at AAPT</p>

				<p>**This is an automatically generated email. Please do not respond**</p>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
