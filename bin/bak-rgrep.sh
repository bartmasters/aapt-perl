#!/bin/sh
for FILE in `find . -print`
do
    if [ `grep -c $1 $FILE` -ne 0 ]
    then
	echo $FILE
	grep -i -n $1 $FILE
    fi
done
