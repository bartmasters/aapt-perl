#!/bin/sh
# Fix group permissions for Smartcafe CVS files

CVSPATH="/export/home/gtxdev/GTXCVS/AAPT"

cd $CVSPATH

find . -user bamaster -ls -exec chown bamaster:gtxdevgrp {} \;

# All done, so exit successfully
echo "All good"
exit 0
