#!/bin/bash
#SBATCH --job-name=masurca
#SBATCH --output=logs/%x-%u-%A-%a.log
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --time=12000
#SBATCH --mem=360G

####################################################
# HELP                                             #
####################################################
usage="
Run MaSuRCA hybrid assembly from organelle-filtered Illumina paired-end
reads and Nanopore reads.

sbatch scripts/$(basename "$0") [-h|-f|-r|-l|-o]

where:
    -h  show this help text
    -f  path to Illumina fwd reads (fastq.gz, organelle-filtered)
    -r  path to Illumina rev reads (fastq.gz, organelle-filtered)
    -l  path to Nanopore long reads (fastq.gz, organelle-filtered)
    -o  output directory

example:
sbatch scripts/masurca.sh \\
    -f results/readfilt/macroalga_R1_chloroplast-mapped.fq.gz \\
    -r results/readfilt/macroalga_R2_chloroplast-mapped.fq.gz \\
    -l results/readfilt/macroalga-minion-chloroplast-mapped.fq.gz \\
    -o results/masurca/macroalga
"

while getopts ':h:f:r:l:o:' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    f) FWDPATH="${OPTARG}"
       ;;
    r) REVPATH="${OPTARG}"
       ;;
    l) LRPATH="${OPTARG}"
       ;;
    o) OUTDIR="${OPTARG}"
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
echo "Command: sbatch $(basename "$0") -f $FWDPATH -r $REVPATH -l $LRPATH -o $OUTDIR"
echo "-------------------------------------------------"

## =================================================
## Environment
## =================================================
# source ~/miniconda3/etc/profile.d/conda.sh
# conda activate masurca

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
srun mc cp $FWDPATH $TMP/
srun mc cp $REVPATH $TMP/
srun mc cp $LRPATH $TMP/
echo `date`"  Collecting input data finished."
echo "-------------------------------------------------"

## =================================================
## Run MaSuRCA
## =================================================
echo `date`"  MaSuRCA started..."
# -i: Illumina paired-end reads (fwd,rev)
# -r: Nanopore long reads
# -t: thread count
# -o: working/output directory
cmd="srun masurca \
    -i $TMP/$(basename $FWDPATH),$TMP/$(basename $REVPATH) \
    -r $TMP/$(basename $LRPATH) \
    -t $SLURM_CPUS_ON_NODE \
    -o $TMP"
echo "Command: $cmd"
eval $cmd
echo `date`"  MaSuRCA finished."
echo "-------------------------------------------------"

## =================================================
## Archive and copy output
## =================================================
echo `date`"  Archiving and moving data..."
PREFIX=$(basename $OUTDIR)

# Archive the assembly directory; MaSuRCA writes everything under $TMP
srun tar -czvf $TMP/${PREFIX}-masurca-run.tar.gz \
    --exclude="*.fastq.gz" \
    -C $(dirname $TMP) $(basename $TMP)

srun mc cp $TMP/${PREFIX}-masurca-run.tar.gz $OUTDIR/
srun rm -fr $TMP
echo `date`"  Archiving and moving data finished."
echo "-------------------------------------------------"

echo `date`" All done!"
echo "$SLURM_JOB_NAME finished on node $SLURM_NODEID using $SLURM_CPUS_ON_NODE cpus."
####################################################
# THE END                                          #
####################################################
