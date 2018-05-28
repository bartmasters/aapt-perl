<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/data">Subject: Online Billing Confirmation - <xsl:value-of select="account_number"/>

Dear <xsl:value-of select="customer_name"/>

Thank you for subscribing to AAPT's Online Billing.

You can access your account at any time by going to
https://www.aapt.com.au/youraccount/ and simply typing in your
Account Number <xsl:value-of select="account_number"/> and password. If you don't remember your password
then you can use your last invoice number to access your account instead.


If you have trouble logging in to your account or if you have any questions regarding
your invoice please call <xsl:value-of select="call_centre_phone_number"/>.


The team at AAPT

**This is an automatically generated email. Please do not respond**
	</xsl:template>
</xsl:stylesheet>
