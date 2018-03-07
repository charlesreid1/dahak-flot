#!/bin/bash

eval "$(pyenv init -)"

conda env create --name snakemake --file envs/basic.yml

source activate snakemake
