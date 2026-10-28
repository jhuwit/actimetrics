# actimetrics 0.10.0

## Internal

* Imports `actiread` with `except = "tzoffset_to_tz"`, so `actibase` can
  export `tzoffset_to_tz()` later without an import conflict.
* `GGIR` is no longer listed in `Suggests`; it was not used.
* Checks for `agcounts` and `stepcount` now use
  `requireNamespace(pkg, partial = TRUE)` instead of
  `rlang::check_installed()`/`rlang::is_installed()`, so their `.onLoad`
  hooks (which initialize Python via `reticulate`) do not run during the
  check. This fixes the CRAN NOTE in "checking dependencies in R code".

## New features

* New sleep-period-time guiders following the GGIR sleep definitions
  (implemented without calling GGIR): `acti_sleep_hdcza()`,
  `acti_sleep_hlrb()`, `acti_sleep_horangle()`, `acti_sleep_l5()`,
  `acti_sleep_notworn()`, `acti_sleep_setwindow()`, and
  `acti_sleep_diary()`, dispatched by `acti_sleep_guider()` (see
  `acti_sleep_guider_requirements()`).  `acti_sleep_sib()` detects sustained
  inactivity bouts, `acti_sleep_label()` and `acti_sleep_labels()` turn
  guiders into epoch-level sleep/wake labels, `acti_sleep_fuse_labels()`
  combines labels with STAPLE, and `acti_sleep_ensemble()` runs the whole
  pipeline from raw or epoch data.
* New activity-intensity classifiers: `acti_threshold_counts()` and
  `acti_threshold_enmo()` for user-supplied cut-points, and published
  cut-points in `acti_threshold_montoye()`, `acti_threshold_sasaki()`,
  `acti_threshold_romanzini()`, and `acti_threshold_hildebrand()` (with
  `acti_threshold_hildebrand_wrist()` and `acti_threshold_hildebrand_hip()`).
* New `acti_calculate_wear_raw()` estimates non-wear from raw tri-axial
  acceleration, implemented without calling GGIR or actipy.  Like
  `acti_calculate_wear()`, it takes a `method` argument and passes `...` to
  the method function:
  * `acti_calculate_wear_raw_ggir()` (`method = "ggir"`, default): the GGIR
    non-wear and clipping algorithm (van Hees et al. 2011, 2013), exposing
    GGIR's settings: the medium/long window sizes, the `"2023"` and `"2013"`
    approaches, the standard-deviation and range thresholds, the clipping
    threshold or dynamic range, edge correction, and the night-time short
    non-wear filter.
  * `acti_calculate_wear_raw_actipy()` (`method = "actipy"`): stationary
    episodes of Doherty et al. (2017), as in actipy's `detect_nonwear()`,
    with the window, patience, and standard-deviation threshold exposed.

  `acti_calculate_wear()` remains the count-based (Choi/Troiano) method.

## Bug fixes and other changes

* `acti_process()` frees the raw data once counts are calculated, before
  non-wear detection and day inclusion.

* `acti_calculate_stepcount()` (and `py_acti_calculate_stepcount()`) now
  return times in the input's time zone. `stepcount` reports local clock
  times without a time zone, which were previously labelled UTC, shifting
  steps by the input's UTC offset (e.g. one hour for British Summer Time).
  A new `tz` argument sets the time zone, which is needed for file input
  (default `"UTC"`).
* `epoch`/`unit` arguments are standardized with
  `actibase::acti_standardize_epoch()`, so `acti_calculate_counts()` accepts
  `epoch = "1 min"` and the measure functions accept numeric seconds or
  strings such as `"30s"`.  `ensure_all_time = TRUE` no longer errors for
  units such as `"5 seconds"` or `"1 minute"`, and `acti_calculate_mims()`
  no longer errors for units without a space such as `"1min"`.
* `acti_calculate_ai()` and `acti_calculate_mad()` now default to
  `verbose = TRUE`.
* `acti_apply_cole_kripke()`, `acti_apply_sadeh()`, and
  `acti_apply_tudor_locke()` no longer add a superfluous `vector.magnitude`
  column (a copy of `counts`) to their output.
* `acti_apply_cole_kripke()` and `acti_apply_sadeh()` no longer return the
  `count` column that `actigraph.sleepr` uses internally for scoring
  (`axis1` truncated and, for Cole-Kripke, divided by 100).  It overwrote
  any `count` column in the input, which is now kept.

# actimetrics 0.9.0

* Works with both actibase 0.6.0 and 0.8.0: `acti_calculate_measures()` uses
  `acti_flag_qc_all()` when actibase provides it and `flag_qc_all()`
  otherwise, since actibase 0.8.0 renames it.

## Breaking changes

* `acti_process()` and `acti_process_study()` now aim to match ActiLife for
  GT3X data: files are read with `digits = 8` (unless `digits` is given),
  resampled to 30Hz, then rounded to 3 digits half away from zero, as
  ActiLife does. Previously the data were read at 5 digits and not rounded,
  giving counts that differed from ActiLife by 1-3 in many epochs. Rounding
  5-digit data is not a fix: it rounds twice and differs from ActiLife more
  often. Counts from GT3X files will change slightly.

## New features

* `acti_calculate_counts()` and `acti_process()` gain `round_digits` to round
  `X`/`Y`/`Z` half away from zero (base `round()` rounds `0.0625` to
  `0.062`) after resampling and before counting. In `acti_process()`, the
  default `NULL` uses 3 for GT3X data and no rounding otherwise; `NA` turns
  it off.

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
