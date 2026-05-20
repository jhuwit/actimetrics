test_that("acti_calculate_wear marks nonwear and handles empty nonwear", {
  data = data.frame(
    timestamp = as.POSIXct(
      c(
        "2020-01-01 00:00:00",
        "2020-01-01 00:01:00",
        "2020-01-01 00:02:00",
        "2020-01-01 00:03:00"
      ),
      tz = "UTC"
    ),
    vector.magnitude = c(1, 1, 1, 1)
  )

  testthat::local_mocked_bindings(
    apply_choi = function(x, use_magnitude = TRUE, ...) {
      tibble::tibble(
        period_start = as.POSIXct("2020-01-01 00:01:00", tz = "UTC"),
        period_end = as.POSIXct("2020-01-01 00:03:00", tz = "UTC")
      )
    },
    .package = "actigraph.sleepr"
  )
  wear = acti_calculate_wear(data)
  expect_equal(wear$wear, c(TRUE, FALSE, FALSE, TRUE))

  testthat::local_mocked_bindings(
    apply_choi = function(x, use_magnitude = TRUE, ...) {
      tibble::tibble(
        period_start = as.POSIXct(character()),
        period_end = as.POSIXct(character())
      )
    },
    .package = "actigraph.sleepr"
  )
  wear_all = acti_calculate_wear(data)
  expect_true(all(wear_all$wear))
})

test_that("sleep wrappers rename outputs and record transformations", {
  data = data.frame(
    timestamp = as.POSIXct(
      c("2020-01-01 00:00:00", "2020-01-01 00:01:00"),
      tz = "UTC"
    ),
    vector.magnitude = c(1, 1)
  )

  testthat::local_mocked_bindings(
    apply_cole_kripke = function(x) {
      tibble::tibble(
        timestamp = x$timestamp,
        sleep = c(TRUE, FALSE)
      )
    },
    apply_tudor_locke = function(x, ...) {
      tibble::tibble(
        in_bed_time = x$timestamp[1],
        out_bed_time = x$timestamp[2],
        sleep_fragmentation_index = 0
      )
    },
    apply_sadeh = function(x, ...) {
      tibble::tibble(
        timestamp = x$timestamp,
        sleep = c(FALSE, TRUE)
      )
    },
    .package = "actigraph.sleepr"
  )

  ck = acti_apply_cole_kripke(data)
  expect_named(ck, c("time", "sleep"))

  tl = acti_apply_tudor_locke(data)
  expect_true(all(c("in_bed_time", "out_bed_time", "sleep_fragmentation_index") %in% names(tl)))

  sadeh = acti_apply_sadeh(data)
  expect_named(sadeh, c("timestamp", "sleep"))
})

test_that("acti_process merges counts and wear from a file path", {
  path = tempfile(fileext = ".gt3x")
  file.create(path)
  on.exit(unlink(path), add = TRUE)

  input = tibble::tibble(
    time = as.POSIXct(
      c("2020-01-01 00:00:00", "2020-01-01 00:01:00"),
      tz = "UTC"
    ),
    X = c(1, 2),
    Y = c(0, 0),
    Z = c(0, 0)
  )
  attr(input, "sample_rate") = 30L

  testthat::local_mocked_bindings(
    acti_read_gt3x = function(...) input,
    acti_resample = function(data, sample_rate) data,
    acti_calculate_counts = function(data, lfe_select = FALSE, resample = FALSE,
                                     verbose = TRUE) {
      tibble::tibble(
        time = data$time,
        counts = c(5, 7)
      )
    },
    acti_calculate_nonwear = function(counts, method = c("choi", "troiano"),
                                      use_magnitude = TRUE) {
      tibble::tibble(
        time = counts$time,
        wear = c(FALSE, TRUE)
      )
    },
    .package = "actimetrics"
  )

  out = acti_process(path, verbose = FALSE)
  expect_true(all(c("time", "counts", "wear") %in% names(out)))
  expect_equal(out$wear, c(FALSE, TRUE))
})
