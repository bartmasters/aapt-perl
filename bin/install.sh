#!/bin/sh
# Quick little script to install modified VPSE html/
# css files.

VPSEPATH="/opt/InfoVista/PortalSE2"
TEMPPATH="/tmp"

mkdir $TEMPPATH/portalse
cp portalse.tar $TEMPPATH/portalse/

# First, back up the appropriate directories
cd $VPSEPATH/site

mkdir custpages-bak
mkdir images-bak
mkdir pages-bak
mkdir styles-bak

cp default.htm default.htm.bak

cd custpages-bak
cp ../custpages/* .
cd images-bak
cp ../images/* .
cd pages-bak
cp ../pages/* .
cd styles-bak
cp ../styles/* .

cd $TEMPPATH/portalse
tar xvf portalse.tar


# All done, so exit successfully
echo "All backed up ok"
exit 0
