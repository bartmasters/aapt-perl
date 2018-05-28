package au.com.aapt.efa;

import java.util.Iterator;
import java.util.Collection;
import java.util.LinkedList;

import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

public class Message {
	private String id;
	private String templateURI;
	private String structureURI;

	private Sender sender;
	private Collection recipients;
	private Collection headers;
	
	private String body;
	private Element data;

	private Message() {
		this.recipients = new LinkedList();
		this.headers = new LinkedList();
	}

	public Message(String id) {
		this();
		this.id = id;
	}

	/**
	 * Parse a message Element constructing a representing Message object.
	 */
	protected Message(Element messageElement) throws ParseException {
		this();

		// deal with the message attributes first
		if(!messageElement.hasAttribute("id")) throw new ParseException("message element has no id attribute.");
		this.setId(messageElement.getAttribute("id"));
		boolean hasTemplate = messageElement.hasAttribute("template");
		boolean hasStructure = messageElement.hasAttribute("structure");
		if(hasTemplate && hasStructure) throw new ParseException("message element (id = '" + this.id + "') has both a template and structure attribute.");
		try {
			if(hasTemplate) this.setTemplateURI(messageElement.getAttribute("template"));
			if(hasStructure) this.setStructureURI(messageElement.getAttribute("structure"));
		} catch (IllegalStateException ex) {
			throw new ParseException(ex);
		}

		// the sender element
		NodeList senders = messageElement.getElementsByTagName("sender");
		if(senders.getLength() != 1) throw new ParseException("message element (id = '" + this.id + "') has no single sender element.");
		Element senderElement = (Element) senders.item(0);
		this.setSender(new Sender(senderElement));

		// the recipient elements
		NodeList recipients = messageElement.getElementsByTagName("recipient");
		if(recipients.getLength() < 1) throw new ParseException("message element (id = '" + this.id + "') has no recipient elements.");
		for(int i = 0; i < recipients.getLength(); i++) {
			Element recipientElement = (Element) recipients.item(i);
			this.addRecipient(new Recipient(recipientElement));
		}

		// the header elements
		NodeList headers = messageElement.getElementsByTagName("header");
		for(int i = 0; i < headers.getLength(); i++) {
			Element headerElement = (Element) headers.item(i);
			this.addHeader(new Header(headerElement));
		}
		
		// the body element
		NodeList bodies = messageElement.getElementsByTagName("body");
		if(bodies.getLength() > 1) throw new ParseException("message element (id = '" + this.id + "') has more than one body element.");
		if(bodies.getLength() == 1) {
			Element bodyElement = (Element) bodies.item(0);
			StringBuffer sb = new StringBuffer();
			NodeList children = bodyElement.getChildNodes();
			for(int i = 0; i < children.getLength(); i++) {
				String value = children.item(i).getNodeValue();
				if(value != null) sb.append(value);
			}
			try {
				this.setBody(sb.toString());
			} catch (IllegalStateException ex) {
				throw new ParseException(ex);
			}
		}
		
		// the data element
		NodeList datas = messageElement.getElementsByTagName("data");
		if(datas.getLength() > 1) throw new ParseException("message element (id = '" + this.id + "') has more than one data element.");
		if(datas.getLength() == 1) {
			try {
				this.setData((Element) datas.item(0));
			} catch (IllegalStateException ex) {
				throw new ParseException(ex);
			}
		}		
	}

	public String getId() { return this.id; }
	public void setId(String id) { this.id = id; }

	public String getTemplateURI() { return this.templateURI; }
	public void setTemplateURI(String templateURI) {
		if(this.structureURI != null) throw new IllegalStateException("a template can not be specified when a structure has.");
		if(this.body != null) throw new IllegalStateException("a template can not be specified when a body has.");
		this.templateURI = templateURI;
	}

	public String getStructureURI() { return this.structureURI; }
	public void setStructureURI(String structureURI) {
		if(this.templateURI != null) throw new IllegalStateException("a structure can not be specified when a template has.");
		if(this.body != null) throw new IllegalStateException("a structure can not be specified when a body has.");
		this.structureURI = structureURI;
	}

	public Sender getSender() { return this.sender; }
	public void setSender(Sender sender) { this.sender = sender; }

	public Iterator getRecipients() { return this.recipients.iterator(); }
	public void addRecipient(Recipient recipient) { this.recipients.add(recipient); }

	public Iterator getHeaders() { return this.headers.iterator(); }
	public void addHeader(Header header) { this.headers.add(header); }

	public String getBody() { return this.body; }
	public void setBody(String body) {
		if(this.templateURI != null || this.structureURI != null) throw new IllegalStateException("a body can not be specified when a template or structure has.");
		this.body = body;
	}

	public Element getData() { return this.data; }
	public void setData(Element data) {
		if(this.body != null) throw new IllegalStateException("a data block can not be specified when a body has.");
		this.data = data;
	}
}
