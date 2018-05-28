package au.com.aapt.efa.reports;

import au.com.aapt.efa.*;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Iterator;
import java.util.TimeZone;
import java.util.regex.*;

import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

public class MegaReport implements ReportCollator {
	public void exception(Fault exception) {
		System.err.print("exception!! ");
		System.out.println(exception);
		System.exit(1);
	}
	
	public void unmatchedResult(Result result) {
		System.err.print("unmatched result!! ");
		System.err.println(result);
		System.exit(2);
	}
	
	public void unmatchedMessage(Message message) {
		System.err.print("unmatched message!! ");
		System.err.println(message);
		System.exit(3);
	}
	
	public void sent(Message message, SentResult result) {
		report(message, "sent", "ok");
	}
	
	public void error(Message message, ErrorResult result) {
		String msg = result.getMessage();
		Pattern p = Pattern.compile("<([^>]+)>: ([^']+)");
		Matcher m = p.matcher(msg);
		m.find();
//		if(m.matches()) // why doesn't this work in 1.4.2_06-b03 on linux?
		try {
			msg = m.group(2);
		} catch (IllegalStateException e) {
			// no match, so use whole message 
			msg = result.getMessage();
		}
		report(message, "error", msg);
	}
	
	public void start() {
	    Calendar cal = Calendar.getInstance(TimeZone.getTimeZone("GMT+10"));
		SimpleDateFormat sdf = new SimpleDateFormat("ddMMyyyy");
		System.out.println(rpad("HEADER " + sdf.format(cal.getTime()), ' ', 381));
	}

	public void complete() {
		System.out.println(rpad("TRAILER", ' ', 381));
	}

	// a truncating (right) padding function
	private String rpad(String text, char padding, int length) {
		if(length == 0) return "";
		if(text.length() > length) return text.substring(0, length-1);
		StringBuffer sb = new StringBuffer(text);
		for(int i = text.length(); i < length; i++) sb.append(padding);
		return sb.toString();
	}

	private void report(Message message, String result, String resultMessage) {
		Element data = message.getData();
		String customerNumber = "";
		if(data != null) {
			NodeList customerNumbers = data.getElementsByTagName("account_number");
			if(customerNumbers.getLength() > 0) {
				customerNumber = customerNumbers.item(0).getFirstChild().getNodeValue();
				// a fairly safe assumption - DOM sucks for doing this very common pattern
				// if it NullPointerExceptions at some point the input is probably broken,
				// but you can yell at me for being lazy, then fix it :-)
			}
		}
		
		String templateType = "none";
		String templateName = "";
		if(message.getTemplateURI() != null) {
			templateType = "template";
			templateName = message.getTemplateURI();
		}
		if(message.getStructureURI() != null) {
			templateType = "structure";
			templateName = message.getStructureURI();
		}
		
		// this is obviously lossy if there is more than one recipient
		String recipientAddress = null;
		Iterator recipients = message.getRecipients();
		while(recipients.hasNext()) {
			Recipient recipient = (Recipient) recipients.next();
			recipientAddress = recipient.getEmail();
		}
		
		System.out.println(
			rpad(customerNumber, ' ', 11) +
			rpad(templateType, ' ', 10) +
			rpad(templateName, ' ', 50) +
			rpad(recipientAddress, ' ', 200) +
			rpad(result, ' ', 10) + 
			rpad(resultMessage, ' ', 100)
		);
	}
}
