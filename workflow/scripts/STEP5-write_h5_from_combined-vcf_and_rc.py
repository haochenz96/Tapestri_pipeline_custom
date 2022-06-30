# in the default mosaic conda environment
# from missionbio.h5.create import create_cnv_assay, create_dna_assay
# from missionbio.h5.data import H5Writer
# from missionbio.h5.constants import BARCODE, CHROM, ID, POS
# import missionbio.mosaic.io as mio
# import missionbio.mosaic.utils

# in the mosaic-custom conda environment
from h5.create import create_cnv_assay, create_dna_assay
from h5.data import H5Writer
from h5.constants import BARCODE, CHROM, ID, POS
import mosaic.io as mio
import mosaic.utils

import allel
import pandas as pd
import numpy as np
import click
import json
import os
import logging
import sys
from datetime import datetime
import pytz as tz

###############################
# part 0 ----- parse inputs
###############################

# @click.option('--sample_name', required=True, type=str)
# @click.option('--metadata', required=True, type=str)
# @click.option('--all_cell_vcf', required=True, type=str)
# @click.option('--amplicon_file', required=True, type=str)
# @click.option('--read_count_tsv', required=True, type=str)
# @click.option('--output_dir', required=True, type=str)

# metadata = json.loads(metadata)

# get variables from snakemake
sample_name = snakemake.wildcards.sample_name
bars_map = snakemake.params.bars_map # <----------- numerical index to cell barcode map
bar_to_num_map = dict((v,k) for k,v in bars_map.items()) # swap key and value in bars_map
#metadata = snakemake.params.metadata_json
metadata = json.loads(snakemake.params.metadata_json)
for i in metadata:
    if isinstance(metadata[i], dict):
        metadata[i] = json.dumps(metadata[i])
print(metadata)

all_cell_vcf = snakemake.input.output_vcf
amplicons_file = snakemake.config['reference_info']['panel_amplicon_file']
read_counts_tsv = snakemake.input.read_counts_tsv
read_counts_tsv_renamed = snakemake.output.read_count_tsv_renamed
output_h5 = snakemake.output.output_h5

# ----- get current date and time
eastern = tz.timezone('US/Eastern') # <------ uses US eastern time by default
now = datetime.now(tz.utc).astimezone(eastern) 
timestamp = now.strftime("%a %m %d %H:%M:%S %Z %Y")
datetime_simple = now.strftime("%Y-%m-%d--%H_%M")

# write logs
with open(snakemake.log[0], "a") as f:
    sys.stderr = f
    sys.stdout = f
    print(f'[{timestamp}]')
    print(f'--- [STEP5] starting to write to output file: {output_h5}')

    ###############################
    # part 1 ----- create DNA assay
    ###############################
    try:
        dna = create_dna_assay(all_cell_vcf, custom_fields = ['TLOD'], metadata = metadata)
    except Exception as e:
        print(f'[ERROR] --- {e}')

    print('--- [STEP5] created DNA assay.')
    # add cell_num_index
    ordered_cell_num_idx = np.array(pd.Series(dna.row_attrs['barcode']).map(bar_to_num_map))
    dna.add_row_attr('cell_num_index', ordered_cell_num_idx)
    dna.row_attrs['barcode_copy'] = dna.row_attrs['barcode'] # make a copy
    dna.row_attrs['barcode'] = dna.row_attrs['cell_num_index'] # substitute barcode with num index
    print('--- [STEP5] renamed dna.row_attrs["barcode"] to numerical indices.')

    ###############################
    # part 2 ----- create CNV assay
    ###############################

    rc_df = pd.read_csv(read_counts_tsv, sep='\t', index_col=0)
    #print(list(bar_to_num_map.items())[:6]) # [DEBUG]
    # rename cell barcode --> cell numerical index
    rc_df.index = rc_df.index.map(bar_to_num_map) 
    #print(rc_df.index) # [DEBUG]
    # save renamed matrix to output
    rc_df.to_csv(read_counts_tsv_renamed, sep='\t')

    cnv = create_cnv_assay(read_counts_tsv_renamed, metadata)

    amplicons = pd.read_csv(
                amplicons_file,
                sep="\t",
                lineterminator="\n",
                names=['CHROM', 'start_pos', 'end_pos', 'amplicon'],
                dtype={'start_pos': int, 'end_pos': int},
    )

    def add_amplicon_metadata(cnv_assay, amplicons):
        ca = cnv_assay.col_attrs
        chrom = np.full((cnv_assay.shape[1],), "", dtype=object)
        start_pos = np.full((cnv_assay.shape[1],), 0, dtype=int)
        end_pos = np.full((cnv_assay.shape[1],), 0, dtype=int)

        for _, amplicon in amplicons.iterrows():
            matching_ids = ca[ID] == amplicon['amplicon']
            chrom[matching_ids] = amplicon['CHROM'].strip("chrCHR")
            start_pos[matching_ids] = amplicon['start_pos']
            end_pos[matching_ids] = amplicon['end_pos']

        cnv_assay.add_col_attr('CHROM', chrom)
        cnv_assay.add_col_attr('start_pos', start_pos)
        cnv_assay.add_col_attr('end_pos', end_pos)

    add_amplicon_metadata(cnv, amplicons)
    print(f'--- [STEP5] added amplicon metadata from: {amplicons_file}')

    ###############################
    # part 3 ----- add both to H5
    ###############################

    assays = [dna, cnv]

    # !rm $output_h5
    with H5Writer(output_h5) as writer:
        for assay in assays:
            writer.write(assay)

    print(f'--- [STEP5] finished adding DNA, CNV assays to output H5 file.')