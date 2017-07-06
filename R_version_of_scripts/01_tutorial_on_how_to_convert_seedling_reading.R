rm(list=ls())
source('R_version_of_scripts/convert_rust_readings.R')

######## 

###(1) For seedling data conversion: ';13+', '3+', '13-' etc.
inputTypo = 'sample_data_seedling/typo.seedling.txt'
if (file.exists(inputTypo)){
    typo_seedling = read.delim(inputTypo,stringsAsFactors = F, head=F)
} else {
    cat("input typo file does not exist! You can use the one in the sample_data folder\n")
}



inputPheno = 'sample_data_seedling/TCAP_seedling.txt'
if (file.exists(inputPheno)){
    pheno = read.delim(inputPheno, 
                       skip=1, ## note: here skipped a header line 
                       stringsAsFactors = F)
    
} else {
    cat("input phenotype does not exist!\n")
}

### The columns to be processed
columns = c(8, 10)

############################## Finished loading data
d.converted = apply(pheno[,columns],2,convert_seedling)
colnames(d.converted) = paste0(colnames(pheno)[columns],'.num')
### data d.converted are converted seedling readings... New heading add suffix .num to original col names
d = cbind(pheno, d.converted)
d = d[,c(colnames(d)[1:5],  ## keep the first few columns as fixed
         sort(colnames(d)[6:ncol(d)]))  ### sort the remaining columns
      ]
write.table(d, file = 'sample_data_seedling/TCAP_seedling_R.out.txt', sep = '\t', quote=F, row.names = F)
######## Finished converting, sorting and writing data out to a new tab delimited file

