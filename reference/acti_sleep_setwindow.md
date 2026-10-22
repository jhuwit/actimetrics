# Identify a fixed daily sleep window

Identify a fixed daily sleep window

## Usage

``` r
acti_sleep_setwindow(data, start_hour = 22, end_hour = 8)
```

## Arguments

- data:

  A data frame containing timestamps.

- start_hour, end_hour:

  Start and end clock hours (0–24).

## Value

An `acti_sleep_guider` object.

## Examples

``` r
data <- actimetrics::acti_count_data
fixed_window <- acti_sleep_setwindow(data, start_hour = 22, end_hour = 8)
```
