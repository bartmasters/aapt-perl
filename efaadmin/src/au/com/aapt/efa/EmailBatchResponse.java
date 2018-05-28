package au.com.aapt.efa;

import java.util.Map;
import java.util.HashMap;
import java.util.Iterator;

import org.w3c.dom.Element;
import org.w3c.dom.Document;
import org.w3c.dom.NodeList;

public class EmailBatchResponse {
	private Fault fault;  /* we call this a fault to avoid name collision with java.lang.Exception */
	private Map results;

	public EmailBatchResponse() {
		this.results = new HashMap();
	}

	public EmailBatchResponse(Document emailBatchResponse) throws ParseException {
		this();
		if(!emailBatchResponse.getDocumentElement().getTagName().equals("emailBatchResponse")) throw new ParseException("emailBatchResponse document required.");

		NodeList faults = emailBatchResponse.getElementsByTagName("exception");
		NodeList sents = emailBatchResponse.getElementsByTagName("sent");
		NodeList errors = emailBatchResponse.getElementsByTagName("error");

		// an exception, if present
		if(faults.getLength() > 1) throw new ParseException("more than one exception element found.");
		if(faults.getLength() == 1) {
			if(sents.getLength() > 0 || errors.getLength() > 0) throw new ParseException("results found in a response also containing an exception.");
			this.setFault(new Fault((Element) faults.item(0)));
		}

		// sent elements
		for(int i = 0; i < sents.getLength(); i++) {
			Element resultElement = (Element) sents.item(i);
			this.addResult(resultElement);
		}

		// error elements
		for(int i = 0; i < errors.getLength(); i++) {
			Element resultElement = (Element) errors.item(i);
			this.addResult(resultElement);
		}
	}

	public Fault getFault() { return this.fault; }
	public void setFault(Fault fault) {
		if(this.results.size() > 0) throw new IllegalStateException("a response containing results can not represent a fault.");
		this.fault = fault;
	}

	private void addResult(Element resultElement) throws ParseException {
		try {
			if(resultElement.getTagName().equals("sent")) {
				this.addResult(new SentResult(resultElement));
			} else if(resultElement.getTagName().equals("error")) {
				this.addResult(new ErrorResult(resultElement));
			} else {
				throw new ParseException("'" + resultElement.getTagName() + "' is not a valid result element.");
			}
		} catch (IllegalStateException isex) {
			throw new ParseException(isex);
		}
	}

	public void addResult(Result result) {
		if(this.fault != null) throw new IllegalStateException("results can not be added to a response representing a fault.");
		if(this.results.containsKey(result.getId())) throw new IllegalStateException("result id '" + result.getId() + "' not unique within this response.");
		this.results.put(result.getId(), result);
	}

	public Result getResultById(String id) {
		return (Result) this.results.get(id);
	}

	public Iterator getResults() {
		return this.results.values().iterator();
	}
}
