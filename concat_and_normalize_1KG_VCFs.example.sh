#!/bin/bash

##
# Concatenate and Normalize 1KG VCFs
#
# This is an example script to show you can concatenate all
# your VCFs into one BCF, and then left-align and normalize
# the BCF.
#
# The GRCh37 FASTA file can be downloaded with the following command:
#   wget ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/human_g1k_v37.fasta.*
##
set -e

echo "Concatenating chr1-22|MT|X|Y VCFs..."
bcftools concat -Ob -o hg19_1000Gp3_Aug2015.bcf.gz \
  hg19_1000Gp3_Aug2015.chr1-22.vcf.gz \
  hg19_1000Gp3_Aug2015.chrMT.vcf.gz \
  hg19_1000Gp3_Aug2015.chrX.vcf.gz \
  hg19_1000Gp3_Aug2015.chrY.vcf.gz
echo "Done! Output written to hg19_1000Gp3_Aug2015.bcf.gz"

echo "Indexing hg19_1000Gp3_Aug2015.bcf.gz..."
bcftools index -fc hg19_1000Gp3_Aug2015.bcf.gz
echo "Done! Index written to hg19_1000Gp3_Aug2015.bcf.gz.csi"

echo "Left aligning and normalizing BCF..."
bcftools norm -m -any -f human_g1k_v37.fa -Ob -o hg19_1000Gp3_Aug2015.LA-norm.bcf.gz hg19_1000Gp3_Aug2015.bcf.gz
echo "Done! Output written to hg19_1000Gp3_Aug2015.MORL.LA-norm.bcf.gz"

echo "Indexing hg19_1000Gp3_Aug2015.LA-norm.bcf.gz..."
bcftools index -fc hg19_1000Gp3_Aug2015.LA-norm.bcf.gz
echo "Done! Index written to hg19_1000Gp3_Aug2015.LA-norm.bcf.gz.csi"
