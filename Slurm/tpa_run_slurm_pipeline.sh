#!/bin/bash
# =============================================================================
# Script:   run_slurm_pipeline_tpa.sh
# Purpose:  Submit a Slurm array job, wait for completion, then run a
#           follow-up script.
# Usage:    bash run_slurm_pipeline.sh
# =============================================================================

source ./step3_config.sh

VERSION=$CURRENTVS
DATETAG=$DATE

# decompressed file are here
# TPA_FILES_DIR="/projects01/pei-ju.chin/RVDB/rvdb_parallel/RVDBv32.0/TPA_raw_data_may.2026"
# Use TPADIR from step3_config.sh instead of TPA_FILES_DIR
TPA_FILE_LIST=tpa_files_to_process.txt			# already decompressed, assumed file contains list

# export TPA_BASE_DIR="$(pwd)/tpa_results"

TPA_SYSOUT_POSKW=tpa_sysout_sp_poskw
mkdir -p $TPA_SYSOUT_POSKW

TPA_TOTAL_FILES=$(wc -l < "$TPA_FILE_LIST")

if [ "$TPA_TOTAL_FILES" -eq 0 ]; then
    echo "ERROR: ${TPA_FILE_LIST} is empty" 
    exit 1
fi

echo "Found $TPA_TOTAL_FILES files to process" 
echo "" 
echo "Submitting array job with ${TPA_TOTAL_FILES} tasks..."


TPA_LOG_FILE="tpa_slurm_pipeline_$(date +%Y%m%d_%H%M%S).log"  # Log file for this run

# --- Configuration -----------------------------------------------------------
# AS means Array Script 
TPA_AS_POSKW="tpa_rvdb_array_job_3_4.sh"       	# The Slurm array job script to submit

# --- Logging function ---------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TPA_LOG_FILE"
}

# --- Validate scripts exist --------------------------------------------------
if [[ ! -f "$TPA_AS_POSKW" ]]; then
    log "ERROR: Array job script '$TPA_AS_POSKW' not found. Exiting."
    exit 1
fi

# --- Submit the Slurm array job ----------------------------------------------
# Steps:  1 (decompress), 2 (GB to FASTA), 3.1  poskw
log "Submitting Slurm array job (steps: 3.4 tpa): $TPA_AS_POSKW (range: 1-${TPA_TOTAL_FILES})"


# !!!!!! DEBUG DEBUG DEBUG
## TOTAL_FILES=10 

CONCURRENT_TASKS=5000

TPA_JOB_POSKW=$(sbatch --array=1-${TPA_TOTAL_FILES}%${CONCURRENT_TASKS} \
           --job-name=tpa_rvdb_array_job_3_4 \
           --output="${TPA_SYSOUT_POSKW}"/%x-%A_%a.out \
           --error="${TPA_SYSOUT_POSKW}"/%x-%A_%a.err \
           --time=0-48:00:00 \
           --cpus-per-task=4 \
           --mem=200G \
           --exclude=bc054 \
           "${TPA_AS_POSKW}" "${TPA_FILE_LIST}" )
SUBMIT_EXIT_CODE=$?

if [[ $SUBMIT_EXIT_CODE -ne 0 ]]; then
    log "ERROR: Failed to submit array job. sbatch exit code: $SUBMIT_EXIT_CODE"
    exit 1
fi


# Extract the Job ID from sbatch output (e.g., "Submitted batch job 123456")
TPA_JOB_ID_POSKW=$(echo "$TPA_JOB_POSKW" | awk '{print $NF}')
log "Array job submitted successfully. Job ID: $TPA_JOB_ID_POSKW"


# ------------------------------------------------------------------------------------------------
# ------------- Wait for finishing POSKW_TPA and then start merging headers
# !!! Now wait for all array job tasks completed and then run join_headers_poskw.sh Slurm job 

JOIN_HEADERS_POSKW_SCRIPT="join_headers_poskw.sh"

export TPA_POSKW_OUTDIR=$TPADIR/poskw_out_"$DATE"

# --- Submit join-headers_poskw follow-up job with dependency --------------------------------
# afterok: follow-up runs only if ALL array tasks exit with code 0 (success)
log "Submitting follow-up job (join_headers_poskw) with dependency on Job ID $TPA_JOB_ID_POSKW (afterok)..."

TPA_JOB_JOIN_HEADERS_POSKW=$(sbatch --dependency=afterok:"$TPA_JOB_ID_POSKW" \
                              --kill-on-invalid-dep=yes \
                              --job-name=tpa_join_headers_poskw \
                              --output=tpa_sysout_join/%x_%j.out \
                              --error=tpa_sysout_join/%x_%j.err \
                              "$JOIN_HEADERS_POSKW_SCRIPT" "${TPA_POSKW_OUTDIR}" )
SUBMIT_EXIT_CODE=$?

if [[ $SUBMIT_EXIT_CODE -ne 0 ]]; then
   log "ERROR: Failed to submit follow-up job. sbatch exit code: $SUBMIT_EXIT_CODE"
   exit 1
fi

TPA_JOB_ID_JOIN_HEADERS_POSKW=$(echo "$TPA_JOB_JOIN_HEADERS_POSKW" | awk '{print $NF}')
log "Follow-up job ("join_headers_poskw") submitted successfully. Job ID: $TPA_JOB_ID_JOIN_HEADERS_POSKW"
log "Follow-up job will start automatically once all array tasks complete successfully."

# !!!!!!!!!!!!!!!!!!!!!! DEBUG !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# exit 0 DONE


# ------------------------------------------------------------------------------------------------
# ------------- Wait for finishing nerging POSKW headers and then start SIZEMIRNA
TPA_AS_SIZEMIRNA="tpa_rvdb_array_job_3_5.sh"
TPA_SYSOUT_SIZEMIRNA=tpa_sysout_sp_sizemirna
mkdir -p $TPA_SYSOUT_SIZEMIRNA

TPA_JOB_SIZEMIRNA=$(sbatch --dependency=afterok:"$TPA_JOB_ID_JOIN_HEADERS_POSKW" \
		   --array=1-${TPA_TOTAL_FILES}%${CONCURRENT_TASKS} \
           --job-name=sizemirna_tpa \
           --output="${TPA_SYSOUT_SIZEMIRNA}"/%x-%A_%a.out \
           --error="${TPA_SYSOUT_SIZEMIRNA}"/%x-%A_%a.err \
           --time=0-48:00:00 \
           --cpus-per-task=4 \
           --mem=200G \
           --exclude=bc054 \
           "${TPA_AS_SIZEMIRNA}" "${TPA_FILE_LIST}" )  # Submit this same script
SUBMIT_EXIT_CODE=$?

if [[ $SUBMIT_EXIT_CODE -ne 0 ]]; then
    log "ERROR: Failed to submit array job. sbatch exit code: $SUBMIT_EXIT_CODE"
    exit 1
fi

# Extract the Job ID from sbatch output (e.g., "Submitted batch job 123456")
TPA_JOB_ID_SIZEMIRNA=$(echo "$TPA_JOB_SIZEMIRNA" | awk '{print $NF}')
log "Array job submitted successfully. Job ID: $TPA_JOB_ID_SIZEMIRNA"


# ------------------------------------------------------------------------------------------------
# ------------- Wait for finishing sizemirna and then start merging headers
# !!! Now wait for all array job tasks completed and then run join_headers_sizemirna.sh Slurm job 

JOIN_HEADERS_SIZEMIRNA_SCRIPT="join_headers_sizemirna.sh"

export TPA_SIZEMIRNA_OUTDIR=$TPADIR/sizemirna_out_"$DATE"

# --- Submit join-headers_poskw follow-up job with dependency --------------------------------
# afterok: follow-up runs only if ALL array tasks exit with code 0 (success)
log "Submitting follow-up job (join_headers_sizemirna) with dependency on Job ID $TPA_JOB_ID_SIZEMIRNA (afterok)..."

TPA_JOB_JOIN_HEADERS_SIZEMIRNA=$(sbatch --dependency=afterok:"$TPA_JOB_ID_SIZEMIRNA" \
                              --kill-on-invalid-dep=yes \
                              --job-name=tpa_join_headers_sizemirna \
                              --output=tpa_sysout_join/%x_%j.out \
                              --error=tpa_sysout_join/%x_%j.err \
                              "$JOIN_HEADERS_SIZEMIRNA_SCRIPT" "${TPA_SIZEMIRNA_OUTDIR}")
SUBMIT_EXIT_CODE=$?

if [[ $SUBMIT_EXIT_CODE -ne 0 ]]; then
   log "ERROR: Failed to submit follow-up job. sbatch exit code: $SUBMIT_EXIT_CODE"
   exit 1
fi

TPA_JOB_ID_JOIN_HEADERS_SIZEMIRNA=$(echo "$TPA_JOB_JOIN_HEADERS_SIZEMIRNA" | awk '{print $NF}')
log "Follow-up job ("join_headers_sizemirna") submitted successfully. Job ID: $TPA_JOB_ID_JOIN_HEADERS_SIZEMIRNA"
log "Follow-up job will start automatically once all array tasks complete successfully."

# ------------------------------------------------------------------------------------------------


# !!!!!!!!!!!!!!!!!!!!!! DEBUG !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# exit 0 Done



# ------------------------------------------------------------------------------------------------
# ------------- Wait for finishing merging SIZEMIRNA headers and then start NEGKW
TPA_AS_NEGKW="tpa_rvdb_array_job_3_6.sh"
TPA_SYSOUT_NEGKW=tpa_sysout_sp_negkw
mkdir -p $TPA_SYSOUT_NEGKW

TPA_JOB_NEGKW=$(sbatch --dependency=afterok:"$TPA_JOB_ID_JOIN_HEADERS_SIZEMIRNA" \
		   --array=1-${TPA_TOTAL_FILES}%${CONCURRENT_TASKS} \
           --job-name=negkw \
           --output="${TPA_SYSOUT_NEGKW}"/%x-%A_%a.out \
           --error="${TPA_SYSOUT_NEGKW}"/%x-%A_%a.err \
           --time=0-48:00:00 \
           --cpus-per-task=4 \
           --mem=200G \
           --exclude=bc054 \
           "${TPA_AS_NEGKW}" "${TPA_FILE_LIST}" )  # Submit this same script
SUBMIT_EXIT_CODE=$?

if [[ $SUBMIT_EXIT_CODE -ne 0 ]]; then
    log "ERROR: Failed to submit array job. sbatch exit code: $SUBMIT_EXIT_CODE"
    exit 1
fi

# Extract the Job ID from sbatch output (e.g., "Submitted batch job 123456")
TPA_JOB_ID_NEGKW=$(echo "$TPA_JOB_NEGKW" | awk '{print $NF}')
log "Array job submitted successfully. Job ID: $TPA_JOB_ID_NEGKW"



# ------------------------------------------------------------------------------------------------
# ------------- Wait for finishing negkw and then start merging headers after negkw
# !!! Now wait for all array job tasks completed and then run join_headers_negkw.sh Slurm job 

JOIN_HEADERS_NEGKW_SCRIPT="join_headers_negkw.sh"

export TPA_NEGKW_OUTDIR=$TPADIR/negkw_out_"$DATE"

# --- Submit join_headers_negkw follow-up job with dependency --------------------------------
# afterok: follow-up runs only if ALL array tasks exit with code 0 (success)
log "Submitting follow-up job (join_headers_negkw) with dependency on Job ID $TPA_JOB_ID_NEGKW (afterok)..."

JOB_JOIN_HEADERS_NEGKW_TPA=$(sbatch --dependency=afterok:"$TPA_JOB_ID_NEGKW" \
                              --kill-on-invalid-dep=yes \
                              --job-name=tpa_join_headers_negkw \
                              --output=tpa_sysout_join/%x_%j.out \
                              --error=tpa_sysout_join/%x_%j.err \
                              "$JOIN_HEADERS_NEGKW_SCRIPT" "${TPA_NEGKW_OUTDIR}")
SUBMIT_EXIT_CODE=$?

if [[ $SUBMIT_EXIT_CODE -ne 0 ]]; then
   log "ERROR: Failed to submit follow-up job. sbatch exit code: $SUBMIT_EXIT_CODE"
   exit 1
fi

TPA_JOB_ID_JOIN_HEADERS_NEGKW=$(echo "$JOB_JOIN_HEADERS_NEGKW_TPA" | awk '{print $NF}')
log "Follow-up job ("join_headers_sizemirna") submitted successfully. Job ID: $TPA_JOB_ID_JOIN_HEADERS_NEGKW"
log "Follow-up job will start automatically once all array tasks complete successfully."

# ------------------------------------------------------------------------------------------------


log "Done. Exiting pipeline launcher."
exit 0

