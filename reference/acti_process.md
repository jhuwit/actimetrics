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
  min_required = 1368L,
  round_digits = NULL
)
```

## Arguments

- data:

  A `data.frame` from `acti_calculate_counts` that has columns `axis1-3`
  and `counts`

- lfe_select:

  Apply the Actigraph Low Frequency Extension filter. See
  [agcounts::calculate_counts](https://rdrr.io/pkg/agcounts/man/calculate_counts.html)

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

  print diagnostic messages. Either logical or integer, where higher
  values are higher levels of verbosity.

- ...:

  additional arguments to pass to `actigraph.sleepr` function

- min_required:

  Number of minutes required in a day to be called `included`. No day
  inclusion is run if `NULL`.

- round_digits:

  Number of decimal places `X`/`Y`/`Z` are rounded to (half away from
  zero) after resampling to 30Hz and before counting. The default `NULL`
  uses `3` for GT3X data (read with
  [`actiread::acti_read_gt3x()`](https://jhuwit.github.io/actiread/reference/acti_read_gt3x.html))
  and does not round other data. Use `NA` to never round.

## Value

A data frame containing activity counts and wear-time indicators.

## Details

To match ActiLife for GT3X files, a GT3X path is read with `digits = 8`
(unless `digits` is given in `...`), resampled, and then rounded to 3
digits. ActiLife rounds the scaled samples to 3 digits, half away from
zero. Reading at 8 digits and then rounding gives exactly those values,
but rounding values already read at 5 digits does not (e.g.
`0.1234996 -> 0.12350 -> 0.124`).

## Note

For `acti_process`, the `...` argument are passed to
[`actiread::acti_read_gt3x()`](https://jhuwit.github.io/actiread/reference/acti_read_gt3x.html)
