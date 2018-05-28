CLASSES=$(subst .java,.class,$(shell find *.java))

.PHONY: clean all

all: $(CLASSES)

%.class: %.java
	$(JAVAC) $<

clean:
	rm -f *.class