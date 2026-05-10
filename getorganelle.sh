#!/bin/bash
#SBATCH --job-name=gorg
#SBATCH --output=logs/%x-%u-%A-%a.log
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --time=12000
#SBATCH --mem=360G

####################################################
# HELP                                             #
####################################################
usage="
Run GetOrganelle assembly from paired-end Illumina reads.

sbatch scripts/$(basename "$0") [-h|-f|-r|-o|-d|-p]

where:
    -h  show this help text
    -f  path to Illumina fwd reads (fastq.gz)
    -r  path to Illumina rev reads (fastq.gz)
    -o  output directory
    -d  GetOrganelle database (e.g. embplant_pt, other_pt, embplant_mt)
    -p  output prefix (e.g. species-organelle)

examples:
# Plastid assembly:
sbatch scripts/getorganelle.sh \\
    -f data/reads/macroalga_R1.fq.gz \\
    -r data/reads/macroalga_R2.fq.gz \\
    -o results/assembly \\
    -d embplant_pt \\
    -p macroalga-chloroplast

# Mitochondrion assembly:
sbatch scripts/getorganelle.sh \\
    -f data/reads/macroalga_R1.fq.gz \\
    -r data/reads/macroalga_R2.fq.gz \\
    -o results/assembly \\
    -d embplant_mt \\
    -p macroalga-mitochondrion
"

while getopts ':h:f:r:o:d:p:' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    f) FWDPATH="${OPTARG}"
       ;;
    r) REVPATH="${OPTARG}"
       ;;
    o) OUTDIR="${OPTARG}"
       ;;
    d) DB="${OPTARG}"
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
echo "Command: sbatch $(basename "$0") -f $FWDPATH -r $REVPATH -o $OUTDIR -d $DB -p $PREFIX"
echo "-------------------------------------------------"

## =================================================
## Environment
## =================================================
source ~/miniconda3/etc/profile.d/conda.sh
conda activate assembly

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
echo `date`"  Collecting input data finished."
echo "-------------------------------------------------"

## =================================================
## Run GetOrganelle
## =================================================
echo `date`"  GetOrganelle started..."
mkdir -p $TMP/$PREFIX

# -R 30:           extension rounds (raise for low coverage)
# -k 21,45,65,...: k-mer ladder
# --reduce-reads-for-coverage inf / --max-reads inf: disable read subsampling
cmd="srun get_organelle_from_reads.py \
    -1 $TMP/$(basename $FWDPATH) \
    -2 $TMP/$(basename $REVPATH) \
    -o $TMP/$PREFIX \
    -t $SLURM_CPUS_ON_NODE \
    -F $DB \
    -R 30 \
    -k 21,45,65,85,105 \
    --overwrite \
    --reduce-reads-for-coverage inf \
    --max-reads inf"
echo "Command: $cmd"
eval $cmd
echo `date`"  GetOrganelle finished."
echo "-------------------------------------------------"

## =================================================
## Archive and copy output
## =================================================
echo `date`"  Archiving and moving data..."
srun mv $TMP/${PREFIX} $TMP/${PREFIX}-getorganelle-run

# Exclude bulky intermediate FASTQs from the archive
srun tar \
    --exclude="${PREFIX}-getorganelle-run/extended_*paired.fq" \
    -czvf $TMP/${PREFIX}-getorganelle-run.tar.gz \
    -C $TMP ${PREFIX}-getorganelle-run

srun mc cp $TMP/${PREFIX}-getorganelle-run.tar.gz $OUTDIR/
srun rm -fr $TMP
echo `date`"  Archiving and moving data finished."
echo "-------------------------------------------------"

echo `date`" All done!"
echo "$SLURM_JOB_NAME finished on node $SLURM_NODEID using $SLURM_CPUS_ON_NODE cpus."
####################################################
# THE END                                          #
####################################################
