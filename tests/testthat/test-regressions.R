make_minute_counts = function(n = 4L, epoch = 60, ...) {
  tibble::tibble(
    timestamp = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      (seq_len(n) - 1) * epoch,
    ...
  )
}

test_that("MIMS helpers record their transformations", {
  testthat::local_mocked_bindings(
    extrapolate = function(data, dynamic_range, noise_level, k, spar) data,
    interpolate_signal = function(data, sr, method) data,
    iir = function(data, sr, cutoff_freq, order, type, filter_type) data,
    .package = "MIMSunit"
  )
  data = tibble::tibble(
    HEADER_TIME_STAMP = as.POSIXct("2020-01-01", tz = "UTC") + c(0, 0.01),
    X = c(1, 2), Y = c(1, 2), Z = c(1, 2)
  )
  attr(data, "sample_rate") = 100L
  data = set_transformations(data, "original")

  ext = mims_default_extrapolation(data, dynamic_range = c(-8, 8))
  expect_equal(get_transformations(ext), c("extrapolated", "original"))
  int = mims_default_interpolation(data)
  expect_equal(get_transformations(int), c("interpolated", "original"))
  fil = mims_default_filtering(data)
  expect_equal(get_transformations(fil), c("filtered", "original"))

  proc = mims_default_processing(data, dynamic_range = c(-8, 8),
                                 verbose = FALSE)
  expect_equal(get_transformations(proc),
               c("filtered", "extrapolated", "original"))
})

test_that("step summaries keep all-NA epochs as NA, not 0", {
  sdata = tibble::tibble(
    time = as.POSIXct("2020-01-01", tz = "UTC") + seq(0, 110, 10),
    steps = c(rep(NA, 6), 1, NA, 2, 3, NA, 4)
  )
  out = summarize_to_minute(sdata, prefix = "test")
  expect_identical(out$steps, c(NA_real_, 10))
  expect_true("test:steps_summarized_per_60s_epoch" %in%
                get_transformations(out))

  out30 = summarize_to_minute(sdata, prefix = "test", unit = "30 seconds")
  expect_identical(out30$steps, c(NA_real_, NA_real_, 3, 7))
  expect_true("test:steps_summarized_per_30s_epoch" %in%
                get_transformations(out30))
})

test_that("acti_calculate_stepcount keeps missing steps and walking as NA", {
  data = tibble::tibble(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 0:2,
    X = 0, Y = 0, Z = 1
  )
  attr(data, "sample_rate") = 1L
  times = as.POSIXct("2020-01-01", tz = "UTC") + c(0, 30, 60, 90)
  testthat::local_mocked_bindings(
    stepcount = function(data, sample_rate, ...) {
      list(
        walking = tibble::tibble(time = times, walking = c(NA, NA, 0, 1)),
        steps = tibble::tibble(time = times, steps = c(NA, NA, 0, 4))
      )
    },
    .package = "stepcount"
  )
  out = acti_calculate_stepcount(data)
  expect_identical(out$steps, c(NA_real_, 4))
  expect_identical(out$walking, c(NA, TRUE))
})

test_that("acti_calculate_verisense resolves a single method", {
  data = tibble::tibble(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 0:2,
    X = 0, Y = 0, Z = 1
  )
  seen = NULL
  testthat::local_mocked_bindings(
    estimate_steps_verisense = function(data, resample_to_15hz = TRUE, ...,
                                        method) {
      seen <<- method
      tibble::tibble(time = data$time[1], steps = 1)
    },
    .package = "walking"
  )
  out = acti_calculate_verisense(data)
  expect_identical(seen, "original")
  trans = get_transformations(out)
  expect_equal(sum(grepl("verisense_.*_steps_estimated", trans)), 1L)
  expect_error(acti_calculate_verisense(data, method = "bad"))
})

test_that("acti_calculate_wear requires 60-second epochs", {
  data = make_minute_counts(epoch = 30, vector.magnitude = 1)
  expect_error(acti_calculate_wear(data), "requires 60-second epochs")
  expect_error(acti_calculate_wear(data, method = "troiano"),
               "30-second epochs")
  expect_true(check_60s_epochs(data$timestamp[1]))
})

test_that("acti_calculate_wear passes ... and ignores existing wear columns", {
  data = make_minute_counts(vector.magnitude = 1, wear = FALSE,
                            wear_old = TRUE)
  seen = NULL
  testthat::local_mocked_bindings(
    apply_choi = function(x, use_magnitude = TRUE, ...) {
      seen <<- list(...)
      tibble::tibble(
        period_start = x$timestamp[2],
        period_end = x$timestamp[3] + 60
      )
    },
    .package = "actigraph.sleepr"
  )
  wear = acti_calculate_wear(data, min_period_len = 2)
  expect_identical(seen, list(min_period_len = 2))
  expect_named(wear, c("time", "wear"))
  expect_identical(wear$wear, c(TRUE, FALSE, FALSE, TRUE))
})

test_that("axis-based scoring requires axis1 instead of VM/sqrt(3)", {
  vm_only = make_minute_counts(counts = c(1, 2, 3, 4))
  expect_error(acti_apply_cole_kripke(vm_only), "requires an `axis1`")
  expect_error(acti_apply_sadeh(vm_only), "requires an `axis1`")
  expect_error(acti_calculate_wear(vm_only, use_magnitude = FALSE),
               "requires an `axis1`")

  # magnitude-based wear still works from VM-only counts: the synthetic axes
  # reproduce the magnitude exactly
  std = acti_standardize_actigraph.sleepr(vm_only)
  expect_equal(sqrt(std$axis1^2 + std$axis2^2 + std$axis3^2), std$counts)
})

test_that("Cole-Kripke and Sadeh score the axis1 counts", {
  epochs = make_sleepr_epochs()
  ck = acti_apply_cole_kripke(epochs)
  expect_equal(nrow(ck), nrow(epochs))
  # changing axis2/axis3 must not change the axis1-based scores
  shuffled = epochs
  shuffled$axis2 = rev(shuffled$axis2)
  shuffled$axis3 = 0
  expect_identical(acti_apply_cole_kripke(shuffled)$sleep, ck$sleep)
  expect_identical(acti_apply_sadeh(shuffled)$sleep,
                   acti_apply_sadeh(epochs)$sleep)
})

test_that("acti_apply_tudor_locke uses sleep_col", {
  time = as.POSIXct("2020-01-01 22:00:00", tz = "UTC") + c(0, 60, 120)
  data = data.frame(time = time, axis1 = c(1, 2, 3))
  diary = data.frame(onset = time[2], wakeup = time[3])
  labeled = acti_apply_tudor_locke_diary(data, diary, sleep_col = "in_diary")

  testthat::local_mocked_bindings(
    apply_tudor_locke = function(x, ...) {
      expect_identical(x$sleep, c("W", "S", "W"))
      tibble::tibble(in_bed_time = x$timestamp[1])
    },
    .package = "actigraph.sleepr"
  )
  expect_named(acti_apply_tudor_locke(labeled, sleep_col = "in_diary"),
               "in_bed_time")
  expect_error(acti_apply_tudor_locke(labeled), "no sleep-state column `sleep`")
})

test_that("acti_calculate_counts gives a clear sample rate error", {
  one_row = tibble::tibble(
    time = as.POSIXct("2020-01-01", tz = "UTC"), X = 0, Y = 0, Z = 1
  )
  expect_error(
    suppressWarnings(
      acti_calculate_counts(one_row, resample = FALSE, verbose = FALSE)),
    "acti_calculate_counts\\(resample = FALSE\\) needs the sampling frequency"
  )
})

test_that("acti_calculate_counts passes only time/X/Y/Z to agcounts", {
  data = data.frame(
    TIME = as.POSIXct("2020-01-01 00:00:00.5", tz = "UTC") +
      seq(0, by = 1 / 30, length.out = 120),
    x = 0.1, Y = 0.2, Z = 1, light = 5
  )
  attr(data, "sample_rate") = 30L
  data = set_transformations(data, "original")
  seen = NULL
  testthat::local_mocked_bindings(
    calculate_counts = function(raw, epoch, tz, lfe_select, verbose) {
      seen <<- raw
      data.frame(time = raw$time[1], Axis1 = 1, Axis2 = 1, Axis3 = 1,
                 Vector.Magnitude = 2)
    },
    .package = "agcounts"
  )
  for (fix in c(TRUE, FALSE)) {
    out = acti_calculate_counts(data, resample = FALSE, verbose = FALSE,
                                fix_first_second = fix)
    expect_named(seen, c("time", "X", "Y", "Z"))
    expect_equal(attr(seen, "sample_rate"), 30L)
    expect_true("original" %in% get_transformations(out))
  }
})

test_that("acti_calculate_counts handles extra columns with an offset start", {
  if (!can_run_agcounts()) {
    skip("agcounts is not runnable in this session")
  }
  # fix_first_second = FALSE needs agcounts PR #51 (0.7.1) for an offset start
  skip_if(utils::packageVersion("agcounts") < "0.7.1",
          "agcounts < 0.7.1 crashes on a sub-second offset start")
  raw = make_example_signal(n = 30000L)
  r30 = actibase::acti_resample(raw, sample_rate = 30L)
  d = r30[r30$time >= r30$time[1] + 60.5, ]
  attr(d, "sample_rate") = 30L
  d$light = 0
  with_fix = acti_calculate_counts(d, resample = FALSE, verbose = FALSE)
  without = acti_calculate_counts(d, resample = FALSE, verbose = FALSE,
                                  fix_first_second = FALSE)
  expect_equal(without$counts, with_fix$counts)
  expect_false(anyDuplicated(without$time) > 0)
})

test_that("fix_first_second_function pads to the epoch start robustly", {
  t0 = as.POSIXct("2020-01-01 00:00:30.5", tz = "America/New_York")
  data = tibble::tibble(
    time = t0 + seq(0, by = 1 / 30, length.out = 90),
    X = 0.1, Y = 0.2, Z = 1, id = "a"
  )
  attr(data, "sample_rate") = 30L
  attr(data, "header") = "hdr"
  data = set_transformations(data, "original")

  out = fix_first_second_function(data, epoch = 60L)
  n_add = nrow(out) - nrow(data)
  expect_equal(n_add, 915L)
  expect_equal(out$time[1],
               as.POSIXct("2020-01-01 00:00:00", tz = "America/New_York"))
  expect_equal(lubridate::tz(out$time), "America/New_York")
  expect_equal(diff(as.numeric(out$time[seq_len(n_add)])),
               rep(1 / 30, n_add - 1L), tolerance = 1e-5)
  expect_true(all(out$time[seq_len(n_add)] < t0))
  expect_identical(out$id, rep("a", nrow(out)))
  expect_identical(out$X[1], 0.1)
  expect_equal(attr(out, "sample_rate"), 30L)
  expect_identical(attr(out, "header"), "hdr")
  expect_equal(
    get_transformations(out),
    c("acti_calculate_counts:first_second_data_appended", "original")
  )

  aligned = fix_first_second_function(out, epoch = 60L)
  expect_identical(aligned, out)
  expect_identical(fix_first_second_function(data[0, ], sample_rate = 30),
                   data[0, ])
  bad = data
  bad$time[1] = NA
  expect_error(fix_first_second_function(bad, epoch = 60L),
               "first `time` value is missing")
})

test_that("acti_calculate_fast_mims warns that sample_rate is ignored", {
  testthat::local_mocked_bindings(
    mims_default_processing = function(data, ...) {
      out = tibble::tibble(
        HEADER_TIME_STAMP = as.POSIXct("2020-01-01", tz = "UTC"),
        X = 1, Y = 1, Z = 1
      )
      attr(out, "sample_rate") = 100
      out
    },
    acti_calculate_auc = function(data, sample_rate = NULL, ...) {
      expect_equal(sample_rate, 100)
      tibble::tibble(HEADER_TIME_STAMP = data$HEADER_TIME_STAMP, AUC = 1)
    },
    .package = "actimetrics"
  )
  data = make_regular_signal(100)
  expect_warning(
    out <- acti_calculate_fast_mims(data, sample_rate = 30, verbose = FALSE),
    "`sample_rate` is ignored"
  )
  expect_named(out, c("HEADER_TIME_STAMP", "MIMS_UNIT"))
})

test_that("acti_calculate_ai skips 1-sample seconds instead of NA-ing the unit", {
  data = make_regular_signal(5900)
  # add one lone sample in second 59
  lone = data[1, ]
  lone$time = as.POSIXct("2020-01-01 00:00:59.5", tz = "UTC")
  data = rbind(data, lone)
  attr(data, "sample_rate") = 100

  ai = acti_calculate_ai(data)
  expect_equal(nrow(ai), 1L)
  expect_true(is.finite(ai$AI))
  expect_equal(ai$AI, acti_calculate_ai(data[1:5900, ])$AI)

  slow = make_gap_signal()
  expect_warning(ai_slow <- acti_calculate_ai(slow), "fewer than 2 samples")
  expect_true(all(is.na(ai_slow$AI)))
})

test_that("n_in_interval parses unit strings like lubridate", {
  expect_equal(n_in_interval("30s", sample_rate = 1), 30)
  expect_equal(n_in_interval("1min", sample_rate = 1), 60)
  expect_equal(n_in_interval("1 min", sample_rate = 10), 600)
  expect_equal(n_in_interval("30 sec", sample_rate = 1), 30)
  expect_equal(n_in_interval("60 secs", sample_rate = 1), 60)
  expect_equal(n_in_interval("1 minute", sample_rate = 1), 60)
  expect_equal(n_in_interval("2 hours", sample_rate = 1), 7200)
  expect_equal(n_in_interval("1 day", sample_rate = 1), 86400)
  expect_error(n_in_interval("abc", sample_rate = 1), "Could not interpret")
  expect_error(n_in_interval("1 min"))
})

test_that("acti_calculate_auc truncation marks the whole epoch invalid", {
  data = tibble::tibble(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 0:59,
    X = 100, Y = 0.5, Z = 0.5
  )
  attr(data, "sample_rate") = 1
  out = acti_calculate_auc(data, allow_truncation = TRUE, verbose = FALSE)
  expect_equal(out$AUC_X, -0.01)
  expect_equal(out$AUC_Y, -0.01)
  expect_equal(out$AUC, -0.01)

  ok = acti_calculate_auc(data, allow_truncation = FALSE, verbose = FALSE)
  expect_equal(ok$AUC, ok$AUC_X + ok$AUC_Y + ok$AUC_Z)
  expect_true(ok$AUC > 0)
})

test_that("acti_calculate_measures labels the aggregation without a space", {
  data = make_regular_signal(6000)
  out = acti_calculate_measures(data, calculate_mims = FALSE,
                                calculate_ac = FALSE, flag_data = FALSE,
                                verbose = FALSE)
  expect_true("aggregated_at_1 min" %in% get_transformations(out))
})

test_that("py_acti_* return the child-process result visibly", {
  testthat::local_mocked_bindings(
    r = function(func, args, show = FALSE) do.call(func, args),
    .package = "callr"
  )
  testthat::local_mocked_bindings(
    acti_calculate_stepcount = function(...) list(kind = "stepcount", ...),
    acti_calculate_forest = function(...) list(kind = "forest", ...),
    .package = "actimetrics"
  )
  res = withVisible(py_acti_calculate_stepcount(
    x = 1, pyenv_function = function() NULL))
  expect_true(res$visible)
  expect_identical(res$value, list(kind = "stepcount", x = 1))

  res = withVisible(py_acti_calculate_forest(
    x = 1, pyenv_function = function(args) c(args, y = 2)))
  expect_true(res$visible)
  expect_identical(res$value, list(kind = "forest", x = 1, y = 2))
})

test_that("acti_process_study reads CSV with readr and reports failures", {
  indir = tempfile("study_in")
  dir.create(indir)
  outdir = file.path(tempfile("study_out"), "out")
  on.exit(unlink(c(indir, dirname(outdir)), recursive = TRUE), add = TRUE)
  readr::write_csv(
    data.frame(time = "2020-01-01 00:00:00", X = 0, Y = 0, Z = 1),
    file.path(indir, "a.csv")
  )
  file.create(file.path(indir, "b.gt3x"))
  file.create(file.path(indir, "notes.txt"))

  testthat::local_mocked_bindings(
    acti_read_gt3x = function(...) stop("corrupt file"),
    acti_process = function(raw, verbose = TRUE, ...) raw,
    .package = "actimetrics"
  )
  expect_warning(
    saved <- acti_process_study(indir, outdir, verbose = FALSE),
    "1 of 2 file\\(s\\) failed to process: b.gt3x"
  )
  expect_identical(basename(saved), "a.csv.rds")
  expect_identical(unname(attr(saved, "failed")), "corrupt file")
  expect_identical(basename(names(attr(saved, "failed"))), "b.gt3x")

  csv = readRDS(saved)
  expect_s3_class(csv, "tbl_df")
  expect_s3_class(csv$time, "POSIXct")
})

test_that("round_half_away rounds midpoints away from zero", {
  x = c(16, 48, 80, -16, -48) / 256
  expect_equal(round_half_away(x, 3), c(0.063, 0.188, 0.313, -0.063, -0.188))
  expect_equal(round_half_away(x, 3), sign(x) * trunc(abs(x) * 1000 + 0.5) / 1000)
  expect_equal(round_half_away(c(0, 1.2344, -1.2346), 3), c(0, 1.234, -1.235))
})

test_that("acti_calculate_counts rounds XYZ with round_digits", {
  data = data.frame(
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      seq(0, by = 1 / 30, length.out = 120),
    X = 16 / 256, Y = -0.12345, Z = 1.00049
  )
  attr(data, "sample_rate") = 30L
  seen = NULL
  testthat::local_mocked_bindings(
    calculate_counts = function(raw, epoch, tz, lfe_select, verbose) {
      seen <<- raw
      data.frame(time = raw$time[1], Axis1 = 1, Axis2 = 1, Axis3 = 1,
                 Vector.Magnitude = 2)
    },
    .package = "agcounts"
  )
  out = acti_calculate_counts(data, resample = FALSE, verbose = FALSE,
                              round_digits = 3)
  expect_equal(unique(seen$X), 0.063)
  expect_equal(unique(seen$Y), -0.123)
  expect_equal(unique(seen$Z), 1)
  expect_true("acti_calculate_counts:XYZ_rounded_to_3_digits" %in%
                get_transformations(out))
  acti_calculate_counts(data, resample = FALSE, verbose = FALSE)
  expect_equal(unique(seen$Y), -0.12345)
  expect_error(
    acti_calculate_counts(data, resample = FALSE, verbose = FALSE,
                          round_digits = 1.5),
    "round_digits"
  )
})
