#' Example Actigraphy/Activity Count Data
#'
#'
#' @format A `data.frame` with the columns
#' \describe{
#' \item{time}{time at the minute level}
#' \item{axis1}{axis1 (Y) counts}
#' \item{axis2}{axis2 (X) counts}
#' \item{axis3}{axis3 (Z) counts}
#' \item{counts}{vector magnitude of all 3 axes column}
#' }
#' This data was taken from running [agcounts::calculate_counts] via
#' [acti_calculate_counts] on
#' [actibase::acti_raw_data].
"acti_count_data"
