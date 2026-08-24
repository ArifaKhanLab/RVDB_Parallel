#!/bin/bash
#			SBATCH --job-name=rvdb_process_main
#			SBATCH --output=sysout/%x-%j.out

# ── Configuration ──────────────────────────────────────────────────────────────

FILE_LIST=$1

source ./step3_config.sh

# VERSION="29.0"
# DATETAG="may.2024"
VERSION=$CURRENTVS
DATETAG=$DATE

# ══════════════════════════════════════════════════════════════════════════════
# ARRAY JOB EXECUTION (runs when SLURM_ARRAY_TASK_ID is set)
# ══════════════════════════════════════════════════════════════════════════════

echo "====" $(date +%Y%m%d-%H%M%S) "start of array task $SLURM_ARRAY_TASK_ID on node $SLURMD_NODENAME"
SECONDS=0

# ── Get file for this array task ───────────────────────────────────────────────
FILE_TO_PROCESS=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$FILE_LIST")

if [ -z "$FILE_TO_PROCESS" ]; then
    echo "ERROR: No file found for array task $SLURM_ARRAY_TASK_ID"
    exit 1
fi

echo "Processing file: $FILE_TO_PROCESS"


echo "Step 3_2 ($(date)): Size screening."
# poskw_outfn = fn.replace('seq.' + date, 'seq.' + date + '.pscreen.fasta')
# Reproduce from: "/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/rvdb_update_pipeline/SEM-R_june62018_PIPE_parallel.py"
# produces, like: 
# /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/RVDBv29.0/GenBank_raw_data_may.2024/poskw_out_may.2024/gbphg1.seq.may.2024.pscreen.fasta
POSKW_OUTDIR=$GBDIR/poskw_out_"$DATETAG"
POSKW_OUTFN="${POSKW_OUTDIR}"/"${FILE_TO_PROCESS%.gz}"".${DATETAG}"".pscreen.fasta"

STEP3_2="step3_2_sizemirna_gb_v2_array.sh"
bash "${STEP3_2}" "${VERSION}" "${DATETAG}" "${SLURM_CPUS_PER_TASK}" "${POSKW_OUTFN}"
EXIT_STATUS=$?

echo "End of Step 3_2 ($(date))"

# -------------------------------------------------------------


# ── Completion ─────────────────────────────────────────────────────────────────
echo "Duration: $SECONDS seconds"
echo "====" $(date +%Y%m%d-%H%M%S) "end of array task $SLURM_ARRAY_TASK_ID: EXIT_STATUS=$EXIT_STATUS"

exit $EXIT_STATUS

