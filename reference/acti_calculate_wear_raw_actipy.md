# Estimate Non-wear from Raw Accelerometry with the actipy Method

Detects non-wear from raw tri-axial acceleration with the
stationary-episode definition of Doherty et al. (2017), as implemented
in actipy's `detect_nonwear()` (Chan and Doherty). This is a standalone
port and does not require actipy or Python. Usually called through
[`acti_calculate_wear_raw()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_wear_raw.md).

## Usage

``` r
acti_calculate_wear_raw_actipy(
  data,
  window = 10,
  patience = 5400,
  sd_threshold = 0.015
)
```

## Arguments

- data:

  A `data.frame` of raw accelerometer data with a time column and `X`,
  `Y`, `Z` columns, or an `AccData` object. Data should be calibrated
  (e.g. with
  [`acti_calibrate()`](https://jhuwit.github.io/actimetrics/reference/calibrate.md)).

- window:

  Length, in seconds, of the windows used to test for stationarity.

- patience:

  Minimum span, in seconds, of a stationary run for it to be non-wear.

- sd_threshold:

  Standard deviation (g) below which an axis is considered still.

## Value

A `tibble` with one row per window: `time` (start of the window),
`stationary`, `nonwear`, and `wear`.

## Details

The signal is split into windows of `window` seconds, anchored at the
first sample. A window is stationary when the standard deviation of
every axis is below `sd_threshold`. A run of stationary windows is
non-wear when its span, from the start of its first window to the start
of its last window, is longer than `patience` seconds. Windows with
fewer than two samples (for example, during time gaps) are not
stationary.

The defaults are actipy's (10 seconds, 90 minutes, 15 mg). Doherty et
al. (2017) used 60 minutes and 13 mg
(`patience = 3600, sd_threshold = 0.013`). actipy sets samples to `NaN`
from the start of the first window to the start of the last window of a
run; this function labels whole windows, so the last window of a run is
labelled non-wear. actipy runs this step after low-pass filtering and
gravity calibration.

## References

Doherty A, et al. (2017). Large scale population assessment of physical
activity using wrist worn accelerometers: the UK Biobank study. PLoS ONE
12(2): e0169649.
[doi:10.1371/journal.pone.0169649](https://doi.org/10.1371/journal.pone.0169649)

Chan S, Doherty A. actipy: a Python package to process wearable sensor
data.
[doi:10.5281/zenodo.14514488](https://doi.org/10.5281/zenodo.14514488)

## See also

[`acti_calculate_wear_raw()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_wear_raw.md),
[`acti_calculate_wear_raw_ggir()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_wear_raw_ggir.md)

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
wear = acti_calculate_wear_raw_actipy(data, patience = 3000)
table(wear$wear)
#> 
#> FALSE  TRUE 
#>   360   720 
```
