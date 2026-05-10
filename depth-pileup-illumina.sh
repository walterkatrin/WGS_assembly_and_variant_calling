#!/bin/bash
#SBATCH --job-name=depth-pileup
#SBATCH --output=./logs/%x-%u-%A-%a.log
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --time=1260
#SBATCH --mem=72G

#######################################################
# HELP                                                #
#######################################################
usage="
Compute sequencing depth and pileup of Illumina reads against an assembly.

sbatch scripts/$(basename "$0") [-h|-f|-r|-d|-p|-o]

where:
    -h  show this help text
    -f  path to Illumina fwd reads
    -r  path to Illumina rev reads
    -d  path to assembly database (Bowtie2 index prefix)
    -p  prefix used to label output files (e.g. species abbreviation)
    -o  output directory

example:
sbatch scripts/depth-pileup-illumina.sh \\
    -f results/readfilt/macroalga_R1_chloroplast-mapped.fq.gz \\
    -r results/readfilt/macroalga_R2_chloroplast-mapped.fq.gz \\
    -d results/assembly/macroalga-chloroplast-genome \\
    -p macroalga \\
    -o results/pileup
"

while getopts ':h:f:r:d:p:o:' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    f) FWDPATH=${OPTARG}
       ;;
    r) REVPATH=${OPTARG}
       ;;
    d) DB=${OPTARG}
       ;;
    p) PREFIX=${OPTARG}
       ;;
    o) OUTDIR=${OPTARG}
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

#######################################################
# MAIN                                                #
#######################################################
echo `date`" $SLURM_JOB_NAME started on node $SLURM_NODEID using $SLURM_CPUS_ON_NODE cpus."
echo "Command: sbatch $(basename "$0") -f $FWDPATH -r $REVPATH -d $DB -p $PREFIX -o $OUTDIR"
echo "-------------------------------------------------"

## ====================================================
## Environment
## ====================================================
# source ~/miniconda3/etc/profile.d/conda.sh
# conda activate qc

## ====================================================
## Paths etc
## ====================================================
DATE=`date +"%Y%m%dT%H%M%S"`
TMP=/scratch/$USER/tmp-${DATE}
export TMPDIR=$TMP
srun mkdir -p $TMP

## ====================================================
## Collect input data
## ====================================================
echo `date`"  Collecting input data..."
srun mc cp $FWDPATH $TMP/
srun mc cp $REVPATH $TMP/
srun mc find $(dirname $DB) --name "$(basename $DB).*.bt2" --exec "mc cp {} $TMP/"
echo `date`"  Collecting input data finished"
echo "-------------------------------------------------"

## ====================================================
## Run bowtie2
## ====================================================
echo `date`"  Running bowtie2..."
cmd="srun bowtie2 \
    -x $TMP/$(basename $DB) \
    -p $SLURM_CPUS_ON_NODE \
    -X 1000 \
    -1 $TMP/$(basename $FWDPATH) \
    -2 $TMP/$(basename $REVPATH) \
    -S $TMP/${PREFIX}-$(basename $DB)-mappings.sam \
    --quiet"
echo "Command: $cmd"
eval $cmd
echo `date`"  Running bowtie2 finished."
echo "-------------------------------------------------"

## ====================================================
## SAM to sorted BAM
## ====================================================
echo `date`"  Running samtools sort..."
cmd="srun samtools view -@ $SLURM_CPUS_ON_NODE -S -b $TMP/${PREFIX}-$(basename $DB)-mappings.sam \
    | samtools sort -@ $SLURM_CPUS_ON_NODE -o $TMP/${PREFIX}-$(basename $DB)-mappings.bam"
echo "Command: $cmd"
eval $cmd
echo `date`"  Running samtools sort finished."
echo "-------------------------------------------------"

## ====================================================
## Compute per-base coverage
## ====================================================
echo `date`"  Running samtools depth..."
# -a reports every position, including zero-coverage; -d 1000000 lifts the depth cap
# samtools depth automatically skips secondary alignments
cmd="srun samtools depth \
    -d 1000000 -a \
    $TMP/${PREFIX}-$(basename $DB)-mappings.bam \
    > $TMP/${PREFIX}-$(basename $DB)-mappings.depth"
echo "Command: $cmd"
eval $cmd
echo `date`"  Running samtools depth finished."
echo "-------------------------------------------------"

## ====================================================
## Compute pileup
## ====================================================
echo `date`"  Running samtools mpileup..."
cmd="srun samtools mpileup \
    -d 1000000 \
    -o $TMP/${PREFIX}-$(basename $DB)-mappings.pileup \
    $TMP/${PREFIX}-$(basename $DB)-mappings.bam"
echo "Command: $cmd"
eval $cmd
echo `date`"  Running samtools mpileup finished."
echo "-------------------------------------------------"

## ====================================================
## Cleanup
## ====================================================
echo `date`"  Moving output files to $OUTDIR..."
srun mc cp $TMP/${PREFIX}-$(basename $DB)-mappings.bam $OUTDIR/
srun mc cp $TMP/${PREFIX}-$(basename $DB)-mappings.depth $OUTDIR/
srun mc cp $TMP/${PREFIX}-$(basename $DB)-mappings.pileup $OUTDIR/
srun rm -fr $TMP
echo `date`"  Moving output files to $OUTDIR finished."
echo "-------------------------------------------------"
