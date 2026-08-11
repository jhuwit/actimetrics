test_that("HDCZA identifies a prolonged low-angle-change block", {
  angle <- c(seq(0, 100, length.out = 60), rep(100, 480),
             seq(100, 200, length.out = 60))
  out <- acti_sleep_hdcza(angle, epoch_seconds = 60)

  expect_s3_class(out, "acti_sleep_guider")
  expect_equal(out$method, "HDCZA")
  expect_true(sum(out$window) >= 450)
  expect_true(out$start_index > 1)
  expect_true(out$end_index < length(angle))
})

test_that("L5, fixed-window, and diary guiders identify expected windows", {
  activity <- c(rep(10, 120), rep(0, 300), rep(10, 1020))
  l5 <- acti_sleep_l5(activity, epoch_seconds = 60)
  expect_equal(l5$l5_start_index, 121)
  expect_equal(sum(l5$window), 720)

  time <- as.POSIXct("2020-01-01 18:00:00", tz = "UTC") + 0:1439 * 60
  fixed <- acti_sleep_setwindow(time, 22, 8)
  expect_equal(sum(fixed$window), 600)
  diary <- acti_sleep_diary(time, time[300], time[800])
  expect_equal(sum(diary$window), 501)
})

test_that("HLRB and NotWorn return a longest candidate window", {
  sib <- c(rep(FALSE, 120), rep(TRUE, 300), rep(FALSE, 120), rep(TRUE, 180))
  hlrb <- acti_sleep_hlrb(sib, epoch_seconds = 60)
  expect_true(sum(hlrb$window) > 0)

  activity <- c(rep(4, 120), rep(0, 300), rep(4, 120), rep(0, 180))
  notworn <- acti_sleep_notworn(activity, epoch_seconds = 60)
  expect_equal(notworn$method, "NotWorn")
  expect_true(sum(notworn$window) > 0)
})
