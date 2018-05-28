package Utils;

######################################################
# Utils.pm    - Util. Functions
#
# Created:      August 19, 2001
# Author:       David Little
# Version:      1.0
#
######################################################

use Mail::Mailer;
use File::Basename;
use File::Copy;

#----
# date(digits)	-	Return date
# mail(to, subj, body, from) - Mail Someone!
# debug(msg)	- Pring debug message if DEBUG is set...
# fcopy(old, new) - File copy
# fmove(old, new) - File move
# save(file, msg) - Save Message to file
# tagfile(file, start, s) - Tag the file
#

#----
# Debug print outs?  Set this in one of the scripts,
# i.e. Utils::DEBUG = 0;  If you don't want debug info...
use vars qw($DEBUG);

# date(digits) - Return a date field 'digits' in size
# Parameters:	digits - Number of digits date should be
#
# Return:		<date> in yyyymmddhhmmssmm format
#
sub date {
	my $digits = shift || 16;  # How many digits you want...
	$digits = 16 if ($digits > 16);

	my ($y, $m, $d, $h, $mi, $se) = (localtime)[5,4,3,2,1,0];
	$y += 1900;
	$m += 1;
	my $ms = 0;

	my $date = sprintf("%4d%02d%02d%02d%02d%02d%02d%02d", 
				$y, $m, $d, $h, $mi, $se, $ms);

	return substr($date,0,$digits);
}

# mail(to, subj, body, from) - Mail Someone!
# Parameters:	to - Mail address
#				subj - Mail subject
#				body - Mail body
#				from - From address ($0 default)
#
# Return:		Error Message on failure, undef on success
#
sub	mail {
	my $to = shift;
	my $subj = shift || "$0 Message";
	my $body = shift || (caller(2))[3];
	my $from = shift || $0;

	my $mail = Mail::Mailer->new("sendmail") or return "Couldn't create mail object: $!";

	debug("Opening Mail ($to)\n");
	$mail->open({
			'From'		=> $from,
			'To'		=> $to,
			'Subject' 	=> $subj
			})
			or return "Couldn't open mail: $!";
	
	print $mail $body;
	$mail->close();
	debug("Closed Mail ($to)\n");

	return;
}

# debug(msg) - Prints msg message
# Parameters:	msg - String message to print out
#				docaller - Print calling Function info.
#
#
# Print only on Utils::DEBUG set 
#
sub debug {
    my $msg = shift || "";
	my $docaller = shift || 2;

	return $Utils::DEBUG unless ($msg);

	if ($Utils::DEBUG) {
	   my $where = (caller($docaller))[3] || "";

	   my $out = "";
	   $out = "[$where]\t$msg" if ($where && $docaller > 1);
	   $out ||= $msg;

	   print STDOUT "$out";
	}
}

# fcopy(old, new) - File copy
# Parameters:	old - Old filename to copy
#				new - New filename to copy to..
#
#
# Return:		Error Message on Failure, undef on success
#
# This sub uses the File::Basename/File::Copy modules to copy
# the old file (including full path name to new file including
# full path name) The sub. tags (tagfile) the new file if it already
# finds a new filename in existance.
sub	fcopy {
	my $old   = shift;
	my $new   = shift;

	my $odir  = dirname($old);
	die "Couldn't extract directory from $old" unless ($odir);

	$new = $old unless ($new); 
	$new = $odir ."/". $new unless ($new =~ /^\//);
	$new = &tagfile($new) if (-e $new);
	return "Couldn't tag $new" unless ($new);

	return "Couldn't locate $old" unless (-e $old);
	copy($old, $new) or return "Couldn't copy from $old to $new: $!";

	return;
}

# fmove(old, new) - File move
# Parameters:	old - Old filename to move
#				new - New filename to move to..
#
#
# Return:		Error Message on Failure, undef on success
#
# This sub uses the File::Basename/File::Copy modules to move
# the old file (including full path name to new file including
# full path name, The sub. tags, tagfile() the new file if 
# it already finds a the filename in existance.
sub	fmove {
	my $old   = shift;
	my $new   = shift;

	$new = $old unless ($new);
	$new = $odir ."/". $new unless ($new =~ /^\//);
	$new = &tagfile($new) if (-e $new);
	return "Couldn't tag $new" unless ($new);

	return "Couldn't locate $old" unless (-e $old);
	move($old, $new) or return "Couldn't move $old to $new: $!";	

	return;
}

# save(file, msg) - Save Message
# Parameters:	file - filename to save message to..
#				msg - Message to save (scalar, array or hash)
#
#
# Return:		Error Message on Failure, undef on success
#
# This sub. takes file and making sure there's no existing, writes
# the message (which can be SCALAR, ARRAY or HASH) to it.  It tries
# to create the <dir> parent/<dir>/file if it doesn't already exist.
sub save {
	my $file  = shift;
	my $msg   = shift;
	my $loc   = dirname($file) || return;

	debug("Saving File $file\n"); sleep(2);
	my $parent = dirname($loc);
	return "$parent isn't a directory!" unless (-d $parent);	# parent must be a directory	

	# Create the <loc> dir... ~/parent/<loc>/file
	unless (-d $loc) {
		mkdir($loc, "0777") or die "Couldn't mkdir $loc: $!";
	}

	$file = &tagfile($file) || die "Couldn't save $file\n";

	my $output = $msg;
	$output = join("\n", @$msg) if ($msg =~ /ARRAY/);

	if ($msg =~ /HASH/) {
		$output = "";
		foreach ( %$msg ) { $output .= "$_=".$msg->{$_}."\n"; }
	}

	open(S, ">$file") or return "Couldn't open $loc/$file: $!";
	print S "$output\n";
	close(S);

	return;
}

# tagfile(file, start, s) - Tag the file
# Parameters:	file - File to tag
#				start - Start tag at...
#				s - Number of places (e.g. 0001) def: 4
#
# Return:		Tagged file
#
# Tries to tag the file, if tagged file already in existance
# then tag is incremented until tagged file no longer in existance.
#
sub tagfile {
	my $file  = shift;
	my $start = shift || 1;
	my $s     = shift || 4;   # size for sprintf

	my $new 	= $file;
	my $tag 	= $start;	# Append tag onto file 

	while ( -e $new ) {
		$new =  "$file." . sprintf('%0'.$s.'d', $tag++);
		debug("Trying tag file: $new\n");
		return if (length($tag) > $s);
	}

	return $new;
}

sub	display {
	my $head = shift || "";
	my $list = shift || return;
	my $need = shift || "";

	my $i = 1;
	
	my @tmp;
	print "\n";
	print "$head\n". "=" x length($head) . "\n" if ($head);
	if ($list =~ /ARRAY/) {
		foreach ( @$list ) { 
			push @tmp, $_;
			print $i++.". $_\n"; 
		}
	} elsif ( $list =~ /HASH/ ) {
		foreach ( sort keys %$list ) { 
			push @tmp, $_;
			print $i++.". $_: ".$list->{$_}."\n"; 
		}
	} 
	print "\n";

	my $ans;
	if ($need) {
		print "$need> ";
		while($ans = <STD> && $ans !~ /\d/ && $ans > $#tmp) {
			print "Bad Input!\n";
			print "> ";
		}
		chomp($ans);
		return $ans;
	}

}

1;
