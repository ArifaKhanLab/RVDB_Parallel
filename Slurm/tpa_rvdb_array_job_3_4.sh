#!/bin/bash

# rvdb_array_job_1_3_1.sh

# ── Configuration ──────────────────────────────────────────────────────────────

source ./step3_config.sh

FILE_LIST=$1

# TPA_FILES_DIR=$2
# TPADIR


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
FASTA_FILE_NAME="${TPADIR}"/$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$FILE_LIST")

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
echo "Step 3_4 ($(date)): Positive keyword screening in TPA fasta files."
# GenBank
STEP3_4="tpa_step3_4_poskw_v2_array.sh"
bash "${STEP3_4}" "${VERSION}" "${DATETAG}" "${SLURM_CPUS_PER_TASK}" "${FASTA_FILE_NAME}"
EXIT_STATUS=$?

echo "End of Step 3_4 ($(date))"

# ── Completion ─────────────────────────────────────────────────────────────────

echo "Successfully processed: ${FASTA_FILE_NAME}"
echo "Duration: $SECONDS seconds"
echo "====" $(date +%Y%m%d-%H%M%S) "end of array task $SLURM_ARRAY_TASK_ID: EXIT_STATUS=$EXIT_STATUS"

exit $EXIT_STATUS

