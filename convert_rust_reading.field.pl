#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use List::Util qw (sum);

####This is the "convert.rust_reading.field.pl" V1 ###Conversion method proposed by Dr. Matt Rouse, by double weight the first rust reading
#### Written bY Liangliang Gao (University of Minnesota) 6/22/2015; 
#Please cite Gao et al. GWAS paper (to be published, be patient) when using this script 
#This program takes a table of leaf or stem rust phenotype reading (field) and insert 3 columns to it (severity, response and COI). 
#This program is intended for technicians or rust researchers who have zero or little knowledge about perl or unix
#To use it, simply download this script to any linux system and type the command lines such as  "perl convert_rust_reading.field.pl --typo sr.typo.txt --pheno TCAP_field1.txt --columns 5,7"

#This program requires two tab-delimited files (easily produced by copying from excel ...); 
#Attention: It cannot directly take excel files; you must save your data into one or multiple .txt files
#(1) A human typo file to convert typos to standardized readings; the typo file should have two columns; 
	# col1 is your original typos; col2 is the thing that you want it to be; 
	# For exmaple, if you accidentally put 'Mr.Gao' into the reading, you can tell the program to treat it as 'na'; 
	# so the program won't somehow interpret it as "moderately resistant .Gao"; and come up with some numbers that don't make sense... The author tried his best to avoid any ambiguity in regular expression matching; However, it is still possible that someone typed something very "interesting and deceiving"; Thus, please use a typo file to correct that
#(2) The main phenotype file (need to tell the program which two columns are your phenotype readings to be converted; 
	# Pay special attention that Perl is different than some other languages such as R; 
	# It counts from 0, so --columns 5,7 means that the phenotype readings are in columns 6,8; 
	# The second reading (e.g. col 8) will be used to replace the 1st reading (given that there is a 2nd reading); 
	# You can always add an empty column full of 'NA' as the second reading

if ($#ARGV <5){ die "usage: perl convert_rust_reading.field.pl --typo typo.field.txt --pheno TCAP_field1.txt --columns 5,7"};
########## This line tells people that if the required files were not supplied, it will quit or die and ask for the required files; i.e., You must provide --typo, --pheno, and --columns to the program, this program force you to do so (sorry for inconvenience, you can easily write your own, if you know a little bit about perl, and make it less strict);
my ($typo,$pheno,$columns);
GetOptions ("typo=s"=>\$typo, "pheno=s"=>\$pheno, "columns=s"=>\$columns);

#1  pick out the typos or strange codes and convert them to standard codes... stored in a file called sr.na
sub convert_typo {
	open (IN, "< $typo"); ## 1st col typo 2nd col tstandard ...
	my %hash_typo;
	while (<IN>){$_=~s/[\r|\n]//g; my @F=split "\t"; if (@F == 2){$hash_typo{$F[0]}=$F[1]}}; 
	my $input=$_[0]; my $output="";
	if ($input eq ""){$input ="NA"};
	if (exists $hash_typo{$input}){$output=$hash_typo{$input}}else{$output=$input};
	return $output;
}

######### These are strange human typos that need to be taken care of ----> replacing with na or more standard readings...
#2 response type should be converted to numeric;

sub convert_mrs{
	my $it=$_[0];
	$it=~s/MR/X/g; $it=~s/MS/Y/g; 
		#using X to represent Moderately resistant; 
		#using Y to represent Moderately susceptible
	my @FF=split (//,$it);
	@FF=($FF[0],@FF);
	my %hash_rms=("R"=>0.2, "M"=>0.6, "S"=>1, "X"=>0.4,"Y"=>0.8);
		## This scale is based on  Stubbs 1986 Cereal disease mannual, published by CIMMYT
	my $flag="no"; ## set up a flag to scan if there is any non interpretable characters in response type reading
	foreach my $f (@FF){
		if (exists $hash_rms{$f}){
			$f=$hash_rms{$f}
		}else {
			$f='NA';
			$flag="yes"
		}
	};
	################# Added a flag and tested if any response type seems to be non interpretable characters.
	
	my $num_auto;
	if ($flag eq "no") {$num_auto=sum(@FF)/scalar(@FF)}else{$num_auto="NA"};
	if ($num_auto!~/NA/){$num_auto=sprintf("%.2f",$num_auto)};
	return $num_auto;
}






########### This is the response type numerically scaled;


#3  conversion of readings to numeric...
sub convert_sr{	
	my $sr=$_[0]; $sr=~s/[\r|\n]//g;
	my $orig_sr=$sr;
	$sr=&convert_typo($sr);
	$sr=~s/(Trace)|(Tr)|(T)/2/g; #### Here, we are replacing Trace and T readings into 2, which can be modified to be 1 or other small numbers
	$sr=~s/80\//80S/;$sr=~s/\///g;  ### I am replacing a reading specific for this TCAP_field file, 80/ to 80S/; this is a special case;
	$sr=~tr/a-z/A-Z/;  ## Translate small case to Capitalized case
	my ($sev,$it,$coi);
	if ($sr=~/NA/){
		#print "NA\tNA\tNA\tNA\n";
		$sev='NA';$it='NA';$coi='NA';	
		#### This is easy to understand, since NA is the field value, everything will be NA
	}elsif ($sr!~/\d/){
		#print "NA\t$sr\tNA\tNA\n";
		$sev='NA';$it=&convert_mrs($sr);$coi='NA';
		#### This says, if the reading does not contain any numbers, only response type (M,R,S) will be calculated
	}elsif ($sr!~/[R|M|S]/){
		#print "$sr\tNA\tNA\tNA\n"
		$sev=$sr;$it='NA';$coi='NA';
		### This says, if the reading does not contain any R, or M or S init, then only severity will be calculated
	}elsif ($sr=~/(\d+)([R|S|M]+)(\d+)([M|R|S]+)/){
		# print "$1\t$2\t$3\t$4\n"
		$sev=($1*2+$3)/3; my ($it1,$it2)=(&convert_mrs($2),&convert_mrs($4)); 
		$it=($it1*2+$it2)/3;$coi=$sev*$it;  
		### This says, if the reading contains segregating readings such as 35MR80S, it will 
		# doulbe the first severity reading and the first response reading, and take the weighted average
	}elsif ($sr=~/(\d+)([R|S|M]+)/){
		#print "$1\t$2\tna\tna\n";
		$sev=$1;$it=convert_mrs($2);$coi=$sev*$it;
		### This says, if the reading only has one reading (not segregating); then simply sev=sev; coi equals coi
	}else {
		#print "$sr not matched\n"
		$sev="NA";$it="NA";$coi="NA";
		## This says, if the reading has neither 'NA', nor any number, any combination of number and response in less than 3 segregation types; 
		# Replacing it with NA and report everything as NA
	}
	#print "$orig_sr\t$sev\t$it\t$coi\n";
	if ($sev!~/NA/){$sev=sprintf("%.2f",$sev)}; 
	if ($it!~/NA/) {$it=sprintf("%.2f",$it)};
	if ($coi!~/NA/){$coi=sprintf("%.2f",$coi)};
	my $num="$sev\t$it\t$coi";
	return $num;
}
############### Finished generating a hash data to store reading --> sev, it, coi info...

#########################
#4. This is the main program to convert pheno rust 1 and rust 2 and insert 3 columns at the end)...
my $file=$pheno; 
my ($prefix,$file_out); $prefix=$file; $prefix=~s/\.txt//;  $file_out=$prefix . "_out" . ".txt";
my ($col1,$col2); ## use these two variables to store the information of 1st and 2nd reading; again, please note that col numbers counting starts from 0 instead of 1
if ($columns=~/(\d+)\,(\d+)/){$col1=$1; $col2=$2} else {die "where are your columns for phenotype reading?\n"};

open (INPUT, "< $file");
open (OUT, "> $file_out");

my $header=<INPUT>; #Take header; please comment out this line (by putting a hash sign "#" in front of it) if there is no header line in your file(s)....
$header=~s/[\r|\n]//g; ### remove extra new line characters if any
my $new_header= "Prefix\tSeverity\tResponse\tCOI\t$header";
print OUT "$new_header\n";

while (<INPUT>){
	my $line =$_; $line=~s/[\r|\n]//g; 
	my @F=split (/\t/, $line);
	my ($rust1,$rust2)=@F[$col1,$col2];
	if ($rust2!~/NA/i){
		my $read2=&convert_sr($rust2);
		print OUT "$prefix\t$read2\t$line\n";	
		## This says, if there is a second reading, use that one as the reading for the genotype/line
	}else{
		my $read1=convert_sr($rust1); 
		print OUT "$prefix\t$read1\t$line\n";
		## This says, if there is no second reading, or 2nd reading is NA, use the first reading
	};
}
