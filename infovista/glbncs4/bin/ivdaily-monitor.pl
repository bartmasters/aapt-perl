#!/pkgs/bin/perl -w
######################################################
# ivdaily-finish.pl - Finish daily extracts for InfoVista
#
# Created:      August 19, 2003
# Author:       Bart Masters
# Version:      1.0
#
# This program is the final program in the daily extract
# of circuits/NEs from Bioss for Infovista processing.
#
# It is started by ivdaily.pl, and then runs in daemon
# mode waiting for the various extract programs to
# finish their processing.  Once they have finished,
# it will :-
#
# Run extractpword.pl to extract all paswords.
#
# Back up all current files
# 
# Collate all extracted files, and collate them into 
# topology files.
#
# scp the password.txt file to aaptull2.
#
# If there are any problems with processing, the
# appropriate people will be emailed.
#
######################################################

use strict;			# Be good, lil program
use Getopt::Std;		# Process command line options
use File::Copy;			# Copy files around
use Mail::Mailer;		# Email if theres any probs
use Mail::Sender;		# Send emails with attachments

# Global Variables

my %cmds;
my $command;
my $params = "tf:d:";
my $run_path;
my @admin_mail_addr;
my @support_mail_addr;
#my @pollers = qw(hay glb sv8);
my @pollers = qw(hay glb);
my @test_pollers = qw(hvt);
my @extract_list = qw(atmfr custrouter ethlan gen-pword ipvpn saa);
my %extract_complete;
my $run_date;
my %poller_error;

#----------------------
# Main Processing
#----------------------

# Get the command line options

getopts($params, \%cmds);

if (defined $cmds{t})
{
    @pollers = @test_pollers;
}

if (defined $cmds{f})
{
    $run_path = $cmds{f};
}
else
{
    $run_path = "..";
}

if (defined $cmds{d})
{
    $run_date = $cmds{d};
}
else
{
    my @local_time = (localtime)[0..5];
    $local_time[4]++;
    $local_time[5] += 1900;
    my $run_date1 = sprintf("%02d%02d%04d", $local_time[3], $local_time[4], $local_time[5]);
    my $run_date2 = sprintf("%02d%02d%02d", $local_time[2], $local_time[1], $local_time[0]);
    $run_date = $run_date1 . "-" . $run_date2;
}

# Get email details

my $admin_mail_filename = $run_path . "/files/admin_email_addr";
open (ADMINFILE, "$admin_mail_filename") or die "Error opening $admin_mail_filename $!\n";

while (<ADMINFILE>)
{
    chomp;
    my $first_char = substr($_, 0, 1);
    if (($first_char eq "#") ||
	($first_char eq " ") ||
	($first_char eq ""))
    {
	next;
    }
    else
    {
	push (@admin_mail_addr, $_);
    }
}
close (ADMINFILE);

my $support_mail_filename = $run_path . "/files/support_email_addr";
open (SUPPORTFILE, "$support_mail_filename") or die "Error opening $support_mail_filename $!\n";

while (<SUPPORTFILE>)
{
    chomp;
    my $first_char = substr($_, 0, 1);
    if (($first_char eq "#") ||
	($first_char eq " ") ||
	($first_char eq ""))
    {
	next;
    }
    else
    {
	push (@support_mail_addr, $_);
    }
}
close (SUPPORTFILE);

# Set up the hash of programs to be checked for output

my $extract_prog;
foreach $extract_prog (@extract_list)
{
    my $extr_poller;
    foreach $extr_poller (@pollers)
    {
	my $temp = "$extract_prog.end.$extr_poller.$run_date";
	$extract_complete{$temp} = "No";
    }
}
$extract_complete{"wansw.end.$run_date"} = "No";
    
# Now go into daemon mode - every 5 minutes monitor
# the run path and see if all the export jobs have
# completed.

my $exit_daemon = "No";
while ($exit_daemon eq "No")
{
    my $extract_prog;
    foreach $extract_prog (@extract_list)
    {
	my $extr_poller;
	foreach $extr_poller (@pollers)
	{
	    my $temp = "$extract_prog.end.$extr_poller.$run_date";
	    $extract_complete{$temp} = checkFile($extract_prog, $extr_poller);
	}
    }
    my $temp = "wansw.end.$run_date";
    $extract_complete{$temp} = checkFile("wansw");

# Now we've checked if the jobs have finished and created
# the appropriate files, see if all jobs have finished.  If
# they are all finished, exit the daemon.

    my $exit_daemon = "Yes";
    my $program_keys;
    foreach $program_keys (keys %extract_complete)
    {
	if ($extract_complete{$program_keys} eq "No")
	{
	    $exit_daemon = "No";
	}
    }

# If one program hasn't finished, wait 5 minutes before
# checking again.

    if ($exit_daemon eq "Yes")
    {
	last;
    }
    else
    {
	sleep 300;
    }
}

# If we've got here, all the previous programs have finished
# processing, so we can do something with them.  First extract
# all the generated userids/passwords.

extractPword();

# Next clean up the .end files

my $prog_name;
my $temp_filename;
foreach $prog_name (keys %extract_complete)
{
    $temp_filename = $run_path . "/files/" . $prog_name;
    unlink $temp_filename;    
}

# Finally, move the various temp files around.

moveFiles();

exit 0;

#-----------------------------
# Subroutines
#-----------------------------
#
# checkFile	Check if a file exists
#
# Parameters:	Program Name, Poller
#
# Returns:	Yes/No
	    
sub checkFile
{
    my $prog_name = shift;
    my $poller = shift;
    my $temp;
    
    if (defined $poller)
    {
	$temp = $prog_name . ".end." . $poller;
    }
    else
    {
	$temp = $prog_name . ".end";
    }

    my $filename = $run_path . "/files/" . $temp . "." . $run_date;
    my $error_filename = $filename;
    $error_filename =~ s/\.end\./\.error\./;
    $error_filename =~ s/files/log/;

# If an error file exists with a size greater than 0 bytes,
# there was a serious error running that program - email
# support and die.

    if (-s $error_filename)
    {
	mailSupport("There was an error extracting Bioss data - check $error_filename for more information");
	$poller_error{$poller} = "Error";
	return "Yes";
    }
    
    if (-e $filename)
    {
	return "Yes";
    }
    else
    {
	return "No";
    }
}
# extractPword	Extract all passwords
#
# Parameters:	None
#
# Returns:	Return Code

sub extractPword
{
    my $output_file = $run_path . '/log/extractpword.file.' . $run_date;
    my $error_file = $run_path . '/log/extractpword.error.' . $run_date;

    my $command = "$run_path/bin/extractpword.pl -f $run_path >>$output_file 2>>$error_file";
    my $rc = system("$command");

    if ($rc)
    {
        mailSupport ("Error extracting customer passwords - check extractpword error log\n");
	die;
    }
}
# mailAdmin	Mail the admin if bad circuits have been extracted
#
# Parameters:	Error filename
#
# Returns:	None

sub mailAdmin
{
    my $error_filename = shift;
    my $adminmailaddr = join (",", @admin_mail_addr);
    my $mail = new Mail::Sender {smtp => 'glbncs4.opseng.aapt.com.au',
				 from => 'BIOSS Operations@aapt.com.au',
				 on_errors => undef};

    $mail->MailFile({to	=> "$adminmailaddr",
    		subject	=> 'Invalid data extracted',
		msg	=> 'The InfoVista extract from Bioss has found bad data - please check the attached file for details.',
		file	=> "$error_filename"});	

    if (defined $mail->{error_msg})
    {
	mailSupport("Error creating admin email - $mail->{error_msg}\n");
	die;
    }
}
# mailSupport	Mail Apps Support if something bad has happened
#
# Parameters:	Error string
#
# Returns:	None

sub mailSupport
{
    my $error_string = shift;
    my $supportmailaddr = join (",", @support_mail_addr);

    my $mail = Mail::Mailer->new("sendmail") or die "Error trying to create mail: $!\n";
    $mail->open({
	    "From"	=> "IV Daily Extract",
	    "To"	=> $supportmailaddr,
	    "Subject"	=> "Error in Infovista extract from BIOSS on glbncs4"
	    })
		or die "Couldn't create mail: $!\n";
		
    print $mail $error_string;
    $mail->close();
}
# moveFiles	Move around and backup the output files
#
# Parameters:	None
#
# Returns:	None

sub moveFiles
{
# wansw.pl output first

    my $path = $run_path ."/files";
    chdir $path;
	
    copy("wansw.txt", "backup/wansw.$run_date");
    copy("cust.error.txt", "backup/cust.error.$run_date.txt");
    rename("wansw.tmp", "wansw.txt");
    unlink("cust.error.txt");
    unlink("cust.error.tmp");

# Next all the circuit info for each poller.  If the poller
# had an error - just delete the temp files and skip to the
# next poller.

    my $poller;
    foreach $poller (@pollers)
    {
	unlink("${poller}_cust.tmp");
        my $file;
	my $command;

	if ($poller_error{$poller} eq "Yes")
	{
	    unlink<serv-$poller-.*>;
	    next;
	}
	
        opendir(DIR, $path);
	while (defined($file = readdir(DIR)))
        {
	    if ($file =~ /^serv-$poller-.*\.ready$/)
	    {
		$command = "cat $file >> ${poller}_cust.tmp";
		system("$command");
	        unlink("$file");
	    }
	    elsif ($file =~ /^serv-$poller-.*\.tmp$/)
	    {
		unlink($file);
	    }
	    elsif ($file =~ /^serv-$poller-.*\.error$/)
	    {
		$command = "cat $file >> cust.error.tmp";
		system("$command");
		unlink("$file");
	    }
	}

# Play with the output to load in the hardcoded IP-VPN core records

	my $error_file = $run_path . '/log/ipvpn-core.error.' . $run_date;
	my $filename =  $run_path . '/files/'. $poller . '-ipvpn-core' . '.ready';
	my $topo_name = $run_path . '/files/'. $poller . '_cust.tmp';
	my $base_name = $run_path . '/files/ipvpn-core-base';
	$command = "$run_path/bin/ipvpn-core.pl -f $filename -h $poller -b $base_name -t $topo_name -p $run_path >$error_file 2>>$error_file";
	my $rc = system("$command");

	if ($rc)
	{
	    mailSupport ("Error updating IP-VPN core records - check ipvpn-core error log\n");
	}

	$command = "cat $filename >> ${poller}_cust.tmp";
	system("$command");
	
# Now that we have all the circuit output for the poller in 
# poller_cust.tmp, get them ready for FTPing to their appropriate server

	copy("${poller}_topology.txt", "backup/${poller}_topology.$run_date");
	$command = "sort -m ${poller}_cust.tmp ${poller}_extra wansw.txt -o ${poller}_topology.txt";
	system("$command");
	copy("${poller}_topology.txt", "$path/outbound/");
    }
 
# If an error file has been created - email the admin to check it out

    if (-e "cust.error.tmp")
    {
	$command = "cp cust.error.tmp cust.error.txt";
	system("$command");
	# mailAdmin("cust.error.txt");
	# Notes: The cust.error.txt contains many error 103 messages which are not valid to be
	# reported This error report will be checked and the invalid error messages will be
	# removed from the report before e-mailing it to the users
	# (See the Perl script chk_cust_error_rep.pl).
    }
    
# Pull together the password output

    copy("password.tmp", "backup/password.$run_date");
    $command = "sort -m password.tmp special_pwords.txt -o password.txt";
    system("$command");
    unlink("password.tmp");
    copy("password.txt", "$path/outbound/");

# Finally, scp the password to aaptull2 if we're not in test mode.

    unless (defined($cmds{t}))
    {
        $command = "/pkgs/bin/scp $path/outbound/password.txt aaptull2:/opt/InfoVista/PortalSE/config/users.txt";
    
	my $rc = system("$command");
        if ($rc)
	{
	    mailSupport ("Error performing scp from glbncs4 to aaptull2 - $rc\n");
        }
        $command = "/pkgs/bin/scp $path/outbound/password.txt aunswa076.au.tcnz.net:/opt/InfoVista/PortalSE/config/users.txt";
    
	$rc = system("$command");
        if ($rc)
	{
	    mailSupport ("Error performing scp from glbncs4 to aunswa076 - $rc\n");
        }
    }
}
