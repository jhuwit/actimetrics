
# require_axis1: the caller scores the vertical axis (Cole-Kripke, Sadeh,
# axis1-based non-wear), so axis1 cannot be approximated from vector magnitude.
acti_standardize_actigraph.sleepr = function(data, require_axis1 = FALSE,
                                             caller = "This function") {

  timestamp = NULL
  rm(list = c("timestamp"))
  data = actibase::acti_standardise_data(data, subset_xyz = FALSE, check_xyz = FALSE)

  data = data |> rename_timestamp()
  mode(data$timestamp) = "double"
  if (require_axis1 && !"axis1" %in% names(data)) {
    stop(caller, " scores the vertical-axis counts and requires an `axis1` ",
         "column, which `data` does not have.  Vector-magnitude counts ",
         "cannot be substituted; use acti_calculate_counts(), which returns ",
         "`axis1`-`axis3`.", call. = FALSE)
  }

  axes = paste0("axis", 1:3)
  # actigraph.sleepr only uses axis1-axis3 (it computes the magnitude
  # itself), so the magnitude column is only used to fill in missing axes
  # and is not added to the data
  vm_col = intersect(c("vector.magnitude", "counts", "count"), names(data))
  if (length(vm_col) > 0 && !any(axes %in% colnames(data))) {
    # Only valid for magnitude-based scoring: actigraph.sleepr:::add_magnitude
    # recreates exactly the magnitude from these.  Axis-based callers set
    # require_axis1 and never reach this.
    vm = data[[vm_col[1]]]/sqrt(3)
    data$axis1 = vm
    data$axis2 = vm
    data$axis3 = vm
  }
  data
}
