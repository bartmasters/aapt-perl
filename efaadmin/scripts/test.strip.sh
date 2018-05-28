#!/bin/sh
###
# test.strip.sh
#
#	Test script for strip.pl
#	Uses ../testdata/strip-test-input.txt 
#	 and ../testdata/strip-correct-output.txt 
#	Run from the directory containing strip.pl
#
#	author:		Stephen Viles <stephen.viles@aapt.com.au>
#	version:	$Id: test.strip.sh,v 1.1 2004/12/13 04:39:15 sviles Exp $
###

# Create results directory if it does not exist
if [ ! -d results ] ; then
	mkdir results
fi

# Run strip.pl with test input data, redirecting both stdout and stderr
./strip.pl <../testdata/strip-test-input.txt >results/strip-test-output.txt 2>&1
if [ $? -ne 0 ] ; then 
	exit $?;
fi

# Compare results to correct output
diff -u ../testdata/strip-correct-output.txt results/strip-test-output.txt \
	>results/strip-test.diff 2>&1
exit $?;