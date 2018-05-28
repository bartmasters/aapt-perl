package au.com.aapt.efa;

import java.util.Map;
import java.util.HashMap;
import java.util.Iterator;

import org.w3c.dom.Element;
import org.w3c.dom.Document;
import org.w3c.dom.NodeList;

public class EmailBatchRequest {
	private Map messages;

	public EmailBatchRequest() {
		this.messages = new HashMap();
	}

	public EmailBatchRequest(Document emailBatchRequest) throws ParseException {
		this();
		if(!emailBatchRequest.getDocumentElement().getTagName().equals("emailBatchRequest")) throw new ParseException("emailBatchRequest document required.");
		NodeList messages = emailBatchRequest.getElementsByTagName("message");
		for(int i = 0; i < messages.getLength(); i++) {
			Element messageElement = (Element) messages.item(i);
			this.addMessage(messageElement);
		}
	}

	private void addMessage(Element messageElement) throws ParseException {
		try {
			this.addMessage(new Message(messageElement));
		} catch (IllegalStateException ex) {
			throw new ParseException(ex);
		}
	}

	public void addMessage(Message message) {
		if(this.messages.containsKey(message.getId())) throw new IllegalStateException("message id '" + message.getId() + "' not unique within this request.");
		this.messages.put(message.getId(), message);
	}

	public Message getMessageById(String id) {
		return (Message) this.messages.get(id);
	}

	public Iterator getMessages() {
		return this.messages.values().iterator();
	}
}
