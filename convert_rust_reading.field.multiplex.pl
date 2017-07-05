#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use List::Util qw (sum);

# This is a modifed script for "convert.rust.reading.field.pl" to add multiplexibility to it. So, now it takes practically unlimited columns of field rust traits.

if (@ARGV != 6){ die "usage: perl convert_rust_reading.field.multiplex.pl --typo sample_data_field/typo.field.txt --pheno sample_data_field/pheno_LrAM381_summary_Liang2015.txt --columns 3,4,5,6,7"};
########## This line tells people that if the required files were not supplied, it will quit or die and ask for the required files; i.e., You must provide --typo, --pheno, and --columns to the program, this program force you to do so (sorry for inconvenience, you can easily write your own, if you know a little bit about perl, and make it less strict);

my ($typo,$pheno,$columns);
GetOptions ("typo=s"=>\$typo, "pheno=s"=>\$pheno, "columns=s"=>\$columns);

die "input_typo_file[$typo] is not there, please specify a typo file, you can use the provided typo file within sample_data folders\n" unless -s $typo;
die "input_pheno_file[$pheno] is not there\n" unless -s $pheno;
die "input_columns[$columns] is not there, you must specify columns data to be converted in coma separated fashion such as '3,4,5'\n" unless $columns=~ m/[\d]/;


#1  pick out the typos or strange codes and convert them to standard codes... stored in a file called sr.na
sub convert_typo {
	open (IN, "< $typo"); ## 1st col typo 2nd col tstandard ...
	my %hash_typo;
	while (<IN>){$_=~s/\r|\n//g; my @F=split "\t"; if (@F >= 2){$hash_typo{$F[0]}=$F[1]}}; 
	my $input=$_[0]; my $output="";
	if ($input eq ""){$input = 'NA'};
	if (exists $hash_typo{$input}){$output=$hash_typo{$input}}else{$output=$input};
	close (IN);
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
	my $sr=$_[0]; $sr=~s/\r|\n//g;
	my $orig_sr=$sr;
	$sr=&convert_typo($sr);
    $sr=~s/^t/T/g; ### beginning T should be capitalized .... Note Tr(ace) vs TR
	$sr=~s/(Trace)|(Tr)|(T)/2/g; #### Here, we are replacing Trace and T readings into 2, which can be modified to be 1 or other small numbers
	$sr=~s/\s+//g; 
	$sr=~tr/a-z/A-Z/;  
	my ($sev,$it,$coi);
	if ($sr=~/(\d+)[\/|\\]+(\d+)([M|R|S]+)/){
		$sev = ($1*2+$2)/3;
		$it=&convert_mrs($3);
		$coi = $sev*$it;
	}elsif ($sr=~/(\d+)[\/|\\]+(\d+)/){
		$sev = ($1*2+$2)/3;
		$it = "NA";
		$coi = "NA"
	}else {
		$sr=~s/[\/|\\]+//g;
		## Translate small case to Capitalized case
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
			$sev=$1;$it=&convert_mrs($2);$coi=$sev*$it;
			### This says, if the reading only has one reading (not segregating); then simply sev=sev; coi equals coi
		}else {
			#print "$sr not matched\n"
			$sev="NA";$it="NA";$coi="NA";
			## This says, if the reading has neither 'NA', nor any number, any combination of number and response in less than 3 segregation types; 
			# Replacing it with NA and report everything as NA
		}
	}#print "$orig_sr\t$sev\t$it\t$coi\n";
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
my @cols;
if ($columns=~/,/) {@cols=split (/,/, $columns)} elsif($columns=~/\d+/){@cols=($columns)} else {print "you need to speciy comma separated column numbers\n"; exit;};


open (INPUT, "< $file");
open (OUT, "> $file_out");

my $header=<INPUT>; #Take header; please comment out this line (by putting a hash sign "#" in front of it) if there is no header line in your file(s)....
$header=~s/\r|\n//g; #### remove extra new lines
my @spl_head=split(/\t/,$header);  ## splitting the header using tabs

foreach (@cols){
	my $col=$_; $col=~s/\r|\n//g;
	my $orig_head = $spl_head[$col]; 
	$spl_head[$_]="$orig_head\t$orig_head.sev\t$orig_head.it\t$orig_head.coi";
}

my $join_spl_header=join("\t",@spl_head);
print OUT "$join_spl_header\n";


while (<INPUT>){
	my $line =$_; $line=~s/\r|\n//g; 
	my @F=split (/\t/, $line);
	if (@F ==0){next}  ### skip empty lines
	for my $col (@cols) {
		my $orig_rust=$F[$col]; ###?
		my $num_rust = &convert_sr($orig_rust); 
		$F[$col] = "$orig_rust\t$num_rust";  ##?
	} 
	my $new_line = join ("\t", @F);
	print OUT "$new_line\n";
}
