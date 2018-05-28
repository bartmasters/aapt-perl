<?xml version="1.0" ?>
<!-- $Id: test.bill-remind-verif-html.xsl,v 1.8 2005/03/30 07:50:01 bamaster Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html"/>
	<xsl:template match="/data"><xsl:text>

</xsl:text>
<!-- efa.py requires above to contain header field(s) followed by a blank line with no leading whitespace -->
<!-- we use xsl:text to preserve the blank line, otherwise <xsl:output method="html"> will strip it -->
		<html>
			<head>
				<title>Email Verification</title>
				<style type="text/css">
				body	{ background: white; color: black; font-family: Arial, sans-serif; }
				p	{ background: white; color: black; font-family: Arial, sans-serif; }
				</style>
			</head>
			<body>
			<p>Dear <xsl:value-of select="customer_name"/>,</p>
			
			<p>Thank you for subscribing to AAPT's <xsl:value-of select="subscription_type"/> service.</p>
			
			<p>This is a reminder to let you know that you have not yet verified your email address. You can do this by going to: <a href="{action_page}?{verify_action}&amp;{customer_key}"><xsl:value-of select="action_page"/>?<xsl:value-of select="verify_action"/>&amp;<xsl:value-of select="customer_key"/>
			</a></p>
			
			<p>Once we've received your verification, we'll forward you details on how to use your online account.</p>
			
			<p>If you have any difficulties or questions, please email us at <a href="mailto:onlinebilling@aapt.com.au">onlinebilling@aapt.com.au</a>.</p>

			<br/>				
			<p>Thanks,<br/>
			The Team at AAPT<br/>
			<br/>
			<br/>
			<br/>
			View our Terms and Conditions at <a href="http://www.aapt.com.au/youraccount/youraccount_tc.asp">http://www.aapt.com.au/youraccount/youraccount_tc.asp</a></p>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
