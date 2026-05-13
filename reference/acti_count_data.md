# Example Actigraphy/Activity Count Data

Example Actigraphy/Activity Count Data

## Usage

``` r
acti_count_data
```

## Format

A \`data.frame\` with the columns

- time:

  time at the minute level

- axis1:

  axis1 (Y) counts

- axis2:

  axis2 (X) counts

- axis3:

  axis3 (Z) counts

- counts:

  vector magnitude of all 3 axes column

This data was taken from running \[agcounts::calculate_counts\] via
\[acti_calculate_counts\] on \[actibase::acti_raw_data\].
