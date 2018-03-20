import subprocess
import glob
import os

"""
Taxonomic Classification Snakefile

This Snakefile defines tasks for the taxonomic
classification workflow.

Todo:
    - Incorporate OSF CLI tool
    - Move variables that won't change often into .settings files
    - Move rules into individual rule files
"""


# Need PWD for Docker
PWD = os.getcwd()


# Settings:
# --------------------

# Settings common to all 
# taxonomic classification workflows
include: 'taxclass.settings'


# Taxonomic Classification Rules:
# ------------------------------------

include: 'rules/pull_biocontainers.rule'
include: 'rules/sourmash_sbts.rule'
include: 'rules/download_trimmed_data.rule'
include: 'rules/calculate_signatures.rule'
include: 'rules/kaiju.rule'
include: 'rules/kaiju2krona.rule'
include: 'rules/filter_taxa.rule'
include: 'rules/visualize_krona.rule'

onsuccess:
    shell("rm -f .pulled_containers")
    shell("rm -f .trimmed")

