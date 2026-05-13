
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![R-CMD-check](https://github.com/jhuwit/actimetrics/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/jhuwit/actimetrics/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/jhuwit/actimetrics/branch/main/graph/badge.svg)](https://codecov.io/gh/jhuwit/actimetrics?branch=main)
<!-- badges: end -->

# actimetrics

`actimetrics` provides helpers for actigraphy preprocessing, summary
statistics, count-based overlays, and MIMS-oriented processing.

Core entry points:

- `calculate_measures()` for summary metrics such as AI, MAD, MIMS, and
  AC
- `acti_calculate_counts()` and `acti_process()` for count and wear
  overlays
- `mims_default_processing()` for the default MIMS preprocessing chain
- `acti_calibrate()` for calibration through `agcounts`

## Installation

You can install `actimetrics` from GitHub with:

``` r
# install.packages("remotes")
remotes::install_github("jhuwit/actimetrics")
```

## Quick Start

``` r
library(actimetrics)
path <- actiread::acti_example_gt3x()
data <- actiread::acti_read_gt3x(path, verbose = FALSE)

counts <- acti_calculate_counts(data)
#> [1] "Creating Downsampled Data"
#> [1] "Filtering Data"
#> [1] "Trimming Data"
#> [1] "Getting data back to 10Hz for accumulation"
#> [1] "Summing epochs"
summary <- calculate_measures(
  data,
  calculate_mims = FALSE,
  calculate_ac = FALSE,
  flag_data = FALSE
)
#> Fixing Zeros with fix_zeros
#> Calculating ai0
#> Calculating MAD
#> Joining AI and MAD
processed <- mims_default_processing(data[1:6000, ])
#> Warning in get_dynamic_range(data, dynamic_range): No dynamic range found in
#> header, using data estimate
#> Running extrapolation
#> Running filtering
#> Registered S3 methods overwritten by 'signal':
#>   method         from   
#>   print.freqs    gsignal
#>   print.freqz    gsignal
#>   print.grpdelay gsignal
#>   plot.grpdelay  gsignal
#>   print.impz     gsignal
#>   print.specgram gsignal
#>   plot.specgram  gsignal
```
