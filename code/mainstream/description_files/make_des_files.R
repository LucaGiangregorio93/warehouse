library(tidyverse)
library(crosswalkr)
library(xlsx)
library(readxl)
#set directory to main folder
#load wh viz
warehouse_viz <- read_csv("./output/databases/warehouse_viz.csv")

#load wh
warehouse <- read_csv("./output/databases/warehouse.csv")

#read sheets from metadata and sources to build description file
sheets <- c("d1_dashboard", 
            "d2_sector", 
            "d3_vartype", 
            "d4_concept", 
            "d5_dboard_specific")

for(s in 1:length(sheets)){
  tmp <- read_excel("./handmade_tables/dictionary.xlsx",
                                   sheet = sheets[s]) 
  if(s < 5){tmp <- tmp %>% 
    select(code, label, description) %>% 
    filter(!is.na(code)) %>%
    mutate(code_help = paste0(code, "-")) 
  newnames <- c(paste0("d", s, "_code"), 
                paste0("d", s, "_label"), 
                paste0("d", s, "_description"),"code_help") 
  colnames(tmp) <- newnames
  tmp <- tmp %>% mutate()
  }
  if(s > 4){tmp <- tmp %>% 
    select(code, label, description, dashboard) %>%
    filter(!is.na(code)) 
  newnames <- c(paste0("d", s, "_code"), 
                paste0("d", s, "_label"), 
                paste0("d", s, "_description"), 
                paste0("d", s, "_dashbaord")) 
  colnames(tmp) <- newnames
  }
     
  assign(sheets[s], tmp)
}

##read percentiles sheet
pct <- read_excel("./handmade_tables/dictionary.xlsx",
                  sheet = "percentiles") 

##inequality-trends dashboard-specific codes
d5_ineqt <-  d5_dboard_specific %>% filter(d5_dashbaord=="Wealth Inequality Trends") 

##build combination of possible d1-d5 codes (permitted varcodes) from d1-d5codes: 
ds_file <- crossing(d1_code_h = d1_dashboard$code_help,
         d2_code_h = d2_sector$code_help, 
         d3_code_h = d3_vartype$code_help, 
         d4_code_h = d4_concept$code_help, 
         d5_code_h = d5_dboard_specific$d5_code) %>%
  mutate(varcode = paste0(d1_code_h, d2_code_h, d3_code_h, d4_code_h, d5_code_h)) %>%
           mutate(d1_code = substr(d1_code_h, 1, nchar(d1_code_h)-1), 
                  d2_code = substr(d2_code_h, 1, nchar(d2_code_h)-1),
                  d3_code = substr(d3_code_h, 1, nchar(d3_code_h)-1),
                  d4_code = substr(d4_code_h, 1, nchar(d4_code_h)-1),
                  d5_code = substr(d5_code_h, 1, nchar(d5_code_h))) %>%
  select(-d1_code_h, -d2_code_h, -d3_code_h, -d4_code_h, -d5_code_h) 

#expand with percentiles
ds_file_b <- crossing(varcode = ds_file$varcode, 
                             percentile = pct$percentile)
ds_file <- left_join(ds_file_b, ds_file)

##add percentiles labels
ds_file <- left_join(ds_file, pct)

##reduce to what is in warehouse based on varcode + percentile combination (varc_p)
ds_file <- ds_file %>% mutate(varc_p = paste0(varcode, percentile))
wh <- warehouse %>% mutate(varc_p = paste0(varcode, percentile))
wh_available <- unique(wh$varc_p)

ds_file <- ds_file %>% filter(varc_p %in% 
                                wh_available)

#append variables: 
#dx_label
ds_file <- left_join(ds_file, d1_dashboard) 
ds_file <- left_join(ds_file, d2_sector %>% select(-code_help))
ds_file <- left_join(ds_file, d3_vartype %>% select(-code_help)) 
ds_file <- left_join(ds_file, d4_concept %>% select(-code_help)) 
ds_file <- left_join(ds_file, d5_dboard_specific) 
ds_file <- ds_file %>% select(-code_help)

#dx_description: add metadata and longname not for eig section 
viz <- warehouse_viz %>%
  mutate(varc_p = paste0(varcode, percentile)) %>%
  filter(varc_p %in% wh_available) %>% 
  select(varc_p, WhichDistrib, 
         indicator_label, 
         longname, 
         metadata)

viz <- unique(viz)

ds_file <- merge(ds_file, viz, 
             all.x = TRUE, 
             all.y = FALSE, 
             by = c("varc_p"))

#add percentile lable
ds_file <- merge(ds_file, pct, all.x = TRUE, all.y = FALSE)

#rename and reorder
ds_file <- ds_file %>%
  select(varcode, percentile, label_percentile, description_percentile, 
         WhichDistrib, indicator_label,
         d1_code, d1_label, d1_description, 
         d2_code, d2_label, d2_description, 
         d3_code, d3_label, d3_description, 
         d4_code, d4_label, d4_description, 
         d5_code, d5_label, d5_description, 
         longname, metadata)



write.csv(ds_file, "documentation/warehouse_description.csv", row.names = FALSE)



write.xlsx2(ds_file, file = "documentation/warehouse_description.xlsx", sheetName = "des", 
              row.names = FALSE)

setwd("../")

write.xlsx2(ds_file, 
           file = "./THE_GC_WEALTH_PROJECT_website/warehouse_description.xlsx",
           sheetName = "des", 
           row.names = FALSE, 
           append = FALSE)

write.csv(ds_file, 
           file = "./THE_GC_WEALTH_PROJECT_website/warehouse_description.csv",
           row.names = FALSE)
