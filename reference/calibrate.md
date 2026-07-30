# Calibrate Accelerometer Data using `agcounts`

This uses the van Hees calibration method typically exposed through
GGIR, implemented here via
[`agcounts::agcalibrate()`](https://rdrr.io/pkg/agcounts/man/agcalibrate.html).

## Usage

``` r
acti_calibrate(
  data,
  verbose = TRUE,
  fill_zeroes = TRUE,
  round_after_calibration = TRUE,
  ...
)
```

## Arguments

- data:

  Either a GT3X file, `AccData` object, or `data.frame` with `X/Y/Z` and
  `time`

- verbose:

  print diagnostic messages, higher number result in higher verbosity

- fill_zeroes:

  Should
  [`actibase::acti_fill_zeros()`](https://jhuwit.github.io/actibase/reference/acti_fill_zeros.html)
  be run before calculating the measures? This trims zero values from
  the beginning and the end of the time course using last observation
  carried forward behavior.

- round_after_calibration:

  Should the data be rounded after calibration? Will round to 3 digits

- ...:

  Additional arguments to pass to
  [`agcounts::agcalibrate()`](https://rdrr.io/pkg/agcounts/man/agcalibrate.html)

## Examples

``` r
if (FALSE) { # \dontrun{
  res = acti_calibrate(data = actiread::acti_example_gt3x())
} # }
```
