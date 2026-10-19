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
    axis1 = c(1, 1),
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

  tl = acti_apply_tudor_locke(dplyr::mutate(data, sleep = c("S", "W")))
  expect_true(all(c("in_bed_time", "out_bed_time", "sleep_fragmentation_index") %in% names(tl)))

  sadeh = acti_apply_sadeh(data)
  expect_named(sadeh, c("timestamp", "sleep"))
})

test_that("Tudor-Locke diary labels adapt to the downstream state format", {
  time <- as.POSIXct(c("2020-01-01 22:00:00", "2020-01-01 22:01:00",
                       "2020-01-01 22:02:00"), tz = "UTC")
  data <- data.frame(time = time, counts = c(1, 2, 3))
  diary <- data.frame(onset = time[2], wakeup = time[3])
  labeled <- acti_apply_tudor_locke_diary(data, diary)
  expect_identical(labeled$sleep, c(FALSE, TRUE, FALSE))

  testthat::local_mocked_bindings(
    apply_tudor_locke = function(x, ...) {
      expect_identical(x$sleep, c("W", "S", "W"))
      tibble::tibble(in_bed_time = x$timestamp[1])
    },
    .package = "actigraph.sleepr"
  )
  expect_named(acti_apply_tudor_locke(labeled), c("in_bed_time"))
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
                                     verbose = TRUE, round_digits = NULL) {
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

test_that("acti_process reads GT3X at 8 digits and rounds after resampling", {
  path = tempfile(fileext = ".gt3x")
  file.create(path)
  on.exit(unlink(path), add = TRUE)

  input = tibble::tibble(
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + c(0, 60),
    X = c(1, 2), Y = c(0, 0), Z = c(0, 0)
  )
  attr(input, "sample_rate") = 30L
  input = set_transformations(input, "acti_read_gt3x:data_read")
  plain = input
  attr(plain, "transformations") = NULL
  read_args = NULL
  digits_used = list()
  testthat::local_mocked_bindings(
    acti_read_gt3x = function(...) {
      read_args <<- list(...)
      input
    },
    acti_resample = function(data, sample_rate) data,
    acti_calculate_counts = function(data, lfe_select = FALSE, resample = FALSE,
                                     verbose = TRUE, round_digits = NULL) {
      digits_used[length(digits_used) + 1] <<- list(round_digits)
      tibble::tibble(time = data$time, counts = c(5, 7))
    },
    acti_calculate_nonwear = function(counts, method = c("choi", "troiano"),
                                      use_magnitude = TRUE) {
      tibble::tibble(time = counts$time, wear = c(FALSE, TRUE))
    },
    .package = "actimetrics"
  )
  acti_process(path, verbose = FALSE, min_required = NULL)
  if (gt3x_supports_digits()) {
    expect_equal(read_args$digits, 8L)
  }
  acti_process(path, verbose = FALSE, min_required = NULL, digits = 3L)
  expect_equal(read_args$digits, 3L)
  acti_process(plain, verbose = FALSE, min_required = NULL)
  acti_process(path, verbose = FALSE, min_required = NULL, round_digits = NA)
  expect_equal(digits_used, list(3L, 3L, NULL, NA))
})
