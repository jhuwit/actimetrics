# Process Count Data

Process Count Data

Process Count Data

## Usage

``` r
acti_calculate_counts(
  data,
  epoch = 60L,
  resample = TRUE,
  lfe_select = FALSE,
  verbose = TRUE,
  fix_first_second = TRUE,
  round_digits = NULL
)

acti_calculate_wear(
  data,
  method = c("choi", "troiano"),
  use_magnitude = TRUE,
  ...
)

acti_calculate_nonwear(
  data,
  method = c("choi", "troiano"),
  use_magnitude = TRUE,
  ...
)

acti_apply_cole_kripke(data)

acti_apply_sadeh(data, ...)
```

## Arguments

- data:

  A `data.frame` from `acti_calculate_counts` that has columns `axis1-3`
  and `counts`

- epoch:

  epoch length, either in seconds or a string such as `"1 min"` (see
  [`actibase::acti_standardize_epoch()`](https://jhuwit.github.io/actibase/reference/acti_standardize_epoch.html));
  must be a whole number of seconds. Default is 60 seconds. See
  [agcounts::calculate_counts](https://rdrr.io/pkg/agcounts/man/calculate_counts.html)

- resample:

  (recommended) resample the data to 30Hz using
  [actibase::acti_resample](https://jhuwit.github.io/actibase/reference/acti_resample.html)
  vs. using the resampling method from
  [agcounts::calculate_counts](https://rdrr.io/pkg/agcounts/man/calculate_counts.html).

- lfe_select:

  Apply the Actigraph Low Frequency Extension filter. See
  [agcounts::calculate_counts](https://rdrr.io/pkg/agcounts/man/calculate_counts.html)

- verbose:

  print diagnostic messages. Either logical or integer, where higher
  values are higher levels of verbosity.

- fix_first_second:

  Fix the first second bug in `agcounts`. Appends replicated data of the
  first record if the first record is not an "even" epoch (e.g. 60
  second epoch and data does not start at a 00 second).

- round_digits:

  If not `NULL`, the number of decimal places the `X`/`Y`/`Z` values are
  rounded to after resampling and before counting. Use `3` to match
  ActiLife, which rounds GT3X data to 3 decimals (half away from zero,
  so `0.0625` becomes `0.063`, unlike
  [`base::round()`](https://rdrr.io/r/base/Round.html)). Useful if the
  data were read with more digits. Default `NULL` does not round.

- method:

  Method for detecting non-wear, either "choi" or "troiano",
  corresponding to
  [`actigraph.sleepr::apply_choi()`](https://rdrr.io/pkg/actigraph.sleepr/man/apply_choi.html)
  or
  [`actigraph.sleepr::apply_troiano()`](https://rdrr.io/pkg/actigraph.sleepr/man/apply_troiano.html)

- use_magnitude:

  If `TRUE`, the magnitude of the vector (axis1, axis2, axis3) is used
  to measure activity; otherwise the axis1 value is used.

- ...:

  additional arguments to pass to `actigraph.sleepr` function

## Value

A `data.frame` of transformed data

A `data.frame` of transformed data with columns `axis1-3`, `counts`, and
`counts_log10`.

A `data.frame` of transformed data

## Details

The sampling frequency is only needed when `resample = FALSE`; it is
taken from the `sample_rate` attribute (or estimated from `time`).

`acti_calculate_wear()`, `acti_apply_cole_kripke()`, and
`acti_apply_sadeh()` require 60-second epochs. Cole–Kripke, Sadeh, and
`acti_calculate_wear(use_magnitude = FALSE)` score the vertical axis, so
`data` must contain `axis1`; vector-magnitude-only counts are an error.

## Note

This calls the downstream wear-processing helpers used by
`actigraph.sleepr`

## Examples

``` r

# \donttest{
path = actiread::acti_example_gt3x()
ac = actiread::acti_read_gt3x(path)
#> ℹ Filling zeros in data
#> ✔ Filled zeros in data
#> ℹ Timezone not applied to data
out = acti_calculate_counts(ac)
#> namespace 'agcounts' is already loaded so argument 'partial' will be ignored.
#> [1] "Creating Downsampled Data"
#> [1] "Filtering Data"
#> [1] "Trimming Data"
#> [1] "Getting data back to 10Hz for accumulation"
#> [1] "Summing epochs"
# }
data = actimetrics::acti_count_data
wear = actimetrics::acti_calculate_wear(data)
tro_wear = actimetrics::acti_calculate_wear(data, method = "troiano")
ck = actimetrics::acti_apply_cole_kripke(data)
tl = actimetrics::acti_apply_tudor_locke(ck)
sadeh = actimetrics::acti_apply_sadeh(ck)
```
