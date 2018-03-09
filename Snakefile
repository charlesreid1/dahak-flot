import subprocess
import glob
import os
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider
HTTP = HTTPRemoteProvider()


"""
Taxonomic Classification Snakefile

This Snakefile defines tasks for the taxonomic
classification workflow.


Todo:
    - Incorporate OSF CLI tool
    - Move variables that won't change often into .settings files
    - Move rules into individual rule files


Notes: 

We define a block of variables before each rule that 
specify input/output files and any parameters for the 
commands. This makes it easy to change hard-coded 
variables into config params from a .settings file.

Dealing with directories, filenames, and wildcards is awkward but doable.
(Snakemake wants relative paths, Docker wants absolute paths,
 brackets aren't evaluated if they're in strings but they are if they're
 hard-coded in the rules, etc.)

Snakemake is designed for things to be hard-coded.
If you don't follow the Snakemake model, life is difficult.
"""


# Need PWD for Docker
PWD = os.getcwd()


# User-specific settings 
include: 'user.settings'

# Settings common to all 
# taxonomic classification workflows
include: 'taxclass.settings'


# Rules:
# ------------

include: 'rules/pull_biocontainers.rule'
include: 'rules/sourmash_sbts.rule'
include: 'rules/download_trimmed_data.rule'
include: 'rules/calculate_signatures.rule'
include: 'rules/kaiju.rule'
include: 'rules/kaiju2krona.rule'
include: 'rules/filter_taxa.rule'
include: 'rules/visualize_krona.rule'



# NOTE:
#
# Snakefiles are difficult to test because 
# using wildcards to match rules makes it unclear what
# files *are* available or not.
# 
# Example: we have a "databases" wild card, but this 
# Snakefile contains no information about what values
# for "databases" would actually be valid.
#
# In some cases, we don't have a list of acceptable vaules.
# But we ought to be able to distinguish between wildcards
# the user *actually* wants to set arbitrarily, and wildcards
# that can only take on a set number of values, 
# furthermore values the user may not know.
#
# We also have problems with prefix directories being 
# matched in wildcards, so we can't put data in its
# own directory without more acrobatics.

### rule cleanreally:
###     """
###     This nukes everything - all that hard work! Be careful.
###     """
###     shell:
###         '''
###         '''

## NOTE: Add this back in once we're finished testing.
#onsuccess:
#    shell("rm -f .pulled_containers")
#    shell("rm -f .trimmed")

