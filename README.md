<img src="https://user-images.githubusercontent.com/2214135/104771331-09f2f780-576a-11eb-870b-501ee23d4a3e.png" height="150">

# Genomics Cohorts Knowledge Ontology

**NOTE:** This is work in progress.

An ontology to represent genomics cohort attributes. The GECKO is maintained by the CINECA project, https://www.cineca-project.eu, and standardises attributes commonly used for genomics cohort description as well as individual-level data items. A series of tools is being developed to enable automated generation of harmonised data files based on a JSON schema mapping file. For more information please contact info@cineca-project.eu

GECKO currently has two products:
* `gecko.owl`: the OBO version of GECKO
* `views/ihcc-gecko.owl`: a view developed for [International HundredK+ Cohorts Consortium](https://ihccglobal.org/)

While the OBO view of GECKO conforms to OBO priniciples and reuses classes from upper-level ontologies such as [BFO](http://purl.obolibrary.org/obo/bfo.owl), the IHCC view rearranges the core GECKO terms (including some imported, lower-level terms) and groups them into 5 categories. The labels in the IHCC view are not the `rdfs:label` from the OBO version, but come from the "IHCC browser label" annotation property.

![IHCC GECKO View](https://github.com/IHCC-cohorts/GECKO/blob/master/views/ihcc-gecko.jpg)

## &copy; 2020 EMBL-EBI

Distributed under the [Creative Commons Attribution 4.0 International (CC BY 4.0) License](https://creativecommons.org/licenses/by/4.0/).
