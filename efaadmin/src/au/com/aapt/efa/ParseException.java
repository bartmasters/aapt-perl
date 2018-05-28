package au.com.aapt.efa;

public class ParseException extends Exception {
	public ParseException() { super(); }
	public ParseException(String message) { super(message); }
	public ParseException(Throwable cause) { super(cause); }
	public ParseException(String message, Throwable cause) { super(message, cause); }
}