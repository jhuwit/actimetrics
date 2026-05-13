#' Process Count Data
#'
#' @inheritParams acti_calculate_counts
#' @export
#' @note For `acti_process_gt3x`, the `...` argument are passed to
#' `actiread::acti_read_gt3x()`
acti_process = function(data,
                        lfe_select = FALSE,
                        method = c("choi", "troiano"),
                        use_magnitude = TRUE,
                        verbose = TRUE,
                        ...) {
  if (assertthat::is.string(data) &&
      file.exists(data)) {
    data = acti_read_gt3x(data, ...,
                          verbose = verbose)
  }


  data = acti_resample(data, sample_rate = 30L)

  counts = acti_calculate_counts(
    data,
    lfe_select = lfe_select,
    # already done
    resample = FALSE,
    verbose = verbose)

  # Process the data
  wear = acti_calculate_nonwear(
    counts,
    method = method,
    use_magnitude = use_magnitude)

  result = dplyr::full_join(counts, wear, by = "time") %>%
    dplyr::mutate(wear = ifelse(is.na(wear), FALSE, wear))
  result = set_transformations(result,
                               "counts_wear_merge",
                               prefix = "acti_process",
                               add = TRUE)

  return(result)
}
