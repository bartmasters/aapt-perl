#!//usr/local/bin/perl -w

use strict;
use DBI;
use File::Copy;

use Getopt::Std;

#----
# XYZ Files/Directory to clean up...
my @remove = ( 	
		"/home/dlittle/Perl/Checker/bin/.xyz.dbm",
		"/home/dlittle/tmp"
		);

#----
# DB Tables to truncate
my @tables = qw(
		xyz_transaction
		xyz_carrier
		xyz_product
		xyz_site
		xyz_contact
		xyz_service
		xyz_mail
);

my %cmds;
getopts('o:s:u:p:dS:U:', \%cmds);

$cmds{o} ||= "haybioss1.opseng.aapt.com.au";
$cmds{s} ||= "WF817";
$cmds{u} ||= "wf";
$cmds{p} ||= "wf";

$cmds{S} ||= "glbncs4.opseng.aapt.com.au";
$cmds{U} ||= "dlittle";

my $source = 'DBI:Oracle:host='.$cmds{o}.';sid='.$cmds{s};  
print "---> Connection to $source with user, '$cmds{u}'\n";

my $dbh;
unless ($cmds{d}) {
	$dbh = DBI->connect($source, $cmds{u}, $cmds{p}, 
		{ RaiseError => 1, AutoCommit => 0 }) || die $DBI::errstr;
}

print "---> Truncate SQL for tables:\n\t- ";
print join("\n\t- ", @tables);

$SIG{INT} = \&interupt;

#----
# Just in case there's a ^C
print "\n---> Truncate in 4 seconds\n";
sleep(1);
print "---> Truncate in 3 seconds\n";
sleep(1);
print "---> Truncate in 2 seconds\n";
sleep(1);
print "---> Truncate in 1 seconds\n";
sleep(1);

unless ($cmds{d}) {
	my $sql = "truncate table ";
	foreach ( @tables ) {
		$dbh->do("$sql $_");
	}

	print "\n---> Truncation complete\n";

	$dbh->disconnect();
}

print "\n---> Doing directory/file cleanup\n";

foreach ( @remove ) {
	if (-e $_ && -f $_) {
		print "\tMoving $_\n"; 
		sleep(1);
		move($_, "/home/dlittle/tmp");
	} elsif(-e $_ && -d $_) {
		opendir(DIR, $_) or die "Couldn't open dir: $_: $!\n";
			my @files = readdir DIR;
		closedir DIR;
		print "\tDeleting (".($#files-1).") file(s)\n" if ($#files > 1);
		sleep(1);
		my ($f, $rem) = ("","rm ");
		foreach $f ( @files ) {
			if ($f =~ /^\.{1,2}$/) { next; }
			print "\t\t$_/$f\n";
			$rem .= "$_/$f ";
		}
		sleep(3);
		system("$rem") unless (length($rem) < 4 || $cmds{d})
	}
}

print "\n---> Do you wish to delete all mails in the POP Server?\n";
my $ans = <STDIN>; chomp($ans);
if ($ans && $ans =~ /[yY]/) {
	print "Password: ";
	my $pass = <STDIN>; chomp($pass);
	require Net::POP3;

	my $pop = new Net::POP3($cmds{S}, Timeout => 60)
                or ERROR("Couldn't Connect to POP ($cmds{S}): $!\n");

	defined($pop->login($cmds{U}, $pass))
                or ERROR("Couldn't Login to POP ($cmds{S})\n");

	my $mails = $pop->uidl()
                or ERROR("Couldn't Extract message no. and unique ids from pop server: $!\n");

	my @num = keys %$mails;
	print "---> Deleting ".($#num+1)." mails from server!\n" if ($#num > -1);
	my $msgn = "";
	foreach $msgn ( @num ) {  
		print "---> Deleting '$msgn'\n"; 
		$pop->delete($msgn) unless ($cmds{d}); 
	}
}

print "\n---> End $0\n";

sub interupt {
	my $int = shift;

	$dbh->disconnect();
	die "\n--->Cleanup cancelled\n";
}

sub ERROR {
	my $msg = shift;

	die "$msg";
}
