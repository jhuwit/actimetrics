# actimetrics 0.8.0

## Breaking changes

* `acti_apply_cole_kripke()`, `acti_apply_sadeh()`, and
  `acti_calculate_wear(use_magnitude = FALSE)` now error if `axis1` is
  missing. Both sleep algorithms score the vertical axis, so vector-magnitude
  counts are no longer silently converted with `axis1 = VM / sqrt(3)`.
* `acti_calculate_wear()` errors with an informative message unless the data
  are 60-second epochs (required by Choi and Troiano).
* Step summaries (`acti_calculate_stepcount()`, `acti_calculate_verisense()`,
  `acti_calculate_forest()`, `acti_calculate_sdt()`) now return `NA` for
  epochs where all values are missing (e.g. non-wear) rather than 0 steps;
  `walking` from `acti_calculate_stepcount()` is likewise `NA`.
* With `allow_truncation = TRUE`, `acti_calculate_auc()` and
  `acti_calculate_fast_mims()` mark an epoch with any out-of-range axis as
  `-0.01` (all axes and the total), as `MIMSunit` does, rather than adding
  the `-1` sentinel into the total.

## New features

* New `acti_process_study()` processes every supported raw file (GT3X, CWA,
  GENEActiv BIN, CSV) in a directory with `acti_process()` and saves RDS
  files. Failures are always reported with a warning and listed in the
  `failed` attribute of the result. CSV files are read with `readr`, which is
  now in Imports.
* `acti_apply_tudor_locke()` gains `sleep_col` to use a sleep-state column
  with another name (e.g. from `acti_apply_tudor_locke_diary()`).
* `acti_calculate_ai()` has its own documentation page describing the
  (noise-unadjusted) Activity Index of Bai et al. (2016).

## Bug fixes

* `acti_calculate_counts()` subsets to `time`/`X`/`Y`/`Z` before calling
  `agcounts`, whose start-of-record padding failed on data with extra
  columns (e.g. GENEActiv `light`/`temperature`).
* The first-second padding before `agcounts` keeps all columns, attributes,
  and the timezone, builds the padded times on an exact sample grid, and no
  longer re-prefixes the existing transformation history. It is kept by
  default alongside the upstream fix (bhelsel/agcounts#51), as it also avoids
  agcounts' duplicate zero-count rows and works with older `agcounts`.
* `acti_calculate_wear()` now passes `...` to `actigraph.sleepr` (arguments
  such as `min_period_len` were ignored) and is not affected by existing
  `wear` columns.
* `mims_default_extrapolation()`, `mims_default_interpolation()`, and
  `mims_default_filtering()` now record their transformations.
* `acti_calculate_ai()` skips 1-second windows with a single sample instead of
  making the whole epoch `NA`, and warns for data sampled under 2 Hz.
* `acti_calculate_verisense()` validates `method` with `match.arg()`, so the
  default is `"original"`.
* `acti_calculate_fast_mims()` uses the sample rate of the processed
  (100 Hz) data; a supplied `sample_rate` is ignored with a warning.
* A user-supplied `sample_rate` in `acti_calculate_measures()` is now passed
  through to the activity-count calculation, and a missing sample rate gives
  an informative error from `acti_calculate_counts(resample = FALSE)`.
* Epoch/unit strings such as `"30s"` and `"1min"` are parsed with
  `lubridate`, consistent with `lubridate::floor_date()`.
* `py_acti_calculate_stepcount()` and `py_acti_calculate_forest()` return
  their result visibly.
* Fixed the `aggregated_at_` transformation label and documentation of
  `verbose` and `lfe_select`.


# actimetrics 0.7.0

* Add sleep diary labeling for Tudor--Locke and adapt diary labels for
  `actigraph.sleepr::apply_tudor_locke()`.
* Declare `actigraph.sleepr` as an installation dependency for sleep wrappers.

* Fixing bug with `acti_calculate_mims` due to not subsetting `XYZ`.


# actimetrics 0.6.0

* Fixing `agcounts` bug from https://github.com/bhelsel/agcounts/issues/50.

# actimetrics 0.5.0

* Fixing issues with CRAN.
* Removing count from `globalVariables`.

# actimetrics 0.4.0

* Fixing multithreading with `SSQ_PARALLEL=0` before import for forest.

# actimetrics 0.3.0

* Stepcount can now pass in an epoch.

# actimetrics 0.2.0

* Initial CRAN submission.
* Moving sleep to `actisleep`
