# ==============================================================================
# TABS MODULE - AI INSIGHTS INTEGRATION TESTS
# ==============================================================================
#
# End-to-end tests for the AI insights pipeline:
#   - generate_all_insights() with mocked LLM calls
#   - Sidecar read/write round-trip
#   - Cache hit/miss behaviour
#   - Graceful degradation
#   - Idempotency
#
# These tests do NOT make real API calls. They test the orchestration logic
# with mocked call_insight_model() behaviour.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_ai_insights_integration.R")
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

# Source all AI modules
source(file.path(turas_root, "modules/shared/lib/ai/ai_provider.R"))
source(file.path(turas_root, "modules/shared/lib/ai/ai_schemas.R"))
source(file.path(turas_root, "modules/shared/lib/ai/ai_utils.R"))
source(file.path(turas_root, "modules/shared/lib/ai/ai_verify.R"))
source(file.path(turas_root, "modules/tabs/lib/ai/ai_extraction.R"))
source(file.path(turas_root, "modules/tabs/lib/ai/ai_prompts.R"))
source(file.path(turas_root, "modules/tabs/lib/ai/ai_schemas_tabs.R"))
source(file.path(turas_root, "modules/tabs/lib/ai/ai_insights.R"))

# ==============================================================================
# FIXTURES
# ==============================================================================

make_integration_banner_info <- function() {
  list(
    internal_keys = c("TOTAL::Total", "Segment::Premium", "Segment::Budget"),
    columns       = c("Total", "Premium", "Budget"),
    letters       = c("A", "B", "C"),
    key_to_display = c(
      "TOTAL::Total"      = "Total",
      "Segment::Premium"  = "Premium",
      "Segment::Budget"   = "Budget"
    ),
    banner_info = list(
      Segment = list(
        internal_keys = c("Segment::Premium", "Segment::Budget"),
        columns       = c("Premium", "Budget"),
        letters       = c("B", "C"),
        question = data.frame(
          QuestionCode = "Segment",
          QuestionText = "Customer segment",
          stringsAsFactors = FALSE
        )
      )
    ),
    banner_headers = data.frame(
      label = c("Total", "Segment"),
      start_col = c(1, 2),
      end_col = c(1, 3),
      stringsAsFactors = FALSE
    )
  )
}

make_integration_all_results <- function() {
  make_q <- function(code, text) {
    list(
      question_code = code,
      question_text = text,
      question_type = "Single_Response",
      base_filter = NA,
      filter_label = NA,
      table = data.frame(
        RowLabel = c("Good", "Good", "Good",
                     "Average", "Average", "Average",
                     "Poor", "Poor", "Poor"),
        RowType = c("Frequency", "Column %", "Sig.",
                    "Frequency", "Column %", "Sig.",
                    "Frequency", "Column %", "Sig."),
        `TOTAL::Total` = c(60, 60.0, "",
                           25, 25.0, "",
                           15, 15.0, ""),
        `Segment::Premium` = c(45, 90.0, "C",
                               3, 6.0, "",
                               2, 4.0, ""),
        `Segment::Budget` = c(15, 30.0, "",
                              22, 44.0, "B",
                              13, 26.0, "B"),
        check.names = FALSE,
        stringsAsFactors = FALSE
      ),
      bases = list(
        `TOTAL::Total`     = list(unweighted = 100, weighted = 100),
        `Segment::Premium` = list(unweighted = 50, weighted = 50),
        `Segment::Budget`  = list(unweighted = 50, weighted = 50)
      )
    )
  }

  list(
    Q1 = make_q("Q1", "Service quality"),
    Q2 = make_q("Q2", "Value for money"),
    Q3 = make_q("Q3", "Delivery speed"),
    Q4 = make_q("Q4", "Communication")
  )
}

make_integration_config_obj <- function() {
  list(
    project_title   = "Integration Test Study",
    apply_weighting = FALSE,
    fieldwork_dates = "March 2026"
  )
}

make_integration_sidecar <- function(enabled = TRUE) {
  list(
    version      = "1.0",
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    config = list(
      enabled                   = enabled,
      provider                  = "anthropic",
      model                     = "claude-sonnet-4-20250514",
      temperature               = 0.3,
      max_tokens                = 1500L,
      exec_summary_max_tokens   = 2500L,
      verify_callouts           = FALSE,
      rank_callouts             = FALSE,
      generate_exec_summary     = FALSE,
      generate_per_question     = TRUE,
      exec_summary_reviewed     = TRUE,
      max_verification_attempts = 2L,
      api_key_env               = "NONEXISTENT_INTEGRATION_KEY"
    ),
    questions          = list(),
    executive_summary  = NULL
  )
}

write_test_sidecar <- function(sidecar, sidecar_path) {
  json_text <- jsonlite::toJSON(sidecar, auto_unbox = TRUE, pretty = TRUE,
                                digits = 6, null = "null")
  writeLines(as.character(json_text), sidecar_path)
}

# ==============================================================================
# TESTS: Sidecar detection and loading
# ==============================================================================

context("generate_all_insights — sidecar loading")

test_that("returns NULL when no sidecar file exists", {
  all_results <- make_integration_all_results()
  banner_info <- make_integration_banner_info()
  config_obj  <- make_integration_config_obj()

  tmp_path <- tempfile(fileext = "_ai_insights.json")
  on.exit(unlink(tmp_path))

  result <- generate_all_insights(all_results, banner_info, config_obj, tmp_path)
  expect_null(result)
})

test_that("returns NULL when sidecar has enabled=FALSE", {
  all_results <- make_integration_all_results()
  banner_info <- make_integration_banner_info()
  config_obj  <- make_integration_config_obj()

  tmp_path <- tempfile(fileext = "_ai_insights.json")
  on.exit(unlink(tmp_path))

  sidecar <- make_integration_sidecar(enabled = FALSE)
  write_test_sidecar(sidecar, tmp_path)

  result <- generate_all_insights(all_results, banner_info, config_obj, tmp_path)
  expect_null(result)
})

# ==============================================================================
# TESTS: Graceful degradation
# ==============================================================================

context("generate_all_insights — graceful degradation")

test_that("returns result structure even when all API calls fail", {
  all_results <- make_integration_all_results()
  banner_info <- make_integration_banner_info()
  config_obj  <- make_integration_config_obj()

  tmp_path <- tempfile(fileext = "_ai_insights.json")
  on.exit(unlink(tmp_path))

  sidecar <- make_integration_sidecar(enabled = TRUE)
  write_test_sidecar(sidecar, tmp_path)

  # API key doesn't exist, so all calls will fail
  Sys.unsetenv("NONEXISTENT_INTEGRATION_KEY")

  suppressWarnings({
    result <- generate_all_insights(all_results, banner_info, config_obj, tmp_path)
  })

  # Should still return a result (not NULL), just with no callouts
  expect_false(is.null(result))
  expect_true(is.list(result))
  expect_true("callouts" %in% names(result))
  expect_true("model_display_name" %in% names(result))
})

test_that("sidecar is saved even when all API calls fail", {
  all_results <- make_integration_all_results()
  banner_info <- make_integration_banner_info()
  config_obj  <- make_integration_config_obj()

  tmp_path <- tempfile(fileext = "_ai_insights.json")
  on.exit(unlink(tmp_path))

  sidecar <- make_integration_sidecar(enabled = TRUE)
  write_test_sidecar(sidecar, tmp_path)

  Sys.unsetenv("NONEXISTENT_INTEGRATION_KEY")

  suppressWarnings({
    generate_all_insights(all_results, banner_info, config_obj, tmp_path)
  })

  # Sidecar should still exist and be readable
  expect_true(file.exists(tmp_path))
  reloaded <- jsonlite::fromJSON(readLines(tmp_path, warn = FALSE),
                                 simplifyVector = FALSE)
  expect_equal(reloaded$version, "1.0")
})

# ==============================================================================
# TESTS: Cache behaviour
# ==============================================================================

context("generate_all_insights — cache behaviour")

test_that("cached callouts are preserved when data hash matches", {
  all_results <- make_integration_all_results()
  banner_info <- make_integration_banner_info()
  config_obj  <- make_integration_config_obj()

  tmp_path <- tempfile(fileext = "_ai_insights.json")
  on.exit(unlink(tmp_path))

  # Pre-populate sidecar with a cached callout
  q_data <- extract_question_data(all_results[["Q1"]], banner_info)
  data_hash <- compute_data_hash(q_data)

  sidecar <- make_integration_sidecar(enabled = TRUE)
  sidecar$questions$Q1 <- list(
    ai_callout = list(
      has_insight      = TRUE,
      narrative        = "Pre-cached insight about Q1.",
      confidence       = "high",
      data_limitations = "",
      pinned           = TRUE,
      verified         = TRUE,
      data_hash        = data_hash
    )
  )
  write_test_sidecar(sidecar, tmp_path)

  Sys.unsetenv("NONEXISTENT_INTEGRATION_KEY")

  suppressWarnings({
    result <- generate_all_insights(all_results, banner_info, config_obj, tmp_path)
  })

  # Q1 should retain its cached callout (hash matches)
  q1_callout <- result$callouts$Q1$ai_callout
  expect_false(is.null(q1_callout))
  expect_equal(q1_callout$narrative, "Pre-cached insight about Q1.")
  expect_true(q1_callout$pinned)
})

# ==============================================================================
# TESTS: Idempotency
# ==============================================================================

context("generate_all_insights — idempotency")

test_that("manually suppressed callouts are not regenerated", {
  all_results <- make_integration_all_results()
  banner_info <- make_integration_banner_info()
  config_obj  <- make_integration_config_obj()

  tmp_path <- tempfile(fileext = "_ai_insights.json")
  on.exit(unlink(tmp_path))

  # Pre-populate with a suppressed callout (has_insight=FALSE, with hash)
  q_data <- extract_question_data(all_results[["Q1"]], banner_info)
  data_hash <- compute_data_hash(q_data)

  sidecar <- make_integration_sidecar(enabled = TRUE)
  sidecar$questions$Q1 <- list(
    ai_callout = list(
      has_insight      = FALSE,
      narrative        = "",
      confidence       = "high",
      data_limitations = "",
      pinned           = FALSE,
      verified         = TRUE,
      data_hash        = data_hash
    )
  )
  write_test_sidecar(sidecar, tmp_path)

  Sys.unsetenv("NONEXISTENT_INTEGRATION_KEY")

  suppressWarnings({
    result <- generate_all_insights(all_results, banner_info, config_obj, tmp_path)
  })

  # Q1 should still have has_insight=FALSE (suppressed, hash matches, not regenerated)
  q1_callout <- result$callouts$Q1$ai_callout
  expect_false(is.null(q1_callout))
  expect_false(q1_callout$has_insight)
})

test_that("edited narrative text is preserved when data unchanged", {
  all_results <- make_integration_all_results()
  banner_info <- make_integration_banner_info()
  config_obj  <- make_integration_config_obj()

  tmp_path <- tempfile(fileext = "_ai_insights.json")
  on.exit(unlink(tmp_path))

  q_data <- extract_question_data(all_results[["Q2"]], banner_info)
  data_hash <- compute_data_hash(q_data)

  sidecar <- make_integration_sidecar(enabled = TRUE)
  sidecar$questions$Q2 <- list(
    ai_callout = list(
      has_insight      = TRUE,
      narrative        = "Researcher-edited narrative text.",
      confidence       = "high",
      data_limitations = "",
      pinned           = TRUE,
      verified         = TRUE,
      data_hash        = data_hash
    )
  )
  write_test_sidecar(sidecar, tmp_path)

  Sys.unsetenv("NONEXISTENT_INTEGRATION_KEY")

  suppressWarnings({
    result <- generate_all_insights(all_results, banner_info, config_obj, tmp_path)
  })

  # Q2 narrative should be preserved (researcher edit, hash matches)
  q2_callout <- result$callouts$Q2$ai_callout
  expect_equal(q2_callout$narrative, "Researcher-edited narrative text.")
  expect_true(q2_callout$pinned)
})

# ==============================================================================
# TESTS: Model display name
# ==============================================================================

context("generate_all_insights — model attribution")

test_that("result includes model_display_name", {
  all_results <- make_integration_all_results()
  banner_info <- make_integration_banner_info()
  config_obj  <- make_integration_config_obj()

  tmp_path <- tempfile(fileext = "_ai_insights.json")
  on.exit(unlink(tmp_path))

  sidecar <- make_integration_sidecar(enabled = TRUE)
  sidecar$config$generate_per_question <- FALSE
  write_test_sidecar(sidecar, tmp_path)

  suppressWarnings({
    result <- generate_all_insights(all_results, banner_info, config_obj, tmp_path)
  })

  expect_equal(result$model_display_name, "claude-sonnet-4-20250514 (Anthropic)")
})
