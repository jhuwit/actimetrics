# Apply Tudor–Locke sleep period detection

Delegates to
[`actigraph.sleepr::apply_tudor_locke()`](https://rdrr.io/pkg/actigraph.sleepr/man/apply_tudor_locke.html).
Input must be 60-second epoch data with activity counts and a `sleep`
state. Data from
[`acti_apply_cole_kripke()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
is accepted directly. Data labeled by
[`acti_apply_tudor_locke_diary()`](https://jhuwit.github.io/actimetrics/reference/acti_apply_tudor_locke_diary.md)
is also accepted: its logical `sleep` column is converted to the `S`/`W`
states expected downstream.

## Usage

``` r
acti_apply_tudor_locke(data, ...)
```

## Arguments

- data:

  Epoch-level data containing activity counts and sleep state.

- ...:

  Arguments passed to
  [`actigraph.sleepr::apply_tudor_locke()`](https://rdrr.io/pkg/actigraph.sleepr/man/apply_tudor_locke.html).

## Value

A data frame summarizing detected sleep periods.
