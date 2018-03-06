# Getting Started with Dahak Flot

This document walks you through running Snakemake workflows.

## Before You Begin

If you don't already have snakemake installed, 
start by installing pyenv, and use pyenv to install conda.
The steps below will cover how to install snakemake.
(Also see [install_pyenv.py](https://github.com/charlesreid1/dahak-yeti/blob/master/scripts/install_pyenv.py) 
and [install_snakemake.py](https://github.com/charlesreid1/dahak-yeti/blob/master/scripts/install_snakemake.py)
scripts in [dahak-yeti](https://github.com/charlesreid1/dahak-yeti)).

If you are using the preferred method of managing conda
using pyenv, you should put the pyenv conda on your path
before running any of the commands below:

```
eval "$(pyenv init -)"
```

## Install Snakemake in Conda Environment

Create conda env:

```
conda env create --name snakemake --file envs/basic.yml
```

The file `environment.yml` should contain, at minimum:

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

Activate conda env:

```
source activate snakemake
```

## Running Snakemake Rules

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

