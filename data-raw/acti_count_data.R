## code to prepare `acti_count_data` dataset goes here
library(actibase)
library(actimetrics)
acti_count_data = acti_calculate_counts(actibase::acti_raw_data)


usethis::use_data(acti_count_data, overwrite = TRUE)
