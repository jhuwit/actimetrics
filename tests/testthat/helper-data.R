make_gap_signal = function() {
  time1 = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + 0:59
  time3 = as.POSIXct("2020-01-01 00:02:00", tz = "UTC") + 0:59
  data = tibble::tibble(
    time = c(time1, time3),
    X = c(rep(0, 60), rep(0.5, 60)),
    Y = c(rep(0.1, 60), rep(0.2, 60)),
    Z = c(rep(1, 60), rep(1.1, 60))
  )
  attr(data, "sample_rate") = 1
  data
}

make_flagged_signal = function() {
  data = make_gap_signal()
  data$flag_low = rep(c(0, 1), each = 60)
  data$X[1:5] = 0
  data$Y[1:5] = 0
  data$Z[1:5] = 0
  data
}

make_example_signal = function(n = 12000L) {
  if (!exists(".actimetrics_example_signal", envir = .GlobalEnv, inherits = FALSE)) {
    assign(
      ".actimetrics_example_signal",
      actiread::acti_read_gt3x(
        actiread::acti_example_gt3x(),
        verbose = FALSE
      ),
      envir = .GlobalEnv
    )
  }
  get(".actimetrics_example_signal", envir = .GlobalEnv)[seq_len(n), ]
}

make_regular_signal = function(n = 12000L) {
  time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
    seq(0, by = 0.01, length.out = n)
  data = tibble::tibble(
    time = time,
    X = sin(seq_len(n) / 10) / 10,
    Y = cos(seq_len(n) / 12) / 10,
    Z = rep(1, n)
  )
  attr(data, "sample_rate") = 100
  data
}

make_sleepr_epochs = function() {
  agd_file = system.file(
    "extdata",
    "GT3XPlus-RawData-Day01.agd",
    package = "actigraph.sleepr"
  )
  actigraph.sleepr::read_agd(agd_file) |>
    actigraph.sleepr::collapse_epochs(60)
}

make_accdata = function() {
  data = data.frame(
    X = c(0, 0.1, -0.1),
    Y = c(0, 0.1, -0.1),
    Z = c(1, 1.1, 0.9)
  )
  hdr = data.frame(
    Field = c("Acceleration Min", "Acceleration Max"),
    Value = c("-2", "2")
  )
  structure(
    list(
      data = data,
      header = hdr,
      original_header = list(),
      freq = 100,
      missingness = NULL
    ),
    class = "AccData"
  )
}

can_load_pkg = function(pkg) {
  isTRUE(tryCatch(requireNamespace(pkg, quietly = TRUE), error = function(e) FALSE))
}

can_run_agcounts = local({
  value = NULL
  function() {
    if (!is.null(value)) {
      return(value)
    }
    cache_dir = file.path(
      path.expand("~"),
      "Library/Caches/org.R-project.R/R/reticulate"
    )
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    if (file.access(cache_dir, 2) != 0) {
      value <<- FALSE
      return(value)
    }
    data = actiread::acti_read_gt3x(
      actiread::acti_example_gt3x(),
      verbose = FALSE
    )[1:12000, ]
    value <<- !inherits(
      suppressWarnings(suppressMessages(try(acti_calculate_counts(data), silent = TRUE))),
      "try-error"
    )
    value
  }
})
