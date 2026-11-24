# 2 wake epochs before bed, 10 in bed (2 before onset), 2 after.
# Sleep period (8 epochs): S S W S S S W W
make_sleep_night = function(epoch_seconds = 60) {
  start = as.POSIXct("2020-01-01 22:00:00", tz = "UTC")
  sleep = c("W", "W",           # before bed
            "W", "W",           # in bed, before onset
            "S", "S", "W", "S", "S", "S", "W", "W",
            "W", "W")           # out of bed
  axis1 = c(100, 100,
            50, 0,
            0, 0, 20, 0, 5, 0, 30, 0,
            100, 100)
  data = tibble::tibble(
    time = start + (seq_along(sleep) - 1) * epoch_seconds,
    axis1 = axis1,
    axis2 = 0,
    axis3 = 0,
    counts = 2 * axis1,
    sleep = sleep
  )
  diary = data.frame(
    in_bed_time = data$time[3],
    onset_time = data$time[5],
    out_bed_time = data$time[13]
  )
  list(data = data, diary = diary)
}

test_that("sleep diary metrics are correct for 60-second epochs", {
  x = make_sleep_night(60)
  out = acti_calculate_sleep_diary_metrics(x$data, x$diary)
  expect_equal(nrow(out), 1L)
  expect_equal(out$index, 1L)
  # latency counts only in-bed time before onset, not wake before bed
  expect_equal(out$latency, 2)
  expect_equal(out$duration, 10)
  expect_equal(out$total_sleep_time, 5)
  expect_equal(out$wake_after_onset, 3)
  # efficiency is over time in bed, not all of `data`
  expect_equal(out$efficiency, 50)
  expect_equal(out$activity_counts, 55)
  expect_equal(out$activity_counts_vm, 110)
  expect_equal(out$nonzero_epochs, 3L)
  expect_equal(out$movement_index, 37.5)
  expect_equal(out$nb_awakenings, 2L)
  expect_equal(out$ave_awakening, 1.5)
  # sleep bouts of 2 and 3 minutes: none is 1 minute or shorter
  expect_equal(out$fragmentation_index, 0)
  expect_equal(out$sleep_fragmentation_index, 37.5)
})

test_that("sleep diary metrics use minutes for 30-second epochs", {
  x = make_sleep_night(30)
  out = acti_calculate_sleep_diary_metrics(x$data, x$diary)
  expect_equal(out$latency, 1)
  expect_equal(out$duration, 5)
  expect_equal(out$total_sleep_time, 2.5)
  expect_equal(out$wake_after_onset, 1.5)
  expect_equal(out$efficiency, 50)
  expect_equal(out$nb_awakenings, 2L)
  expect_equal(out$ave_awakening, 0.75)
  # sleep bouts of 1 and 1.5 minutes: half are at most 1 minute
  expect_equal(out$fragmentation_index, 50)
  expect_equal(out$movement_index, 37.5)
  expect_equal(out$sleep_fragmentation_index, 87.5)
})

test_that("sleep diary metrics handle onset, multiple nights, and logical sleep", {
  x = make_sleep_night(60)
  # no onset column: onset is in-bed time, and the leading wake bout at onset
  # is not an awakening
  diary = x$diary[c("in_bed_time", "out_bed_time")]
  out = acti_calculate_sleep_diary_metrics(x$data, diary)
  expect_equal(out$latency, 0)
  expect_equal(out$onset_time, out$in_bed_time)
  expect_equal(out$wake_after_onset, 5)
  expect_equal(out$nb_awakenings, 2L)
  expect_equal(out$efficiency, 50)

  # two nights, other diary columns kept, logical sleep, `timestamp` input
  diary2 = data.frame(
    id = c("a", "b"),
    in_bed_time = x$data$time[c(3, 9)],
    out_bed_time = x$data$time[c(7, 13)]
  )
  data2 = x$data
  data2$sleep = data2$sleep == "S"
  names(data2)[names(data2) == "time"] = "timestamp"
  out2 = acti_calculate_sleep_diary_metrics(data2, diary2)
  expect_equal(out2$id, c("a", "b"))
  expect_equal(out2$duration, c(4, 4))
  expect_equal(out2$total_sleep_time, c(2, 2))
  expect_equal(out2$efficiency, c(50, 50))

  # custom column names
  diary3 = stats::setNames(x$diary, c("bed", "asleep", "up"))
  out3 = acti_calculate_sleep_diary_metrics(
    x$data, diary3, in_bed_col = "bed", onset_col = "asleep",
    out_bed_col = "up")
  expect_equal(out3$latency, 2)
})

test_that("sleep diary metrics round with either rounder", {
  x = make_sleep_night(60)
  x$diary$out_bed_time = x$data$time[12]
  # 5 sleep of 9 in bed: 55.555...
  out = acti_calculate_sleep_diary_metrics(x$data, x$diary)
  expect_equal(out$efficiency, 55.56)
  out = acti_calculate_sleep_diary_metrics(x$data, x$diary,
                                           do_rounding = FALSE)
  expect_equal(out$efficiency, 500 / 9)
  expect_error(acti_calculate_sleep_diary_metrics(x$data, x$diary,
                                                  rounder = "floor"))
})

test_that("rounder = \"Round\" rounds half away from zero (15-second epochs)", {
  # sleep period: S W S W W W W S -> awakenings of 0.25 and 1 minute, mean
  # 0.625, which round() gives as 0.62 and round half away as 0.63
  sleep = c("S", "W", "S", "W", "W", "W", "W", "S")
  data = tibble::tibble(
    time = as.POSIXct("2020-01-01 23:00:00", tz = "UTC") + (0:7) * 15,
    axis1 = 0, sleep = sleep
  )
  diary = data.frame(in_bed_time = data$time[1],
                     out_bed_time = data$time[8] + 15)
  out = acti_calculate_sleep_diary_metrics(data, diary, do_rounding = FALSE)
  expect_equal(out$duration, 2)
  expect_equal(out$total_sleep_time, 0.75)
  expect_equal(out$wake_after_onset, 1.25)
  expect_equal(out$nb_awakenings, 2L)
  expect_equal(out$ave_awakening, 0.625)
  # all three sleep bouts are 15 seconds
  expect_equal(out$fragmentation_index, 100)
  expect_equal(
    acti_calculate_sleep_diary_metrics(data, diary)$ave_awakening, 0.62)
  expect_equal(
    acti_calculate_sleep_diary_metrics(data, diary,
                                       rounder = "Round")$ave_awakening,
    0.63)
  # no vector magnitude column
  expect_true(is.na(out$activity_counts_vm))
})

test_that("sleep diary metrics check epochs, diary, and data", {
  x = make_sleep_night(60)
  # 45-second epochs do not divide a minute
  y = make_sleep_night(45)
  expect_error(acti_calculate_sleep_diary_metrics(y$data, y$diary),
               "divides 60 seconds")
  # irregular times
  z = x$data
  z$time[4] = z$time[4] + 10
  expect_error(acti_calculate_sleep_diary_metrics(z, x$diary),
               "regular 60-second epoch grid")
  # a missing in-bed epoch
  expect_error(acti_calculate_sleep_diary_metrics(x$data[-6, ], x$diary),
               "not in `data`")
  # diary times off the epoch grid
  d = x$diary
  d$in_bed_time = d$in_bed_time + 30
  expect_error(acti_calculate_sleep_diary_metrics(x$data, d), "not in `data`")
  # onset before bed, or out of bed before onset
  d = x$diary
  d$onset_time = d$in_bed_time - 60
  expect_error(acti_calculate_sleep_diary_metrics(x$data, d),
               "in_bed_time <= onset_time")
  # overlapping nights
  d = rbind(x$diary, x$diary)
  expect_error(acti_calculate_sleep_diary_metrics(x$data, d), "overlap")
  expect_error(
    acti_calculate_sleep_diary_metrics(x$data, x$diary["in_bed_time"]),
    "missing column")
  expect_error(
    acti_calculate_sleep_diary_metrics(x$data[c("time", "axis1")], x$diary),
    "`sleep`")
  bad = x$data
  bad$sleep[1] = NA
  expect_error(acti_calculate_sleep_diary_metrics(bad, x$diary), "S\"/\"W")
})

test_that("sleep diary metrics work on Cole-Kripke output", {
  skip_if_not_installed("actigraph.sleepr")
  data = actimetrics::acti_count_data
  ck = acti_calculate_cole_kripke(data)
  diary = data.frame(in_bed_time = data$time[5],
                     onset_time = data$time[10],
                     out_bed_time = data$time[35])
  out = acti_calculate_sleep_diary_metrics(ck, diary)
  expect_equal(out$latency, 5)
  expect_equal(out$duration, 30)
  expect_equal(out$total_sleep_time + out$wake_after_onset, 25)
  expect_equal(out$activity_counts, sum(ck$axis1[10:34]))
  expect_equal(out$activity_counts_vm, sum(ck$counts[10:34]))
})

test_that("sleep diary metrics match Tudor-Locke on the same bed times", {
  skip_if_not_installed("actigraph.sleepr")
  n = 300
  sleep = rep("W", n)
  sleep[41:260] = "S"
  # short wake bouts (kept in the Tudor-Locke period) and a 1-minute sleep
  # bout at 121
  sleep[c(80, 81, 120, 122, 150:153, 200)] = "W"
  sleep[30] = "S"
  axis1 = ifelse(sleep == "W", 200, 0)
  axis1[c(90, 91, 170)] = 15
  data = tibble::tibble(
    time = as.POSIXct("2020-01-01 21:00:00", tz = "UTC") + (seq_len(n) - 1) * 60,
    axis1 = axis1, axis2 = 0, axis3 = 0, sleep = sleep
  )
  tl = acti_calculate_tudor_locke(data)
  expect_equal(nrow(tl), 1L)
  diary = data.frame(in_bed_time = tl$in_bed_time,
                     out_bed_time = tl$out_bed_time)
  out = acti_calculate_sleep_diary_metrics(data, diary, do_rounding = FALSE)
  expect_gt(tl$fragmentation_index, 0)
  for (col in c("latency", "efficiency", "duration", "activity_counts",
                "nonzero_epochs", "total_sleep_time", "wake_after_onset",
                "nb_awakenings", "ave_awakening", "movement_index",
                "fragmentation_index", "sleep_fragmentation_index")) {
    expect_equal(as.numeric(out[[col]]), as.numeric(tl[[col]]), label = col)
  }
})

test_that("sleep diary metrics handle nights with no sleep or no wake", {
  x = make_sleep_night(60)
  awake = x$data
  awake$sleep = "W"
  out = acti_calculate_sleep_diary_metrics(awake, x$diary)
  expect_equal(out$total_sleep_time, 0)
  expect_equal(out$efficiency, 0)
  expect_equal(out$wake_after_onset, 8)
  # the whole sleep period is one wake bout at onset: not an awakening
  expect_equal(out$nb_awakenings, 0L)
  expect_equal(out$ave_awakening, 0)
  expect_equal(out$fragmentation_index, 0)

  asleep = x$data
  asleep$sleep = "S"
  out = acti_calculate_sleep_diary_metrics(asleep, x$diary)
  # before onset is latency even when scored as sleep
  expect_equal(out$latency, 2)
  expect_equal(out$total_sleep_time, 8)
  expect_equal(out$efficiency, 80)
  expect_equal(out$wake_after_onset, 0)
  expect_equal(out$nb_awakenings, 0L)
  expect_equal(out$ave_awakening, 0)
  expect_equal(out$fragmentation_index, 0)
})

test_that("sleep diary metrics do not depend on data order, gaps, or time zone", {
  x = make_sleep_night(60)
  base = acti_calculate_sleep_diary_metrics(x$data, x$diary)

  shuffled = x$data[c(14:1), ]
  expect_equal(acti_calculate_sleep_diary_metrics(shuffled, x$diary), base)

  # a gap outside the in-bed period is fine
  gap = x$data[-c(1, 14), ]
  expect_equal(acti_calculate_sleep_diary_metrics(gap, x$diary), base)
  gap = x$data[-2, ]
  expect_equal(acti_calculate_sleep_diary_metrics(gap, x$diary), base)

  # the same instants in another time zone
  ny = x$diary
  ny[] = lapply(ny, lubridate::with_tz, tzone = "America/New_York")
  out = acti_calculate_sleep_diary_metrics(x$data, ny)
  expect_equal(out[-(2:4)], base[-(2:4)])
  expect_equal(as.numeric(out$in_bed_time), as.numeric(base$in_bed_time))
})

test_that("sleep diary metrics take epoch_seconds and check_times", {
  x = make_sleep_night(60)
  expect_equal(
    acti_calculate_sleep_diary_metrics(x$data, x$diary, epoch_seconds = 60),
    acti_calculate_sleep_diary_metrics(x$data, x$diary))
  # 60-second data are on a 30-second grid with gaps, but the in-bed
  # 30-second epochs are missing
  expect_error(
    acti_calculate_sleep_diary_metrics(x$data, x$diary, epoch_seconds = 30),
    "not in `data`")
  expect_error(
    acti_calculate_sleep_diary_metrics(x$data, x$diary, epoch_seconds = 120),
    "divides 60 seconds")
  expect_error(
    acti_calculate_sleep_diary_metrics(x$data, x$diary, epoch_seconds = -1),
    "positive")

  # check_times = FALSE scores the in-bed epochs that are present
  out = acti_calculate_sleep_diary_metrics(x$data[-6, ], x$diary,
                                           check_times = FALSE)
  expect_equal(out$duration, 9)
  expect_equal(out$total_sleep_time, 4)
  expect_error(
    acti_calculate_sleep_diary_metrics(x$data, x$diary, check_times = NA))
})

test_that("sleep diary metrics keep a user index and reject duplicates", {
  x = make_sleep_night(60)
  d = x$diary
  d$index = 7L
  d$note = "night 1"
  out = acti_calculate_sleep_diary_metrics(x$data, d)
  expect_equal(out$index, 7L)
  expect_equal(out$note, "night 1")
  expect_equal(names(out)[1:4],
               c("index", "in_bed_time", "onset_time", "out_bed_time"))

  d2 = data.frame(in_bed_time = x$data$time[c(3, 9)],
                  out_bed_time = x$data$time[c(7, 13)],
                  index = c(1, 1))
  expect_error(acti_calculate_sleep_diary_metrics(x$data, d2), "unique")

  # nights given out of order are still scored by their own times
  d3 = d2[2:1, ]
  d3$index = c("late", "early")
  out3 = acti_calculate_sleep_diary_metrics(x$data, d3)
  expect_equal(out3$index, c("late", "early"))
  expect_equal(out3$total_sleep_time, c(2, 2))
  expect_equal(out3$latency, c(0, 0))
})

test_that("sleep diary metrics validate diary and data types", {
  x = make_sleep_night(60)
  expect_error(acti_calculate_sleep_diary_metrics(x$data, x$diary[0, ]),
               "at least one row")
  expect_error(acti_calculate_sleep_diary_metrics(x$data, "diary"),
               "data frame")
  d = x$diary
  d$in_bed_time = as.character(d$in_bed_time)
  expect_error(acti_calculate_sleep_diary_metrics(x$data, d), "POSIXct")
  d = x$diary
  d$out_bed_time = NA
  expect_error(acti_calculate_sleep_diary_metrics(x$data, d), "POSIXct")
  d = x$diary
  d$out_bed_time = d$onset_time
  expect_error(acti_calculate_sleep_diary_metrics(x$data, d),
               "onset_time < out_bed_time")
  bad = x$data
  bad$time = as.character(bad$time)
  expect_error(acti_calculate_sleep_diary_metrics(bad, x$diary), "POSIXct")
  bad = x$data
  bad$sleep[3] = "A"
  expect_error(acti_calculate_sleep_diary_metrics(bad, x$diary), "S\"/\"W")
  expect_error(acti_calculate_sleep_diary_metrics(list(), x$diary))
  dup = rbind(x$data, x$data[5, ])
  expect_error(acti_calculate_sleep_diary_metrics(dup, x$diary),
               "strictly increasing")
})

test_that("sleep diary helpers work on their own", {
  expect_equal(rleid(c("W", "W", "S", "W", "S", "S")), c(1, 1, 2, 3, 4, 4))
  expect_equal(rleid(character()), integer())

  t0 = as.POSIXct("2020-01-01 22:00:00", tz = "UTC")
  expect_equal(sleep_diary_epoch_seconds(t0 + c(0, 30, 60, 120)), 30)
  expect_equal(sleep_diary_epoch_seconds(t0 + (0:3) * 15), 15)
  expect_equal(sleep_diary_epoch_seconds(t0, epoch_seconds = 60), 60)
  expect_error(sleep_diary_epoch_seconds(t0 + (0:3) * 90), "divides 60")

  diary = check_diary(data.frame(in_bed_time = t0, out_bed_time = t0 + 120))
  expect_equal(diary$onset_time, diary$in_bed_time)
  expect_equal(diary$index, 1L)
  diary$onset_time = t0 + 60
  ss = expand_start_stop(diary, epoch_seconds = 30)
  expect_equal(ss$time, t0 + c(0, 30, 60, 90))
  expect_equal(ss$is_past_onset, c(FALSE, FALSE, TRUE, TRUE))
  expect_true(all(ss$in_bed))
})
