#!/bin/bash
# =============================================================================
# Script:   run_slurm_pipeline.sh
# Purpose:  Submit a Slurm array job, wait for completion, then run a
#           follow-up script.
# Usage:    bash run_slurm_pipeline.sh
# =============================================================================

source ./step3_config.sh

VERSION=$CURRENTVS
DATETAG=$DATE

GZ_FILES_DIR="/projects01/pei-ju.chin/RVDB/rvdb_parallel/RVDBv32.0/GenBank_raw_data_may.2026"

export BASE_DIR="$(pwd)/results"
FILE_LIST=files_to_process.txt

SYSOUT_DECOMPRESS_GB2FASTA_POSKW=sysout_sp_decompress_gb2faasta_poskw
mkdir -p $SYSOUT_DECOMPRESS_GB2FASTA_POSKW
mkdir -p "$BASE_DIR"

echo "=== SETUP PHASE ==="  
echo "Scanning for .gz files in ${GZ_FILES_DIR}..." 

# Generate file list: If it's a symlink, find won't follow it unless you add -L
find -L "${GZ_FILES_DIR}" -name "*.gz" -printf "%f\n" > "$FILE_LIST"


TOTAL_FILES=$(wc -l < "$FILE_LIST")

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "ERROR: No .gz files found in ${GZ_FILES_DIR}" 
    exit 1
fi

echo "Found $TOTAL_FILES .gz files to process" 
echo "" 
echo "Submitting array job with ${TOTAL_FILES} tasks..."


LOG_FILE="slurm_pipeline_$(date +%Y%m%d_%H%M%S).log"  # Log file for this run


# --- Configuration -----------------------------------------------------------
# AS means Array Script 
AS_DECOMPRESS_GB2FASTA_POSKW="rvdb_array_job_1_3_1.sh"       	# The Slurm array job script to submit

# --- Logging function ---------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# --- Validate scripts exist --------------------------------------------------
if [[ ! -f "$AS_DECOMPRESS_GB2FASTA_POSKW" ]]; then
    log "ERROR: Array job script '$AS_DECOMPRESS_GB2FASTA_POSKW' not found. Exiting."
    exit 1
fi


# --- Submit the Slurm array job ----------------------------------------------
# Steps:  1 (decompress), 2 (GB to FASTA), 3.1  poskw
log "Submitting Slurm array job (steps: 1, 2, 3.1): $AS_DECOMPRESS_GB2FASTA_POSKW (range: 1-${TOTAL_FILES})"


# !!!!!! DEBUG DEBUG DEBUG
## TOTAL_FILES=10 

CONCURRENT_TASKS=5000

JOB_DECOMPRESS_GB2FASTA_POSKW=$(sbatch --array=1-${TOTAL_FILES}%${CONCURRENT_TASKS} \
           --job-name=rvdb_array_job_1_3_1 \
           --output="${SYSOUT_DECOMPRESS_GB2FASTA_POSKW}"/%x-%A_%a.out \
           --error="${SYSOUT_DECOMPRESS_GB2FASTA_POSKW}"/%x-%A_%a.err \
           --time=0-48:00:00 \
           --cpus-per-task=4 \
           --mem=200G \
           --exclude=bc054 \
           "${AS_DECOMPRESS_GB2FASTA_POSKW}" "${FILE_LIST}" "${BASE_DIR}" \
           "${GZ_FILES_DIR}")  # Submit this same script
DECOMPRESS_GB2FASTA_POSKW_EXIT_CODE=$?

if [[ $DECOMPRESS_GB2FASTA_POSKW_EXIT_CODE -ne 0 ]]; then
    log "ERROR: Failed to submit array job. sbatch exit code: $DECOMPRESS_GB2FASTA_POSKW_EXIT_CODE"
    exit 1
fi

# Extract the Job ID from sbatch output (e.g., "Submitted batch job 123456")
JOB_ID_DECOMPRESS_GB2FASTA_POSKW=$(echo "$JOB_DECOMPRESS_GB2FASTA_POSKW" | awk '{print $NF}')
log "Array job submitted successfully. Job ID: $JOB_ID_DECOMPRESS_GB2FASTA_POSKW"


# ------------------------------------------------------------------------------------------------
# ------------- Wait for finishing POSKW and then start merging headers
# !!! Now wait for all array job tasks completed and then run join_headers_poskw.sh Slurm job 

JOIN_HEADERS_POSKW_SCRIPT="join_headers_poskw.sh"

export POSKW_OUTDIR=$GBDIR/poskw_out_"$DATE"

# --- Submit join-headers_poskw follow-up job with dependency --------------------------------
# afterok: follow-up runs only if ALL array tasks exit with code 0 (success)
log "Submitting follow-up job (join_headers_poskw) with dependency on Job ID $JOB_ID_DECOMPRESS_GB2FASTA_POSKW (afterok)..."

JOB_JOIN_HEADERS_POSKW=$(sbatch --dependency=afterok:"$JOB_ID_DECOMPRESS_GB2FASTA_POSKW" \
                              --kill-on-invalid-dep=yes \
                              "$JOIN_HEADERS_POSKW_SCRIPT" "${POSKW_OUTDIR}")
JOIN_HEADERS_POSKW_EXIT_CODE=$?

if [[ $JOIN_HEADERS_POSKW_EXIT_CODE -ne 0 ]]; then
   log "ERROR: Failed to submit follow-up job. sbatch exit code: $JOIN_HEADERS_POSKW_EXIT_CODE"
   exit 1
fi

JOB_ID_JOIN_HEADERS_POSKW=$(echo "$JOB_JOIN_HEADERS_POSKW" | awk '{print $NF}')
log "Follow-up job ("join_headers_poskw") submitted successfully. Job ID: $JOB_ID_JOIN_HEADERS_POSKW"
log "Follow-up job will start automatically once all array tasks complete successfully."


# ------------------------------------------------------------------------------------------------
# ------------- Wait for finishing merging POSKW headers and then start SIZEMIRNA
AS_SIZEMIRNA="rvdb_array_job_3_2.sh"
SYSOUT_SIZEIRNA=sysout_sp_sizemirna
mkdir -p $SYSOUT_SIZEIRNA

JOB_SIZEMIRNA=$(sbatch --dependency=afterok:"$JOB_ID_JOIN_HEADERS_POSKW" \
		   --array=1-${TOTAL_FILES}%${CONCURRENT_TASKS} \
           --job-name=sizemirna \
           --output="${SYSOUT_SIZEIRNA}"/%x-%A_%a.out \
           --error="${SYSOUT_SIZEIRNA}"/%x-%A_%a.err \
           --time=0-48:00:00 \
           --cpus-per-task=4 \
           --mem=200G \
           --exclude=bc054 \
           "${AS_SIZEMIRNA}" "${FILE_LIST}" )  # Submit this same script
SUBMIT_EXIT_CODE=$?

if [[ $SUBMIT_EXIT_CODE -ne 0 ]]; then
    log "ERROR: Failed to submit array job. sbatch exit code: $SUBMIT_EXIT_CODE"
    exit 1
fi

# Extract the Job ID from sbatch output (e.g., "Submitted batch job 123456")
JOB_ID_SIZEMIRNA=$(echo "$JOB_SIZEMIRNA" | awk '{print $NF}')
log "Array job submitted successfully. Job ID: $JOB_ID_SIZEMIRNA"


# ------------------------------------------------------------------------------------------------
# ------------- Wait for finishing sizemirna and then start merging headers
# !!! Now wait for all array job tasks completed and then run join_headers_sizemirna.sh Slurm job 

JOIN_HEADERS_SIZEMIRNA_SCRIPT="join_headers_sizemirna.sh"

export SIZEMIRNA_OUTDIR=$GBDIR/sizemirna_out_"$DATE"

# --- Submit join-headers_poskw follow-up job with dependency --------------------------------
# afterok: follow-up runs only if ALL array tasks exit with code 0 (success)
log "Submitting follow-up job (join_headers_sizemirna) with dependency on Job ID $JOB_ID_SIZEMIRNA (afterok)..."

JOB_JOIN_HEADERS_SIZEMIRNA=$(sbatch --dependency=afterok:"$JOB_ID_SIZEMIRNA" \
                              --kill-on-invalid-dep=yes \
                              "$JOIN_HEADERS_SIZEMIRNA_SCRIPT" "${SIZEMIRNA_OUTDIR}")
JOIN_HEADERS_SIZEMIRNA_EXIT_CODE=$?

if [[ $JOIN_HEADERS_SIZEMIRNA_EXIT_CODE -ne 0 ]]; then
   log "ERROR: Failed to submit follow-up job. sbatch exit code: $JOIN_HEADERS_SIZEMIRNA_EXIT_CODE"
   exit 1
fi

JOB_ID_JOIN_HEADERS_SIZEMIRNA=$(echo "$JOB_JOIN_HEADERS_SIZEMIRNA" | awk '{print $NF}')
log "Follow-up job ("join_headers_sizemirna") submitted successfully. Job ID: $JOB_ID_JOIN_HEADERS_SIZEMIRNA"
log "Follow-up job will start automatically once all array tasks complete successfully."

# ------------------------------------------------------------------------------------------------


# ------------------------------------------------------------------------------------------------
# ------------- Wait for finishing merging SIZEMIRNA headers and then start NEGKW
AS_NEGKW="rvdb_array_job_3_3.sh"
SYSOUT_NEGKW=sysout_sp_negkw
mkdir -p $SYSOUT_NEGKW

JOB_NEGKW=$(sbatch --dependency=afterok:"$JOB_ID_JOIN_HEADERS_SIZEMIRNA" \
		   --array=1-${TOTAL_FILES}%${CONCURRENT_TASKS} \
           --job-name=negkw \
           --output="${SYSOUT_NEGKW}"/%x-%A_%a.out \
           --error="${SYSOUT_NEGKW}"/%x-%A_%a.err \
           --time=0-48:00:00 \
           --cpus-per-task=4 \
           --mem=200G \
           --exclude=bc054 \
           "${AS_NEGKW}" "${FILE_LIST}" )  # Submit this same script
SUBMIT_EXIT_CODE=$?

if [[ $SUBMIT_EXIT_CODE -ne 0 ]]; then
    log "ERROR: Failed to submit array job. sbatch exit code: $SUBMIT_EXIT_CODE"
    exit 1
fi

# Extract the Job ID from sbatch output (e.g., "Submitted batch job 123456")
JOB_ID_NEGKW=$(echo "$JOB_NEGKW" | awk '{print $NF}')
log "Array job submitted successfully. Job ID: $JOB_ID_NEGKW"



# ------------------------------------------------------------------------------------------------
# ------------- Wait for finishing negkw and then start merging headers after negkw
# !!! Now wait for all array job tasks completed and then run join_headers_negkw.sh Slurm job 

JOIN_HEADERS_NEGKW_SCRIPT="join_headers_negkw.sh"

export NEGKW_OUTDIR=$GBDIR/negkw_out_"$DATE"

# --- Submit join_headers_negkw follow-up job with dependency --------------------------------
# afterok: follow-up runs only if ALL array tasks exit with code 0 (success)
log "Submitting follow-up job (join_headers_negkw) with dependency on Job ID $JOB_ID_NEGKW (afterok)..."

JOB_JOIN_HEADERS_NEGKW=$(sbatch --dependency=afterok:"$JOB_ID_NEGKW" \
                              --kill-on-invalid-dep=yes \
                              "$JOIN_HEADERS_NEGKW_SCRIPT" "${NEGKW_OUTDIR}")
JOIN_HEADERS_NEGKW_EXIT_CODE=$?

if [[ $JOIN_HEADERS_NEGKW_EXIT_CODE -ne 0 ]]; then
   log "ERROR: Failed to submit follow-up job. sbatch exit code: $JOIN_HEADERS_NEGKW_EXIT_CODE"
   exit 1
fi

JOB_ID_JOIN_HEADERS_NEGKW=$(echo "$JOB_JOIN_HEADERS_NEGKW" | awk '{print $NF}')
log "Follow-up job ("join_headers_sizemirna") submitted successfully. Job ID: $JOB_ID_JOIN_HEADERS_NEGKW"
log "Follow-up job will start automatically once all array tasks complete successfully."

# ------------------------------------------------------------------------------------------------


log "Done. Exiting pipeline launcher."
exit 0

