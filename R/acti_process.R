#' Process Raw data to Counts
#'
#' @inheritParams acti_calculate_counts
#' @return A data frame containing activity counts and wear-time indicators.
#' @param min_required Number of minutes required in a day to be called `included`. No
#' day inclusion is run if `NULL`.
#' @param calibrate Logical. If `TRUE`, the data will be calibrated using [acti_calibrate()]
#' @param round_digits Number of decimal places `X`/`Y`/`Z` are rounded to
#' (half away from zero) after resampling to 30Hz and before counting.  The
#' default `NULL` uses `3` for GT3X data (read with [actiread::acti_read_gt3x()])
#' and does not round other data.  Use `NA` to never round.
#' @details To match ActiLife for GT3X files, a GT3X path is read with
#' `digits = 8` (unless `digits` is given in `...`), resampled, and then
#' rounded to 3 digits.  ActiLife rounds the scaled samples to 3 digits, half
#' away from zero.  Reading at 8 digits and then rounding gives exactly those
#' values, but rounding values already read at 5 digits does not
#' (e.g. `0.1234996 -> 0.12350 -> 0.124`).
#' @export
#' @note For `acti_process`, the `...` argument are passed to
#' [actiread::acti_read_gt3x()]
acti_process = function(data,
                        lfe_select = FALSE,
                        method = c("choi", "troiano"),
                        use_magnitude = TRUE,
                        calibrate = FALSE,
                        verbose = TRUE,
                        ...,
                        min_required = 1368L,
                        round_digits = NULL
) {
  if (assertthat::is.string(data) &&
      file.exists(data)) {
    data = read_gt3x_full_digits(data, ..., verbose = verbose)
  }
  if (is.null(round_digits) && is_gt3x_data(data)) {
    round_digits = 3L
  }

  data = acti_standardize_data(data, subset_xyz = FALSE)
  if (calibrate) {
    tz = lubridate::tz(data$time)
    data = acti_calibrate(data,
                          fill_zeroes = FALSE,
                          round_after_calibration = FALSE,
                          tz = tz,
                          verbose = verbose)
  }

  data = acti_resample(data, sample_rate = 30L)

  counts = acti_calculate_counts(
    data,
    lfe_select = lfe_select,
    # already done
    resample = FALSE,
    verbose = verbose,
    # after resampling
    round_digits = round_digits)
  # the raw data are not needed after counting; free them before the
  # remaining steps (a 7-day 30 Hz recording is about 550 MB)
  rm(data)
  invisible(gc())

  # Process the data
  wear = acti_calculate_nonwear(
    counts,
    method = method,
    use_magnitude = use_magnitude)

  result = dplyr::full_join(counts, wear, by = "time") |>
    dplyr::mutate(wear = ifelse(is.na(wear), FALSE, wear))
  result = set_transformations(result,
                               "counts_wear_merge",
                               prefix = "acti_process",
                               add = TRUE)
  if (!is.null(min_required)) {
    result = actibase::add_day_inclusion(data = result,
                                         min_required = min_required)
  }

  return(result)
}

# Read a GT3X file with `digits = 8` (unless `digits` is given) so it can be
# resampled before rounding to 3 digits as ActiLife does
read_gt3x_full_digits = function(path, ..., verbose = TRUE) {
  args = list(path, ..., verbose = verbose)
  if (is.null(args[["digits"]]) && gt3x_supports_digits()) {
    args$digits = 8L
  }
  do.call(acti_read_gt3x, args)
}

# read.gt3x 1.3.0 added `digits` (same check as actiread)
gt3x_supports_digits = function() {
  utils::packageVersion("read.gt3x") >= package_version("1.3.0") ||
    "digits" %in% names(formals(utils::getFromNamespace("parseGT3X",
                                                        "read.gt3x")))
}

is_gt3x_data = function(data) {
  any(grepl("^acti_read_gt3x:", get_transformations(data)))
}
