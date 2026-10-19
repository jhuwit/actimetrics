#' Process all supported actigraphy files in a directory
#'
#' Files are read according to their extension, passed to [acti_process()], and
#' saved as individual RDS files in `outdir`. Supported extensions are GT3X,
#' CWA, GeneActiv BIN, and CSV, including `.gz` and `.xz` compressed suffixes
#' for the supported formats described below.
#'
#' @param directory Directory containing raw actigraphy files.
#' @param outdir Directory in which processed RDS files are saved. Created if
#'   needed.
#' @param verbose Logical; report progress for each file.  Failures are
#'   always reported with a warning.
#' @param ... Arguments passed to [acti_process()].
#' @return Invisibly, a character vector of paths to the saved RDS files.
#'   Files that failed are listed in its `failed` attribute: a named
#'   character vector of error messages, named by input file.
#'   Each RDS contains the processed data, with the raw reader header attached
#'   as the `header` attribute when available.
#' @export
acti_process_study = function(directory, outdir, verbose = TRUE, ...) {
  if (!dir.exists(directory)) {
    stop("`directory` must be an existing directory", call. = FALSE)
  }
  if (missing(outdir) || !assertthat::is.string(outdir) || !nzchar(outdir)) {
    stop("Please supply an output directory in `outdir`", call. = FALSE)
  }
  if (!dir.exists(outdir)) {
    dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(outdir)) {
    stop("Could not create `outdir`", call. = FALSE)
  }

  files = list.files(directory, full.names = TRUE, recursive = FALSE,
                     all.files = FALSE)
  files = files[!dir.exists(files)]
  lower_files = tolower(basename(files))
  suffixes = c(".gt3x", ".gt3x.gz", ".gt3x.xz",
               ".cwa", ".cwa.gz",
               ".bin", ".bin.gz", ".bin.xz",
               ".csv", ".csv.gz")
  types = c("gt3x", "gt3x", "gt3x", "cwa", "cwa",
            "bin", "bin", "bin", "csv", "csv")
  matched = vapply(lower_files, function(x) {
    idx = which(vapply(suffixes, function(suffix) endsWith(x, suffix),
                       logical(1)))
    if (length(idx)) idx[[1]] else NA_integer_
  }, integer(1))
  supported = !is.na(matched)
  files = files[supported]
  types = types[matched[supported]]
  saved = character()
  failed = character()

  for (i in seq_along(files)) {
    file = files[[i]]
    if (verbose) message("Processing ", basename(file))
    tryCatch({
      raw = switch(types[[i]],
        gt3x = read_gt3x_full_digits(file, verbose = verbose),
        cwa = actiread::acti_read_cwa(file, verbose = verbose),
        bin = actiread::acti_read_geneactiv(file, verbose = verbose),
        csv = readr::read_csv(file, show_col_types = FALSE,
                              progress = FALSE)
      )
      header = if (is.list(raw) && !is.data.frame(raw) &&
                   !is.null(raw$header)) raw$header else attr(raw, "header")
      processed = acti_process(raw, verbose = verbose, ...)
      if (!is.null(header)) attr(processed, "header") = header

      out_file = file.path(outdir, paste0(basename(file), ".rds"))
      saveRDS(processed, out_file)
      saved = c(saved, out_file)
    }, error = function(e) {
      if (verbose) message("Skipping ", basename(file), ": ", conditionMessage(e))
      failed[[file]] <<- conditionMessage(e)
    })
  }
  if (length(failed) > 0) {
    warning(length(failed), " of ", length(files), " file(s) failed to ",
            "process: ", paste(basename(names(failed)), collapse = ", "),
            "; see attr(<result>, \"failed\")", call. = FALSE)
  }
  attr(saved, "failed") = failed
  invisible(saved)
}
