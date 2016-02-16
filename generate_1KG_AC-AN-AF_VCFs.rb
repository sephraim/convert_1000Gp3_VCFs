#!/bin/env ruby

##
# Generate 1KG AC/AN/AF VCF files
#
# This will work for chr1-22/MT/X/Y VCFs and will create a VCF
# for each chromosome. bcftools is used to recalculate AC and AN 
# using a population-specific subset of samples. This script must
# be used for chrMT|X|Y because AN varies. However, for chr1-22
# it is much faster to use the pre-specified AN to calculate AC.
#
# This will generate a new file for each chromosome specified below.
#
# Example usage:
#   ./generate_1KG_AC-AN-AF_VCFs.rb
##

CHRS = ['MT', 'X', 'Y'] # <-- Change chromosomes if you want

POPS = ['ALL', 'AFR', 'AMR', 'EAS','EUR', 'SAS'] # ALL *must* come first in the list
F_PANEL = `ls integrated_call_samples_*.panel`.chomp
F_MALE_PANEL = `ls integrated_call_male_samples_*.panel`.chomp
F_SAMPLE_LIST = 'sub-population_samples.tmp'

# Create header
header  = "##fileformat=VCFv4.1\n"\
          "##fileDate=#{Time.now.strftime("%Y%m%d")}\n"\
          "##reference=ftp://ftp.1000genomes.ebi.ac.uk//vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz\n"\
          "##source=1000GenomesPhase3Pipeline\n"
CHRS.each do |chr|
  header += "##contig=<ID=#{chr},assembly=b37>\n"
end
header += "##INFO=<ID=1KG_ALL_AC,Number=A,Type=Integer,Description=\"Total number of alternate alleles in called genotypes\">\n"\
          "##INFO=<ID=1KG_ALL_AN,Number=1,Type=Integer,Description=\"Total number of alleles in called genotypes\">\n"\
          "##INFO=<ID=1KG_ALL_AF,Number=A,Type=Float,Description=\"Estimated allele frequency in ALL populations in the range (0,1)\">\n"
POPS.each do |pop|
  next if pop == 'ALL'
  header += "##INFO=<ID=1KG_#{pop}_AC,Number=A,Type=Float,Description=\"Number of alternate alleles in called genotypes in the #{pop} populations\">\n"\
            "##INFO=<ID=1KG_#{pop}_AN,Number=1,Type=Float,Description=\"Number of alleles in called genotypes in the #{pop} populations\">\n"\
            "##INFO=<ID=1KG_#{pop}_AF,Number=A,Type=Float,Description=\"Allele frequency in the #{pop} populations calculated from AC and AN, in the range (0,1)\">\n"
end
header += "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\n"

CHRS.each do |chr|
  f_input_vcf = `ls *.chr#{chr}.*.vcf.gz`.chomp
  f_output_vcf = "hg19_1KG.chr#{chr}.vcf"
  tmp_counts_files = []

  puts "Creating counts files..."
  POPS.each_with_index do |pop, i|
    tmp_counts_files << "counts.#{pop}.chr#{chr}.tmp"
    puts "- #{tmp_counts_files[i]}"

    if chr == 'MT'
      # Generate tmp counts file
      if pop == 'ALL'
        # Get sample list
        `cut -f1 #{F_PANEL} > #{F_SAMPLE_LIST}`

        # Recalculate AC/AN, and don't include CHROM, POS, REF and ALT
        `bcftools norm -m- -Ou #{f_input_vcf} \
           | bcftools view -G -S #{F_SAMPLE_LIST} --force-samples -Ou \
           | bcftools query -f '%CHROM\\t%POS\\t%ID\\t%REF\\t%ALT\\t.\\t.\\t%INFO/AC\\t%INFO/AN\\n' \
           | awk -F '\\t' -v OFS='\\t' '{print $1, $2, $3, $4, $5, $6, $7, "1KG_#{pop}_AC="$8";1KG_#{pop}_AN="$9";1KG_#{pop}_AF="$8/$9}' \
           > #{tmp_counts_files[i]}`
      else
        # Get sample list
        `grep '#{pop}' #{F_PANEL} | cut -f1 > #{F_SAMPLE_LIST}`

        # Recalculate AC/AN, and don't include CHROM, POS, REF and ALT
        `bcftools norm -m- -Ou #{f_input_vcf} \
           | bcftools view -G -S #{F_SAMPLE_LIST} --force-samples -Ou \
           | bcftools query -f '%INFO/AC\\t%INFO/AN\\n' \
           | awk -F '\\t' -v OFS='\\t' '{print "1KG_#{pop}_AC="$1";1KG_#{pop}_AN="$2";1KG_#{pop}_AF="$1/$2}' \
           > #{tmp_counts_files[i]}`
      end
    else
      # Generate tmp counts file
      if pop == 'ALL'
        # Don't recalculate AC/AN, and do include CHROM, POS, REF and ALT
        `bcftools query -f '%CHROM\\t%POS\\t%ID\\t%REF\\t%ALT\\t.\\t.\\t1KG_#{pop}_AC=%INFO/AC;1KG_#{pop}_AN=%INFO/AN;1KG_#{pop}_AF=%INFO/AF\\n' -o #{tmp_counts_files[i]} #{f_input_vcf}`
      else
        # Get sample list
        if chr == 'Y'
          # Male samples only
          `grep '#{pop}' #{F_MALE_PANEL} | cut -f1 > #{F_SAMPLE_LIST}`
        else
          # Male + female samples
          `grep '#{pop}' #{F_PANEL} | cut -f1 > #{F_SAMPLE_LIST}`
        end
  
        # Recalculate AC/AN, and don't include CHROM, POS, REF and ALT
        `bcftools view -G -S #{F_SAMPLE_LIST} -Ou #{f_input_vcf} \
           | bcftools query -f '1KG_#{pop}_AC=%INFO/AC;1KG_#{pop}_AN=%INFO/AN;1KG_#{pop}_AF=%INFO/#{pop}_AF\\n' -o #{tmp_counts_files[i]}`
      end
    end
  end

  # Combine counts files
  puts "Combining all counts files for chr#{chr} into #{f_output_vcf}..."
  File.open(f_output_vcf, 'w') { |f| f.write(header) }
  `paste -d';' #{tmp_counts_files.join(' ')} >> #{f_output_vcf}`

  # Remove tmp files
  puts "Removing tmp files for chr#{chr}..."
  tmp_counts_files.each { |f| File.delete(f) }

  puts "Done. Counts for chr#{chr} written to #{f_output_vcf}"

  puts "Compressing output into #{f_output_vcf}.gz..."
  `bcftools view -Oz -o #{f_output_vcf}.gz #{f_output_vcf}`
  puts "Done. Compressed output written to #{f_output_vcf}.gz"
  
  puts "Indexing #{f_output_vcf}.gz..."
  `bcftools index -ft #{f_output_vcf}.gz`
  puts "Done. Index written to #{f_output_vcf}.gz.tbi"

  puts "All done! Output files are:"
  puts "- #{f_output_vcf}"
  puts "- #{f_output_vcf}.gz"
  puts "- #{f_output_vcf}.gz.tbi"
end

File.delete(F_SAMPLE_LIST)
