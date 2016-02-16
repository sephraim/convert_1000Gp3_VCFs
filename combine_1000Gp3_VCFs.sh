#!/bin/bash -e

##
# Combine 1000Gp3 VCFs (for chr1-22)
#
# This script will
# - Combine all 1000 Genomes VCF files
# - Remove all tags from the INFO column
# - Replace all INFO tags with new AC, AN, and AF tags for each population
# - Drop all columns after the INFO column (including samples)
# - Produce a .vcf, .vcf.gz, and a .vcf.gz.tbi file
#
# This script is only used for chr1-22. The AC, AN, and AF need to be
# calculated on the fly (with bcftools) for chrX|Y|MT. See 
#
# Example usage:
#   ./combine_1000Gp3_VCFs.sh <OUTPUT_VCF>
#   ./combine_1000Gp3_VCFs.sh hg19_1KG.chr1-22.vcf
##

##
# Test mode
#
# Enabling test mode will perform a simple combination of
# VCF files just to make sure the script is working. This means
# only a small region from each VCF will be included in the final
# output.
#
# Test mode is automatically enabled if output VCF is named 'test.vcf'
# For example:
#   ./combine_1000Gp3_VCFs.sh test.vcf
##

# Set output file
out_file=$1

# Check output file name
if [ "$out_file" = "" ]; then
  echo "ERROR: Must supply output file name"
  echo "Example usage:"
  echo "  ./combine_1000Gp3_VCFs.sh output.vcf"
elif [ "$out_file" = "test.vcf" ]; then
  TEST_MODE=true
  echo "Test mode enabled"
elif [ -f "$out_file" ]; then
  echo "ERROR: $out_file already exists"
elif [ -f "$out_file.gz" ]; then
  echo "ERROR: $out_file will get compressed into $out_file.gz, which already exists"
else
  TEST_MODE=false
fi

chr1_vcf="$(ls *.chr1.*.vcf.gz)"
region=''

# Combine VCFs
echo "Concatentating VCFs into $out_file..."
for i in {1..22}
do
  cur_vcf="$(ls *.chr$i.*.vcf.gz)"
  echo "- Adding $cur_vcf..."

  # Only include test regions?
  if [ "$TEST_MODE" = true ]; then
    region="-r $i:1-100000"
  fi
  
  if [ "$cur_vcf" = "$chr1_vcf" ]; then
    # Initialize output file (using chr1 VCF)
    bcftools view -O v $region $cur_vcf \
    | ruby -an fill_AC_AN_AF.rb \
    > $out_file
  else
    # Add to output file (no header)
    bcftools view -H -O v $region $cur_vcf \
    | ruby -an fill_AC_AN_AF.rb \
    >> $out_file
  fi
done
echo "Done. All VCFs combined into $out_file"

echo "Compressing output into $out_file.gz..."
bcftools view -Oz -o "$out_file.gz" "$out_file"
echo "Done. Compressed file is $out_file.gz..."

echo "Indexing $out_file.gz..."
bcftools index -ft "$out_file.gz"
echo "Done. Index written to $out_file.gz.tbi"

echo "All done! Output files are:"
echo "- $out_file"
echo "- $out_file.gz"
echo "- $out_file.gz.tbi"
