#!/bin/bash

# /projects01/pei-ju.chin/RVDB/RVDB_Scripts/rvdb_update_pipeline/VDBunzip_reformat_gb_to_fasta_PIPE.py

# Enable debug mode
# set -x

# Source GNU Parallel environment setup script
#source /projects01/mikem/applications/GNUParallel/set_env.sh

# Assigne the datetag and RVDB version
VERSION=$1
DATETAG=$2

#Assigne user-defined CPU thread usage
NUM_OF_CPUS=$3


export VERSION
export DATETAG

# Define directory containing .gz files
# Modified by PC to fix T77920 workstation settings
export GZ_FILES_DIR="RVDBv${VERSION}/GenBank_raw_data_${DATETAG}" 

# Generate base directory name using current date and time
#export BASE_DIR=run_"$(date +%Y%m%d_%H_%M_%S)"
#mkdir -p "$BASE_DIR"

# Define a custom script to process a file
process_file() {
	FILE_TO_PROCESS="$1"

	# Prepare output directory for each file
	OUTPUT_PREFIX="${FILE_TO_PROCESS%.gz}" # e.g., gbphg1.seq.gz > gbphg1.seq
	# OUTPUT_DIR="${BASE_DIR}/${OUTPUT_PREFIX}" Modified by PC to fix T77920 workstation settings

	# echo "OUTPUT_DIR=$OUTPUT_DIR" 

	# mkdir -p "$OUTPUT_DIR" Modified by PC to fix T77920 workstation settings

	#EXTRACTD_FILE="${OUTPUT_DIR}/${OUTPUT_PREFIX}" Modified by PC to fix T77920 workstation settings

	export EXTRACTD_FILE="${GZ_FILES_DIR}/${OUTPUT_PREFIX}" 

	# Main processing logic
	gunzip -c "${GZ_FILES_DIR}/${FILE_TO_PROCESS}" > "${EXTRACTD_FILE}"
	
	#Decompress by Rapidgz
	#rapidgzip -d -k -P 0 -c "${GZ_FILES_DIR}/${FILE_TO_PROCESS}" > "${EXTRACTD_FILE}"
	
	
	# export INPUT_GZ_FILE="${GZ_FILES_DIR}/${FILE_TO_PROCESS}"
	# export OUTPUT_FILE="${EXTRACTD_FILE}"


	# Step 1
	

	# Step 2


	# Step 3


  # Add your custom processing steps here
}



export -f process_file # Export the function for GNU Parallel

# Find .gz files and save just the file names to a file list
find "${GZ_FILES_DIR}" -name "*.gz" -printf "%f\n" > "RVDBv${VERSION}/files_to_process.txt"

# Use GNU Parallel to run the custom script for each file
time parallel -j $NUM_OF_CPUS process_file ::: $(cat "RVDBv${VERSION}/files_to_process.txt")

# Decompress by Rapidgz
# time parallel -j 1 process_file ::: $(cat "RVDBv${VERSION}/files_to_process.txt")
