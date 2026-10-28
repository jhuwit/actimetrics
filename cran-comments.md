## R CMD check results

0 errors | 0 warnings | 2 notes

* This is an update release (0.10.0).
* "Days since last update": this follows 0.9.0 closely because it fixes
  step counts being shifted by the input's UTC offset, and is part of a
  coordinated update of the 'activerse' packages against 'actibase' 0.8.0.

NOTE "Failed to inspect Python interpreter" is due to "bug"
https://github.com/r-lib/rlang/issues/1924,
where `rlang::check_installed("agcounts")` calls `.onLoad` which calls
a `reticulate::py_require` statement that tries to initialize Python.

---

This release adds sleep-period-time guiders and sleep/wake labelling
(`acti_sleep_*()`) and activity-intensity cut-point classifiers
(`acti_threshold_*()`), and fixes several bugs (see NEWS.md), including:

* Step counts from 'stepcount' are returned in the input's time zone
  rather than mislabelled as UTC.
* Epoch/unit arguments accept any form understood by
  `actibase::acti_standardize_epoch()`; `ensure_all_time = TRUE` no longer
  errors for units such as "5 seconds".
* The Cole-Kripke, Sadeh, and Tudor-Locke wrappers no longer add a
  superfluous `vector.magnitude` column or overwrite an input `count` column.

'actibase' (>= 0.8.0), the current CRAN version, is now required.
