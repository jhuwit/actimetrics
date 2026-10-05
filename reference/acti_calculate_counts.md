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
  fix_first_second = TRUE
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

acti_apply_tudor_locke(data, ...)

acti_apply_sadeh(data, ...)
```

## Arguments

- data:

  A `data.frame` from `acti_calculate_counts` that has columns `axis1-3`
  and `counts`

- epoch:

  epoch length in seconds. Default is 60 seconds. See
  [`agcounts::calculate_counts()`](https://rdrr.io/pkg/agcounts/man/calculate_counts.html)

- resample:

  (recommended) resample the data to 30Hz using
  [actibase::acti_resample](https://jhuwit.github.io/actibase/reference/acti_resample.html)
  vs. using the resampling method from
  [agcounts::calculate_counts](https://rdrr.io/pkg/agcounts/man/calculate_counts.html).

- lfe_select:

  Apply the Actigraph Low Frequency Extension filter. See
  [`agcounts::calculate_counts()`](https://rdrr.io/pkg/agcounts/man/calculate_counts.html)
  higher values are higher levels of verbosity.

- verbose:

  print diagnostic messages. Either logical or integer, where

- fix_first_second:

  Fix the first second bug in `agcounts`. Appends replicated data of the
  first record if the first record is not an "even" epoch (e.g. 60
  second epoch and data does not start at a 00 second).

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
#> Downloading uv...
#> Done!
#> Error in fix_first_second_function(): argument "data" is missing, with no default
# }
data = actimetrics::acti_count_data
wear = actimetrics::acti_calculate_wear(data)
tro_wear = actimetrics::acti_calculate_wear(data, method = "troiano")
ck = actimetrics::acti_apply_cole_kripke(data)
tl = actimetrics::acti_apply_tudor_locke(ck)
sadeh = actimetrics::acti_apply_sadeh(ck)
```
