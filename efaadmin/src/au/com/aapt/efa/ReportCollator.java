package au.com.aapt.efa;

public interface ReportCollator {
	public void exception(Fault exception);

	public void unmatchedResult(Result result);
	public void unmatchedMessage(Message message);

	// yes it is redundant to have two seperate methods for subclass types of Result
	public void sent(Message generator, SentResult result);
	public void error(Message generator, ErrorResult result);

	public void start();
	public void complete();
}
