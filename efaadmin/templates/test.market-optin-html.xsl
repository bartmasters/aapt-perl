<?xml version="1.0" ?>
<!-- $Id: test.market-optin-html.xsl,v 1.11 2005/03/30 07:50:01 bamaster Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html"/>
	<xsl:template match="/data"><xsl:text>

</xsl:text>
<!-- efa.py requires above to contain header field(s) followed by a blank line with no leading whitespace -->
<!-- we use xsl:text to preserve the blank line, otherwise <xsl:output method="html"> will strip it -->
		<html>
			<head>
				<title>Subscription Success</title>
				<style type="text/css">
				body	{ background: white; color: black; font-family: Arial, sans-serif; }
				p	{ background: white; color: black; font-family: Arial, sans-serif; }
				</style>
			</head>
			<body>
			<p>Dear <xsl:value-of select="customer_name"/>,</p>
			
			<p>We're pleased to confirm your subscription to receive the latest news, promotions and offers from AAPT via email.</p>
			
			<p>If you have any difficulties or questions please email us at <a href="mailto:onlinebilling@aapt.com.au">onlinebilling@aapt.com.au</a></p>
			
			<p>Visit <a href="http://www.aapt.com.au">http://www.aapt.com.au</a> to see what's new.</p>
			<br/>
			<p>Thanks,<br/>
			The Team at AAPT<br/>
			<br/>
			<br/>
			<br/>
			View our Terms and Conditions at <a href="http://www.aapt.com.au/youraccount/youraccount_tc.asp">http://www.aapt.com.au/youraccount/youraccount_tc.asp</a>
			<br/>
			To unsubscribe, please go to <a href="{action_page}?{cancel_action}&amp;{customer_key}"><xsl:value-of select="action_page"/>?<xsl:value-of select="cancel_action"/>&amp;<xsl:value-of select="customer_key"/></a></p>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
