
# require_axis1: the caller scores the vertical axis (Cole-Kripke, Sadeh,
# axis1-based non-wear), so axis1 cannot be approximated from vector magnitude.
acti_standardize_actigraph.sleepr = function(data, require_axis1 = FALSE,
                                             caller = "This function") {

  count = counts = vector.magnitude = timestamp = NULL
  rm(list = c("timestamp", "vector.magnitude", "counts", "count"))
  data = actibase::acti_standardise_data(data, subset_xyz = FALSE, check_xyz = FALSE)

  data = data |> rename_timestamp()
  mode(data$timestamp) = "double"
  if (require_axis1 && !"axis1" %in% names(data)) {
    stop(caller, " scores the vertical-axis counts and requires an `axis1` ",
         "column, which `data` does not have.  Vector-magnitude counts ",
         "cannot be substituted; use acti_calculate_counts(), which returns ",
         "`axis1`-`axis3`.", call. = FALSE)
  }

  if (!"vector.magnitude" %in% names(data)) {
    if ("counts" %in% names(data)) {
      data = dplyr::mutate(data, vector.magnitude = counts)
    } else if ("count" %in% names(data)) {
      data = dplyr::mutate(data, vector.magnitude = count)
    }
  }
  axes = paste0("axis", 1:3)
  if ("vector.magnitude" %in% names(data) &&
      !any(axes %in% colnames(data))) {
    # Only valid for magnitude-based scoring: actigraph.sleepr:::add_magnitude
    # recreates exactly vector.magnitude from these.  Axis-based callers set
    # require_axis1 and never reach this.
    data = data |>
      dplyr::mutate(
        axis1 = vector.magnitude/sqrt(3),
        axis2 = vector.magnitude/sqrt(3),
        axis3 = vector.magnitude/sqrt(3)
      )
  }
  # data = data[!is.na(data$timestamp) & !is.na(data$vector.magnitude), ]
  # data = dplyr::select(data, timestamp, vector.magnitude)
  data
}
