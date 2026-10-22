# Identify a sleep window with HDCZA

Implements the HDCZA sleep-period-time guider for wrist accelerometry.
It finds prolonged periods of little change in the supplied z-axis
angle, joins interruptions shorter than an hour, and returns the longest
resulting block. The default threshold is the 0.2 degrees specified in
the GGIR guider documentation.

## Usage

``` r
acti_sleep_hdcza(
  data,
  epoch = "5 seconds",
  threshold = 0.2,
  ignore_invalid = FALSE,
  min_block_minutes = 30,
  max_gap_minutes = 60
)
```

## Arguments

- data:

  A data frame of raw accelerometer observations.

- epoch:

  Epoch used to average raw angles, passed to
  [`lubridate::floor_date()`](https://lubridate.tidyverse.org/reference/round_date.html).

- threshold:

  Maximum five-minute rolling median absolute angle change.

- ignore_invalid:

  Whether invalid observations are treated as movement; use `NA` to
  treat them as no movement.

- min_block_minutes:

  Minimum low-movement block duration.

- max_gap_minutes:

  Maximum interruption bridged between blocks.

## Value

An `acti_sleep_guider` object. `window` is the selected SPT guider;
`crude_window` retains all candidate blocks before choosing the longest.

## Examples

``` r
# \donttest{
# The bundled actiread recording contains raw X, Y, and Z acceleration.
raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
hdcza <- acti_sleep_hdcza(raw, epoch = "5 seconds")
# }
```
