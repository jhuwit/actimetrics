acti_standardize_actigraph.sleepr = function(data) {

  count = counts = vector.magnitude = timestamp = NULL
  rm(list = c("timestamp", "vector.magnitude", "counts", "count"))
  data = actibase::acti_standardise_data(data, subset_xyz = FALSE, check_xyz = FALSE)

  data = data %>% rename_timestamp()
  if (!"vector.magnitude" %in% names(data)) {
    if ("counts" %in% names(data)) {
      data = dplyr::mutate(data, vector.magnitude = counts)
    } else if ("count" %in% names(data)) {
      data = dplyr::mutate(data, vector.magnitude = count)
    }
  }
  # data = data[!is.na(data$timestamp) & !is.na(data$vector.magnitude), ]
  data = dplyr::select(data, timestamp, vector.magnitude)
  data
}
