#' Classify activity counts using intensity thresholds
#'
#' Applies count thresholds to a count-data set after verifying that its
#' timestamps have the requested, regular epoch.  Thresholds must be expressed
#' in counts per `epoch` seconds.  Published cut-points should only be used at
#' the epoch and placement for which they were developed.
#'
#' @param data A data frame with `time` and `counts` columns.
#' @param thresholds Increasing numeric lower bounds for successive intensity
#'   categories, expressed in counts per `epoch` seconds.
#' @param labels Labels for the categories.  There must be one more label than
#'   threshold.
#' @param name Name of the factor column to add to `data`.
#' @param epoch Required epoch, in seconds.
#' @return `data` with an ordered factor column named by `name`.
#' @export
#' @examples
#' counts <- data.frame(
#'   time = as.POSIXct("2020-01-01", tz = "UTC") + 60 * 0:2,
#'   counts = c(0, 3000, 5000)
#' )
#' acti_threshold_counts(
#'   counts,
#'   thresholds = c(2860, 3941),
#'   labels = c("sedentary", "light", "mvpa")
#' )
acti_threshold_counts <- function(data,
                                  thresholds,
                                  labels,
                                  name = "activity_intensity",
                                  epoch = 60) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  if (!all(c("time", "counts") %in% names(data))) {
    stop("`data` must contain `time` and `counts` columns.", call. = FALSE)
  }
  if (!inherits(data$time, "POSIXt")) {
    stop("`time` must be a POSIXct or POSIXlt column.", call. = FALSE)
  }
  if (!is.numeric(data$counts)) {
    stop("`counts` must be numeric.", call. = FALSE)
  }
  if (!is.numeric(epoch) || length(epoch) != 1L || is.na(epoch) || epoch <= 0) {
    stop("`epoch` must be one positive number of seconds.", call. = FALSE)
  }
  if (!is.numeric(thresholds) || any(!is.finite(thresholds)) ||
      is.unsorted(thresholds, strictly = TRUE)) {
    stop("`thresholds` must be finite, strictly increasing numeric values.",
         call. = FALSE)
  }
  if (length(labels) != length(thresholds) + 1L || anyNA(labels)) {
    stop("`labels` must have one more non-missing value than `thresholds`.",
         call. = FALSE)
  }
  if (nrow(data) < 2L) {
    stop("`data` must have at least two rows to verify its epoch.", call. = FALSE)
  }

  intervals <- as.numeric(diff(data$time), units = "secs")
  if (any(!is.finite(intervals)) || any(abs(intervals - epoch) > 1e-8)) {
    stop("`time` must be regular with an epoch of ", epoch, " seconds.",
         call. = FALSE)
  }

  data[[name]] <- cut(
    data$counts,
    breaks = c(-Inf, thresholds, Inf),
    labels = labels,
    right = FALSE,
    ordered_result = TRUE
  )
  data
}

#' Classify wrist ActiGraph counts with Montoye cut-points
#'
#' Classifies 60-second ActiGraph vector-magnitude counts from a non-dominant
#' wrist as sedentary, light activity, or moderate-to-vigorous physical
#' activity (MVPA).  These cut-points were developed in free-living adults with
#' a GT9X Link and should not be used for another placement, device, or epoch.
#'
#' Montoye et al. recommend `<2860` counts/minute for sedentary activity,
#' `2860`--`3940` for light activity, and `>=3941` for MVPA
#' <doi:10.1080/02640414.2020.1794244>.
#'
#' @inheritParams acti_threshold_counts
#' @param name Name of the added ordered factor column.
#' @return `data` with an ordered factor column named by `name`.
#' @references Montoye AH, Clevenger KA, Pfeiffer KA, et al. Development of
#'   cut-points for determining activity intensity from a wrist-worn ActiGraph
#'   accelerometer in free-living adults. *Journal of Sports Sciences*.
#'   2020;38(22):2569-2578. doi:10.1080/02640414.2020.1794244.
#' @export
acti_threshold_montoye <- function(data, name = "montoye_intensity") {
  acti_threshold_counts(
    data = data,
    thresholds = c(2860, 3941),
    labels = c("sedentary", "light", "mvpa"),
    name = name,
    epoch = 60
  )
}

#' Classify hip ActiGraph counts with Sasaki cut-points
#'
#' Classifies 60-second ActiGraph vector-magnitude counts from a hip-worn
#' GT3X as less-than-moderate activity, moderate, hard, or very hard activity.
#' The source provides no sedentary/light boundary, so the first category is
#' deliberately named `light_or_less`.  Do not use these hip-specific
#' cut-points for wrist data.
#'
#' Sasaki et al. recommend `2690`--`6166` counts/minute for moderate,
#' `6167`--`9642` for hard, and `>9642` for very hard activity
#' <doi:10.1016/j.jsams.2011.04.003>.
#'
#' @inheritParams acti_threshold_counts
#' @param name Name of the added ordered factor column.
#' @return `data` with an ordered factor column named by `name`.
#' @references Sasaki JE, John D, Freedson PS. Validation and comparison of
#'   ActiGraph activity monitors. *Journal of Science and Medicine in Sport*.
#'   2011;14(5):411-416. doi:10.1016/j.jsams.2011.04.003.
#' @export
acti_threshold_sasaki <- function(data, name = "sasaki_intensity") {
  acti_threshold_counts(
    data = data,
    thresholds = c(2690, 6167, 9643),
    labels = c("light_or_less", "moderate", "hard", "very_hard"),
    name = name,
    epoch = 60
  )
}

#' Classify adolescent hip ActiGraph counts with Romanzini cut-points
#'
#' Classifies 15-second ActiGraph GT3X vector-magnitude counts from an
#' adolescent hip-worn monitor as sedentary, light, moderate, or vigorous
#' activity.  The cut-points must not be rescaled to another epoch.
#'
#' Romanzini et al. recommend `<=180` counts/15 seconds for sedentary,
#' `181`--`756` for light, `757`--`1111` for moderate, and `>=1112` for
#' vigorous activity <doi:10.1080/17461391.2012.732614>.
#'
#' @inheritParams acti_threshold_counts
#' @param name Name of the added ordered factor column.
#' @return `data` with an ordered factor column named by `name`.
#' @references Romanzini M, Petroski EL, Ohara D, Dourado AC, Reichert FF.
#'   Calibration of ActiGraph GT3X, Actical and RT3 accelerometers in
#'   adolescents. *European Journal of Sport Science*. 2014;14(1):91-99.
#'   doi:10.1080/17461391.2012.732614.
#' @export
acti_threshold_romanzini <- function(data, name = "romanzini_intensity") {
  acti_threshold_counts(
    data = data,
    thresholds = c(181, 757, 1112),
    labels = c("sedentary", "light", "moderate", "vigorous"),
    name = name,
    epoch = 15
  )
}

#' Classify ENMO using activity-intensity thresholds
#'
#' Applies thresholds to Euclidean Norm Minus One (ENMO) values after checking
#' the regular epoch in `time`.  ENMO values must be in milli-g (mg), as is
#' conventional for published ENMO cut-points.  The output of
#' [acti_calculate_enmo()] is in g; multiply `ENMO_t` by 1000 before using this
#' function.
#'
#' @param data A data frame with a `time` and an ENMO column.
#' @param thresholds Increasing numeric lower bounds for successive intensity
#'   categories, in mg.
#' @param labels Labels for the categories. There must be one more label than
#'   threshold.
#' @param name Name of the factor column to add to `data`.
#' @param epoch Required epoch, in seconds.
#' @param enmo Name of the ENMO column, in mg.
#' @return `data` with an ordered factor column named by `name`.
#' @export
acti_threshold_enmo <- function(data,
                                thresholds,
                                labels,
                                name = "activity_intensity",
                                epoch,
                                enmo = "enmo") {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  if (!all(c("time", enmo) %in% names(data))) {
    stop("`data` must contain `time` and the selected ENMO column.", call. = FALSE)
  }
  if (!inherits(data$time, "POSIXt")) {
    stop("`time` must be a POSIXct or POSIXlt column.", call. = FALSE)
  }
  if (!is.numeric(data[[enmo]])) {
    stop("the selected ENMO column must be numeric.", call. = FALSE)
  }
  if (!is.numeric(epoch) || length(epoch) != 1L || is.na(epoch) || epoch <= 0) {
    stop("`epoch` must be one positive number of seconds.", call. = FALSE)
  }
  if (!is.numeric(thresholds) || any(!is.finite(thresholds)) ||
      is.unsorted(thresholds, strictly = TRUE)) {
    stop("`thresholds` must be finite, strictly increasing numeric values.",
         call. = FALSE)
  }
  if (length(labels) != length(thresholds) + 1L || anyNA(labels)) {
    stop("`labels` must have one more non-missing value than `thresholds`.",
         call. = FALSE)
  }
  if (nrow(data) < 2L) {
    stop("`data` must have at least two rows to verify its epoch.", call. = FALSE)
  }

  intervals <- as.numeric(diff(data$time), units = "secs")
  if (any(!is.finite(intervals)) || any(abs(intervals - epoch) > 1e-8)) {
    stop("`time` must be regular with an epoch of ", epoch, " seconds.",
         call. = FALSE)
  }
  data[[name]] <- cut(
    data[[enmo]],
    breaks = c(-Inf, thresholds, Inf),
    labels = labels,
    right = FALSE,
    ordered_result = TRUE
  )
  data
}

#' Classify adult ENMO with Hildebrand cut-points
#'
#' Classifies one-second, raw ActiGraph GT3X+ ENMO values in mg from adults as
#' light-or-less, moderate, or vigorous physical activity. The source used a
#' 60-Hz device at the right hip or non-dominant wrist; select the matching
#' placement and do not apply these adult thresholds to children.
#'
#' Hildebrand et al. report lower bounds of 69.1 and 258.7 mg at the hip, and
#' 100.6 and 428.8 mg at the wrist, for moderate and vigorous activity,
#' respectively <doi:10.1249/MSS.0000000000000289>.
#'
#' @inheritParams acti_threshold_enmo
#' @param placement Body placement used in the original calibration: `"hip"`
#'   or `"wrist"`.
#' @param name Name of the added ordered factor column.
#' @param enmo Name of the ENMO column, in mg.
#' @return `data` with an ordered factor column named by `name`.
#' @references Hildebrand M, van Hees VT, Hansen BH, Ekelund U. Age group
#'   comparability of raw accelerometer output from wrist- and hip-worn
#'   monitors. *Medicine & Science in Sports & Exercise*. 2014;46(9):1816-1824.
#'   doi:10.1249/MSS.0000000000000289.
#' @export
acti_threshold_hildebrand <- function(data,
                                      placement = c("wrist", "hip"),
                                      name = "hildebrand_intensity",
                                      enmo = "enmo") {
  placement <- match.arg(placement)
  thresholds <- switch(
    placement,
    hip = c(69.1, 258.7),
    wrist = c(100.6, 428.8)
  )
  acti_threshold_enmo(
    data = data,
    thresholds = thresholds,
    labels = c("light_or_less", "moderate", "vigorous"),
    name = name,
    epoch = 1,
    enmo = enmo
  )
}

#' @rdname acti_threshold_hildebrand
#' @param ... not used, but used to pass arguments to
#' [acti_threshold_hildebrand] from
#' [acti_threshold_hildebrand_wrist] and [acti_threshold_hildebrand_hip]
#' @export
acti_threshold_hildebrand_wrist <- function(...,
                                      placement = "wrist") {
  acti_threshold_hildebrand(..., placement = placement)
}

#' @rdname acti_threshold_hildebrand
#' @export
acti_threshold_hildebrand_hip <- function(...,
                                      placement = "hip") {
  acti_threshold_hildebrand(..., placement = placement)
}
