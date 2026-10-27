#' Estimate Non-wear from Raw Accelerometry
#'
#' Detects non-wear from raw tri-axial acceleration.  Unlike
#' [acti_calculate_wear()], which works on 60-second activity counts, this
#' function takes the raw `X`, `Y`, `Z` signal (in g) as input.  It calls
#' [acti_calculate_wear_raw_ggir()] or [acti_calculate_wear_raw_actipy()];
#' see those functions for the algorithms and their arguments.  Neither GGIR
#' nor actipy is required.
#'
#' @param data A `data.frame` of raw accelerometer data with a time column and
#'   `X`, `Y`, `Z` columns, or an `AccData` object.  Data should be calibrated
#'   (e.g. with [acti_calibrate()]).
#' @param method Method for detecting non-wear, either `"ggir"` or
#'   `"actipy"`, corresponding to [acti_calculate_wear_raw_ggir()] or
#'   [acti_calculate_wear_raw_actipy()].
#' @param ... additional arguments to pass to the method function, such as
#'   `sample_rate`, `approach`, or `sd_threshold` for `"ggir"`, or `window`,
#'   `patience`, or `sd_threshold` for `"actipy"`.
#'
#' @return A `tibble` with one row per epoch, containing at least `time`
#'   (start of the epoch), `nonwear`, and `wear`.  The epoch length and the
#'   other columns depend on `method`.
#' @seealso [acti_calculate_wear_raw_ggir()], [acti_calculate_wear_raw_actipy()]
#' @export
#' @examples
#' n = 3 * 3600 * 10
#' time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + (seq_len(n) - 1) / 10
#' moving = rep(c(TRUE, FALSE, TRUE), each = n / 3)
#' set.seed(1)
#' data = data.frame(
#'   time = time,
#'   X = ifelse(moving, stats::rnorm(n, sd = 0.3), 0),
#'   Y = ifelse(moving, stats::rnorm(n, sd = 0.3), 0),
#'   Z = ifelse(moving, stats::rnorm(n, sd = 0.3), 1)
#' )
#' ggir = acti_calculate_wear_raw(data, sample_rate = 10)
#' actipy = acti_calculate_wear_raw(data, method = "actipy", patience = 3000)
acti_calculate_wear_raw = function(data,
                                   method = c("ggir", "actipy"),
                                   ...) {
  method = match.arg(method)
  func = switch(method,
                ggir = acti_calculate_wear_raw_ggir,
                actipy = acti_calculate_wear_raw_actipy
  )
  func(data, ...)
}
