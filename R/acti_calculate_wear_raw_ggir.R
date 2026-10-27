# GGIR non-wear detection from raw acceleration ------------------------------
#
# Standalone port of the non-wear and clipping detection in GGIR
# (`detect_nonwear_clipping()` in part 1 and `g.weardec()` in part 2).  The
# implementation does not call, import, or require GGIR.

# Per medium-epoch non-wear score (0-3 axes) and clipping fraction.  `xyz` is a
# numeric matrix of calibrated X, Y, Z acceleration (g) sampled at `sf` Hz.
.wear_raw_nonwear_clipping = function(xyz, sf,
                                      medium_epoch = 900,
                                      long_epoch = 3600,
                                      clip_threshold = 7.5,
                                      sd_threshold = 0.013,
                                      range_threshold = 0.15,
                                      approach = c("2023", "2013")) {
  approach = match.arg(approach)
  medium_size = medium_epoch * sf
  long_size = long_epoch * sf
  n_medium = floor(nrow(xyz) / medium_size)
  clip_log = nonwear_log = matrix(0, n_medium, 3)
  min_epoch_count = ((long_size / medium_size) / 2) + 1
  subsample_by = ceiling(sf / 5)
  # GGIR only evaluates the samples that fill complete medium epochs
  n_used = n_medium * medium_size

  for (h in seq_len(n_medium)) {
    clip_start = (h - 1) * medium_size
    clip_end = h * medium_size
    if (approach == "2013") {
      # Centred long window; the start and end of the recording use a fixed
      # window, as in GGIR.  Only the centre medium epoch is labelled.
      flag_rows = h
      if (h <= min_epoch_count) {
        nw_start = 1
        nw_end = long_size
      } else if (h >= (n_medium - min_epoch_count)) {
        nw_start = (n_medium - min_epoch_count) * medium_size
        nw_end = n_medium * medium_size
      } else {
        nw_start = ((h - 1) * medium_size + medium_size * 0.5) -
          long_size * 0.5
        nw_end = ((h - 1) * medium_size + medium_size * 0.5) +
          long_size * 0.5
      }
      indices = (1 + nw_start):nw_end
    } else {
      # Forward-looking long window; every medium epoch it covers is labelled.
      flag_rows = h:(h + long_size / medium_size - 1)
      flag_rows = flag_rows[flag_rows <= n_medium]
      nw_start = h * medium_size - medium_size
      nw_end = min(nw_start + long_size, n_used)
      indices = seq(1 + nw_start, nw_end, by = subsample_by)
    }
    for (jj in seq_len(3)) {
      x = xyz[(1 + clip_start):clip_end, jj]
      above = abs(x) > clip_threshold
      clip_log[h, jj] = sum(above, na.rm = TRUE)
      if (any(abs(x[which(above)]) > clip_threshold * 1.5)) {
        clip_log[h, jj] = medium_size
      }
      x = xyz[indices, jj]
      abs_range = abs(max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
      if (abs_range < range_threshold &&
          stats::sd(x, na.rm = TRUE) < sd_threshold) {
        nonwear_log[flag_rows, jj] = 1
      }
    }
  }
  clipping_score = apply(clip_log / medium_size, 1, max)
  nonwear_score = rowSums(nonwear_log)

  # A single-axis epoch between two multi-axis epochs is promoted to 2
  for (one_i in which(nonwear_score == 1)) {
    if (one_i - 1 < 1 || one_i + 1 > length(nonwear_score)) next
    if (nonwear_score[one_i - 1] > 1 && nonwear_score[one_i + 1] > 1) {
      nonwear_score[one_i] = 2
    }
  }
  list(nonwear_score = nonwear_score,
       clipping_score = if (n_medium > 0) clipping_score else numeric(0))
}

# Remove nonwear runs shorter than `max_hours` that occur inside a clock-hour
# window (GGIR `nonwearFiltermaxHours` with `nonwearFilterWindow`).
.wear_raw_filter_night = function(r1, hour, medium_epoch, max_hours, window) {
  runs = rle(as.numeric(r1))
  if (length(runs$values) == 1L) return(r1)
  values = rep(runs$values, runs$lengths)
  lengths = rep(runs$lengths, runs$lengths) * medium_epoch / 3600
  if (window[1] > window[2]) {
    in_window = hour >= window[1] | hour < window[2]
  } else {
    in_window = hour >= window[1] & hour < window[2]
  }
  r1[values == 1 & lengths < max_hours & in_window] = 0
  r1
}

# Port of GGIR's `additionalNonWearDetection()`: relabel short wear bouts that
# are surrounded by long non-wear bouts.  `s1`/`s3` are padded with zeros.
.wear_raw_additional = function(s1, s3, medium_epoch, n_epochs,
                                edge_correction = FALSE) {
  per_hour = 3600 / medium_epoch
  ch1 = which(diff(s1) == 1) + 1
  ch2 = which(diff(s1) == -1) + 1
  if (length(ch1) > 1) {
    for (i in seq_len(length(ch1) - 1)) {
      wear_length = abs(ch1[i + 1] - ch2[i])
      nonwear_after = abs(ch2[i + 1] - ch1[i + 1])
      nonwear_before = abs(ch2[i] - ch1[i])
      ratio = wear_length / (nonwear_after + nonwear_before)
      if (wear_length < 6 * per_hour && ratio < 0.3) {
        s3[ch2[i]:(ch1[i + 1] - 1)] = 1
      }
      if (wear_length < 3 * per_hour && ratio < 0.8) {
        s3[ch2[i]:(ch1[i + 1] - 1)] = 1
      }
      if (ch1[i] > (n_epochs - 24 * per_hour)) {
        if (wear_length < 3 * per_hour && nonwear_before > per_hour) {
          s3[ch2[i]:(ch1[i + 1] - 1)] = 1
        }
      }
    }
  }
  if (edge_correction && length(ch1) > 0) {
    if (ch1[1] < 3 * per_hour && ch1[1] > 1) {
      s3[1:(ch1[1] - 1)] = 1
    }
    last = ch2[length(ch2)]
    if (last > (length(s3) - 3 * per_hour) && last != length(s3)) {
      s3[last:length(s3)] = 1
    }
  }
  s3
}

# Port of GGIR's `g.weardec()`.  Returns the non-wear (r1), clipping (r2), and
# additional non-wear (r3) indicators per medium epoch.
.wear_raw_decide = function(nonwear_score, clipping_score, medium_epoch,
                            wear_threshold = 2, clipping_threshold = 0.3,
                            edge_correction = TRUE, hour = NULL,
                            filter_max_hours = NULL, filter_window = NULL) {
  n = length(nonwear_score)
  r1 = as.numeric(nonwear_score >= wear_threshold)
  r2 = as.numeric(clipping_score > clipping_threshold)
  if (!is.null(filter_max_hours)) {
    r1 = .wear_raw_filter_night(r1, hour, medium_epoch,
                                filter_max_hours, filter_window)
  }
  pad = function(x) c(0, x, 0)
  unpad = function(x) x[-c(1L, length(x))]
  r3 = unpad(.wear_raw_additional(pad(r1), pad(rep(0, n)), medium_epoch, n,
                                  edge_correction = edge_correction))
  for (i in 1:2) {
    r1b = pmin(r3 + r1, 1)
    r3 = unpad(.wear_raw_additional(pad(r1b), pad(r3), medium_epoch, n,
                                    edge_correction = FALSE))
  }
  list(r1 = r1, r2 = r2, r3 = r3)
}

# GGIR drops the samples before the first clock time whose minute is a
# multiple of the medium epoch (in minutes).
.wear_raw_aligned_start = function(time, medium_epoch) {
  t0 = time[1]
  start_minutes = medium_epoch / 60
  sec = floor(lubridate::second(t0))
  minute = lubridate::minute(t0) + (sec > 0)
  min_shift = start_minutes - (minute %% start_minutes)
  if (min_shift == start_minutes) min_shift = 0
  lubridate::floor_date(t0, "minute") + ((sec > 0) + min_shift) * 60
}

.wear_raw_clip_threshold = function(data, dynamic_range = NULL) {
  if (is.null(dynamic_range)) {
    dynamic_range = suppressWarnings(
      get_dynamic_range(data, flag_estimated = TRUE)
    )
    if (isTRUE(attr(dynamic_range, "estimated"))) {
      return(7.5)
    }
  }
  max(abs(as.numeric(dynamic_range))) - 0.5
}

#' Estimate Non-wear from Raw Accelerometry with the GGIR Method
#'
#' Detects non-wear and signal clipping from raw tri-axial acceleration with
#' the algorithm in GGIR (van Hees et al. 2011, 2013), as implemented in
#' GGIR's `detect_nonwear_clipping()` and `g.weardec()`.  This is a standalone
#' port and does not require GGIR.  Usually called through
#' [acti_calculate_wear_raw()].
#'
#' For each medium epoch (default 15 minutes), a long window (default 60
#' minutes) is evaluated per axis.  An axis is scored as non-wear when both
#' its standard deviation is below `sd_threshold` and its range is below
#' `range_threshold`.  The non-wear score is the number of axes (0--3) that
#' meet both criteria, and an epoch is non-wear when the score is at least
#' `wear_threshold`.  An epoch is clipped when more than `clipping_threshold`
#' of its samples on any axis exceed `clip_threshold` (or, if any sample
#' exceeds `1.5 * clip_threshold`, the whole epoch is clipped).  Short wear
#' bouts surrounded by long non-wear bouts are then relabelled as non-wear,
#' following GGIR part 2.
#'
#' GGIR reads files in chunks (24 hours for GT3X files) and scores each chunk
#' separately.  With `approach = "2023"`, a window that starts in one chunk
#' cannot label epochs in the next, so GGIR's `nonwearscore` can be lower for
#' the first epochs after a chunk boundary.  This function scores the whole
#' recording at once.  GGIR also imputes time gaps before scoring; this
#' function does not.
#'
#' @param data A `data.frame` of raw accelerometer data with a time column and
#'   `X`, `Y`, `Z` columns, or an `AccData` object.  Data should be calibrated
#'   (e.g. with [acti_calibrate()]) and regularly sampled.
#' @param sample_rate Sampling frequency (Hz).  If `NULL`, taken from the
#'   `sample_rate` attribute of `data`.
#' @param medium_epoch Length, in seconds, of the epoch the output is reported
#'   in (GGIR `windowsizes[2]`).
#' @param long_epoch Length, in seconds, of the window used to evaluate
#'   non-wear (GGIR `windowsizes[3]`).
#' @param approach Non-wear window approach (GGIR `nonwear_approach`).
#'   `"2023"` (GGIR default) uses a forward-looking long window, evaluated on
#'   a subsample of `ceiling(sample_rate / 5)`, and labels every medium epoch
#'   it covers.  `"2013"` uses a long window centred on each medium epoch and
#'   labels only that epoch.
#' @param sd_threshold Standard deviation (g) below which an axis is
#'   considered still.  GGIR uses 0.013, or `1.2 * rmc.noise` for ad-hoc
#'   formats.
#' @param range_threshold Range (g) below which an axis is considered still
#'   (GGIR `nonwear_range_threshold`, in mg, divided by 1000).  GGIR uses 0.15,
#'   or 0.2 for Verisense devices.
#' @param dynamic_range Dynamic range of the device (g), e.g. `c(-8, 8)`.  If
#'   `NULL`, it is taken from the attributes or header of `data` when
#'   available.  Used to set `clip_threshold`.
#' @param clip_threshold Absolute acceleration (g) above which a sample is
#'   counted as clipped.  Defaults to the dynamic range minus 0.5, or 7.5 when
#'   the dynamic range is unknown, as in GGIR.
#' @param wear_threshold Minimum number of axes that must be still for an epoch
#'   to be non-wear.  Fixed at 2 in GGIR.
#' @param clipping_threshold Fraction of clipped samples above which an epoch
#'   is flagged as clipping.  Fixed at 0.3 in GGIR.
#' @param edge_correction Should non-wear starting (ending) within the first
#'   (last) 3 hours of the recording be extended to the start (end)?  GGIR
#'   `nonWearEdgeCorrection`.
#' @param filter_max_hours,filter_window If `filter_max_hours` is not `NULL`,
#'   non-wear bouts shorter than `filter_max_hours` hours occurring inside the
#'   clock window `filter_window = c(start_hour, end_hour)` are relabelled as
#'   wear (GGIR `nonwearFiltermaxHours` and `nonwearFilterWindow`).  The
#'   window may wrap midnight, e.g. `c(22, 7)`.
#' @param align_start Should samples before the first clock time aligned to
#'   `medium_epoch` be dropped, as GGIR does?  If `FALSE`, epochs start at the
#'   first sample.
#'
#' @return A `tibble` with one row per medium epoch:
#' \describe{
#'   \item{`time`}{Start of the epoch.}
#'   \item{`nonwear_score`}{Number of axes (0--3) meeting the non-wear
#'   criteria (GGIR `nonwearscore`).}
#'   \item{`clipping_score`}{Maximum fraction of clipped samples across axes
#'   (GGIR `clippingscore`).}
#'   \item{`nonwear`}{Non-wear from the score (GGIR `r1`).}
#'   \item{`clipping`}{Clipping (GGIR `r2`).}
#'   \item{`nonwear_additional`}{Additional non-wear from the bout rules
#'   (GGIR `r3`).}
#'   \item{`wear`}{`TRUE` if none of `nonwear`, `clipping`, or
#'   `nonwear_additional` is flagged.}
#' }
#' @references
#' van Hees VT, et al. (2011). Estimation of daily energy expenditure in
#' pregnant and non-pregnant women using a wrist-worn tri-axial accelerometer.
#' PLoS ONE 6(7): e22922. \doi{10.1371/journal.pone.0022922}
#'
#' van Hees VT, et al. (2013). Separating movement and gravity components in
#' an acceleration signal and implications for the assessment of human daily
#' physical activity. PLoS ONE 8(4): e61691.
#' \doi{10.1371/journal.pone.0061691}
#' @seealso [acti_calculate_wear_raw()], [acti_calculate_wear_raw_actipy()]
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
#' acti_calculate_wear_raw_ggir(data, sample_rate = 10)
acti_calculate_wear_raw_ggir = function(data,
                                        sample_rate = NULL,
                                        medium_epoch = 900,
                                        long_epoch = 3600,
                                        approach = c("2023", "2013"),
                                        sd_threshold = 0.013,
                                        range_threshold = 0.15,
                                        dynamic_range = NULL,
                                        clip_threshold = NULL,
                                        wear_threshold = 2,
                                        clipping_threshold = 0.3,
                                        edge_correction = TRUE,
                                        filter_max_hours = NULL,
                                        filter_window = NULL,
                                        align_start = TRUE) {
  approach = match.arg(approach)
  sample_rate = resolve_sample_rate(data, sample_rate,
                                    caller = "acti_calculate_wear_raw_ggir()")
  if (is.null(clip_threshold)) {
    clip_threshold = .wear_raw_clip_threshold(data, dynamic_range)
  }
  assertthat::assert_that(
    assertthat::is.number(medium_epoch), medium_epoch > 0,
    assertthat::is.number(long_epoch), long_epoch >= medium_epoch,
    msg = "`medium_epoch` and `long_epoch` must be positive numbers, with `long_epoch >= medium_epoch`."
  )
  assertthat::assert_that(
    (long_epoch / medium_epoch) %% 1 == 0,
    msg = "`long_epoch` must be a multiple of `medium_epoch`."
  )
  assertthat::assert_that(
    assertthat::is.number(sd_threshold),
    assertthat::is.number(range_threshold),
    assertthat::is.number(clip_threshold),
    assertthat::is.number(wear_threshold),
    assertthat::is.number(clipping_threshold),
    assertthat::is.flag(edge_correction),
    assertthat::is.flag(align_start)
  )
  if (!is.null(filter_max_hours)) {
    assertthat::assert_that(
      assertthat::is.number(filter_max_hours),
      is.numeric(filter_window), length(filter_window) == 2L,
      msg = paste0("`filter_window` must be c(start_hour, end_hour) when ",
                   "`filter_max_hours` is set.")
    )
  }

  data = acti_standardize_data(data, subset_xyz = FALSE)
  trans = get_transformations(data)
  data = data[order(data$time), , drop = FALSE]
  time_diff = diff(as.numeric(data$time))
  if (any(time_diff > 1.5 / sample_rate)) {
    warning("`data` has time gaps; acti_calculate_wear_raw_ggir() treats ",
            "samples as contiguous.  Fill gaps before running for GGIR-like ",
            "results.")
  }
  if (align_start && nrow(data) > 0) {
    start = .wear_raw_aligned_start(data$time, medium_epoch)
    data = data[data$time >= start, , drop = FALSE]
  }
  if (nrow(data) < long_epoch * sample_rate) {
    stop("`data` is shorter than `long_epoch` (", long_epoch, " seconds); ",
         "non-wear cannot be estimated.", call. = FALSE)
  }

  xyz = as.matrix(data[, c("X", "Y", "Z")])
  scores = .wear_raw_nonwear_clipping(
    xyz, sf = sample_rate,
    medium_epoch = medium_epoch, long_epoch = long_epoch,
    clip_threshold = clip_threshold, sd_threshold = sd_threshold,
    range_threshold = range_threshold, approach = approach
  )
  n_epochs = length(scores$nonwear_score)
  epoch_time = data$time[1] + (seq_len(n_epochs) - 1) * medium_epoch
  hour = lubridate::hour(epoch_time) + lubridate::minute(epoch_time) / 60
  decision = .wear_raw_decide(
    scores$nonwear_score, scores$clipping_score, medium_epoch,
    wear_threshold = wear_threshold, clipping_threshold = clipping_threshold,
    edge_correction = edge_correction, hour = hour,
    filter_max_hours = filter_max_hours, filter_window = filter_window
  )

  out = tibble::tibble(
    time = epoch_time,
    nonwear_score = scores$nonwear_score,
    clipping_score = scores$clipping_score,
    nonwear = decision$r1 == 1,
    clipping = decision$r2 == 1,
    nonwear_additional = decision$r3 == 1
  )
  out$wear = !(out$nonwear | out$clipping | out$nonwear_additional)
  out = set_transformations(out, trans)
  out = set_transformations(out,
                            paste0("ggir_", approach, "_wear_algorithm_run"),
                            prefix = "acti_calculate_wear_raw_ggir",
                            add = TRUE)
  out
}
