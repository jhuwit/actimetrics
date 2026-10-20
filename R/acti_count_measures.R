#' Process Count Data
#'
#' @param data A `data.frame` from `acti_calculate_counts` that has
#' columns `axis1-3` and `counts`
#' @return A `data.frame` of transformed data
#' @note This calls the downstream wear-processing helpers used by
#' `actigraph.sleepr`
#' @param method Method for detecting non-wear, either "choi" or "troiano",
#' corresponding to `actigraph.sleepr::apply_choi()` or
#' `actigraph.sleepr::apply_troiano()`
#' @param ... additional arguments to pass to `actigraph.sleepr` function
#' @param use_magnitude  If `TRUE`, the magnitude of the vector
#' (axis1, axis2, axis3) is used to measure activity;
#' otherwise the axis1 value is used.
#' @details `acti_calculate_wear()`, `acti_apply_cole_kripke()`, and
#' `acti_apply_sadeh()` require 60-second epochs.  Cole--Kripke, Sadeh, and
#' `acti_calculate_wear(use_magnitude = FALSE)` score the vertical axis, so
#' `data` must contain `axis1`; vector-magnitude-only counts are an error.
#' @export
#' @rdname acti_calculate_counts
#' @examples
#' data = actimetrics::acti_count_data
#' wear = actimetrics::acti_calculate_wear(data)
#' tro_wear = actimetrics::acti_calculate_wear(data, method = "troiano")
#' ck = actimetrics::acti_apply_cole_kripke(data)
#' tl = actimetrics::acti_apply_tudor_locke(ck)
#' sadeh = actimetrics::acti_apply_sadeh(ck)
acti_calculate_wear = function(data,
                               method = c("choi", "troiano"),
                               use_magnitude = TRUE,
                               ...) {
  timestamp = time = wear = NULL
  rm(list = c("timestamp", "time", "wear"))
  rlang::check_installed("actigraph.sleepr")
  data = acti_standardize_actigraph.sleepr(
    data,
    require_axis1 = !use_magnitude,
    caller = "acti_calculate_wear(use_magnitude = FALSE)"
  )
  check_60s_epochs(data$timestamp, caller = "acti_calculate_wear()")

  method = match.arg(method)
  func = switch(method,
                choi = function(x, ...) actigraph.sleepr::apply_choi(
                  x,
                  use_magnitude = use_magnitude,
                  ...),
                troiano = function(x, ...) actigraph.sleepr::apply_troiano(
                  x,
                  use_magnitude = use_magnitude,
                  ...)
  )
  choi_nonwear = func(data, ...)
  if (nrow(choi_nonwear) > 0) {
    choi_df = purrr::map2_df(
      # change for the end - not the last value
      choi_nonwear$period_start, choi_nonwear$period_end - 60L,
      function(from, to) {
        data.frame(timestamp = seq(from, to, by = 60L),
                   wear = FALSE)
      })
    choi_df = dplyr::left_join(
      dplyr::select(data, timestamp), choi_df, by = "timestamp") |>
      tidyr::replace_na(list(wear = TRUE))
  } else {
    choi_df = data.frame(timestamp = unique(data$timestamp),
                         wear = TRUE)
  }

  choi_df = choi_df |>
    dplyr::rename(time = timestamp) |>
    dplyr::select(time, wear) |>
    dplyr::as_tibble()

  trans = get_transformations(data)
  choi_df = set_transformations(choi_df, trans)
  choi_df = set_transformations(choi_df,
                                paste0(method, "_wear_algorithm_run",
                                       ifelse(use_magnitude, "_using", "_notusing"),
                                       "_magnitude"),
                                prefix = "acti_calculate_wear",
                                add = TRUE)
  choi_df
}

#' @export
#' @rdname acti_calculate_counts
acti_calculate_nonwear = acti_calculate_wear



#' @export
#' @rdname acti_calculate_counts
acti_apply_cole_kripke = function(data) {
  rlang::check_installed("actigraph.sleepr")
  timestamp = NULL
  rm(list = c("timestamp"))
  data = acti_standardize_actigraph.sleepr(
    data, require_axis1 = TRUE, caller = "acti_apply_cole_kripke()")

  # https://actigraphcorp.my.site.com/support/s/article/What-does-the-Detect-Sleep-Periods-button-do-and-how-does-it-work
  ck = data |>
    actigraph.sleepr::apply_cole_kripke()
  ck = restore_count_column(ck, data)
  ck = ck |>
    dplyr::rename(time = timestamp)
  trans = get_transformations(data)
  ck = set_transformations(ck, trans)
  ck = set_transformations(ck,
                           "cole_kripke_run",
                           prefix = "acti_apply_cole_kripke",
                           add = TRUE)
  ck
}

#' Apply Tudor--Locke sleep period detection
#'
#' Delegates to `actigraph.sleepr::apply_tudor_locke()`. Input must be
#' 60-second epoch data with activity counts and a `sleep` state. Data from
#' [acti_apply_cole_kripke()] is accepted directly. Data labeled by
#' [acti_apply_tudor_locke_diary()] is also accepted: its logical `sleep`
#' column is converted to the `S`/`W` states expected downstream.
#'
#' @param data Epoch-level data containing activity counts and sleep state.
#' @param ... Arguments passed to `actigraph.sleepr::apply_tudor_locke()`.
#' @param sleep_col Name of the sleep-state column in `data`, either logical
#'   (as from [acti_apply_tudor_locke_diary()]) or `S`/`W`.  It is used as the
#'   `sleep` column expected by `actigraph.sleepr`.
#' @return A data frame summarizing detected sleep periods.
#' @export
acti_apply_tudor_locke = function(data, ..., sleep_col = "sleep") {
  rlang::check_installed("actigraph.sleepr")
  assertthat::assert_that(assertthat::is.string(sleep_col))
  if (!sleep_col %in% names(data)) {
    stop("`data` has no sleep-state column `", sleep_col, "`; set ",
         "`sleep_col` or run acti_apply_cole_kripke() or ",
         "acti_apply_tudor_locke_diary() first.", call. = FALSE)
  }
  data$sleep = data[[sleep_col]]
  data = acti_standardize_actigraph.sleepr(data)
  if (is.logical(data$sleep)) {
    data$sleep = ifelse(data$sleep, "S", "W")
  }
  tl = data |>
    actigraph.sleepr::apply_tudor_locke(...)
  trans = get_transformations(data)
  tl = set_transformations(tl, trans)
  tl = set_transformations(tl,
                           "tudor_locke_run",
                           prefix = "acti_apply_tudor_locke",
                           add = TRUE)
  tl
}


#' @export
#' @rdname acti_calculate_counts
acti_apply_sadeh = function(data, ...) {
  rlang::check_installed("actigraph.sleepr")
  data = acti_standardize_actigraph.sleepr(
    data, require_axis1 = TRUE, caller = "acti_apply_sadeh()")
  tl = data |>
    actigraph.sleepr::apply_sadeh(...)
  tl = restore_count_column(tl, data)
  trans = get_transformations(data)
  tl = set_transformations(tl, trans)
  tl = set_transformations(tl,
                           "apply_sadeh_run",
                           prefix = "acti_apply_sadeh",
                           add = TRUE)
  tl
}

# actigraph.sleepr's Cole-Kripke and Sadeh scoring leave behind a `count`
# column of truncated/rescaled axis1 values used to score.  It is not a count,
# and it overwrites any `count` column in the input, so drop it and restore
# the input's column.
restore_count_column = function(scored, data) {
  scored$count = NULL
  if ("count" %in% names(data)) {
    scored$count = data$count
  }
  scored
}

check_60s_epochs = function(timestamp, caller = "This function") {
  if (length(timestamp) < 2L) {
    return(invisible(TRUE))
  }
  d = diff(as.numeric(timestamp))
  d = d[!is.na(d)]
  epoch = stats::median(d)
  if (!isTRUE(all.equal(epoch, 60))) {
    stop(caller, " requires 60-second epochs (the algorithms are defined ",
         "on 1-minute counts), but `data` has ", format(epoch),
         "-second epochs.  Use `acti_calculate_counts(epoch = 60)` or ",
         "aggregate the counts to 1 minute first.", call. = FALSE)
  }
  invisible(TRUE)
}
