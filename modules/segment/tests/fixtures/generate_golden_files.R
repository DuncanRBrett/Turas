# ==============================================================================
# SEGMENT MODULE - GOLDEN FILE GENERATOR
# ==============================================================================
# Generates expected output baselines for regression testing.
# Run after a verified-correct analysis to establish golden files.
#
# Usage:
#   Sys.setenv(TURAS_ROOT = getwd())
#   source("modules/segment/tests/fixtures/generate_golden_files.R")
#
# Outputs:
#   tests/fixtures/golden/
#     golden_metrics.rds     - Expected validation metrics
#     golden_structure.rds   - Expected output structure
#     golden_file_list.rds   - Expected output files and sizes
#
# Version: 1.0
# ==============================================================================

cat("\n=== Generating Golden Files ===\n\n")

turas_root <- Sys.getenv("TURAS_ROOT", getwd())
source(file.path(turas_root, "modules/segment/R/00_main.R"))
source(file.path(turas_root, "modules/segment/tests/fixtures/generate_test_data.R"))

# Create golden files directory
golden_dir <- file.path(turas_root, "modules/segment/tests/fixtures/golden")
dir.create(golden_dir, recursive = TRUE, showWarnings = FALSE)

# Generate standard test data
test_data <- generate_segment_test_data(n = 400, k_true = 3, n_vars = 8,
                                         missing_rate = 0.02, seed = 42)

# Create temp config
temp_dir <- file.path(tempdir(), "golden_gen")
dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)

data_path <- file.path(temp_dir, "golden_data.csv")
write.csv(test_data$data, data_path, row.names = FALSE)

config_path <- file.path(temp_dir, "golden_config.xlsx")
wb <- openxlsx::createWorkbook()
openxlsx::addWorksheet(wb, "Config")
config_df <- data.frame(
  Setting = c("data_file", "id_variable", "clustering_vars",
    "method", "k_fixed", "nstart", "seed",
    "missing_data", "missing_threshold", "standardize",
    "min_segment_size_pct", "outlier_detection",
    "output_folder", "output_prefix", "create_dated_folder",
    "save_model", "html_report",
    "generate_rules", "generate_action_cards",
    "auto_name_style", "scale_max",
    "project_name", "analyst_name", "description"),
  Value = c(data_path, "respondent_id",
    paste(test_data$clustering_vars, collapse = ","),
    "kmeans", "3", "10", "42",
    "listwise_deletion", "30", "TRUE",
    "5", "FALSE",
    file.path(temp_dir, "output"), "golden_", "FALSE",
    "TRUE", "TRUE",
    "TRUE", "TRUE",
    "simple", "10",
    "Golden File Test", "Test Runner", "Golden file generation"),
  stringsAsFactors = FALSE
)
openxlsx::writeData(wb, "Config", config_df)
openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

# Run the analysis
cat("Running golden file analysis...\n")
result <- turas_segment_from_config(config_path)

# Extract golden metrics
golden_metrics <- list(
  mode = result$mode,
  status = result$status,
  k = result$k,
  method = result$method,
  silhouette = result$validation$avg_silhouette,
  betweenss_totss = result$validation$betweenss_totss,
  n_clusters = length(unique(result$clusters)),
  n_assigned = length(result$clusters),
  segment_sizes = as.integer(table(result$clusters)),
  has_exec_summary = !is.null(result$exec_summary),
  has_enhanced_rules = !is.null(result$enhanced$rules),
  has_enhanced_cards = !is.null(result$enhanced$cards),
  timestamp = Sys.time(),
  version = SEGMENT_VERSION
)

# Extract output file structure
output_dir <- file.path(temp_dir, "output")
output_files <- list.files(output_dir, recursive = TRUE)
golden_files <- data.frame(
  filename = output_files,
  size = sapply(output_files, function(f) file.size(file.path(output_dir, f))),
  extension = tools::file_ext(output_files),
  stringsAsFactors = FALSE
)

# Extract result structure
golden_structure <- list(
  result_names = sort(names(result)),
  output_file_count = length(output_files),
  output_extensions = sort(unique(tools::file_ext(output_files))),
  has_html = any(grepl("\\.html$", output_files)),
  has_model = any(grepl("\\.rds$", output_files)),
  has_assignments = any(grepl("assignments", output_files)),
  has_report = any(grepl("report", output_files))
)

# Save golden files
saveRDS(golden_metrics, file.path(golden_dir, "golden_metrics.rds"))
saveRDS(golden_structure, file.path(golden_dir, "golden_structure.rds"))
saveRDS(golden_files, file.path(golden_dir, "golden_file_list.rds"))

cat(sprintf("\nGolden files saved to: %s\n", golden_dir))
cat(sprintf("  golden_metrics.rds    - %d metrics\n", length(golden_metrics)))
cat(sprintf("  golden_structure.rds  - %d structure fields\n", length(golden_structure)))
cat(sprintf("  golden_file_list.rds  - %d output files\n", nrow(golden_files)))

# Print key metrics for verification
cat("\n=== Golden Metrics ===\n")
cat(sprintf("  Mode: %s\n", golden_metrics$mode))
cat(sprintf("  Status: %s\n", golden_metrics$status))
cat(sprintf("  k: %d\n", golden_metrics$k))
cat(sprintf("  Silhouette: %.3f\n", golden_metrics$silhouette))
cat(sprintf("  BSS/TSS: %.3f\n", golden_metrics$betweenss_totss))
cat(sprintf("  Segment sizes: %s\n", paste(golden_metrics$segment_sizes, collapse = ", ")))
cat(sprintf("  Version: %s\n", golden_metrics$version))

# Cleanup
unlink(temp_dir, recursive = TRUE)
cat("\n=== Golden file generation complete ===\n")
