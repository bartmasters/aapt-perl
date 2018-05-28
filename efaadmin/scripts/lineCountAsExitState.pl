#!/usr/bin/perl
# $Id: lineCountAsExitState.pl,v 1.1 2005/01/27 06:50:11 sviles Exp $
# The lines from here to the =cut are part of Perl's
# internal documentation system.  If you want 
# view the documentation use the command:
#
#       perldoc <script>
#
=pod

=head1 NAME

lineCountAsExitState.pl - Sets exit state to number of lines in input

=head1 SYNOPSIS

    perl lineCountAsExitState.pl [<input-file]

=head1 DESCRIPTION

The C<lineCountAsExitState.pl> script reads lines from standard input and sets
the exit state to the number of lines read, maximum 255. It produces no output.

=head1 AUTHOR

Stephen Viles, E<lt>stephen.viles@aapt.com.auE<gt>.

=head1 COPYRIGHT

Copyright 2005 AAPT Limited.  All rights reserved.

=cut

use strict;
use warnings;

my $line;
my $count = 0;

while (defined($line = <STDIN>) and $count < 255) {
        $count++;
}
exit $count;
