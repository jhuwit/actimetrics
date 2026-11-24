## R CMD check results

0 errors | 0 warnings | 2 notes

* This is an update release (0.11.0).
* "Days since last update": this follows 0.9.0 closely because it fixes
  step counts being shifted by the input's UTC offset, and is part of a
  coordinated update of the 'activerse' packages against 'actibase' 0.8.0.

## Notes on the CRAN check page (0.10.0)

The current CRAN check results show NOTEs under "checking dependencies in
R code" on r-devel-linux-x86_64-fedora-clang, r-devel-linux-x86_64-fedora-gcc,
r-release-macos-arm64 and r-oldrel-macos-arm64. These come from Python
setup on the check machines, not from 'actimetrics' code:

* To check `pkg::fun` calls, R CMD check loads the namespaces of the
  installed Suggests packages, which runs their `.onLoad` hooks.
* 'agcounts' calls `reticulate::py_module_available()` in `.onLoad`, which
  starts Python. On Fedora, reticulate finds `/usr/sbin/pypy`, which does
  not support `-I`, giving "Failed to inspect Python interpreter". On macOS
  arm64, reticulate's uv backend downloads CPython and numpy to start
  Python, and that download output appears as the NOTE.

'actimetrics' only uses these packages conditionally, through
`requireNamespace(..., partial = TRUE)`, so it does not run their `.onLoad`
hooks when its own functions are called.

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
