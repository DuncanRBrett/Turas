# ==============================================================================
# TABS MODULE - AI UTILS TESTS
# ==============================================================================
#
# Tests for shared AI utility functions:
#   - build_sidecar_path()      — path derivation
#   - read_ai_sidecar()         — JSON sidecar loading
#   - write_ai_sidecar()        — atomic JSON sidecar writing
#   - compute_data_hash()       — content-hash caching
#   - is_callout_cache_valid()  — cache validity checking
#   - estimate_tokens()         — token count estimation
#   - create_default_sidecar()  — template generation
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_ai_utils.R")
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

source(file.path(turas_root, "modules/shared/lib/ai/ai_utils.R"))

# ==============================================================================
# HELPERS
# ==============================================================================

make_test_sidecar <- function() {
  list(
    version      = "1.0",
    generated_at = "2026-04-03T14:30:00",
    config = list(
      enabled  = TRUE,
      provider = "anthropic",
      model    = "claude-sonnet-4-20250514"
    ),
    questions = list(
      Q001 = list(
        ai_callout = list(
          has_insight      = TRUE,
          narrative        = "The NPS of +7 masks a segment divide.",
          confidence       = "high",
          data_limitations = "",
          pinned           = FALSE,
          verified         = TRUE,
          data_hash        = "abc123def456"
        )
      )
    ),
    executive_summary = list(
      narrative        = "This study reveals interesting patterns.",
      confidence       = "high",
      data_limitations = ""
    )
  )
}

make_test_question_data <- function() {
  list(
    q_code          = "Q001",
    q_title         = "Overall Satisfaction",
    q_type          = "Likert",
    response_labels = c("Very satisfied", "Satisfied", "Neutral"),
    results         = list(Total = c(45, 35, 20)),
    significance    = list(),
    base_sizes      = list(Total = 100)
  )
}

# ==============================================================================
# TESTS: build_sidecar_path
# ==============================================================================

context("build_sidecar_path")

test_that("derives correct path from xlsx config", {
  result <- build_sidecar_path("projects/Demo_CX_Crosstabs.xlsx")
  expect_equal(result, "projects/Demo_CX_Crosstabs_ai_insights.json")
})

test_that("handles path with multiple dots", {
  result <- build_sidecar_path("dir.name/file.name.xlsx")
  expect_equal(result, "dir.name/file.name_ai_insights.json")
})

test_that("handles path without extension", {
  result <- build_sidecar_path("projects/config_file")
  expect_equal(result, "projects/config_file_ai_insights.json")
})

test_that("returns NULL for NULL input", {
  expect_null(build_sidecar_path(NULL))
})

test_that("returns NULL for empty string", {
  expect_null(build_sidecar_path(""))
})

# ==============================================================================
# TESTS: read_ai_sidecar / write_ai_sidecar
# ==============================================================================

context("read_ai_sidecar and write_ai_sidecar")

test_that("returns NULL when sidecar does not exist", {
  tmp_config <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp_config))

  result <- read_ai_sidecar(tmp_config)
  expect_null(result)
})

test_that("write then read round-trips correctly", {
  tmp_config <- tempfile(fileext = ".xlsx")
  sidecar_path <- build_sidecar_path(tmp_config)
  on.exit({
    unlink(tmp_config)
    unlink(sidecar_path)
  })

  sidecar <- make_test_sidecar()
  success <- write_ai_sidecar(sidecar, tmp_config)
  expect_true(success)
  expect_true(file.exists(sidecar_path))

  # Read it back
  loaded <- read_ai_sidecar(tmp_config)
  expect_false(is.null(loaded))
  expect_equal(loaded$version, "1.0")
  expect_equal(loaded$config$provider, "anthropic")
  expect_equal(loaded$questions$Q001$ai_callout$narrative,
               "The NPS of +7 masks a segment divide.")
  expect_true(loaded$questions$Q001$ai_callout$has_insight)
  expect_equal(loaded$questions$Q001$ai_callout$data_hash, "abc123def456")
})

test_that("atomic write does not leave temp files on success", {
  tmp_config <- tempfile(fileext = ".xlsx")
  sidecar_path <- build_sidecar_path(tmp_config)
  on.exit({
    unlink(tmp_config)
    unlink(sidecar_path)
  })

  sidecar <- make_test_sidecar()
  write_ai_sidecar(sidecar, tmp_config)

  tmp_file <- paste0(sidecar_path, ".tmp")
  expect_false(file.exists(tmp_file))
})

test_that("write returns FALSE on NULL config path", {
  expect_warning(
    result <- write_ai_sidecar(list(), NULL),
    "Cannot write AI sidecar"
  )
  expect_false(result)
})

test_that("write returns FALSE on empty config path", {
  expect_warning(
    result <- write_ai_sidecar(list(), ""),
    "Cannot write AI sidecar"
  )
  expect_false(result)
})

test_that("read handles corrupted JSON gracefully", {
  tmp_config <- tempfile(fileext = ".xlsx")
  sidecar_path <- build_sidecar_path(tmp_config)
  on.exit({
    unlink(tmp_config)
    unlink(sidecar_path)
  })

  writeLines("{ this is not valid json !!!", sidecar_path)
  expect_warning(
    result <- read_ai_sidecar(tmp_config),
    "Failed to read AI sidecar"
  )
  expect_null(result)
})

test_that("write updates generated_at timestamp", {
  tmp_config <- tempfile(fileext = ".xlsx")
  sidecar_path <- build_sidecar_path(tmp_config)
  on.exit({
    unlink(tmp_config)
    unlink(sidecar_path)
  })

  sidecar <- list(config = list(enabled = TRUE))
  write_ai_sidecar(sidecar, tmp_config)

  loaded <- read_ai_sidecar(tmp_config)
  expect_true(!is.null(loaded$generated_at))
  expect_true(nzchar(loaded$generated_at))
})

# ==============================================================================
# TESTS: compute_data_hash
# ==============================================================================

context("compute_data_hash")

test_that("returns consistent hash for identical data", {
  data <- make_test_question_data()
  hash1 <- compute_data_hash(data)
  hash2 <- compute_data_hash(data)
  expect_equal(hash1, hash2)
})

test_that("returns different hash for different data", {
  data1 <- make_test_question_data()
  data2 <- make_test_question_data()
  data2$results$Total <- c(50, 30, 20)  # Changed values

  hash1 <- compute_data_hash(data1)
  hash2 <- compute_data_hash(data2)
  expect_false(identical(hash1, hash2))
})

test_that("hash is a 32-character MD5 string", {
  data <- make_test_question_data()
  hash <- compute_data_hash(data)
  expect_true(is.character(hash))
  expect_equal(nchar(hash), 32L)
  expect_true(grepl("^[0-9a-f]{32}$", hash))
})

test_that("hash changes when response labels change", {
  data1 <- make_test_question_data()
  data2 <- make_test_question_data()
  data2$response_labels <- c("Excellent", "Good", "Fair")

  expect_false(identical(compute_data_hash(data1), compute_data_hash(data2)))
})

# ==============================================================================
# TESTS: is_callout_cache_valid
# ==============================================================================

context("is_callout_cache_valid")

test_that("returns TRUE when hashes match", {
  callout <- list(has_insight = TRUE, data_hash = "abc123")
  expect_true(is_callout_cache_valid(callout, "abc123"))
})

test_that("returns FALSE when hashes differ", {
  callout <- list(has_insight = TRUE, data_hash = "abc123")
  expect_false(is_callout_cache_valid(callout, "def456"))
})

test_that("returns FALSE for NULL callout", {
  expect_false(is_callout_cache_valid(NULL, "abc123"))
})

test_that("returns FALSE when callout has no data_hash", {
  callout <- list(has_insight = TRUE)
  expect_false(is_callout_cache_valid(callout, "abc123"))
})

# ==============================================================================
# TESTS: estimate_tokens
# ==============================================================================

context("estimate_tokens")

test_that("returns positive numeric for non-empty payload", {
  data <- list(question = "How satisfied?", results = c(50, 30, 20))
  tokens <- estimate_tokens(data)
  expect_true(is.numeric(tokens))
  expect_true(tokens > 0)
})

test_that("larger payloads produce larger estimates", {
  small <- list(x = 1)
  large <- list(x = rep(1, 1000), y = rep("long string here", 500))

  small_tokens <- estimate_tokens(small)
  large_tokens <- estimate_tokens(large)
  expect_true(large_tokens > small_tokens)
})

test_that("estimate is roughly nchar/4", {
  data <- list(text = paste(rep("word", 100), collapse = " "))
  json_len <- nchar(jsonlite::toJSON(data, auto_unbox = TRUE))
  expected <- json_len / 4
  actual <- estimate_tokens(data)
  expect_equal(actual, expected, tolerance = 0.01)
})

# ==============================================================================
# TESTS: create_default_sidecar
# ==============================================================================

context("create_default_sidecar")

test_that("creates a valid sidecar template with defaults", {
  sidecar <- create_default_sidecar()

  expect_equal(sidecar$version, "1.0")
  expect_true(nzchar(sidecar$generated_at))
  expect_true(sidecar$config$enabled)
  expect_equal(sidecar$config$provider, "anthropic")
  expect_equal(sidecar$config$model, "claude-sonnet-4-20250514")
  expect_equal(sidecar$config$temperature, 0.3)
  expect_equal(sidecar$config$max_tokens, 1500L)
  expect_true(sidecar$config$verify_callouts)
  expect_true(sidecar$config$rank_callouts)
  expect_true(sidecar$config$generate_exec_summary)
  expect_true(sidecar$config$generate_per_question)
  expect_true(sidecar$config$exec_summary_reviewed)
  expect_false(sidecar$config$easystats_narration)
  expect_equal(sidecar$config$max_verification_attempts, 2L)
  expect_equal(sidecar$config$api_key_env, "ANTHROPIC_API_KEY")
  expect_true(is.list(sidecar$questions))
  expect_equal(length(sidecar$questions), 0L)
  expect_null(sidecar$executive_summary)
})

test_that("accepts custom provider and model", {
  sidecar <- create_default_sidecar(provider = "openai", model = "gpt-4.1")

  expect_equal(sidecar$config$provider, "openai")
  expect_equal(sidecar$config$model, "gpt-4.1")
})

test_that("default sidecar round-trips through JSON", {
  sidecar <- create_default_sidecar()

  tmp_config <- tempfile(fileext = ".xlsx")
  sidecar_path <- build_sidecar_path(tmp_config)
  on.exit({
    unlink(tmp_config)
    unlink(sidecar_path)
  })

  write_ai_sidecar(sidecar, tmp_config)
  loaded <- read_ai_sidecar(tmp_config)

  expect_equal(loaded$config$provider, "anthropic")
  expect_equal(loaded$config$temperature, 0.3)
  expect_true(loaded$config$enabled)
})
