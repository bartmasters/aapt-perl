<?xml version="1.0" ?>
<!-- $Id: test.bill-email-password-txt.xsl,v 1.7 2005/03/30 07:49:59 bamaster Exp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/data">
Dear <xsl:value-of select="customer_name"/>,

We're pleased to confirm your subscription to AAPT's <xsl:value-of select="subscription_type"/> service.

You can now access 'Your Account' by following the simple steps below:
			
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
