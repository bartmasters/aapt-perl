package au.com.aapt.efa;

import org.w3c.dom.Element;

public abstract class Result {
	private String id;
	
	protected Result(String id) {
		this.setId(id);
	}

	protected Result(Element resultElement) throws ParseException {
		if(!resultElement.hasAttribute("id")) throw new ParseException("element has no id attribute.");
		this.setId(resultElement.getAttribute("id"));
	}

	public String getId() { return this.id; }
	public void setId(String id) { this.id = id; }
}
