#' Process Count Data
#'
#' @param data A `data.frame` from [actiread::acti_read_gt3x]
#' @return A `data.frame` of transformed data
#' @param verbose print diagnostic messages.  Either logical or integer, where
#' @param epoch epoch length in seconds.  Default is 60 seconds.
#' See [agcounts::calculate_counts]
#' @param lfe_select Apply the Actigraph Low Frequency Extension filter.
#' See [agcounts::calculate_counts]
#' higher values are higher levels of verbosity.
#' @export
#' @examples
#' path = actiread::acti_example_gt3x()
#' ac = actiread::acti_read_gt3x(path)
#' out = acti_calculate_counts(ac)
acti_calculate_counts = function(
    data,
    epoch = 60L,
    lfe_select = FALSE,
    verbose = TRUE
) {
  rlang::check_installed("agcounts")
  vector.magnitude = NULL
  rm(list = c("vector.magnitude"))
  stopifnot(!is.null(attr(data, "sample_rate")))
  tz = lubridate::tz(data$time)
  trans = get_transformations(data)
  counts = agcounts::calculate_counts(
    raw = data,
    epoch = epoch,
    tz = tz,
    lfe_select = lfe_select,
    verbose = verbose
  )
  attr(counts, "sample_rate") = round(60/epoch, 2)

  counts = counts %>%
    dplyr::rename_with(tolower)
  counts = counts %>%
    dplyr::rename(counts = vector.magnitude)
  # to deal with https://github.com/bhelsel/agcounts/issues/42
  counts = counts %>%
    dplyr::mutate(time = lubridate::floor_date(time, unit = paste0(epoch, " seconds"))) %>%
    dplyr::group_by(time) %>%
    dplyr::summarise(dplyr::across(dplyr::everything(), \(x) sum(x, na.rm = TRUE))) %>%
    dplyr::ungroup()
  counts = set_transformations(counts, trans)
  counts = set_transformations(counts,
                               c(
                                 paste0("sample_rate_attribute_changed_to_",
                                        round(60/epoch, 2)),
                                 paste0("counts_created_at_", epoch, "s_epoch")
                               ),
                               prefix = "acti_calculate_counts",
                               add = TRUE)
  counts = counts %>% dplyr::as_tibble()
}

