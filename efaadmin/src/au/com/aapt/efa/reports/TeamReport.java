package au.com.aapt.efa.reports;

import java.util.Iterator;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

import au.com.aapt.efa.ErrorResult;
import au.com.aapt.efa.Fault;
import au.com.aapt.efa.Message;
import au.com.aapt.efa.Recipient;
import au.com.aapt.efa.ReportCollator;
import au.com.aapt.efa.Result;
import au.com.aapt.efa.SentResult;

public class TeamReport implements ReportCollator {
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
		// no reporting on successful send
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
		report(message, msg);
	}
	
	public void start() {
	}

	public void complete() {
	}

	// a truncating (right) padding function
	private String rpad(String text, char padding, int length) {
		if(length == 0) return "";
		if(text.length() > length) return text.substring(0, length-1);
		StringBuffer sb = new StringBuffer(text);
		for(int i = text.length(); i < length; i++) sb.append(padding);
		return sb.toString();
	}

	// a shorter version of the above
	private String rpad(String text, int length) {
		return rpad(text, ' ', length);
	}
	
	private void report(Message message, String resultMessage) {
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
		
		// this is obviously lossy if there is more than one recipient
		String recipientAddress = null;
		Iterator recipients = message.getRecipients();
		while(recipients.hasNext()) {
			Recipient recipient = (Recipient) recipients.next();
			recipientAddress = recipient.getEmail();
		}
		
		System.out.println(
			rpad(customerNumber, ' ', 20) +
			rpad(recipientAddress, ' ', 50) +
			resultMessage
		);
	}
}
