# Legacy overlay helpers.
# These functions are kept out of the exported actibase baseline API on
# purpose. Move them into a downstream overlay package if they are still
# needed.

#' Calculate Summary Measures from Raw Accelerometer Data
#'
#' @param data An object with columns `X`, `Y`, and `Z` or an
#' object of class `AccData`
#' @param unit length of time to calculate measures over.  a character string
#' specifying a time unit or a multiple of a unit to be rounded to.
#' Valid base units are `second`, `minute`, `hour`, `day`, `week`, `month`,
#' `bimonth`, `quarter`, `season`, `halfyear`, and `year`.
#' Arbitrary unique English abbreviations as in the `lubridate::period()`
#' constructor are allowed.
#' @param dynamic_range Dynamic range of the device, in gravity units
#' @param verbose print diagnostic messages
#' @param fix_zeros Should `actibase::acti_fill_zeros()` be run before
#' calculating the measures?
#' @param calculate_mims Should MIMS units be calculated?
#' @param calculate_ac Should Activity Counts from the `agcounts` package be
#' calculated?
#' @param flag_data Should the downstream overlay `flag_qc()` be run?
#' It will be executed after `fix_zeros` before any measure calculation
#' @param flags the flags to calculate,
#' passed to the downstream overlay `flag_qc()`
#' @param ensure_all_time if `TRUE`, then all times from the first to
#' last times will be in the output, even if data during that time was not
#' in the input
#' @param sample_rate Sample rate of the data, only used if
#' `calculcate_ac = TRUE`
#' @param ... additional arguments to pass to `MIMSunit::mims_unit()`
#'
#' @return A data set with the calculated features
#' @export
#' @examples
#' file = actiread::acti_example_gt3x()
#' res = actiread::acti_read_gt3x(file, verbose = FALSE)
#' res = res[1:12000, ]
#' measures = acti_calculate_measures(
#'   res,
#'   dynamic_range = NULL,
#'   calculate_mims = FALSE,
#'   calculate_ac = FALSE,
#'   flag_data = FALSE
#' )
#' auc = acti_calculate_auc(res)
#' \donttest{
#' mims = acti_calculate_mims(res, dynamic_range = NULL)
#' }
#' if (requireNamespace("data.table", quietly = TRUE)) {
#'    dt = data.table::as.data.table(res)
#'    out = acti_calculate_measures(dt, calculate_mims = FALSE, flag_data = FALSE,
#'      calculate_ac = FALSE)
#' }
acti_calculate_measures = function(
  data,
  unit = "1 min",
  fix_zeros = TRUE,
  dynamic_range = NULL,
  calculate_mims = TRUE,
  calculate_ac = TRUE,
  flag_data = TRUE,
  flags = NULL,
  ensure_all_time = TRUE,
  verbose = TRUE,
  sample_rate = NULL,
  ...) {
  if (calculate_ac && !requireNamespace("agcounts", quietly = TRUE)) {
    stop("agcounts package required for calculating AC")
  }

  if (calculate_mims && !requireNamespace("MIMSunit", quietly = TRUE)) {
    stop("MIMSunit package required for calculating MIMS")
  }

  time = HEADER_TIME_STAMP = X = Y = Z = r = NULL
  rm(list = c("HEADER_TIME_STAMP", "X", "Y", "Z", "r", "time"))
  if (calculate_mims || flag_data) {
    dynamic_range = get_dynamic_range(data, dynamic_range)
  }
  is_data_table = is_dt(data)
  data = acti_standardize_data(
    data,
    subset_xyz = FALSE,
    colname_time = "HEADER_TIME_STAMP"
  )
  data = rename_time_stamp(data)
  if (calculate_ac) {
    sample_rate = get_sample_rate(data, sample_rate = sample_rate)
  }
  if (fix_zeros) {
    if (verbose) {
      message("Fixing Zeros with fix_zeros")
    }
    data = acti_fill_zeros(data)
  }
  if (flag_data) {
    if (verbose) {
      message("Flagging data")
    }
    data = flag_qc_all(data, dynamic_range = dynamic_range, verbose = verbose,
                       flags = flags)
    data$flags = rowSums(
      data %>%
        dplyr::select(dplyr::starts_with("flag_")) > 0
    )
    flags = acti_calculate_flags(data, unit = unit)
    data = data %>%
      dplyr::select(-dplyr::starts_with("flag"))
  }
  transformations = get_transformations(data)

  data = remake_dt(data, is_data_table = is_data_table)

  if (verbose) {
    message("Calculating ai0")
  }
  res = acti_calculate_ai(data, unit = unit, verbose = verbose > 1)
  if (verbose) {
    message("Calculating MAD")
  }
  mad = acti_calculate_mad(data, unit = unit, verbose = verbose > 1)
  if (verbose) {
    message("Joining AI and MAD")
  }

  data = as.data.frame(data)
  res = dplyr::full_join(res, mad, by = "HEADER_TIME_STAMP")
  rm(mad)
  if (calculate_mims) {
    if (verbose) {
      message("Calculating MIMS")
    }
    calculate_mims_fun = get("acti_calculate_mims", mode = "function")
    mims = calculate_mims_fun(data, unit = unit,
                              dynamic_range = dynamic_range,
                              ...)
  }

  if (calculate_ac) {
    if (verbose) {
      message("Calculating AC")
    }
    # not an acti here because internal
    ac = calculate_activity_counts(
      data,
      unit = unit,
      sample_rate = sample_rate,
      verbose = verbose
    )
    ac$X = ac$Y = ac$Z = NULL
    if (verbose) {
      message("Joining AC")
    }
    res = dplyr::full_join(res, ac, by = "HEADER_TIME_STAMP")
    rm(ac)
  }
  rm(data)

  if (calculate_mims) {
    if (verbose) {
      message("Joining MIMS")
    }
    res = dplyr::full_join(res, mims, by = "HEADER_TIME_STAMP")
  }
  if (flag_data) {
    if (verbose) {
      message("Joining flags")
    }
    res = dplyr::full_join(res, flags, by = "HEADER_TIME_STAMP")
  }
  res = join_all_time(res, unit, ensure_all_time)
  res = res %>%
    dplyr::rename(time = HEADER_TIME_STAMP)
  transforms = paste("aggregated_at_", paste(unit, collapse = "_"))
  transformations = c(transforms, transformations)
  res = set_transformations(res, transformations = transformations,
                            add = FALSE)
  res
}

floor_sec = function(x) {
  if (lubridate::is.POSIXct(x)) {
    tz = lubridate::tz(x)
    x = as.numeric(x)
    x = floor(x)
    as.POSIXct(x, tz = tz, origin = lubridate::origin)
  } else {
    lubridate::floor_date(x, "1 sec")
  }
}

remake_dt = function(data, is_data_table = FALSE) {
  if (requireNamespace("data.table", quietly = TRUE) &&
      is_data_table) {
    data = data.table::as.data.table(data)
  }
  data
}
is_dt = function(x) {
  inherits(x, "data.table")
}

.datatable.aware = TRUE

#' @export
#' @rdname acti_calculate_measures
acti_calculate_ai = function(data, unit = "1 min", ensure_all_time = TRUE,
                        verbose = FALSE) {
  time = HEADER_TIME_STAMP = X = Y = Z = r = NULL
  rm(list = c("HEADER_TIME_STAMP", "X", "Y", "Z", "r", "time"))
  AI = NULL
  rm(list = c("AI"))

  is_data_table = is_dt(data)
  data = acti_standardize_data(
    data,
    subset_xyz = FALSE,
    colname_time = "HEADER_TIME_STAMP"
  )
  data = rename_time_stamp(data)
  if (is_data_table &&
      requireNamespace("data.table", quietly = TRUE)) {
    data = remake_dt(data, is_data_table = is_data_table)
    data = data[, HEADER_TIME_STAMP := floor_sec(HEADER_TIME_STAMP)]
    if (verbose) {
      message("Summarizing the variance")
    }
    data = data[, .(X = var(X, na.rm = TRUE),
                    Y = var(Y, na.rm = TRUE),
                    Z = var(Z, na.rm = TRUE)),
                by = .(HEADER_TIME_STAMP)]
    data$AI = sqrt(1/3 * (data$X + data$Y + data$Z))
    data = as.data.frame(data)[c("HEADER_TIME_STAMP", "AI")]
  } else {
    if (verbose) {
      message("Running floor_sec on time")
    }
    data = data %>%
      dplyr::mutate(HEADER_TIME_STAMP = floor_sec(HEADER_TIME_STAMP))

    if (verbose) {
      message("Summarizing the variance")
    }
    data = data %>%
      dplyr::group_by(HEADER_TIME_STAMP) %>%
      dplyr::summarise(
        AI = var(X, na.rm = TRUE) +
          var(Y, na.rm = TRUE) +
          var(Z, na.rm = TRUE)
      )
    if (verbose) {
      message("Calculating AI")
    }
    if (!is_data_table) {
      data = data %>%
        dplyr::ungroup()
    }
    data = data %>%
      dplyr::mutate(AI = sqrt(AI/3))
  }

  data = data %>%
    dplyr::mutate(
      HEADER_TIME_STAMP = lubridate::floor_date(HEADER_TIME_STAMP,
                                                unit)) %>%
    dplyr::group_by(HEADER_TIME_STAMP) %>%
    dplyr::summarise(
      AI = sum(AI)
    )
  data = data %>%
    tibble::as_tibble() %>%
    dplyr::ungroup()
  data = join_all_time(data, unit, ensure_all_time)
  data = remake_dt(data, is_data_table = is_data_table)
  data
}

join_all_time = function(data, unit = "1 min", ensure_all_time) {
  if (ensure_all_time) {
    rtime = range(data$HEADER_TIME_STAMP)
    time_df = tibble::tibble(HEADER_TIME_STAMP = seq(rtime[1], rtime[2],
                                                     by = unit))
    data = dplyr::left_join(time_df, data, by = "HEADER_TIME_STAMP")
  }
  data
}

#' @export
#' @rdname acti_calculate_measures
acti_calculate_activity_index = acti_calculate_ai

#' @export
#' @rdname acti_calculate_measures
acti_calculate_flags = function(data, unit = "1 min", ensure_all_time = TRUE) {
  time = HEADER_TIME_STAMP = X = Y = Z = r = NULL
  rm(list = c("HEADER_TIME_STAMP", "X", "Y", "Z", "r", "time"))
  data = acti_standardize_data(
    data,
    subset_xyz = FALSE,
    colname_time = "HEADER_TIME_STAMP"
  )
  data = rename_time_stamp(data)
  if (!any(grepl("^flag", colnames(data)))) {
    stop("flag is not in the data, please run flag_qc")
  }

  data = data %>%
    dplyr::mutate(
      HEADER_TIME_STAMP = lubridate::floor_date(HEADER_TIME_STAMP,
                                                unit)) %>%
    dplyr::group_by(HEADER_TIME_STAMP) %>%
    dplyr::summarise(
      dplyr::across(dplyr::starts_with("flag"), sum),
      n_samples_in_unit = dplyr::n()
    ) %>%
    dplyr::ungroup()
  data = join_all_time(data, unit, ensure_all_time)
  data
}

#' @export
#' @rdname acti_calculate_measures
acti_calculate_n_idle = function(data, unit = "1 min", ensure_all_time = TRUE) {
  ENMO = time = HEADER_TIME_STAMP = X = Y = Z = r = NULL
  rm(list = c("HEADER_TIME_STAMP", "X", "Y", "Z", "r", "time", "ENMO"))
  data = acti_standardize_data(
    data,
    subset_xyz = FALSE,
    colname_time = "HEADER_TIME_STAMP"
  )
  data = rename_time_stamp(data)

  n_idle = r = all_zero = NULL
  rm(list = c("n_idle", "r", "all_zero"))
  data = data %>%
    dplyr::mutate(
      r = sqrt(X^2+Y^2+Z^2),
      all_zero = X == 0 & Y == 0 & Z == 0,
      HEADER_TIME_STAMP = lubridate::floor_date(HEADER_TIME_STAMP,
                                                unit)) %>%
    dplyr::group_by(HEADER_TIME_STAMP) %>%
    dplyr::summarise(
      n_idle = sum(is.na(r) | all_zero)
    ) %>%
    dplyr::ungroup()
  data = join_all_time(data, unit, ensure_all_time)
  data
}

#' @export
#' @rdname acti_calculate_measures
acti_calculate_enmo = function(...) {
  ENMO_t = time = HEADER_TIME_STAMP = X = Y = Z = r = NULL
  rm(list = c("HEADER_TIME_STAMP", "X", "Y", "Z", "r", "time"))
  out = acti_calculate_mad(...)
  out %>%
    dplyr::select(HEADER_TIME_STAMP, ENMO_t)
}

#' @export
#' @rdname acti_calculate_measures
acti_calculate_ai_defined = function(...) {
  AI_DEFINED = time = HEADER_TIME_STAMP = X = Y = Z = r = NULL
  rm(list = c("HEADER_TIME_STAMP", "X", "Y", "Z", "r", "time", "AI_DEFINED"))
  out = acti_calculate_mad(...)
  out %>%
    dplyr::select(HEADER_TIME_STAMP, AI_DEFINED)
}

if (requireNamespace("data.table", quietly = TRUE)) {
  `:=` <- data.table::`:=`
  utils::globalVariables(c(
    ".",
    "AC",
    "HEADER_TIME_STAMP",
    "count",
    "counts",
    "timestamp",
    "vector.magnitude"
  ))
}

#' @export
#' @rdname acti_calculate_measures
acti_calculate_mad = function(data, unit = "1 min", ensure_all_time = TRUE,
                         verbose = FALSE) {
  ENMO_t = time = HEADER_TIME_STAMP = X = Y = Z = r = NULL
  rm(list = c("HEADER_TIME_STAMP", "X", "Y", "Z", "r", "time"))
  is_data_table = is_dt(data)
  data = acti_standardize_data(
    data,
    subset_xyz = FALSE,
    colname_time = "HEADER_TIME_STAMP"
  )
  data = rename_time_stamp(data)

  if (verbose) {
    message("Calculating r, ENMO, and flooring time")
  }
  if (is_data_table &&
      requireNamespace("data.table", quietly = TRUE)) {
    data = remake_dt(data, is_data_table = is_data_table)
    if (verbose) {
      message("Summarizing the variance")
    }
    data = data[, r := sqrt(X^2 + Y^2 + Z^2)]
    data = data[, HEADER_TIME_STAMP := lubridate::floor_date(
      HEADER_TIME_STAMP, unit)]

    data = data[, ENMO_t := r - 1]
    data = data[, ENMO_t := dplyr::if_else(ENMO_t < 0, 0, ENMO_t)]

    if (verbose) {
      message("Calculating all MAD measures")
    }
    data = data[, .(
      SD = sd(r, na.rm = TRUE),
      SD_t = sd(ENMO_t, na.rm = TRUE),
      AI_DEFINED = sqrt((
        var(X, na.rm = TRUE) +
          var(Y, na.rm = TRUE) +
          var(Z, na.rm = TRUE)) / 3),
      MAD = mean(abs(r - mean(r, na.rm = TRUE)), na.rm = TRUE),
      MEDAD = median(abs(r - mean(r, na.rm = TRUE)), na.rm = TRUE),
      mean_r = mean(r, na.rm = TRUE),
      ENMO_t = mean(ENMO_t, na.rm = TRUE)
    ), by = .(HEADER_TIME_STAMP)]
  } else {
    data = data %>%
      dplyr::mutate(
        r = sqrt(X^2 + Y^2 + Z^2),
        ENMO_t = r - 1,
        ENMO_t = dplyr::if_else(ENMO_t < 0, 0, ENMO_t),
        HEADER_TIME_STAMP = lubridate::floor_date(HEADER_TIME_STAMP,
                                                  unit))

    if (verbose) {
      message("Calculating all MAD measures")
    }
    data = data %>%
      dplyr::group_by(HEADER_TIME_STAMP) %>%
      dplyr::summarise(
        SD = sd(r, na.rm = TRUE),
        SD_t = sd(ENMO_t, na.rm = TRUE),
        AI_DEFINED = sqrt((
          var(X, na.rm = TRUE) +
            var(Y, na.rm = TRUE) +
            var(Z, na.rm = TRUE)) / 3),
        MAD = mean(abs(r - mean(r, na.rm = TRUE)), na.rm = TRUE),
        MEDAD = median(abs(r - mean(r, na.rm = TRUE)), na.rm = TRUE),
        mean_r = mean(r, na.rm = TRUE),
        ENMO_t = mean(ENMO_t, na.rm = TRUE)
      ) %>%
      dplyr::ungroup()
  }
  data = data %>%
    tibble::as_tibble() %>%
    dplyr::ungroup()
  data = join_all_time(data, unit, ensure_all_time)
  data = remake_dt(data, is_data_table = is_data_table)
  data
}

#' @export
#' @rdname acti_calculate_measures
#' @param sample_rate sample rate of data, if not specified in header of object
#' @param allow_truncation truncate small values
acti_calculate_auc = function(data, unit = "1 min",
                         sample_rate = NULL,
                         allow_truncation = FALSE,
                         ensure_all_time = TRUE,
                         verbose = TRUE
) {
  dtime = good = NULL
  rm(list = c("good", "dtime"))
  dtime = time = HEADER_TIME_STAMP = X = Y = Z = r = NULL
  rm(list = c("HEADER_TIME_STAMP", "X", "Y", "Z", "r", "time", "dtime"))
  AUC_X = AUC_Y = AUC_Z = NULL
  rm(list = c("AUC_X", "AUC_Z", "AUC_Y"))
  data = acti_standardize_data(
    data,
    subset_xyz = FALSE,
    colname_time = "HEADER_TIME_STAMP"
  )
  data = rename_time_stamp(data)
  sample_rate = get_sample_rate(data, sample_rate)

  n_total = n_in_interval(unit, sample_rate)
  max_values <- 16 * n_total

  if (verbose) {
    message("Absolute values")
  }
  data = data %>%
    dplyr::mutate(
      X = abs(X),
      Y = abs(Y),
      Z = abs(Z))
  if (verbose) {
    message("Calculting trapezoids")
  }
  data = data %>%
    dplyr::mutate(
      dtime = difftime(HEADER_TIME_STAMP,
                       dplyr::lag(HEADER_TIME_STAMP, n = 1),
                       units = "secs"),
      dtime = as.numeric(dtime),
      X = (X + dplyr::lag(X, n = 1)) / 2 * dtime,
      Y = (Y + dplyr::lag(Y, n = 1)) / 2 * dtime,
      Z = (Z + dplyr::lag(Z, n = 1)) / 2 * dtime
    ) %>%
    dplyr::select(-dtime)
  if (verbose) {
    message("Replacing first value as NA")
  }
  replace_first_na = function(x) {
    x[1] = NA
    x
  }
  data = data %>%
    dplyr::mutate(
      HEADER_TIME_STAMP = lubridate::floor_date(HEADER_TIME_STAMP,
                                                unit)
    ) %>%
    dplyr::group_by(HEADER_TIME_STAMP) %>%
    dplyr::mutate(
      X = replace_first_na(X),
      Y = replace_first_na(Y),
      Z = replace_first_na(Z)
    )
  data = data %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      good = !(is.na(X) | is.na(Y) | is.na(Z))
    )

  if (verbose) {
    message("Calculating AUCs")
  }
  data = data %>%
    dplyr::group_by(HEADER_TIME_STAMP) %>%
    dplyr::summarise(
      good = sum(good),
      AUC_X = sum(X, na.rm = TRUE),
      AUC_Y = sum(Y, na.rm = TRUE),
      AUC_Z = sum(Z, na.rm = TRUE)
    ) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(good = good >= (0.9 * n_total))
  data = data %>%
    dplyr::mutate(
      AUC_X = ifelse(good, AUC_X, NA),
      AUC_Y = ifelse(good, AUC_Y, NA),
      AUC_Z = ifelse(good, AUC_Z, NA)
    )
  if (allow_truncation) {
    if (verbose) {
      message("Truncating Small AUCs")
    }
    minimum = 1e-04 * n_total
    data = data %>%
      dplyr::mutate(
        AUC_X = ifelse(AUC_X <= minimum, 0, AUC_X),
        AUC_Y = ifelse(AUC_Y <= minimum, 0, AUC_Y),
        AUC_Z = ifelse(AUC_Z <= minimum, 0, AUC_Z)
      )
    data = data %>%
      dplyr::mutate(
        AUC_X = ifelse(AUC_X < 0 | AUC_X >= max_values, -1, AUC_X),
        AUC_Y = ifelse(AUC_Y < 0 | AUC_Y >= max_values, -1, AUC_Y),
        AUC_Z = ifelse(AUC_Z < 0 | AUC_Z >= max_values, -1, AUC_Z)
      )
  }
  data = data %>%
    dplyr::mutate(
      AUC = AUC_X + AUC_Y + AUC_Z
    ) %>%
    dplyr::select(-good)
  data = join_all_time(data, unit, ensure_all_time)
  data
}

calculate_activity_counts = function(data,
                                     unit = "1 min",
                                     sample_rate = NULL,
                                     verbose = TRUE) {
  data = acti_standardize_data(
    data,
    subset_xyz = FALSE,
    colname_time = "HEADER_TIME_STAMP"
  )
  data = rename_time_stamp(data)
  if ("HEADER_TIME_STAMP" %in% names(data) && !"time" %in% names(data)) {
    names(data)[names(data) == "HEADER_TIME_STAMP"] = "time"
  }
  sample_rate = get_sample_rate(data, sample_rate = sample_rate)
  if (is.null(sample_rate)) {
    stop("sample_rate is required for calculating AC")
  }
  epoch = as.integer(n_in_interval(unit, sample_rate = 1))
  counts = acti_calculate_counts(
    data,
    epoch = epoch,
    verbose = verbose
  )
  counts = counts %>%
    dplyr::rename(HEADER_TIME_STAMP = time, AC = counts) %>%
    dplyr::select(HEADER_TIME_STAMP, AC)
  counts
}

#' @export
#' @rdname acti_calculate_measures
acti_calculate_fast_mims = function(
  data,
  unit = "1 min",
  dynamic_range = NULL,
  sample_rate = NULL,
  allow_truncation = TRUE,
  ensure_all_time = TRUE,
  verbose = TRUE,
  ...) {
  args = list(data,
              ...,
              verbose = verbose,
              dynamic_range = dynamic_range)
  output_mims_per_axis = FALSE
  if ("output_mims_per_axis" %in% names(args)) {
    output_mims_per_axis = args$output_mims_per_axis
    args$output_mims_per_axis = NULL
  }
  data = do.call(mims_default_processing, args = args)
  data = acti_calculate_auc(
    data, unit = unit,
    sample_rate = sample_rate,
    allow_truncation = allow_truncation,
    ensure_all_time = ensure_all_time,
    verbose = verbose
  )
  colnames(data) = sub("AUC", "MIMS_UNIT", colnames(data))
  if (!output_mims_per_axis) {
    data = data[, c("HEADER_TIME_STAMP", "MIMS_UNIT")]
  }
  data
}

#' @export
#' @rdname acti_calculate_measures
acti_calculate_mims = function(
  data,
  unit = "1 min",
  dynamic_range = c(-6, 6),
  ensure_all_time = TRUE,
  ...) {
  HEADER_TIME_STAMP = NULL
  rm(list = "HEADER_TIME_STAMP")

  dynamic_range = get_dynamic_range(data, dynamic_range = dynamic_range)
  check = check_dynamic_range(data, dynamic_range = dynamic_range)
  if (!check) {
    msg = paste0("Dynamic range does not cover all the data in data",
                 ", please check data")
    warning(msg)
  }
  data = acti_standardize_data(
    data,
    subset_xyz = FALSE,
    colname_time = "HEADER_TIME_STAMP"
  )
  data = rename_time_stamp(data)
  if (!requireNamespace("MIMSunit", quietly = TRUE)) {
    stop("MIMSunit package required for calculating MIMS")
  }
  data = MIMSunit::mims_unit(
    data,
    epoch = unit,
    dynamic_range = dynamic_range,
    ...)
  data = data %>% dplyr::mutate(
    HEADER_TIME_STAMP = lubridate::floor_date(HEADER_TIME_STAMP,
                                              unit = unit))
  data = join_all_time(data, unit, ensure_all_time)

  data
}

check_dynamic_range = function(data, dynamic_range = c(-6, 6)) {
  time = HEADER_TIME_STAMP = X = Y = Z = r = NULL
  rm(list = c("HEADER_TIME_STAMP", "X", "Y", "Z", "r", "time"))
  hdr = NULL

  dynamic_range = get_dynamic_range(data, dynamic_range)
  if (is.AccData(data)) {
    data = data$data
  }
  stopifnot(length(dynamic_range) == 2,
            is.numeric(dynamic_range))

  r = range(data[actibase::xyz], na.rm = TRUE)
  all(r >= dynamic_range[1] & r <= dynamic_range[2])
}

n_in_interval = function(epoch, sample_rate = NULL) {
  stopifnot(!is.null(sample_rate))
  epoch = strsplit(epoch, " ")[[1]]
  if (length(epoch) == 1) {
    token = 1
  } else {
    stopifnot(length(epoch) == 2)
    token = as.numeric(epoch[1])
    epoch = epoch[2]
  }
  epoch = sub("s$", "", trimws(epoch))
  epoch = match.arg(epoch, c("seconds", "minutes", "hours", "days"))
  multiplier = switch(epoch,
                      seconds = 1,
                      minutes = 60,
                      hours = 60*60,
                      days = 60*60*24)
  n = token * sample_rate * multiplier
  return(n)
}
