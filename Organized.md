# How This Repo Is Organized

Hat tip to [@luiziber](https://github.com/luizirber) on the directory structure.

Hat tip to [snakemake-rules repo](https://github.com/percyfal/snakemake-rules) for example Snakefile rules and guiding principles.

## Directory Structure

* `inputs/` - data that will not change (sequences, CSVs, adapters, etc.)
* `envs/` - conda environment descriptions
* `data/` - intermediate and final data files go into `data` dir
    * Subdirectories contain results from intermediate steps
    * Example: `data/sig` for signatures, `data/sbt` for SBTs
* `cloud/` - files for submitting cloud/cluster jobs to run Snakemake workflows
* `notebooks/` - Jupyter Notebooks

## Organizing Rules

We follow the recommendations of the
[snakemake-rules repo](https://github.com/percyfal/snakemake-rules):

> Rules are organized by application directories. Each directory contains a 
> settings file, that initializes global configuration variables, and to 
> define default configuration values applicable to all rules for the given 
> application. The actual application rules are stored one rule per file with 
> suffix .rule. 

## Principles

* **One Subtask, One Subdirectory**: subtasks are organized into their own directories. 
    One subtask is usually completed with one application (e.g., download tarball).

* **Atomic Tasks**: Each subtask consists of a few atomic tasks (Example: simple algebra operations).

* **Aggregation**: Each subtask aggregates the results of the atomic tasks (Example: taking sum or product).
    The final master task aggregates the results of each subtask.





