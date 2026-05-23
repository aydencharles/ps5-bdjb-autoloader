JAR_NAME := poops.jar

MAKEFILE_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
BDJSDK_HOME  ?= $(MAKEFILE_DIR)/../../../../
JAVA8_HOME   ?= $(BDJSDK_HOME)/host/jdk8
JAVA11_HOME  ?= $(BDJSDK_HOME)/host/jdk11
JAVAC        := $(JAVA8_HOME)/bin/javac
JAR          := $(JAVA8_HOME)/bin/jar

export JAVA8_HOME
export JAVA11_HOME

CLASSPATH     := $(BDJSDK_HOME)/target/lib/enhanced-stubs.zip:$(BDJSDK_HOME)/target/lib/bdjstack.jar:$(BDJSDK_HOME)/target/lib/rt.jar:../../discdir/BDMV/JAR/00000.jar
SOURCES       := $(filter-out src/org/bdj/external/BinaryPaths.java, $(wildcard src/org/bdj/external/*.java)) src/org/bdj/external/BinaryPaths.java
JFLAGS        := -Xlint:-options -source 1.4 -target 1.4

all: $(JAR_NAME)

src/org/bdj/external/BinaryPaths.java:
	@KEXP_FILE=$$(basename $$(ls src/org/bdj/external/kexp-*.bin 2>/dev/null | head -n 1)); \
	ELFLDR_FILE=$$(basename $$(ls src/org/bdj/external/elfldr-*.elf 2>/dev/null | head -n 1)); \
	if [ -z "$$KEXP_FILE" ]; then echo "Error: kexp binary not found in src/org/bdj/external/" >&2; exit 1; fi; \
	if [ -z "$$ELFLDR_FILE" ]; then echo "Error: elfldr binary not found in src/org/bdj/external/" >&2; exit 1; fi; \
	echo "package org.bdj.external;" > $@; \
	echo "public class BinaryPaths {" >> $@; \
	echo "    public static final String BIN_PATH = \"/org/bdj/external/$$KEXP_FILE\";" >> $@; \
	echo "    public static final String ELFLDR_PATH = \"/org/bdj/external/$$ELFLDR_FILE\";" >> $@; \
	echo "}" >> $@

# Create JAR with manifest
$(JAR_NAME): $(SOURCES) manifest.txt
	$(JAVAC) $(JFLAGS) -cp $(CLASSPATH) $(SOURCES)
	$(JAR) cfm $@ manifest.txt -C src/ org/bdj/external

clean:
	rm -f src/org/bdj/api/*.class src/org/bdj/*.class src/org/bdj/external/*.class $(JAR_NAME) src/org/bdj/external/BinaryPaths.java

