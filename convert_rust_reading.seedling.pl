#!/usr/bin/perl -w
use strict;   ### This forces you to define a variable before you can use it; and it restricts your defined variables to be within their scopes/loops; i.e, the same variable $F might not interfere with another $F in a different loop
use Getopt::Long;  ## This enables the program to take long options such as --pheno; which makes it easier for people to understand which parameter matches which file
use List::Util qw (sum);  ## This enables the use of some functions such as "max,min, sum"; which saves you a little bit time on coding...

####This is the "convert_rust_reading.seedling.pl" V1 
###Conversion method proposed by Zhang et al 2014 Plos One 9(7) by taking the first and last reading, then double weight the first
#### Written by Liangliang Gao (University of Minnesota) 6/23/2015; 
#Please cite Gao et al. GWAS paper (to be published, be patient) when using this script 
#This program takes a table of leaf or stem or stripe rust phenotype reading (seedling) and insert additional columns to it.
#This program is intended for technicians or rust researchers who have zero or little knowledge about perl or unix
#To use it, simply download this script to any linux system and type the command lines such as  "perl convert_rust_reading.field.pl --typo sr.typo.txt --pheno TCAP_seedling.txt --columns "

#This program requires two tab-delimited files (easily produced by copying from excel ...); 
#Attention: It cannot directly take excel files; you must save your data into one or multiple .txt files
#(1) A human typo file to convert typos to standardized readings; the typo file should have two columns; 
	# col1 is your original typos; col2 is the thing that you want it to be; 
#(2) The main phenotype file (need to tell the program which columns are your phenotype readings to be converted; 
	# Pay special attention that Perl is different than some other languages such as R; 
	# It counts from 0, so --columns 5,7 means that the phenotype readings are in columns 6,8; 
	

if ($#ARGV <5){ die "usage: perl convert_rust_reading.field.pl --typo typo.seedling.txt --pheno TCAP_seedling.txt --columns 5,7,9,11,13,15,17"};
########## This line tells people that if the required files were not supplied, it will quit or die and ask for the required files; 
### i.e., You must provide --typo, --pheno, and --columns to the program, this program force you to do so 
### (sorry for inconvenience, you can easily write your own or modify this script, if you know a little bit about perl, and make it less strict and do more;

my ($typo,$pheno,$columns);
GetOptions ("typo=s"=>\$typo, "pheno=s"=>\$pheno, "columns=s"=>\$columns);

#1  This is a function or subroutine to pick out the typos or strange codes and convert them to standard codes... stored in a file called human.typo.txt
sub convert_typo {
	open (IN, "< $typo"); ## 1st col typo 2nd col standard ...
	my %hash_typo;
	while (<IN>){$_=~s/\r|\n//g; my @F=split "\t"; if (@F ==2) {$hash_typo{$F[0]}=$F[1]}}; 
	my $input=$_[0]; my $output="";
	if (exists $hash_typo{$input}){$output=$hash_typo{$input}}else{$output=$input};
	return $output;
}
######### These are strange human typos that need to be taken care of ----> replacing with na or more standard readings...


########### This is a function/subroutine for infection type (IT) numerically scaled;
#2  conversion of infection type (IT) to numeric...
sub convert_IT{	
	my $it=$_[0]; $it=~s/\r|\n//g;
	my $orig_it=$it;
	$it=&convert_typo($it);
	my $num_IT;
	if ($it=~/NA/){
		$num_IT='NA';  
		###### This is easy to understand if IT is NA, then num_IT is also NA
	}elsif($it=~/[0|;|1|2|3|4]/){
		######### So, if the IT seems to contain the 0-4 Stakman Scale (1962?), proceed with following
		$it=~s/\s+//g;  ## remove extra spaces; note g means global substitutions; all spaces will be removed
		$it=~s/\///g;  ## remove extra slashes ; similarly all slashes will be removed ...
		#############
		my %replace = (	"1-" => 'a', "1+" => 'b', "2-" => 'c', "2+" => 'd',"3-" => 'e',	"3+" => 'f');
		$it=~s/(1\-|1\+|2\-|2\+|3\-|3\+)/$replace{$1}||$1/e;
		######### Replacing comples double digits such as 1-, 1+, 2-, 2+ with single letters a, b, c, d...
		my @F=split (//,$it);  ### Then splitting into single digits
		@F=($F[0],@F);  ### Got the Infection type (IT) splitted (if it is a complex reading); and doubled the first
		########## Then double weight the first reading
		############### below is a hash or dictionary structure to store scales proposed by Zhang et al. 2014 PlosOne
		my %hash_IT =(
			"0"  => 0,
			";"  => 0,  
			"a"  => 1,  ## a represents 1-
			"1"  => 2,
			"b"  => 3,  ## b represents 1+
			"c"  => 4,  ## c represents 2-
			"2"  => 5,
			"d"  => 6,  ## d represents 2+
			"e"  => 7,  ## e represents 3-
			"3"  => 8,
			"f"  => 9,  ## f represents 3+
			"4"  => 9
		);
		## This 0-9 numeric scale was proposed and published by Zhang et al PLOS ONE 2014 9(7)
		
		my @numbers;
		foreach (@F){
			my $it=$_; if (exists $hash_IT{$it}){push (@numbers, $hash_IT{$it})}
			#### This says, if the elements exist in the 0-9 scales; then convert to numbers and store them into @numbers;
		};
		
		###After running the above loop; if there is something converted to numeric 0-9 scale; then do the math!
		if ($#numbers>0){
			$num_IT=sum(@numbers)/scalar(@numbers)
			###### This is the calculation of (reading1*2+reading2+reading3+.....)/(number of readings)
			###### This program tolerates unlimited number of readings per genotype;
		}else{
			$num_IT='NA'
		};  ### obviously, if nothing was converted to the 0-9 scale, then simply num_IT is NA;
		
		if ($num_IT!~/NA/){$num_IT=sprintf("%.2f", $num_IT)}; ### format the number to have 2 decimal digits
	}else {
		$num_IT = 'NA'
		##### This says, if original typing contains neither 'NA', nor any '0;1234' numbers; then treat it as NA
	}
	return $num_IT;
	###### Return $num_IT, no matter it is NA, or Numbers;
}
############### Finished generating a hash data to store seedling IT reading 


#########################
#3. This is the main program to convert seedling pheno (IT) and insert one additional column following each original data reading
my $file=$pheno; 
my ($prefix,$file_out); $prefix=$file; $prefix=~s/\.txt//;  $file_out=$prefix . "_out" . ".txt";
my @cols=split (/,/, $columns);

open (INPUT, "< $file");
open (OUT, "> $file_out");

my $header=<INPUT>; #Take header; please comment out this line (by putting a hash sign "#" in front of it) if there is no header line in your file(s)....
$header=~s/\r|\n//g; ### remove extra new line characters (if any)
my @spl_head=split(/\t/,$header);  ## splitting the header using tabs

foreach (@cols){
	my $col=$_; $col=~s/\r|\n//g;
	my $orig_head = $spl_head[$col]; my $num_head=$spl_head[$col].".num"; 
	$spl_head[$_]="$orig_head\t$num_head";
}
####### For each col, if it is a column with rust readings, add additional column next to it named such as 'BBBCC.NUM'


my $join_spl_header=join("\t",@spl_head);
print OUT "$join_spl_header\n";
#### Then join the header again and print it to file > file_out.txt

## Now do the same thing for each actual data
while (<INPUT>){
	my $line =$_; $line=~s/\r|\n//g; ## take the line and remove extra newline characters such as "\n" or "\r"
	my @F=split (/\t/, $line);  ## split each reading line using tabs
	
	##########################################
	for my $col (@cols) {
		my $orig_IT=$F[$col]; ###?
		my $num_IT = &convert_IT ($orig_IT); 
		$F[$col] = "$orig_IT\t$num_IT";  ##?
	} 
	#################### This for loop, will calculate num_IT for each specified reading 
	#################### then add a column next to each specified rust columns (IT)	
		
	##### OK after finishing the data generation, merge them back to a complete line and print ...
	my $new_line = join ("\t", @F);
	print OUT "$new_line\n";
	########## Join the new line and print it to output
}


