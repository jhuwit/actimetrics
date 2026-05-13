#' Process Count Daa
#'
#' @param data A `data.frame` from `acti_calculate_counts` that has
#' columns `axis1-3` and `counts`
#' @return A `data.frame` of transformed data
#' @note This calls [acti_check_data], [acti_calculate_distance], and
#' [acti_process_time]
#' @param verbose print diagnostic messages.  Either logical or integer, where
#' @param epoch epoch length in seconds.  Default is 60 seconds.
#' See [agcounts::calculate_counts]
#' @param lfe_select Apply the Actigraph Low Frequency Extension filter.
#' See [agcounts::calculate_counts]
#' higher values are higher levels of verbosity.
#' @export
#' @examples
#' path = system.file("extdata", "TAS1H30182785_2019-09-17.gt3x.gz",
#'                    package = "actibase")
#' ac = acti_read_gt3x(path, verbose = FALSE)
#' out = acti_calculate_counts(ac)
#'
#' @param method Method for detecting non-wear, either "choi" or "troiano",
#' corresponding to [actigraph.sleepr::apply_choi] or [actigraph.sleepr::apply_troiano]
#' @param ... additional arguments to pass to `actigraph.sleepr` function
#' @param use_magnitude  If `TRUE`, the magnitude of the vector
#' (axis1, axis2, axis3) is used to measure activity;
#' otherwise the axis1 value is used.
#' @export
#' @rdname acti_calculate_counts
acti_calculate_wear = function(data,
                             method = c("choi", "troiano"),
                             use_magnitude = TRUE,
                             ...) {
  time = timestamp = NULL
  rm(list = c("time", "timestamp"))
  data = data %>%
    dplyr::rename(timestamp = time)
  mode(data$timestamp) = "double"
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
  choi_nonwear = func(data)
  if (nrow(choi_nonwear) > 0) {
    choi_df = purrr::map2_df(
      # change for the end - not the last value
      choi_nonwear$period_start, choi_nonwear$period_end - 60L,
      function(from, to) {
        data.frame(timestamp = seq(from, to, by = 60L),
                   wear = FALSE)
      })
    choi_df = dplyr::left_join(data, choi_df) %>%
      tidyr::replace_na(list(wear = TRUE))
  } else {
    choi_df = data.frame(timestamp = unique(data$timestamp),
                         wear = TRUE)
  }

  choi_df = choi_df %>%
    dplyr::rename(time = timestamp) %>%
    dplyr::select(time, dplyr::contains("wear")) %>%
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
  timestamp = NULL
  rm(list = c("timestamp"))
  data = data %>% rename_timestamp()

  # https://actigraphcorp.my.site.com/support/s/article/What-does-the-Detect-Sleep-Periods-button-do-and-how-does-it-work
  ck = data %>%
    actigraph.sleepr::apply_cole_kripke()
  ck = ck %>%
    dplyr::rename(time = timestamp)
  trans = get_transformations(data)
  ck = set_transformations(ck, trans)
  ck = set_transformations(ck,
                           "cole_kripke_run",
                           prefix = "acti_apply_cole_kripke",
                           add = TRUE)
  ck
}

#' @export
#' @rdname acti_calculate_counts
acti_apply_tudor_locke = function(data, ...) {
  data = data %>% rename_timestamp()
  tl = data %>%
    actigraph.sleepr::apply_tudor_locke(...)
  trans = get_transformations(data)
  tl = set_transformations(tl, trans)
  tl = set_transformations(tl,
                           "tudor_locke_run",
                           prefix = "acti_apply_tudor_locke",
                           add = TRUE)
  tl
}

