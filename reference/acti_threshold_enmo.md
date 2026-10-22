# Classify ENMO using activity-intensity thresholds

Applies thresholds to Euclidean Norm Minus One (ENMO) values after
checking the regular epoch in `time`. ENMO values must be in milli-g
(mg), as is conventional for published ENMO cut-points. The output of
[`acti_calculate_enmo()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_measures.md)
is in g; multiply `ENMO_t` by 1000 before using this function.

## Usage

``` r
acti_threshold_enmo(
  data,
  thresholds,
  labels,
  name = "activity_intensity",
  epoch,
  enmo = "enmo"
)
```

## Arguments

- data:

  A data frame with a `time` and an ENMO column.

- thresholds:

  Increasing numeric lower bounds for successive intensity categories,
  in mg.

- labels:

  Labels for the categories. There must be one more label than
  threshold.

- name:

  Name of the factor column to add to `data`.

- epoch:

  Required epoch, in seconds.

- enmo:

  Name of the ENMO column, in mg.

## Value

`data` with an ordered factor column named by `name`.
