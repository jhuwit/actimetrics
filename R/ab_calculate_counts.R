fix_first_second_function = function(data, sample_rate = NULL, epoch = 60L) {
  if (is.null(sample_rate)) {
    sample_rate = get_sample_rate(data)
  }
  # Fix for https://github.com/bhelsel/agcounts/issues/50
  t1 = data$time[1]
  tz = lubridate::tz(t1)

  data_start <- lubridate::floor_date(t1, paste(epoch, "secs"))
  trans = get_transformations(data)

  if (data_start != t1) {
    add_times = seq(data_start, t1, 1/sample_rate)
    add_times = add_times[add_times < t1]
    data_add = data.frame(
      time = as.POSIXct(add_times, tz),
      X = rep(data[["X"]][1], length(add_times)),
      Y = rep(data[["Y"]][1], length(add_times)),
      Z = rep(data[["Z"]][1], length(add_times))
    )
    data <- rbind(data_add, data)
    data = set_transformations(data,
                               c(
                                 "first_second_data_appended",
                                 trans
                               ),
                               prefix = "acti_calculate_counts",
                               add = FALSE)
  }
  data
}

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
#' @param resample (recommended) resample the data to 30Hz using
#' [actibase::acti_resample] vs. using the resampling method from
#' [agcounts::calculate_counts].
#' @param fix_first_second Fix the first second bug in `agcounts`.  Appends
#' replicated data of the first record if the first record is not an "even"
#' epoch (e.g. 60 second epoch and data does not start at a 00 second).
#'
#'
#' @export
#' @returns A `data.frame` of transformed data with columns `axis1-3`,
#' `counts`, and `counts_log10`.
#' @examples
#'
#' \donttest{
#' path = actiread::acti_example_gt3x()
#' ac = actiread::acti_read_gt3x(path)
#' out = acti_calculate_counts(ac)
#' }
acti_calculate_counts = function(
    data,
    epoch = 60L,
    resample = TRUE,
    lfe_select = FALSE,
    verbose = TRUE,
    fix_first_second = TRUE
) {
  rlang::check_installed("agcounts")
  vector.magnitude = NULL
  rm(list = c("vector.magnitude"))

  if (resample) {
    data = actibase::acti_resample(data, sample_rate = 30L)
  }
  sample_rate = actibase::get_sample_rate(data)
  if (!is.null(attr(data, "sample_rate")) && !is.null(sample_rate)) {
    attr(data, "sample_rate") = sample_rate
  }
  stopifnot(!is.null(attr(data, "sample_rate")))
  tz = lubridate::tz(data$time)
  trans = get_transformations(data)

  if (fix_first_second) {
    data = fix_first_second_function(
      data = data,
      sample_rate = attr(data, "sample_rate"),
      epoch = epoch)
  }

  counts = agcounts::calculate_counts(
    raw = data,
    epoch = epoch,
    tz = tz,
    lfe_select = lfe_select,
    verbose = verbose
  )
  attr(counts, "sample_rate") = round(60/epoch, 2)

  counts = counts |>
    dplyr::rename_with(tolower)
  counts = counts |>
    dplyr::rename(counts = vector.magnitude)
  # to deal with https://github.com/bhelsel/agcounts/issues/42
  counts = counts |>
    dplyr::mutate(time = lubridate::floor_date(time, unit = paste0(epoch, " seconds"))) |>
    dplyr::group_by(time) |>
    dplyr::summarise(dplyr::across(dplyr::everything(), function(x) sum(x, na.rm = TRUE))) |>
    dplyr::ungroup()
  # Log-transform accelerometer counts with a +1 offset so zeros stay finite.
  counts <- counts |>
    dplyr::mutate(counts_log10 = log10(counts + 1))

  counts = set_transformations(counts, trans)
  counts = set_transformations(counts,
                               c(
                                 paste0("sample_rate_attribute_changed_to_",
                                        round(60/epoch, 2)),
                                 paste0("log_10+1-counts_created_at_", epoch, "s_epoch"),
                                 paste0("counts_created_at_", epoch, "s_epoch")
                               ),
                               prefix = "acti_calculate_counts",
                               add = TRUE)
  counts = counts |> dplyr::as_tibble()
  return(counts)
}
