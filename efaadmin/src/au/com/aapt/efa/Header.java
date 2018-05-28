package au.com.aapt.efa;

import org.w3c.dom.Element;

public class Header {
	private String name;
	private String value;

	public Header(String name, String value) {
		this.name = name;
		this.value = value;
	}

	protected Header(Element headerElement) throws ParseException {
		if(!headerElement.getTagName().equals("header")) throw new ParseException("header element required.");
		this.name = headerElement.getAttribute("name");
		if(this.name == null) throw new ParseException("header element has no name attribute.");
		this.value = headerElement.getAttribute("value");
		if(this.value == null) throw new ParseException("header element has no value attribute.");
	}

	public String getName() { return this.name; }
	public void setName(String name) { this.name = name; }

	public String getValue() { return this.value; }
	public void setValue(String value) { this.value = value; }
}
