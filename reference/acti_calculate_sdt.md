# Calculate Step Counts via Oak/Forest

Calculate Step Counts via Oak/Forest

## Usage

``` r
acti_calculate_sdt(data, sample_rate = NULL, ...)
```

## Arguments

- data:

  A \`data.frame\`, \`AccData\` object, or GT3X file with \`X\`, \`Y\`,
  \`Z\`, and \`time\`

- sample_rate:

  Sample rate in Hz. If omitted, it is taken from the input object when
  available.

- ...:

  Additional arguments passed to \[walking::sdt_count_steps()\]

## Value

A tibble with minute-level \`time\`, \`steps\` columns.

## Examples

``` r
data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#> ℹ Filling zeros in data
#> ✔ Filled zeros in data
#> ℹ Timezone not applied to data
steps = acti_calculate_sdt(data)
#> Warning: Python version requirements cannot be changed after Python has been initialized.
#> * Python version request: '3.11' (from package:walking)
#> * Python version initialized: '3.12.13'
#> sdt completed
```
