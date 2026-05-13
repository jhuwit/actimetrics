
acti_standardize_actigraph.sleepr = function(data) {

  count = counts = vector.magnitude = timestamp = NULL
  rm(list = c("timestamp", "vector.magnitude", "counts", "count"))
  data = actibase::acti_standardise_data(data, subset_xyz = FALSE, check_xyz = FALSE)

  data = data %>% rename_timestamp()
  mode(data$timestamp) = "double"

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
    # the actigraph.sleepr:::add_magnitude will recreate it anyway
    data = data %>%
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
