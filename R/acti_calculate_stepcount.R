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
#' @param epoch epoch unit to aggregate the data to, passed to
#' [lubridate::floor_date()], original output is at 10-seconds
#'
#' @return A tibble with minute-level `time`, `steps`, and `walking`
#' columns.
#' @export
#'
#' @examples
#' \donttest{
#'   # reticulate::py_require("stepcount==3.11.0", python_version = "3.10", action = "add")
#'   # sc = try({ reticulate::import("stepcount") })
#'   if (stepcount::have_stepcount()) {
#'     data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#'     steps = acti_calculate_stepcount(data, sample_rate = 100)
#'     steps = acti_calculate_stepcount(data, model_type = "rf")
#'   }
#' }
acti_calculate_stepcount = function(data,
                                    sample_rate = NULL,
                                    ...,
                                    epoch = "1 minute"
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
  # This fixes where stepcount is done on rounded seconds for every 10 seconds,
  # not just whatever the data started on
  # if (is.data.frame(data)) {
  # fix_first_second_function(data, sample_rate = attr(data, "sample_rate"), epoch = 10L)
  # }
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
  walking = walking |>
    dplyr::mutate(
      time = lubridate::floor_date(time, unit = epoch),
      walking = walking > 0) |>
    dplyr::group_by(time) |>
    dplyr::summarise(
      walking = if (all(is.na(walking))) NA else any(walking, na.rm = TRUE)
    )
  sdata = steps$steps
  sdata = set_transformations(sdata, get_transformations(data), add = FALSE)
  sdata = set_transformations(sdata, "stepcounts_created",
                              prefix = "acti_calculate_stepcount",
                              add = TRUE)
  sdata = summarize_to_minute(sdata, prefix = "acti_calculate_stepcount",
                              unit = epoch)

  sdata = sdata |>
    dplyr::left_join(walking, by = "time")
  sdata = set_transformations(sdata,
                              "walking_column_joined",
                              prefix = "acti_calculate_stepcount",
                              add = TRUE)
  sdata
}



#' Perform step count calculation in a separate Python environment
#'
#' @param ... arguments passed to [acti_calculate_stepcount()]
#' @param pyenv_function function that loads the `stepcount` Python package.
#' By default, it uses `stepcount::py_require_stepcount()` to
#' set up the package. If this function has an `args` argument, the output
#' of `pyenv_function` will be re-assigned to `args`.
#' @param show Logical, whether to show the standard output on the
#' screen while the child process is running, passed to [callr::r()]
#'
#' @returns The output from [acti_calculate_stepcount()].
#' A tibble with minute-level `time`, `steps`, and `walking` columns.
#' @export
#'
#' @examples
#' \donttest{
#'   if (stepcount::have_stepcount()) {
#'     data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#'     steps = py_acti_calculate_stepcount(data, sample_rate = 100)
#'   }
#' }
py_acti_calculate_stepcount = function(
    ...,
    pyenv_function = function() {
      stepcount::py_require_stepcount()
    },
    show = FALSE) {
  run_in_callr(actimetrics::acti_calculate_stepcount, ...,
               pyenv_function = pyenv_function, show = show)
}
