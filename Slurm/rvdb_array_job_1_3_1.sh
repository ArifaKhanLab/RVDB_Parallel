#!/bin/bash

# rvdb_array_job_1_3_1.sh

# ── Configuration ──────────────────────────────────────────────────────────────

FILE_LIST=$1
BASE_DIR=$2
GZ_FILES_DIR=$3


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

# ── Prepare output directory ───────────────────────────────────────────────────
OUTPUT_PREFIX="${FILE_TO_PROCESS%.gz}"  # Remove .gz extension
OUTPUT_DIR="${BASE_DIR}"/"${OUTPUT_PREFIX}"
mkdir -p "$OUTPUT_DIR"

EXTRACTED_FILE="${OUTPUT_DIR}"/"${OUTPUT_PREFIX}"

# ── Step 1: Decompress ─────────────────────────────────────────────────────────

if [ ! -f "${EXTRACTED_FILE}" ] || [ -f "${EXTRACTED_FILE}" -a ! -s "${EXTRACTED_FILE}" ]; then
    echo "Step 1: Decompressing, File: ${FILE_TO_PROCESS}..."
    gunzip -c "${GZ_FILES_DIR}/${FILE_TO_PROCESS}" > "${EXTRACTED_FILE}"
    if [ $? -ne 0 ] || [ ! -s "${EXTRACTED_FILE}" ]; then
        echo "ERROR: Decompression failed or output file is empty for ${FILE_TO_PROCESS}" >&2
        rm -f "${EXTRACTED_FILE}"
        exit 1
    fi
    echo "Step 1: Decompression complete. Output: ${EXTRACTED_FILE}"
else
    echo "Step 1: Decompressing. File ${FILE_TO_PROCESS} has already been decompressed and is non-empty."
fi



if [ $? -ne 0 ]; then
    echo "ERROR: Failed to decompress ${FILE_TO_PROCESS}"
    exit 1
fi

echo "End of Step 1 ($(date)): Decompressed to: ${EXTRACTED_FILE}"

# ── Step 2: Python processing ──────────────────────────────────────────────────
echo "Step 2 ($(date)): Convert GB format to FASTA format. Running Python processing..."

## export INPUT_GZ_FILE="${GZ_FILES_DIR}""/GB_phg/""${FILE_TO_PROCESS}"
export INPUT_GZ_FILE="${FILE_TO_PROCESS}"
export OUTPUT_FILE="${EXTRACTED_FILE}"

# Option A: Use external script

# source /projects01/mikem/applications/miniconda3/set_env.sh
# which python

SAVED_ARGS=("$@")
set --
# source /projects01/mikem/applications/miniconda3/set_env.sh
source /projects01/mikem/Python-3.11/set_env.sh
set -- "${SAVED_ARGS[@]}"


STEP2="step2_v4_3_array.sh"
# bash "${STEP2}" "${VERSION}" "${DATETAG}" "${INPUT_GZ_FILE}" "${OUTPUT_FILE}" "${GZ_FILES_DIR}" "${SLURM_CPUS_PER_TASK}"
FASTA_FILE_NAME=$(bash "${STEP2}" "${VERSION}" "${DATETAG}" "${INPUT_GZ_FILE}" "${OUTPUT_FILE}" "${GZ_FILES_DIR}" "${SLURM_CPUS_PER_TASK}" | tail -1)

# filename=$(bash /path/to/your_script.sh | tail -1)
echo "File processed: $FASTA_FILE_NAME"

echo "End of Step 2 ($(date))"


# ── Step 3: Additional processing ──────────────────────────────────────────────
echo "Step 3_1 ($(date)): Positive keyword screening."
# GenBank
STEP3_1="step3_1_poskw_gb_v2_array.sh"
bash "${STEP3_1}" "${VERSION}" "${DATETAG}" "${SLURM_CPUS_PER_TASK}" "${FASTA_FILE_NAME}"
echo "End of Step 3_1 ($(date))"

# ── Completion ─────────────────────────────────────────────────────────────────
EXIT_STATUS=$?

echo "Successfully processed: ${FILE_TO_PROCESS}"
echo "Output directory: ${OUTPUT_DIR}"
echo "Duration: $SECONDS seconds"
echo "====" $(date +%Y%m%d-%H%M%S) "end of array task $SLURM_ARRAY_TASK_ID: EXIT_STATUS=$EXIT_STATUS"

exit $EXIT_STATUS

