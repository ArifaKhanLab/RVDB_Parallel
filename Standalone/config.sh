# config.sh

# To do: Take this variables from prompt. eg. $3 
#NUM_OF_CPUS=1
NUM_OF_CPUS=$1
#Modified by PC to fix T77920 workstation settings
# Assigne the datetag and RVDB version
# To do: Take these two variables from prompt. eg. $1 and $2

#export DATE="may.2024"
#export CURRENTVS="29.0"

export DATE=$2
export CURRENTVS=$3

#export HOMEDIR=/home/a7032018/projects/RVDB/rvdb_parallel/
export HOMEDIR=$(pwd)
export WDIR=$HOMEDIR/RVDBv"$CURRENTVS"
export GBDIR=$WDIR/GenBank_raw_data_"$DATE"
export TPADIR=$WDIR/TPA_raw_data_"$DATE"
export REFSEQDIR=$WDIR/RefSeq_raw_data_"$DATE"

export POSKW_OUTDIR=$GBDIR/poskw_out_"$DATE" # step3_sizemirna_gb_v2.sh
export SIZEMIRNA_OUTDIR=$GBDIR/sizemirna_out_"$DATE" # step3_negkw_gb_v2.sh

export POSKW_TPA_OUTDIR=$TPADIR/poskw_out_"$DATE" # step3_sizemirna_tpa_v2.sh
export SIZEMIRNA_TPA_OUTDIR=$TPADIR/sizemirna_out_"$DATE" # step3_negkw_tpa_v2.sh
