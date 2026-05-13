test_that("stepcount works", {
  testthat::skip_if_not_installed("stepcount")
  testthat::skip_if_not_installed("reticulate")
  try({
    reticulate::py_require("stepcount==3.11.0", python_version = "3.10",
                           action = "add")
    reticulate::import("stepcount")
  })

  testthat::skip_if_not(stepcount::stepcount_check())
  steps = acti_calculate_stepcount(actibase::acti_raw_data)

})
