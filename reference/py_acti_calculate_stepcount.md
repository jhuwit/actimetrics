# Perform step count calculation in a separate Python environment

Perform step count calculation in a separate Python environment

## Usage

``` r
py_acti_calculate_stepcount(
  ...,
  pyenv_function = function() {
     stepcount::py_require_stepcount()
 },
  show = FALSE
)
```

## Arguments

- ...:

  arguments passed to
  [`acti_calculate_stepcount()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_stepcount.md)

- pyenv_function:

  function that loads the `stepcount` Python package. By default, it
  uses `reticulate::py_import("stepcount")` to import the package. If
  this function has an `args` argument, the output of `pyenv_function`
  will be re-assigned to `args`.

- show:

  Logical, whether to show the standard output on the screen while the
  child process is running, passed to
  [`callr::r()`](https://callr.r-lib.org/reference/r.html)

## Value

The output from
[`acti_calculate_stepcount()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_stepcount.md).
A tibble with minute-level `time`, `steps`, and `walking` columns.

## Examples

``` r
if (FALSE) { # \dontrun{
  data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
  steps = py_acti_calculate_stepcount(data, sample_rate = 100)
} # }
```
