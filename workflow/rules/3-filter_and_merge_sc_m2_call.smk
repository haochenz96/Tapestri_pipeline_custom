rule step3_bcftools_filter_and_merge_sc_m2_vcfs:
    # scatter by sample
    # for each single cell VCF, split multiallelic sites, hard filter (v3) and index; 
    input:
        sc_m2_vcfs_filter_added = get_step2_m2_vcfs_by_sample,
    output:
        merged_prev_filtered_vcf = "{sample_name}/3-bcf_filter/combined_vcf/{sample_name}-combined_VCF_filter_v3.prev_filtered.vcf.gz",
        merged_prev_filtered_vcf_stats = "{sample_name}/3-bcf_filter/combined_vcf/{sample_name}-combined_VCF_filter_v3.prev_filtered.vcf.gz.stats",
    params:
        # @HZ 04/01/2022
        # need to add quotation marks around these filters in the shell command, because snakemake will input these params.X as string without quotation marks
        sc_vcf_filters = parse_bcf_filters(config['bcftools']['pass1_sc_vcf_filters']),
        merged_vcf_filters = parse_bcf_filters(config['bcftools']['pass1_merged_vcf_filters']), 
    conda:
        "../envs/bcftools.yaml"
    threads: lambda wildcards, attempt: attempt * 4,
    resources:
        mem_mb = lambda wildcards, attempt: attempt * 2000,
        time_min = lambda wildcards, attempt: attempt * 119,
    log: 
        "{sample_name}/logs/{sample_name}.snakemake_progress.log"
    shell:
        """
        echo "----------" >> {log}
        echo "[`date`]" >> {log}
        echo "[INFO] [STEP2] finished sc_mutect2_call for sample {wildcards.sample_name}" >> {log}

        # @part1
        mkdir -p {wildcards.sample_name}/3-bcf_filter/filtered_vcfs
        for sc_m2_vcf in {input.sc_m2_vcfs_filter_added}; do 
            
            out_name=$(basename ${{sc_m2_vcf}})

            bcftools norm -m- ${{sc_m2_vcf}} | \
            bcftools filter -i '{params.sc_vcf_filters}' | \
            bgzip -c > \
            {wildcards.sample_name}/3-bcf_filter/filtered_vcfs/${{out_name/somatic_m2_filter_added.vcf.gz/hard_filtered.vcf.gz}}

            tabix {wildcards.sample_name}/3-bcf_filter/filtered_vcfs/${{out_name/somatic_m2_filter_added.vcf.gz/hard_filtered.vcf.gz}}
            echo cell -- ${{out_name}} -- norm, filter, zip, index done
        done

        # @part2
        bcftools merge --merge none $(find {wildcards.sample_name}/3-bcf_filter/filtered_vcfs -name '*hard_filtered.vcf.gz') | \
        bcftools sort | \
        bcftools filter -i '{params.merged_vcf_filters}' | \
        bgzip -c > \
        {output.merged_prev_filtered_vcf}

        tabix {output.merged_prev_filtered_vcf}

        bcftools stats {output.merged_prev_filtered_vcf} > {output.merged_prev_filtered_vcf_stats} && \
         echo "[INFO] [STEP3] finished filtering and merging single-cell mutect2(pass1) VCFs sample {wildcards.sample_name}" >> {log}
        """