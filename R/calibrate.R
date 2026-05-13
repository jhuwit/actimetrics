#' Calibrate Accelerometer Data using `agcounts`
#'
#' @param file Either a GT3X file, `AccData` object, or `data.frame` with
#' `X/Y/Z` and `time`
#' @param verbose print diagnostic messages, higher number result in higher verbosity
#' @param ... Additional arguments to pass to [agcounts::agcalibrate]
#' @param fill_zeroes Should [locf_zeros] be run before calculating
#' the measures?
#' should the time course be trimmed for zero values at
#' the beginning and the end of the time course?
#' observation carried forward?
#' @param round_after_calibration Should the data be rounded after calibration?
#' Will round to 3 digits
#'
#' @rdname calibrate
#' @export
#'
#' @examples
#'   res = acti_calibrate(actiread::acti_example_gt3x())
acti_calibrate = function(
    file,
    verbose = TRUE,
    fill_zeroes = TRUE,
    round_after_calibration = TRUE,
    ...) {
  rlang::check_installed("agcounts")
  if (is.character(file) && grepl("[.]gt3x(|[.]gz)$", file)) {
    if (verbose) {
      message("Detected gt3x file - reading in using acti_read_gt3x")
    }
    file = acti_read_gt3x(file, verbose = verbose > 1)
  }
  # running it here because then we can add the transforms in there
  if (fill_zeroes) {
    if (verbose) {
      message("Filling Zeros")
    }
    file = acti_fill_zeros(
      file
    )
  }
  # already done - don't want to add another transformations
  transformations = get_transformations(file)

  if (verbose) {
    message("Running agcounts::agcalibrate")
  }
  data = agcounts::agcalibrate(
    file,
    verbose = verbose > 1,
    ...)

  if (round_after_calibration) {
    for (i in xyz) {
      data[[i]] = round(data[[i]], 3)
    }
  }
  data = set_transformations(data, transformations)
  data = set_transformations(data,
                             transformations = "agcounts_calibrated",
                             prefix = "acti_calibrate",
                             add = TRUE)

  return(data)
}
