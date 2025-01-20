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

Additionally, genomes can be filtered by the RefSeq category "representative genome" or "reference genome" using option `-r`.

Files are downloaded with `wget`.

Copyright 2018 Peter Menzel <pmenzel@gmail.com>

