## R CMD check results

0 errors | 0 warnings | 1 note

* This is an update release (0.9.0).

## Resubmission

This is a resubmission.  The previous 0.9.0 upload failed the incoming checks
because it called functions from an unreleased version of 'actibase'.  This
version works with both the CRAN version of 'actibase' (0.6.0) and 'actibase'
0.8.0, currently in the incoming queue, which renames `flag_qc_all()` to
`acti_flag_qc_all()`.

---

NOTE "Failed to inspect Python interpreter" is due to "bug" 
https://github.com/r-lib/rlang/issues/1924, 
where `rlang::check_installed("agcounts")` calls `.onLoad` which calls
a `reticulate::py_require` statement that tries to initialize Python.


This release fixes several bugs (see NEWS.md), including:

* Step summaries no longer report 0 steps for fully missing (non-wear) epochs.
* Cole-Kripke and Sadeh sleep scoring now require the vertical-axis (`axis1`)
  counts rather than approximating them from vector magnitude.
* Activity counts are robust to raw data with extra columns and to records
  that do not start on an epoch boundary (see bhelsel/agcounts#50, #51).
* MIMS preprocessing helpers record their transformations, and truncated
  MIMS/AUC epochs are flagged as in 'MIMSunit'.

Counts from GT3X files now match ActiLife more closely: data are resampled
before being rounded to 3 digits (half away from zero), as ActiLife does.

It also adds `acti_process_study()` for batch processing a directory of raw
files. 'readr' is added to Imports; it is already a dependency of 'actiread'.
