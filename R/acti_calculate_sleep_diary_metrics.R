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

# Internal helpers ------------------------------------------------------------

# Run-length ID: each run of repeated values gets its own integer
rleid = function(x) {
  x = rle(x)$lengths
  rep(seq_along(x), times = x)
}

# Epoch length (seconds) of `time`, which must be strictly increasing with
# every gap a whole number of epochs.  The metrics count bouts of at most one
# minute, so the epoch must divide 60 seconds (e.g. 15, 30, or 60).
sleep_diary_epoch_seconds = function(time, epoch_seconds = NULL) {
  epoch_seconds = .acti_sleep_epoch_seconds(time, epoch_seconds)
  if (!isTRUE(all.equal(60 %% epoch_seconds, 0)) &&
      !isTRUE(all.equal(60 %% epoch_seconds, epoch_seconds))) {
    stop("Epoch length is ", epoch_seconds, " seconds; sleep diary metrics ",
         "need an epoch that divides 60 seconds (e.g. 15, 30, or 60).",
         call. = FALSE)
  }
  if (length(time) >= 2L) {
    d = as.numeric(diff(time), units = "secs")
    steps = d / epoch_seconds
    if (any(d <= 0) || any(abs(steps - round(steps)) > 1e-6)) {
      stop("`time` must be strictly increasing on a regular ", epoch_seconds,
           "-second epoch grid (gaps must be whole epochs).", call. = FALSE)
    }
  }
  epoch_seconds
}

# Standardize diary columns to in_bed_time/onset_time/out_bed_time/index.
# onset_time is optional: without it, onset is the in-bed time (latency 0).
check_diary = function(diary,
                       in_bed_col = "in_bed_time",
                       onset_col = "onset_time",
                       out_bed_col = "out_bed_time") {
  assertthat::assert_that(
    is.data.frame(diary), nrow(diary) > 0,
    msg = "`diary` must be a data frame with at least one row."
  )
  missing_cols = setdiff(c(in_bed_col, out_bed_col), names(diary))
  if (length(missing_cols) > 0) {
    stop("`diary` is missing column(s): ",
         paste0("`", missing_cols, "`", collapse = ", "), ".", call. = FALSE)
  }
  diary = tibble::as_tibble(diary)
  diary$in_bed_time = diary[[in_bed_col]]
  diary$out_bed_time = diary[[out_bed_col]]
  diary$onset_time = if (onset_col %in% names(diary)) {
    diary[[onset_col]]
  } else {
    diary$in_bed_time
  }
  times = diary[c("in_bed_time", "onset_time", "out_bed_time")]
  assertthat::assert_that(
    all(vapply(times, inherits, logical(1), what = "POSIXt")),
    !anyNA(unlist(times)),
    msg = "Diary in-bed, onset, and out-of-bed times must be complete POSIXct times."
  )
  if (any(diary$onset_time < diary$in_bed_time) ||
      any(diary$out_bed_time <= diary$onset_time)) {
    stop("Each diary row needs in_bed_time <= onset_time < out_bed_time.",
         call. = FALSE)
  }
  ord = order(diary$in_bed_time)
  if (length(ord) > 1 &&
      any(diary$in_bed_time[ord][-1] < diary$out_bed_time[ord][-length(ord)])) {
    stop("Diary in-bed periods must not overlap.", call. = FALSE)
  }
  if (!"index" %in% names(diary)) {
    diary$index = seq_len(nrow(diary))
  }
  if (anyDuplicated(diary$index)) {
    stop("`diary$index` must be unique.", call. = FALSE)
  }
  diary
}

# One row per epoch in each in-bed period: [in_bed_time, out_bed_time)
expand_start_stop = function(diary, epoch_seconds = 60) {
  dplyr::bind_rows(Map(
    function(from, onset, to, index) {
      # change for the end - not the last value
      time = seq(from, to - epoch_seconds, by = epoch_seconds)
      tibble::tibble(time = time,
                     in_bed = TRUE,
                     is_past_onset = time >= onset,
                     index = index)
    },
    diary$in_bed_time, diary$onset_time, diary$out_bed_time, diary$index
  ))
}

#' Apply diary bed times to data
#' @noRd
apply_diary_bed_times = function(data, diary, epoch_seconds = 60,
                                 check_times = TRUE) {
  in_bed = is_past_onset = NULL
  rm(list = c("in_bed", "is_past_onset"))

  ss = expand_start_stop(diary, epoch_seconds = epoch_seconds)

  if (check_times) {
    # every in-bed epoch must be in the data (no gaps, aligned to the grid)
    missing_time = !as.numeric(ss$time) %in% as.numeric(data$time)
    if (any(missing_time)) {
      stop(sum(missing_time), " in-bed epoch(s) from the diary are not in ",
           "`data` (first: ", format(ss$time[missing_time][1], usetz = TRUE),
           "); check the diary times, epoch alignment, and gaps in `data`, ",
           "or set `check_times = FALSE`.", call. = FALSE)
    }
  }

  data |>
    dplyr::left_join(ss, by = "time") |>
    dplyr::mutate(
      in_bed = dplyr::coalesce(in_bed, FALSE),
      is_past_onset = dplyr::coalesce(is_past_onset, FALSE)
    )
}

# Sleep metrics for one in-bed period.  `data` holds that period's epochs with
# `in_bed`, `is_past_onset`, `sleep` ("S"/"W"), `axis1`, and optionally `vm`.
# Minutes are epochs * epoch_seconds / 60.  The sleep period runs from onset to
# out of bed.
calculate_sleep_metrics = function(data, epoch_seconds = 60,
                                   do_rounding = TRUE,
                                   rounder = c("round", "Round")) {
  vm = axis1 = sleep = is_past_onset = in_bed = NULL
  duration = total_sleep_time = nb_awakenings = NULL
  movement_index = fragmentation_index = NULL
  ave_awakening = efficiency = sleep_fragmentation_index = NULL
  rm(list = c("vm", "axis1", "sleep", "is_past_onset", "in_bed",
              "duration", "total_sleep_time", "nb_awakenings",
              "movement_index", "fragmentation_index",
              "ave_awakening", "efficiency", "sleep_fragmentation_index"))

  minutes_per_epoch = epoch_seconds / 60
  if (!"vm" %in% names(data)) {
    data$vm = NA_real_
  }
  in_bed_data = data |>
    dplyr::filter(in_bed)
  sleep_period = in_bed_data |>
    dplyr::filter(is_past_onset)

  sums = in_bed_data |>
    dplyr::summarise(
      # time from getting into bed to sleep onset
      latency = sum(!is_past_onset) * minutes_per_epoch,
      duration = dplyr::n() * minutes_per_epoch
    )
  period_sums = sleep_period |>
    dplyr::summarise(
      activity_counts = sum(axis1),
      activity_counts_vm = sum(vm),
      nonzero_epochs = sum(axis1 > 0),
      total_sleep_time = sum(sleep == "S") * minutes_per_epoch,
      wake_after_onset = sum(sleep == "W") * minutes_per_epoch,
      movement_index = if (dplyr::n() > 0) 100 * mean(axis1 > 0) else NA_real_
    )
  sums = dplyr::bind_cols(sums, period_sums) |>
    dplyr::mutate(
      # sleep time over time in bed
      efficiency = 100 * total_sleep_time / duration
    )

  # Runs of sleep/wake within the sleep period
  runs = sleep_period |>
    dplyr::group_by(rleid = rleid(sleep)) |>
    dplyr::summarise(
      sleep = dplyr::first(sleep),
      duration = dplyr::n() * minutes_per_epoch,
      .groups = "drop"
    ) |>
    dplyr::mutate(
      # wake at diary onset is not an awakening
      nb_awakenings = sleep == "W" & dplyr::row_number() > 1
    )

  sleep_bouts = runs$duration[runs$sleep == "S"]
  sums$fragmentation_index = if (length(sleep_bouts) > 0) {
    # percent of sleep bouts that are at most one minute
    100 * mean(sleep_bouts <= 1 + 1e-8)
  } else {
    0
  }
  awakenings = runs$duration[runs$nb_awakenings]
  sums$nb_awakenings = length(awakenings)
  sums$ave_awakening = if (length(awakenings) > 0) mean(awakenings) else 0
  sums = sums |>
    dplyr::mutate(
      sleep_fragmentation_index = movement_index + fragmentation_index
    )

  if (do_rounding) {
    rounder = match.arg(rounder)
    func_round = switch(rounder,
                        round = round,
                        Round = round_half_away)
    sums = sums |>
      dplyr::mutate(
        ave_awakening = func_round(ave_awakening, 2L),
        efficiency = func_round(efficiency, 2L),
        movement_index = func_round(movement_index, 3L),
        fragmentation_index = func_round(fragmentation_index, 3L),
        sleep_fragmentation_index = func_round(sleep_fragmentation_index, 3L)
      )
  }
  sums |>
    dplyr::select(
      "latency", "efficiency", "duration", "activity_counts",
      "activity_counts_vm", "nonzero_epochs", "total_sleep_time",
      "wake_after_onset", "nb_awakenings", "ave_awakening", "movement_index",
      "fragmentation_index", "sleep_fragmentation_index"
    )
}
