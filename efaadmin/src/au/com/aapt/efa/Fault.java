package au.com.aapt.efa;

import org.w3c.dom.Node;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

public class Fault {
	private String type;
	private String message;
	
	public Fault(String type, String message) {
		this.type = type;
		this.message = message;
	}
	
	protected Fault(Element faultElement) throws ParseException {
		if(!faultElement.getTagName().equals("exception")) throw new ParseException("exception element required.");
		if(!faultElement.hasAttribute("type")) throw new ParseException("exception element has no type attribute.");
		
		this.setType(faultElement.getAttribute("type"));

		StringBuffer sb = new StringBuffer();
		NodeList children = faultElement.getChildNodes();
		for(int i = 0; i < children.getLength(); i++) {
			Node child = children.item(i);
			if(child.getNodeValue() != null) sb.append(child.getNodeValue());
		}
		this.setMessage(sb.toString());
	}

	public String getType() { return this.type; }
	public void setType(String type) { this.type = type; }

	public String getMessage() { return this.message; }
	public void setMessage(String message) { this.message = message; }

	public String toString() {
		return "Fault: type = '" + this.type + "', message = '" + this.message + "'";
	}
}
