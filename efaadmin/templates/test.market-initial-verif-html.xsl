<?xml version="1.0" ?>
<!-- $Id: test.market-initial-verif-html.xsl,v 1.9 2005/03/30 07:50:01 bamaster Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html"/>
	<xsl:template match="/data"><xsl:text>

</xsl:text>
<!-- efa.py requires above to contain header field(s) followed by a blank line with no leading whitespace -->
<!-- we use xsl:text to preserve the blank line, otherwise <xsl:output method="html"> will strip it -->
		<html>
			<head>
				<title>Email Verification Reminder</title>
				<style type="text/css">
				body	{ background: white; color: black; font-family: Arial, sans-serif; }
				p	{ background: white; color: black; font-family: Arial, sans-serif; }
				</style>
			</head>
			<body>
			<p>Dear <xsl:value-of select="customer_name"/>,</p>
			
			<p>Thank you for subscribing to receive the latest news, promotions and offers from AAPT via email.</p>
			
			<p>All you need to do now is verify that we have your correct email address. To do this, go to: <a href="{action_page}?{verify_action}&amp;{customer_key}"><xsl:value-of select="action_page"/>?<xsl:value-of select="verify_action"/>&amp;<xsl:value-of select="customer_key"/>
			</a></p>
			
			<p>Once we've received your verification, you will begin receiving the latest updates from AAPT via email.</p>
			
			<p>If you have any difficulties or questions please email us at <a href="mailto:onlinebilling@aapt.com.au">onlinebilling@aapt.com.au</a></p>

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
