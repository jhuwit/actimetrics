# actimetrics workflow

`actimetrics` bundles a small set of actigraphy helpers for raw
preprocessing, summary metrics, count overlays, and MIMS-oriented
processing.

## Read data

``` r

path <- actiread::acti_example_gt3x()
data <- actiread::acti_read_gt3x(path, verbose = FALSE)
data <- data[1:12000, ]
```

## Summary metrics

``` r

summary <- acti_calculate_measures(
  data,
  calculate_mims = FALSE,
  calculate_ac = FALSE,
  flag_data = FALSE
)
#> Fixing Zeros with fix_zeros
#> Calculating ai0
#> Calculating MAD
#> Joining AI and MAD
summary
#> # A tibble: 2 × 9
#>   time                   AI    SD  SD_t AI_DEFINED   MAD MEDAD mean_r ENMO_t
#>   <dttm>              <dbl> <dbl> <dbl>      <dbl> <dbl> <dbl>  <dbl>  <dbl>
#> 1 2019-09-17 18:40:00  23.2  1.87  1.85       1.33 1.09  0.630   1.65  0.688
#> 2 2019-09-17 18:41:00  22.9  1.54  1.53       1.08 0.853 0.552   1.69  0.708
```

## Counts and wear

``` r

counts <- acti_calculate_counts(data)
wear <- acti_calculate_nonwear(counts)
head(counts)
head(wear)
```

## MIMS preprocessing

``` r

processed <- mims_default_processing(data[1:6000, ], round_after_processing = TRUE)
#> Running extrapolation
#> Running filtering
head(processed)
#>     HEADER_TIME_STAMP     X Y     Z
#> 1 2019-09-17 18:40:00 0.000 0 0.000
#> 2 2019-09-17 18:40:00 0.000 0 0.003
#> 3 2019-09-17 18:40:00 0.000 0 0.012
#> 4 2019-09-17 18:40:00 0.000 0 0.033
#> 5 2019-09-17 18:40:00 0.001 0 0.070
#> 6 2019-09-17 18:40:00 0.001 0 0.127
```

## Calibration

Calibration uses the van Hees method as implemented by `agcounts`, which
is the same approach typically exposed through `GGIR`.

``` r

calibrated <- acti_calibrate(data)
get_transformations(calibrated)
```
