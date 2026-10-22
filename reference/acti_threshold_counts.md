# Classify activity counts using intensity thresholds

Applies count thresholds to a count-data set after verifying that its
timestamps have the requested, regular epoch. Thresholds must be
expressed in counts per `epoch` seconds. Published cut-points should
only be used at the epoch and placement for which they were developed.

## Usage

``` r
acti_threshold_counts(
  data,
  thresholds,
  labels,
  name = "activity_intensity",
  epoch = 60
)
```

## Arguments

- data:

  A data frame with `time` and `counts` columns.

- thresholds:

  Increasing numeric lower bounds for successive intensity categories,
  expressed in counts per `epoch` seconds.

- labels:

  Labels for the categories. There must be one more label than
  threshold.

- name:

  Name of the factor column to add to `data`.

- epoch:

  Required epoch, in seconds.

## Value

`data` with an ordered factor column named by `name`.

## Examples

``` r
counts <- data.frame(
  time = as.POSIXct("2020-01-01", tz = "UTC") + 60 * 0:2,
  counts = c(0, 3000, 5000)
)
acti_threshold_counts(
  counts,
  thresholds = c(2860, 3941),
  labels = c("sedentary", "light", "mvpa")
)
#>                  time counts activity_intensity
#> 1 2020-01-01 00:00:00      0          sedentary
#> 2 2020-01-01 00:01:00   3000              light
#> 3 2020-01-01 00:02:00   5000               mvpa
```
