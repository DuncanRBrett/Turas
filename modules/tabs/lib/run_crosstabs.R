# ==============================================================================
# CROSSTABS - TURAS V10.0
# ==============================================================================
# Enterprise-grade survey crosstabs - Modular architecture
#
# PREVIOUS FIXES:
# 1. ✅ Multi-mention questions now display correctly
# 2. ✅ ShowInOutput filtering works properly
# 3. ✅ Rating calculations fixed (OptionValue support)
# 4. ✅ All debug code removed
# 5. ✅ Clean, production-ready code
#
# V10.0 IMPROVEMENTS (Practical Enhancements):
# 1. ✅ Replaced deprecated pryr with lobstr for memory monitoring
# 2. ✅ Renamed log_issue() to add_log_entry() for clarity (alias kept)
# 3. ✅ Added smart CSV caching for large Excel files (10x faster loads)
# 4. ✅ Added configuration summary before processing (shows ETA)
# 5. ✅ Global namespace pollution fixed in excel_writer.R (local=TRUE)
# 6. ✅ MAX_DECIMAL_PLACES constant properly defined in validation.R
# 7. ✅ Refactored into focused modules for maintainability
#
# MODULAR ARCHITECTURE:
# - crosstabs_initialization.R: TRS guard, dependencies, constants
# - crosstabs_config.R: Configuration loading and survey structure
# - crosstabs_data.R: Data loading, weighting, validation
# - crosstabs_significance.R: Significance testing functions
# - crosstabs_excel.R: Excel writing and checkpoint functions
# - crosstabs_execution.R: Main execution orchestration
# ==============================================================================

SCRIPT_VERSION <- "10.0"

# ==============================================================================
# DETERMINE SCRIPT DIRECTORY
# ==============================================================================

# Must be defined BEFORE sourcing any modules
# toolkit_path should be set by the calling notebook/script to point to this file
script_dir <- tryCatch({
  if (exists("toolkit_path") && !is.null(toolkit_path) && length(toolkit_path) > 0 && nchar(toolkit_path) > 0) {
    dirname(toolkit_path)
  } else {
    # Fallback: look for the lib directory relative to working directory
    candidates <- c(
      file.path(getwd(), "modules", "tabs", "lib"),
      file.path(dirname(getwd()), "modules", "tabs", "lib"),
      getwd()
    )
    found <- candidates[dir.exists(candidates)][1]
    if (is.na(found)) getwd() else found
  }
}, error = function(e) {
  getwd()
})

# ==============================================================================
# LOAD SUB-MODULES (NEW IN V10.0)
# ==============================================================================

# Source initialization module (TRS guard, dependencies, constants)
source(file.path(script_dir, "crosstabs_initialization.R"))

# Run dependency check
check_dependencies()

# ==============================================================================
# LOAD CORE DEPENDENCIES
# ==============================================================================

source(file.path(script_dir, "shared_functions.R"))
source(file.path(script_dir, "validation.R"))
source(file.path(script_dir, "weighting.R"))
source(file.path(script_dir, "ranking.R"))

# Phase 7 Migration: Modular architecture files
source(file.path(script_dir, "banner.R"))
source(file.path(script_dir, "cell_calculator.R"))
source(file.path(script_dir, "question_dispatcher.R"))
source(file.path(script_dir, "standard_processor.R"))
source(file.path(script_dir, "numeric_processor.R"))
source(file.path(script_dir, "excel_writer.R"))
source(file.path(script_dir, "banner_indices.R"))
source(file.path(script_dir, "config_loader.R"))
source(file.path(script_dir, "question_orchestrator.R"))

# Composite Metrics Feature (V10.1)
source(file.path(script_dir, "composite_processor.R"))
source(file.path(script_dir, "summary_builder.R"))

# Load new sub-modules (V10.0)
source(file.path(script_dir, "crosstabs_config.R"))
source(file.path(script_dir, "crosstabs_data.R"))
source(file.path(script_dir, "crosstabs_significance.R"))
source(file.path(script_dir, "crosstabs_excel.R"))
source(file.path(script_dir, "crosstabs_execution.R"))

# ==============================================================================
# STARTUP
# ==============================================================================

# Print TRS start banner
if (exists("turas_print_start_banner", mode = "function")) {
  turas_print_start_banner("TABS", SCRIPT_VERSION)
} else {
  print_toolkit_header("Crosstab Analysis - Turas v10.0")
}

# Validate config_file exists
if (!exists("config_file")) {
  # TRS Refusal: CFG_NO_CONFIG_FILE
  tabs_refuse(
    code = "CFG_NO_CONFIG_FILE",
    title = "Configuration File Not Defined",
    problem = "The config_file variable is not defined.",
    why_it_matters = "Analysis requires a configuration file to specify data sources and settings.",
    how_to_fix = c(
      "Run this script from the Jupyter notebook entry point",
      "Or set config_file variable before sourcing this script"
    )
  )
}

project_root <- get_project_root(config_file)
log_message(sprintf("Project root: %s", project_root), "INFO")

start_time <- Sys.time()

# ==============================================================================
# LOAD CONFIGURATION
# ==============================================================================

config_obj <- load_crosstabs_configuration(config_file, project_root)

# Get structure file path
structure_file <- get_config_value(
  load_config_sheet(config_file, "Settings"),
  "structure_file",
  required = TRUE
)
structure_file_path <- resolve_path(project_root, structure_file)

# Get output settings
config <- load_config_sheet(config_file, "Settings")
output_subfolder <- get_config_value(config, "output_subfolder", "Crosstabs")
output_filename <- get_config_value(config, "output_filename", "Crosstabs.xlsx")

# ==============================================================================
# LOAD SURVEY STRUCTURE
# ==============================================================================

survey_structure <- load_crosstabs_survey_structure(structure_file_path, project_root)

# Load composite definitions
composite_defs <- load_crosstabs_composites(structure_file_path)

# ==============================================================================
# LOAD DATA
# ==============================================================================

survey_data <- load_crosstabs_data(config_obj, survey_structure, project_root)

# Setup weights
weight_result <- setup_crosstabs_weights(survey_data, config_obj)
master_weights <- weight_result$master_weights
effective_n <- weight_result$effective_n
is_weighted <- weight_result$is_weighted

# ==============================================================================
# LOAD QUESTION SELECTION
# ==============================================================================

selection_result <- load_question_selection(config_file)
selection_df <- selection_result$all_questions
crosstab_questions <- selection_result$selected_questions

# ==============================================================================
# VALIDATION
# ==============================================================================

error_log <- run_crosstabs_validation(
  survey_structure,
  survey_data,
  config_obj,
  composite_defs
)

# ==============================================================================
# CREATE BANNER STRUCTURE
# ==============================================================================

banner_info <- create_crosstabs_banner(selection_df, survey_structure)

# Print configuration summary
print_config_summary(
  config_obj,
  nrow(crosstab_questions),
  nrow(survey_data),
  length(banner_info$columns)
)

# ==============================================================================
# SETUP CHECKPOINTING
# ==============================================================================

checkpoint_result <- setup_checkpointing(
  config_obj,
  project_root,
  output_subfolder,
  crosstab_questions
)

checkpoint_file <- checkpoint_result$checkpoint_file
all_results <- checkpoint_result$all_results
processed_questions <- checkpoint_result$processed_questions
remaining_questions <- checkpoint_result$remaining_questions

# ==============================================================================
# PROCESS QUESTIONS
# ==============================================================================

orchestration_result <- process_questions_with_checkpointing(
  remaining_questions,
  survey_data,
  survey_structure,
  banner_info,
  master_weights,
  config_obj,
  checkpoint_file,
  crosstab_questions,
  processed_questions,
  is_weighted
)

all_results <- orchestration_result$all_results
processed_questions <- orchestration_result$processed_questions
run_status <- orchestration_result$run_status
skipped_questions <- orchestration_result$skipped_questions
partial_questions <- orchestration_result$partial_questions

# ==============================================================================
# TRS v1.0: MANDATORY PARTIAL STATUS DISCLOSURE
# ==============================================================================

if (run_status == "PARTIAL") {
  cat("\n")
  cat(paste(rep("!", 80), collapse=""), "\n")
  cat("[TRS PARTIAL] ANALYSIS COMPLETED WITH PARTIAL RESULTS\n")
  cat(paste(rep("!", 80), collapse=""), "\n")

  # Report skipped questions
  if (length(skipped_questions) > 0) {
    cat(sprintf("\n  SKIPPED QUESTIONS: %d\n", length(skipped_questions)))
    cat("  The following questions are MISSING from your output:\n\n")
    for (skip_code in names(skipped_questions)) {
      skip_info <- skipped_questions[[skip_code]]
      cat(sprintf("    - %s: %s (stage: %s)\n",
                  skip_code, skip_info$reason, skip_info$stage))
    }
  }

  # Report questions with missing sections
  if (length(partial_questions) > 0) {
    cat(sprintf("\n  QUESTIONS WITH MISSING SECTIONS: %d\n", length(partial_questions)))
    cat("  The following questions have incomplete output:\n\n")
    for (pq_code in names(partial_questions)) {
      pq_info <- partial_questions[[pq_code]]
      cat(sprintf("    - %s:\n", pq_code))
      for (section in pq_info$sections) {
        cat(sprintf("        * %s: %s\n", section$section, section$error))
      }
    }
  }

  cat("\n")
  cat("  ACTION REQUIRED: Review and fix the issues above, then re-run.\n")
  cat("  A 'Run_Status' sheet will be included in your workbook.\n")
  cat(paste(rep("!", 80), collapse=""), "\n\n")
}

# ==============================================================================
# PROCESS COMPOSITE METRICS
# ==============================================================================

composite_results <- process_composites(
  composite_defs,
  survey_data,
  survey_structure,
  banner_info,
  config_obj
)

# Merge composite results into main results
all_results <- merge_composite_results(all_results, composite_results, banner_info)

# ==============================================================================
# CREATE EXCEL OUTPUT
# ==============================================================================

log_message("Creating Excel output...", "INFO")

wb <- openxlsx::createWorkbook()

# Create styles
styles <- create_crosstabs_styles(config_obj)

# Build project info
project_name <- get_config_value(survey_structure$project, "project_name", "Crosstabs")
project_info <- list(
  project_name = project_name,
  total_responses = nrow(survey_data),
  effective_n = effective_n,
  total_banner_cols = length(banner_info$columns),
  num_banner_questions = if (!is.null(banner_info$banner_questions)) {
    nrow(banner_info$banner_questions)
  } else {
    0
  }
)

# Write all sheets
write_all_sheets(
  wb, all_results, composite_results, composite_defs,
  error_log, survey_data, survey_structure, banner_info,
  config_obj, styles, project_info, run_status,
  skipped_questions, partial_questions, processed_questions,
  crosstab_questions, master_weights, effective_n, trs_state
)

# ==============================================================================
# SAVE WORKBOOK
# ==============================================================================

output_path <- resolve_path(project_root, file.path(output_subfolder, output_filename))
output_dir <- dirname(output_path)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
  log_message("✓ Created output directory", "INFO")
}

# TRS v1.0: Get run result for atomic save
run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
  turas_run_state_result(trs_state)
} else {
  NULL
}

# TRS v1.0: Use atomic save if available
if (exists("turas_save_workbook_atomic", mode = "function")) {
  save_result <- turas_save_workbook_atomic(wb, output_path, run_result = run_result, module = "TABS")
  if (!save_result$success) {
    tabs_refuse(
      code = "IO_EXCEL_SAVE_FAILED",
      title = "Failed to Save Excel File",
      problem = "Could not save the Excel workbook to disk.",
      why_it_matters = "The analysis results cannot be delivered without saving the file.",
      how_to_fix = c(
        "Check that the output directory is writable",
        "Ensure the file is not open in another application",
        "Verify there is sufficient disk space"
      ),
      details = paste0("Output path: ", output_path, "\nError: ", save_result$error)
    )
  } else {
    log_message(sprintf("\u2713 Saved: %s", output_path), "INFO")
  }
} else {
  tryCatch({
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
    log_message(sprintf("\u2713 Saved: %s", output_path), "INFO")
  }, error = function(e) {
    tabs_refuse(
      code = "IO_EXCEL_SAVE_FAILED",
      title = "Failed to Save Excel File",
      problem = "Could not save the Excel workbook to disk.",
      why_it_matters = "The analysis results cannot be delivered without saving the file.",
      how_to_fix = c(
        "Check that the output directory is writable",
        "Ensure the file is not open in another application",
        "Verify there is sufficient disk space"
      ),
      details = paste0("Output path: ", output_path, "\nError: ", conditionMessage(e))
    )
  })
}

# ==============================================================================
# COMPLETION SUMMARY
# ==============================================================================

elapsed <- difftime(Sys.time(), start_time, units = "secs")

# TRS v1.0: Print final banner
if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
  turas_print_final_banner(run_result)
} else {
  cat("\n")
  cat(paste(rep("=", 80), collapse=""), "\n")
  cat("ANALYSIS COMPLETE - TURAS V10.0 (MODULAR)\n")
  cat(paste(rep("=", 80), collapse=""), "\n\n")

  # TRS v1.0: Display run status prominently
  if (run_status == "PARTIAL") {
    cat("⚠  TRS Status: PARTIAL (see Run_Status sheet for details)\n")
    if (length(skipped_questions) > 0) {
      cat(sprintf("⚠  Questions skipped: %d\n", length(skipped_questions)))
    }
    if (length(partial_questions) > 0) {
      cat(sprintf("⚠  Questions with missing sections: %d\n", length(partial_questions)))
    }
  } else {
    cat("✓ TRS Status: PASS\n")
  }
  cat("\n")
}

cat("✓ Project:", project_name, "\n")
cat("✓ Questions:", length(all_results), "\n")
cat("✓ Responses:", nrow(survey_data), "\n")

if (config_obj$apply_weighting) {
  cat("✓ Weighting:", config_obj$weight_variable, "\n")
  cat("✓ Effective N:", effective_n, "\n")
}

cat("✓ Significance:", if (config_obj$enable_significance_testing) "ENABLED" else "disabled", "\n")
if (config_obj$enable_significance_testing) {
  cat("✓ Alpha (p-value):", sprintf("%.3f", config_obj$alpha), "\n")
}
cat("✓ Output:", output_path, "\n")
cat("✓ Duration:", format_seconds(as.numeric(elapsed)), "\n")

if (nrow(error_log) > 0) {
  cat("⚠  Issues:", nrow(error_log), "(see Error Log)\n")
}

cat("\n")
cat("TURAS V10.0 - MODULAR ARCHITECTURE:\n")
cat("  ✓ Refactored into focused modules for maintainability\n")
cat("  ✓ Multi-mention questions display correctly\n")
cat("  ✓ ShowInOutput filtering works properly\n")
cat("  ✓ Rating calculations fixed (OptionValue support)\n")
cat("  ✓ Replaced deprecated pryr with lobstr\n")
cat("  ✓ Smart CSV caching for large Excel files\n")
cat("  ✓ Configuration summary with ETA before processing\n")
cat("\n")
cat("Ready for production use.\n")
cat(paste(rep("=", 80), collapse=""), "\n")

# ==============================================================================
# END OF SCRIPT - TURAS V10.0 (MODULAR ARCHITECTURE)
# ==============================================================================
