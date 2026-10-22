grid_data = function(n = 30 * 120, start = "2020-01-01 10:00:00", tz = "UTC",
                     sample_rate = 30) {
  set.seed(1)
  t0 = as.numeric(as.POSIXct(start, tz = tz))
  data = data.frame(
    time = as.POSIXct(seq(0, (n - 1) / sample_rate, 1 / sample_rate) + t0,
                      tz = tz, origin = lubridate::origin),
    X = round(rnorm(n), 8), Y = round(rnorm(n), 8), Z = round(rnorm(n), 8)
  )
  attr(data, "sample_rate") = sample_rate
  data
}

test_that("on_resample_grid detects data already on the resampling grid", {
  data = grid_data()
  expect_true(on_resample_grid(data, 30L))
  expect_false(on_resample_grid(data, 25L))
  # irregular, unsorted, duplicated, or missing times
  shifted = data
  shifted$time[10] = shifted$time[10] + 0.001
  expect_false(on_resample_grid(shifted, 30L))
  expect_false(on_resample_grid(data[c(2, 1, 3:nrow(data)), ], 30L))
  expect_false(on_resample_grid(data[c(1, 1:nrow(data)), ], 30L))
  missing = data
  missing$time[5] = NA
  expect_false(on_resample_grid(missing, 30L))
  expect_false(on_resample_grid(data[1, ], 30L))
  # other sampling rates
  expect_false(on_resample_grid(grid_data(sample_rate = 100), 30L))
})

test_that("as_resampled matches acti_resample for data on the grid", {
  for (tz in c("UTC", "Europe/London", "America/New_York")) {
    data = grid_data(tz = tz)
    expected = acti_resample(data, sample_rate = 30L)
    expect_identical(as_resampled(data, sample_rate = 30L), expected)
    tbl = dplyr::as_tibble(data)
    attr(tbl, "sample_rate") = 30
    expect_identical(as_resampled(tbl, sample_rate = 30L),
                     acti_resample(tbl, sample_rate = 30L))
  }
  # extra columns are dropped, as acti_resample does
  data = grid_data()
  data$temperature = 20
  expect_identical(as_resampled(data, 30L), acti_resample(data, 30L))
})

test_that("acti_process gives the same counts with and without resampling", {
  data = grid_data(n = 30 * 60 * 10)
  skipped = acti_process(data, verbose = FALSE, min_required = NULL)
  testthat::local_mocked_bindings(on_resample_grid = function(...) FALSE)
  resampled = acti_process(data, verbose = FALSE, min_required = NULL)
  expect_identical(skipped, resampled)
})

test_that("acti_process gives the same result for a GT3X file", {
  skip_if_not_installed("actiread")
  skip_on_cran()
  path = actiread::acti_example_gt3x()
  skipped = acti_process(path, verbose = FALSE)
  testthat::local_mocked_bindings(on_resample_grid = function(...) FALSE)
  resampled = acti_process(path, verbose = FALSE)
  expect_identical(skipped, resampled)
})
