# Perform step count calculation in a separate Python environment

Perform step count calculation in a separate Python environment

## Usage

``` r
py_acti_calculate_forest(
  ...,
  pyenv_function = function() {
     reticulate::import("forest")
 },
  show = FALSE
)
```

## Arguments

- ...:

  arguments passed to \[acti_calculate_forest()\]

- pyenv_function:

  function that loads the \`forest\` Python package. By default, it uses
  \`reticulate::py_import("forest")\` to import the package.

- show:

  Logical, whether to show the standard output on the screen while the
  child process is running, passed to \[callr::r()\]

## Value

The output from \[acti_calculate_forest()\].

## Examples

``` r
if (FALSE) { # \dontrun{
  data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
  steps = py_acti_calculate_forest(data, sample_rate = 100)
} # }
```
