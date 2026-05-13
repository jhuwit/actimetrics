test_that("Wear and others still work without axis data if counts there", {
  if (!can_run_agcounts() || !can_load_pkg("actigraph.sleepr")) {
    skip("agcounts is not runnable in this session")
  }
  counts = acti_calculate_counts(actibase::acti_raw_data, verbose = TRUE)

  wear_with_axis = acti_calculate_wear(counts)

  counts = counts %>%
    dplyr::select(-dplyr::starts_with("axis"))
  wear = acti_calculate_wear(counts)

  expect_equal(wear_with_axis, wear)
})
