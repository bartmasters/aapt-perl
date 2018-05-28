<?xml version="1.0" ?>
<!-- $Id: test.invoice-notif-tempinv-html.xsl,v 1.2 2005/01/31 23:57:21 sviles Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html"/>
	<xsl:template match="/data"><xsl:text>

</xsl:text>
<!-- efa.py requires above to contain header field(s) followed by a blank line with no leading whitespace -->
<!-- we use xsl:text to preserve the blank line, otherwise <xsl:output method="html"> will strip it -->
		<html>
			<head>
				<title>AAPT Invoice <xsl:value-of select="invoice_date"/></title>
				<style type="text/css">
				body	{ background: white; color: black; font-family: Arial, sans-serif; }
				p	{ background: white; color: black; font-family: Arial, sans-serif; }
				</style>
			</head>
			<body>
				<p>Dear <xsl:value-of select="customer_name"/></p>

				<p>Your AAPT bill dated <xsl:value-of select="invoice_date"/> 
				is now ready to be viewed online.</p>

				<p>It is simple to access. Just go to 
				<a href="https://www.aapt.com.au/youraccount/">
				https://www.aapt.com.au/youraccount/</a>
				and type in your Account Number 
				<xsl:value-of select="account_number"/>. Instead of a password,
				you can use this temporary invoice number 
				<xsl:value-of select="temp_invoice_number"/> 
				to log in. You will be prompted to enter your new password.</p>

				<p>If you wish to UNSUBSCRIBE your Online Billing function, click here:
				<a href="{action_page}?{optout_action}&amp;{customer_key}">
				<xsl:value-of select="action_page"/>?<xsl:value-of select="optout_action"/>
				&amp;<xsl:value-of select="customer_key"/>
				</a></p>

				<p>If you have trouble logging in or you have any questions 
				regarding your bill please call  
				<xsl:value-of select="call_centre_phone_number"/>.</p>

				<p>Now that you are receiving your invoice online, you'll no longer receive
				a paper invoice. Why not make things even easier and sign up for Direct 
				Debit? Simply log into your account at <a href="https://www.aapt.com.au/youraccount/">
				https://www.aapt.com.au/youraccount/</a></p>
				
				<ul>
					<li>request an info pack under Services or</li>
					<li>print off a PDF form under Payments or</li>
					<li>call us on <xsl:value-of select="call_centre_phone_number"/></li>
				</ul>
				
				<p>It's easy to set up and means you'll have one less thing to worry about 
				every month.</p>

				<p>The team at AAPT</p>

				<p>**This is an automatically generated email. Please do not respond**</p>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
