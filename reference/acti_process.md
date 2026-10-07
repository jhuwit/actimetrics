# Process Raw data to Counts

Process Raw data to Counts

## Usage

``` r
acti_process(
  data,
  lfe_select = FALSE,
  method = c("choi", "troiano"),
  use_magnitude = TRUE,
  calibrate = FALSE,
  verbose = TRUE,
  ...,
  min_required = 1368L
)
```

## Arguments

- data:

  A `data.frame` from `acti_calculate_counts` that has columns `axis1-3`
  and `counts`

- lfe_select:

  Apply the Actigraph Low Frequency Extension filter. See
  [`agcounts::calculate_counts()`](https://rdrr.io/pkg/agcounts/man/calculate_counts.html)
  higher values are higher levels of verbosity.

- method:

  Method for detecting non-wear, either "choi" or "troiano",
  corresponding to
  [`actigraph.sleepr::apply_choi()`](https://rdrr.io/pkg/actigraph.sleepr/man/apply_choi.html)
  or
  [`actigraph.sleepr::apply_troiano()`](https://rdrr.io/pkg/actigraph.sleepr/man/apply_troiano.html)

- use_magnitude:

  If `TRUE`, the magnitude of the vector (axis1, axis2, axis3) is used
  to measure activity; otherwise the axis1 value is used.

- calibrate:

  Logical. If `TRUE`, the data will be calibrated using
  [`acti_calibrate()`](https://jhuwit.github.io/actimetrics/reference/calibrate.md)

- verbose:

  print diagnostic messages. Either logical or integer, where

- ...:

  additional arguments to pass to `actigraph.sleepr` function

- min_required:

  Number of minutes required in a day to be called `included`. No day
  inclusion is run if `NULL`.

## Value

A data frame containing activity counts and wear-time indicators.

## Note

For `acti_process_gt3x`, the `...` argument are passed to
[`actiread::acti_read_gt3x()`](https://jhuwit.github.io/actiread/reference/acti_read_gt3x.html)
