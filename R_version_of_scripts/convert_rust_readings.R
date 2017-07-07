
convert_field = function(x, typo=typo_field){
        ## Written by Liangliang Gao (lgao@umn.edu) 2017/07/06, as companion script to the Perl or Python versions
        ## You can cite Gao et al, 2016 PLoS One paper PLoS One 11:e0148671 for the method
        ## This function requires a column/vector of field rust reading, containing characters [0-9][MRS][-winteR][7jS][dry][type] etc. 
        ## and a typo data, column1 is orig_read, column is replace to ... You can use the typo file in the sample data folder
        ## The output is a list of three numeric vectors Severity, Infection Type and Coefificnet of infection (See Gao PloS One 216 for details on how they were calculated).   
        
        colnames(typo)[1:2] = c('orig_read','replace_to')
        #x = c("10R",'TraceR','tR','Tr3', "10RMR",  "10MRMS",'es')
        #### (I) replace orig_reading with replaced values based on the typo file
        tmp.x = mapvalues(x, from = c(typo$orig_read), to = c(typo$replace_to), warn_missing = F)
        
        ### (II) convert_mrs function to convert MRS into numeric scales based on 1986 CIMMYT mannuals 
        convert_mrs = function(IT){
                IT = toupper(IT)
                IT = gsub('X','',IT)
                IT = gsub('Y', '', IT)
                IT = gsub('MR','X', IT)
                IT = gsub('MS','Y', IT)
                
                mylist = strsplit(IT,'')
                
                calc_mrs = function(y){
                        y = c(y[1],y) ## double weight the first IT type
                        y = y[y %in% c('R','M','S','X','Y')]
                        ## This step removes all non-convertable characters, such as 'E', '--', '.', '' etc.
                        ## Not sure if this is the best way to handle the situation. sometimes, people do make typos like 'MRT', 
                        y = mapvalues(y, from = c('R','M','S','X','Y'),
                                      to = c(0.2, 0.6, 1, 0.4, 0.8),
                                      warn_missing = F
                        )
                        num_IT = round(mean(as.numeric(y)),2)
                        return(num_IT)
                }
                
                NUM = calc_mrs(unlist(mylist))
                return(NUM)
        }
        #convert_mrs('RMS')   0.4
        #convert_mrs('345')  NaN
        #convert_mrs('MR') 0.4
        #convert_mrs('X') 0.4 ######## Is this what people wanted? probably not. Fix it!
        #convert_mrs('X') Nan fixed
        
        
        ### (III) convert_read function to convert the complete cell value such as '35MRMS60S' into three values Sev, IT, COI
        tmp.x = gsub(' ', '',  tmp.x) 
        tmp.x = gsub('^t', 'T',  tmp.x) 
        tmp.x = gsub('Trace|Tr|T', '2',  tmp.x) 
        
        sev.vec=c(); it.vec=c(); coi.vec=c();
        
        for (i in seq_along(tmp.x)){
                read = tmp.x[i]
                if (grepl('^(\\d+)\\/(\\d+)([MRS]?)',read)){
                        sev1 = sub('^(\\d+)\\/(\\d+)([MRS]?)','\\1',read)
                        sev2 = sub('^(\\d+)\\/(\\d+)([MRS]?)','\\2',read)
                        sev = c(sev1,sev1,sev2)
                        sev = mean(as.numeric(sev))
                        it = convert_mrs(sub('^(\\d+)\\/(\\d+)([MRS]?)','\\3',read))
                        coi = sev*it
                }else {
                        read = gsub('\\/','',read)
                        if (grepl('NA',read)){
                                sev =NA; coi=NA; it=NA
                        }else if (!grepl('[0-9]', read)){
                                sev=NA; coi=NA; it=convert_mrs(read)
                        }else if (!grepl('[RMS]', read)){
                                sev=suppressWarnings(as.numeric(read))
                                coi = NA; it =NA;
                        }else if (grepl('(\\d+)([MRS]+)(\\d+)([MRS]+$)', read)){
                                sev1 = sub('^(\\d+)([MRS]+)(\\d+)([MRS]+$)','\\1',read)
                                it1 = convert_mrs(sub('^(\\d+)([MRS]+)(\\d+)([MRS]+$)','\\2',read))
                                sev2 = sub('^(\\d+)([MRS]+)(\\d+)([MRS]+$)','\\3',read)
                                it2 = convert_mrs(sub('^(\\d+)([MRS]+)(\\d+)([MRS]+$)','\\4',read))
                                sev = mean(as.numeric(c(sev1,sev1,sev2)))
                                it = mean(as.numeric(c(it1,it1,it2)))
                                coi = sev*it
                                
                        }else if (grepl('(\\d+)([MRS]+$)', read)){
                                sev = as.numeric(sub('^(\\d+)([MRS]+)','\\1',read))
                                it = convert_mrs(sub('^(\\d+)([MRS]+)','\\2',read))
                                coi = sev*it
                        }else{
                                sev = NA; it = NA; coi =NA;
                        }
                }
                sev.vec = c(sev.vec, sev)
                it.vec = c(it.vec, it)
                coi.vec = c(coi.vec, coi)
        }
        
        return(list(sev.vec=round(sev.vec,2), it.vec=round(it.vec,2), coi.vec=round(coi.vec,2)))
        
}



convert_seedling = function(x, typo=typo_seedling){
        ## Written by Liangliang Gao (lgao@umn.edu)  2017/07/06, as companion script to the Perl or Python versions
        ## You can cite Gao et al, 2016 PLoS One paper PLoS One 11:e0148671 for the method
        ## This function requires a column/vector of seedling rust reading, containing characters [0|1|2|3|4|;|+|-], 
        ## preferably no other characters. Even if it does contain other characters, such as Esc, seg etc. it will be ignored.
        ## and a typo data, column1 is orig_read, column is replace to ... You can use the typo file in the sample data folder
        ## The output is a numeric vector
        
        colnames(typo)[1:2] = c('orig_read','replace_to')
        #x = c('na',5, 3.44, 6, 9, '1  /3+','; 1     ','(X);13','3',';','es')
        #### (I) replace orig_reading with replaced values based on the typo file
        tmp.x = mapvalues(x, from = c(typo$orig_read), to = c(typo$replace_to), warn_missing = F)
        tmp.x = toupper(tmp.x)
        
        ### (II) replace strings and split strings, do weighted calculation
        tmp.x = gsub(' ', '',  tmp.x) ## remove all spaces
        tmp.x = gsub('\\/','', tmp.x)
        tmp.x = gsub('[A-Z]','', tmp.x)
        tmp.x = gsub('1\\-','a', tmp.x)
        tmp.x = gsub('1\\+','b', tmp.x)
        tmp.x = gsub('2\\-','c', tmp.x)
        tmp.x = gsub('2\\+','d', tmp.x)
        tmp.x = gsub('3\\-','e', tmp.x)
        tmp.x = gsub('3\\+','f', tmp.x)
        
        mylist = strsplit(tmp.x, '')
        
        double_wt = function(y){
                y = c(y[1],y)
                y = y[y %in% c('0',';','a','1','b','c','2','d','e','3','f','4')]
                ## This step removes all non-convertable characters, such as '--', '..', '.', '' etc.
                ## Not sure if this is the best way to handle the situation. sometimes, people do make typos like '--', 
                ## But in the case of '3.33' or '5.34', not sure if this should be converted to NA or 333 and 34
                
                y = mapvalues(y, from = c('0',';','a','1','b','c','2','d','e','3','f','4'), 
                              to   = c( 0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  9),
                              warn_missing = F
                )
                my_avg = round(mean(as.numeric(y)),2)
                return(my_avg)
        }
        
        tmp.x = unlist(lapply(mylist,double_wt))
        return(tmp.x)
        
}


mapvalues = function (x, from, to, warn_missing = TRUE) {
        ### Note: this function is borrowed from the plyr v1.8.3 package
        if (length(from) != length(to)) {
                stop("`from` and `to` vectors are not the same length.")
        }
        if (!is.atomic(x)) {
                stop("`x` must be an atomic vector.")
        }
        if (is.factor(x)) {
                levels(x) = mapvalues(levels(x), from, to, warn_missing)
                return(x)
        }
        mapidx = match(x, from)
        mapidxNA = is.na(mapidx)
        from_found = sort(unique(mapidx))
        if (warn_missing && length(from_found) != length(from)) {
                message("The following `from` values were not present in `x`: ", 
                        paste(from[!(1:length(from) %in% from_found)], collapse = ", "))
        }
        x[!mapidxNA] = to[mapidx[!mapidxNA]]
        x
}


