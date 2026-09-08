# Calculate Step Counts via `stepcount`

Use the `stepcount` package to estimate steps from raw accelerometer
data and summarize them to minute-level epochs (as opposed to 10s
default)

## Usage

``` r
acti_calculate_stepcount(data, sample_rate = NULL, ..., epoch = "1 minute")
```

## Arguments

- data:

  A `data.frame`, `AccData` object, or GT3X file with `X`, `Y`, `Z`, and
  `time`

- sample_rate:

  Sample rate in Hz. If omitted, it is taken from the input object when
  available.

- ...:

  Additional arguments passed to
  [`stepcount::stepcount()`](https://rdrr.io/pkg/stepcount/man/stepcount.html)

- epoch:

  epoch unit to aggregate the data to, passed to
  [`lubridate::floor_date()`](https://lubridate.tidyverse.org/reference/round_date.html),
  original output is at 10-seconds

## Value

A tibble with minute-level `time`, `steps`, and `walking` columns.

## Examples

``` r
# \donttest{
  reticulate::py_require("stepcount==3.11.0", python_version = "3.10", action = "add")
#> Error in reticulate::py_require("stepcount==3.11.0", python_version = "3.10",     action = "add"): Python version requirements cannot be changed after Python has been initialized.
#> * Python version request: '3.10'
#> * Python version initialized: '3.12.14'
  sc = reticulate::import("stepcount")
#> Error in py_module_import(module, convert = convert): ModuleNotFoundError: No module named 'stepcount'
#> Run `reticulate::py_last_error()` for details.
  data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
#> ℹ Filling zeros in data
#> ✔ Filled zeros in data
#> ℹ Timezone not applied to data
  steps = acti_calculate_stepcount(data, sample_rate = 100)
#> Warning: Python version requirements cannot be changed after Python has been initialized.
#> * Python version request: '3.10' (from package:stepcount)
#> * Python version initialized: '3.12.14'
#> Warning: stepcount_check() indicates the stepcount functions may not be  available, may need to run reticulate::py_install('stepcount', pip = TRUE)
#> Loading model...
#> Error in py_module_import(module, convert = convert): ModuleNotFoundError: No module named 'stepcount'
#> Run `reticulate::py_last_error()` for details.
  steps = acti_calculate_stepcount(data, model_type = "rf")
#> Warning: stepcount_check() indicates the stepcount functions may not be  available, may need to run reticulate::py_install('stepcount', pip = TRUE)
#> Loading model...
#> Error in py_module_import(module, convert = convert): ModuleNotFoundError: No module named 'stepcount'
#> Run `reticulate::py_last_error()` for details.
# }
```
