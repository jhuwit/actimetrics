# Calculate Step Counts via Oak/Forest

Calculate Step Counts via Oak/Forest

## Usage

``` r
acti_calculate_forest(data, ...)
```

## Arguments

- data:

  A \`data.frame\`, \`AccData\` object, or GT3X file with \`X\`, \`Y\`,
  \`Z\`, and \`time\`

- ...:

  Additional arguments passed to \[walking::find_walking()\]

## Value

A tibble with minute-level \`time\`, \`steps\` columns.

## Examples

``` r
if (reticulate::py_module_available("forest")) {
  data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
  steps = acti_calculate_forest(data, sample_rate = 100)
}
#> Downloading uv...
#> Done!
```
