# dahak-flot

Snakemake workflows for dahak. (*flot* is French for flow.)

This repo assumes you have a version of `conda` installed.

## Before You Begin

If you don't already have snakemake installed, 
start by installing pyenv, and use pyenv to install conda.
The steps below will cover how to install snakemake.
(Also see [install_pyenv.py](https://github.com/charlesreid1/dahak-yeti/blob/master/scripts/install_pyenv.py) 
and [install_snakemake.py](https://github.com/charlesreid1/dahak-yeti/blob/master/scripts/install_snakemake.py)
scripts in [dahak-yeti](https://github.com/charlesreid1/dahak-yeti)).

## Install Snakemake in Conda Environment

Create conda env:

```
conda env create --name snakemake --file environment.yaml
```

Activate conda env:

```
source activate snakemake
```

The file `environment.yaml` should contain, at minimum:

```
channels:
  - conda-forge
  - bioconda
  - r
  - defaults
dependencies:
  - graphviz=2.38.0
  - python=3.5.1
  - snakemake=3.11.0
  - pyyaml=3.11
```

## Running

To run snakemake rules, use the snakemake command.
Give it an output file, or a rule name:

```
snakemake file.out
```

The default name used is Snakefile. To specify a different snakefile,
use the -s flag:

```
snakemake -s mysnakefile file.out
```

## How This Repo Is Organized

The repository follows the 
[snakemake examples](https://percyfal.github.io/snakemake-rules/docs/configuration.html):
of [@percyfal](https://github.com/percyfal):

> Rules are organized by application directories. Each directory contains a 
> settings file, that initializes global configuration variables, and to 
> define default configuration values applicable to all rules for the given 
> application. The actual application rules are stored one rule per file with 
> suffix .rule. 

Here is how we interpret that statement for the taxonomic classification workflow
Snakefile:

* **One Subtask, One Subdirectory**: subtasks are organized into their own directories. 
    This roughly maps to applications - one subtask is usually completed with one application.
    (Example: downloading a tarball.)

* **Atomic Tasks**: Each subtask consists of a few atomic tasks (simple algebra operations).
    * The atomic tasks are carried out.
    * The subtask aggregates these into a final result.
    * This makes workflows more flexible and modular.

* **Aggregation**: Each subtask aggregates the results of the atomic tasks (e.g., a sum or product).
    Likewise, the final master task aggregates the results of each subtask.

## What's In Each Subtask Directory

Each subtask directory contains the following:

* **Subtask Snakemake Rules**: a Snakemake rule file 
    that defines a master rule for that subtask and specifies what that subtask does.

* **Snakemake Configuration Files**: a Snakemake config file
    that defines defaults (which the user can change). If there are multiple rules,
    rules specific to a rule file can also be defined in that file.
