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
  data_start = lubridate::floor_date(
    t1, acti_standardize_epoch(epoch, output = "character"))
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

# Round half away from zero, as ActiLife does for GT3X data
# (`Math.Round(x, 3, MidpointRounding.AwayFromZero)` in
# https://github.com/actigraph/GT3X-File-Format/blob/main/LogRecords/Activity.md)
# and as `read.gt3x` does (C++ `std::round`).  Base R `round()` does not:
# `round(0.0625, 3)` is 0.062, not 0.063.  This is
# `sign(x) * trunc(abs(x) * 10^digits + 0.5) / 10^digits`, but compares the
# fractional part to 0.5 so that adding 0.5 cannot round up in floating point.
round_half_away = function(x, digits = 3L) {
  m = 10^digits
  y = abs(x) * m
  r = trunc(y)
  sign(x) * (r + (y - r >= 0.5)) / m
}

# Round X/Y/Z with round_half_away(); NULL or NA does nothing
round_xyz = function(data, round_digits, prefix) {
  if (is.null(round_digits) || (length(round_digits) == 1L && is.na(round_digits))) {
    return(data)
  }
  if (!(assertthat::is.number(round_digits) && round_digits >= 0 &&
        round_digits == trunc(round_digits))) {
    stop("`round_digits` must be NULL, NA, or a single non-negative integer.",
         call. = FALSE)
  }
  for (i in c("X", "Y", "Z")) {
    data[[i]] = round_half_away(data[[i]], digits = round_digits)
  }
  set_transformations(data,
                      paste0("XYZ_rounded_to_", round_digits, "_digits"),
                      prefix = prefix, add = TRUE)
}

#' Process Count Data
#'
#' @param data A `data.frame` from [actiread::acti_read_gt3x]
#' @return A `data.frame` of transformed data
#' @param verbose print diagnostic messages.  Either logical or integer, where
#' higher values are higher levels of verbosity.
#' @param epoch epoch length, either in seconds or a string such as `"1 min"`
#' (see [actibase::acti_standardize_epoch()]); must be a whole number of
#' seconds.  Default is 60 seconds.  See [agcounts::calculate_counts]
#' @param lfe_select Apply the Actigraph Low Frequency Extension filter.
#' See [agcounts::calculate_counts]
#' @param resample (recommended) resample the data to 30Hz using
#' [actibase::acti_resample] vs. using the resampling method from
#' [agcounts::calculate_counts].
#' @param round_digits If not `NULL`, the number of decimal places the
#' `X`/`Y`/`Z` values are rounded to after resampling and before counting.
#' Use `3` to match ActiLife, which rounds GT3X data to 3 decimals (half away
#' from zero, so `0.0625` becomes `0.063`, unlike [base::round()]).  Useful if
#' the data were read with more digits.  Default `NULL` does not round.
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
    fix_first_second = TRUE,
    round_digits = NULL
) {
  rlang::check_installed("agcounts")
  epoch = acti_standardize_epoch(epoch)
  assertthat::assert_that(
    assertthat::is.count(epoch),
    msg = "`epoch` must be a whole number of seconds."
  )
  epoch = as.integer(epoch)
  epoch_unit = acti_standardize_epoch(epoch, output = "character")
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
  # round after resampling, so the interpolation uses the unrounded values
  data = round_xyz(data, round_digits, prefix = "acti_calculate_counts")
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
    dplyr::mutate(time = lubridate::floor_date(time, unit = epoch_unit)) |>
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
