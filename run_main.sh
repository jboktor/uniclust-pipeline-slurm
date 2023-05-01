#!/bin/bash -ex
#SBATCH --job-name=uniclust-log.%J
#SBATCH --output=uniclust-log.%J
#SBATCH --time=5-00:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=10G

export RUNNER="mpirun --pernode --bind-to none"
export COMMON="--threads 16"
export OMP_NUM_THREADS=16
source ./paths.sh
./uniclust_workflow.sh "${FASTA}" "${BASE}" "${RELEASE}" "${SHORTRELEASE}"

pigz -c "${BASE}/${RELEASE}/uniprot_db.lookup" > "${BASE}/${RELEASE}/uniclust_uniprot_mapping.tsv.gz"
