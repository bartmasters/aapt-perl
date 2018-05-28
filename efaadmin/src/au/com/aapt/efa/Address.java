package au.com.aapt.efa;

import org.w3c.dom.Element;

public abstract class Address {
	private static final String emailRegexp = "^[^@]+@[^@.]+\\.[^@]+$";
	
	private String email;
	private String name;
	private String comment;

	protected Address(String email) {
		this.setEmail(email);
	}

	protected Address(Element addressElement) throws ParseException {
		if(!addressElement.hasAttribute("address")) throw new ParseException("element has no address attribute.");
		try {
			this.setEmail(addressElement.getAttribute("address"));
		} catch (IllegalArgumentException ex) {
			throw new ParseException(ex);
		}
		if(addressElement.hasAttribute("name")) this.setName(addressElement.getAttribute("name"));
		if(addressElement.hasAttribute("comment")) this.setComment(addressElement.getAttribute("comment"));
	}

	public String getEmail() { return this.email; }
	public void setEmail(String email) {
// Removed this check - it was bombing out if an address is not a valid email address, which would
// cause the whole job to die.  We don't care if there is an invalid email address.
//		if(!email.matches(Address.emailRegexp)) throw new IllegalArgumentException("'" + email + "' is not a valid email address.");
		this.email = email;
	}

	public String getName() { return this.name; }
	public void setName(String name) { this.name = name; }

	public String getComment() { return this.comment; }
	public void setComment(String comment) { this.comment = comment; }
}
