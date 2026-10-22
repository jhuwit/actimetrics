# Identify a low-activity window for no-night-wear protocols

Identify a low-activity window for no-night-wear protocols

## Usage

``` r
acti_sleep_notworn(data, min_block_minutes = 30, max_gap_minutes = 60)
```

## Arguments

- data:

  A data frame of regular activity epochs.

- min_block_minutes:

  Minimum duration of a low-activity block.

- max_gap_minutes:

  Maximum interruption bridged between blocks.

## Examples

``` r
data <- actimetrics::acti_count_data
data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
# `counts` is an epoch-level activity metric.
no_night_wear <- acti_sleep_notworn(data)
```
