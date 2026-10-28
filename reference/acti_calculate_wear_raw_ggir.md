# Estimate Non-wear from Raw Accelerometry with the GGIR Method

Detects non-wear and signal clipping from raw tri-axial acceleration
with the algorithm in GGIR (van Hees et al. 2011, 2013), as implemented
in GGIR's `detect_nonwear_clipping()` and `g.weardec()`. This is a
standalone port and does not require GGIR. Usually called through
[`acti_calculate_wear_raw()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_wear_raw.md).

## Usage

``` r
acti_calculate_wear_raw_ggir(
  data,
  sample_rate = NULL,
  medium_epoch = 900,
  long_epoch = 3600,
  approach = c("2023", "2013"),
  sd_threshold = 0.013,
  range_threshold = 0.15,
  dynamic_range = NULL,
  clip_threshold = NULL,
  wear_threshold = 2,
  clipping_threshold = 0.3,
  edge_correction = TRUE,
  filter_max_hours = NULL,
  filter_window = NULL,
  align_start = TRUE
)
```

## Arguments

- data:

  A `data.frame` of raw accelerometer data with a time column and `X`,
  `Y`, `Z` columns, or an `AccData` object. Data should be calibrated
  (e.g. with
  [`acti_calibrate()`](https://jhuwit.github.io/actimetrics/reference/calibrate.md))
  and regularly sampled.

- sample_rate:

  Sampling frequency (Hz). If `NULL`, taken from the `sample_rate`
  attribute of `data`.

- medium_epoch:

  Length, in seconds, of the epoch the output is reported in (GGIR
  `windowsizes[2]`).

- long_epoch:

  Length, in seconds, of the window used to evaluate non-wear (GGIR
  `windowsizes[3]`).

- approach:

  Non-wear window approach (GGIR `nonwear_approach`). `"2023"` (GGIR
  default) uses a forward-looking long window, evaluated on a subsample
  of `ceiling(sample_rate / 5)`, and labels every medium epoch it
  covers. `"2013"` uses a long window centred on each medium epoch and
  labels only that epoch.

- sd_threshold:

  Standard deviation (g) below which an axis is considered still. GGIR
  uses 0.013, or `1.2 * rmc.noise` for ad-hoc formats.

- range_threshold:

  Range (g) below which an axis is considered still (GGIR
  `nonwear_range_threshold`, in mg, divided by 1000). GGIR uses 0.15, or
  0.2 for Verisense devices.

- dynamic_range:

  Dynamic range of the device (g), e.g. `c(-8, 8)`. If `NULL`, it is
  taken from the attributes or header of `data` when available. Used to
  set `clip_threshold`.

- clip_threshold:

  Absolute acceleration (g) above which a sample is counted as clipped.
  Defaults to the dynamic range minus 0.5, or 7.5 when the dynamic range
  is unknown, as in GGIR.

- wear_threshold:

  Minimum number of axes that must be still for an epoch to be non-wear.
  Fixed at 2 in GGIR.

- clipping_threshold:

  Fraction of clipped samples above which an epoch is flagged as
  clipping. Fixed at 0.3 in GGIR.

- edge_correction:

  Should non-wear starting (ending) within the first (last) 3 hours of
  the recording be extended to the start (end)? GGIR
  `nonWearEdgeCorrection`.

- filter_max_hours, filter_window:

  If `filter_max_hours` is not `NULL`, non-wear bouts shorter than
  `filter_max_hours` hours occurring inside the clock window
  `filter_window = c(start_hour, end_hour)` are relabelled as wear (GGIR
  `nonwearFiltermaxHours` and `nonwearFilterWindow`). The window may
  wrap midnight, e.g. `c(22, 7)`.

- align_start:

  Should samples before the first clock time aligned to `medium_epoch`
  be dropped, as GGIR does? If `FALSE`, epochs start at the first
  sample.

## Value

A `tibble` with one row per medium epoch:

- `time`:

  Start of the epoch.

- `nonwear_score`:

  Number of axes (0–3) meeting the non-wear criteria (GGIR
  `nonwearscore`).

- `clipping_score`:

  Maximum fraction of clipped samples across axes (GGIR
  `clippingscore`).

- `nonwear`:

  Non-wear from the score (GGIR `r1`).

- `clipping`:

  Clipping (GGIR `r2`).

- `nonwear_additional`:

  Additional non-wear from the bout rules (GGIR `r3`).

- `wear`:

  `TRUE` if none of `nonwear`, `clipping`, or `nonwear_additional` is
  flagged.

## Details

For each medium epoch (default 15 minutes), a long window (default 60
minutes) is evaluated per axis. An axis is scored as non-wear when both
its standard deviation is below `sd_threshold` and its range is below
`range_threshold`. The non-wear score is the number of axes (0–3) that
meet both criteria, and an epoch is non-wear when the score is at least
`wear_threshold`. An epoch is clipped when more than
`clipping_threshold` of its samples on any axis exceed `clip_threshold`
(or, if any sample exceeds `1.5 * clip_threshold`, the whole epoch is
clipped). Short wear bouts surrounded by long non-wear bouts are then
relabelled as non-wear, following GGIR part 2.

GGIR reads files in chunks (24 hours for GT3X files) and scores each
chunk separately. With `approach = "2023"`, a window that starts in one
chunk cannot label epochs in the next, so GGIR's `nonwearscore` can be
lower for the first epochs after a chunk boundary. This function scores
the whole recording at once. GGIR also imputes time gaps before scoring;
this function does not.

## References

van Hees VT, et al. (2011). Estimation of daily energy expenditure in
pregnant and non-pregnant women using a wrist-worn tri-axial
accelerometer. PLoS ONE 6(7): e22922.
[doi:10.1371/journal.pone.0022922](https://doi.org/10.1371/journal.pone.0022922)

van Hees VT, et al. (2013). Separating movement and gravity components
in an acceleration signal and implications for the assessment of human
daily physical activity. PLoS ONE 8(4): e61691.
[doi:10.1371/journal.pone.0061691](https://doi.org/10.1371/journal.pone.0061691)

## See also

[`acti_calculate_wear_raw()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_wear_raw.md),
[`acti_calculate_wear_raw_actipy()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_wear_raw_actipy.md)

## Examples

``` r
n = 3 * 3600 * 10
time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + (seq_len(n) - 1) / 10
moving = rep(c(TRUE, FALSE, TRUE), each = n / 3)
set.seed(1)
data = data.frame(
  time = time,
  X = ifelse(moving, stats::rnorm(n, sd = 0.3), 0),
  Y = ifelse(moving, stats::rnorm(n, sd = 0.3), 0),
  Z = ifelse(moving, stats::rnorm(n, sd = 0.3), 1)
)
acti_calculate_wear_raw_ggir(data, sample_rate = 10)
#> # A tibble: 12 × 7
#>    time                nonwear_score clipping_score nonwear clipping
#>    <dttm>                      <dbl>          <dbl> <lgl>   <lgl>   
#>  1 2020-01-01 00:00:00             0              0 FALSE   FALSE   
#>  2 2020-01-01 00:15:00             0              0 FALSE   FALSE   
#>  3 2020-01-01 00:30:00             0              0 FALSE   FALSE   
#>  4 2020-01-01 00:45:00             0              0 FALSE   FALSE   
#>  5 2020-01-01 01:00:00             3              0 TRUE    FALSE   
#>  6 2020-01-01 01:15:00             3              0 TRUE    FALSE   
#>  7 2020-01-01 01:30:00             3              0 TRUE    FALSE   
#>  8 2020-01-01 01:45:00             3              0 TRUE    FALSE   
#>  9 2020-01-01 02:00:00             0              0 FALSE   FALSE   
#> 10 2020-01-01 02:15:00             0              0 FALSE   FALSE   
#> 11 2020-01-01 02:30:00             0              0 FALSE   FALSE   
#> 12 2020-01-01 02:45:00             0              0 FALSE   FALSE   
#> # ℹ 2 more variables: nonwear_additional <lgl>, wear <lgl>
```
