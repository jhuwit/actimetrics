rename_timestamp = function(data) {
  timestamp = time = NULL
  rm(list = c("timestamp", "time"))
  if ("time" %in% colnames(data) && !"timestamp" %in% colnames(data)) {
    data = data %>% dplyr::rename(timestamp = time)
  }
  data
}

remake_acc = function(df, hdr) {
  df <- list(
    data = df,
    freq = attr(df, "sample_rate"),
    header = hdr,
    missingness = attr(df, "missingness"))
  class(df) = "AccData"
}
