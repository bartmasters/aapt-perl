<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text"/>
	<xsl:template match="/data">Subject: AAPT Invoice <xsl:value-of select="invoice_date"/> - <xsl:value-of select="account_number"/>

Dear <xsl:value-of select="customer_name"/>

Your invoice is now ready to view online.

It's easy:
1.	Go to https://www.aapt.com.au/youraccount/
2.	Type in your Account Number: <xsl:value-of select="account_number"/>
3.	Type in your Password.

Forgotten your password? Simply use your previous invoice number instead.
If you have trouble logging in or you have any questions, please call us
on <xsl:value-of select="call_centre_phone_number"/>.

Now that you are receiving your invoice online, you'll no longer receive
a paper invoice. Why not make things even easier and sign up for Direct 
Debit? Simply log into your account at https://www.aapt.com.au/youraccount/

*	request an info pack under Services or
*	print off a PDF form under Payments or
*	call us on <xsl:value-of select="call_centre_phone_number"/>

It's easy to set up and means you'll have one less thing to worry about 
every month.

The team at AAPT


**This is an automatically generated email.  Please do not respond**
	</xsl:template>
</xsl:stylesheet>
