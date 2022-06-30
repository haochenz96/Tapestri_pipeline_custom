rule step1_split_sc_bams:
    # scatter per sample, per cell
    input:
        CELLS_BAM = '{sample_name}/tap_pipeline_output/results/bam/{sample_name}.tube1.cells.bam',
    output:
        SC_BAM = "{sample_name}/1-sc_bams/{sample_name}_{cell_num_index}.bam",
        # sc_bai = expand('sc_bams/{sample_name}_{cell_barcode}.bai', cell_barcode = bars, sample_name = sample_name),
    params:
        cell_barcode = lambda wildcards: sample_barcode_maps[wildcards.sample_name][wildcards.cell_num_index],
    conda:
        "../envs/samtools.yaml"
    threads: lambda wildcards, attempt: 2**(attempt-1),
    resources: 
        mem_mb = lambda wildcards, attempt: attempt * 4000,
        time_min = lambda wildcards, attempt: attempt * 29,
    shell:
        # -- trial 1 --
        "samtools view -b -r {params.cell_barcode} {input.CELLS_BAM} > {output.SC_BAM} && "
        "samtools index {output.SC_BAM} "