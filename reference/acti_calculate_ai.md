# Calculate the Activity Index (AI)

Computes the Activity Index of Bai et al. (2016) from raw tri-axial
accelerometry. For each 1-second window \\t\\, with \\\sigma^2_m(t)\\
the variance of axis \\m \in \\X, Y, Z\\\\ over the samples in that
second, \$\$AI(t) = \sqrt{\frac{1}{3}\sum\_{m} \sigma^2_m(t)}.\$\$ The
per-second values are then summed within each `unit` (e.g. a minute).

## Usage

``` r
acti_calculate_ai(data, unit = "1 min", ensure_all_time = TRUE, verbose = TRUE)

acti_calculate_activity_index(
  data,
  unit = "1 min",
  ensure_all_time = TRUE,
  verbose = TRUE
)
```

## Arguments

- data:

  An object with columns `X`, `Y`, and `Z` and a time column, or an
  object of class `AccData`

- unit:

  length of time to sum the per-second AI over, passed to
  [`lubridate::floor_date()`](https://lubridate.tidyverse.org/reference/round_date.html)

- ensure_all_time:

  if `TRUE`, all times from the first to the last `unit` are in the
  output, even those with no input data

- verbose:

  print diagnostic messages

## Value

A `data.frame` (or `data.table` if `data` is one) with columns
`HEADER_TIME_STAMP` and `AI`.

## Details

This is the unadjusted index (sometimes written \\AI_0\\): it does not
subtract or normalise by the device's systematic noise variance
\\\bar{\sigma}^2_m\\, which the original definition estimates from a
stationary period. It differs from `AI_DEFINED` returned by
[`acti_calculate_mad()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_measures.md),
which takes the variances over the whole `unit` rather than summing
1-second values.

A 1-second variance needs at least two samples, so seconds with fewer
than two samples are `NA` and are skipped when summing; a `unit` with no
valid seconds is `NA`. Data sampled at under 2 Hz therefore give
all-`NA` AI (with a warning).

## References

Bai J, Di C, Xiao L, et al. (2016). An Activity Index for Raw
Accelerometry Data and Its Comparison with Other Activity Metrics. PLoS
ONE 11(8): e0160644.
[doi:10.1371/journal.pone.0160644](https://doi.org/10.1371/journal.pone.0160644)

## Examples

``` r
file = actiread::acti_example_gt3x()
res = actiread::acti_read_gt3x(file, verbose = FALSE)
ai = acti_calculate_ai(res[1:12000, ])
#> Running floor_sec on time
#> Summarizing the variance
#> Calculating AI
```
