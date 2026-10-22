# Convert a sleep guider to epoch-level sleep/wake labels

A guider defines the likely main sleep window; it is not a sleep/wake
classifier itself. This function applies GGIR's final overlap step to a
sustained-inactivity-bout (`sib`) classification. With the default
`"SPT"` rule, an entire SIB is sleep when any part overlaps the guider.
With `"TimeInBed"`, an SIB must be wholly inside the guider.

## Usage

``` r
acti_sleep_label(sib, guider, sleepwindow_type = c("SPT", "TimeInBed"))
```

## Arguments

- sib:

  Logical or 0/1 sustained-inactivity-bout classification at the same
  regular epochs as `guider$window`.

- guider:

  An `acti_sleep_guider` object.

- sleepwindow_type:

  Whether the guider approximates sleep-period time (`"SPT"`) or time in
  bed (`"TimeInBed"`).

## Value

A logical vector: `TRUE` for sleep and `FALSE` for wake.

## Examples

``` r
data <- actimetrics::acti_count_data
data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
guider <- acti_sleep_l5(data)
sib <- data$counts == 0
sleep <- acti_sleep_label(sib, guider)
```
