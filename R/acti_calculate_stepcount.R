#' Calculate Step Counts via `stepcount`
#'
#' Use the `stepcount` package to estimate steps from raw accelerometer data
#' and summarize them to minute-level epochs (as opposed to 10s default)
#'
#' @param data A `data.frame`, `AccData` object, or GT3X file with `X`, `Y`,
#' `Z`, and `time`
#' @param sample_rate Sample rate in Hz. If omitted, it is taken from the
#' input object when available.
#' @param ... Additional arguments passed to [stepcount::stepcount()]
#'
#' @return A tibble with minute-level `time`, `steps`, and `walking`
#' columns.
#' @export
#'
#' @examples
#' \dontrun{
#'   reticulate::py_require("stepcount==3.11.0", python_version = "3.10", action = "add")
#'   sc = reticulate::import("stepcount")
#'   data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#'   steps = acti_calculate_stepcount(data, sample_rate = 100)
#'   steps = acti_calculate_stepcount(data, model_type = "rf")
#' }
acti_calculate_stepcount = function(data,
                                    sample_rate = NULL,
                                    ...
) {
  rlang::check_installed("stepcount")
  if (is.data.frame(data)) {
    data = acti_standardize_data(data, check_xyz = TRUE)
  }
  if (!is.null(sample_rate)) {
    attr(data, "sample_rate") = sample_rate
  } else {
    if (is.null(attr(data, "sample_rate"))) {
      attr(data, "sample_rate") = get_sample_rate(data)
    }
  }
  # assertthat::assert_that(
  #   assertthat::is.count(attr(data, "sample_rate"))
  # )
  assertthat::assert_that(
    assertthat::is.number(attr(data, "sample_rate"))
  )
  steps = stepcount::stepcount(data,
                               sample_rate = attr(data, "sample_rate"),
                               ...)
  walking = steps$walking
  walking = walking %>%
    dplyr::mutate(
      time = lubridate::floor_date(time, "1 minute"),
      walking = walking > 0) %>%
    dplyr::group_by(time) %>%
    dplyr::summarise(walking = any(walking, na.rm = TRUE))
  sdata = steps$steps
  sdata = set_transformations(sdata,
                              c("stepcounts_created",
                                get_transformations(data)
                              ),
                              prefix = "acti_calculate_stepcount",
                              add = FALSE)

  # Now do it at a minute level
  trans = get_transformations(sdata)
  sdata = sdata %>%
    dplyr::mutate(time = lubridate::floor_date(time, unit = "1 min")) %>%
    dplyr::group_by(time) %>%
    dplyr::summarise(steps = sum(steps, na.rm = TRUE)) %>%
    dplyr::ungroup()
  sdata = set_transformations(sdata, trans)
  sdata = set_transformations(sdata,
                              "steps_summarized_per_60s_epoch",
                              prefix = "acti_calculate_stepcount",
                              add = TRUE)

  sdata = sdata %>%
    dplyr::left_join(walking, by = "time")
  sdata = set_transformations(sdata,
                              "walking_column_joined",
                              prefix = "acti_calculate_stepcount",
                              add = TRUE)

  sdata = sdata %>%
    dplyr::mutate(steps = ifelse(!is.finite(steps), NA_integer_, steps))
  sdata
}



#' Perform step count calculation in a separate Python environment
#'
#' @param ... arguments passed to [acti_calculate_stepcount()]
#' @param pyenv_function function that loads the `stepcount` Python package.
#' By default, it uses `reticulate::py_import("stepcount")` to
#' import the package. If this function has an `args` argument, the output
#' of `pyenv_function` will be re-assigned to `args`.
#' @param show Logical, whether to show the standard output on the
#' screen while the child process is running, passed to [callr::r()]
#'
#' @returns The output from [acti_calculate_stepcount()].
#' A tibble with minute-level `time`, `steps`, and `walking` columns.
#' @export
#'
#' @examples
#' \dontrun{
#'   data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#'   steps = py_acti_calculate_stepcount(data, sample_rate = 100)
#' }
py_acti_calculate_stepcount = function(
    ...,
    pyenv_function = function() {
      stepcount::py_require_stepcount()
    },
    show = FALSE) {
  rlang::check_installed("callr")
  steps <- callr::r(
    show = show,
    func = function(..., pyenv_function) {
      args = list(...)
      if ("args" %in% methods::formalArgs(pyenv_function)) {
        args = pyenv_function(args)
      } else {
        pyenv_function()
      }
      res = do.call(actimetrics::acti_calculate_stepcount, args = args)
    },
    args = list(...,
                pyenv_function = pyenv_function)
  ) # Safely injects data into the process
}
