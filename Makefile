# GECKO Build File
# James A. Overton <james@overton.ca>
#
# WARN: This file contains significant whitespace, i.e. tabs!
# Ensure that your text editor shows you those characters.

### Workflow
#
# 1. Edit the [GECKO template](https://docs.google.com/spreadsheets/d/1bYnbxvPPFO7D7zg9Tr2e32jb8l13kMZ81vP_iaSZCXg/edit#gid=0)
# 2. [Update files](update)
# 2. View files:
#     - [ROBOT report](build/report.html)
#     - [GECKO tree](build/gecko.html) ([gecko.owl](gecko.owl))
#     - [IHCC view tree](build/ihcc-gecko.html) ([ihcc-gecko.owl](views/ihcc-gecko.owl))

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
DATE = $(shell date +'%Y-%m-%d')
OBO = http://purl.obolibrary.org/obo

LICENSE = https://creativecommons.org/licenses/by/4.0/
DESCRIPTION = An ontology to represent genomics cohort attributes.
COMMENT = The GECKO is maintained by the CINECA project, https://www.cineca-project.eu, and standardises attributes commonly used for genomics cohort description as well as individual-level data items. A series of tools is being developed to enable automated generation of harmonised data files based on a JSON schema mapping file. For more information please contact info@cineca-project.eu
TITLE = Genomics Cohorts Knowledge Ontology

.PHONY: all
all: gecko.owl views/ihcc-gecko.owl build/gecko.html build/ihcc-gecko.html build/report.html

.PHONY: clean
clean:
	rm -rf build

.PHONY: update
update:
	rm -rf build/templates.xlsx
	make build/templates.xlsx
	make all

build:
	mkdir -p $@

build/robot.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/html-report/lastSuccessfulBuild/artifact/bin/robot.jar
#curl -L -o $@ https://github.com/ontodev/robot/releases/download/v1.6.0/robot.jar

build/robot-tree.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/tree-view/lastSuccessfulBuild/artifact/bin/robot.jar

### GECKO

build/templates.xlsx: | build
	curl -L -o $@ "https://docs.google.com/spreadsheets/d/1bYnbxvPPFO7D7zg9Tr2e32jb8l13kMZ81vP_iaSZCXg/export?format=xlsx"

src/ontology/templates/index.tsv src/ontology/templates/gecko.tsv src/ontology/templates/properties.tsv src/ontology/templates/external.tsv: build/templates.xlsx | build/robot.jar
	xlsx2csv -d tab -n $(basename $(notdir $@)) $< $@

build/properties.ttl: src/ontology/templates/properties.tsv | build/robot.jar
	$(ROBOT) template \
	--template $< \
	--output $@

gecko.owl: build/properties.ttl src/ontology/templates/index.tsv src/ontology/templates/gecko.tsv src/ontology/templates/external.tsv | build/robot.jar
	$(ROBOT) template \
	--input $< \
	--template $(word 2,$^) \
	--template $(word 3,$^) \
	--template $(word 4,$^) \
	--merge-before \
	annotate \
	--link-annotation dcterms:license $(LICENSE) \
	--annotation dc11:description "$(DESCRIPTION)" \
	--annotation dc11:title "$(TITLE)" \
	--annotation rdfs:comment "$(COMMENT)" \
	--ontology-iri $(OBO)/gecko.owl \
	--version-iri $(OBO)/gecko/$(DATE)/gecko.owl \
	--output $@

### IHCC Browser View

build/query_result.csv: gecko.owl src/get_ihcc_view.rq | build/robot.jar
	$(ROBOT) query \
	--input $< \
	--query $(word 2,$^) $@

build/ihcc_view_template.csv: src/ihcc_view.py build/query_result.csv
	python3 $^ $@

views/ihcc-gecko.owl: build/ihcc_view_template.csv | build/robot.jar
	$(ROBOT) template \
	--template $< \
	annotate \
	--ontology-iri $(OBO)/ihcc-gecko.owl \
	--version-iri $(OBO)/gecko/$(DATE)/ihcc-gecko.owl \
	--output $@


### Trees
#
# We use ROBOT's experimental tree branch to generate HTML tree views.

build/gecko.html: gecko.owl | build/robot-tree.jar
	java -jar build/robot-tree.jar tree \
	--input $< \
	--tree $@

build/ihcc-gecko.html: views/ihcc-gecko.owl | build/robot-tree.jar
	java -jar build/robot-tree.jar tree \
	--input $< \
	--tree $@


### Report
#
# We run ROBOT report to check for common mistakes.

.PRECIOUS: build/report.html
build/report.html: gecko.owl | build/robot.jar
	$(ROBOT) report \
	--input $< \
	--labels true \
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

