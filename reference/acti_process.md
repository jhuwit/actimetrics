# Process Count Data

Process Count Data

## Usage

``` r
acti_process(
  data,
  lfe_select = FALSE,
  method = c("choi", "troiano"),
  use_magnitude = TRUE,
  verbose = TRUE,
  ...
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

- verbose:

  print diagnostic messages. Either logical or integer, where

- ...:

  additional arguments to pass to `actigraph.sleepr` function

## Note

For `acti_process_gt3x`, the `...` argument are passed to
[`actiread::acti_read_gt3x()`](https://jhuwit.github.io/actiread/reference/acti_read_gt3x.html)
