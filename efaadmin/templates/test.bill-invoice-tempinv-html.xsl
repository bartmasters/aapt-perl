<?xml version="1.0" ?>
<!-- $Id: test.bill-invoice-tempinv-html.xsl,v 1.13 2005/03/30 07:50:00 bamaster Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html"/>
	<xsl:template match="/data"><xsl:text>

</xsl:text>
<!-- efa.py requires above to contain header field(s) followed by a blank line with no leading whitespace -->
<!-- we use xsl:text to preserve the blank line, otherwise <xsl:output method="html"> will strip it -->
		<html>
			<head>
				<title>Your monthly Invoice is now online</title>
				<style type="text/css">
				body	{ background: white; color: black; font-family: Arial, sans-serif; }
				p	{ background: white; color: black; font-family: Arial, sans-serif; }
				</style>
			</head>
			<body>
				<p>Dear <xsl:value-of select="customer_name"/>,</p>

				<p>Your invoice is now ready to be viewed online.</p>

				<p>Simply follow the steps below to view your invoice:</p>
				<ul>
					<li>Go to <a href="http://www.aapt.com.au/youraccount/">http://www.aapt.com.au/youraccount/</a>.</li>
					<li>Type in your Account Number <xsl:value-of select="account_number"/>.</li>
					<li>Type in your temporary Invoice Number as your Password <xsl:value-of select="temp_invoice_number"/>.</li>
					<li>Press 'Submit'.</li>
				</ul>
				<p>Once logged in, you'll be prompted to enter your own password.</p>

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
