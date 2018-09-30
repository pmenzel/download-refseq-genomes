#!/usr/bin/env perl

# This script downloads all bacterial, Archaeal, or viral genomes (as gbff.gz
# files) from the NCBI FTP server that belong to the taxonomy sub-tree denoted
# by the taxon id given as argument.
#
# For example:
# ./download-refseq-genomes.pl 203682
# will download all Planctomycetes genomes.
#
# The file type can be set using command line option -t using one of the values
# "fna", "faa", or "gbff" (default).
#
# Currently, only genomes with status "Complete Genome" are downloaded.
#
# Copyright 2018 Peter Menzel <pmenzel@gmail.com>


use warnings;
use strict;
use Getopt::Std;

my %options=();
getopts("t:", \%options);

my %nodes;
my $arg_taxid = 1;
my %allowed_filetypes = ( "gbff" => "_genomic.gbff.gz", "fna" => "_genomic.fna.gz", "faa" => "_protein.faa.gz" );
my $filetype = "gbff";

if(exists($options{t})) {
	if(defined($options{t}) && $options{t} =~ /gbff|fna|faa/) {
		$filetype = $options{t};
	}
	else {
		die("Option -t must be set to one of {",join(", ",keys(%allowed_filetypes)),"}.\n");
	}
}

my $url_ext = $allowed_filetypes{$filetype};

if(!defined $ARGV[0]) { die "Usage:  download_refseq_genomes.pl <taxon id>\n"; }
$arg_taxid = $ARGV[0];
if($arg_taxid==131567 or $arg_taxid==1) { die "Please choose a taxid within Archaea, bacteria, or viruses.\n"; }

my %assembly_summaries = (
 2 => "ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/bacteria/assembly_summary.txt",
 2157 => "ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/archaea/assembly_summary.txt",
 10239 => "ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/viral/assembly_summary.txt");

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
my $wgetProgress = "";
my @wgethelp = `wget --help`;
if(grep(/--show-progress/, @wgethelp)) { $wgetProgress=' --show-progress '; }

print "Downloading file taxdump.tar.gz\n";
system('wget -N -nv '.$wgetProgress.' ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz');

if(! -r "taxdump.tar.gz") { print "Missing file taxdump.tar.gz"; exit 1; }

print "Extracting nodes.dmp from taxdump.tar.gz\n";
system('tar xf taxdump.tar.gz nodes.dmp');
print "Reading nodes.dmp\n";

open(NODES,"nodes.dmp") or die "Cannot open nodes.dmp\n";
while(<NODES>) {
	chomp;
	my @F = split(/\|/);
	if($#F > 1) {
		my $id = -+- $F[0];
		my $parentid = -+- $F[1];
		$nodes{$id} = $parentid;
	}
}
close(NODES);

#check if argument taxid is in tree
if(!defined($nodes{$arg_taxid})) { die "Taxon ID $arg_taxid is not found in taxonomy!\n"; }

my @l = get_lineage($arg_taxid);
my $branch = $l[1];
if($branch==131567) {$branch=$l[2];}
if(!defined($assembly_summaries{$branch})) { die "Cannot determine major branch from taxon id $branch in lineage @l\n"; }

print "Downloading assembly summary\n";
system('wget -N -nv'.$wgetProgress.$assembly_summaries{$branch});
if(! -r "assembly_summary.txt") { print "Missing file assembly_summary.txt"; exit 1; }

open(ASSS,"assembly_summary.txt") or die "Cannot open assembly_summary.txt\n";
my $firstline=<ASSS>;
my @download_list;
while(<ASSS>) {
	chomp;
	my @F = split(/\t/);
	next unless $#F > 10;
	next unless $F[11] eq "Complete Genome";
	my $taxid = $F[5];
	if(!defined($nodes{$taxid})) { print "Warning: Taxon ID $taxid not found in taxonomy.\n"; next; }
	if(is_ancestor($taxid,$arg_taxid)) {
	  push(@download_list,$F[19]);
	}
}
close(ASSS);

print "Downloading ", scalar(@download_list), " genomes.\n\n";
foreach my $l (@download_list) {
	my @F = split(/\//,$l);
	print "Downloading ", $F[-1],"\n";
	my $path = $l.'/'.$F[-1].$url_ext;
	system('wget -N -nv'.$wgetProgress.$path);
}

