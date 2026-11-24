#' Calculate sleep metrics from diary bed times
#'
#' Scores each diary night from epoch-level sleep/wake data (e.g. from
#' [acti_calculate_cole_kripke()] or [acti_calculate_sadeh()]) using the
#' diary's in-bed, sleep-onset, and out-of-bed times, as ActiLife does when
#' bed times are entered from a sleep diary.  [acti_calculate_tudor_locke()]
#' instead detects bed and onset times from the counts, so its latency is
#' always 0.
#'
#' @param data Epoch-level data with a POSIXct `time` (or `timestamp`)
#'   column, a `sleep` column (`"S"`/`"W"`, or logical with `TRUE` for sleep),
#'   and `axis1` counts.  A vector-magnitude column (`counts`,
#'   `vector.magnitude`, or `vm`) is optional and gives `activity_counts_vm`.
#' @param diary A data frame with one row per night and POSIXct in-bed and
#'   out-of-bed times, and optionally sleep-onset times.  Without an onset
#'   column, onset is the in-bed time.  An `index` column, if present, labels
#'   the nights and must be unique.  Other columns are kept in the output.
#' @param in_bed_col,onset_col,out_bed_col Names of the diary in-bed,
#'   sleep-onset, and out-of-bed columns.  Out of bed is exclusive: the epoch
#'   starting at `out_bed_time` is not in bed.
#' @param epoch_seconds Epoch length in seconds.  If `NULL`, it is estimated
#'   from `time`.  It must divide 60 seconds (e.g. 15, 30, or 60).
#' @param check_times If `TRUE`, every in-bed epoch must be in `data`, so
#'   that the diary times are on the epoch grid and there are no gaps.
#' @param do_rounding If `TRUE`, round `efficiency` and `ave_awakening` to 2
#'   digits and the movement and fragmentation indices to 3 digits.
#' @param rounder `"round"` uses base `round()` (round half to even);
#'   `"Round"` rounds half away from zero, as ActiLife does.
#'
#' @return A tibble with one row per diary night: the diary columns
#'   (`index`, `in_bed_time`, `onset_time`, `out_bed_time`, and any others),
#'   then the metrics below.  Times are in minutes.  The *sleep period* runs
#'   from `onset_time` to `out_bed_time`.
#' \describe{
#'   \item{latency}{Time from getting into bed to sleep onset.}
#'   \item{efficiency}{100 * `total_sleep_time` / `duration`.}
#'   \item{duration}{Time in bed, from `in_bed_time` to `out_bed_time`.}
#'   \item{activity_counts, activity_counts_vm}{Sum of `axis1` and of the
#'     vector magnitude (`NA` if absent) in the sleep period.}
#'   \item{nonzero_epochs}{Sleep-period epochs with `axis1 > 0`.}
#'   \item{total_sleep_time}{Sleep (`"S"`) time in the sleep period.}
#'   \item{wake_after_onset}{Wake (`"W"`) time in the sleep period (WASO).}
#'   \item{nb_awakenings}{Number of wake bouts in the sleep period, not
#'     counting a wake bout at onset.}
#'   \item{ave_awakening}{Mean length of those wake bouts (0 if none).}
#'   \item{movement_index}{Percent of sleep-period epochs with `axis1 > 0`.}
#'   \item{fragmentation_index}{Percent of sleep bouts that are at most one
#'     minute long (0 if no sleep).}
#'   \item{sleep_fragmentation_index}{`movement_index` +
#'     `fragmentation_index`.}
#' }
#' @export
#' @examples
#' data = actimetrics::acti_count_data
#' ck = acti_calculate_cole_kripke(data)
#' diary = data.frame(
#'   in_bed_time = data$time[5],
#'   onset_time = data$time[10],
#'   out_bed_time = data$time[35]
#' )
#' acti_calculate_sleep_diary_metrics(ck, diary)
acti_calculate_sleep_diary_metrics = function(
    data, diary,
    in_bed_col = "in_bed_time",
    onset_col = "onset_time",
    out_bed_col = "out_bed_time",
    epoch_seconds = NULL,
    check_times = TRUE,
    do_rounding = TRUE,
    rounder = c("round", "Round")) {
  index = NULL
  rm(list = c("index"))
  rounder = match.arg(rounder)
  assertthat::assert_that(is.data.frame(data),
                          assertthat::is.flag(check_times),
                          assertthat::is.flag(do_rounding))

  if (!"time" %in% names(data) && "timestamp" %in% names(data)) {
    data$time = data$timestamp
  }
  missing_cols = setdiff(c("time", "sleep", "axis1"), names(data))
  if (length(missing_cols) > 0) {
    stop("`data` is missing column(s): ",
         paste0("`", missing_cols, "`", collapse = ", "),
         "; run acti_calculate_cole_kripke() or acti_calculate_sadeh() on ",
         "counts from acti_calculate_counts().", call. = FALSE)
  }
  assertthat::assert_that(
    inherits(data$time, "POSIXt"), !anyNA(data$time),
    msg = "`data$time` must be a complete POSIXct time column."
  )
  sleep = data$sleep
  if (is.logical(sleep)) {
    sleep = ifelse(sleep, "S", "W")
  }
  if (anyNA(sleep) || !all(sleep %in% c("S", "W"))) {
    stop("`data$sleep` must be \"S\"/\"W\" (or logical) with no missing ",
         "values.", call. = FALSE)
  }
  vm_col = intersect(c("vm", "vector.magnitude", "counts"), names(data))
  data = tibble::tibble(
    time = data$time,
    sleep = sleep,
    axis1 = data$axis1,
    vm = if (length(vm_col) > 0) data[[vm_col[1]]] else NA_real_
  )
  data = data[order(data$time), ]
  epoch_seconds = sleep_diary_epoch_seconds(data$time, epoch_seconds)

  diary = check_diary(diary, in_bed_col = in_bed_col, onset_col = onset_col,
                      out_bed_col = out_bed_col)
  data = apply_diary_bed_times(data, diary, epoch_seconds = epoch_seconds,
                               check_times = check_times)

  metrics = dplyr::bind_rows(lapply(diary$index, function(i) {
    night = data[!is.na(data$index) & data$index == i, ]
    calculate_sleep_metrics(night, epoch_seconds = epoch_seconds,
                            do_rounding = do_rounding, rounder = rounder)
  }))
  diary = diary |>
    dplyr::relocate("index", "in_bed_time", "onset_time", "out_bed_time")
  dplyr::bind_cols(diary, metrics)
}
