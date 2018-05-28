<?xml version="1.0" ?>
<!-- $Id $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/data">
Dear <xsl:value-of select="customer_name"/>,

Your invoice is now ready to be viewed online.

Simply follow the steps below to view your invoice:
			
* Go to http://www.aapt.com.au/youraccount/.
* Type in your Account Number <xsl:value-of select="account_number"/>.
* Type in your Password <xsl:value-of select="password"/>.
* Press 'Submit'.

If you have difficulties logging in to 'Your Account', or have any questions regarding your invoice, please email us at mailto:onlinebilling@aapt.com.au

AAPT's NEW Direct Debit service makes paying your bills even easier
*	It is the simple and hassle free way to pay your bill each month.
*	You can now choose when you would like to make your payments and the frequency of those payments - such as weekly or fortnightly
*	You never have to worry about missing a payment or paying late payment fees

With AAPT's Direct Debit service you are always in control of your payments - so why not sign up today. Simply log into your account at http://aapt.com.au/youraccount and select Payments > Direct Debit.

If you have already established Direct Debit with us, your payment will automatically be debited each month.

			
Thanks,
The Team at AAPT



View our Terms and Conditions at http://www.aapt.com.au/youraccount/youraccount_tc.asp
	</xsl:template>
</xsl:stylesheet>
