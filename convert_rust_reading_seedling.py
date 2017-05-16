#!/usr/bin/env python

import re
import sys
import getopt

opts, args = getopt.getopt(sys.argv[1:], 't:p:c', ['typo_f=','PHENO=','cols='])

def usage():
    print "python convert_rust_reading_seedling.py --typo sample_data_seedling/typo.seedling.txt --PHENO  sample_data_seedling/TCAP_seedling.txt --cols 7,9"
    
if len(opts)<2:  ### if there are less than 2 arguments, exit and print usage
    usage()
    sys.exit(2)
    
for opt, arg in opts:
    if opt in ('-h', '--help'):
        usage()
        sys.exit(2)
    elif opt in ('-t','--typo_f'):
        typo_f = arg
    elif opt in ('-p', '--PHENO'):
        PHENO = arg
    elif opt in ('-c', '--cols'):
        cols = arg
    else:
        usage()
        sys.exit(2)

###### 1. typo conversion

def convert_typo(read):
    IN = open (typo_f, 'rU') ### This file should have 2 columns, col1 is typo, col2 is the standardized (correct) reading
    typo_dict = dict()
    for line in IN:
        line = line.strip("\r\n")
        F = line.split(); 
        typ = F[0]; std=F[1]
        if len(F) == 2:
            typo_dict[typ] = std
    if read in typo_dict.keys():
        read = typo_dict[read]
    return read
        
# print convert_typo("5") ### there should never be a 5 for IT (0-4 scale), 5 will be converted to NA
# print convert_typo("3+")


##2. convert IT (infection type)
def convert_IT (IT):
    IT = IT.replace('\r\n','')
    orig_it = IT
    IT = convert_typo(IT)
    if re.search('NA',IT):
        num_IT = "NA"
    elif re.search('[01234\;]',IT):
        IT = re.sub('\s+',"", IT)
        IT = re.sub ('\/',"", IT)
        IT = IT.replace("1-", 'a')
        IT = IT.replace("1+", 'b')
        IT = IT.replace("2-", 'c')
        IT = IT.replace("2+", 'd')
        IT = IT.replace("3-", 'e')
        IT = IT.replace("3+", 'f')
        fields = list(IT)
        fields = [fields[0]] + fields ### double weight the first element
        dict_IT = {'0':0, ';':0, 'a':1, '1':2, 'b':3, 'c':4,'2':5,'d':6,'e':7,'3':8,'f':9,'4':9}
        numbers =list()
        for num in fields:
            if dict_IT.has_key(num):
                numbers.append(dict_IT[num])
        if len(numbers) >0:
            num_IT = sum(numbers)/float(len(numbers))
            num_IT = round (num_IT, 2)  ###  rouding to 2 decimal points
    else:
        num_IT = "NA"
    return num_IT
        
# print convert_IT('4   3-3+2-;')

#3 main program

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
header = header.strip('\r\n')
F = header.split("\t")

for col in cols:
    F[col] = F[col]+"\t"+F[col]+".num"
print >>out_file, "\t".join(F)

for Line in InPheno:
    Line = Line.strip ('\r\n')
    F = Line.split("\t")
    for col in cols:
        IT = F[col]
        num_IT = convert_IT (IT)
        F[col] = IT+"\t"+str(num_IT)
    new_Line = "\t".join(F)
    print >>out_file, new_Line

InPheno.close()
out_file.close()    

