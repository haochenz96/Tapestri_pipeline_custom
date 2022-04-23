rule write_h5:
    # write SNV and CNV matrices.
    input:
        # output_vcf = "{sample_name}/bcf_pass2/{sample_name}-f_q_intersected.vcf.gz",
        # output_vcf_stats = "{sample_name}/bcf_pass2/{sample_name}-f_q_intersected.vcf.gz.stats",
        output_vcf = "{sample_name}/4-bcf_genotyping/combined_vcf/{sample_name}-combined_VCF.filtered.vcf.gz",
        output_vcf_stats = "{sample_name}/4-bcf_genotyping/combined_vcf/{sample_name}-combined_VCF.filtered.vcf.gz.stats",
        # the stat file ensures that the merging step finishes
        read_counts_tsv = "{sample_name}/tap_pipeline_output/results/tsv/{sample_name}.tube1.barcode.cell.distribution.tsv",
    output:
        output_h5 = "{sample_name}/OUTPUTS_from_mpileup/{sample_name}_DNA_CNV.h5",
    params:
        metadata_json = json.dumps({
            "sample_name": "{sample_name}",
            "genome_version": config['reference_info']['genome_version'],
            "panel_version": config['reference_info']['panel_version'],
            "filterm2_ops": config['mutect2']['filterm2_ops'],
            "bcftools_pass1_sc_vcf_filters": config['bcftools']['pass1_sc_vcf_filters'],
            "bcftools_pass1_merged_vcf_filters": config['bcftools']['pass1_merged_vcf_filters'],
            "bcftools_pass2_sc_vcf_filters": config['bcftools']['pass2_sc_vcf_filters'],
        }),
    conda:
        "../envs/mosaic.yaml"
    threads: 4
    resources:
        mem_mb = lambda wildcards, attempt: attempt * 2000,
        time_min = 59
    script:
        "../scripts/write_h5.py"