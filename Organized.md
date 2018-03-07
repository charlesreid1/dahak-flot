# How This Repo Is Organized

The dahak-flot repo contains Snakemake workflows, but it also contains scripting for infrastructure to support Snakemake workflows. For example, setting up a cloud network, allocating a monitoring node, submitting to an HPC batch queue system.

## Directory Structure

* `cloud/` - files for submitting cloud/cluster jobs to run Snakemake workflows

* `data/` - intermediate and final data files go into `data` dir
    * Subdirectories contain results from intermediate steps
    * Example: `data/sig` for signatures, `data/sbt` for SBTs

* `inputs/` - data that will not change (sequences, CSVs, adapters, etc.)

* `envs/` - conda environment descriptions

* `notebooks/` - Jupyter Notebooks

## Rules

* Rules/rule files should be atomic
* Also include default configuration values for each application
* Store in .rule files

As rules get more complex:
* Can organize rule files by application directory, or by associated subtask
* Rules and tasks are atomic
* Subtasks aggregate multiple rules together (to generate output file for specified subtask)
* Master task aggregates subtasks together

## Attribution

Hat tip to [@luiziber](https://github.com/luizirber) on the directory structure.

Hat tip to [snakemake-rules repo](https://github.com/percyfal/snakemake-rules) for example Snakefile rules and guiding principles.
