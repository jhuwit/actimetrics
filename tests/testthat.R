if (rlang::is_installed("stepcount") && rlang::is_installed("reticulate")) {
  try({
    reticulate::py_require("stepcount==3.11.0", python_version = "3.10",
                           action = "add")
    reticulate::import("stepcount")
  })
}
Sys.setenv(SSQ_PARALLEL = 0)
library(testthat)
library(actimetrics)


test_check("actimetrics")
