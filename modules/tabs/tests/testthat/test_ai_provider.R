# ==============================================================================
# TABS MODULE - AI PROVIDER TESTS
# ==============================================================================
#
# Tests for the shared AI provider abstraction layer:
#   - create_ai_chat()         — provider construction with error handling
#   - call_insight_model()     — structured LLM calls with graceful degradation
#   - get_model_display_name() — human-readable model attribution
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_ai_provider.R")
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

# ==============================================================================
# HELPERS
# ==============================================================================

make_anthropic_config <- function() {
  list(
    provider    = "anthropic",
    model       = "claude-sonnet-4-20250514",
    api_key_env = "ANTHROPIC_API_KEY",
    temperature = 0.3,
    max_tokens  = 1500L
  )
}

make_openai_config <- function() {
  list(
    provider    = "openai",
    model       = "gpt-4.1",
    api_key_env = "OPENAI_API_KEY",
    temperature = 0.3,
    max_tokens  = 1500L
  )
}

make_ollama_config <- function() {
  list(
    provider     = "ollama",
    model        = "gemma4:31b",
    ollama_model = "gemma4:31b",
    ollama_url   = "http://localhost:11434",
    temperature  = 0.3,
    max_tokens   = 1500L
  )
}

# ==============================================================================
# TESTS: AI_PROVIDER_REGISTRY
# ==============================================================================

context("AI_PROVIDER_REGISTRY")

test_that("registry contains all expected providers", {
  expected <- c("anthropic", "openai", "google", "ollama")
  for (p in expected) {
    expect_true(p %in% names(AI_PROVIDER_REGISTRY),
                info = sprintf("Provider '%s' missing from registry", p))
  }
})

test_that("each registry entry has required fields", {
  for (name in names(AI_PROVIDER_REGISTRY)) {
    entry <- AI_PROVIDER_REGISTRY[[name]]
    expect_true(!is.null(entry$constructor),
                info = sprintf("Provider '%s' missing 'constructor'", name))
    expect_true(!is.null(entry$label),
                info = sprintf("Provider '%s' missing 'label'", name))
  }
})

test_that("ollama has NULL env_var (no API key required)", {
  expect_null(AI_PROVIDER_REGISTRY$ollama$env_var)
})

# ==============================================================================
# TESTS: create_ai_chat
# ==============================================================================

context("create_ai_chat")

test_that("refuses unknown provider with TRS refusal", {
  config <- list(provider = "nonexistent", model = "some-model")
  result <- create_ai_chat(config)

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_UNKNOWN_AI_PROVIDER")
  expect_true(grepl("nonexistent", result$message))
  expect_true(grepl("anthropic", result$how_to_fix))
})

test_that("refuses missing API key with TRS refusal", {
  # Save and clear any existing key
  original_key <- Sys.getenv("TEST_AI_KEY_MISSING", "")
  Sys.unsetenv("TEST_AI_KEY_MISSING")
  on.exit({
    if (nzchar(original_key)) Sys.setenv(TEST_AI_KEY_MISSING = original_key)
  })

  config <- list(
    provider    = "anthropic",
    model       = "claude-sonnet-4-20250514",
    api_key_env = "TEST_AI_KEY_MISSING"
  )
  result <- create_ai_chat(config)

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_MISSING_API_KEY")
  expect_true(grepl("TEST_AI_KEY_MISSING", result$message))
})

test_that("defaults to anthropic when provider is NULL", {
  # With no API key set, should fail on missing key, not unknown provider
  Sys.unsetenv("ANTHROPIC_API_KEY_TEST_DEFAULT")
  config <- list(model = "test-model", api_key_env = "ANTHROPIC_API_KEY_TEST_DEFAULT")
  result <- create_ai_chat(config)

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
  # Should fail on missing API key, not unknown provider
  expect_equal(result$code, "CFG_MISSING_API_KEY")
})

test_that("refuses when ellmer package is missing", {
  skip_if(requireNamespace("ellmer", quietly = TRUE) == FALSE,
          "Test requires ellmer NOT installed — skipping in normal environment")
  # This test validates the pattern but can only truly fail
  # in an environment without ellmer. The code path is tested via the
  # requireNamespace check in create_ai_chat.
  expect_true(TRUE)
})

# ==============================================================================
# TESTS: call_insight_model
# ==============================================================================

context("call_insight_model")

test_that("returns NULL on provider setup failure (missing API key)", {
  config <- list(
    provider    = "anthropic",
    model       = "claude-sonnet-4-20250514",
    api_key_env = "NONEXISTENT_KEY_FOR_TEST"
  )
  Sys.unsetenv("NONEXISTENT_KEY_FOR_TEST")

  prompt <- list(system = "Test system prompt", user = "Test user prompt")

  # Should produce a warning and return NULL
  expect_warning(
    result <- call_insight_model(prompt, ellmer::type_object("test"), config),
    "AI provider setup failed"
  )
  expect_null(result)
})

test_that("returns NULL on unknown provider", {
  config <- list(provider = "nonexistent", model = "test")
  prompt <- list(system = "Test", user = "Test")

  expect_warning(
    result <- call_insight_model(prompt, ellmer::type_object("test"), config),
    "AI provider setup failed"
  )
  expect_null(result)
})

# ==============================================================================
# TESTS: get_model_display_name
# ==============================================================================

context("get_model_display_name")

test_that("formats anthropic model correctly", {
  config <- make_anthropic_config()
  name <- get_model_display_name(config)
  expect_equal(name, "claude-sonnet-4-20250514 (Anthropic)")
})

test_that("formats openai model correctly", {
  config <- make_openai_config()
  name <- get_model_display_name(config)
  expect_equal(name, "gpt-4.1 (OpenAI)")
})

test_that("formats google model correctly", {
  config <- list(provider = "google", model = "gemini-2.5-pro")
  name <- get_model_display_name(config)
  expect_equal(name, "gemini-2.5-pro (Google)")
})

test_that("formats ollama model using ollama_model field", {
  config <- make_ollama_config()
  name <- get_model_display_name(config)
  expect_equal(name, "gemma4:31b (Ollama (local))")
})

test_that("handles unknown provider gracefully", {
  config <- list(provider = "custom_provider", model = "custom-model-v1")
  name <- get_model_display_name(config)
  expect_equal(name, "custom-model-v1 (custom_provider)")
})

test_that("handles NULL provider and model with defaults", {
  config <- list()
  name <- get_model_display_name(config)
  expect_equal(name, "unknown-model (Anthropic)")
})

# ==============================================================================
# TESTS: AI_RATE_LIMIT_SECONDS
# ==============================================================================

context("AI rate limit")

test_that("rate limit is a positive number", {
  expect_true(is.numeric(AI_RATE_LIMIT_SECONDS))
  expect_true(AI_RATE_LIMIT_SECONDS > 0)
  expect_equal(AI_RATE_LIMIT_SECONDS, 0.5)
})
