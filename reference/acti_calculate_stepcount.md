# Calculate Step Counts via \`stepcount\`

Use the \`stepcount\` package to estimate steps from raw accelerometer
data and summarize them to minute-level epochs (as opposed to 10s
default)

## Usage

``` r
acti_calculate_stepcount(data, sample_rate = NULL, ...)
```

## Arguments

- data:

  A \`data.frame\`, \`AccData\` object, or GT3X file with \`X\`, \`Y\`,
  \`Z\`, and \`time\`

- sample_rate:

  Sample rate in Hz. If omitted, it is taken from the input object when
  available.

- ...:

  Additional arguments passed to \[stepcount::stepcount()\]

## Value

A tibble with minute-level \`time\`, \`steps\`, and \`walking\` columns.

## Examples

``` r
if (FALSE) { # \dontrun{
  reticulate::py_require("stepcount==3.11.0", python_version = "3.10", action = "add")
  sc = reticulate::import("stepcount")
  data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
  steps = acti_calculate_stepcount(data, sample_rate = 100)
} # }
```
