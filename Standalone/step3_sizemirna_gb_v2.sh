#!/bin/bash

export SCRIPT_PATH="$0"					# Get the full path of the script
export SCRIPT_NAME="${SCRIPT_PATH##*/}" # Script name (no path) via param. expansion
echo "Running $SCRIPT_NAME"






#source ./config.sh
source ./config.sh $1 $2 $3

#	$1= CPU_NUM
#	$2= Date (e.g. may.2025)
#	$3= RVDB_VERSION (e.g. 30.0)

# Log directory for the Linux bash script
timestamp=$(date +%Y%m%d_%H%M%S)  # Format: YYYYMMDD_HHMMSS
# export LOGDIR=logs_sizemirna_"$timestamp"
export LOGDIR=RVDBv"$CURRENTVS"/GenBank_raw_data_"$DATE"/logs_sizemirna_"$timestamp"
mkdir -p $LOGDIR
LOG_SCRIPT=$LOGDIR/log_script.txt

SECONDS=0
echo "====" `date +%Y%m%d-%H%M%S` "start of Linux bash script $SCRIPT_NAME on node $HOSTNAME" >> $LOG_SCRIPT


export SCREENTYPE=sizemirna					# screening type
export SEQTYPE=gb						# gb or tpa

# export WDIR=$HOMEDIR/RVDBv"$CURRENTVS" 					# /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel/RVDBv29.0
# export GBDIR=$WDIR/GenBank_raw_data_"$DATE"
# export REFSEQDIR=$WDIR/RefSeq_raw_data_"$DATE" 			# /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel/RVDBv29.0/RefSeq_raw_data_may.2024

# export POSKW_OUTDIR=$GBDIR/poskw_out_"$DATE"



# Create list of FASTA files
PSCREEN_LIST=pscreen_list.txt
rm -f $PSCREEN_LIST
# Create the list
for file in $POSKW_OUTDIR/gb*.seq.$DATE.pscreen.fasta; do
  echo "${file##*/}" >> $PSCREEN_LIST
done

# Enable debug mode
# set -x

# Source GNU Parallel and Python environments
#source /projects01/mikem/applications/GNUParallel/set_env.sh
#source /projects01/mikem/python-3.12.5/set_env.sh

# RAMDISK for speedup
export RAMDISK="/dev/shm"


export PY_SCRIPT=rvdb_update_pipeline/SEM-R_aug2025_PIPE_parallel.py
# export PY_SCRIPT=/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel/step3_version1/SEM-R_june62018_PIPE.py

# Define a custom script to process a file
process_pscreen() {
	export PSCREEN_TO_PROCESS="$1"


	export PSCREEN_LOG_DIR="$LOGDIR"/"$PSCREEN_TO_PROCESS"
	mkdir -p $PSCREEN_LOG_DIR
	export LOGF="$PSCREEN_LOG_DIR"/generic.log
	## export PRNF="$BN".prn	# print file

	echo "================= Start $SCRIPT_NAME on host $HOSTNAME for $PSCREEN_TO_PROCESS =================" > $LOGF
	echo "Processing $PSCREEN_TO_PROCESS RAMDISK= $RAMDISK" >> $LOGF
	echo "Log file is: LOGF=$LOGF" >> $LOGF

	# Get the file size of the fasta file (in bytes)
	export PSCREEN_FULL_PATH=$POSKW_OUTDIR/$PSCREEN_TO_PROCESS

    FILE_SIZE=$(stat -c %s "$PSCREEN_FULL_PATH")
    echo "File size: $FILE_SIZE bytes" >> $LOGF
	# Check if the available RAMDISK space is sufficient
    RAMDISK_AVAILABLE_KB=$(df -P "$RAMDISK" | tail -1 | awk '{print $4}')
    RAMDISK_AVAILABLE_BYTES=$((RAMDISK_AVAILABLE_KB * 1024))  # Convert KB to bytes
    echo "RAMDISK_AVAILABLE_BYTES=$RAMDISK_AVAILABLE_BYTES bytes" >> $LOGF

    if [ "$RAMDISK_AVAILABLE_BYTES" -lt "$FILE_SIZE" ]; then
        echo "Not enough space on RAMDISK. Available space: $RAMDISK_AVAILABLE bytes, required: $FILE_SIZE bytes." >> $LOGF
		echo "Using file $PSCREEN_FULL_PATH on the hard drive " >> $LOGF

		# Like: /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel/step2_for_step1_run_20240729_19_46_04_run_6036491/output/RVDBv29.0/GenBank_raw_data_jun.2024/gbphg1.seq.jun.2024

		# time python $PY_SCRIPT $HOMEDIR $DATE $CURRENTVS $SCREENTYPE $SEQTYPE
		#{ time python $PY_SCRIPT $HOMEDIR $DATE $CURRENTVS $SCREENTYPE $SEQTYPE; } 2>&1 | tee -a $LOGF
		{ python $PY_SCRIPT $HOMEDIR $DATE $CURRENTVS $SCREENTYPE $SEQTYPE; } 2>&1 | tee -a $LOGF

    else
		# Use from RAMDISK. Copy to RAMDISK first:
		export RAM_PSCREEN_FILE="${RAMDISK}"/"${PSCREEN_TO_PROCESS}"

		echo "Started copying $PSCREEN_FULL_PATH to $RAM_PSCREEN_FILE" >> $LOGF
    	start_time=$(date +%s%N)  # Start time in nanoseconds
		cp $PSCREEN_FULL_PATH $RAM_PSCREEN_FILE
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
		echo "Using file $RAM_PSCREEN_FILE on RAMDISK" >> $LOGF
		export PSCREEN_FULL_PATH=$RAM_PSCREEN_FILE

		# time python $PY_SCRIPT $HOMEDIR $DATE $CURRENTVS $SCREENTYPE $SEQTYPE
		#{ time python $PY_SCRIPT $HOMEDIR $DATE $CURRENTVS $SCREENTYPE $SEQTYPE; } 2>&1 | tee -a $LOGF
		{ python $PY_SCRIPT $HOMEDIR $DATE $CURRENTVS $SCREENTYPE $SEQTYPE; } 2>&1 | tee -a $LOGF
		# Cleanup (remove the file from RAM disk)
		echo "Removing the file $RAM_PSCREEN_FILE from RAM disk" >> $LOGF
	    rm -f $RAM_PSCREEN_FILE
    fi

	echo "================= Start $SCRIPT_NAME on host $HOSTNAME for $PSCREEN_TO_PROCESS =================" >> $LOGF

	# debug
	exit
} # end of process_pscreen()


export -f process_pscreen # Export the function for GNU Parallel

# Use GNU Parallel to run the custom script for each file
# -j option followed by the number of jobs you want to allow in parallel
time parallel -j $NUM_OF_CPUS process_pscreen ::: $(cat $PSCREEN_LIST)

echo "**** Duration of parallel processing: $SECONDS seconds elapsed." >> $LOG_SCRIPT
SECONDS=0			# restart time for join operations

# /projects01/pei-ju.chin/RVDB/RVDB_Scripts/rvdb_update_pipeline/VDBunzip_reformat_gb_to_fasta_PIPE.py

# sizemirna_outdir = os.path.join(tpadir, 'sizemirna_out_' + date)
# Join headers_... files
export SIZEMIRNA_OUTDIR=$GBDIR/sizemirna_out_"$DATE"

# /projects01/pei-ju.chin/RVDB/RVDB_Scripts/rvdb_update_pipeline/VDBunzip_reformat_gb_to_fasta_PIPE.py
# Function to join files with a given prefix and remove the original files
join_files_size_mirna() {
	local middle=$1				# like AMB, DUP, FLAG, OK, VRL

	local prefix="headers_sizemirna${middle}_"
	local output_file="${SIZEMIRNA_OUTDIR}/headers_sizemirna${middle}.txt"

	# Check if any files with the given prefix exist
	if ls "${SIZEMIRNA_OUTDIR}/${prefix}"* 1> /dev/null 2>&1; then
	    # Concatenate all files with the given prefix into the output file
	    cat "${SIZEMIRNA_OUTDIR}/${prefix}"* > "${output_file}"

	    # Remove the original files (but not the output file)
	    for file in "${SIZEMIRNA_OUTDIR}/${prefix}"*; do

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

join_files_size_mirna "FLAG"
join_files_size_mirna "OK"


EXIT_STATUS=$?
echo "Duration of join operations: $SECONDS seconds elapsed." >> $LOG_SCRIPT
echo "====" `date +%Y%m%d-%H%M%S` "end of Linux bash script $SCRIPT_NAME on node $HOSTNAME" >> $LOG_SCRIPT

