package au.com.aapt.efa;

import org.w3c.dom.Element;

public class Recipient extends Address {
	public static final String TO = "to";
	public static final String CC = "cc";
	public static final String BCC = "bcc";

	private String type;

	public Recipient(String type, String email) {
		super(email);
		this.setType(type);
	}

	protected Recipient(Element recipientElement) throws ParseException {
		super(recipientElement);
		if(!recipientElement.getTagName().equals("recipient")) throw new ParseException("recipient element required.");
		if(!recipientElement.hasAttribute("type")) throw new ParseException("recipient element has no type attribute.");
		try {
			this.setType(recipientElement.getAttribute("type"));
		} catch (IllegalArgumentException ex) {
			throw new ParseException("type can not be assigned.", ex);
		}
	}
	
	public String getType() { return this.type; }
	public void setType(String type) {
		if(!type.equals(Recipient.TO) && !type.equals(Recipient.CC) && !type.equals(Recipient.BCC)) throw new IllegalArgumentException("'" + type + " is an invalid recipient type.");
		this.type = type;
	}
}
