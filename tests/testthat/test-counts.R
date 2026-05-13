test_that("acti_calculate_counts compares resample strategies", {
  data = make_regular_signal(12000)

  counts_resample = suppressWarnings(
    acti_calculate_counts(data, resample = TRUE, verbose = FALSE)
  )
  counts_no_resample = suppressWarnings(
    acti_calculate_counts(data, resample = FALSE, verbose = FALSE)
  )

  expect_identical(names(counts_resample), names(counts_no_resample))
  expect_equal(counts_resample$time, counts_no_resample$time)
  expect_equal(nrow(counts_resample), nrow(counts_no_resample))
  expect_false(isTRUE(all.equal(counts_resample, counts_no_resample)))
  expect_true(any(counts_resample$counts != counts_no_resample$counts))
})
