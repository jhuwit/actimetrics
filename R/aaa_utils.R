rename_timestamp = function(data) {
  timestamp = time = NULL
  rm(list = c("timestamp", "time"))
  if ("time" %in% colnames(data) && !"timestamp" %in% colnames(data)) {
    data = data %>% dplyr::rename(timestamp = time)
  }
  data
}

rename_time_stamp = function(data, colname_time = "HEADER_TIME_STAMP") {
  if ("time" %in% colnames(data) && !colname_time %in% colnames(data)) {
    colnames(data)[colnames(data) == "time"] = colname_time
  }
  data
}

remake_acc = function(data, hdr) {
  data <- list(
    data = data,
    freq = attr(data, "sample_rate"),
    header = hdr,
    missingness = attr(data, "missingness"))
  class(data) = "AccData"
  data
}
