rm(list=ls())
source('R_version_of_scripts/convert_rust_readings.R')
### (2) For field data conversion '35MRMS, 60/80S, 60MS/S' etc.
inputTypo = 'sample_data_field/typo.field.txt'
if (file.exists(inputTypo)){
    typo_field = read.delim(inputTypo,stringsAsFactors = F, head=F)
} else {
    cat("input typo file does not exist! You can use the one in the sample_data folder\n")
}


inputPheno = 'sample_data_field/pheno_LrAM381_summary_Liang2015.txt'
if (file.exists(inputPheno)){
    pheno = read.delim(inputPheno, 
                       stringsAsFactors = F)
    
} else {
    cat("input phenotype does not exist!\n")
}

### The columns to be processed
columns = c(6, 8)


########### Finished loading data and paramters
d.convert=pheno
for (c in columns){
        d.tmp = data.frame(convert_field(pheno[,c]))
        colnames(d.tmp) = paste0(colnames(pheno)[c],c('.sev','.it','.coi'))
        d.convert = data.frame(d.convert,d.tmp)
}
write.table(d.convert, file = 'sample_data_field/pheno_LrAM381_summary_Liang2015_R.out.txt', sep = '\t', quote=F, row.names = F)

