#!/usr/bin/perl -w

use Getopt::Std;
getopts "g:i:m:";


if ((!defined $opt_g)|| (!defined $opt_i)) {
    die "************************************************************************
    Usage: perl $0 -g group.txt -i cds.fasta
           -h : help
           -g : group file, one line for each group, e.g. AT1G00004 Sb3G000010 
           -i : cds.fasta
	   -m : model, YN for dicots and NG for monocots (default NG)
************************************************************************\n";
}else{
  print "************************************************************************\n";
  print "Version demo\n";
  print "Copyright to Tanger, tanger.zhang\@gmail.com\n";
  print "RUNNING...\n";
  print "************************************************************************\n";
        
     }

system("rm -rf axt_dir");
system("mkdir axt_dir");
system("rm -rf homo_dir");
system("mkdir homo_dir");
system("rm -rf kaks_result");
system("mkdir kaks_result");

open(PROC, "> proc") or die"";
print PROC "20";
close PROC;

my $group_file = $opt_g;
my $cds        = $opt_i;
my $model      = (defined $opt_m)?$opt_m:"NG";

my %cdsdb;
open(IN, $cds) or die"";
$/='>';
<IN>;
while(<IN>){
	chomp;
	my ($gene,$seq) = split(/\n/,$_,2);
	$gene =~ s/\s+.*//g;
	$seq  =~ s/\s+//g;
	$cdsdb{$gene} = $seq;
	}
close IN;

print "1. Generate cds/protein fasta files in cds_fasta/ and pro_fasta/\n";

system("rm -rf cds_fasta");
system("mkdir cds_fasta");
system("rm -rf pro_fasta");
system("mkdir pro_fasta");


open(OUT, "> run_convert.sh") or die"";
print OUT "#!/bin/bash\n";

open(IN, $group_file) or die"";
my $content = <IN>;
my @linedb = split(/\n/,$content);
foreach my $line(@linedb){
	my $label            = $line;
	$label               =~ s/\s+/_/g;
	my $cds_per_group    = $label."cds.fasta";
	my $pro_per_group    = $label."pro.fasta";
	open(my $out, ">cds_fasta/$cds_per_group");
	my @data = split(/\s+/,$line);
	next if(@data <= 1);
	foreach my $gene (@data){
		print $out ">$gene\n$cdsdb{$gene}\n";
		}
  close $out;
  system("cds2pro.pl cds_fasta/$cds_per_group > pro_fasta/$pro_per_group");
  print OUT "cds2axt.pl -i $label\n";

	}
close OUT;
print "....Done....\n";

print "2. converting to axt format ...\n";
system("sh run_convert.sh");
print "....Done....\n";

print "3. running Ka/Ks calculator ...\n";

while(my $axt_file = glob "axt_dir/*.cds_aln.axt"){
	$axt_file   =~ s/axt_dir\///g;
	my $kaks    = $axt_file;
	$kaks       =~ s/.cds_aln.axt//g;
	$kaks      .= ".kaks.txt";
	system("KaKs_Calculator -m $model -i axt_dir/$axt_file -o kaks_result/$kaks &>> run.log");
	}

print "....Done....\n";

print "4. combing results ...\n";
my %pairsdb;
open(IN, "cat kaks_result/* |grep -v 'Sequence'|") or die"";
$content = <IN>;
@linedb  = split(/\n/,$content);
foreach my $line(@linedb){
	my @data = split(/\s+/,$line);
	$pairsdb{$data[0]}->{'Ka'}      = $data[2];
	$pairsdb{$data[0]}->{'Ks'}      = $data[3];
  $pairsdb{$data[0]}->{'ratio'}   = $data[4];
  $pairsdb{$data[0]}->{'P'}       = $data[5];
  
	}
close IN;

open(OUT, "> group_kaks.txt") or die"";
open(IN, $group_file) or die"";
$content = <IN>;
@linedb = split(/\n/,$content);
foreach $line(@linedb){
	my @genedb      = split(/\s+/,$line);
	my $num_of_gene = @genedb;
	next if($num_of_gene<2);
	print OUT ">$line\n";
	my ($pairA,$pairB);
	for(my $i=0;$i<=$num_of_gene;$i++){
		for(my $j=$i+1;$j<$num_of_gene;$j++){
			$pairA  = $genedb[$i]."-".$genedb[$j];
			$pairB  = $genedb[$j]."-".$genedb[$i];
#			print OUT "$pairA\n";
			print OUT "$pairA	$pairsdb{$pairA}->{'Ka'}	$pairsdb{$pairA}->{'Ks'}	$pairsdb{$pairA}->{'ratio'}	$pairsdb{$pairA}->{'P'}\n" if(exists($pairsdb{$pairA}) and $pairsdb{$pairA} ne "NA");
	                print OUT "$pairB	$pairsdb{$pairB}->{'Ka'}	$pairsdb{$pairB}->{'Ks'}	$pairsdb{$pairB}->{'ratio'}	$pairsdb{$pairB}->{'P'}\n" if(exists($pairsdb{$pairB}) and $pairsdb{$pairB} ne "NA");
		}
		}
	}
close IN;
close OUT;
print "....Done....\n";

print "5. cleaning files ...\n";
system("rm -rf axt_dir");
system("rm -rf cds_fasta");
system("rm -rf homo_dir");
system("rm -rf pro_fasta");
print "....Finished....\n";


