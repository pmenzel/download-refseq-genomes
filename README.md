# Download RefSeq genomes by taxon id

This script downloads all bacterial, Archaeal, or viral genomes (as gbff.gz
files) from the NCBI FTP server that belong to the taxonomy sub-tree denoted
by the taxon id given as argument.

For example:
```
./download-refseq-genomes.pl 203682
```
will download all Planctomycetes genomes.

Currently, only genomes with status "Complete Genome" are downloaded.

The script will first download and parse the NCBI taxonomy. Next
it determines the major branch (i.e. Bacteria, Archaea or Viruses)
and download the list of genome assemblies for that branch.
Then this list is filtered by those genomes that are within the select 
taxonomic sub-tree and the genomes are downloaded with `wget`.

Copyright 2018 Peter Menzel <pmenzel@gmail.com>

