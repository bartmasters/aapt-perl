#!/bin/csh

# $Header: wfbkg.csh 26.0 2000/07/05 22:08:36 kma ship $
#
# Workflow Background Engine perpetual shell
# Runs the workflow background engine periodically
#
# ENVIRONMENT
#
# HISTORY
#   18 Oct 1996  G Buzsaki     Created

#
# Usage
#
set PROG=$0
set PROG=$PROG:t
echo "Workflow Background Engine"

#
# Test connection
#
sqlplus wf/wf <<END >&/dev/null
exit 99
END

if ("$status" != "99") then
  echo "Error:  Invalid connect string."
  exit 1
endif

#
# Log file
#
set LOG=/pkgs/XYZed-1.0/logs/$PROG:r.log
echo "  Log file: ' $LOG'"
cat <<END > $LOG
Workflow Background Engine Log
END
if ($status != 0) then
  echo "Error:  can't write log file"
  exit 1
endif


#
# Engine Loop
#
while 1
  echo "  Background started:  " `date`
  echo "# Background started:  " `date`   >> $LOG

  # Run background engine
  sqlplus -s wf/wf << END >> $LOG
whenever sqlerror exit failure;
exec wf_engine.background;
exit 99;
END
  set STAT=$status
  echo "  Background finished: " `date`
  echo "# Background finished: " `date`   >> $LOG

  if $STAT != 99 then
    echo "    Engine Failure, check log"
  endif
  echo "  resting for 10 minutes..."
  sleep 600
end

echo "Exiting, status $STAT"
exit $STAT
