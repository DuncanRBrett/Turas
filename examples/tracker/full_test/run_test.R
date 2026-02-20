# ==============================================================================
# Run Full Tracker Test
# ==============================================================================
# This script runs the tracker on the full test dataset.
# It produces both Excel and HTML tracking crosstab reports.
# ==============================================================================

# Set paths
test_dir <- dirname(sys.frame(1)$ofile)
turas_root <- normalizePath(file.path(test_dir, "..", "..", ".."))

# Source the tracker
tracker_path <- file.path(turas_root, "modules", "tracker", "run_tracker.R")
source(tracker_path)

# Run with banners enabled
result <- run_tracker(
  tracking_config_path = file.path(test_dir, "tracking_config.xlsx"),
  question_mapping_path = file.path(test_dir, "question_mapping.xlsx"),
  data_dir = test_dir,
  use_banners = TRUE
)

cat("\n\nOutput files:\n")
if (is.list(result)) {
  for (name in names(result)) {
    cat(paste0("  ", name, ": ", result[[name]], "\n"))
  }
} else {
  cat(paste0("  ", result, "\n"))
}

