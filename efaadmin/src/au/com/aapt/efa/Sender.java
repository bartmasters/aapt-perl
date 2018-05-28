package au.com.aapt.efa;

import org.w3c.dom.Element;

public class Sender extends Address {
	public Sender(String email) {
		super(email);
	}

	protected Sender(Element senderElement) throws ParseException {
		super(senderElement);
		if(!senderElement.getTagName().equals("sender")) throw new ParseException("sender element required.");
	}
}
