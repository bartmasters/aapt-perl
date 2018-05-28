package au.com.aapt.efa;

import org.w3c.dom.Node;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

public class ErrorResult extends Result {
	private String type;
	private String message;

	public ErrorResult(String id, String type, String message) {
		super(id);
		this.type = type;
		this.message = message;
	}
	
	protected ErrorResult(Element errorElement) throws ParseException {
		super(errorElement);
		if(!errorElement.hasAttribute("type")) throw new ParseException("error element has no type attribute.");
		this.setType(errorElement.getAttribute("type"));		

		StringBuffer sb = new StringBuffer();
		NodeList children = errorElement.getChildNodes();
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
		return "Error: id = '" + this.getId() + "', type = '" + this.type + "', message = '" + this.message + "'";
	}
}
