test_that("stepcount wrapper uses the provided or inferred sample rate", {
  data = tibble::tibble(
    time = as.POSIXct(
      c("2020-01-01 00:00:00", "2020-01-01 00:00:01", "2020-01-01 00:00:02"),
      tz = "UTC"
    ),
    X = c(0, 0, 0),
    Y = c(0, 0, 0),
    Z = c(1, 1, 1)
  )
  attr(data, "sample_rate") = 1L

  testthat::local_mocked_bindings(
    stepcount = function(data, sample_rate, ...) {
      list(
        walking = tibble::tibble(
          time = as.POSIXct(
            c("2020-01-01 00:00:01", "2020-01-01 00:00:31"),
            tz = "UTC"
          ),
          walking = c(0, 1)
        ),
        steps = tibble::tibble(
          time = as.POSIXct(
            c("2020-01-01 00:00:01", "2020-01-01 00:00:31"),
            tz = "UTC"
          ),
          steps = c(2, 3)
        )
      )
    },
    .package = "stepcount"
  )

  out = acti_calculate_stepcount(data)
  expect_equal(out$steps, 5)
  expect_true(out$walking)

  out_explicit = acti_calculate_stepcount(data, sample_rate = 2)
  expect_equal(out_explicit$steps, 5)
})

test_that("stepcount and sdt infer sample rate when missing", {
  data = tibble::tibble(
    time = as.POSIXct(
      c("2020-01-01 00:00:00", "2020-01-01 00:00:01", "2020-01-01 00:00:02"),
      tz = "UTC"
    ),
    X = c(0, 0, 0),
    Y = c(0, 0, 0),
    Z = c(1, 1, 1)
  )

  testthat::local_mocked_bindings(
    get_sample_rate = function(data, sample_rate = NULL) 1L,
    .package = "actibase"
  )
  testthat::local_mocked_bindings(
    stepcount = function(data, sample_rate, ...) {
      list(
        walking = tibble::tibble(
          time = as.POSIXct(
            c("2020-01-01 00:00:01", "2020-01-01 00:00:31"),
            tz = "UTC"
          ),
          walking = c(0, 1)
        ),
        steps = tibble::tibble(
          time = as.POSIXct(
            c("2020-01-01 00:00:01", "2020-01-01 00:00:31"),
            tz = "UTC"
          ),
          steps = c(2, 3)
        )
      )
    },
    .package = "stepcount"
  )
  testthat::local_mocked_bindings(
    estimate_steps_sdt = function(data, sample_rate, ...) {
      tibble::tibble(
        time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        steps = 5
      )
    },
    .package = "walking"
  )

  testthat::expect_warning({
    out = acti_calculate_stepcount(data)
  })
  expect_equal(out$steps, 5)

  testthat::expect_warning({
    sdt = acti_calculate_sdt(data)
  })
  expect_equal(sdt$steps, 5)
})

test_that("summarize_to_minute aggregates step data", {
  sdata = tibble::tibble(
    time = as.POSIXct(
      c(
        "2020-01-01 00:00:01",
        "2020-01-01 00:00:31",
        "2020-01-01 00:01:01"
      ),
      tz = "UTC"
    ),
    steps = c(1, 2, 3)
  )

  out = actimetrics:::summarize_to_minute(sdata, prefix = "test")
  expect_equal(nrow(out), 2L)
  expect_equal(out$steps, c(3, 3))
})

test_that("walking wrappers summarize mocked step outputs", {
  data = tibble::tibble(
    time = as.POSIXct(
      c("2020-01-01 00:00:00", "2020-01-01 00:00:01", "2020-01-01 00:00:02"),
      tz = "UTC"
    ),
    X = c(0, 0, 0),
    Y = c(0, 0, 0),
    Z = c(1, 1, 1)
  )
  attr(data, "sample_rate") = 100L

  testthat::local_mocked_bindings(
    estimate_steps_verisense = function(data, resample_to_15hz = TRUE, ..., method) {
      tibble::tibble(
        time = as.POSIXct(
          c("2020-01-01 00:00:01", "2020-01-01 00:00:31"),
          tz = "UTC"
        ),
        steps = c(2, 3)
      )
    },
    estimate_steps_forest = function(data, ...) {
      tibble::tibble(
        time = as.POSIXct(
          c("2020-01-01 00:00:01", "2020-01-01 00:00:31"),
          tz = "UTC"
        ),
        steps = c(2, 3)
      )
    },
    estimate_steps_sdt = function(data, sample_rate, ...) {
      tibble::tibble(
        time = as.POSIXct("2020-01-01 00:00:01", tz = "UTC"),
        steps = 5
      )
    },
    .package = "walking"
  )

  verisense = acti_calculate_verisense(data, method = "revised")
  expect_equal(verisense$steps, 5)

  forest = acti_calculate_forest(data)
  expect_equal(forest$steps, 5)

  sdt = acti_calculate_sdt(data, sample_rate = 100)
  expect_equal(sdt$steps, 5)
})

