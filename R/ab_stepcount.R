acti_calculate_stepcount = function(data,
                                    sample_rate = NULL,
                                    ...
) {
  rlang::check_installed("stepcount")
  data = acti_standardize_data(data, check_xyz = TRUE)
  if (!is.null(sample_rate)) {
    attr(data, "sample_rate") = sample_rate
  }
  assertthat::assert_that(
    assertthat::is.count(attr(data, "sample_rate"))
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
                              c("ssl_stepcounts_created",
                                get_transformations(data)
                              ),
                              prefix = "acti_stepcount",
                              add = FALSE)

  trans = get_transformations(sdata)
  sdata = sdata %>%
    dplyr::mutate(time = lubridate::floor_date(time, unit = "1 min")) %>%
    dplyr::group_by(time) %>%
    dplyr::summarise(steps = sum(steps, na.rm = TRUE)) %>%
    dplyr::ungroup()
  sdata = set_transformations(sdata, trans)
  sdata = set_transformations(sdata,
                              "steps_summarized_per_60s_epoch",
                              prefix = "acti_stepcount",
                              add = TRUE)

  sdata = sdata %>%
    dplyr::left_join(walking, by = "time")
  sdata = set_transformations(sdata,
                              "walking_column_joined",
                              prefix = "acti_stepcount",
                              add = TRUE)

  sdata = sdata %>%
    dplyr::mutate(steps = ifelse(!is.finite(steps), NA_integer_, steps))
  sdata
}

