
expand_start_stop = function(df, subtract_value = 60L) {
  bed_time = purrr::pmap_dfr(
    # change for the end - not the last value
    list(df$in_bed_time, df$out_bed_time - subtract_value, df$index),
    function(from, to, index) {
      data.frame(time = seq(from, to, by = 60L),
                 in_bed = TRUE,
                 index = index)
    })
  onset_time = purrr::pmap_dfr(
    # change for the end - not the last value
    list(df$onset_time, df$out_bed_time - subtract_value, df$index),
    function(from, to, index) {
      data.frame(time = seq(from, to, by = 60L),
                 is_past_onset = TRUE,
                 index = index)
    })
  bed_time = bed_time %>%
    dplyr::full_join(onset_time, by = join_by(time, index)) %>%
    tidyr::replace_na(list(in_bed = FALSE, is_past_onset = FALSE))
  bed_time
}

rleid = function(x) {
  x <- rle(x)$lengths
  rep(seq_along(x), times = x)
}

check_diary = function(diary) {
  onset_time = out_bed_time = NULL
  rm(list = c("out_bed_time", "onset_time"))

  stopifnot("in_bed_time" %in% colnames(diary))
  if (!"onset_time" %in% colnames(diary)) {
    stopifnot("out_bed_time" %in% colnames(diary))
    diary = diary %>%
      dplyr::mutate(onset_time = out_bed_time)
  }
  if (!"out_bed_time" %in% colnames(diary)) {
    stopifnot("onset_time" %in% colnames(diary))
    diary = diary %>%
      dplyr::mutate(out_bed_time = onset_time)
  }
  diary
}

#' Apply diary bed times to data
apply_diary_bed_times = function(data, diary, check_times = TRUE) {

  is_past_onset = in_bed = NULL
  rm(list = c("in_bed", "is_past_onset"))
  diary = check_diary(diary)

  # Get the Sleep diary data from that ID
  ss = expand_start_stop(diary)

  if (check_times) {
    # check to make sure nothing wrong with the date/time
    stopifnot(all(ss$time %in% data$time))
  }

  data = data %>%
    dplyr::left_join(ss, by = "time") %>%
    dplyr::mutate(in_bed = ifelse(is.na(in_bed), FALSE, in_bed),
           is_past_onset = ifelse(is.na(is_past_onset), FALSE, is_past_onset))
  data
}

calculate_sleep_metrics = function(data, do_rounding = TRUE,
                                   rounder = c("round", "Round")) {
  avg_awakening_length = NULL
  rm(list = c("avg_awakening_length"))
  sums = data %>%
    dplyr::summarise(
      total_counts_vm = sum(vm),
      total_counts = sum(axis1),
      latency = sum(!is_past_onset),
      waso = sum(sleep == "W" & is_past_onset),
      total_sleep_time = sum(sleep == "S"),
      total_minutes_in_bed = sum(in_bed),
      efficiency = 100 * total_sleep_time/dplyr::n(),
      movement_index = mean(count > 0) * 100
    ) %>%
    dplyr::select(
      latency, total_counts, efficiency, total_minutes_in_bed,
      total_sleep_time, waso,
      dplyr::everything())

  result = data %>%
    # First round of `group_by`, `summarise`, `mutate` operations
    # Return the stop/end indices for runs of repeated value
    # need rleid for the fragmentation index
    # and for row_number() == 1 below
    dplyr::group_by(
      rleid = rleid(.data$sleep)
    ) %>%
    dplyr::summarise(
      sleep = first(.data$sleep),
      duration = dplyr::n(),
      nonzero_epochs = sum(.data$axis1 > 0),
      activity_counts = sum(.data$axis1)
    )

  fragmentation_index = result %>%
    dplyr::filter(sleep == "S") %>%
    dplyr::summarise(fragmentation_index = mean(duration == 1)) %>%
    dplyr::pull(fragmentation_index)
  fragmentation_index = fragmentation_index * 100

  sums$fragmentation_index = fragmentation_index
  sums = sums %>%
    dplyr::mutate(
      sleep_fragmentation_index = fragmentation_index + movement_index
    )

  result = result %>%
    dplyr::mutate(
      nb_awakenings = (.data$sleep == "W")
    )

  # added to check for awakenings
  result = result %>%
    dplyr::mutate(
      # first onset is wake not really an "awakening"
      nb_awakenings = if_else(
        row_number() == 1 & .data$sleep == "W", FALSE, .data$nb_awakenings
      )
    )

  sub_result = result %>%
    dplyr::ungroup() %>%
    dplyr::summarise(
      # order matters here for summarise
      avg_awakening_length = mean(
        dplyr::if_else(nb_awakenings, duration, NA_real_),
        na.rm = TRUE),
      nb_awakenings = sum(nb_awakenings)
    )
  sub_result = sub_result %>%
    dplyr::mutate(
      avg_awakening_length = dplyr::if_else(nb_awakenings == 0,
                                            0,
                                            avg_awakening_length)
    )

  sums$nb_awakenings = sub_result$nb_awakenings
  sums$avg_awakening_length = sub_result$avg_awakening_length

  if (do_rounding) {
    rounder = match.arg(rounder)
    func_round = switch(rounder,
                        round = round,
                        Round = ncar::Round)
    sums = sums %>%
      dplyr::mutate(
        avg_awakening_length = func_round(avg_awakening_length, 2),
        efficiency = func_round(efficiency, 2L),

        movement_index = func_round(movement_index, 3L),
        fragmentation_index = func_round(fragmentation_index, 3L),
        sleep_fragmentation_index = func_round(sleep_fragmentation_index, 3L)
      )
  }
  sums

}
