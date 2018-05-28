<?xml version="1.0" ?>
<!-- $Id: test.bill-email-password-html.xsl,v 1.9 2005/03/30 07:49:59 bamaster Exp $ -->
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

				<p>We're pleased to confirm your subscription to AAPT's <xsl:value-of select="subscription_type"/> service.</p>

				<p>You can now access 'Your Account' by following the simple steps below:
				<br/>
				
				<ul>
				<li>Go to <a href="http://www.aapt.com.au/youraccount/">http://www.aapt.com.au/youraccount/</a>.</li>
				<li>Type in your Account Number <xsl:value-of select="account_number"/>.</li>
				<li>Type in your Password <xsl:value-of select="password"/>.</li>
				<li>Press 'Submit'.</li>
				</ul></p>

				<p>If you have difficulties logging in to 'Your Account', or have any questions regarding your invoice, please email us at <a href="mailto:onlinebilling@aapt.com.au">onlinebilling@aapt.com.au</a></p>

				<p><b>AAPT's NEW Direct Debit service makes paying your bills even easier</b>
				<ul>
					<li>It is the simple and hassle free way to pay your bill each month.</li>
					<li>You can now choose when you would like to make your payments and the frequency of those payments - such as weekly or fortnightly</li>
					<li>You never have to worry about missing a payment or paying late payment fees.</li>
				</ul></p>

				<p>With AAPT's Direct Debit service you are always in control of your payments - so why not sign up today. Simply log into your account at <a href="http://www.aapt.com.au/youraccount/">http://aapt.com.au/youraccount/</a> and select Payments > Direct Debit.</p>
				
				<p>If you have already established Direct Debit with us, your payment will automatically be debited each month.</p>

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
