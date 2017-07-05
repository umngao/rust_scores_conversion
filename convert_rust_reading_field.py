#!/usr/bin/env python
import os
import re
import sys
import argparse

parser = argparse.ArgumentParser (description = "python convert_rust_reading_seedling.py --typo sample_data_seedling/typo.seedling.txt --PHENO  sample_data_seedling/TCAP_seedling.txt --columns 7,9")
parser.add_argument ('-t','--typo_f', help ="typo file, you can use the one supplied in the sample data folder")
parser.add_argument ('-p', '--PHENO', help ="phenotype file, tab delimited, ending with .txt, see sample_data for example")
parser.add_argument ('-c', '--columns', help ="columns of data to be converted, should be comma delimited, such as '3,4,5'")

if len(sys.argv)==1:
    parser.print_help()
    sys.exit(1)

args = parser.parse_args()

if os.path.exists(args.typo_f) and os.path.getsize(args.typo_f) > 0:
    typo_f=args.typo_f
else:
    sys.exit('the typo file is not thre! you can use the one in sample data folder')
if os.path.exists(args.PHENO) and os.path.getsize(args.PHENO) > 0:
    PHENO=args.PHENO
else:
    sys.exit('the phenotype file is not thre! provide tab delimited pheno file, ending .txt')
if re.search(r'[0-9]',args.columns):
    cols=args.columns
else:
    sys.exit("he columns should be specified! use coma separated values such as '3,4,5'")

###### 1. typo conversion
#typo_f = "sample_data_field/typo.field.txt"

def convert_typo(read):
    IN = open (typo_f, 'rU') ### This file should have 2 columns, col1 is typo, col2 is the standardized (correct) reading
    typo_dict = dict()
    for line in IN:
        line = line.rstrip()
        F = line.split(); 
        typ = F[0]; std=F[1]
        if len(F) == 2:
            typo_dict[typ] = std
    if read in typo_dict:
        read = typo_dict[read]
    return read
        
# print convert_typo("5") ### there should never be a 5 for IT (0-4 scale), 5 will be converted to NA
# print convert_typo("late")


##2. convert IT (infection type)
def convert_mrs (IT):
    orig_it = IT
    IT = convert_typo(IT)
    IT = IT.replace("MR",'X')
    IT = IT.replace('MS','Y')
    ITs = list(IT)
    if len(ITs)>0:
        ITs.insert(0, ITs[0])
    hash_mrs = {'R':0.2, 'M':0.6, 'S':1, 'X':0.4,'Y':0.8}
    flag = 1  ### set up a flag to scan if there are any non-interpretable characters
    num_ITs = list()
    for f in ITs:
        if f in  hash_mrs:
            flag =0
            num_ITs.append(hash_mrs[f])
    if flag == 0:
        num_IT = sum(num_ITs)/float(len(num_ITs))
        num_IT = round (num_IT, 2)  ###  rouding to 2 decimal points
    else:
        num_IT = "NA"
    return num_IT
        
# print convert_mrs('RMS')
# print convert_mrs('345')

### 3. conversion of readings to numeric
def convert_sr(read):
    read = convert_typo(read)
    read = re.sub('^t','T',read)  ### Some people prefer to use tr to represent TR, 
                                  ### capitalize first T to avoid confusion
    read = re.sub('(Trace)|(Tr)|T','2',read) ### replace trace R or TR with 2R (highly resistant ones)
    
    read = re.sub ('\s+','', read)
    read = read.upper()  ### upper case
    
    sev,it,coi = ('NA','NA','NA')
    if re.search(r'(\d+)[\/\\]+(\d+)([MRS]+)',read):
        matches = re.findall(r'(\d+)[\/\\]+(\d+)([MRS]+)',read)
        sr1,sr2,it1 =matches[0]
        sev = (int(sr1)*2+int(sr2))/3
        it = convert_mrs(it1)
        coi = sev*it
    elif re.search(r'(\d+)[\/\\]+(\d+)',read):
        matches = re.findall(r'(\d+)[\/\\]+(\d+)',read)
        sr1,sr2 =matches[0]
        sev = (int(sr1)*2+int(sr2))/3
    else:
        read = re.sub (r'[\/\\]+', "", read)
        if re.search('NA', read):
            sev = "NA" ### do nothing everything will be NA
        elif not re.search ('[0-9]', read):  ### else if  there are no numbers [0-9] in the read
            it = convert_mrs(read) ### coi and sev are NA by default
        elif not re.search ('[RMS]', read):
            sev = read
        elif re.search ('(\d+)([RMS]+)', read):
            matches = re.findall('(\d+)([RMS]+)',read)
            if len(matches) ==1:
                sr1, it1 = matches[0]
                sev = int(sr1); 
                it = convert_mrs(it1)
                coi = sev*it
            elif len(matches)==2:
                sr1,it1 = matches[0]
                sr2,it2 = matches[1]
                sev = (int(sr1)*2+int(sr2))/3
                it = (convert_mrs(it1)*2+convert_mrs(it2))/3
                coi = sev*it
    mylist = (read, str(sev), str(it), str(coi))
    my_join_val = "\t".join(mylist)
    return my_join_val

# print convert_sr('60')
# print convert_sr('Tr3')
# print convert_sr('MRS')
# print convert_sr('60MS30MR')


#4 main program

PHENO_OUT = PHENO.replace (".txt", ".python.out.txt")

cols = re.sub('\s+','',cols)   ### remove extra spaces if any (in column specification)
if re.search(',', cols):  ### if column numbers were specified with comma, split 
    cols = cols.split(","); 
    for i in range(len(cols)):
        cols[i]=int(cols[i])
else:
    cols =[int(cols)]   ### if there is only one value for column specification, cols =[cols]

########## assign cols using ARGV or mannually such as here.

InPheno = open (PHENO, 'rU')
out_file = open (PHENO_OUT, 'w')

header = InPheno.readline()  ### remove header
header = header.rstrip()
F = header.split("\t")

for col in cols:
    F[col] = F[col]+"\t"+F[col]+".sev" +"\t"+ F[col]+".it" +"\t" +F[col]+".coi"
print >>out_file, "\t".join(F)

for Line in InPheno:
    Line = Line.rstrip ()
    F = Line.split("\t")
    for col in cols:
        read = F[col]
        num_converted = convert_sr (read)
        F[col] = num_converted
    new_Line = "\t".join(F)
    print >>out_file, new_Line

InPheno.close()
out_file.close()    

