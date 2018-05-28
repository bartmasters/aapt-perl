#!/pkgs/bin/perl
# $Id: strip.pl,v 1.3 2004/12/13 06:16:33 sviles Exp $
# The lines from here to the =cut are part of Perl's
# internal documentation system.  If you want 
# view the documentation use the command:
#
#       perldoc <script>
#
=pod

=head1 NAME

strip.pl - Filter to strip trailing spaces

=head1 SYNOPSIS

    perl strip.pl <original-text >stripped-text

=head1 DESCRIPTION

The C<strip.pl> filter reads lines from standard input, removes trailing spaces,
 and prints the lines to standard output.

=head1 AUTHOR

Stephen Viles, E<lt>stephen.viles@aapt.com.auE<gt>.

=head1 COPYRIGHT

Copyright 2004 AAPT Limited.  All rights reserved.

=cut

use strict;
use warnings;

my $line;

while (defined($line = <STDIN>)) {
#                   +------------ Match start of line (^)
#                   |+----------- Match any character (.)
#                   ||+---------- Repeat 0 or more times (*)
#                   |||+--------- as little as possible (?)
#                  +||||+-------- Put the enclosed in $1
#                  ^||||^+------- Match space
#                  ^||||^|+------ Repeat one or more times (+)
#                  ^||||^||+----- Match end of line ($)
#                 +^||||^|||+---- Substitute matched expression
#                 ^^||||^|||^+-+- with $1 
        $line =~ s/(^.*?) +$/$1/;
        print $line;
}
