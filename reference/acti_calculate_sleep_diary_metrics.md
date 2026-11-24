# Calculate sleep metrics from diary bed times

Scores each diary night from epoch-level sleep/wake data (e.g. from
[`acti_calculate_cole_kripke()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
or
[`acti_calculate_sadeh()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md))
using the diary's in-bed, sleep-onset, and out-of-bed times, as ActiLife
does when bed times are entered from a sleep diary.
[`acti_calculate_tudor_locke()`](https://jhuwit.github.io/actimetrics/reference/acti_apply_tudor_locke.md)
instead detects bed and onset times from the counts, so its latency is
always 0.

## Usage

``` r
acti_calculate_sleep_diary_metrics(
  data,
  diary,
  in_bed_col = "in_bed_time",
  onset_col = "onset_time",
  out_bed_col = "out_bed_time",
  epoch_seconds = NULL,
  check_times = TRUE,
  do_rounding = TRUE,
  rounder = c("round", "Round")
)
```

## Arguments

- data:

  Epoch-level data with a POSIXct `time` (or `timestamp`) column, a
  `sleep` column (`"S"`/`"W"`, or logical with `TRUE` for sleep), and
  `axis1` counts. A vector-magnitude column (`counts`,
  `vector.magnitude`, or `vm`) is optional and gives
  `activity_counts_vm`.

- diary:

  A data frame with one row per night and POSIXct in-bed and out-of-bed
  times, and optionally sleep-onset times. Without an onset column,
  onset is the in-bed time. An `index` column, if present, labels the
  nights and must be unique. Other columns are kept in the output.

- in_bed_col, onset_col, out_bed_col:

  Names of the diary in-bed, sleep-onset, and out-of-bed columns. Out of
  bed is exclusive: the epoch starting at `out_bed_time` is not in bed.

- epoch_seconds:

  Epoch length in seconds. If `NULL`, it is estimated from `time`. It
  must divide 60 seconds (e.g. 15, 30, or 60).

- check_times:

  If `TRUE`, every in-bed epoch must be in `data`, so that the diary
  times are on the epoch grid and there are no gaps.

- do_rounding:

  If `TRUE`, round `efficiency` and `ave_awakening` to 2 digits and the
  movement and fragmentation indices to 3 digits.

- rounder:

  `"round"` uses base [`round()`](https://rdrr.io/r/base/Round.html)
  (round half to even); `"Round"` rounds half away from zero, as
  ActiLife does.

## Value

A tibble with one row per diary night: the diary columns (`index`,
`in_bed_time`, `onset_time`, `out_bed_time`, and any others), then the
metrics below. Times are in minutes. The *sleep period* runs from
`onset_time` to `out_bed_time`.

- latency:

  Time from getting into bed to sleep onset.

- efficiency:

  100 \* `total_sleep_time` / `duration`.

- duration:

  Time in bed, from `in_bed_time` to `out_bed_time`.

- activity_counts, activity_counts_vm:

  Sum of `axis1` and of the vector magnitude (`NA` if absent) in the
  sleep period.

- nonzero_epochs:

  Sleep-period epochs with `axis1 > 0`.

- total_sleep_time:

  Sleep (`"S"`) time in the sleep period.

- wake_after_onset:

  Wake (`"W"`) time in the sleep period (WASO).

- nb_awakenings:

  Number of wake bouts in the sleep period, not counting a wake bout at
  onset.

- ave_awakening:

  Mean length of those wake bouts (0 if none).

- movement_index:

  Percent of sleep-period epochs with `axis1 > 0`.

- fragmentation_index:

  Percent of sleep bouts that are at most one minute long (0 if no
  sleep).

- sleep_fragmentation_index:

  `movement_index` + `fragmentation_index`.

## Examples

``` r
data = actimetrics::acti_count_data
ck = acti_calculate_cole_kripke(data)
diary = data.frame(
  in_bed_time = data$time[5],
  onset_time = data$time[10],
  out_bed_time = data$time[35]
)
acti_calculate_sleep_diary_metrics(ck, diary)
#> # A tibble: 1 × 17
#>   index in_bed_time         onset_time          out_bed_time        latency
#>   <int> <dttm>              <dttm>              <dttm>                <dbl>
#> 1     1 2019-09-17 18:44:00 2019-09-17 18:49:00 2019-09-17 19:14:00       5
#> # ℹ 12 more variables: efficiency <dbl>, duration <dbl>, activity_counts <dbl>,
#> #   activity_counts_vm <dbl>, nonzero_epochs <int>, total_sleep_time <dbl>,
#> #   wake_after_onset <dbl>, nb_awakenings <int>, ave_awakening <dbl>,
#> #   movement_index <dbl>, fragmentation_index <dbl>,
#> #   sleep_fragmentation_index <dbl>
```
