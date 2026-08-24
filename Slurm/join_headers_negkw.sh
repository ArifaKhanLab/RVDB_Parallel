#!/bin/bash
#SBATCH --job-name=join_headers_negkw        	# Job name
#SBATCH --output=sysout_join/%x_%j.out   		# Standard output file (%j = Job ID)
#SBATCH --error=sysout_join/%x_%j.err    # Standard error file
#SBATCH --ntasks=1                    # Number of tasks
#SBATCH --cpus-per-task=1             # CPUs per task
#SBATCH --mem=10GB                   # Memory requested
#SBATCH --time=4:00:00  


# how to run:
# time bash /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/join_headers_negkw.sh

# SIZEMIRNA_OUTDIR="/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/RVDBv32.0/GenBank_raw_data_may.2026/poskw_out_may.2026"
# SIZEMIRNA_OUTDIR="/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/RVDBv32.0/GenBank_raw_data_may.2026/sizemirna_out_may.2026"
# NEGKW_OUTDIR="/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/RVDBv32.0/GenBank_raw_data_may.2026/negkw_out_may.2026"
NEGKW_OUTDIR=$1

# LOGDIR=/scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/sysout_join
# mkdir -p $LOGDIR
# LOG_SCRIPT=$LOGDIR/join_headers_negkw.txt 

# > $LOG_SCRIPT # truncate it to zero bytes (i.e., erase its contents), while still keeping the file.

# source /scratch/mikem/UserSupport/pei-ju.chin/rvdb_parallel_array_job/step3_config.sh
# source ./step3_config.sh

# Function to join files with a given prefix and remove the original files
join_files_negkw_gb() {
	local middle=$1				# like AMB, DUP, FLAG, OK, VRL

	local prefix="headers_nscreen${middle}_${CURRENTVS}_"
	local output_file="${NEGKW_OUTDIR}/headers_nscreen${middle}_${CURRENTVS}.txt"

	# Check if any files with the given prefix exist
	if ls "${NEGKW_OUTDIR}/${prefix}"* 1> /dev/null 2>&1; then
	    # Concatenate all files with the given prefix into the output file
	    cat "${NEGKW_OUTDIR}/${prefix}"* > "${output_file}"

	    # Remove the original files (but not the output file)
	    for file in "${NEGKW_OUTDIR}/${prefix}"*; do

	    	# Debug
	    	echo "file = $file" # >> $LOG_SCRIPT

	      if [[ "$file" != "$output_file" ]]; then
	        rm "$file"
	      fi
	    done

	    echo "Files with prefix '${prefix}' have been joined into '${output_file}' and the original files have been removed." # >> $LOG_SCRIPT
	else
	    echo "No files found with the prefix '${prefix}'. No action taken." # >> $LOG_SCRIPT
	fi
}

join_files_negkw_gb "AMB"
join_files_negkw_gb "DUP"
join_files_negkw_gb "FLAG"
join_files_negkw_gb "OK"
join_files_negkw_gb "VRL"
