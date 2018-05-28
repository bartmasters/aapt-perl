#!/bin/sh
COUNT=1

until test $COUNT -ge 4
do
   echo $COUNT
   COUNT=`expr $COUNT + 1`
done

