summarize_to_minute = function(sdata, prefix) {
  steps = NULL
  rm(list = c("steps"))
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
                              prefix = prefix,
                              add = TRUE)
  sdata = sdata %>%
    dplyr::mutate(steps = ifelse(!is.finite(steps), NA_integer_, steps))
  sdata
}

#' Calculate Step Counts via Verisense
#'
#'
#' @param data A `data.frame`, `AccData` object, or GT3X file with `X`, `Y`,
#' `Z`, and `time`
#' @param resample_to_15hz resample data to 15Hz,
#' passed to [walking::estimate_steps_verisense()]
#' @param method parameters to estimate wlaking, either original or revised,
#' passed to [walking::estimate_steps_verisense()]
#' @param ... Additional arguments passed to [walking::estimate_steps_verisense()]
#'
#' @return A tibble with minute-level `time`, `steps` columns.
#' @export
#'
#' @examples
#' data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#' steps = acti_calculate_verisense(data)
acti_calculate_verisense = function(data,
                                    resample_to_15hz = TRUE,
                                    method = c("original", "revised"),
                                    ...
) {
  trans = get_transformations(data)

  sdata = walking::estimate_steps_verisense(
    data,
    resample_to_15hz = resample_to_15hz,
    ...,
    method = method
  )
  sdata = sdata %>% dplyr::as_tibble()

  sdata = set_transformations(sdata, get_transformations(data), add = FALSE)
  sdata = set_transformations(sdata,
                              paste0("verisense_", method, "_steps_estimated"),
                              prefix = "acti_calculate_verisense",
                              add = TRUE)

  sdata = summarize_to_minute(sdata, prefix = "acti_calculate_verisense")
  sdata
}



#' Calculate Step Counts via Oak/Forest
#'
#'
#' @param data A `data.frame`, `AccData` object, or GT3X file with `X`, `Y`,
#' `Z`, and `time`
#' @param ... Additional arguments passed to [walking::find_walking()]
#'
#' @return A tibble with minute-level `time`, `steps` columns.
#' @export
#'
#' @examples
#' if (reticulate::py_module_available("forest")) {
#'   data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#'   steps = acti_calculate_forest(data, sample_rate = 100)
#' }
acti_calculate_forest = function(data,
                                 ...
) {
  steps = NULL
  rm(list = c("steps"))
  trans = get_transformations(data)
  rlang::check_installed("walking")

  sdata = walking::estimate_steps_forest(
    data,
    ...
  )
  sdata = sdata %>% dplyr::as_tibble()

  sdata = set_transformations(sdata, get_transformations(data), add = FALSE)
  sdata = set_transformations(sdata,
                              paste0("forest_steps_estimated"),
                              prefix = "acti_calculate_forest",
                              add = TRUE)

  sdata = summarize_to_minute(sdata, prefix = "acti_calculate_forest")
  sdata

}


#' Perform step count calculation in a separate Python environment
#'
#' @param ... arguments passed to [acti_calculate_forest()]
#' @param pyenv_function function that loads the `forest` Python package.
#' By default, it uses `reticulate::py_import("forest")` to
#' import the package.
#'
#' @returns The output from [acti_calculate_forest()].
#' @export
#'
#' @examples
#' \dontrun{
#'   data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#'   steps = py_acti_calculate_forest(data, sample_rate = 100)
#' }
py_acti_calculate_forest = function(
    ...,
    pyenv_function = function() {
      reticulate::import("forest")
    }) {
  rlang::check_installed("callr")
  steps <- callr::r(
    func = function(..., pyenv_function) {
      args = list(...)
      pyenv_function()
      res = do.call(actimetrics::acti_calculate_forest, args = args)
    },
    show = TRUE,
    args = list(...,
                pyenv_function = pyenv_function)
  ) # Safely injects data into the process
}



#' Calculate Step Counts via Oak/Forest
#'
#'
#' @param data A `data.frame`, `AccData` object, or GT3X file with `X`, `Y`,
#' `Z`, and `time`
#' @param sample_rate Sample rate in Hz. If omitted, it is taken from the
#' input object when available.
#' @param ... Additional arguments passed to [walking::sdt_count_steps()]
#'
#' @return A tibble with minute-level `time`, `steps` columns.
#' @export
#'
#' @examples
#' data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#' steps = acti_calculate_sdt(data)
acti_calculate_sdt = function(data,
                              sample_rate = NULL,
                              ...) {
  data = acti_standardize_data(data, check_xyz = TRUE)
  if (!is.null(sample_rate)) {
    attr(data, "sample_rate") = sample_rate
  } else {
    if (is.null(attr(data, "sample_rate"))) {
      attr(data, "sample_rate") = get_sample_rate(data)
    }
  }

  sdata = walking::estimate_steps_sdt(
    data,
    sample_rate = attr(data, "sample_rate"),
    ...)
  sdata = sdata %>% dplyr::as_tibble()

  sdata = set_transformations(sdata, get_transformations(data), add = FALSE)
  sdata = set_transformations(sdata,
                              paste0("sdt_steps_estimated"),
                              prefix = "acti_calculate_sdt",
                              add = TRUE)

  sdata = summarize_to_minute(sdata, prefix = "acti_calculate_sdt")
  sdata
}
