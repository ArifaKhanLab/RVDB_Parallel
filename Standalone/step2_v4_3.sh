#!/bin/bash
VERSION=$1
DATETAG=$2
NUM_OF_CPUS=$3

# Enable debug mode
# set -x

# Source GNU Parallel environment setup script > Disabled by PC to fix T77920 workstation settings
# source /projects01/mikem/applications/GNUParallel/set_env.sh > Disabled by PC to fix T77920 workstation settings
# source /projects01/mikem/python-3.12.5/set_env.sh > Disabled by PC to fix T77920 workstation settings
# source /projects01/mikem/applications/emboss/set_env.sh > Disabled by PC to fix T77920 workstation settings

# Define directory containing extracted .gz files
# export GZ_FILES_DIR=/projects01/arifakhanlabs/mikem/RVDB_update/RVDBv28.0/GB_phg > Modified by PC to fix T77920 workstation settings
# To discuss: What to do from L15-31
export EXT_FILES_BASE=./
# export EXT_FILES_RUN=run_20240729_19_46_04
# export EXT_FILES_DIR=$EXT_FILES_BASE/$EXT_FILES_RUN
# ls -1 $EXT_FILES_DIR > dirs_to_process_step2.txt
# ls -d $EXT_FILES_DIR/* | grep -v '/log' | awk -F'/' '{print $NF}' > dirs_to_process_step2.txt

export VERSION		# 29.0
export DATETAG		# jun.2024


# STEP2_BASE="$EXT_FILES_BASE"/step2_for_step1_"$EXT_FILES_RUN"_run_"$SLURM_JOB_ID"
# export OUTDIR="$STEP2_BASE"/output
# mkdir -p $OUTDIR

# export GZ_FILES_DIR="/home/a7032018/projects/RVDB/rvdb_parallel/RVDBv${VERSION}/GenBank_raw_data_${DATETAG}"
export GZ_FILES_DIR="RVDBv${VERSION}/GenBank_raw_data_${DATETAG}"


export LOGDIR="$GZ_FILES_DIR"/logs_step2
mkdir -p $LOGDIR

echo "Log directory is: $LOGDIR"

# Generate base directory name using current date and time
# export BASE_DIR=run_step2_"$(date +%Y%m%d_%H_%M_%S)"
# mkdir -p "$BASE_DIR"

export RAMDISK="/dev/shm"


# python3 ../VDBunzip_reformat_gb_to_fasta_PIPE_parallel.py \
#	/projects01/pei-ju.chin/RVDB/rvdb_parallel/ jun.2024 29.0 gb
## export PYTHON_TEST_CODE=test_v3.py
## export MAIN_PROCESSING="python3 $PYTHON_TEST_CODE $OUTDIR jun.2024 29.0"

# Assigne the datetag and RVDB version
# To do: Take these two variables from prompt. eg. $1 and $2


# Such as /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel/step2_for_step1_run_20240729_19_46_04_run_5372680/output/RVDBv29.0/GenBank_raw_data_jun.2024
# export OUT_FILE_DIR="$OUTDIR"/RVDBv"$VERSION"/GenBank_raw_data_"$DATETAG"
# mkdir -p $OUT_FILE_DIR

# Get the full path of the script
export SCRIPT_PATH="$0"
# Extract the file name (without path) using parameter expansion
export SCRIPT_NAME="${SCRIPT_PATH##*/}"


# Define a custom script to process a file
process_dir() {
    FILE_TO_PROCESS0="$1"
    export FILE_TO_PROCESS="${FILE_TO_PROCESS0%.gz}"

    export EXTRACTED_FILE0="${GZ_FILES_DIR}/${FILE_TO_PROCESS}"
    export EXTRACTED_FILE="${RAMDISK}/${FILE_TO_PROCESS}"
    export OUT_FILE="${GZ_FILES_DIR}/${FILE_TO_PROCESS}.${DATETAG}"

    BN="${LOGDIR}/${FILE_TO_PROCESS}"
    export LOGF="${BN}.log"

    echo "================= Start $SCRIPT_NAME on host $HOSTNAME for $BN =================" > "$LOGF"
    echo "Processing: $FILE_TO_PROCESS" >> "$LOGF"
    echo "EXTRACTED_FILE0: $EXTRACTED_FILE0" >> "$LOGF"
    echo "EXTRACTED_FILE: $EXTRACTED_FILE" >> "$LOGF"
    echo "RAMDISK: $RAMDISK" >> "$LOGF"

    FILE_SIZE=$(stat -c %s "$EXTRACTED_FILE0")
    RAMDISK_AVAILABLE_KB=$(df -P "$RAMDISK" | tail -1 | awk '{print $4}')
    RAMDISK_AVAILABLE_BYTES=$((RAMDISK_AVAILABLE_KB * 1024))
    BUFFER_SIZE=$((FILE_SIZE / 10))  # 10% buffer
    #BUFFER_SIZE=$((FILE_SIZE / 1))  # 100% buffer
    REQUIRED_SPACE=$((FILE_SIZE + BUFFER_SIZE))

    echo "File size: $FILE_SIZE bytes" >> "$LOGF"
    echo "Required with buffer: $REQUIRED_SPACE bytes" >> "$LOGF"
    echo "Available RAMDISK: $RAMDISK_AVAILABLE_BYTES bytes" >> "$LOGF"
    df -h "$RAMDISK" >> "$LOGF"

    if [ "$RAMDISK_AVAILABLE_BYTES" -lt "$REQUIRED_SPACE" ]; then
        echo "Not enough RAMDISK space. Using file on disk: $EXTRACTED_FILE0" >> "$LOGF"
        EXTRACTED_FILE="$EXTRACTED_FILE0"
        python rvdb_update_pipeline/VDBunzip_reformat_gb_to_fasta_PIPE_parallel.py "$EXT_FILES_BASE" "$DATETAG" "$VERSION" gb
    else
        echo "Copying $EXTRACTED_FILE0 → $EXTRACTED_FILE (RAMDISK)" >> "$LOGF"
        start_time=$(date +%s%N)

        cp "$EXTRACTED_FILE0" "$EXTRACTED_FILE"
        if [ $? -eq 0 ]; then
            end_time=$(date +%s%N)
            elapsed_ns=$((end_time - start_time))
            elapsed_ms=$((elapsed_ns / 1000000))
            elapsed_s=$((elapsed_ns / 1000000000))
            remain_ms=$(( (elapsed_ns % 1000000000) / 1000000 ))

            echo "File copied successfully!" >> "$LOGF"
            echo "Elapsed time: $elapsed_ns ns | $elapsed_ms ms | $elapsed_s s and $remain_ms ms" >> "$LOGF"
            echo "Running: python VDBunzip_reformat_gb_to_fasta_PIPE_parallel.py $EXT_FILES_BASE $DATETAG $VERSION gb" >> "$LOGF"

            python rvdb_update_pipeline/VDBunzip_reformat_gb_to_fasta_PIPE_parallel.py "$EXT_FILES_BASE" "$DATETAG" "$VERSION" gb

            echo "Cleaning up RAMDISK file: $EXTRACTED_FILE" >> "$LOGF"
            rm -f "$EXTRACTED_FILE"
        else
        	rm -f "$EXTRACTED_FILE"
            echo "Error: File copy failed! Falling back to disk file." >> "$LOGF"
            EXTRACTED_FILE="$EXTRACTED_FILE0"
            python rvdb_update_pipeline/VDBunzip_reformat_gb_to_fasta_PIPE_parallel.py "$EXT_FILES_BASE" "$DATETAG" "$VERSION" gb
        fi
    fi

    echo "================= End $SCRIPT_NAME on host $HOSTNAME for $BN =================" >> "$LOGF"
}


export -f process_dir # Export the function for GNU Parallel

# Use GNU Parallel to run the custom script for each file
# -j option followed by the number of jobs you want to allow in parallel

time parallel -j $NUM_OF_CPUS process_dir ::: $(cat "RVDBv${VERSION}/files_to_process.txt")
# parallel -j $NUM_OF_CPUS process_dir ::: $(cat dirs_to_process_step2.txt)

# /projects01/pei-ju.chin/RVDB/RVDB_Scripts/rvdb_update_pipeline/VDBunzip_reformat_gb_to_fasta_PIPE.py
