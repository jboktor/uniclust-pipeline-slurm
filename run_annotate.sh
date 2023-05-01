#!/bin/bash -ex
#SBATCH --job-name=uniclust-log.%J
#SBATCH --output=uniclust-log.%J
#SBATCH --time=5-00:00:00
#SBATCH --ntasks=160
#SBATCH --cpus-per-task=4

function make_annotation() {
    local BASE="$1"
    local PREFIX="$2"
    local DB="${BASE}/${PREFIX}"
    local LOGPATH="${BASE}/logs"
    mkdir -p "${LOGPATH}"
    local ANNODB="$3"

    local PAUSETIME=10
    local HHPARAMS="-v 0 -cpu 1 -n 1 -e 0.1"
    mpirun -pernode cp -f ${ANNODB}/pfamA_29.0/pfam_{a3m,hhm,cs219}.ff{data,index} /dev/shm
    sleep ${PAUSETIME}
    OMP_NUM_THREADS=1 mpirun hhblits_mpi -i "${DB}_a3m" -blasttab "${DB}_pfam" -d "/dev/shm/pfam" ${HHPARAMS}
    mpirun -pernode rm -f /dev/shm/pfam_{a3m,hhm,cs219}.ff{data,index}


    mpirun -pernode cp -f ${ANNODB}/pdb70_14Sep16/pdb70_{a3m,hhm,cs219}.ff{data,index} /dev/shm
    sleep ${PAUSETIME}
    OMP_NUM_THREADS=1 mpirun hhblits_mpi -i "${DB}_a3m" -blasttab "${DB}_pdb" -d "/dev/shm/pdb70" ${HHPARAMS}
    mpirun -pernode rm -f /dev/shm/pdb70_{a3m,hhm,cs219}.ff{data,index}

    mpirun -pernode cp -f ${ANNODB}/scop70_1.75/scop70_1.75_{a3m,hhm,cs219}.ff{data,index} /dev/shm
    sleep ${PAUSETIME}
    OMP_NUM_THREADS=1 mpirun hhblits_mpi -i "${DB}_a3m" -blasttab "${DB}_scop" -d "/dev/shm/scop70_1.75" ${HHPARAMS}
    mpirun -pernode rm -f /dev/shm/scop70_1.75_{a3m,hhm,cs219}.ff{data,index}

    for i in pfam pdb scop; do
        ln -s "${DB}_${i}.ffdata" "${DB}_${i}"
        ln -s "${DB}_${i}.ffindex" "${DB}_${i}.index"
    done
}

function make_lengths() {
    local BASE=$1
    local DB=$2
    local RESULT=$3

    awk '{ print $1"\t"$3-2 }' "$BASE/uniprot_db.index" > "${RESULT}"
    awk '{ sub("\\.a3m", "", $1); print $1"\t"$3-2 }' "${DB}/pfamA_29.0/pfam_cs219.ffindex" >> "${RESULT}"
    awk '{ print $1"\t"$3-2 }' "${DB}/pdb70_14Sep16/pdb70_cs219.ffindex" >> "${RESULT}"
    awk '{ print $1"\t"$3-2 }' "${DB}/scop70_1.75/scop70_1.75_cs219.ffindex" >> "${RESULT}"
}

function make_tsv() {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIXDOM="${3}_${RELEASE}"
    local PREFIXMSA="${4}_${RELEASE}"
    local DOMDB="${BASE}/${PREFIXDOM}"
    local MSADB="${BASE}/${PREFIXMSA}"
    local LENGTHFILE="$5"
    local TMPPATH="$6"

    export RUNNER="mpirun --pernode --bind-to none"

    ln -sf "${PREFIXMSA}_a3m.ffdata" "${MSADB}_a3m"
    ln -sf "${PREFIXMSA}_a3m.ffindex" "${MSADB}_a3m.index"

    local OUTPUT=""
    for type in pfam scop pdb; do
        $RUNNER mmseqs summarizetabs "${DOMDB}_${type}" "${LENGTHFILE}" "${TMPPATH}/${PREFIXDOM}_${type}_annotation" -e 0.01 --overlap 0.1
        $RUNNER mmseqs extractdomains "${TMPPATH}/${PREFIXDOM}_${type}_annotation" "${MSADB}_a3m" "${TMPPATH}/${PREFIXMSA}_${type}" --msa-type 1 -e 0.01
        tr -d '\000' < "${TMPPATH}/${PREFIXMSA}_${type}" > "${TMPPATH}/${PREFIXMSA}_${type}.tsv"
        OUTPUT="${OUTPUT} ${TMPPATH}/${PREFIXMSA}_${type}.tsv"
    done

    local OUTPATH="${TMPPATH}/${PREFIXMSA}"
    tar -cv --use-compress-program=pigz \
        --show-transformed-names --transform "s|${OUTPATH:1}|uniclust_${RELEASE}/uniclust_${RELEASE}_annotation|g" \
        -f "${BASE}/uniclust_${RELEASE}_annotation.tar.gz" \
        ${OUTPUT}
}

source ./paths.sh
a3m_database_extract -i "${TARGET}/uniboost10_${RELEASE}_ca3m" -o "${TARGET}/uniboost10_${RELEASE}_a3m" -d "${TARGET}/uniboost10_${RELEASE}_sequence" -q "${TARGET}/uniboost10_${RELEASE}_header" 
make_annotation "$TARGET" "uniboost10_${RELEASE}" "$HHDBPATH"

TMPPATH="$TARGET/tmp/annotation"
mkdir -p "$TARGET/tmp/annotation"
make_lengths "$TARGET" "$HHDBPATH" "$TMPPATH/lengths"
make_tsv "$TARGET" "${RELEASE}" "uniboost10" "uniclust30" "$TMPPATH/lengths" "$TMPPATH"
