# Apply a sleep diary to epoch data for Tudor–Locke

Adds a logical sleep column to epoch data from diary onset and wakeup
times. The result can be passed to
[`acti_apply_tudor_locke()`](https://jhuwit.github.io/actimetrics/reference/acti_apply_tudor_locke.md)
when it also has activity counts and represents 60-second epochs. The
wrapper converts the logical diary labels to the `S`/`W` states required
downstream.

## Usage

``` r
acti_apply_tudor_locke_diary(
  data,
  sleep_diary,
  time_col = "time",
  diary_onset_col = "onset",
  diary_wakeup_col = "wakeup",
  sleep_col = "sleep"
)
```

## Arguments

- data:

  Epoch-level data containing a POSIXct timestamp column.

- sleep_diary:

  A data frame with POSIXct sleep onset and wakeup columns. Each
  interval may span midnight; multiple days are supported.

- time_col:

  Name of the POSIXct timestamp column in `data`.

- diary_onset_col:

  Name of the diary onset column.

- diary_wakeup_col:

  Name of the diary wakeup column.

- sleep_col:

  Name of the logical sleep column to add or replace.

## Value

`data` with a logical `sleep_col`, `TRUE` from onset (inclusive) to
wakeup (exclusive).
