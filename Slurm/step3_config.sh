# config.sh

# NUM_OF_CPUS=4

export DATE="may.2026"
export CURRENTVS="32.0"

# export HOMEDIR=/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel
# export HOMEDIR=/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel/RVDBv29.0
export HOMEDIR=/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job

export WDIR=$HOMEDIR/RVDBv"$CURRENTVS"
export GBDIR=$WDIR/GenBank_raw_data_"$DATE"
export TPADIR=$WDIR/TPA_raw_data_"$DATE"
export REFSEQDIR=$WDIR/RefSeq_raw_data_"$DATE"

export POSKW_OUTDIR=$GBDIR/poskw_out_"$DATE" # step3_sizemirna_gb_v2.sh
export SIZEMIRNA_OUTDIR=$GBDIR/sizemirna_out_"$DATE" # step3_negkw_gb_v2.sh

export POSKW_TPA_OUTDIR=$TPADIR/poskw_out_"$DATE" # step3_sizemirna_tpa_v2.sh
export SIZEMIRNA_TPA_OUTDIR=$TPADIR/sizemirna_out_"$DATE" # step3_negkw_tpa_v2.sh
