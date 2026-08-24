#!/bin/bash

CURRENTVS=$1			# e.g. "29.0"
DATE=$2			# e.g. "may.2024"

NUM_OF_CPUS=$3
FASTA_FULL_PATH=$4

export SCRIPT_PATH="$0"					# Get the full path of the script
export SCRIPT_NAME="${SCRIPT_PATH##*/}" # Script name (no path) via param. expansion
echo "Running $SCRIPT_NAME"

# Log directory for the Linux bash script
# timestamp=$(date +%Y%m%d_%H%M%S)  # Format: YYYYMMDD_HHMMSS
# export LOGDIR=logs_poskw_tpa_"$timestamp"
export LOGDIR=logs_tpa_step3_4_poskw_"$SLURM_ARRAY_TASK_ID"
mkdir -p $LOGDIR
LOG_SCRIPT=$LOGDIR/log_script.txt

SECONDS=0
echo "====" `date +%Y%m%d-%H%M%S` "start of Linux bash script $SCRIPT_NAME on node $HOSTNAME" >> $LOG_SCRIPT

source step3_config.sh


export SCREENTYPE=poskw					# screening type
export SEQTYPE=tpa						# gb or tpa

# export WDIR=$HOMEDIR/RVDBv"$CURRENTVS" 					# /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel/RVDBv29.0
# export GBDIR=$WDIR/GenBank_raw_data_"$DATE"
# export TPADIR=$WDIR/TPA_raw_data_"$DATE"
# export REFSEQDIR=$WDIR/RefSeq_raw_data_"$DATE" 			# /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel/RVDBv29.0/RefSeq_raw_data_may.2024

# Create list of FASTA files
## FASTA_TPA_LIST=list_fasta_tpa.txt
## rm -f $FASTA_TPA_LIST
# Create the list
## for file in $TPADIR/*tpa_cu*.seq.$DATE; do
##   echo "${file##*/}" >> $FASTA_TPA_LIST
## done

# Enable debug mode
# set -x

# Source GNU Parallel and Python environments
# source /projects01/mikem/applications/GNUParallel/set_env.sh

# source /projects01/mikem/python-3.12.5/set_env.sh
SAVED_ARGS=("$@")
set --
# source /projects01/mikem/applications/miniconda3/set_env.sh
source /projects01/mikem/Python-3.11/set_env.sh
set -- "${SAVED_ARGS[@]}"


# RAMDISK for speedup
export RAMDISK="/dev/shm"


## export PY_SCRIPT=SEM-R_june62018_PIPE_parallel.py
# export PY_SCRIPT=/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel/step3_version1/SEM-R_june62018_PIPE.py
# export PY_SCRIPT="/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/rvdb_update_pipeline/SEM-R_june62018_PIPE_parallel.py"
export PY_SCRIPT="/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/rvdb_update_pipeline/SEM-R_aug2025_PIPE_parallel.py"


# Define a custom script to process a file
## process_fasta_tpa() {
	# export FASTA_TO_PROCESS="$1"
	export FASTA_TO_PROCESS="${FASTA_FULL_PATH##*/}"  # The ##*/ strips everything up to and including the last /, leaving just the filename.


	# export FASTA_LOG_DIR="$LOGDIR"/"$FASTA_TO_PROCESS"
	# mkdir -p $FASTA_LOG_DIR
	# export LOGF="$FASTA_LOG_DIR"/generic.log
	export LOGF=""$LOGDIR""/"$FASTA_TO_PROCESS".log
	## export PRNF="$BN".prn	# print file

	echo "================= Start $SCRIPT_NAME on host $HOSTNAME for $FASTA_TO_PROCESS =================" > $LOGF
	echo "Processing $FASTA_TO_PROCESS RAMDISK= $RAMDISK" >> $LOGF
	echo "Log file is: LOGF=$LOGF" >> $LOGF

	# Get the file size of the fasta file (in bytes)
	export FASTA_FULL_PATH=$TPADIR/$FASTA_TO_PROCESS

    FILE_SIZE=$(stat -c %s "$FASTA_FULL_PATH")
    echo "File size: $FILE_SIZE bytes" >> $LOGF
	# Check if the available RAMDISK space is sufficient
    RAMDISK_AVAILABLE_KB=$(df -P "$RAMDISK" | tail -1 | awk '{print $4}')
    RAMDISK_AVAILABLE_BYTES=$((RAMDISK_AVAILABLE_KB * 1024))  # Convert KB to bytes
    echo "RAMDISK_AVAILABLE_BYTES=$RAMDISK_AVAILABLE_BYTES bytes" >> $LOGF

    if [ "$RAMDISK_AVAILABLE_BYTES" -lt "$FILE_SIZE" ]; then
        echo "Not enough space on RAMDISK. Available space: $RAMDISK_AVAILABLE bytes, required: $FILE_SIZE bytes." >> $LOGF
		echo "Using file $FASTA_FULL_PATH on the hard drive " >> $LOGF

		# Like: /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel/step2_for_step1_run_20240729_19_46_04_run_6036491/output/RVDBv29.0/GenBank_raw_data_jun.2024/gbphg1.seq.jun.2024
		export RAM_FASTA_FILE="" 		# not using RAMDISK
		# time python $PY_SCRIPT $HOMEDIR $DATE $CURRENTVS $SCREENTYPE $SEQTYPE
		{ time python $PY_SCRIPT $HOMEDIR $DATE $CURRENTVS $SCREENTYPE $SEQTYPE; } 2>&1 | tee -a $LOGF

    else
		# Use from RAMDISK. Copy to RAMDISK first:
		export RAM_FASTA_FILE="${RAMDISK}"/"${FASTA_TO_PROCESS}"

		echo "Started copying $FASTA_FULL_PATH to $RAM_FASTA_FILE" >> $LOGF
    	start_time=$(date +%s%N)  # Start time in nanoseconds
		cp $FASTA_FULL_PATH $RAM_FASTA_FILE
		end_time=$(date +%s%N)    # End time in nanoseconds
		elapsed_time_ns=$((end_time - start_time))

		echo "Ended Copying" >> $LOGF

		elapsed_time_ms=$((elapsed_time_ns / 1000000))        # Convert to milliseconds
		elapsed_time_s=$((elapsed_time_ns / 1000000000))      # Convert to seconds
		# Calculate remaining milliseconds for more precision
		remaining_ms=$(( (elapsed_time_ns % 1000000000) / 1000000 ))

		# Print and log the elapsed time in different units (nanoseconds, milliseconds, and seconds)
		echo "Elapsed time: $elapsed_time_ns nanoseconds" >> $LOGF
		echo "Elapsed time: $elapsed_time_ms milliseconds" >> $LOGF
		echo "Elapsed time: $elapsed_time_s seconds and $remaining_ms milliseconds" >> $LOGF

		# Main processing logic
		echo "Using file $RAM_FASTA_FILE on RAMDISK" >> $LOGF
		export FASTA_FULL_PATH=$RAM_FASTA_FILE

		# time python $PY_SCRIPT $HOMEDIR $DATE $CURRENTVS $SCREENTYPE $SEQTYPE
		{ time python $PY_SCRIPT $HOMEDIR $DATE $CURRENTVS $SCREENTYPE $SEQTYPE; } 2>&1 | tee -a $LOGF

		# Cleanup (remove the file from RAM disk)
		echo "Removing the file $RAM_FASTA_FILE from RAM disk" >> $LOGF
	    rm -f $RAM_FASTA_FILE
    fi

	echo "================= Start $SCRIPT_NAME on host $HOSTNAME for $FASTA_TO_PROCESS =================" >> $LOGF

	# debug
##	exit
## } # end of process_fasta_tpa()


## export -f process_fasta_tpa # Export the function for GNU Parallel

# Use GNU Parallel to run the custom script for each file
# -j option followed by the number of jobs you want to allow in parallel
## parallel -j $NUM_OF_CPUS process_fasta_tpa ::: $(cat $FASTA_TPA_LIST)

echo "**** Duration of parallel processing: $SECONDS seconds elapsed." >> $LOG_SCRIPT
SECONDS=0			# restart time for join operations


# Join headers_... files
export POSKW_OUTDIR=$TPADIR/poskw_out_"$DATE"

: <<'COMMENT'

# Function to join files with a given prefix and remove the original files
join_files_poskw() {

	local prefix="headers_pscreen_"
	local output_file="${POSKW_OUTDIR}/headers_pscreen.txt"

	# Check if any files with the given prefix exist
	if ls "${POSKW_OUTDIR}/${prefix}"* 1> /dev/null 2>&1; then
	    # Concatenate all files with the given prefix into the output file
	    cat "${POSKW_OUTDIR}/${prefix}"* > "${output_file}"

	    # Remove the original files (but not the output file)
	    for file in "${POSKW_OUTDIR}/${prefix}"*; do

	    	# Debug
	    	echo "file = $file" >> $LOG_SCRIPT

	      if [[ "$file" != "$output_file" ]]; then
	        rm "$file"
	      fi
	    done

	    echo "Files with prefix '${prefix}' have been joined into '${output_file}' and the original files have been removed." >> $LOG_SCRIPT
	else
	    echo "No files found with the prefix '${prefix}'. No action taken." >> $LOG_SCRIPT
	fi
}

# Call join
join_files_poskw

COMMENT

EXIT_STATUS=$?
echo "Duration of join operations: $SECONDS seconds elapsed." >> $LOG_SCRIPT
echo "====" `date +%Y%m%d-%H%M%S` "end of Linux bash script $SCRIPT_NAME on node $HOSTNAME" >> $LOG_SCRIPT
