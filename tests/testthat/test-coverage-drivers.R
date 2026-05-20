test_that("internal helpers reshape timestamps and reconstruction", {
  data = tibble::tibble(time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"), x = 1)
  expect_true("timestamp" %in% names(actimetrics:::rename_timestamp(data)))
  expect_true("HEADER_TIME_STAMP" %in% names(actimetrics:::rename_time_stamp(data)))

  acc_data = tibble::tibble(time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"), X = 1)
  attr(acc_data, "sample_rate") = 100
  acc = actimetrics:::remake_acc(
    acc_data,
    hdr = tibble::tibble(Field = "Acceleration Min", Value = "-2")
  )
  expect_s3_class(acc, "AccData")
  expect_equal(acc$freq, 100)

  expect_true(inherits(actimetrics:::floor_sec(as.Date("2020-01-01")), "POSIXct"))

  dt = actimetrics:::remake_dt(data, is_data_table = TRUE)
  expect_true(data.table::is.data.table(dt))

  joined = actimetrics:::join_all_time(
    tibble::tibble(
      HEADER_TIME_STAMP = as.POSIXct(
        c("2020-01-01 00:00:00", "2020-01-01 00:02:00"),
        tz = "UTC"
      ),
      value = c(1, 3)
    ),
    unit = "1 min",
    ensure_all_time = TRUE
  )
  expect_equal(nrow(joined), 3L)
  expect_true(is.na(joined$value[2]))

  expect_equal(actimetrics:::n_in_interval("1 min", sample_rate = 100), 6000)
  expect_equal(actimetrics:::n_in_interval("2 hours", sample_rate = 1), 7200)
  expect_equal(actimetrics:::n_in_interval("minutes", sample_rate = 2), 120)
  expect_true(actimetrics:::check_dynamic_range(make_accdata(), c(-2, 2)))
})

test_that("activity measure helpers cover tibble and data.table branches", {
  base_data = tibble::tibble(
    time = as.POSIXct(
      c(
        "2020-01-01 00:00:00",
        "2020-01-01 00:00:30",
        "2020-01-01 00:02:00",
        "2020-01-01 00:02:30"
      ),
      tz = "UTC"
    ),
    X = c(0, 1, 2, 3),
    Y = c(0, 1, 2, 3),
    Z = c(1, 1, 1, 1)
  )
  attr(base_data, "sample_rate") = 1L

  ai_df = acti_calculate_ai(base_data, ensure_all_time = TRUE, verbose = TRUE)
  ai_dt = acti_calculate_ai(data.table::as.data.table(base_data), ensure_all_time = TRUE, verbose = TRUE)
  expect_equal(nrow(ai_df), 3L)
  expect_true(is.na(ai_df$AI[2]))
  expect_true(data.table::is.data.table(ai_dt))

  mad_df = acti_calculate_mad(base_data, ensure_all_time = TRUE, verbose = TRUE)
  mad_dt = acti_calculate_mad(data.table::as.data.table(base_data), ensure_all_time = TRUE, verbose = TRUE)
  expect_true(all(c("SD", "MAD", "ENMO_t") %in% names(mad_df)))
  expect_true(data.table::is.data.table(mad_dt))

  flags_data = make_flagged_signal()
  flags = acti_calculate_flags(flags_data, ensure_all_time = TRUE)
  idle = acti_calculate_n_idle(flags_data, ensure_all_time = TRUE)
  expect_true(all(c("flag_low", "n_samples_in_unit") %in% names(flags)))
  expect_true(any(idle$n_idle > 0))

  enmo = acti_calculate_enmo(base_data, ensure_all_time = TRUE)
  ai_defined = acti_calculate_ai_defined(base_data, ensure_all_time = TRUE)
  expect_true(all(c("HEADER_TIME_STAMP", "ENMO_t") %in% names(enmo)))
  expect_true(all(c("HEADER_TIME_STAMP", "AI_DEFINED") %in% names(ai_defined)))

  auc_data = tibble::tibble(
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + 0:59,
    X = rep(1, 60),
    Y = rep(2, 60),
    Z = rep(3, 60)
  )
  attr(auc_data, "sample_rate") = 1L
  auc_plain = acti_calculate_auc(auc_data, allow_truncation = FALSE, ensure_all_time = TRUE, verbose = TRUE)
  auc_trunc = acti_calculate_auc(auc_data, allow_truncation = TRUE, ensure_all_time = TRUE, verbose = TRUE)
  expect_true(all(c("AUC_X", "AUC_Y", "AUC_Z", "AUC") %in% names(auc_plain)))
  expect_equal(auc_plain$AUC, auc_trunc$AUC)

  testthat::local_mocked_bindings(
    acti_calculate_counts = function(data, epoch = 60L, resample = TRUE, lfe_select = FALSE, verbose = TRUE) {
      tibble::tibble(
        time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        counts = 4
      )
    },
    .package = "actimetrics"
  )
  ac = calculate_activity_counts(base_data, unit = "1 min", sample_rate = 1, verbose = FALSE)
  expect_true(all(c("HEADER_TIME_STAMP", "AC") %in% names(ac)))
})

test_that("measure wrappers fail fast when dependencies are absent", {
  testthat::local_mocked_bindings(
    requireNamespace = function(package, quietly = TRUE) {
      if (package == "agcounts") {
        FALSE
      } else {
        TRUE
      }
    },
    .package = "base"
  )
  expect_error(
    acti_calculate_measures(
      tibble::tibble(
        time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        X = 1,
        Y = 1,
        Z = 1
      ),
      calculate_mims = FALSE,
      calculate_ac = TRUE,
      flag_data = FALSE,
      fix_zeros = FALSE,
      verbose = FALSE
    ),
    "agcounts package required for calculating AC"
  )
})

test_that("measure wrappers fail when MIMS is unavailable", {
  testthat::local_mocked_bindings(
    requireNamespace = function(package, quietly = TRUE) {
      if (package == "MIMSunit") {
        FALSE
      } else {
        TRUE
      }
    },
    .package = "base"
  )
  expect_error(
    acti_calculate_measures(
      tibble::tibble(
        time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        X = 1,
        Y = 1,
        Z = 1
      ),
      calculate_mims = TRUE,
      calculate_ac = FALSE,
      flag_data = FALSE,
      fix_zeros = FALSE,
      verbose = FALSE
    ),
    "MIMSunit package required for calculating MIMS"
  )
})

test_that("measure wrappers and calibration can be driven by mocks", {
  base_data = tibble::tibble(
    time = as.POSIXct(
      c(
        "2020-01-01 00:00:00",
        "2020-01-01 00:00:30",
        "2020-01-01 00:02:00",
        "2020-01-01 00:02:30"
      ),
      tz = "UTC"
    ),
    X = c(0.1, 0.2, 0.3, 0.4),
    Y = c(0.2, 0.3, 0.4, 0.5),
    Z = c(0.3, 0.4, 0.5, 0.6)
  )
  attr(base_data, "sample_rate") = 1L

  testthat::local_mocked_bindings(
    mims_default_processing = function(data, ...) {
      tibble::tibble(
        HEADER_TIME_STAMP = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        X = 1,
        Y = 2,
        Z = 3
      )
    },
    acti_calculate_auc = function(data, ...) {
      tibble::tibble(
        HEADER_TIME_STAMP = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        AUC_X = 1,
        AUC_Y = 2,
        AUC_Z = 3,
        AUC = 6
      )
    },
    .package = "actimetrics"
  )
  fast_short = acti_calculate_fast_mims(base_data, output_mims_per_axis = FALSE, verbose = FALSE)
  fast_full = acti_calculate_fast_mims(base_data, output_mims_per_axis = TRUE, verbose = FALSE)
  expect_named(fast_short, c("HEADER_TIME_STAMP", "MIMS_UNIT"))
  expect_true(all(c("MIMS_UNIT_X", "MIMS_UNIT_Y", "MIMS_UNIT_Z", "MIMS_UNIT") %in% names(fast_full)))

  testthat::local_mocked_bindings(
    mims_unit = function(data, epoch, dynamic_range, ...) {
      tibble::tibble(
        HEADER_TIME_STAMP = data$HEADER_TIME_STAMP,
        MIMS = 9
      )
    },
    .package = "MIMSunit"
  )
  expect_warning(
    acti_calculate_mims(base_data, dynamic_range = c(-0.1, 0.1), ensure_all_time = TRUE),
    "Dynamic range does not cover all the data"
  )

  testthat::local_mocked_bindings(
    acti_fill_zeros = function(data) data,
    flag_qc_all = function(data, dynamic_range, verbose, flags) {
      dplyr::mutate(data, flag_low = 1L)
    },
    acti_calculate_counts = function(data, epoch = 60L, resample = TRUE, lfe_select = FALSE, verbose = TRUE) {
      tibble::tibble(
        time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        counts = 5
      )
    },
    acti_calculate_mims = function(data, unit = "1 min", dynamic_range = NULL, ...) {
      tibble::tibble(
        HEADER_TIME_STAMP = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        MIMS = 7
      )
    },
    .package = "actimetrics"
  )
  measures = acti_calculate_measures(
    base_data,
    calculate_mims = TRUE,
    calculate_ac = TRUE,
    flag_data = TRUE,
    fix_zeros = TRUE,
    verbose = TRUE,
    ensure_all_time = TRUE
  )
  expect_true(all(c("time", "AC", "MIMS", "flags") %in% names(measures)))

  measures_min = acti_calculate_measures(
    base_data,
    calculate_mims = FALSE,
    calculate_ac = FALSE,
    flag_data = FALSE,
    fix_zeros = FALSE,
    verbose = FALSE,
    ensure_all_time = FALSE
  )
  expect_true("time" %in% names(measures_min))

  path = tempfile(fileext = ".gt3x")
  file.create(path)
  on.exit(unlink(path), add = TRUE)
  testthat::local_mocked_bindings(
    acti_read_gt3x = function(path, verbose = FALSE) base_data,
    .package = "actimetrics"
  )
  testthat::local_mocked_bindings(
    agcalibrate = function(data, verbose = FALSE, ...) {
      data$X = 1.23456
      data$Y = 2.34567
      data$Z = 3.45678
      data
    },
    .package = "agcounts"
  )
  testthat::local_mocked_bindings(
    acti_fill_zeros = function(data) data,
    .package = "actibase"
  )
  expect_message(
    calibrated <- acti_calibrate(path, verbose = TRUE, fill_zeroes = TRUE, round_after_calibration = TRUE),
    "Running agcounts::agcalibrate"
  )
  expect_equal(calibrated$X[1], 1.235)

  calibrated2 = acti_calibrate(base_data, verbose = FALSE, fill_zeroes = FALSE, round_after_calibration = FALSE)
  expect_equal(calibrated2$X[1], 1.23456)
})

test_that("sleepr standardization and MIMS helpers cover reconstruction branches", {
  sleep_counts = data.frame(
    timestamp = as.POSIXct(c("2020-01-01 00:00:00", "2020-01-01 00:01:00"), tz = "UTC"),
    counts = c(1, 2)
  )
  out_counts = actimetrics:::acti_standardize_actigraph.sleepr(sleep_counts)
  expect_true(all(c("timestamp", "vector.magnitude", "axis1", "axis2", "axis3") %in% names(out_counts)))

  sleep_count = data.frame(
    timestamp = as.POSIXct(c("2020-01-01 00:00:00", "2020-01-01 00:01:00"), tz = "UTC"),
    count = c(3, 4)
  )
  out_count = actimetrics:::acti_standardize_actigraph.sleepr(sleep_count)
  expect_equal(out_count$vector.magnitude, c(3, 4))

  testthat::local_mocked_bindings(
    extrapolate = function(data, dynamic_range, noise_level, k, spar) {
      dplyr::mutate(
        data,
        EXTRAPOLATED_HEADER_TIME_STAMP = HEADER_TIME_STAMP,
        EXTRAPOLATED_X = X,
        EXTRAPOLATED_Y = Y,
        EXTRAPOLATED_Z = Z
      )
    },
    interpolate_signal = function(data, sr, method) {
      dplyr::mutate(
        data,
        INTERPOLATED_HEADER_TIME_STAMP = HEADER_TIME_STAMP,
        INTERPOLATED_X = X,
        INTERPOLATED_Y = Y,
        INTERPOLATED_Z = Z
      )
    },
    iir = function(data, sr, cutoff_freq, order, type, filter_type) {
      tibble::tibble(
        IIR_HEADER_TIME_STAMP = data$HEADER_TIME_STAMP,
        IIR_X = data$X,
        IIR_Y = data$Y,
        IIR_Z = data$Z
      )
    },
    .package = "MIMSunit"
  )

  fil_data = tibble::tibble(
    HEADER_TIME_STAMP = as.POSIXct(c("2020-01-01 00:00:00", "2020-01-01 00:00:01"), tz = "UTC"),
    X = c(1, 2),
    Y = c(1, 2),
    Z = c(1, 2)
  )
  attr(fil_data, "sample_rate") = 100L
  ext = mims_default_extrapolation(fil_data, dynamic_range = c(-2, 2))
  int = mims_default_interpolation(fil_data)
  fil = mims_default_filtering(fil_data)
  proc = mims_default_processing(fil_data, use_extrapolation = TRUE, use_filtering = TRUE, round_after_processing = TRUE)

  expect_true("sample_rate" %in% names(attributes(ext)))
  expect_true("sample_rate" %in% names(attributes(int)))
  expect_true("sample_rate" %in% names(attributes(fil)))
  expect_true(all(c("X", "Y", "Z") %in% names(proc)))

  acc = make_accdata()
  testthat::local_mocked_bindings(
    acti_standardize_data = function(data, subset_xyz = FALSE, colname_time = "HEADER_TIME_STAMP", check_xyz = TRUE) {
      out = tibble::tibble(
        HEADER_TIME_STAMP = as.POSIXct(c("2020-01-01 00:00:00", "2020-01-01 00:00:01"), tz = "UTC"),
        X = c(1, 2),
        Y = c(1, 2),
        Z = c(1, 2)
      )
      attr(out, "sample_rate") = 100L
      out
    },
    .package = "actimetrics"
  )
  ext_acc = mims_default_extrapolation(acc, dynamic_range = c(-2, 2))
  int_acc = mims_default_interpolation(acc)
  fil_acc = mims_default_filtering(acc)
  proc_acc = mims_default_processing(acc, use_extrapolation = TRUE, use_filtering = TRUE, round_after_processing = FALSE)
  expect_s3_class(ext_acc, "AccData")
  expect_s3_class(int_acc, "AccData")
  expect_s3_class(fil_acc, "AccData")
  expect_true("data" %in% names(proc_acc))
})

test_that("mims helpers error when the dependency is unavailable", {
  testthat::local_mocked_bindings(
    requireNamespace = function(package, quietly = TRUE) FALSE,
    .package = "base"
  )
  expect_error(
    mims_default_extrapolation(tibble::tibble(HEADER_TIME_STAMP = as.POSIXct("2020-01-01", tz = "UTC"), X = 1, Y = 1, Z = 1)),
    "MIMSunit package required for mims_default_extrapolation"
  )
  expect_error(
    mims_default_interpolation(tibble::tibble(HEADER_TIME_STAMP = as.POSIXct("2020-01-01", tz = "UTC"), X = 1, Y = 1, Z = 1)),
    "MIMSunit package required for mims_default_interpolation"
  )
  expect_error(
    mims_default_filtering(tibble::tibble(HEADER_TIME_STAMP = as.POSIXct("2020-01-01", tz = "UTC"), X = 1, Y = 1, Z = 1)),
    "MIMSunit package required for mims_default_filtering"
  )
})

test_that("calculate_activity_counts requires a sample rate", {
  testthat::local_mocked_bindings(
    get_sample_rate = function(data, sample_rate = NULL) NULL,
    .package = "actimetrics"
  )
  expect_error(
    calculate_activity_counts(
      tibble::tibble(
        time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        X = 1,
        Y = 1,
        Z = 1
      ),
      unit = "1 min",
      sample_rate = NULL,
      verbose = FALSE
    ),
    "sample_rate is required for calculating AC"
  )
})

test_that("acti_calculate_mims requires MIMSunit", {
  testthat::local_mocked_bindings(
    requireNamespace = function(package, quietly = TRUE) FALSE,
    .package = "base"
  )
  expect_error(
    acti_calculate_mims(
      tibble::tibble(
        time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        X = 1,
        Y = 1,
        Z = 1
      ),
      ensure_all_time = FALSE
    ),
    "MIMSunit package required for calculating MIMS"
  )
})
