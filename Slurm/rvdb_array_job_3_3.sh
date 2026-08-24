#!/bin/bash
#					SBATCH --job-name=rvdb_process_main
#					SBATCH --output=sysout/%x-%j.out

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



echo "Step 3_3 ($(date)): Negative keyword search."
# size_mirna_screen_fn1 = fn.replace('.pscreen.fasta', '.sizemirnascreenOK.fasta')
# Reproduce from: "/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/rvdb_update_pipeline/SEM-R_june62018_PIPE_parallel.py"
# produces, like: /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/RVDBv29.0/GenBank_raw_data_may.2024/sizemirna_out_may.2024/gbphg1.seq.may.2024.sizemirnascreenOK.fasta

SIZEMIRNA_OUTDIR=$GBDIR/sizemirna_out_"$DATETAG"
SIZE_MIRNA_SCREEN_FN1="${SIZEMIRNA_OUTDIR}"/"${FILE_TO_PROCESS%.gz}"".${DATETAG}"".sizemirnascreenOK.fasta"


STEP3_3="step3_3_negkw_gb_v2_array.sh"
bash "${STEP3_3}" "${VERSION}" "${DATETAG}" "${SLURM_CPUS_PER_TASK}" "${SIZE_MIRNA_SCREEN_FN1}"
EXIT_STATUS=$?

echo "End of Step 3_3 ($(date))"


# ── Completion ─────────────────────────────────────────────────────────────────

echo "Duration: $SECONDS seconds"
echo "====" $(date +%Y%m%d-%H%M%S) "end of array task $SLURM_ARRAY_TASK_ID: EXIT_STATUS=$EXIT_STATUS"

exit $EXIT_STATUS
