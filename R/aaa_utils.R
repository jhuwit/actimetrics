rename_timestamp = function(data) {
  timestamp = time = NULL
  rm(list = c("timestamp", "time"))
  if ("time" %in% colnames(data) && !"timestamp" %in% colnames(data)) {
    data = data |> dplyr::rename(timestamp = time)
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

# Resolve the sampling frequency once, with an error that explains what is
# missing and how to supply it, instead of a bare `stopifnot()`.
resolve_sample_rate = function(data, sample_rate = NULL,
                               caller = "This function") {
  tryCatch(
    get_sample_rate(data, sample_rate = sample_rate),
    error = function(e) {
      stop(
        caller, " needs the sampling frequency (Hz) of `data`, but it could ",
        "not be determined: ", conditionMessage(e), "\n",
        "Set it with `attr(data, \"sample_rate\") = <Hz>` or pass ",
        "`sample_rate` where available.",
        call. = FALSE
      )
    }
  )
}

# actibase renamed flag_qc_all() to acti_flag_qc_all() in 0.8.0; look the
# function up at run time so either version of actibase works
run_flag_qc_all = function(...) {
  exports = getNamespaceExports("actibase")
  fun = if ("acti_flag_qc_all" %in% exports) "acti_flag_qc_all" else "flag_qc_all"
  getExportedValue("actibase", fun)(...)
}
