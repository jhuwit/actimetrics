test_that("summary helpers calculate and fill time correctly", {
  data = make_gap_signal()

  ai_sparse = acti_calculate_ai(data, ensure_all_time = FALSE, verbose = TRUE)
  ai_full = acti_calculate_ai(data, ensure_all_time = TRUE, verbose = TRUE)
  expect_equal(nrow(ai_sparse) + 1L, nrow(ai_full))
  expect_true("AI" %in% names(ai_full))

  ai_index = acti_calculate_activity_index(
    data,
    ensure_all_time = FALSE,
    verbose = TRUE
  )
  expect_equal(ai_sparse, ai_index)

  dt = data.table::as.data.table(data)
  ai_dt = acti_calculate_ai(dt, ensure_all_time = FALSE, verbose = TRUE)
  expect_true(data.table::is.data.table(ai_dt))

  mad = acti_calculate_mad(data, ensure_all_time = FALSE, verbose = TRUE)
  expect_true(all(c("MAD", "ENMO_t", "AI_DEFINED") %in% names(mad)))
  expect_equal(
    nrow(acti_calculate_enmo(data, ensure_all_time = FALSE)),
    nrow(mad)
  )
  expect_equal(
    nrow(acti_calculate_ai_defined(data, ensure_all_time = FALSE)),
    nrow(mad)
  )

  auc = acti_calculate_auc(
    data,
    allow_truncation = TRUE,
    ensure_all_time = FALSE,
    verbose = TRUE
  )
  expect_true(all(c("AUC_X", "AUC_Y", "AUC_Z", "AUC") %in% names(auc)))

  expect_error(acti_calculate_flags(data), "flag is not in the data")
})

test_that("flag and idle summaries work on flagged data", {
  data = make_flagged_signal()

  flags = acti_calculate_flags(data, ensure_all_time = FALSE)
  expect_true("flag_low" %in% names(flags))
  expect_true("n_samples_in_unit" %in% names(flags))

  idle = acti_calculate_n_idle(data, ensure_all_time = FALSE)
  expect_true("n_idle" %in% names(idle))
  expect_true(any(idle$n_idle > 0))
})

test_that("calculate_measures combines summary outputs", {
  if (!can_run_agcounts() || !can_load_pkg("MIMSunit")) {
    skip("agcounts or MIMSunit is not runnable in this session")
  }
  data = make_example_signal(12000)

  measures = acti_calculate_measures(
    data,
    calculate_mims = TRUE,
    calculate_ac = TRUE,
    flag_data = TRUE,
    dynamic_range = c(-10, 10),
    ensure_all_time = FALSE,
    verbose = TRUE
  )

  expect_true("time" %in% names(measures))
  expect_true("AC" %in% names(measures))
  expect_true(any(grepl("MIMS", names(measures))))
  expect_true("flags" %in% names(measures))
})

test_that("data.table input stays data.table for summary branches", {
  data = data.table::as.data.table(make_gap_signal())
  mad = acti_calculate_mad(data, ensure_all_time = FALSE, verbose = TRUE)
  expect_true(data.table::is.data.table(mad))
})

test_that("dynamic range checks support AccData inputs", {
  data = make_accdata()
  expect_true(actimetrics:::check_dynamic_range(data, c(-2, 2)))
})
