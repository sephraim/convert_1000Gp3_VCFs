#!/usr/bin/ruby -an

##
# Fill AC-AN-AF
#
# This is a helper script for combine_1000Gp3_VCFs.sh.
# It will fill in the INFO field with AC, AN, and AF for
# each population.
##

class String
  ##
  # Get VCF Field
  #
  # Example:
  #   vcf_row.get_vcf_field('CLINVAR_PATHOGENICITY')
  #   vcf_row.get_vcf_field(/CURATED_DISEASE[Ss]/i)
  #
  # @param [String/Regexp] tag Name of the INFO tag
  ##
  def get_vcf_field(tag)
    if !tag.is_a? Regexp
      tag = Regexp.escape(tag)
    end 
    return self.scan(/(?:^|[\t;])#{tag}=([^;\t]*)/).flatten[0].to_s
  end 
end

BEGIN {
  # Input/output field separators
  $; = "\t"
  $, = "\t"

  # Panel file with all samples
  F_PANEL = `ls integrated_call_samples_*.panel`.chomp

  # Set all 1KG super-populations and their AN
  POPS = {
    'AFR' => `grep AFR #{F_PANEL}`.lines.count*2,
    'AMR' => `grep AMR #{F_PANEL}`.lines.count*2,
    'EAS' => `grep EAS #{F_PANEL}`.lines.count*2,
    'EUR' => `grep EUR #{F_PANEL}`.lines.count*2,
    'SAS' => `grep SAS #{F_PANEL}`.lines.count*2,
  }
}

if $_.start_with?('##') && !$_.start_with?('##INFO=', '##FILTER=', '##FORMAT=', '##bcftools')
  # Print meta-info (without INFO tags)
  puts $_
elsif $_.start_with?('#CHROM')
  # Print new INFO tags
  puts '##INFO=<ID=1KG_ALL_AC,Number=A,Type=Integer,Description="Total number of alternate alleles in called genotypes">'
  puts '##INFO=<ID=1KG_ALL_AN,Number=1,Type=Integer,Description="Total number of alleles in called genotypes">'
  puts '##INFO=<ID=1KG_ALL_AF,Number=A,Type=Float,Description="Estimated allele frequency in ALL populations in the range (0,1)">'
  POPS.each do |pop, info_AN|
    puts "##INFO=<ID=1KG_#{pop}_AC,Number=A,Type=Float,Description=\"Number of alternate alleles in called genotypes in the #{pop} populations\">"
    puts "##INFO=<ID=1KG_#{pop}_AN,Number=1,Type=Float,Description=\"Number of alleles in called genotypes in the #{pop} populations\">"
    puts "##INFO=<ID=1KG_#{pop}_AF,Number=A,Type=Float,Description=\"Allele frequency in the #{pop} populations calculated from AC and AN, in the range (0,1)\">"
  end
  
  # Print header (up thru INFO column)
  puts $F[0..7].join($,)
elsif !$_.match(/^[12XY]/).nil?
  info = $F[7]

  # Set AC, AN, and AF for each super-population
  # Build new INFO column
  new_info = []
  new_info << "1KG_ALL_AC=#{info.get_vcf_field('AC')}"
  new_info << "1KG_ALL_AN=#{info.get_vcf_field('AN')}"
  new_info << "1KG_ALL_AF=#{info.get_vcf_field('AF')}"

  # Set AC, AN, and AF for each super-population (chromosomes 1-22 only)
  if !$_.match(/^[12]/).nil?
    POPS.each do |pop, info_AN| 
      # Get AFs
      info_AFs = info.get_vcf_field("#{pop}_AF").split(',')
    
      # Calculate ACs
      info_ACs = []
      info_AFs.each do |af|
        if af == '.'
          info_ACs << '.'
        else
          info_ACs << (info_AN.to_i*af.to_f).round
        end
      end
    
      # Update new INFO column
      new_info << "1KG_#{pop}_AC=#{info_ACs.join(',')}"
      new_info << "1KG_#{pop}_AN=#{info_AN}"
      new_info << "1KG_#{pop}_AF=#{info_AFs.join(',')}"
    end
  end

  # Print updated records
  puts [$F[0..4], '.', '.', new_info.join(';')].flatten.join($,)
elsif !$_.match(/^M/).nil?
  puts [$F[0..4], '.', '.', '.'].flatten.join($,)
end
