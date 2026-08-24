# run_slurm_pipeline.sh


---

## Purpose

Top-level orchestration script for the RVDB GenBank processing pipeline.
It scans for `.gz` input files, submits a chain of Slurm array jobs with
`afterok` dependencies, and logs each submission step.

---

## Pipeline Control Flow

```
bash run_slurm_pipeline.sh
├── sbatch rvdb_array_job_1_3_1.sh           (steps 1, 2, 3.1)
│   ├── bash step2_v4_3_array.sh
│   │   └── VDBunzip_reformat_gb_to_fasta_PIPE_parallel.py
│   └── bash step3_1_poskw_gb_v2_array.sh
│       └── SEM-R_aug2025_PIPE_parallel.py
│
├── sbatch join_headers_poskw.sh             (dependency: afterok rvdb_array_job_1_3_1)
│
├── sbatch rvdb_array_job_3_2.sh             (dependency: afterok join_headers_poskw)
│   └── bash step3_2_sizemirna_gb_v2_array.sh
│       └── SEM-R_aug2025_PIPE_parallel.py
│
├── sbatch join_headers_sizemirna.sh         (dependency: afterok rvdb_array_job_3_2)
│
├── sbatch rvdb_array_job_3_3.sh             (dependency: afterok join_headers_sizemirna)
│   └── bash step3_3_negkw_gb_v2_array.sh
│       └── SEM-R_aug2025_PIPE_parallel.py
│
└── sbatch join_headers_negkw.sh             (dependency: afterok rvdb_array_job_3_3)
```

---

## How to Run

### 1. Navigate to the working directory

```bash
cd /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job
```

### 2. Create the raw-data directory for the new release

```bash
mkdir -p RVDBv32.0/GenBank_raw_data_may.2026
```

### 3. Create the release-notes symbolic link

```bash
ln -s <source> RVDBv32.0/gb_releasenotes_v271_may.2026.txt
```

### 4. Update the two hardcoded paths in `run_slurm_pipeline.sh`

**`GZ_FILES_DIR`** — Path to your new `.gz` input directory.
Find and update this line:
```bash
GZ_FILES_DIR="/projects01/pei-ju.chin/RVDB/rvdb_parallel/RVDBv32.0/GenBank_raw_data_may.2026"
```

**`BASE_DIR`** — Desired output root (default is usually fine).
Find and update this line:
```bash
export BASE_DIR="$(pwd)/results"
```

### 5. Launch the pipeline

```bash
bash run_slurm_pipeline.sh
```

The script will:
1. Scan `GZ_FILES_DIR` for `.gz` files and write a `files_to_process.txt` manifest.
2. Submit all Slurm jobs with chained `afterok` dependencies.
3. Write a timestamped log file (`slurm_pipeline_YYYYMMDD_HHMMSS.log`).

---

## Key Variables

**`GZ_FILES_DIR`** — Source directory containing `.gz` input files. **Update for each release.**
```bash
GZ_FILES_DIR="/projects01/pei-ju.chin/RVDB/rvdb_parallel/RVDBv32.0/GenBank_raw_data_may.2026"
```

**`BASE_DIR`** — Root directory for all pipeline output.
```bash
export BASE_DIR="$(pwd)/results"
```

**`FILE_LIST`** — Auto-generated manifest of `.gz` filenames.
```bash
FILE_LIST=files_to_process.txt
```

**`CONCURRENT_TASKS`** — Maximum simultaneously running Slurm array tasks.
```bash
CONCURRENT_TASKS=5000
```

**`VERSION`** — RVDB version, sourced from `step3_config.sh`.
```bash
VERSION=$CURRENTVS
```

**`DATETAG`** — Date tag, sourced from `step3_config.sh`.
```bash
DATETAG=$DATE
```

---

## Slurm Job Summary

**`JOB_DECOMPRESS_GB2FASTA_POSKW`**
- Script: `rvdb_array_job_1_3_1.sh`
- Dependency: none (first job)
- Resources: 4 CPUs, 200 GB RAM, 48 h, `--exclude=bc054`

**`JOB_JOIN_HEADERS_POSKW`**
- Script: `join_headers_poskw.sh`
- Dependency:
```bash
--dependency=afterok:$JOB_ID_DECOMPRESS_GB2FASTA_POSKW
```
- Resources: default (no override)

**`JOB_SIZEMIRNA`**
- Script: `rvdb_array_job_3_2.sh`
- Dependency:
```bash
--dependency=afterok:$JOB_ID_JOIN_HEADERS_POSKW
```
- Resources: 4 CPUs, 200 GB RAM, 48 h, `--exclude=bc054`

**`JOB_JOIN_HEADERS_SIZEMIRNA`**
- Script: `join_headers_sizemirna.sh`
- Dependency:
```bash
--dependency=afterok:$JOB_ID_SIZEMIRNA
```
- Resources: default (no override)

**`JOB_NEGKW`**
- Script: `rvdb_array_job_3_3.sh`
- Dependency:
```bash
--dependency=afterok:$JOB_ID_JOIN_HEADERS_SIZEMIRNA
```
- Resources: 4 CPUs, 200 GB RAM, 48 h, `--exclude=bc054`

**`JOB_JOIN_HEADERS_NEGKW`**
- Script: `join_headers_negkw.sh`
- Dependency:
```bash
--dependency=afterok:$JOB_ID_NEGKW
```
- Resources: default (no override)

> All follow-up jobs use `--kill-on-invalid-dep=yes` — the chain stops automatically if any upstream job fails.

---

## Output Directories (created automatically)

**`sysout_sp_decompress_gb2faasta_poskw/`** — stdout/stderr for `rvdb_array_job_1_3_1` tasks.
```bash
mkdir -p $SYSOUT_DECOMPRESS_GB2FASTA_POSKW
```

**`sysout_sp_sizemirna/`** — stdout/stderr for `rvdb_array_job_3_2` tasks.
```bash
mkdir -p $SYSOUT_SIZEIRNA
```

**`sysout_sp_negkw/`** — stdout/stderr for `rvdb_array_job_3_3` tasks.
```bash
mkdir -p $SYSOUT_NEGKW
```

**`results/`** — Pipeline output files.
```bash
mkdir -p "$BASE_DIR"
```

---

## Logging

Each run produces a timestamped log file in the current directory:

```
slurm_pipeline_YYYYMMDD_HHMMSS.log
```

Every submission and error is recorded via the internal `log()` function, which
prefixes each line with a `[YYYY-MM-DD HH:MM:SS]` timestamp.

---

## Error Handling

- If no `.gz` files are found in `GZ_FILES_DIR`, the script exits immediately
  with a non-zero code.
- If any `sbatch` call fails, the script logs the exit code and exits.
- All follow-up jobs use `--kill-on-invalid-dep=yes`, so the chain stops
  automatically if any upstream job fails.

---

## Full Script

```bash
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

find -L "${GZ_FILES_DIR}" -name "*.gz" -printf "%f\n" > "$FILE_LIST"

TOTAL_FILES=$(wc -l < "$FILE_LIST")

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "ERROR: No .gz files found in ${GZ_FILES_DIR}"
    exit 1
fi

echo "Found $TOTAL_FILES .gz files to process"
echo ""
echo "Submitting array job with ${TOTAL_FILES} tasks..."

LOG_FILE="slurm_pipeline_$(date +%Y%m%d_%H%M%S).log"

AS_DECOMPRESS_GB2FASTA_POSKW="rvdb_array_job_1_3_1.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [[ ! -f "$AS_DECOMPRESS_GB2FASTA_POSKW" ]]; then
    log "ERROR: Array job script '$AS_DECOMPRESS_GB2FASTA_POSKW' not found. Exiting."
    exit 1
fi

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
           "${GZ_FILES_DIR}")
DECOMPRESS_GB2FASTA_POSKW_EXIT_CODE=$?

if [[ $DECOMPRESS_GB2FASTA_POSKW_EXIT_CODE -ne 0 ]]; then
    log "ERROR: Failed to submit array job. sbatch exit code: $DECOMPRESS_GB2FASTA_POSKW_EXIT_CODE"
    exit 1
fi

JOB_ID_DECOMPRESS_GB2FASTA_POSKW=$(echo "$JOB_DECOMPRESS_GB2FASTA_POSKW" | awk '{print $NF}')
log "Array job submitted successfully. Job ID: $JOB_ID_DECOMPRESS_GB2FASTA_POSKW"

JOIN_HEADERS_POSKW_SCRIPT="join_headers_poskw.sh"
export POSKW_OUTDIR=$GBDIR/poskw_out_"$DATE"

JOB_JOIN_HEADERS_POSKW=$(sbatch --dependency=afterok:"$JOB_ID_DECOMPRESS_GB2FASTA_POSKW" \
                              --kill-on-invalid-dep=yes \
                              "$JOIN_HEADERS_POSKW_SCRIPT" "${POSKW_OUTDIR}")
JOIN_HEADERS_POSKW_EXIT_CODE=$?

if [[ $JOIN_HEADERS_POSKW_EXIT_CODE -ne 0 ]]; then
   log "ERROR: Failed to submit follow-up job. sbatch exit code: $JOIN_HEADERS_POSKW_EXIT_CODE"
   exit 1
fi

JOB_ID_JOIN_HEADERS_POSKW=$(echo "$JOB_JOIN_HEADERS_POSKW" | awk '{print $NF}')
log "Follow-up job (join_headers_poskw) submitted. Job ID: $JOB_ID_JOIN_HEADERS_POSKW"

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
           "${AS_SIZEMIRNA}" "${FILE_LIST}")
SUBMIT_EXIT_CODE=$?

if [[ $SUBMIT_EXIT_CODE -ne 0 ]]; then
    log "ERROR: Failed to submit array job. sbatch exit code: $SUBMIT_EXIT_CODE"
    exit 1
fi

JOB_ID_SIZEMIRNA=$(echo "$JOB_SIZEMIRNA" | awk '{print $NF}')
log "Array job submitted successfully. Job ID: $JOB_ID_SIZEMIRNA"

JOIN_HEADERS_SIZEMIRNA_SCRIPT="join_headers_sizemirna.sh"
export SIZEMIRNA_OUTDIR=$GBDIR/sizemirna_out_"$DATE"

JOB_JOIN_HEADERS_SIZEMIRNA=$(sbatch --dependency=afterok:"$JOB_ID_SIZEMIRNA" \
                              --kill-on-invalid-dep=yes \
                              "$JOIN_HEADERS_SIZEMIRNA_SCRIPT" "${SIZEMIRNA_OUTDIR}")
JOIN_HEADERS_SIZEMIRNA_EXIT_CODE=$?

if [[ $JOIN_HEADERS_SIZEMIRNA_EXIT_CODE -ne 0 ]]; then
   log "ERROR: Failed to submit follow-up job. sbatch exit code: $JOIN_HEADERS_SIZEMIRNA_EXIT_CODE"
   exit 1
fi

JOB_ID_JOIN_HEADERS_SIZEMIRNA=$(echo "$JOB_JOIN_HEADERS_SIZEMIRNA" | awk '{print $NF}')
log "Follow-up job (join_headers_sizemirna) submitted. Job ID: $JOB_ID_JOIN_HEADERS_SIZEMIRNA"

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
           "${AS_NEGKW}" "${FILE_LIST}")
SUBMIT_EXIT_CODE=$?

if [[ $SUBMIT_EXIT_CODE -ne 0 ]]; then
    log "ERROR: Failed to submit array job. sbatch exit code: $SUBMIT_EXIT_CODE"
    exit 1
fi

JOB_ID_NEGKW=$(echo "$JOB_NEGKW" | awk '{print $NF}')
log "Array job submitted successfully. Job ID: $JOB_ID_NEGKW"

JOIN_HEADERS_NEGKW_SCRIPT="join_headers_negkw.sh"
export NEGKW_OUTDIR=$GBDIR/negkw_out_"$DATE"

JOB_JOIN_HEADERS_NEGKW=$(sbatch --dependency=afterok:"$JOB_ID_NEGKW" \
                              --kill-on-invalid-dep=yes \
                              "$JOIN_HEADERS_NEGKW_SCRIPT" "${NEGKW_OUTDIR}")
JOIN_HEADERS_NEGKW_EXIT_CODE=$?

if [[ $JOIN_HEADERS_NEGKW_EXIT_CODE -ne 0 ]]; then
   log "ERROR: Failed to submit follow-up job. sbatch exit code: $JOIN_HEADERS_NEGKW_EXIT_CODE"
   exit 1
fi

JOB_ID_JOIN_HEADERS_NEGKW=$(echo "$JOB_JOIN_HEADERS_NEGKW" | awk '{print $NF}')
log "Follow-up job (join_headers_negkw) submitted. Job ID: $JOB_ID_JOIN_HEADERS_NEGKW"

log "Done. Exiting pipeline launcher."
exit 0
```
