# GECKO Build File
# James A. Overton <james@overton.ca>
#
# WARN: This file contains significant whitespace, i.e. tabs!
# Ensure that your text editor shows you those characters.

### Workflow
#
# 1. Edit [mapping table](https://docs.google.com/spreadsheets/d/1IRAv5gKADr329kx2rJnJgtpYYqUhZcwLutKke8Q48j4/edit)
# 2. [Update files](all)
# 2. View files:
#     - [ROBOT report](build/report.html)
#     - [Core tree](build/gecko.html) ([gecko.owl](build/gecko.owl))
#     - [Full tree](build/gecko-full.html) ([gecko.owl](build/gecko-full.owl))

### Configuration
#
# These are standard options to make Make sane:
# <http://clarkgrubb.com/makefile-style-guide#toc2>

MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:
.SECONDARY:

ROBOT = java -jar build/robot.jar --prefixes src/prefixes.json
IMPORT_IDS := BFO CHEBI CL CMO DOID EFO GO HP NCIT NCBITaxon MMO OBI OGMS PR UBERON
IMPORT_IDS_LOWER := $(foreach o, $(IMPORT_IDS), $(shell echo $(o) | tr '[:upper:]' '[:lower:]'))
IMPORT_OWLS := $(foreach o, $(IMPORT_IDS_LOWER), src/ontology/imports/$(o).owl)

.PHONY: all
all: build/gecko.html build/gecko-full.html build/report.html

.PHONY: update
update:
	#rm -rf build/intermediate build/*.owl build/*.html
	#rm -rf build/templates.xslx src/ontology/templates/* src/ontology/modules/*
	#rm -rf build/gecko-mapping.xlsx
	make all



build build/imports build/intermediate:
	mkdir -p $@

build/robot.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/html-report/lastSuccessfulBuild/artifact/bin/robot.jar
#curl -L -o $@ https://github.com/ontodev/robot/releases/download/v1.6.0/robot.jar

build/robot-tree.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/tree-view/lastSuccessfulBuild/artifact/bin/robot.jar


### Tables
#
# Many of our terms are specified in two Google Sheets.
# We use ROBOT to turn them into OWL.

build/templates.xlsx: | build
	curl -L -o $@ "https://docs.google.com/spreadsheets/d/1FwYYlJPzFAAItZyaKY2YnP01yQw6BkARq3CPifQSx1A/export?format=xlsx"

build/gecko-mapping.xlsx: | build
	curl -L -o $@ "https://docs.google.com/spreadsheets/d/1IRAv5gKADr329kx2rJnJgtpYYqUhZcwLutKke8Q48j4/export?format=xlsx"

src/ontology/templates/gecko.tsv: build/templates.xlsx
	xlsx2csv -d tab -n $(basename $(notdir $@)) $< $@

src/ontology/templates/index.tsv: build/gecko-mapping.xlsx
	xlsx2csv -d tab -n index $< $@

src/ontology/templates/properties.tsv: build/gecko-mapping.xlsx
	xlsx2csv -d tab -n properties $< $@

build/intermediate/properties.owl: src/ontology/templates/properties.tsv | build/intermediate build/robot.jar
	$(ROBOT) template --template $< --output $@


### Imports
#
# We look for external terms in src/ontology/templates/index.tsv,
# download their OWL files,
# use ROBOT to filter for just the terms we need,
# then save the results to src/ontology/imports/.
#
# WARN: Unforunately some of the source ontologies are large.
# Extracting a few terms from them still requires loading the full ontology,
# which requires a lot of memory.
#
# TODO: It would be better to use dated versions of these imports.

build/imports/efo.owl.gz: | build/imports
	curl -L https://www.ebi.ac.uk/ols/ontologies/efo/download | gzip > $@

build/imports/%.owl.gz: | build/imports
	curl -L http://purl.obolibrary.org/obo/$*.owl | gzip > $@

build/imports/%.txt: src/ontology/templates/index.tsv | build/imports
	cut -f1 $< \
	| sed /^$*:/!d \
	> $@

src/ontology/imports/%.owl: build/imports/%.owl.gz build/imports/%.txt | build/robot.jar
	java -Xmx16g -jar build/robot.jar --prefixes src/prefixes.json filter \
	--input $< \
	--term-file $(word 2,$^) \
	--select annotations \
	--output $@

# We automatically build a catalog file from the imports
src/ontology/catalog-v001.xml: src/ontology/gecko-edit.ttl
	echo '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' > $@
	echo '<catalog prefer="public" xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">' >> $@
	echo '  <uri name="http://purl.obolibrary.org/obo/gecko/gecko-edit.owl" uri="gecko-edit.owl"/>' >> $@
	$(foreach o, $(IMPORT_IDS_LOWER), echo '<uri name="http://purl.obolibrary.org/obo/gecko/imports/$(o).owl" uri="imports/$(o).owl"/>' >> $@;)
	echo '</catalog>' >> $@


### GECKO Tasks - to be moved into separate repo

# GECKO does not have an xref template
build/gecko.owl: build/intermediate/properties.owl src/ontology/templates/gecko.tsv src/ontology/gecko-edit.ttl src/ontology/catalog-v001.xml $(IMPORT_OWLS) | build/robot.jar
	$(ROBOT) template --input $< \
	--merge-before \
	--template $(word 2,$^) \
	merge \
	--input $(word 3,$^) \
	--include-annotations true \
	annotate \
	--ontology-iri "http://purl.obolibrary.org/obo/gecko.owl" \
	--version-iri "http://purl.obolibrary.org/obo/gecko/$(shell date +'%Y-%m-%d').owl" \
	--output $@

# GECKO plus OBO terms
build/intermediate/index.owl: src/ontology/templates/properties.tsv src/ontology/templates/index.tsv | build/intermediate build/robot.jar
	$(ROBOT) template --template $< \
	template --merge-before \
	--template $(word 2,$^) \
	--output $@

build/gecko-full.owl: build/gecko.owl build/intermediate/index.owl | build/robot.jar
	$(ROBOT) merge --input $< \
	--input $(word 2,$^) \
	reason reduce \
	--output $@


### Trees
#
# We use ROBOT's experimental tree branch to generate HTML tree views.

build/%.html: build/%.owl | build/robot-tree.jar
	java -jar build/robot-tree.jar tree \
	--input $< \
	--tree $@


### Report
#
# We run ROBOT report to check for common mistakes.

.PRECIOUS: build/report.html
build/report.html: build/gecko-full.owl | build/robot.jar
	$(ROBOT) report \
	--input $< \
	--labels true \
	--print 20 \
	--format HTML \
	--standalone true \
	--fail-on none \
	--output $@


# NCIT Module - NCIT terms that have been mapped to GECKO terms

#.PRECIOUS: build/ncit.owl.gz
#build/ncit.owl.gz: | build
#	curl -L http://purl.obolbrary.org/obo/ncit.owl | gzip > $@

#build/ncit-terms.txt: build/gecko.owl src/gecko/get-ncit-ids.rq src/gecko/ncit-annotation-properites.txt | build/robot.jar
#	$(ROBOT) query --input $< --query $(word 2,$^) $@
#	tail -n +2 $@ > $@.tmp
#	cat $@.tmp $(word 3,$^) > $@ && rm $@.tmp

#build/ncit-module.owl: build/ncit.owl.gz build/ncit-terms.txt | build/robot-rdfxml.jar
#	$(ROBOT_RDFXML) extract --input $< \
#	--term-file $(word 2,$^) \
#	--method rdfxml \
#	--intermediates minimal --output $@

