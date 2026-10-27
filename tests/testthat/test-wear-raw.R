make_still_signal = function(still_minutes, sf = 10,
                             start = "2020-01-01 00:00:00") {
  # `still_minutes` is a logical vector, one value per minute
  state = rep(still_minutes, each = 60 * sf)
  n = length(state)
  set.seed(42)
  sdv = ifelse(state, 0.002, 0.3)
  data = data.frame(
    time = as.POSIXct(start, tz = "UTC") + (seq_len(n) - 1) / sf,
    X = stats::rnorm(n, sd = sdv),
    Y = stats::rnorm(n, sd = sdv),
    Z = 1 + stats::rnorm(n, sd = sdv)
  )
  attr(data, "sample_rate") = sf
  data
}

test_that("acti_calculate_wear_raw flags a still hour with the 2023 approach", {
  data = make_still_signal(rep(c(FALSE, TRUE, FALSE), each = 60 * 4))
  out = acti_calculate_wear_raw(data)

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("time", "nonwear_score", "clipping_score", "nonwear",
                      "clipping", "nonwear_additional", "wear"))
  expect_equal(nrow(out), 48)
  expect_equal(diff(as.numeric(out$time[1:2])), 900)
  expect_equal(which(out$nonwear_score == 3), 17:32)
  expect_equal(which(!out$wear), 17:32)
  expect_false(any(out$clipping))
})

test_that("the 2013 approach uses a centred window", {
  data = make_still_signal(rep(c(FALSE, TRUE, FALSE), each = 60 * 4))
  out = acti_calculate_wear_raw(data, approach = "2013")
  # A centred 60-minute window must lie entirely inside the still period
  expect_equal(which(out$nonwear_score == 3), 19:30)
})

test_that("thresholds change the non-wear decision", {
  data = make_still_signal(rep(c(FALSE, TRUE, FALSE), each = 60 * 4))
  strict = acti_calculate_wear_raw(data, sd_threshold = 0.001)
  expect_true(all(strict$nonwear_score == 0))
  lenient = acti_calculate_wear_raw(data, wear_threshold = 4)
  expect_false(any(lenient$nonwear))
})

test_that("short wear bouts between long non-wear are relabelled", {
  still = c(rep(FALSE, 120), rep(TRUE, 300), rep(FALSE, 75),
            rep(TRUE, 300), rep(FALSE, 600))
  out = acti_calculate_wear_raw(make_still_signal(still))
  gap = out$time >= as.POSIXct("2020-01-01 07:00:00", tz = "UTC") &
    out$time < as.POSIXct("2020-01-01 08:15:00", tz = "UTC")
  expect_true(any(out$nonwear_additional[gap]))
  expect_false(any(out$wear[gap]))
})

test_that("edge correction extends non-wear near the start", {
  still = c(rep(FALSE, 60), rep(TRUE, 240), rep(FALSE, 600))
  data = make_still_signal(still)
  with_edge = acti_calculate_wear_raw(data)
  without = acti_calculate_wear_raw(data, edge_correction = FALSE)
  expect_true(all(with_edge$nonwear_additional[1:4]))
  expect_false(any(without$nonwear_additional[1:4]))
})

test_that("night filter removes short non-wear inside the window", {
  still = c(rep(FALSE, 23 * 60), rep(TRUE, 120), rep(FALSE, 10 * 60))
  data = make_still_signal(still)
  plain = acti_calculate_wear_raw(data)
  filtered = acti_calculate_wear_raw(data, filter_max_hours = 3,
                                     filter_window = c(22, 7))
  expect_true(any(plain$nonwear))
  expect_false(any(filtered$nonwear))
  expect_error(acti_calculate_wear_raw(data, filter_max_hours = 3),
               "filter_window")
})

test_that("clipping is detected from the dynamic range", {
  data = make_still_signal(rep(FALSE, 180))
  data$X[seq(1, 900 * 10 * 0.5)] = 7.9
  out = acti_calculate_wear_raw(data, dynamic_range = c(-8, 8))
  expect_equal(out$clipping_score[1], 0.5)
  expect_true(out$clipping[1])
  expect_false(out$wear[1])
  expect_false(any(acti_calculate_wear_raw(data, clip_threshold = 8)$clipping))
})

test_that("start is aligned to the medium epoch like GGIR", {
  data = make_still_signal(rep(FALSE, 180), start = "2020-01-01 00:07:23")
  out = acti_calculate_wear_raw(data)
  expect_equal(out$time[1], as.POSIXct("2020-01-01 00:15:00", tz = "UTC"))
  out = acti_calculate_wear_raw(data, align_start = FALSE)
  expect_equal(out$time[1], as.POSIXct("2020-01-01 00:07:23", tz = "UTC"))
})

test_that("acti_calculate_wear_raw validates input", {
  data = make_still_signal(rep(FALSE, 30))
  expect_error(acti_calculate_wear_raw(data), "shorter than")
  data = make_still_signal(rep(FALSE, 120))
  expect_error(acti_calculate_wear_raw(data, long_epoch = 1000),
               "multiple")
  gap = data[-(5000:6000), ]
  attr(gap, "sample_rate") = 10
  expect_warning(acti_calculate_wear_raw(gap), "time gaps")
})

test_that("actipy method flags stationary runs longer than patience", {
  data = make_still_signal(rep(c(FALSE, TRUE, FALSE), times = c(60, 100, 60)))
  out = acti_calculate_wear_raw(data, method = "actipy")

  expect_named(out, c("time", "stationary", "nonwear", "wear"))
  expect_equal(nrow(out), 220 * 6)
  expect_equal(diff(as.numeric(out$time[1:2])), 10)
  expect_equal(which(out$nonwear), 361:960)
  expect_identical(out$wear, !out$nonwear)

  # A 100-minute run is not longer than a 100-minute patience
  short = acti_calculate_wear_raw(data, method = "actipy", patience = 6000)
  expect_false(any(short$nonwear))
  # The Doherty et al. (2017) definition
  doherty = acti_calculate_wear_raw(data, method = "actipy",
                                    patience = 3600, sd_threshold = 0.013)
  expect_equal(which(doherty$nonwear), 361:960)
  strict = acti_calculate_wear_raw(data, method = "actipy",
                                   sd_threshold = 0.001)
  expect_false(any(strict$stationary))
})

test_that("actipy method does not treat time gaps as stationary", {
  still = rep(c(FALSE, TRUE, FALSE), times = c(60, 100, 60))
  data = make_still_signal(still)
  # Remove 10 minutes from the middle of the still period
  gap = data$time >= as.POSIXct("2020-01-01 01:50:00", tz = "UTC") &
    data$time < as.POSIXct("2020-01-01 02:00:00", tz = "UTC")
  out = acti_calculate_wear_raw(data[!gap, ], method = "actipy",
                                patience = 3000)
  empty = out$time >= as.POSIXct("2020-01-01 01:50:00", tz = "UTC") &
    out$time < as.POSIXct("2020-01-01 02:00:00", tz = "UTC")
  expect_false(any(out$stationary[empty]))
  # Each side of the gap is 50 minutes; the run before the gap spans 49:50
  expect_false(any(out$nonwear))
})

test_that("acti_calculate_wear_raw dispatches to the method functions", {
  data = make_still_signal(rep(c(FALSE, TRUE, FALSE), each = 60 * 4))
  expect_identical(
    acti_calculate_wear_raw(data, approach = "2013"),
    acti_calculate_wear_raw_ggir(data, approach = "2013")
  )
  expect_identical(
    acti_calculate_wear_raw(data, method = "actipy", patience = 3600),
    acti_calculate_wear_raw_actipy(data, patience = 3600)
  )
  expect_error(acti_calculate_wear_raw(data, method = "choi"))
  # Arguments are passed only to the selected method
  expect_error(acti_calculate_wear_raw(data, method = "actipy",
                                       approach = "2013"),
               "unused argument")
})
