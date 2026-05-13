# Legacy overlay helpers.
# These functions are kept out of the exported actibase baseline API on
# purpose. Move them into a downstream overlay package if they are still
# needed.



#' Default MIMS worker functions
#'
#' @param data data set of data, usually time and X/Y/Z.  Usually from
#' `actiread::acti_read_gt3x()`
#' @param dynamic_range dynamic range of the data.  Will be passed to
#' `actibase::get_dynamic_range()`
#'
#' @return A data set of data
#' @export
mims_default_extrapolation = function(data, dynamic_range = NULL) {
  if (!requireNamespace("MIMSunit", quietly = TRUE)) {
    stop("MIMSunit package required for mims_default_extrapolation")
  }
  transformations = get_transformations(data)
  is_acc = is.AccData(data)
  if (is_acc) {
    hdr = data$header
  }
  dynamic_range = get_dynamic_range(
    data,
    dynamic_range = dynamic_range)
  # required for MIMS functionality
  data = acti_standardize_data(
    data,
    subset_xyz = FALSE,
    colname_time = "HEADER_TIME_STAMP"
  )
  data = rename_time_stamp(data)
  sample_rate = attr(data, "sample_rate")

  noise_level = 0.03
  k = 0.05
  spar = 0.6
  # interpolation
  data <- MIMSunit::extrapolate(data, dynamic_range, noise_level,
                              k, spar)
  colnames(data) = gsub("EXTRAPOLATED_", "", colnames(data))
  attr(data, "sample_rate") = 100
  transformations = c("extrapolated", transformations)
  transformations = set_transformations(data, transformations = transformations,
                                        add = FALSE)
  if (is_acc) {
    data = remake_acc(data, hdr)
  }
  data
}

#' @rdname mims_default_extrapolation
#' @export
mims_default_interpolation = function(data) {
  if (!requireNamespace("MIMSunit", quietly = TRUE)) {
    stop("MIMSunit package required for mims_default_interpolation")
  }
  transformations = get_transformations(data)

  is_acc = is.AccData(data)
  if (is_acc) {
    hdr = data$header
  }
  data = acti_standardize_data(
    data,
    subset_xyz = FALSE,
    colname_time = "HEADER_TIME_STAMP"
  )
  data = rename_time_stamp(data)
  data = MIMSunit::interpolate_signal(data, sr = 100L, method = "linear")
  colnames(data) = gsub("INTERPOLATED_", "", colnames(data))
  attr(data, "sample_rate") = 100
  if (is_acc) {
    data = remake_acc(data, hdr)
  }
  transformations = c("interpolated", transformations)
  transformations = set_transformations(data, transformations = transformations,
                                        add = FALSE)
  data
}


# data already has been interpolated
#' @rdname mims_default_extrapolation
#' @export
mims_default_filtering = function(data) {
  if (!requireNamespace("MIMSunit", quietly = TRUE)) {
    stop("MIMSunit package required for mims_default_filtering")
  }
  transformations = get_transformations(data)
  is_acc = is.AccData(data)
  if (is_acc) {
    hdr = data$header
  }
  data = acti_standardize_data(
    data,
    subset_xyz = FALSE,
    colname_time = "HEADER_TIME_STAMP"
  )
  data = rename_time_stamp(data)
  sample_rate = attr(data, "sample_rate")
  if (is.null(sample_rate)) {
    stop("data needs attribute 'sample_rate' for filtering")
  }
  if (sample_rate != 100) {
    warning("Sample rate != 100, not sure if this works the same")
  }
  data <- MIMSunit::iir(
    data, sr = sample_rate,
    # cutoff_freq = eval(formals(custom_mims_unit)$cutoffs),
    cutoff_freq = c(0.2, 5.0),
    order = 4,
    type = "pass",
    filter_type = "butter")
  colnames(data) = gsub("IIR_", "", colnames(data))
  attr(data, "sample_rate") = sample_rate
  if (is_acc) {
    data = remake_acc(data, hdr)
  }
  transformations = c("filtered", transformations)
  transformations = set_transformations(data, transformations = transformations,
                                        add = FALSE)
  data
}

#' Default MIMS Pre-processing
#'
#' @param data Data set of raw accelerometry values, usually time and X/Y/Z.
#' Usually from `actiread::acti_read_gt3x()`
#' @param use_extrapolation If `TRUE` the function will apply extrapolation
#' algorithm to the input signal, otherwise it will skip
#' extrapolation but only linearly interpolate the signal to 100Hz.
#' @param use_filtering If `TRUE` the function will apply bandpass
#' filtering to the input signal, otherwise it will skip the filtering.
#' @param verbose print diagnostic messages
#' @param dynamic_range the dynamic ranges of the input signal.  Passed to
#' `actimetrics::mims_default_extrapolation()`.  Only needed if
#' `use_extrapolation = TRUE`
#' @param round_after_processing Should the result be rounded to 3
#' decimal values after processing, to make similar to standard accelerometry?
#'
#' @return A processed data set
#' @export
mims_default_processing = function(
  data, use_extrapolation = TRUE, use_filtering = TRUE,
  verbose = TRUE, dynamic_range = NULL,
  round_after_processing = FALSE) {
  X = Y = Z = NULL
  rm(list = c("X", "Y", "Z"))
  dynamic_range = get_dynamic_range(data, dynamic_range)
  if (use_extrapolation) {
    if (verbose) {
      message("Running extrapolation")
    }
    data <- mims_default_extrapolation(data, dynamic_range)
  } else {
    if (verbose) {
      message("Running interpolation")
    }
    data <- mims_default_interpolation(data)
  }
  if (use_filtering) {
    if (verbose) {
      message("Running filtering")
    }
    data = mims_default_filtering(data)
  }
  if (round_after_processing) {
    data = data %>%
      dplyr::mutate(
        X = round(X, 3),
        Y = round(Y, 3),
        Z = round(Z, 3))
  }
  data
}
