# ==============================================================================
# TABS MODULE - AI VERIFY TESTS
# ==============================================================================
#
# Tests for AI verification and selectivity passes:
#   - verify_callout()  — factual accuracy checking
#   - rank_callouts()   — editorial quality filtering
#
# These tests use mock prompt builders and do NOT make real API calls.
# They test the logic flow, not the LLM output quality.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_ai_verify.R")
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

source(file.path(turas_root, "modules/shared/lib/ai/ai_provider.R"))
source(file.path(turas_root, "modules/shared/lib/ai/ai_schemas.R"))
source(file.path(turas_root, "modules/shared/lib/ai/ai_verify.R"))

# ==============================================================================
# HELPERS / MOCK FUNCTIONS
# ==============================================================================

make_test_callout <- function(has_insight = TRUE, narrative = "NPS of +7 is notable.",
                              confidence = "high") {
  list(
    has_insight      = has_insight,
    narrative        = narrative,
    confidence       = confidence,
    data_limitations = "",
    pinned           = FALSE
  )
}

make_test_question_data <- function() {
  list(
    q_code          = "Q001",
    q_title         = "Overall NPS",
    q_type          = "NPS",
    response_labels = c("Promoter", "Passive", "Detractor"),
    results         = list(Total = c(40, 35, 25)),
    significance    = list(),
    base_sizes      = list(Total = 100)
  )
}

make_test_ai_config <- function(verify = TRUE, rank = TRUE) {
  list(
    provider                  = "anthropic",
    model                     = "claude-sonnet-4-20250514",
    api_key_env               = "NONEXISTENT_TEST_KEY",
    verify_callouts           = verify,
    rank_callouts             = rank,
    max_verification_attempts = 2L,
    max_tokens                = 1500L,
    temperature               = 0.3
  )
}

# Mock prompt builder that returns a valid prompt structure
mock_build_prompt <- function(data, study_context, prompt_type) {
  list(
    system = sprintf("Mock system prompt for %s", prompt_type),
    user   = sprintf("Mock user prompt for %s", prompt_type)
  )
}

# Mock prompt builder that throws an error
mock_build_prompt_error <- function(data, study_context, prompt_type) {
  stop("Prompt construction failed")
}

# ==============================================================================
# TESTS: verify_callout — Skip / pass-through cases
# ==============================================================================

context("verify_callout — skip and pass-through")

test_that("skips verification when verify_callouts is FALSE", {
  config <- make_test_ai_config(verify = FALSE)
  callout <- make_test_callout()
  q_data <- make_test_question_data()

  result <- verify_callout(callout, q_data, config, mock_build_prompt)
  expect_true(result$verified)
  expect_equal(result$narrative, callout$narrative)
})

test_that("skips verification when has_insight is FALSE", {
  config <- make_test_ai_config(verify = TRUE)
  callout <- make_test_callout(has_insight = FALSE)
  q_data <- make_test_question_data()

  result <- verify_callout(callout, q_data, config, mock_build_prompt)
  expect_true(result$verified)
})

test_that("returns verified=FALSE when prompt builder fails", {
  config <- make_test_ai_config(verify = TRUE)
  callout <- make_test_callout()
  q_data <- make_test_question_data()

  expect_warning(
    result <- verify_callout(callout, q_data, config, mock_build_prompt_error),
    "Failed to build verification prompt"
  )
  expect_false(result$verified)
})

test_that("returns verified=FALSE when LLM call fails (missing API key)", {
  config <- make_test_ai_config(verify = TRUE)
  Sys.unsetenv("NONEXISTENT_TEST_KEY")
  callout <- make_test_callout()
  q_data <- make_test_question_data()

  # call_insight_model will fail due to missing API key
  suppressWarnings({
    result <- verify_callout(callout, q_data, config, mock_build_prompt)
  })
  expect_false(result$verified)
})

test_that("preserves callout fields through verification", {
  config <- make_test_ai_config(verify = FALSE)
  callout <- make_test_callout(narrative = "Specific narrative text")
  callout$pinned <- TRUE
  callout$confidence <- "medium"
  q_data <- make_test_question_data()

  result <- verify_callout(callout, q_data, config, mock_build_prompt)
  expect_equal(result$narrative, "Specific narrative text")
  expect_true(result$pinned)
  expect_equal(result$confidence, "medium")
})

# ==============================================================================
# TESTS: rank_callouts — Skip and pass-through
# ==============================================================================

context("rank_callouts — skip and pass-through")

test_that("skips ranking when rank_callouts is FALSE", {
  config <- make_test_ai_config(rank = FALSE)
  callouts <- list(
    Q001 = make_test_callout(narrative = "Callout 1"),
    Q002 = make_test_callout(narrative = "Callout 2"),
    Q003 = make_test_callout(narrative = "Callout 3")
  )

  result <- rank_callouts(callouts, config, mock_build_prompt)
  # All should be unchanged
  expect_true(result$Q001$has_insight)
  expect_true(result$Q002$has_insight)
  expect_true(result$Q003$has_insight)
})

test_that("skips ranking when fewer than 3 active callouts", {
  config <- make_test_ai_config(rank = TRUE)
  callouts <- list(
    Q001 = make_test_callout(narrative = "Callout 1"),
    Q002 = make_test_callout(narrative = "Callout 2")
  )

  result <- rank_callouts(callouts, config, mock_build_prompt)
  expect_true(result$Q001$has_insight)
  expect_true(result$Q002$has_insight)
})

test_that("skips callouts with has_insight FALSE in ranking input", {
  config <- make_test_ai_config(rank = TRUE)
  callouts <- list(
    Q001 = make_test_callout(narrative = "Callout 1"),
    Q002 = make_test_callout(has_insight = FALSE),
    Q003 = make_test_callout(narrative = "Callout 3")
  )

  # Only 2 active callouts (Q001, Q003), so skip ranking
  result <- rank_callouts(callouts, config, mock_build_prompt)
  expect_true(result$Q001$has_insight)
  expect_false(result$Q002$has_insight)
  expect_true(result$Q003$has_insight)
})

test_that("fails open when prompt builder errors", {
  config <- make_test_ai_config(rank = TRUE)
  callouts <- list(
    Q001 = make_test_callout(narrative = "Callout 1"),
    Q002 = make_test_callout(narrative = "Callout 2"),
    Q003 = make_test_callout(narrative = "Callout 3")
  )

  expect_warning(
    result <- rank_callouts(callouts, config, mock_build_prompt_error),
    "Failed to build selectivity prompt"
  )
  # All callouts retained (fail-open)
  expect_true(result$Q001$has_insight)
  expect_true(result$Q002$has_insight)
  expect_true(result$Q003$has_insight)
})

test_that("fails open when LLM call fails", {
  config <- make_test_ai_config(rank = TRUE)
  Sys.unsetenv("NONEXISTENT_TEST_KEY")
  callouts <- list(
    Q001 = make_test_callout(narrative = "Callout 1"),
    Q002 = make_test_callout(narrative = "Callout 2"),
    Q003 = make_test_callout(narrative = "Callout 3")
  )

  suppressWarnings({
    result <- rank_callouts(callouts, config, mock_build_prompt)
  })
  # All callouts retained (fail-open)
  expect_true(result$Q001$has_insight)
  expect_true(result$Q002$has_insight)
  expect_true(result$Q003$has_insight)
})

test_that("passes question_titles to prompt builder", {
  config <- make_test_ai_config(rank = TRUE)
  callouts <- list(
    Q001 = make_test_callout(narrative = "Callout 1"),
    Q002 = make_test_callout(narrative = "Callout 2"),
    Q003 = make_test_callout(narrative = "Callout 3")
  )
  titles <- c(Q001 = "Overall Satisfaction", Q002 = "NPS Score", Q003 = "Delivery")

  # With titles, the prompt should include them
  captured_data <- NULL
  capture_prompt <- function(data, study_context, prompt_type) {
    captured_data <<- data
    list(system = "test", user = "test")
  }

  Sys.unsetenv("NONEXISTENT_TEST_KEY")
  suppressWarnings({
    rank_callouts(callouts, config, capture_prompt, question_titles = titles)
  })

  # Verify titles were passed through
  expect_false(is.null(captured_data))
  expect_equal(captured_data$Q001$q_title, "Overall Satisfaction")
  expect_equal(captured_data$Q002$q_title, "NPS Score")
})

test_that("handles NULL callouts gracefully", {
  config <- make_test_ai_config(rank = TRUE)
  callouts <- list(
    Q001 = make_test_callout(narrative = "Callout 1"),
    Q002 = NULL,
    Q003 = make_test_callout(narrative = "Callout 3")
  )

  # Should not error — NULL entries are skipped
  suppressWarnings({
    result <- rank_callouts(callouts, config, mock_build_prompt)
  })
  expect_true(result$Q001$has_insight)
  expect_null(result$Q002)
  expect_true(result$Q003$has_insight)
})
