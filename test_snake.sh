#!/bin/bash

################################################
#                 VERIFIED

## pull_biocontainers
#snakemake .pulled_containers

## download sourmash sbts
#snakemake data/sourmash/microbe-genbank-sbt-k21-2017.05.09.tar.gz

## pretend download sourmash sbts went ok
#snakemake --cleanup-metadata data/sourmash/microbe-genbank-sbt-k21-2017.05.09.tar.gz

## unpack sourmash sbts
#snakemake data/sourmash/genbank-k21.sbt.json

## pretend unpack sourmash sbts went ok
#snakemake --cleanup-metadata data/sourmash/genbank-k21.sbt.json

## download trimmed data
#snakemake .trimmed

## pretend download trimmed data went ok
#snakemake --cleanup-metadata .trimmed

## calculate signatures
#snakemake --printshellcmds data/trimmed/SRR606249.trim2.scaled10k.k21_31_51.sig data/trimmed/SRR606249_merged.trim2.fq.gz

## pretend calc sigs went ok
#snakemake --cleanup-metadata data/trimmed/SRR606249.trim2.scaled10k.k21_31_51.sig data/trimmed/SRR606249_merged.trim2.fq.gz

################################################
#                 UNVERIFIED

# Note: symlinks in mounted directories do not work.

# Note: disorienting to jump into the pipeline in the middle. 
# what was prior step? (no way to "read" Snakefile.)

snakemake --printshellcmds data/kaijudb/{nodes.dmp,kaiju_db_nr_euk.fmi}
