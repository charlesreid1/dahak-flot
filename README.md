# dahak-flot

This repository contains files for Snakemake workflows for dahak.

(*flot* is French for flow.)

You should start with a version of `conda` installed.

See [snakemake-rules repo](https://github.com/percyfal/snakemake-rules) 
for example Snakefile rules and guiding principles.

## Quick Start: Taxonomic Classification

(Example target file? Test?)

## Getting Started

This document walks you through running Snakemake workflows:

[GettingStarted.md](/GettingStarted.md)

## General Notes: How This Repo Is Organized

This document covers how Snakemake rules and files are organized:

[Organized.md](/Organized.md)

## Customizing

Snakemake rules can use their own conda environments.
To do this, add your conda environmnent .yml to the `envs/` directory.

To add or modify the rules, determine the name of the step
you wish to modify, and find it in the `rules/` directory.

To view or modify the file containing taxonomic classification workflow settings, 
edit `taxclass.settings`.

To define your own settings for Snakemake to use, see `user.settings`.

