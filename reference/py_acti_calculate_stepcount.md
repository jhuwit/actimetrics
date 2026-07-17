# Perform step count calculation in a separate Python environment

Perform step count calculation in a separate Python environment

## Usage

``` r
py_acti_calculate_stepcount(
  ...,
  pyenv_function = function() {
     reticulate::import("stepcount")
 }
)
```

## Arguments

- ...:

  arguments passed to \[acti_calculate_stepcount()\]

- pyenv_function:

  function that loads the \`stepcount\` Python package. By default, it
  uses \`reticulate::py_import("stepcount")\` to import the package.

## Value

The output from \[acti_calculate_stepcount()\]. A tibble with
minute-level \`time\`, \`steps\`, and \`walking\` columns.

## Examples

``` r
if (FALSE) { # \dontrun{
  data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
  steps = py_acti_calculate_stepcount(data, sample_rate = 100)
} # }
```
