# Default MIMS worker functions

Default MIMS worker functions

## Usage

``` r
mims_default_extrapolation(data, dynamic_range = NULL)

mims_default_interpolation(data)

mims_default_filtering(data)
```

## Arguments

- data:

  data set of data, usually time and X/Y/Z. Usually from
  [`actiread::acti_read_gt3x()`](https://jhuwit.github.io/actiread/reference/acti_read_gt3x.html)

- dynamic_range:

  dynamic range of the data. Will be passed to
  [`actibase::get_dynamic_range()`](https://jhuwit.github.io/actibase/reference/get_dynamic_range.html)

## Value

A data set of data
