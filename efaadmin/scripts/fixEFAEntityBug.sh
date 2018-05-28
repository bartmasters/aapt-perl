#!/bin/sh
###
# fixEFAEntityBug.sh
#
# Works around an entity escaping bug in Dougal's efa.py EFA implementation.
#
#	author:		Alan Yates <alan.yates@aapt.com.au>
#	version:	$Id: fixEFAEntityBug.sh,v 1.4 2005/05/05 05:57:39 bamaster Exp $
###

###
# Load config details
###
. $HOME/bin/config

if [ ! -f $1 ] ; then
	echo "`date +%Y-%m-%dT%H:%M:%S` $$ can not find file '$1'!" >> $LOGFILE
	exit 1
fi

###
# Fix busted entities - this isn't very robust!
###
sed "s/'</'\&lt;/g" $1 > $TEMP/$$
sed "s/>:/\&gt;:/g" $TEMP/$$ > $1
rm -f $TEMP/$$
