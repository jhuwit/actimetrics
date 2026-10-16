# AGENTS.md

Notes for agents working on `actimetrics`.

## agcounts and the “first second” padding

[`acti_calculate_counts()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
calls
[`agcounts::calculate_counts()`](https://rdrr.io/pkg/agcounts/man/calculate_counts.html).
When the data do not start on an epoch boundary (e.g. first sample at
18:41:00.5 for 60 s epochs), agcounts pads the start itself. Before
agcounts PR \#51 (issue \#50) that padding was broken;
`fix_first_second_function()` (`R/ab_calculate_counts.R`) pads the data
*before* agcounts sees it, so the agcounts padding branch never runs
(`data_start == t1`).

### What agcounts PR \#51 fixed (merged 2026-10-15, agcounts 0.7.1 on GitHub main)

- Crash `wrong sign in 'by' argument` when the first sample was \< 1 s
  after the epoch boundary (it padded with
  `seq(data_start, t1 - 1, ...)`).
- A 1-second gap: padding stopped at `t1 - 1` instead of just before
  `t1`.

With PR \#51, counts are identical with and without our padding on the
example GT3X (starts at 0.5 s and 37.5 s past the minute were checked).

### What agcounts still gets wrong (as of PR \#51)

1.  **Extra columns**: its padding is
    `rbind(data.frame(time, X, Y, Z), raw)`, which errors
    (`numbers of columns of arguments do not match`) if `raw` has other
    columns (e.g. GENEActiv `light`, `temperature`). Only reachable with
    `acti_calculate_counts(resample = FALSE)`:
    [`actibase::acti_resample()`](https://jhuwit.github.io/actibase/reference/acti_resample.html)
    already drops non-XYZ columns.
2.  **Spurious zero-count rows** (agcounts issue \#42): its
    expected-timestamp grid is built from the *unaligned* first time, so
    it appends zero rows that duplicate epochs (39 real minutes -\> 78
    rows).
    [`acti_calculate_counts()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
    fixes this by flooring `time` to the epoch and summing.
3.  **Version**: Suggests requires `agcounts (>= 0.6.7)`; the CRAN
    release may not contain PR \#51.

### Why we keep `fix_first_second = TRUE` as the default

Padding first avoids all three: agcounts sees aligned data, so neither
its padding (`rbind`) nor its unaligned timestamp grid is used,
regardless of the installed agcounts version. Our padding keeps all
columns and attributes, uses an exact sample grid from the epoch start,
and keeps the timezone.

[`acti_calculate_counts()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
also runs `acti_standardize_data(subset_xyz = TRUE)` first, so agcounts
only ever sees `time`/`X`/`Y`/`Z` (this also maps names like
`TIME`/`HEADER_TIME_STAMP` and lower-case `x`). That fixes (1) even with
`fix_first_second = FALSE`, and keeps the `sample_rate` and
`transformations` attributes. It does not fix (2) or (3), which is why
the padding stays.

Do not remove the floor-and-sum step after
[`agcounts::calculate_counts()`](https://rdrr.io/pkg/agcounts/man/calculate_counts.html)
or the padding without re-checking these cases.
