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

  arguments passed to
  [`acti_calculate_forest()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_forest.md)

- pyenv_function:

  function that loads the `forest` Python package. By default, it uses
  `reticulate::py_import("forest")` to import the package. If this
  function has an `args` argument, the output of `pyenv_function` will
  be re-assigned to `args`.

- show:

  Logical, whether to show the standard output on the screen while the
  child process is running, passed to
  [`callr::r()`](https://callr.r-lib.org/reference/r.html)

## Value

The output from
[`acti_calculate_forest()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_forest.md).

## Examples

``` r
# \donttest{
  Sys.setenv("SSQ_PARALLEL" = 0)
  data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#> ℹ Filling zeros in data
#> ✔ Filled zeros in data
#> ℹ Timezone not applied to data
  steps = py_acti_calculate_forest(data, sample_rate = 100)
#> Error in "get_result(output = out, options)": ! callr subprocess failed: could not start R, exited with non-zero status, has crashed or was killed
# }
```
