test_that("acti_write_agd writes a reader-compatible AGD database", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("bit64")
  skip_if_not_installed("actigraph.sleepr")

  counts <- data.frame(
    HEADER_TIMESTAMP = c("2020-01-01T00:00:00.000Z", "2020-01-01T00:01:00.000Z"),
    X = c(1, 2),
    Y = c(3, 4),
    Z = c(5, 6)
  )
  file <- tempfile(fileext = ".agd")
  on.exit(unlink(file), add = TRUE)

  acti_write_agd(counts, file, original_sample_rate = 80)

  raw <- actigraph.sleepr::read_agd_raw(file)
  expect_true(all(c("data", "sleep", "awakenings", "filters", "settings") %in% names(raw)))
  expect_equal(raw$data$axis1, counts$X)
  expect_equal(raw$data$axis2, counts$Y)
  expect_equal(raw$data$axis3, counts$Z)

  round_trip <- actigraph.sleepr::read_agd(file)
  expect_equal(round_trip$timestamp, as.POSIXct(counts$HEADER_TIMESTAMP,
                                                format = "%Y-%m-%dT%H:%M:%OSZ",
                                                tz = "UTC"))
  expect_equal(attr(round_trip, "epochlength"), 60L)
  expect_equal(attr(round_trip, "original sample rate"), "80")
  expect_error(acti_write_agd(counts, file), "already exists")

  half_minute <- counts
  half_minute$HEADER_TIMESTAMP <- c("2020-01-01T00:00:00.000Z",
                                    "2020-01-01T00:00:30.000Z")
  short_file <- tempfile(fileext = ".agd")
  on.exit(unlink(short_file), add = TRUE)
  acti_write_agd(half_minute, short_file)
  expect_equal(attr(actigraph.sleepr::read_agd(short_file), "epochlength"), 30L)
})
