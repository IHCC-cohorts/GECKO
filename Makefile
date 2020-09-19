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

UNAME := $(shell uname)
ifeq ($(UNAME), Darwin)
	RDFTAB_URL := https://github.com/ontodev/rdftab.rs/releases/download/v0.1.1/rdftab-x86_64-apple-darwin
else
	RDFTAB_URL := https://github.com/ontodev/rdftab.rs/releases/download/v0.1.1/rdftab-x86_64-unknown-linux-musl
endif

.PHONY: all
all: gecko.owl views/ihcc-gecko.owl build/gecko.html build/ihcc-gecko.html build/report.html

.PHONY: clean
clean:
	rm -rf build

.PHONY: update
update: fetch_templates all

build:
	mkdir -p $@

build/imports: | build
	mkdir -p $@

build/robot.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/html-report/lastSuccessfulBuild/artifact/bin/robot.jar
#curl -L -o $@ https://github.com/ontodev/robot/releases/download/v1.6.0/robot.jar

build/robot-tree.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/tree-view/lastSuccessfulBuild/artifact/bin/robot.jar

build/rdftab: | build
	curl -L -o $@ $(RDFTAB_URL)
	chmod +x $@


### GECKO

TEMPLATE_NAMES := index gecko properties external

TEMPLATES := $(foreach T,$(TEMPLATE_NAMES),src/ontology/templates/$(T).tsv)

.PHONY: fetch_templates
fetch_templates: src/scripts/fix_tsv.py | build/robot.jar .cogs
	cogs fetch && cogs pull
	python3 $< $(TEMPLATES)

build/properties.ttl: src/ontology/templates/properties.tsv | build/robot.jar
	$(ROBOT) template \
	--template $< \
	--output $@

gecko.owl: build/properties.ttl src/ontology/templates/index.tsv src/ontology/templates/gecko.tsv src/ontology/templates/external.tsv src/ontology/annotations.owl | build/robot.jar
	$(ROBOT) template \
	--input $< \
	--template $(word 2,$^) \
	--template $(word 3,$^) \
	--template $(word 4,$^) \
	--merge-before \
	merge \
	--input $(word 5,$^) \
	annotate \
	--link-annotation dcterms:license $(LICENSE) \
	--annotation dc11:description "$(DESCRIPTION)" \
	--annotation dc11:title "$(TITLE)" \
	--annotation rdfs:comment "$(COMMENT)" \
	--ontology-iri $(OBO)/gecko.owl \
	--version-iri $(OBO)/gecko/releases/$(DATE)/gecko.owl \
	--output $@


### Imports

IMPORTS := bfo eupath go iao mf mondo obi ogms omrse pato pco pdro stato uberon # cmo 
IMPORT_MODS := $(foreach I,$(IMPORTS),build/imports/$(I).ttl)

UC = $(shell echo '$1' | tr '[:lower:]' '[:upper:]')

build/imports/%.owl: | build/imports
	curl -Lk -o $@ http://purl.obolibrary.org/obo/$(notdir $@)

build/imports/%.owl.gz: build/imports/%.owl
	gzip -f $<

build/imports/%.db: src/scripts/prefixes.sql | build/imports/%.owl.gz build/rdftab
	gunzip -f $(basename $@).owl.gz
	rm -rf $@
	sqlite3 $@ < $<
	./build/rdftab $@ < $(basename $@).owl
	gzip -f $(basename $@).owl

build/imports/%.txt: src/ontology/templates/index.tsv | build/imports
	awk -F '\t' '{print $$1}' $< | tail -n +3 | sed -n '/$(call UC,$(notdir $(basename $@))):/p' > $@

build/imports/%.ttl: build/imports/%.db build/imports/%.txt
	python3 -m gizmos.extract -d $< -T $(word 2,$^) -n > $@

src/ontology/annotations.owl: $(IMPORT_MODS) src/queries/fix_annotations.rq build/properties.ttl  | build/robot.jar
	$(ROBOT) merge \
	$(foreach I,$(IMPORT_MODS), --input $(I)) \
	remove \
	--term rdfs:label \
	query \
	--update src/queries/fix_annotations.rq \
	merge \
	--input build/properties.ttl \
	annotate \
	--ontology-iri "http://purl.obolibrary.org/obo/cob/$(notdir $@)" \
	--output $@


### IHCC Browser View

build/query_result.csv: gecko.owl src/queries/get_ihcc_view.rq | build/robot.jar
	$(ROBOT) query \
	--input $< \
	--query $(word 2,$^) $@

build/ihcc_view_template.csv: src/scripts/ihcc_view.py build/query_result.csv
	python3 $^ $@

build/ihcc_annotations.ttl: gecko.owl src/queries/build_ihcc_annotations.rq | build/robot.jar
	$(ROBOT) query --input $< --query $(word 2,$^) $@

views/ihcc-gecko.owl: build/ihcc_view_template.csv build/ihcc_annotations.ttl | build/robot.jar
	$(ROBOT) template \
	--template $< \
	merge \
	--input $(word 2,$^) \
	annotate \
	--ontology-iri $(OBO)/gecko/ihcc-gecko.owl \
	--version-iri $(OBO)/gecko/releases/$(DATE)/views/ihcc-gecko.owl \
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


### COGS Set Up

BRANCH := $(shell git branch --show-current)

init-cogs: .cogs

# required env var GOOGLE_CREDENTIALS
.cogs: | $(TEMPLATES)
	cogs init -u $(EMAIL) -t "GECKO $(BRANCH)" $(foreach T,$(TEMPLATES), && cogs add $(T) -r 2)
	cogs push
	cogs open

destroy-cogs: | .cogs
	cogs delete -f


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

