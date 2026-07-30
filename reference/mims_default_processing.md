# Default MIMS Pre-processing

Default MIMS Pre-processing

## Usage

``` r
mims_default_processing(
  data,
  use_extrapolation = TRUE,
  use_filtering = TRUE,
  verbose = TRUE,
  dynamic_range = NULL,
  round_after_processing = FALSE
)
```

## Arguments

- data:

  Data set of raw accelerometry values, usually time and X/Y/Z. Usually
  from
  [`actiread::acti_read_gt3x()`](https://jhuwit.github.io/actiread/reference/acti_read_gt3x.html)

- use_extrapolation:

  If `TRUE` the function will apply extrapolation algorithm to the input
  signal, otherwise it will skip extrapolation but only linearly
  interpolate the signal to 100Hz.

- use_filtering:

  If `TRUE` the function will apply bandpass filtering to the input
  signal, otherwise it will skip the filtering.

- verbose:

  print diagnostic messages

- dynamic_range:

  the dynamic ranges of the input signal. Passed to
  [`actimetrics::mims_default_extrapolation()`](https://jhuwit.github.io/actimetrics/reference/mims_default_extrapolation.md).
  Only needed if `use_extrapolation = TRUE`

- round_after_processing:

  Should the result be rounded to 3 decimal values after processing, to
  make similar to standard accelerometry?

## Value

A processed data set
