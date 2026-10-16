# Process all supported actigraphy files in a directory

Files are read according to their extension, passed to
[`acti_process()`](https://jhuwit.github.io/actimetrics/reference/acti_process.md),
and saved as individual RDS files in `outdir`. Supported extensions are
GT3X, CWA, GeneActiv BIN, and CSV, including `.gz` and `.xz` compressed
suffixes for the supported formats described below.

## Usage

``` r
acti_process_study(directory, outdir, verbose = TRUE, ...)
```

## Arguments

- directory:

  Directory containing raw actigraphy files.

- outdir:

  Directory in which processed RDS files are saved. Created if needed.

- verbose:

  Logical; report progress for each file. Failures are always reported
  with a warning.

- ...:

  Arguments passed to
  [`acti_process()`](https://jhuwit.github.io/actimetrics/reference/acti_process.md).

## Value

Invisibly, a character vector of paths to the saved RDS files. Files
that failed are listed in its `failed` attribute: a named character
vector of error messages, named by input file. Each RDS contains the
processed data, with the raw reader header attached as the `header`
attribute when available.
