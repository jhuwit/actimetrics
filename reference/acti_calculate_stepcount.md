# Calculate Step Counts via `stepcount`

Use the `stepcount` package to estimate steps from raw accelerometer
data and summarize them to minute-level epochs (as opposed to 10s
default)

## Usage

``` r
acti_calculate_stepcount(
  data,
  sample_rate = NULL,
  ...,
  epoch = "1 minute",
  tz = NULL
)
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

  epoch to aggregate the data to, in seconds or a string such as
  `"1 minute"` (see
  [`actibase::acti_standardize_epoch()`](https://jhuwit.github.io/actibase/reference/acti_standardize_epoch.html));
  original output is at 10-seconds

- tz:

  Time zone of the returned times. `stepcount` reports local clock times
  without a time zone; by default they are given the time zone of
  `data$time` (so they line up with the input), or `"UTC"` when `data`
  is a file path. Set `tz` to the recording's time zone for file input.

## Value

A tibble with minute-level `time`, `steps`, and `walking` columns.

## Examples

``` r
# \donttest{
  # reticulate::py_require("stepcount==3.11.0", python_version = "3.10", action = "add")
  # sc = try({ reticulate::import("stepcount") })
  if (stepcount::have_stepcount()) {
    data = actiread::acti_read_gt3x(actiread::acti_example_gt3x())
    steps = acti_calculate_stepcount(data, sample_rate = 100)
    steps = acti_calculate_stepcount(data, model_type = "rf")
  }
#> Warning: Python version requirements cannot be changed after Python has been initialized.
#> * Python version request: '3.10' (from package:stepcount)
#> * Python version initialized: '3.13.17'
# }
```
