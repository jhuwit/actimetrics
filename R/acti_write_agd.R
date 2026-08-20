#' Write ActiGraph Epoch Data to an AGD File
#'
#' Writes epoch-level axis counts to an SQLite-backed `.agd` file that can be
#' read by [actigraph.sleepr::read_agd()].  The AGD format stores time as .NET
#' ticks (100 ns since 0001-01-01), rather than as Unix time.
#'
#' @param data A data frame with a time column and three count columns.
#'   Time may be called `time`, `timestamp`, or `HEADER_TIMESTAMP`; count
#'   columns may be `axis1`--`axis3` or `X`--`Z`.
#' @param file Path for the new `.agd` file.
#' @param epoch_length Length of each epoch in seconds.  Defaults to `NULL`,
#'   in which case it is estimated as the median spacing between timestamps.
#' @param original_sample_rate Sample rate of the signal used to derive the
#'   counts.
#' @param settings Optional named character vector of additional ActiLife
#'   settings.  Entries supplied here replace the defaults.
#' @param overwrite Whether to replace an existing file.
#' @return `file`, invisibly.
#' @export
#' @examples
#' \dontrun{
#' counts <- read.csv("72310_counts.csv.gz")
#' acti_write_agd(counts, file, original_sample_rate = 80)
#' actigraph.sleepr::read_agd("7231060sec.agd")
#' }
acti_write_agd <- function(data,
                           file,
                           epoch_length = NULL,
                           original_sample_rate = NA_integer_,
                           settings = character(),
                           overwrite = FALSE) {
  rlang::check_installed("DBI")
  rlang::check_installed("RSQLite")
  rlang::check_installed("bit64")

  if (!is.data.frame(data)) {
    rlang::abort("`data` must be a data frame.")
  }
  if (!is.character(file) || length(file) != 1L || is.na(file) || !nzchar(file)) {
    rlang::abort("`file` must be one non-empty path.")
  }
  if (file.exists(file) && !isTRUE(overwrite)) {
    rlang::abort("`file` already exists; set `overwrite = TRUE` to replace it.")
  }

  if (!is.data.frame(data)) {
    rlang::abort("`data` must be a data frame.")
  }
  # time is now time
  data = actibase::acti_standardise_data(
    data,
    check_xyz = FALSE,
    subset_xyz = FALSE
  )
  axis_names <- if (all(paste0("axis", 1:3) %in% names(data))) {
    paste0("axis", 1:3)
  } else if (all(c("X", "Y", "Z") %in% names(data))) {
    c("X", "Y", "Z")
  } else {
    rlang::abort("`data` needs either `axis1`--`axis3` or `X`--`Z` count columns.")
  }

  time <- data$time
  if (!inherits(time, "POSIXt")) {
    # ActiGraph CSV exports use ISO-8601 timestamps, including fractional
    # seconds and a trailing UTC marker.  `as.POSIXct()` without a format
    # silently discards the time-of-day for that form.
    time <- as.POSIXct(time, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  }
  if (anyNA(time)) {
    rlang::abort("`data` contains missing or unparseable timestamps.")
  }
  if (anyDuplicated(time) || is.unsorted(as.numeric(time))) {
    rlang::abort("Timestamps must be unique and sorted ascending.")
  }
  if (is.null(epoch_length)) {
    if (length(time) < 2L) {
      rlang::abort("Cannot estimate `epoch_length` from fewer than two timestamps; supply it explicitly.")
    }
    epoch_length <- stats::median(diff(as.numeric(time)))
  }
  if (!is.numeric(epoch_length) || length(epoch_length) != 1L ||
      is.na(epoch_length) || epoch_length <= 0) {
    rlang::abort("`epoch_length` must be one positive number of seconds.")
  }
  axes <- data[axis_names]
  if (any(!vapply(axes, is.numeric, logical(1))) || anyNA(axes)) {
    rlang::abort("Count columns must be numeric and contain no missing values.")
  }
  names(axes) <- paste0("axis", 1:3)

  # Avoid double precision loss: construct ticks as signed 64-bit integers.
  ticks <- bit64::as.integer64(as.numeric(time)) * bit64::as.integer64(10000000) +
    bit64::as.integer64("621355968000000000")
  agd_data <- data.frame(dataTimestamp = ticks, axes, check.names = FALSE)

  defaults <- c(
    softwarename = "ActiLife",
    softwareversion = "6.13.6",
    finished = "true",
    filter = "Normal",
    epochlength = as.character(as.integer(epoch_length)),
    startdatetime = as.character(ticks[[1]]),
    stopdatetime = "0",
    `original sample rate` = as.character(original_sample_rate),
    epochcount = as.character(nrow(agd_data))
  )
  if (length(settings)) {
    if (is.null(names(settings)) || any(!nzchar(names(settings)))) {
      rlang::abort("`settings` must be a named vector.")
    }
    defaults[names(settings)] <- as.character(settings)
  }
  settings_data <- data.frame(
    settingID = seq_along(defaults),
    settingName = names(defaults),
    settingValue = unname(defaults),
    check.names = FALSE
  )

  if (file.exists(file)) {
    unlink(file)
  }
  db <- DBI::dbConnect(RSQLite::SQLite(), dbname = file)
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  DBI::dbExecute(db, "CREATE TABLE data (dataTimestamp INTEGER, axis1 REAL, axis2 REAL, axis3 REAL)")
  DBI::dbExecute(db, "CREATE TABLE sleep (sleepID INTEGER PRIMARY KEY, inBedTimestamp INTEGER, outBedTimestamp INTEGER, timeAsleep INTEGER, timeAwake INTEGER, awakenings INTEGER, wakeAfterOnset INTEGER, latency INTEGER, efficiency REAL, totalCounts INTEGER)")
  DBI::dbExecute(db, "CREATE TABLE awakenings (awakeningID INTEGER PRIMARY KEY, sleepID INTEGER, timestamp INTEGER, length INTEGER)")
  DBI::dbExecute(db, "CREATE TABLE filters (filterID INTEGER PRIMARY KEY, filterStartTimestamp INTEGER, filterStopTimestamp INTEGER)")
  DBI::dbExecute(db, "CREATE TABLE settings (settingID INTEGER PRIMARY KEY, settingName VARCHAR(64), settingValue VARCHAR(8192))")
  DBI::dbExecute(db, "CREATE TABLE crouterEpoch (dataTimestamp INTEGER, metRate REAL)")
  DBI::dbExecute(db, "CREATE TABLE crouterMinute (dataTimestamp INTEGER, metRate REAL)")
  DBI::dbExecute(db, "CREATE TABLE logDiaryTimes (id INTEGER PRIMARY KEY AUTOINCREMENT, onDateTimestamp BIGINT NOT NULL, offDateTimestamp BIGINT NOT NULL, category VARCHAR(8192) NULL)")
  DBI::dbWriteTable(db, "data", agd_data, append = TRUE)
  DBI::dbWriteTable(db, "settings", settings_data, append = TRUE)
  DBI::dbExecute(db, "CREATE INDEX IX_dataTimestamp ON data (dataTimestamp)")
  DBI::dbExecute(db, "CREATE INDEX IX_filterStartTimestamp ON filters (filterStartTimestamp)")
  DBI::dbExecute(db, "CREATE INDEX IX_filterStopTimestamp ON filters (filterStopTimestamp)")
  DBI::dbExecute(db, "CREATE INDEX IX_crouterEpochDataTimestamp ON crouterEpoch (dataTimestamp)")
  DBI::dbExecute(db, "CREATE INDEX IX_crouterMinuteDataTimestamp ON crouterMinute (dataTimestamp)")
  invisible(file)
}
