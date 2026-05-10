#!/bin/bash
#SBATCH --job-name=canu
#SBATCH --output=logs/%x-%u-%A-%a.log
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --time=12000
#SBATCH --mem=200G

####################################################
# HELP                                             #
####################################################
usage="
Run Canu assembly from organelle-filtered Nanopore reads.

sbatch scripts/$(basename "$0") [-h|-l|-g|-o|-p]

where:
    -h  show this help text
    -l  path to long reads (fastq.gz, organelle-filtered MinION)
    -g  expected genome size (e.g. 150k for a plastid, 345k for some algal mt)
    -o  output directory
    -p  output prefix (e.g. species-canu)

example:
sbatch scripts/canu.sh \\
    -l results/readfilt/macroalga-minion-chloroplast-mapped.fq.gz \\
    -g 150k \\
    -o results/canu/macroalga \\
    -p macroalga-canu
"

while getopts ':h:l:g:o:p:' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    l) LRPATH="${OPTARG}"
       ;;
    g) GENOMESIZE="${OPTARG}"
       ;;
    o) OUTDIR="${OPTARG}"
       ;;
    p) PREFIX="${OPTARG}"
       ;;
    :) printf "missing argument for -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done
shift $((OPTIND - 1))

####################################################
# MAIN                                             #
####################################################
echo `date`" $SLURM_JOB_NAME started on node $SLURM_NODEID using $SLURM_CPUS_ON_NODE cpus."
echo "Command: sbatch $(basename "$0") -l $LRPATH -g $GENOMESIZE -o $OUTDIR -p $PREFIX"
echo "-------------------------------------------------"

## =================================================
## Environment
## =================================================
# source ~/miniconda3/etc/profile.d/conda.sh
# conda activate canu

## =================================================
## Paths on scratch
## =================================================
DATE=`date +"%Y%m%dT%H%M%S"`
TMP=/scratch/$USER/$DATE
export TMPDIR=$TMP
srun mkdir -p $TMP

## =================================================
## Collect input data
## =================================================
echo `date`"  Collecting input data..."
srun mc cp $LRPATH $TMP/
echo `date`"  Collecting input data finished."
echo "-------------------------------------------------"

## =================================================
## Run Canu
## =================================================
echo `date`"  Canu started..."
# useGrid=false: run in-process instead of submitting Canu's own SLURM jobs
# -nanopore-raw: input is uncorrected Nanopore reads
cmd="srun canu \
    -d $TMP \
    -p $PREFIX \
    genomeSize=$GENOMESIZE \
    useGrid=false \
    -nanopore-raw $TMP/$(basename $LRPATH)"
echo "Command: $cmd"
eval $cmd
echo `date`"  Canu finished."
echo "-------------------------------------------------"

## =================================================
## Archive and copy output
## =================================================
echo `date`"  Archiving and moving data..."
srun tar -czvf $TMP/${PREFIX}-canu-run.tar.gz \
    -C $TMP \
    ${PREFIX}.contigs.fasta \
    ${PREFIX}.unitigs.fasta \
    ${PREFIX}.report \
    ${PREFIX}.contigs.gfa 2>/dev/null || true

srun mc cp $TMP/${PREFIX}-canu-run.tar.gz $OUTDIR/
srun rm -fr $TMP
echo `date`"  Archiving and moving data finished."
echo "-------------------------------------------------"

echo `date`" All done!"
echo "$SLURM_JOB_NAME finished on node $SLURM_NODEID using $SLURM_CPUS_ON_NODE cpus."
####################################################
# THE END                                          #
####################################################
