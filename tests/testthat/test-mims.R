test_that("MIMS worker helpers process standardised data", {
  data = make_example_signal(6000)

  extrapolated = mims_default_extrapolation(data, dynamic_range = c(-2, 2))
  expect_equal(attr(extrapolated, "sample_rate"), 100)
  expect_true("HEADER_TIME_STAMP" %in% names(extrapolated))

  interpolated = mims_default_interpolation(data)
  expect_equal(attr(interpolated, "sample_rate"), 100)
  expect_true("HEADER_TIME_STAMP" %in% names(interpolated))

  filtered = mims_default_filtering(data)
  expect_equal(attr(filtered, "sample_rate"), 100)
  expect_true("HEADER_TIME_STAMP" %in% names(filtered))

  data_warn = data
  attr(data_warn, "sample_rate") = 50
  expect_warning(mims_default_filtering(data_warn), "Sample rate != 100")

  data_no_sr = data
  attr(data_no_sr, "sample_rate") = NULL
  expect_error(
    mims_default_filtering(data_no_sr),
    "sample_rate"
  )
})

test_that("MIMS processors and shortcuts return expected shapes", {
  data = make_example_signal(6000)

  processed = mims_default_processing(
    data,
    use_extrapolation = FALSE,
    use_filtering = FALSE,
    dynamic_range = c(-2, 2),
    round_after_processing = TRUE
  )
  expect_true(all(c("HEADER_TIME_STAMP", "X", "Y", "Z") %in% names(processed)))
  expect_true(all(abs(processed$X * 1000 - round(processed$X * 1000)) < 1e-8))

  fast = acti_calculate_fast_mims(
    data,
    dynamic_range = c(-2, 2),
    output_mims_per_axis = TRUE,
    ensure_all_time = FALSE,
    verbose = TRUE
  )
  expect_true(any(grepl("MIMS_UNIT", names(fast))))

  mims = acti_calculate_mims(data, dynamic_range = c(-10, 10), ensure_all_time = FALSE)
  expect_true(any(grepl("MIMS", names(mims))))
})

test_that("wear helpers rename time columns and run algorithms", {
  if (!can_run_agcounts() || !can_load_pkg("actigraph.sleepr")) {
    skip("agcounts or actigraph.sleepr is not runnable in this session")
  }
  data = make_sleepr_epochs()
  wear = acti_calculate_wear(data)
  expect_named(wear, c("time", "wear"))

  cole_kripke = acti_apply_cole_kripke(data)
  expect_true(all(c("time", "sleep") %in% names(cole_kripke)))
  expect_true(any(grepl("cole_kripke_run", get_transformations(cole_kripke))))

  tudor_locke = acti_apply_tudor_locke(cole_kripke)
  expect_true(all(
    c("in_bed_time", "out_bed_time", "sleep_fragmentation_index") %in%
      names(tudor_locke)
  ))
  expect_true(any(grepl("tudor_locke_run", get_transformations(tudor_locke))))

  sadeh = acti_apply_sadeh(cole_kripke)
  expect_true(all(c("timestamp", "sleep") %in% names(sadeh)))
  expect_true(any(grepl("apply_sadeh_run", get_transformations(sadeh))))
})

test_that("activity count, processing, and calibration helpers work on example data", {
  if (!can_run_agcounts() || !can_load_pkg("actigraph.sleepr")) {
    skip("agcounts is not runnable in this session")
  }
  data = make_regular_signal(12000)
  counts = acti_calculate_counts(data, verbose = TRUE)
  expect_true(all(c("time", "counts") %in% names(counts)))

  path = actiread::acti_example_gt3x()
  processed = acti_process(path, verbose = FALSE)
  expect_true(all(c("time", "counts", "wear") %in% names(processed)))
  expect_true(any(grepl("counts_wear_merge", get_transformations(processed))))

  calibrated = acti_calibrate(data = data[1:6000, ], verbose = FALSE)
  expect_true("time" %in% names(calibrated))
})

test_that("acti_calibrate emits verbose messages", {
  if (!can_run_agcounts()) {
    skip("agcounts is not runnable in this session")
  }
  expect_message(
    acti_calibrate(
      data = actiread::acti_example_gt3x(),
      verbose = TRUE
    ),
    "Running agcounts::agcalibrate"
  )
})
