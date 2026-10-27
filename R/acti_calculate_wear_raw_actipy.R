# actipy non-wear detection from raw acceleration ----------------------------
#
# Standalone port of actipy's `detect_nonwear()`.  The implementation does not
# call, import, or require actipy or Python.

# Port of actipy's `detect_nonwear()`: windows of `window` seconds, anchored at
# the first sample, are stationary when the standard deviation of every axis
# is below `sd_threshold`.  Runs of stationary windows whose span (start of
# the first window to start of the last window) exceeds `patience` seconds
# are non-wear.  Windows without samples, or with a single sample, are not
# stationary, as in pandas.
.wear_raw_actipy = function(time, xyz, window = 10, patience = 5400,
                            sd_threshold = 0.015) {
  t0 = time[1]
  bin = floor(as.numeric(difftime(time, t0, units = "secs")) / window) + 1
  n_bins = max(bin)
  stationary = rep(TRUE, n_bins)
  for (jj in seq_len(3)) {
    x = xyz[, jj]
    keep = !is.na(x)
    x = x[keep]
    b = bin[keep]
    n = tabulate(b, nbins = n_bins)
    bin_sum = function(v) {
      s = rowsum(v, b)
      out = rep(0, n_bins)
      out[as.integer(rownames(s))] = s[, 1]
      out
    }
    mean_x = bin_sum(x) / n
    sd_x = sqrt(bin_sum((x - mean_x[b])^2) / (n - 1))
    stationary = stationary & n >= 2L & sd_x < sd_threshold
  }
  runs = rle(stationary)
  span = (runs$lengths - 1) * window
  nonwear_run = runs$values & span > patience
  nonwear = rep(nonwear_run, runs$lengths)
  tibble::tibble(
    time = t0 + (seq_len(n_bins) - 1) * window,
    stationary = stationary,
    nonwear = nonwear,
    wear = !nonwear
  )
}

#' Estimate Non-wear from Raw Accelerometry with the actipy Method
#'
#' Detects non-wear from raw tri-axial acceleration with the
#' stationary-episode definition of Doherty et al. (2017), as implemented in
#' actipy's `detect_nonwear()` (Chan and Doherty).  This is a standalone port
#' and does not require actipy or Python.  Usually called through
#' [acti_calculate_wear_raw()].
#'
#' The signal is split into windows of `window` seconds, anchored at the first
#' sample.  A window is stationary when the standard deviation of every axis
#' is below `sd_threshold`.  A run of stationary windows is non-wear when its
#' span, from the start of its first window to the start of its last window,
#' is longer than `patience` seconds.  Windows with fewer than two samples
#' (for example, during time gaps) are not stationary.
#'
#' The defaults are actipy's (10 seconds, 90 minutes, 15 mg).  Doherty et al.
#' (2017) used 60 minutes and 13 mg (`patience = 3600, sd_threshold = 0.013`).
#' actipy sets samples to `NaN` from the start of the first window to the
#' start of the last window of a run; this function labels whole windows, so
#' the last window of a run is labelled non-wear.  actipy runs this step after
#' low-pass filtering and gravity calibration.
#'
#' @param data A `data.frame` of raw accelerometer data with a time column and
#'   `X`, `Y`, `Z` columns, or an `AccData` object.  Data should be calibrated
#'   (e.g. with [acti_calibrate()]).
#' @param window Length, in seconds, of the windows used to test for
#'   stationarity.
#' @param patience Minimum span, in seconds, of a stationary run for it to be
#'   non-wear.
#' @param sd_threshold Standard deviation (g) below which an axis is
#'   considered still.
#'
#' @return A `tibble` with one row per window: `time` (start of the window),
#'   `stationary`, `nonwear`, and `wear`.
#' @references
#' Doherty A, et al. (2017). Large scale population assessment of physical
#' activity using wrist worn accelerometers: the UK Biobank study. PLoS ONE
#' 12(2): e0169649. \doi{10.1371/journal.pone.0169649}
#'
#' Chan S, Doherty A. actipy: a Python package to process wearable sensor
#' data. \doi{10.5281/zenodo.14514488}
#' @seealso [acti_calculate_wear_raw()], [acti_calculate_wear_raw_ggir()]
#' @export
#' @examples
#' n = 3 * 3600 * 10
#' time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + (seq_len(n) - 1) / 10
#' moving = rep(c(TRUE, FALSE, TRUE), each = n / 3)
#' set.seed(1)
#' data = data.frame(
#'   time = time,
#'   X = ifelse(moving, stats::rnorm(n, sd = 0.3), 0),
#'   Y = ifelse(moving, stats::rnorm(n, sd = 0.3), 0),
#'   Z = ifelse(moving, stats::rnorm(n, sd = 0.3), 1)
#' )
#' wear = acti_calculate_wear_raw_actipy(data, patience = 3000)
#' table(wear$wear)
acti_calculate_wear_raw_actipy = function(data,
                                          window = 10,
                                          patience = 5400,
                                          sd_threshold = 0.015) {
  assertthat::assert_that(
    assertthat::is.number(window), window > 0,
    assertthat::is.number(patience), patience >= 0,
    assertthat::is.number(sd_threshold),
    msg = paste0("`window` must be a positive number, and `patience` and ",
                 "`sd_threshold` non-negative numbers.")
  )
  data = acti_standardize_data(data, subset_xyz = FALSE)
  trans = get_transformations(data)
  data = data[order(data$time), , drop = FALSE]
  assertthat::assert_that(nrow(data) > 0, msg = "`data` has no rows.")
  out = .wear_raw_actipy(data$time, as.matrix(data[, c("X", "Y", "Z")]),
                         window = window, patience = patience,
                         sd_threshold = sd_threshold)
  out = set_transformations(out, trans)
  out = set_transformations(out, "actipy_wear_algorithm_run",
                            prefix = "acti_calculate_wear_raw_actipy",
                            add = TRUE)
  out
}
