#-------------------------------------------------------#
#                                                       #
# Hostname      : glbncs4                               #
#                                                       #
# Location      : /export/oracle/product/OD6.0.6        #
#                                                       #
# Filename      : reports60.sh                          #
#                                                       #
#-------------------------------------------------------#

## Example file to set environment variables in Bourne-shell or K-shell
## for Oracle Reports 6i. Refer to Install Doc for more detail on each
## of these environment variables. You need to modify all the environment
## variables before doing source on this file ( % . reports60.sh ).

ORACLE_HOME=/export/oracle/product/OD6.0.6; export ORACLE_HOME

## if you need more than one diretory in your path, all directories should  be
## separated by ':'
PATH=$ORACLE_HOME/bin:${PATH}; export PATH
LD_LIBRARY_PATH=$ORACLE_HOME/lib:${LD_LIBRARY_PATH}:$ORACLE_HOME/network/jre11/lib/sparc/native_threads; export LD_LIBRARY_PATH

## You need to set TNS_ADMIN and TWO_TASK or ORACLE_SID to connect to database
TNS_ADMIN=/export/oracle/local/network/admin; export TNS_ADMIN
#TWO_TASK=< two task name >; export TWO_TASK
#ORACLE_SID=< ORACLE SID >; export ORACLE_SID

## setting for all products
ORACLE_TERM=vt220; export ORACLE_TERM
TK60_ICON=$ORACLE_HOME/tools/devdem60/bin/icon; export TK60_ICON
UI_ICON=$TK60_ICON; export UI_ICON
DEMO60=$ORACLE_HOME/tools/devdem60; export DEMO60

## setting for Forms Runtime
FORMS60_PATH=$ORACLE_HOME/tools/devdem60/demo/forms; export FORMS60_PATH
FORMS60_TERMINAL=$ORACLE_HOME/forms60/admin/terminal/US; export FORMS60_TERMINAL

## setting for Reports  Runtime
REPORTS60_PATH=/export/oracle/inms/reports6i; export REPORTS60_PATH
REPORTS60_TERMINAL=$ORACLE_HOME/reports60/admin/terminal/US; export REPORTS60_TERMINAL
REPORTS60_TMP=/tmp; export REPORTS60_TMP
REPORTS60_CLASSPATH=$ORACLE_HOME/network/jre11/lib/rt.jar:$ORACLE_HOME/reports60/java/myreports60.jar:$ORACLE_HOME/reports60/java/xmlparser.jar; export REPORTS60_CLASSPATH
REPORTS60_JNI_LIB=$ORACLE_HOME/network/jre11/lib/sparc/native_threads/libjava.so; export REPORTS60_JNI_LIB

REPORTS60_DEV2K=FALSE; export REPORTS60_DEV2K

## If REPORTS60_NO_DUMMY_PRINTER is set, no printer needs to be set up
## for Reports Server.
REPORTS60_NO_DUMMY_PRINTER=; export REPORTS60_NO_DUMMY_PRINTER

## setting for Graphics Runtime
GRAPHICS60_PATH=$ORACLE_HOME/tools/devdem60/demo/graphics:$ORACLE_HOME/tools/devdem60/demo/forms:$ORACLE_HOME/graphics60/admin/sql:$ORACLE_HOME/tools/devdem60/admin; export GRAPHICS60_PATH
SQLLIB_PATH=$ORACLE_HOME/tools/devdem60/demo/forms; export SQLLIB_PATH

## setting for Web Graphics
GRAPHICS_WEB_DIR=$ORACLE_HOME/tools/devdem60/demo/graphics; export GRAPHICS_WEB_DIR
OWS_IMG_DIR=$ORACLE_HOME/tools/devdem60/web; export OWS_IMG_DIR

## setting for Project Builder
ORACLE_AUTOREG=$ORACLE_HOME/guicommon6/tk60/admin/; export ORACLE_AUTOREG
