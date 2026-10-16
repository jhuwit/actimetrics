# Fix for https://github.com/bhelsel/agcounts/issues/50
# Pads the start of the record (carrying the first row backwards) so the data
# begin on an epoch boundary.  All columns and attributes are kept.
fix_first_second_function = function(data, sample_rate = NULL, epoch = 60L) {
  if (nrow(data) == 0L) {
    return(data)
  }
  sample_rate = resolve_sample_rate(data, sample_rate,
                                    caller = "fix_first_second_function()")
  t1 = data$time[1]
  if (is.na(t1)) {
    stop("The first `time` value is missing; cannot align to epoch start.",
         call. = FALSE)
  }
  tz = lubridate::tz(t1)
  data_start = lubridate::floor_date(t1, paste(epoch, "secs"))
  offset = as.numeric(difftime(t1, data_start, units = "secs"))
  # number of sample-grid points in [data_start, t1); the tolerance avoids
  # floating point adding a sample at t1 itself
  n_add = ceiling(offset * sample_rate - 1e-6)
  if (n_add <= 0L) {
    return(data)
  }

  keep_attrs = attributes(data)
  keep_attrs = keep_attrs[setdiff(names(keep_attrs),
                                  c("names", "row.names", "class"))]
  data_add = data[rep(1L, n_add), , drop = FALSE]
  data_add$time = lubridate::with_tz(
    data_start + (seq_len(n_add) - 1L) / sample_rate, tz)
  out = dplyr::bind_rows(data_add, data)
  for (a in names(keep_attrs)) {
    attr(out, a) = keep_attrs[[a]]
  }
  attr(out, "sample_rate") = sample_rate
  set_transformations(out, "first_second_data_appended",
                      prefix = "acti_calculate_counts", add = TRUE)
}

#' Process Count Data
#'
#' @param data A `data.frame` from [actiread::acti_read_gt3x]
#' @return A `data.frame` of transformed data
#' @param verbose print diagnostic messages.  Either logical or integer, where
#' higher values are higher levels of verbosity.
#' @param epoch epoch length in seconds.  Default is 60 seconds.
#' See [agcounts::calculate_counts]
#' @param lfe_select Apply the Actigraph Low Frequency Extension filter.
#' See [agcounts::calculate_counts]
#' @param resample (recommended) resample the data to 30Hz using
#' [actibase::acti_resample] vs. using the resampling method from
#' [agcounts::calculate_counts].
#' @param fix_first_second Fix the first second bug in `agcounts`.  Appends
#' replicated data of the first record if the first record is not an "even"
#' epoch (e.g. 60 second epoch and data does not start at a 00 second).
#' @details The sampling frequency is only needed when `resample = FALSE`;
#' it is taken from the `sample_rate` attribute (or estimated from `time`).
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

  # agcounts only uses time/X/Y/Z, and its own start padding rbind()s a
  # time/X/Y/Z data.frame onto the data, which fails with extra columns
  data = acti_standardize_data(data, subset_xyz = TRUE)
  if (resample) {
    # sets the sample_rate attribute to 30
    data = actibase::acti_resample(data, sample_rate = 30L)
  } else {
    attr(data, "sample_rate") = resolve_sample_rate(
      data, caller = "acti_calculate_counts(resample = FALSE)")
  }
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
