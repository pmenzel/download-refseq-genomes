#!/usr/bin/env perl

# This script downloads all RefSeq genome assemblies
# from the NCBI FTP server that belong to the taxonomy sub-tree denoted
# by the taxon id given as argument.
#
# For example:
# ./download-refseq-genomes.pl 203682
# will download all Planctomycetes genomes.
#
# The file type can be set using command line option -t using one of the values
# "fna", "faa", "gff", or "gbff" (default).
#
# By default, only genomes with assembly_level "Complete Genome" are downloaded.
# Setting option -a will download all genomes regardless of assembly level.
#
# Copyright 2018,2019 Peter Menzel <pmenzel@gmail.com>


use warnings;
use strict;
use Getopt::Std;
use Term::ANSIColor;

my %options=();
getopts("t:a", \%options);

my %nodes;
my $arg_taxid = 1;
my %allowed_filetypes = ( "gbff" => "_genomic.gbff.gz", "fna" => "_genomic.fna.gz", "faa" => "_protein.faa.gz", "gff" => "_genomic.gff.gz" );
my $filetype = "gbff";

# switch for selecting only assemblies with "Complete Genome" (default) or all types
my $assembly_level_all = 0;
if(exists($options{a})) {
	print STDERR "Genome completeness: all\n";
	$assembly_level_all = 1;
}
else {
	print STDERR "Genome completeness: Complete Genome\n";
}

if(exists($options{t})) {
	if(defined($options{t}) && $options{t} =~ /gbff|fna|faa|gff/) {
		$filetype = $options{t};
		print STDERR "File type: $filetype\n";
	}
	else {
		die("Option -t must be set to one of {",join(", ",keys(%allowed_filetypes)),"}.\n");
	}
}
else {
	print STDERR "File type: gbff\n";
}

my $url_ext = $allowed_filetypes{$filetype};

if(!defined $ARGV[0]) { die "Usage:  download_refseq_genomes.pl <taxon id>\n"; }
$arg_taxid = $ARGV[0];

my $assembly_summary = "http://ftp.ncbi.nlm.nih.gov/genomes/refseq/assembly_summary_refseq.txt";

sub is_ancestor {
	my $id = $_[0];
	my $parent = $_[1];
	if(!defined $nodes{$id}) { print STDERR "Taxon ID $id not found in nodes.dmp!\n"; return 0; }
	if(!defined $nodes{$parent}) { print STDERR "Taxon ID $parent not found in nodes.dmp!\n"; return 0; }
	while(defined $nodes{$id} && $id != $nodes{$id}) {
		if($id==$parent) { return 1; }
		$id = $nodes{$id};
	}
	return 0;
}

sub get_lineage {
	my $id = $_[0];
	my @lineage;
	#use nodes for traversing lineage to root of tree and create a stack
	if(!defined $nodes{$id}) { print STDERR "Taxon ID $id not found in nodes.dmp!\n"; push @lineage, $id; return @lineage; }
	unshift @lineage,$id;
	while(defined $nodes{$id} && $id != $nodes{$id}) {
		unshift(@lineage,$nodes{$id});
		$id = $nodes{$id};
	}
	#return the stack with the lineage IDs, where root node should be the first element of the stack
	if($lineage[0] != 1) { die "Root node is not 1, but is $lineage[0]\n";}
	return @lineage;
}

#test if option --show-progress is available for wget, then use it when downloading
my $wgetProgress = " ";
my @wgethelp = `wget --help`;
if(grep(/--show-progress/, @wgethelp)) { $wgetProgress=' --show-progress '; }

print STDERR "Downloading file taxdump.tar.gz\n";
system('wget -N -nv '.$wgetProgress.' http://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz');

if(! -r "taxdump.tar.gz") { print STDERR "Missing file taxdump.tar.gz"; exit 1; }

#print STDERR "Extracting nodes.dmp from taxdump.tar.gz\n";
#system('tar xf taxdump.tar.gz nodes.dmp');
print STDERR "Reading nodes.dmp from taxdump.tar.gz\n";

open(NODES,"gunzip -c taxdump.tar.gz | tar -O -xf - nodes.dmp |") or die "Cannot open nodes.dmp\n";
while(<NODES>) {
	my @F = split(/\|/,$_);
	if($#F > 1) {
		my $id = -+- $F[0];
		my $parentid = -+- $F[1];
		$nodes{$id} = $parentid;
	}
}
close(NODES);

#check if argument taxid is in tree
if(!defined($nodes{$arg_taxid})) { die "Taxon ID $arg_taxid is not found in taxonomy!\n"; }

print STDERR "Downloading assembly summary\n";
system('wget -N -c -nv'.$wgetProgress.$assembly_summary);
if($? != 0) { die "Error: Failed  to download $assembly_summary.\n"; }

print STDERR "Parsing assembly summary\n";
open(ASSS,"assembly_summary_refseq.txt") or die "Cannot open assembly_summary_refseq.txt\n";
my @download_list;
while(<ASSS>) {
	next if /^#/;
	my @F = split(/\t/,$_);
	if($#F < 19) { print STDERR "Warning: Line $. has less than 20 fields, skipping...\n"; next; }
	next unless $assembly_level_all || $F[11] eq "Complete Genome";
	my $taxid = $F[5];
	if(!defined($nodes{$taxid})) { print STDERR "Warning: Taxon ID $taxid not found in taxonomy.\n"; next; }
	if(is_ancestor($taxid,$arg_taxid)) {
	  if($F[19] ne "na") {
		  push(@download_list,$F[19]);
		}
		else { print STDERR "Warning: No download URL for assembly $F[0]\n"; }
	}
}
close(ASSS);

print colored("\nDownloading ".scalar(@download_list). " genomes for taxon ID $arg_taxid\n\n","green");
foreach my $l (@download_list) {
	my @F = split(/\//,$l);
	print STDERR "Downloading ", $F[-1],"\n";
	my $path = $l.'/'.$F[-1].$url_ext;
	my $cmd = 'wget -P genomes/ -nc -nv '.$path;
	`$cmd`;
	if($? != 0) { print STDERR "Error downloading $path\n";}
}

