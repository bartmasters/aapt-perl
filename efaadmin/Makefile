###
# A fairly generic Java project Makefile
#	Requires:	GNU make, Java and tools in $PATH
#	Version:	$Id: Makefile,v 1.1.1.1 2004/12/06 01:23:24 alany Exp $
#	Author:		Alan Yates <alan.yates@aapt.com.au>
###

###
# Determine packages, environment, etc.
###
PACKAGES=$(subst src/,,$(dir $(shell find src -name Makefile)))
CLASSPATH=$(shell find `pwd`/lib -name \*.jar | tr '\n' ':')$(shell pwd)/src

###
# Java tools
###
JAR=jar
JAVA=java
JAVAC=javac

###
# Export build environment to sub-Makefiles in package directories
###
export JAVAC		# Java compiler
export CLASSPATH	# used by $(JAVAC) to resolve classes (lib/*.jar and src/ class tree)

###
# JAR to build, Main-Class and Class-Path for its manifest
###
JARNAME=efaReportGenerator.jar
MAINCLASS=au.com.aapt.efa.ReportGenerator
MANIFEST_CLASSPATH=$(shell find lib -name \*.jar | tr '\n' ' ')



.PHONY: $(PACKAGES) $(JARNAME) all test clean

# default target
all: $(JARNAME)

$(PACKAGES):
	$(MAKE) -C src/$@

$(JARNAME): $(PACKAGES)
	echo "Main-Class: $(MAINCLASS)" > manifest
	echo "Class-Path: $(MANIFEST_CLASSPATH)" >> manifest
	cd src && $(JAR) c0fm ../$(JARNAME) ../manifest `find . -name \*.class`
	rm manifest

test: $(JARNAME)
	$(JAVA) -jar $(JARNAME) $(ARGS)

clean:
	for dir in $(PACKAGES) ; do \
		$(MAKE) -C src/$$dir clean; \
	done
	rm -f $(JARNAME)
