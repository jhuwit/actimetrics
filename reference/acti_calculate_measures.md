# Calculate Summary Measures from Raw Accelerometer Data

Calculate Summary Measures from Raw Accelerometer Data

## Usage

``` r
acti_calculate_measures(
  data,
  unit = "1 min",
  fix_zeros = TRUE,
  dynamic_range = NULL,
  calculate_mims = TRUE,
  calculate_ac = TRUE,
  flag_data = TRUE,
  flags = NULL,
  ensure_all_time = TRUE,
  verbose = TRUE,
  sample_rate = NULL,
  ...
)

acti_calculate_ai(
  data,
  unit = "1 min",
  ensure_all_time = TRUE,
  verbose = FALSE
)

acti_calculate_activity_index(
  data,
  unit = "1 min",
  ensure_all_time = TRUE,
  verbose = FALSE
)

acti_calculate_flags(data, unit = "1 min", ensure_all_time = TRUE)

acti_calculate_n_idle(data, unit = "1 min", ensure_all_time = TRUE)

acti_calculate_enmo(...)

acti_calculate_ai_defined(...)

acti_calculate_mad(
  data,
  unit = "1 min",
  ensure_all_time = TRUE,
  verbose = FALSE
)

acti_calculate_auc(
  data,
  unit = "1 min",
  sample_rate = NULL,
  allow_truncation = FALSE,
  ensure_all_time = TRUE,
  verbose = TRUE
)

acti_calculate_fast_mims(
  data,
  unit = "1 min",
  dynamic_range = NULL,
  sample_rate = NULL,
  allow_truncation = TRUE,
  ensure_all_time = TRUE,
  verbose = TRUE,
  ...
)

acti_calculate_mims(
  data,
  unit = "1 min",
  dynamic_range = c(-6, 6),
  ensure_all_time = TRUE,
  ...
)
```

## Arguments

- data:

  An object with columns \`X\`, \`Y\`, and \`Z\` or an object of class
  \`AccData\`

- unit:

  length of time to calculate measures over. a character string
  specifying a time unit or a multiple of a unit to be rounded to. Valid
  base units are \`second\`, \`minute\`, \`hour\`, \`day\`, \`week\`,
  \`month\`, \`bimonth\`, \`quarter\`, \`season\`, \`halfyear\`, and
  \`year\`. Arbitrary unique English abbreviations as in the
  \`lubridate::period()\` constructor are allowed.

- fix_zeros:

  Should \`actibase::acti_fill_zeros()\` be run before calculating the
  measures?

- dynamic_range:

  Dynamic range of the device, in gravity units

- calculate_mims:

  Should MIMS units be calculated?

- calculate_ac:

  Should Activity Counts from the \`agcounts\` package be calculated?

- flag_data:

  Should the downstream overlay \`flag_qc()\` be run? It will be
  executed after \`fix_zeros\` before any measure calculation

- flags:

  the flags to calculate, passed to the downstream overlay \`flag_qc()\`

- ensure_all_time:

  if \`TRUE\`, then all times from the first to last times will be in
  the output, even if data during that time was not in the input

- verbose:

  print diagnostic messages

- sample_rate:

  sample rate of data, if not specified in header of object

- ...:

  additional arguments to pass to \`MIMSunit::mims_unit()\`

- allow_truncation:

  truncate small values

## Value

A data set with the calculated features

## Examples

``` r
file = actiread::acti_example_gt3x()
res = actiread::acti_read_gt3x(file, verbose = FALSE)
res = res[1:12000, ]
measures = acti_calculate_measures(
  res,
  dynamic_range = NULL,
  calculate_mims = FALSE,
  calculate_ac = FALSE,
  flag_data = FALSE
)
#> Fixing Zeros with fix_zeros
#> Calculating ai0
#> Calculating MAD
#> Joining AI and MAD
auc = acti_calculate_auc(res)
#> Absolute values
#> Calculting trapezoids
#> Replacing first value as NA
#> Calculating AUCs
# \donttest{
mims = acti_calculate_mims(res, dynamic_range = NULL)
#> ================================================================================
# }
if (requireNamespace("data.table", quietly = TRUE)) {
   dt = data.table::as.data.table(res)
   out = acti_calculate_measures(dt, calculate_mims = FALSE, flag_data = FALSE,
     calculate_ac = FALSE)
}
#> Fixing Zeros with fix_zeros
#> Calculating ai0
#> Calculating MAD
#> Joining AI and MAD
```
