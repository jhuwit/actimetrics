test_that("acti_threshold_counts classifies counts at the requested epoch", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 60 * 0:3,
    counts = c(0, 99, 100, 200)
  )

  out <- acti_threshold_counts(
    data,
    thresholds = 100,
    labels = c("low", "high"),
    name = "intensity"
  )

  expect_s3_class(out$intensity, "ordered")
  expect_identical(as.character(out$intensity), c("low", "low", "high", "high"))
})

test_that("threshold helpers use their published boundaries", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 60 * 0:8,
    counts = c(0, 2689, 2690, 2860, 3940, 3941, 6167, 9642, 9643)
  )

  montoye <- acti_threshold_montoye(data)
  expect_identical(
    as.character(montoye$montoye_intensity),
    c("sedentary", "sedentary", "sedentary", "light", "light", "mvpa", "mvpa", "mvpa", "mvpa")
  )

  sasaki <- acti_threshold_sasaki(data)
  expect_identical(
    as.character(sasaki$sasaki_intensity),
    c("light_or_less", "light_or_less", "moderate", "moderate", "moderate", "moderate", "hard", "hard", "very_hard")
  )
})

test_that("threshold helpers reject missing, irregular, and wrong-epoch time data", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + c(0, 30, 60),
    counts = c(0, 1, 2)
  )

  expect_error(acti_threshold_montoye(data), "epoch of 60 seconds")
  expect_error(
    acti_threshold_counts(data[, "counts", drop = FALSE], 1, c("a", "b")),
    "time.*counts"
  )
  data$time <- as.character(data$time)
  expect_error(acti_threshold_counts(data, 1, c("a", "b")), "POSIXct")
})

test_that("Romanzini cut-points require 15-second vector-magnitude counts", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 15 * 0:6,
    counts = c(180, 181, 756, 757, 1111, 1112, 2000)
  )
  out <- acti_threshold_romanzini(data)
  expect_identical(
    as.character(out$romanzini_intensity),
    c("sedentary", "light", "light", "moderate", "moderate", "vigorous", "vigorous")
  )
})

test_that("acti_threshold_enmo classifies each supplied ENMO threshold", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 0:4,
    enmo = c(0, 49.9, 50, 199.9, 200)
  )
  out <- acti_threshold_enmo(
    data,
    thresholds = c(50, 200),
    labels = c("low", "middle", "high"),
    epoch = 1
  )
  expect_identical(
    as.character(out$activity_intensity),
    c("low", "low", "middle", "middle", "high")
  )
})

test_that("Hildebrand helpers use every published threshold and source epoch", {
  hip_data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 0:4,
    enmo = c(69, 69.1, 258.6, 258.7, 500)
  )
  out <- acti_threshold_hildebrand(hip_data, placement = "hip")
  expect_identical(
    as.character(out$hildebrand_intensity),
    c("light_or_less", "moderate", "moderate", "vigorous", "vigorous")
  )
  expect_error(
    acti_threshold_hildebrand(transform(hip_data, time = time + 4 * 0:4)),
    "epoch of 1 seconds"
  )
  wrist_data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 0:4,
    enmo = c(100.5, 100.6, 428.7, 428.8, 500)
  )
  wrist <- acti_threshold_hildebrand(wrist_data, placement = "wrist")
  expect_identical(
    as.character(wrist$hildebrand_intensity),
    c("light_or_less", "moderate", "moderate", "vigorous", "vigorous")
  )
})
