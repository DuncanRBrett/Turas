# ==============================================================================
# CROSS-ENGINE PARITY FIXTURE — tabs pipeline loader
# ==============================================================================
#
# Sources the tabs pipeline into the calling environment so the parity fixture
# can be run end to end (config -> data -> analysis -> data layer). Shared by
# the island regenerator (regenerate_parity_island.R) and the R half of the
# parity harness (modules/tabs/tests/testthat/test_cross_engine_stats.R) so the
# two can never load different code and agree by accident.
#
# The sourcing order mirrors test_e2e_integration.R. Like that file it hand-
# copies the run_crosstabs.R constants rather than sourcing the orchestrator,
# which would fire check_dependencies() and the CLI path on load.
#
# Requires `turas_root` to already exist in the calling environment.
# ==============================================================================

stopifnot(exists("turas_root"), nzchar(turas_root), dir.exists(turas_root))
lib_dir <- file.path(turas_root, "modules/tabs/lib")

# --- 1. TRS refusal infrastructure and guard layer ---
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(lib_dir, "00_guard.R"))

# --- 2. Utility modules (dependency order) ---
source(file.path(lib_dir, "validation_utils.R"))
source(file.path(lib_dir, "path_utils.R"))
source(file.path(lib_dir, "type_utils.R"))
source(file.path(lib_dir, "logging_utils.R"))
source(file.path(lib_dir, "config_utils.R"))
source(file.path(lib_dir, "excel_utils.R"))
source(file.path(lib_dir, "filter_utils.R"))
source(file.path(lib_dir, "data_loader.R"))
source(file.path(lib_dir, "banner.R"))
source(file.path(lib_dir, "banner_indices.R"))

# --- 3. Set .tabs_lib_dir in globalenv (required by tabs_source / tabs_lib_path) ---
assign(".tabs_lib_dir", lib_dir, envir = globalenv())

# --- 4. Cell calculator, weighting, ranking ---
source(file.path(lib_dir, "cell_calculator.R"))
source(file.path(lib_dir, "weighting.R"))
source(file.path(lib_dir, "ranking.R"))

# --- 5. Shared utility functions (from shared_functions.R, inline to avoid side effects) ---
safe_execute <- function(expr, default = NA, error_msg = "Operation failed", silent = FALSE) {
  tryCatch(expr, error = function(e) {
    if (!silent) cat(sprintf("  [WARNING] %s: %s\n", error_msg, conditionMessage(e)))
    return(default)
  })
}
assign("safe_execute", safe_execute, envir = globalenv())

batch_rbind <- function(row_list) {
  if (length(row_list) == 0) return(data.frame())
  all_cols <- unique(unlist(lapply(row_list, names)))
  row_list <- lapply(row_list, function(df) {
    missing_cols <- setdiff(all_cols, names(df))
    for (col in missing_cols) df[[col]] <- NA
    df[, all_cols, drop = FALSE]
  })
  do.call(rbind, row_list)
}
assign("batch_rbind", batch_rbind, envir = globalenv())

create_error_log <- function() {
  data.frame(
    Timestamp = character(), Component = character(),
    Issue_Type = character(), Description = character(),
    QuestionCode = character(), Severity = character(),
    stringsAsFactors = FALSE
  )
}
assign("create_error_log", create_error_log, envir = globalenv())

calc_percentage <- function(numerator, denominator, decimal_places = 0) {
  if (is.na(denominator) || denominator == 0) return(NA_real_)
  round((numerator / denominator) * 100, decimal_places)
}
assign("calc_percentage", calc_percentage, envir = globalenv())

print_toolkit_header <- function(analysis_type = "Analysis") {
  cat(sprintf("\n%s\n  TURAS E2E TEST - %s\n%s\n\n",
              strrep("=", 80), analysis_type, strrep("=", 80)))
}
assign("print_toolkit_header", print_toolkit_header, envir = globalenv())

format_seconds <- function(seconds) {
  if (seconds < 60) return(sprintf("%.1f seconds", seconds))
  sprintf("%.1f minutes", seconds / 60)
}
assign("format_seconds", format_seconds, envir = globalenv())

# --- 6. Constants from run_crosstabs.R ---
assign("TOTAL_COLUMN", "Total", envir = globalenv())
assign("SIG_ROW_TYPE", "Sig.", envir = globalenv())
assign("SIG2_ROW_TYPE", "Sig.2", envir = globalenv())
assign("BASE_ROW_LABEL", "Base (n=)", envir = globalenv())
assign("UNWEIGHTED_BASE_LABEL", "Base (unweighted)", envir = globalenv())
assign("WEIGHTED_BASE_LABEL", "Base (weighted)", envir = globalenv())
assign("EFFECTIVE_BASE_LABEL", "Effective base", envir = globalenv())
assign("FREQUENCY_ROW_TYPE", "Frequency", envir = globalenv())
assign("COLUMN_PCT_ROW_TYPE", "Column %", envir = globalenv())
assign("ROW_PCT_ROW_TYPE", "Row %", envir = globalenv())
assign("AVERAGE_ROW_TYPE", "Average", envir = globalenv())
assign("INDEX_ROW_TYPE", "Index", envir = globalenv())
assign("SCORE_ROW_TYPE", "Score", envir = globalenv())
assign("MINIMUM_BASE_SIZE", 30, envir = globalenv())
assign("VERY_SMALL_BASE_SIZE", 10, envir = globalenv())
assign("DEFAULT_ALPHA", 0.05, envir = globalenv())
assign("DEFAULT_MIN_BASE", 30, envir = globalenv())
assign("MAX_EXCEL_COLUMNS", 16384, envir = globalenv())
assign("MAX_EXCEL_ROWS", 1048576, envir = globalenv())
assign("BATCH_WRITE_THRESHOLD", 100, envir = globalenv())
assign("VECTORIZE_THRESHOLD", 50, envir = globalenv())
assign("CHECKPOINT_FREQUENCY", 10, envir = globalenv())
assign("MEMORY_WARNING_GIB", 6, envir = globalenv())
assign("MEMORY_CRITICAL_GIB", 8, envir = globalenv())
assign("MAX_DECIMAL_PLACES", 6, envir = globalenv())
assign("SCRIPT_VERSION", "10.2", envir = globalenv())

# --- 7. Significance functions (extracted from run_crosstabs.R) ---
.rc_lines <- readLines(file.path(lib_dir, "run_crosstabs.R"))
.rc_start <- grep("^run_significance_tests_for_row <- function", .rc_lines)
.rc_end   <- grep("^add_significance_row <- function", .rc_lines)
.rc_next  <- grep("^(#' Write question table|write_question_table_fast)", .rc_lines)
.rc_next  <- .rc_next[.rc_next > .rc_end[1]][1] - 1
eval(parse(text = .rc_lines[.rc_start[1]:.rc_next]), envir = globalenv())

# Also extract write_question_table_fast and format_output_value
.wq_start <- grep("^write_question_table_fast <- function", .rc_lines)
.fo_start <- grep("^format_output_value <- function", .rc_lines)
.main_exec <- grep("^# MAIN EXECUTION", .rc_lines)
.wq_end <- .main_exec[1] - 2
eval(parse(text = .rc_lines[.wq_start[1]:.wq_end]), envir = globalenv())
rm(.rc_lines, .rc_start, .rc_end, .rc_next, .wq_start, .fo_start, .main_exec, .wq_end)

# --- 8. Processors and dispatchers ---
source(file.path(lib_dir, "config_loader.R"))
source(file.path(lib_dir, "validation.R"))
source(file.path(lib_dir, "standard_processor.R"))
source(file.path(lib_dir, "numeric_processor.R"))
source(file.path(lib_dir, "question_orchestrator.R"))
source(file.path(lib_dir, "composite_processor.R"))
source(file.path(lib_dir, "excel_writer.R"))
source(file.path(lib_dir, "summary_builder.R"))

# --- 9. Phase 4 crosstabs sub-modules ---
tabs_source("crosstabs", "checkpoint.R")
tabs_source("crosstabs", "crosstabs_config.R")
tabs_source("crosstabs", "data_setup.R")
tabs_source("crosstabs", "analysis_runner.R")
tabs_source("crosstabs", "workbook_builder.R")

# --- 10. Shared report helpers (row/banner shape + chart palette) ---
source(file.path(turas_root, "modules/tabs/lib/report_shared.R"))


# ==============================================================================

# --- 11. Data layer + the processors the fixture's question types need ---
source(file.path(lib_dir, "score_utils.R"))
source(file.path(lib_dir, "allocation_processor.R"))
source(file.path(lib_dir, "data_layer_writer.R"))
