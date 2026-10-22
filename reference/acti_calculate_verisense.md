# Calculate Step Counts via Verisense

Calculate Step Counts via Verisense

## Usage

``` r
acti_calculate_verisense(
  data,
  resample_to_15hz = TRUE,
  method = c("original", "revised"),
  ...
)
```

## Arguments

- data:

  A `data.frame`, `AccData` object, or GT3X file with `X`, `Y`, `Z`, and
  `time`

- resample_to_15hz:

  resample data to 15Hz, passed to
  [`walking::estimate_steps_verisense()`](https://rdrr.io/pkg/walking/man/estimate_steps.html)

- method:

  parameters to estimate walking, either original or revised, passed to
  [`walking::estimate_steps_verisense()`](https://rdrr.io/pkg/walking/man/estimate_steps.html)

- ...:

  Additional arguments passed to
  [`walking::estimate_steps_verisense()`](https://rdrr.io/pkg/walking/man/estimate_steps.html)

## Value

A tibble with minute-level `time`, `steps` columns.

## Examples

``` r
data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#> ℹ Filling zeros in data
#> ✔ Filled zeros in data
#> ℹ Timezone not applied to data
steps = acti_calculate_verisense(data)
#> Finding Peak Locations
#> Thresholding Peak by VM Threshold
#> Thresholding Peak by Periodicity
#> Thresholding Peak by Similarity
#> Thresholding Peak by Continuity
```
