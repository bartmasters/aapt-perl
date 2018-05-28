package au.com.aapt.efa;

import org.w3c.dom.Element;

public class SentResult extends Result {
	public SentResult(String id) {
		super(id);
	}
	
	protected SentResult(Element sentElement) throws ParseException {
		super(sentElement);
	}
	
	public String toString() {
		return "Sent: id = '" + this.getId() + "'";
	}
}
