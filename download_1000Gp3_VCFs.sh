#!/bin/bash

# Download panel file, all VCFs, and all indexes from the 1000 Genomes FTP server

wget -A "*.genotypes.vcf.gz*,*.panel" -R "*_male_*" ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/*
