# ==============================================================================
# TABS MODULE - END-TO-END INTEGRATION TESTS
# ==============================================================================
#
# Tests the full tabs pipeline using demo data:
#   1. Config loading. Load_crosstabs_config()
#   2. Data loading. Load_crosstabs_data()
#   3. Analysis. Run_crosstabs_analysis()
#   4. Excel output. Create_crosstabs_workbook()
#   5. Interactive report data layer. Write_data_layer()
#
# These tests are slower (Excel I/O) but prove the complete system works.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_e2e_integration.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()
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
# TEST CONSTANTS
# ==============================================================================

demo_config_file <- file.path(turas_root, "examples/tabs/demo_survey/Demo_Crosstab_Config.xlsx")


# ==============================================================================
# 1. CONFIG LOADING TESTS
# ==============================================================================

context("E2E: Config loading")

test_that("loads demo config successfully", {
  skip_if_not(file.exists(demo_config_file), "Demo config file not found")

  config_result <- load_crosstabs_config(demo_config_file)

  expect_true(is.list(config_result))
  expect_true("config_obj" %in% names(config_result))
  expect_true("project_root" %in% names(config_result))
  expect_true("output_path" %in% names(config_result))
  expect_true("structure_file_path" %in% names(config_result))

  # Verify key config settings were parsed

  expect_true(is.logical(config_result$config_obj$enable_significance_testing))
  expect_true(is.logical(config_result$config_obj$apply_weighting))
  expect_true(is.numeric(config_result$config_obj$alpha))
  expect_true(config_result$config_obj$alpha > 0 && config_result$config_obj$alpha < 1)
})


test_that("refuses missing config file", {
  skip_if_not(file.exists(demo_config_file), "Demo config file not found (need guard layer)")

  expect_error(
    load_crosstabs_config("/nonexistent/path/missing_config.xlsx"),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 2. DATA LOADING TESTS
# ==============================================================================

context("E2E: Data loading")

test_that("loads demo data successfully", {
  skip_if_not(file.exists(demo_config_file), "Demo config file not found")

  config_result <- load_crosstabs_config(demo_config_file)
  data_result <- load_crosstabs_data(config_result)

  expect_true(is.list(data_result))
  expect_true(is.data.frame(data_result$survey_data))
  expect_true(nrow(data_result$survey_data) > 0)
  expect_true("survey_structure" %in% names(data_result))
  expect_true("crosstab_questions" %in% names(data_result))
  expect_true(nrow(data_result$crosstab_questions) > 0)
  expect_true(is.numeric(data_result$master_weights))
  expect_equal(length(data_result$master_weights), nrow(data_result$survey_data))
})


# ==============================================================================
# 3. FULL ANALYSIS TESTS
# ==============================================================================

context("E2E: Full analysis pipeline")

test_that("runs demo analysis end-to-end", {
  skip_if_not(file.exists(demo_config_file), "Demo config file not found")

  config_result <- load_crosstabs_config(demo_config_file)
  data_result <- load_crosstabs_data(config_result)
  analysis_result <- run_crosstabs_analysis(
    config_result, data_result,
    checkpoint_frequency = CHECKPOINT_FREQUENCY,
    total_column = TOTAL_COLUMN
  )

  expect_true(is.list(analysis_result))
  expect_true(analysis_result$run_status %in% c("PASS", "PARTIAL"))
  expect_true(length(analysis_result$all_results) > 0)
  expect_true(!is.null(analysis_result$banner_info))
  expect_true(is.data.frame(analysis_result$error_log))

  # Each result should have standard structure
  first_result <- analysis_result$all_results[[1]]
  expect_true("question_code" %in% names(first_result))
  expect_true("table" %in% names(first_result))
  expect_true(is.data.frame(first_result$table))
  expect_true(nrow(first_result$table) > 0)
})


test_that("analysis produces results for all selected questions plus composites", {
  skip_if_not(file.exists(demo_config_file), "Demo config file not found")

  config_result <- load_crosstabs_config(demo_config_file)
  data_result <- load_crosstabs_data(config_result)
  analysis_result <- run_crosstabs_analysis(
    config_result, data_result,
    checkpoint_frequency = CHECKPOINT_FREQUENCY,
    total_column = TOTAL_COLUMN
  )

  n_selected <- nrow(data_result$crosstab_questions)
  n_composites <- length(analysis_result$composite_results)
  n_results <- length(analysis_result$all_results)
  n_skipped <- length(analysis_result$skipped_questions)

  # all_results includes both question results and composite results.
  # Every selected question should produce a result or be tracked as skipped,
  # plus composite metrics are appended to all_results.
  expect_equal(n_results + n_skipped, n_selected + n_composites,
    info = sprintf(
      "Expected %d results + %d skipped = %d selected + %d composites, got %d + %d = %d",
      n_results, n_skipped, n_selected, n_composites,
      n_results, n_skipped, n_results + n_skipped))
})


# ==============================================================================
# 4. EXCEL OUTPUT TESTS
# ==============================================================================

context("E2E: Excel output")

test_that("creates valid Excel output file", {
  skip_if_not(file.exists(demo_config_file), "Demo config file not found")

  tmp_output <- tempfile(pattern = "turas_e2e_", fileext = ".xlsx")
  on.exit(unlink(tmp_output), add = TRUE)

  # Run full pipeline
  config_result <- load_crosstabs_config(demo_config_file)
  data_result <- load_crosstabs_data(config_result)
  analysis_result <- run_crosstabs_analysis(
    config_result, data_result,
    checkpoint_frequency = CHECKPOINT_FREQUENCY,
    total_column = TOTAL_COLUMN
  )

  # Create workbook with temp output path
  workbook_result <- create_crosstabs_workbook(
    all_results = analysis_result$all_results,
    composite_results = analysis_result$composite_results,
    composite_defs = data_result$composite_defs,
    survey_structure = data_result$survey_structure,
    survey_data = data_result$survey_data,
    banner_info = analysis_result$banner_info,
    config_obj = config_result$config_obj,
    error_log = analysis_result$error_log,
    trs_state = NULL,
    run_status = analysis_result$run_status,
    skipped_questions = analysis_result$skipped_questions,
    partial_questions = analysis_result$partial_questions,
    processed_questions = analysis_result$processed_questions,
    crosstab_questions = data_result$crosstab_questions,
    effective_n = data_result$effective_n,
    master_weights = data_result$master_weights,
    output_path = tmp_output,
    script_version = SCRIPT_VERSION,
    total_column = TOTAL_COLUMN,
    very_small_base = VERY_SMALL_BASE_SIZE
  )

  # Verify file was created
  expect_true(file.exists(tmp_output),
    info = "Excel output file should exist after workbook creation")

  # Verify expected sheets
  sheets <- openxlsx::getSheetNames(tmp_output)
  expect_true("Crosstabs" %in% sheets,
    info = paste("Expected 'Crosstabs' sheet. Found:", paste(sheets, collapse = ", ")))
  expect_true("Summary" %in% sheets,
    info = paste("Expected 'Summary' sheet. Found:", paste(sheets, collapse = ", ")))

  # Verify workbook_result structure
  expect_true(is.list(workbook_result))
  expect_equal(workbook_result$output_path, tmp_output)
  expect_true(nzchar(workbook_result$project_name))
})


test_that("output Crosstabs sheet contains data rows", {
  skip_if_not(file.exists(demo_config_file), "Demo config file not found")

  tmp_output <- tempfile(pattern = "turas_e2e_data_", fileext = ".xlsx")
  on.exit(unlink(tmp_output), add = TRUE)

  # Run full pipeline
  config_result <- load_crosstabs_config(demo_config_file)
  data_result <- load_crosstabs_data(config_result)
  analysis_result <- run_crosstabs_analysis(
    config_result, data_result,
    checkpoint_frequency = CHECKPOINT_FREQUENCY,
    total_column = TOTAL_COLUMN
  )

  workbook_result <- create_crosstabs_workbook(
    all_results = analysis_result$all_results,
    composite_results = analysis_result$composite_results,
    composite_defs = data_result$composite_defs,
    survey_structure = data_result$survey_structure,
    survey_data = data_result$survey_data,
    banner_info = analysis_result$banner_info,
    config_obj = config_result$config_obj,
    error_log = analysis_result$error_log,
    trs_state = NULL,
    run_status = analysis_result$run_status,
    skipped_questions = analysis_result$skipped_questions,
    partial_questions = analysis_result$partial_questions,
    processed_questions = analysis_result$processed_questions,
    crosstab_questions = data_result$crosstab_questions,
    effective_n = data_result$effective_n,
    master_weights = data_result$master_weights,
    output_path = tmp_output,
    script_version = SCRIPT_VERSION,
    total_column = TOTAL_COLUMN,
    very_small_base = VERY_SMALL_BASE_SIZE
  )

  # Read the Crosstabs sheet and verify it has meaningful data
  ct_data <- openxlsx::read.xlsx(tmp_output, sheet = "Crosstabs")
  expect_true(nrow(ct_data) > 0,
    info = "Crosstabs sheet should contain data rows")

  # There should be at least as many rows as selected questions (each question
  # produces multiple rows: base, frequencies, percentages, etc.)
  n_selected <- nrow(data_result$crosstab_questions)
  expect_true(nrow(ct_data) >= n_selected,
    info = sprintf("Crosstabs sheet has %d rows, expected at least %d (one per question)",
                   nrow(ct_data), n_selected))
})



# ==============================================================================
# 6. COMPOSITE INDICES REACH THE MICRODATA ISLAND
# ==============================================================================
# A composite (COMP_SAT = the mean of Q002..Q005) has no column in the data and
# no row in the Questions sheet, so it used to be absent from TR.MICRO.scores.
# It therefore could not recompute under a live filter, and the wave tracker
# SILENTLY dropped any Question_Mapping row naming one. The fault that cost
# SACS its Overall Engagement trend. Gated end to end on the demo project,
# because the unit test cannot prove the real pipeline wires composite_defs
# through.

context("E2E: composite indices in the microdata island")

source(file.path(turas_root, "modules/tabs/lib/score_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_layer_writer.R"))
source(file.path(turas_root, "modules/tabs/lib/microdata_writer.R"))

e2e_micro_build <- function() {
  config_result <- load_crosstabs_config(demo_config_file)
  data_result <- load_crosstabs_data(config_result)
  analysis_result <- run_crosstabs_analysis(
    config_result, data_result,
    checkpoint_frequency = CHECKPOINT_FREQUENCY, total_column = TOTAL_COLUMN)
  dl <- build_data_layer(analysis_result$all_results, analysis_result$banner_info,
                         config_result$config_obj, data_result$survey_structure)
  micro <- build_microdata(dl, data_result$survey_data, data_result$survey_structure,
                           analysis_result$banner_info, config_result$config_obj,
                           composite_defs = data_result$composite_defs)
  list(dl = dl, micro = micro, defs = data_result$composite_defs)
}

e2e_dl_question <- function(dl, code) {
  for (q in dl$questions) if (identical(q$code, code)) return(q)
  NULL
}

test_that("the demo project's composites are flagged and carry per-respondent scores", {
  skip_if_not(file.exists(demo_config_file), "Demo config file not found")
  built <- e2e_micro_build()

  codes <- as.character(built$defs$CompositeCode)
  expect_true(length(codes) > 0)

  for (code in codes) {
    q <- e2e_dl_question(built$dl, code)
    expect_false(is.null(q), info = paste(code, "should be a data-layer question"))
    expect_true(isTRUE(q$composite),
      info = paste(code, "should be flagged composite so the Patterns scans skip it"))
    sc <- built$micro$scores[[code]]
    expect_false(is.null(sc),
      info = paste(code, "should carry per-respondent scores in the island"))
    expect_equal(length(sc), built$micro$n,
      info = paste(code, "score vector should be one value per respondent"))
    expect_true(any(!is.na(sc)), info = paste(code, "should have at least one real score"))
  }
})

test_that("an ordinary question carries no composite flag", {
  skip_if_not(file.exists(demo_config_file), "Demo config file not found")
  built <- e2e_micro_build()
  source_q <- e2e_dl_question(built$dl, "Q002")
  if (!is.null(source_q)) expect_null(source_q$composite)
})

# The decimal places the composite's mean row is published at, so the
# reconciliation tolerance tracks the config instead of hard-coding 1 dp.
config_obj_dp <- function(built) {
  dp <- suppressWarnings(as.numeric(
    load_crosstabs_config(demo_config_file)$config_obj$decimal_places_index))
  if (length(dp) != 1L || is.na(dp)) 1 else dp
}

test_that("the island's composite mean reconciles with every published composite", {
  skip_if_not(file.exists(demo_config_file), "Demo config file not found")
  built <- e2e_micro_build()

  # The island holds per-respondent scores and per-respondent WEIGHTS; the
  # published cell is the weighted mean of those scores. Recomputing unweighted
  # here would pass on an unweighted project and quietly drift on a weighted one
  # (the demo is weighted: it caught exactly that while this gate was written).
  w <- as.numeric(built$micro$weights)
  expect_equal(length(w), built$micro$n)

  checked <- 0L
  for (code in as.character(built$defs$CompositeCode)) {
    q <- NULL
    for (x in built$dl$questions) if (identical(x$code, code)) q <- x
    mean_row <- NULL
    for (r in q$rows) if (identical(r$kind, "mean")) { mean_row <- r; break }
    expect_false(is.null(mean_row),
      info = paste(code, "should publish a mean row"))

    published <- suppressWarnings(as.numeric(mean_row$pct[[1]]))   # column 1 = Total
    if (length(published) != 1L || is.na(published)) next

    sc <- as.numeric(built$micro$scores[[code]])
    keep <- !is.na(sc)
    recomputed <- stats::weighted.mean(sc[keep], w = w[keep])

    # The published cell is DISPLAY-ROUNDED (decimal_places_index), so the gate
    # is that the island lands on the figure the reader sees. Half of the last
    # displayed place, not bit-identity with an unrounded intermediate.
    dp <- suppressWarnings(as.numeric(config_obj_dp(built)))
    tol <- 0.5 * 10^(-dp) + 1e-9
    expect_lt(abs(recomputed - published), tol,
      label = sprintf("%s: island weighted mean %.4f vs published %.4f (%d dp)",
                      code, recomputed, published, dp))
    checked <- checked + 1L
  }
  # A loop that reconciled nothing would pass in silence. The exact shape of
  # useless test this gate exists to prevent.
  expect_gt(checked, 0)
})


# ==============================================================================
# END OF E2E INTEGRATION TESTS
# ==============================================================================
