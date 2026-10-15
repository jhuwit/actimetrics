# Tudor--Locke sleep periods --------------------------------------------------

.acti_sleep_tudor_locke_diary_sleep <- function(time, diary, diary_onset_col,
                                                 diary_wakeup_col) {
  assertthat::assert_that(
    is.data.frame(diary),
    all(c(diary_onset_col, diary_wakeup_col) %in% names(diary)),
    msg = paste0("`sleep_diary` must contain its selected onset and wakeup ",
                 "columns.")
  )
  onset <- diary[[diary_onset_col]]
  wakeup <- diary[[diary_wakeup_col]]
  assertthat::assert_that(
    inherits(onset, "POSIXt"), inherits(wakeup, "POSIXt"),
    !anyNA(onset), !anyNA(wakeup), all(wakeup > onset),
    msg = "Diary onset and wakeup columns must be complete POSIXct times with wakeup after onset."
  )
  sleep <- rep(FALSE, length(time))
  for (i in seq_len(nrow(diary))) {
    sleep <- sleep | (time >= onset[i] & time < wakeup[i])
  }
  sleep
}

#' Apply a sleep diary to epoch data for Tudor--Locke
#'
#' Adds a logical sleep column to epoch data from diary onset and wakeup times.
#' The result can be passed to [acti_apply_tudor_locke()] when it also has
#' activity counts and represents 60-second epochs. The wrapper converts the
#' logical diary labels to the `S`/`W` states required downstream.
#'
#' @param data Epoch-level data containing a POSIXct timestamp column.
#' @param sleep_diary A data frame with POSIXct sleep onset and wakeup columns.
#'   Each interval may span midnight; multiple days are supported.
#' @param time_col Name of the POSIXct timestamp column in `data`.
#' @param diary_onset_col Name of the diary onset column.
#' @param diary_wakeup_col Name of the diary wakeup column.
#' @param sleep_col Name of the logical sleep column to add or replace.
#' @return `data` with a logical `sleep_col`, `TRUE` from onset (inclusive) to
#'   wakeup (exclusive).
#' @export
acti_apply_tudor_locke_diary <- function(data, sleep_diary, time_col = "time",
                                         diary_onset_col = "onset",
                                         diary_wakeup_col = "wakeup",
                                         sleep_col = "sleep") {
  assertthat::assert_that(
    is.data.frame(data), time_col %in% names(data),
    inherits(data[[time_col]], "POSIXt"), !anyNA(data[[time_col]]),
    msg = "`data` must contain a complete POSIXct time column."
  )
  data[[sleep_col]] <- .acti_sleep_tudor_locke_diary_sleep(
    time = data[[time_col]], diary = sleep_diary,
    diary_onset_col = diary_onset_col,
    diary_wakeup_col = diary_wakeup_col
  )
  data
}
