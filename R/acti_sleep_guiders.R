# Sleep guider algorithms -----------------------------------------------------
#
# Standalone implementations of the sleep-period-time (SPT) *guiders*
# described in the GGIR sleep fundamentals documentation.  A guider identifies
# the most likely main sleep window; it is not an epoch-by-epoch sleep/wake
# classifier.  The implementations below do not call, import, or require GGIR.

.acti_sleep_epoch_seconds <- function(time = NULL, epoch_seconds = NULL) {
  if (!is.null(epoch_seconds)) {
    assertthat::assert_that(
      assertthat::is.number(epoch_seconds), epoch_seconds > 0,
      msg = "`epoch_seconds` must be one positive number."
    )
    return(as.numeric(epoch_seconds))
  }
  assertthat::assert_that(
    !is.null(time), length(time) >= 2L,
    msg = "Supply `epoch_seconds`, or at least two regularly spaced timestamps."
  )
  epoch_seconds <- stats::median(as.numeric(diff(time)), na.rm = TRUE)
  assertthat::assert_that(
    assertthat::is.number(epoch_seconds), epoch_seconds > 0,
    msg = "Could not infer a positive epoch length from `time`."
  )
  epoch_seconds
}

.acti_sleep_check_vector <- function(x, name, n = NULL) {
  assertthat::assert_that(
    is.numeric(x), assertthat::not_empty(x),
    msg = sprintf("`%s` must be a non-empty numeric vector.", name)
  )
  if (!is.null(n)) {
    assertthat::assert_that(
      assertthat::are_equal(length(x), n),
      msg = sprintf("`%s` must have length %d.", name, n)
    )
  }
  as.numeric(x)
}

.acti_sleep_roll_apply <- function(x, width, fun) {
  # A centred rolling statistic with zero-filled ends, matching the HDCZA
  # convention used for the first and last half-window.
  n <- length(x)
  out <- numeric(n)
  half_left <- floor((width - 1L) / 2L)
  half_right <- width - half_left - 1L
  for (i in seq_len(n)) {
    lo <- i - half_left
    hi <- i + half_right
    if (lo >= 1L && hi <= n) out[i] <- fun(x[lo:hi])
  }
  out
}

.acti_sleep_blocks <- function(flag, min_block_epochs, max_gap_epochs) {
  # Remove short inactive blocks, bridge short interruptions, then retain the
  # longest remaining block.  `flag` is the candidate low-movement signal.
  n <- length(flag)
  r <- rle(c(FALSE, flag, FALSE))
  interior <- seq.int(2L, length(r$values) - 1L)
  remove <- interior[r$values[interior] &
                       r$lengths[interior] <= min_block_epochs]
  if (length(remove)) r$values[remove] <- FALSE

  flag <- rep(r$values, r$lengths)[-c(1L, n + 2L)]
  r <- rle(c(FALSE, flag, FALSE))
  interior <- seq.int(2L, length(r$values) - 1L)
  fill <- interior[!r$values[interior] &
                     r$lengths[interior] < max_gap_epochs]
  if (length(fill)) r$values[fill] <- TRUE

  crude <- rep(r$values, r$lengths)[-c(1L, n + 2L)]
  r <- rle(c(FALSE, crude, FALSE))
  interior <- seq.int(2L, length(r$values) - 1L)
  candidates <- interior[r$values[interior]]
  selected <- rep(FALSE, n)
  if (length(candidates)) {
    # `which.max` deliberately selects the first tied window, as GGIR does.
    chosen <- candidates[which.max(r$lengths[candidates])]
    start <- sum(r$lengths[seq_len(chosen - 1L)])
    selected[seq.int(start, start + r$lengths[chosen] - 1L)] <- TRUE
  }
  list(crude = crude, selected = selected)
}

.acti_sleep_result <- function(selected, method, threshold = NA_real_,
                               crude = NULL, details = list()) {
  starts <- which(diff(c(FALSE, selected)) == 1L)
  ends <- which(diff(c(selected, FALSE)) == -1L)
  structure(c(list(
    method = method,
    start_index = if (length(starts)) starts[1L] else NA_integer_,
    end_index = if (length(ends)) ends[1L] else NA_integer_,
    threshold = threshold,
    window = selected,
    crude_window = crude
  ), details), class = "acti_sleep_guider")
}

#' Identify a sleep window with HDCZA
#'
#' Implements the HDCZA sleep-period-time guider for wrist accelerometry.  It
#' finds prolonged periods of little change in the supplied z-axis angle, joins
#' interruptions shorter than an hour, and returns the longest resulting block.
#' The default threshold is the 0.2 degrees specified in the GGIR guider
#' documentation.
#'
#' @param angle Numeric z-axis angle in degrees, at a regular epoch interval.
#' @param time Optional POSIXct timestamps used to infer `epoch_seconds`.
#' @param epoch_seconds Length of an epoch in seconds.
#' @param threshold Maximum five-minute rolling median absolute angle change.
#' @param invalid Optional logical/numeric invalid-data indicator.
#' @param ignore_invalid Whether invalid observations are treated as movement;
#'   use `NA` to treat them as no movement.
#' @param min_block_minutes Minimum low-movement block duration.
#' @param max_gap_minutes Maximum interruption bridged between blocks.
#' @return An `acti_sleep_guider` object. `window` is the selected SPT guider;
#'   `crude_window` retains all candidate blocks before choosing the longest.
#' @export
acti_sleep_hdcza <- function(angle, time = NULL, epoch_seconds = NULL,
                             threshold = 0.2, invalid = NULL,
                             ignore_invalid = FALSE,
                             min_block_minutes = 30,
                             max_gap_minutes = 60) {
  angle <- .acti_sleep_check_vector(angle, "angle")
  n <- length(angle)
  epoch_seconds <- .acti_sleep_epoch_seconds(time, epoch_seconds)
  assertthat::assert_that(
    assertthat::is.number(threshold), threshold >= 0,
    msg = "`threshold` must be one non-negative number."
  )
  if (is.null(invalid)) invalid <- rep(FALSE, n)
  assertthat::assert_that(
    assertthat::are_equal(length(invalid), n),
    msg = "`invalid` must match `angle`."
  )

  width <- max(1L, round(5 * 60 / epoch_seconds))
  angle_change <- abs(diff(angle))
  rolling_change <- .acti_sleep_roll_apply(
    angle_change, width, function(x) stats::median(x, na.rm = TRUE)
  )
  # diff() is one observation shorter; its last rolling value is not needed.
  rolling_change <- c(rolling_change, 0)[seq_len(n)]
  low_movement <- rolling_change < threshold
  invalid <- as.logical(invalid)
  if (is.na(ignore_invalid)) {
    low_movement[invalid] <- TRUE
  } else if (isTRUE(ignore_invalid)) {
    low_movement[invalid] <- FALSE
  }

  blocks <- .acti_sleep_blocks(
    low_movement,
    min_block_epochs = 60 * min_block_minutes / epoch_seconds,
    max_gap_epochs = 60 * max_gap_minutes / epoch_seconds
  )
  method <- if (is.na(ignore_invalid) && any(invalid & blocks$selected)) {
    "HDCZA+invalid"
  } else {
    "HDCZA"
  }
  .acti_sleep_result(blocks$selected, method, threshold, blocks$crude,
                     list(angle_change = rolling_change,
                          low_movement = low_movement))
}

#' Identify a sleep window from horizontal posture
#'
#' @inheritParams acti_sleep_hdcza
#' @param horizontal_threshold Absolute-angle limit defining horizontal posture.
#' @export
acti_sleep_horangle <- function(angle, time = NULL, epoch_seconds = NULL,
                                horizontal_threshold = 45, invalid = NULL,
                                ignore_invalid = FALSE,
                                min_block_minutes = 30,
                                max_gap_minutes = 60) {
  angle <- .acti_sleep_check_vector(angle, "angle")
  n <- length(angle)
  epoch_seconds <- .acti_sleep_epoch_seconds(time, epoch_seconds)
  if (is.null(invalid)) invalid <- rep(FALSE, n)
  assertthat::assert_that(
    assertthat::are_equal(length(invalid), n),
    msg = "`invalid` must match `angle`."
  )
  horizontal <- abs(angle) < horizontal_threshold
  invalid <- as.logical(invalid)
  if (is.na(ignore_invalid)) horizontal[invalid] <- TRUE
  if (isTRUE(ignore_invalid)) horizontal[invalid] <- FALSE
  blocks <- .acti_sleep_blocks(horizontal,
                               60 * min_block_minutes / epoch_seconds,
                               60 * max_gap_minutes / epoch_seconds)
  .acti_sleep_result(blocks$selected, "HorAngle", horizontal_threshold,
                     blocks$crude, list(horizontal = horizontal))
}

#' Identify a sleep window from the least-active five hours
#'
#' @param activity Numeric activity metric at a regular epoch interval.
#' @inheritParams acti_sleep_hdcza
#' @param l5_hours Duration of the least-active period.
#' @param window_hours Duration of the guider centred on L5.
#' @export
acti_sleep_l5 <- function(activity, time = NULL, epoch_seconds = NULL,
                          l5_hours = 5, window_hours = 12) {
  activity <- .acti_sleep_check_vector(activity, "activity")
  n <- length(activity)
  epoch_seconds <- .acti_sleep_epoch_seconds(time, epoch_seconds)
  l5_epochs <- round(l5_hours * 3600 / epoch_seconds)
  window_epochs <- round(window_hours * 3600 / epoch_seconds)
  if (l5_epochs < 1L || l5_epochs > n || window_epochs < l5_epochs) {
    stop("The requested L5/window durations are incompatible with the data.",
         call. = FALSE)
  }
  # Circular windows make an L5 period across midnight eligible.
  x <- c(activity, activity[seq_len(l5_epochs - 1L)])
  sums <- vapply(seq_len(n), function(i) sum(x[i:(i + l5_epochs - 1L)],
                                             na.rm = TRUE), numeric(1))
  l5_start <- which.min(sums)
  start <- ((l5_start - floor((window_epochs - l5_epochs) / 2) - 2L) %% n) + 1L
  window <- ((seq_len(n) - start) %% n) < window_epochs
  .acti_sleep_result(window, "L5+/-12", NA_real_, NULL,
                     list(l5_start_index = l5_start,
                          l5_activity_sum = sums[l5_start]))
}

#' Identify a fixed daily sleep window
#'
#' @param time POSIXct timestamps.
#' @param start_hour,end_hour Start and end clock hours (0--24).
#' @return An `acti_sleep_guider` object.
#' @export
acti_sleep_setwindow <- function(time, start_hour = 22, end_hour = 8) {
  assertthat::assert_that(inherits(time, "POSIXt"),
                          msg = "`time` must be a POSIXct/POSIXlt vector.")
  assertthat::assert_that(
    assertthat::is.number(start_hour), assertthat::is.number(end_hour),
    start_hour >= 0, start_hour <= 24, end_hour >= 0, end_hour <= 24,
    msg = "`start_hour` and `end_hour` must be between 0 and 24."
  )
  clock_hour <- as.numeric(format(time, "%H")) +
    as.numeric(format(time, "%M")) / 60 +
    as.numeric(format(time, "%S")) / 3600
  if (start_hour < end_hour) {
    window <- clock_hour >= start_hour & clock_hour < end_hour
  } else {
    window <- clock_hour >= start_hour | clock_hour < end_hour
  }
  .acti_sleep_result(window, "setwindow", NA_real_, NULL,
                     list(start_hour = start_hour, end_hour = end_hour))
}

#' Identify the longest rest bout from sustained inactivity bouts
#'
#' @param sib Logical/numeric sustained-inactivity-bout classification.
#' @inheritParams acti_sleep_hdcza
#' @export
acti_sleep_hlrb <- function(sib, time = NULL, epoch_seconds = NULL) {
  assertthat::assert_that(
    is.numeric(sib) || is.logical(sib), assertthat::not_empty(sib),
    msg = "`sib` must be a non-empty numeric or logical vector."
  )
  sib <- as.logical(sib)
  n <- length(sib)
  epoch_seconds <- .acti_sleep_epoch_seconds(time, epoch_seconds)
  # The documented HLRB method uses a rounded, two-hour rolling average.
  k <- max(1L, round(2 * 3600 / epoch_seconds))
  smooth <- .acti_sleep_roll_apply(as.numeric(sib), k,
                                   function(x) mean(x, na.rm = TRUE)) >= 0.5
  r <- rle(c(FALSE, smooth, FALSE))
  interior <- seq.int(2L, length(r$values) - 1L)
  short_wake <- interior[!r$values[interior] &
                           r$lengths[interior] < 3600 / epoch_seconds]
  if (length(short_wake)) r$values[short_wake] <- TRUE
  crude <- rep(r$values, r$lengths)[-c(1L, n + 2L)]
  blocks <- .acti_sleep_blocks(crude, 0, 0)
  .acti_sleep_result(blocks$selected, "HLRB", NA_real_, crude,
                     list(smoothed_sib = smooth))
}

#' Identify a low-activity window for no-night-wear protocols
#'
#' @inheritParams acti_sleep_hdcza
#' @param activity Numeric acceleration metric or count data.
#' @export
acti_sleep_notworn <- function(activity, time = NULL, epoch_seconds = NULL,
                               invalid = NULL, min_block_minutes = 30,
                               max_gap_minutes = 60) {
  activity <- .acti_sleep_check_vector(activity, "activity")
  n <- length(activity)
  epoch_seconds <- .acti_sleep_epoch_seconds(time, epoch_seconds)
  if (is.null(invalid)) invalid <- rep(FALSE, n)
  assertthat::assert_that(
    assertthat::are_equal(length(invalid), n),
    msg = "`invalid` must match `activity`."
  )
  width <- max(1L, round(5 * 60 / epoch_seconds))
  smooth <- stats::filter(activity, rep(1 / width, width), sides = 2,
                          circular = TRUE)
  smooth <- as.numeric(smooth)
  nonzero <- smooth[smooth != 0 & is.finite(smooth)]
  threshold <- if (length(nonzero)) 0.05 * stats::sd(nonzero) else 0
  if (length(nonzero) && threshold < min(activity, na.rm = TRUE)) {
    threshold <- stats::quantile(smooth, 0.1, na.rm = TRUE, names = FALSE)
  }
  low_activity <- smooth < threshold + 0.001 | as.logical(invalid)
  blocks <- .acti_sleep_blocks(low_activity,
                               60 * min_block_minutes / epoch_seconds,
                               60 * max_gap_minutes / epoch_seconds)
  .acti_sleep_result(blocks$selected, "NotWorn", threshold, blocks$crude,
                     list(smoothed_activity = smooth,
                          low_activity = low_activity))
}

#' Identify a diary-defined sleep window
#'
#' @param time POSIXct timestamps.
#' @param onset,wakeup POSIXct values defining a diary sleep window.
#' @return An `acti_sleep_guider` object. Missing diary times return an empty
#'   window rather than imputing either boundary.
#' @export
acti_sleep_diary <- function(time, onset, wakeup) {
  assertthat::assert_that(inherits(time, "POSIXt"),
                          msg = "`time` must be POSIXct/POSIXlt.")
  assertthat::assert_that(
    assertthat::is.scalar(onset), assertthat::is.scalar(wakeup),
    msg = "`onset` and `wakeup` must each contain one timestamp."
  )
  if (is.na(onset) || is.na(wakeup)) {
    return(.acti_sleep_result(rep(FALSE, length(time)), "sleeplog"))
  }
  if (wakeup < onset) stop("`wakeup` must not precede `onset`.", call. = FALSE)
  .acti_sleep_result(time >= onset & time <= wakeup, "sleeplog",
                     details = list(onset = onset, wakeup = wakeup))
}

#' Dispatch a sleep-period-time guider
#'
#' @param method One of `"HDCZA"`, `"HorAngle"`, `"L5"`, `"setwindow"`,
#'   `"HLRB"`, `"NotWorn"`, or `"sleeplog"`.
#' @param ... Arguments passed to the selected guider.
#' @return An `acti_sleep_guider` object.
#' @export
acti_sleep_guider <- function(method = c("HDCZA", "HorAngle", "L5",
                                         "setwindow", "HLRB", "NotWorn",
                                         "sleeplog"), ...) {
  method <- match.arg(method)
  switch(method,
         HDCZA = acti_sleep_hdcza(...),
         HorAngle = acti_sleep_horangle(...),
         L5 = acti_sleep_l5(...),
         setwindow = acti_sleep_setwindow(...),
         HLRB = acti_sleep_hlrb(...),
         NotWorn = acti_sleep_notworn(...),
         sleeplog = acti_sleep_diary(...)
  )
}
