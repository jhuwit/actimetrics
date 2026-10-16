## R CMD check results

0 errors | 0 warnings | 1 note

* This is an update release (0.8.0).

---

This release fixes several bugs (see NEWS.md), including:

* Step summaries no longer report 0 steps for fully missing (non-wear) epochs.
* Cole-Kripke and Sadeh sleep scoring now require the vertical-axis (`axis1`)
  counts rather than approximating them from vector magnitude.
* Activity counts are robust to raw data with extra columns and to records
  that do not start on an epoch boundary (see bhelsel/agcounts#50, #51).
* MIMS preprocessing helpers record their transformations, and truncated
  MIMS/AUC epochs are flagged as in 'MIMSunit'.

It also adds `acti_process_study()` for batch processing a directory of raw
files. 'readr' is added to Imports; it is already a dependency of 'actiread'.
