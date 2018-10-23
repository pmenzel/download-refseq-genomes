# Download RefSeq genomes by taxon id

This script downloads all bacterial, Archaeal, or viral genomes
from the NCBI FTP server that belong to the taxonomy sub-tree denoted
by the taxon id given as argument.

For example:
```
./download-refseq-genomes.pl 203682
```
will download all Planctomycetes genomes.

The file type can be set using command line option -t using one of the values
`fna`, `faa`, or `gbff` (default),  for example:
```
./download-refseq-genomes.pl -t fna 203682
```

By default, only genomes with assembly_level "Complete Genome" are downloaded.
Setting option -a will download all genomes regardless of assembly level:
```
./download-refseq-genomes.pl -a -t fna 203682
```

The script will first download and parse the NCBI taxonomy. Next
it determines the major branch (i.e. Bacteria, Archaea or Viruses)
and download the list of genome assemblies for that branch.
Then this list is filtered by those genomes that are within the selected
taxonomic sub-tree and the genomes are downloaded with `wget`.

Copyright 2018 Peter Menzel <pmenzel@gmail.com>

