# WGS_assembly_and_variant_calling

# Macroalga chloroplast comparative genomics

Code and documentation for chloroplast genome assembly, ORF identification,
annotation, and variant calling in a green macroalga, combining Illumina
short reads with Oxford Nanopore long reads.

## Pipeline overview

1. **Preliminary assembly** — GetOrganelle on short reads, used as a scaffold
   for read filtering
2. **Read filtering** — extract chloroplast-derived reads from both Illumina
   and Nanopore datasets
3. **Final meta-assembly** — performed on filtered reads (e.g. metaSPAdes)
4. **ORF identification** — EMBOSS `getorf` followed by BLASTp against NCBI nr
5. **Annotation** — via the GeSeq web utility
6. **Variant calling** — pileup-based, pool-seq style

---

## Step 1 — Preliminary chloroplast assembly

Quick draft assembly used for downstream read mapping and filtering.

```bash
sbatch scripts/getorganelle.sh \
  -f data/reads/macroalga_R1.fq.gz \
  -r data/reads/macroalga_R2.fq.gz \
  -o results/assembly \
  -d embplant_pt \
  -p macroalga-chloroplast
```

`-d embplant_pt` is the embryophyte plastid database — for non-embryophyte
green algae use `other_pt` instead (see GetOrganelle docs).

### Post-processing the draft

Three steps prepare the draft for read filtering:

1. **Rename FASTA header** to a stable identifier
2. **Double the sequence** end-to-end — allows paired-end reads spanning the
   circular junction to map concordantly
3. **Build a Bowtie2 index** on the doubled FASTA

The doubled assembly lives at
`results/assembly/macroalga-chloroplast-getorganelle`.

> Drop `sbatch` if not on a SLURM cluster — the script can be run directly.

---

## Step 2 — Filter chloroplast reads

Map all reads against the doubled draft and keep only the chloroplast hits.
This produces clean input for the final assembly and reduces the data
volume substantially.

**Illumina paired-end reads:**

```bash
sbatch scripts/assembly-based-filtering-illumina.sh \
  -f data/reads/macroalga_R1.fq.gz \
  -r data/reads/macroalga_R2.fq.gz \
  -d results/assembly/macroalga-chloroplast-getorganelle \
  -p macroalga \
  -o results/readfilt
```

**Nanopore long reads:**

```bash
sbatch scripts/assembly-based-filtering-minion.sh \
  -i data/reads/macroalga_minion.fq.gz \
  -d results/assembly/macroalga-chloroplast-getorganelle \
  -p macroalga \
  -o results/readfilt
```

---

## Step 3 — Final chloroplast meta-assembly

Using the filtered Illumina + Nanopore reads as input to a hybrid assembler
(e.g. metaSPAdes or MaSuRCA). Output: `results/assembly/macroalga-chloroplast-genome.fa`.

---

## Step 4 — Identify chloroplast ORFs

ORFs are predicted with EMBOSS `getorf` and annotated by BLASTp against
NCBI's non-redundant protein database (nr).

**Extract ORFs:**

```bash
mkdir -p results/getorfs
getorf \
  -circular Y \
  -reverse T \
  -sequence results/assembly/macroalga-chloroplast-genome.fa \
  -outseq results/getorfs/macroalga-chloroplast-orfs.faa
```

`-circular Y` accounts for ORFs spanning the circular start/end;
`-reverse T` includes the reverse strand.

**Build the NCBI nr database** (one-off, large download — several hundred GB):

```bash
cd ~/Databases/ncbi-nr
wget ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nr.gz
gzip -d nr.gz && mv nr nr.faa
makeblastdb -dbtype prot -in nr.faa
date > VERSION.txt
cd -
```

**Run BLASTp:**

```bash
blastp \
  -db ~/Databases/ncbi-nr/nr \
  -query results/getorfs/macroalga-chloroplast-orfs.faa \
  -outfmt 6 \
  > results/getorfs/macroalga-chloroplast-orfs.blastp.tsv
```

`-outfmt 6` gives a tab-separated table suitable for downstream parsing.

---

## Step 5 — Annotate the chloroplast genome

Annotation is done via the **GeSeq** web utility
(<https://chlorobox.mpimp-golm.mpg.de/geseq.html>), which is the de-facto
standard for organelle genome annotation and accepts the assembled FASTA
directly.

---

## Step 6 — Pool-seq variant calling

Pileup-based variant calling on the chloroplast-mapped Illumina reads:

```bash
sbatch scripts/depth-pileup-illumina.sh \
  -f results/readfilt/macroalga_R1_chloroplast-mapped.fq.gz \
  -r results/readfilt/macroalga_R2_chloroplast-mapped.fq.gz \
  -d results/assembly/macroalga-chloroplast-genome \
  -p macroalga \
  -o results/pileup
```

Output is a per-position pileup suitable for downstream variant frequency
analysis in a pool-sequencing context.

---

Attribution
Originally developed by **Evelien Jongepier** for *Caulerpa* chloroplast comparative genomics. This repository is a lightly modified adaptation of that workflow.
