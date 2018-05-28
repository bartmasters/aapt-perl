<?xml version="1.0" ?>
<!-- $Id $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/data">
Dear <xsl:value-of select="customer_name"/>

Your AAPT bill dated <xsl:value-of select="invoice_date"/> is now ready to be viewed online.

It is simple to access. Just go to https://www.aapt.com.au/youraccount/
and type in your Account Number <xsl:value-of select="account_number"/> and password <xsl:value-of select="password"/>. 

If you wish to UNSUBSCRIBE your Online Billing function, click here:
<xsl:value-of select="action_page"/>?<xsl:value-of select="optout_action"/>&amp;<xsl:value-of select="customer_key"/>

If you have trouble logging in or you have any questions regarding your 
bill please call <xsl:value-of select="call_centre_phone_number"/>.

Now that you are receiving your invoice online, you'll no longer receive
a paper invoice. Why not make things even easier and sign up for Direct 
Debit? Simply log into your account at https://www.aapt.com.au/youraccount/

*	request an info pack under Services or
*	print off a PDF form under Payments or
*	call us on <xsl:value-of select="call_centre_phone_number"/>

It's easy to set up and means you'll have one less thing to worry about 
every month.

The team at AAPT

**This is an automatically generated email. Please do not respond**
	</xsl:template>
</xsl:stylesheet>
