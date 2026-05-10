| Script                                | Stage                         | Purpose                                              | 
|---------------------------------------|-------------------------------|------------------------------------------------------|
| getorganelle.sh                       | Step 1 — preliminary assembly | wrapper around GetOrganelle for short-read input     |
| assembly-based-filtering-illumina.sh  | Step 2 — read filtering       | maps Illumina pairs to draft, keeps mapped reads     |
| assembly-based-filtering-minion.sh    | Step 2 — read filtering       | maps Nanopore reads to draft, keeps mapped reads     |
| depth-pileup-illumina.sh              | Step 6 — variant calling      | depth + pileup generation from filtered Illumina BAM |
