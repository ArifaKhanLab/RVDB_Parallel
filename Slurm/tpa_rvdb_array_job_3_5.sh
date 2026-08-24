#!/bin/bash

# rvdb_array_job_1_3_1.sh

# ── Configuration ──────────────────────────────────────────────────────────────
source ./step3_config.sh


FILE_LIST=$1
# TPA_FILES_DIR=$2

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
# FILE_TO_PROCESS=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$FILE_LIST")
FILE_TO_PROCESS=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$FILE_LIST")
FASTA_FILE_NAME="${TPADIR}"/"${FILE_TO_PROCESS}"

if [ -z "$FASTA_FILE_NAME" ]; then
    echo "ERROR: No file found for array task $SLURM_ARRAY_TASK_ID"
    exit 1
fi

echo "Processing file: $FASTA_FILE_NAME"


# source /projects01/mikem/applications/miniconda3/set_env.sh
# which python

SAVED_ARGS=("$@")
set --
# source /projects01/mikem/applications/miniconda3/set_env.sh
source /projects01/mikem/Python-3.11/set_env.sh
set -- "${SAVED_ARGS[@]}"

# ── Step 3: Additional processing ──────────────────────────────────────────────
echo "Step 3_5 ($(date)): Sizemirna screening in TPA fasta files."
POSKW_OUTDIR=$TPADIR/poskw_out_"$DATETAG"
POSKW_OUTFN="${POSKW_OUTDIR}"/"${FILE_TO_PROCESS}"".pscreen.fasta"


# TPA
STEP3_5="tpa_step3_5_sizemirna_v2_array.sh"
bash "${STEP3_5}" "${VERSION}" "${DATETAG}" "${SLURM_CPUS_PER_TASK}" "${POSKW_OUTFN}"
EXIT_STATUS=$?

echo "End of Step 3_5 ($(date))"

# ── Completion ─────────────────────────────────────────────────────────────────

echo "Successfully processed: ${FASTA_FILE_NAME}"
echo "Duration: $SECONDS seconds"
echo "====" $(date +%Y%m%d-%H%M%S) "end of array task $SLURM_ARRAY_TASK_ID: EXIT_STATUS=$EXIT_STATUS"

exit $EXIT_STATUS

