# Changelog

## actimetrics (development version)

- [`acti_process()`](https://jhuwit.github.io/actimetrics/reference/acti_process.md)
  frees the raw data once counts are calculated, before non-wear
  detection and day inclusion.

- [`acti_calculate_stepcount()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_stepcount.md)
  (and
  [`py_acti_calculate_stepcount()`](https://jhuwit.github.io/actimetrics/reference/py_acti_calculate_stepcount.md))
  now return times in the input’s time zone. `stepcount` reports local
  clock times without a time zone, which were previously labelled UTC,
  shifting steps by the input’s UTC offset (e.g. one hour for British
  Summer Time). A new `tz` argument sets the time zone, which is needed
  for file input (default `"UTC"`).

- `epoch`/`unit` arguments are standardized with
  [`actibase::acti_standardize_epoch()`](https://jhuwit.github.io/actibase/reference/acti_standardize_epoch.html),
  so
  [`acti_calculate_counts()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
  accepts `epoch = "1 min"` and the measure functions accept numeric
  seconds or strings such as `"30s"`. `ensure_all_time = TRUE` no longer
  errors for units such as `"5 seconds"` or `"1 minute"`, and
  [`acti_calculate_mims()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_measures.md)
  no longer errors for units without a space such as `"1min"`.

- [`acti_calculate_ai()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_ai.md)
  and
  [`acti_calculate_mad()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_measures.md)
  now default to `verbose = TRUE`.

- [`acti_apply_cole_kripke()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md),
  [`acti_apply_sadeh()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md),
  and
  [`acti_apply_tudor_locke()`](https://jhuwit.github.io/actimetrics/reference/acti_apply_tudor_locke.md)
  no longer add a superfluous `vector.magnitude` column (a copy of
  `counts`) to their output.

- [`acti_apply_cole_kripke()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
  and
  [`acti_apply_sadeh()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
  no longer return the `count` column that `actigraph.sleepr` uses
  internally for scoring (`axis1` truncated and, for Cole-Kripke,
  divided by 100). It overwrote any `count` column in the input, which
  is now kept.

## actimetrics 0.9.0

CRAN release: 2026-10-20

- Works with both actibase 0.6.0 and 0.8.0:
  [`acti_calculate_measures()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_measures.md)
  uses
  [`acti_flag_qc_all()`](https://jhuwit.github.io/actibase/reference/acti_flag_qc.html)
  when actibase provides it and
  [`flag_qc_all()`](https://jhuwit.github.io/actibase/reference/acti_flag_qc.html)
  otherwise, since actibase 0.8.0 renames it.

### Breaking changes

- [`acti_process()`](https://jhuwit.github.io/actimetrics/reference/acti_process.md)
  and
  [`acti_process_study()`](https://jhuwit.github.io/actimetrics/reference/acti_process_study.md)
  now aim to match ActiLife for GT3X data: files are read with
  `digits = 8` (unless `digits` is given), resampled to 30Hz, then
  rounded to 3 digits half away from zero, as ActiLife does. Previously
  the data were read at 5 digits and not rounded, giving counts that
  differed from ActiLife by 1-3 in many epochs. Rounding 5-digit data is
  not a fix: it rounds twice and differs from ActiLife more often.
  Counts from GT3X files will change slightly.

### New features

- [`acti_calculate_counts()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
  and
  [`acti_process()`](https://jhuwit.github.io/actimetrics/reference/acti_process.md)
  gain `round_digits` to round `X`/`Y`/`Z` half away from zero (base
  [`round()`](https://rdrr.io/r/base/Round.html) rounds `0.0625` to
  `0.062`) after resampling and before counting. In
  [`acti_process()`](https://jhuwit.github.io/actimetrics/reference/acti_process.md),
  the default `NULL` uses 3 for GT3X data and no rounding otherwise;
  `NA` turns it off.

## actimetrics 0.8.0

### Breaking changes

- [`acti_apply_cole_kripke()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md),
  [`acti_apply_sadeh()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md),
  and `acti_calculate_wear(use_magnitude = FALSE)` now error if `axis1`
  is missing. Both sleep algorithms score the vertical axis, so
  vector-magnitude counts are no longer silently converted with
  `axis1 = VM / sqrt(3)`.
- [`acti_calculate_wear()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
  errors with an informative message unless the data are 60-second
  epochs (required by Choi and Troiano).
- Step summaries
  ([`acti_calculate_stepcount()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_stepcount.md),
  [`acti_calculate_verisense()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_verisense.md),
  [`acti_calculate_forest()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_forest.md),
  [`acti_calculate_sdt()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_sdt.md))
  now return `NA` for epochs where all values are missing
  (e.g. non-wear) rather than 0 steps; `walking` from
  [`acti_calculate_stepcount()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_stepcount.md)
  is likewise `NA`.
- With `allow_truncation = TRUE`,
  [`acti_calculate_auc()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_measures.md)
  and
  [`acti_calculate_fast_mims()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_measures.md)
  mark an epoch with any out-of-range axis as `-0.01` (all axes and the
  total), as `MIMSunit` does, rather than adding the `-1` sentinel into
  the total.

### New features

- New
  [`acti_process_study()`](https://jhuwit.github.io/actimetrics/reference/acti_process_study.md)
  processes every supported raw file (GT3X, CWA, GENEActiv BIN, CSV) in
  a directory with
  [`acti_process()`](https://jhuwit.github.io/actimetrics/reference/acti_process.md)
  and saves RDS files. Failures are always reported with a warning and
  listed in the `failed` attribute of the result. CSV files are read
  with `readr`, which is now in Imports.
- [`acti_apply_tudor_locke()`](https://jhuwit.github.io/actimetrics/reference/acti_apply_tudor_locke.md)
  gains `sleep_col` to use a sleep-state column with another name
  (e.g. from
  [`acti_apply_tudor_locke_diary()`](https://jhuwit.github.io/actimetrics/reference/acti_apply_tudor_locke_diary.md)).
- [`acti_calculate_ai()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_ai.md)
  has its own documentation page describing the (noise-unadjusted)
  Activity Index of Bai et al. (2016).

### Bug fixes

- [`acti_calculate_counts()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
  subsets to `time`/`X`/`Y`/`Z` before calling `agcounts`, whose
  start-of-record padding failed on data with extra columns
  (e.g. GENEActiv `light`/`temperature`).
- The first-second padding before `agcounts` keeps all columns,
  attributes, and the timezone, builds the padded times on an exact
  sample grid, and no longer re-prefixes the existing transformation
  history. It is kept by default alongside the upstream fix
  (bhelsel/agcounts#51), as it also avoids agcounts’ duplicate
  zero-count rows and works with older `agcounts`.
- [`acti_calculate_wear()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_counts.md)
  now passes `...` to `actigraph.sleepr` (arguments such as
  `min_period_len` were ignored) and is not affected by existing `wear`
  columns.
- [`mims_default_extrapolation()`](https://jhuwit.github.io/actimetrics/reference/mims_default_extrapolation.md),
  [`mims_default_interpolation()`](https://jhuwit.github.io/actimetrics/reference/mims_default_extrapolation.md),
  and
  [`mims_default_filtering()`](https://jhuwit.github.io/actimetrics/reference/mims_default_extrapolation.md)
  now record their transformations.
- [`acti_calculate_ai()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_ai.md)
  skips 1-second windows with a single sample instead of making the
  whole epoch `NA`, and warns for data sampled under 2 Hz.
- [`acti_calculate_verisense()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_verisense.md)
  validates `method` with
  [`match.arg()`](https://rdrr.io/r/base/match.arg.html), so the default
  is `"original"`.
- [`acti_calculate_fast_mims()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_measures.md)
  uses the sample rate of the processed (100 Hz) data; a supplied
  `sample_rate` is ignored with a warning.
- A user-supplied `sample_rate` in
  [`acti_calculate_measures()`](https://jhuwit.github.io/actimetrics/reference/acti_calculate_measures.md)
  is now passed through to the activity-count calculation, and a missing
  sample rate gives an informative error from
  `acti_calculate_counts(resample = FALSE)`.
- Epoch/unit strings such as `"30s"` and `"1min"` are parsed with
  `lubridate`, consistent with
  [`lubridate::floor_date()`](https://lubridate.tidyverse.org/reference/round_date.html).
- [`py_acti_calculate_stepcount()`](https://jhuwit.github.io/actimetrics/reference/py_acti_calculate_stepcount.md)
  and
  [`py_acti_calculate_forest()`](https://jhuwit.github.io/actimetrics/reference/py_acti_calculate_forest.md)
  return their result visibly.
- Fixed the `aggregated_at_` transformation label and documentation of
  `verbose` and `lfe_select`.

## actimetrics 0.7.0

- Add sleep diary labeling for Tudor–Locke and adapt diary labels for
  [`actigraph.sleepr::apply_tudor_locke()`](https://rdrr.io/pkg/actigraph.sleepr/man/apply_tudor_locke.html).

- Declare `actigraph.sleepr` as an installation dependency for sleep
  wrappers.

- Fixing bug with `acti_calculate_mims` due to not subsetting `XYZ`.

## actimetrics 0.6.0

- Fixing `agcounts` bug from
  <https://github.com/bhelsel/agcounts/issues/50>.

## actimetrics 0.5.0

- Fixing issues with CRAN.
- Removing count from `globalVariables`.

## actimetrics 0.4.0

CRAN release: 2026-09-17

- Fixing multithreading with `SSQ_PARALLEL=0` before import for forest.

## actimetrics 0.3.0

- Stepcount can now pass in an epoch.

## actimetrics 0.2.0

- Initial CRAN submission.
- Moving sleep to `actisleep`
