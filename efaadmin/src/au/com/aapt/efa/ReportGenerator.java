package au.com.aapt.efa;

import java.io.File;
import java.util.Iterator;
import java.io.IOException;
import org.xml.sax.SAXException;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;

public class ReportGenerator {
	private EmailBatchRequest request;
	private EmailBatchResponse response;

	public ReportGenerator(File requestFile, File responseFile) throws ParseException, ParserConfigurationException, SAXException, IOException {
		DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
		dbf.setNamespaceAware(true);
		dbf.setValidating(false);
		DocumentBuilder db = dbf.newDocumentBuilder();
		this.request = new EmailBatchRequest(db.parse(requestFile));
		this.response = new EmailBatchResponse(db.parse(responseFile));
	}
	
	public void report(ReportCollator rc) {
		if(this.response.getFault() != null) {
			rc.exception(this.response.getFault());
			return;
		}

		Iterator results = this.response.getResults();
		while(results.hasNext()) {
			Result result = (Result) results.next();
			Message message = this.request.getMessageById(result.getId());

			// if we can't find the request that generated this result (bad!)
			if(message == null) {
				rc.unmatchedResult(result);
				continue;
			}
			
			if(result instanceof ErrorResult) rc.error(message, (ErrorResult) result);
			else if(result instanceof SentResult) rc.sent(message, (SentResult) result);
		}
		
		// quick sanity check to ensure each message has a result
		// the loop above includes a test for the reverse
		// neither should ever happen!
		// The request(id) be 1-1 and onto response(id) (ie bijective)
		Iterator messages = this.request.getMessages();
		while(messages.hasNext()) {
			Message message = (Message) messages.next();
			Result result = this.response.getResultById(message.getId());
			if(result == null) rc.unmatchedMessage(message);
		}
	}
	
	public static void main(String args[]) throws Exception {
		if(args.length < 1 || args.length%2 != 1) throw new Exception("usage: reportImplementor (requestFile responseFile)*");
		ReportCollator rc = (ReportCollator) Class.forName(args[0]).newInstance();
		rc.start();
		for(int i = 1; i < args.length; i+=2) {
			ReportGenerator rg;
			try {
				rg = new ReportGenerator(new File(args[i]), new File(args[i+1]));
			} catch (ParseException e) {
				System.out.println("ParseException " + e.getMessage());
				System.out.println("processing "  + args[i] + " and " + args[i+1]);
				continue;
			} catch (ParserConfigurationException e) {
				System.out.println("ParserConfigurationException " + e.getMessage());
				System.out.println("processing "  + args[i] + " and " + args[i+1]);
				continue;
			} catch (SAXException e) {
				System.out.println("SAXException "  + e.getMessage());
				System.out.println("processing "  + args[i] + " and " + args[i+1]);
				continue;
			} catch (IOException e) {
				System.out.println("IOException "  + e.getMessage());
				System.out.println("processing "  + args[i] + " and " + args[i+1]);
				continue;
			}
			rg.report(rc);
		}
		rc.complete();
	}
}
