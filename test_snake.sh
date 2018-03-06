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

################################################
#                 UNVERIFIED

# calculate signatures
snakemake --printshellcmds data/trimmed/SRR606249.trim2.scaled10k.k21_31_51.sig data/trimmed/SRR606249_merged.trim2.fq.gz



