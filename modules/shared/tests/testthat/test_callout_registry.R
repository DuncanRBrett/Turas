# ==============================================================================
# TESTS: callout_registry.R
# ==============================================================================
# Tests for the shared callout registry system.
# Covers: loading, lookup, HTML generation, caching, module coverage.
# ==============================================================================

library(testthat)

# Source callout registry
turas_root <- Sys.getenv("TURAS_ROOT", getwd())
callout_path <- file.path(turas_root, "modules", "shared", "lib", "callouts", "callout_registry.R")
if (!file.exists(callout_path)) {
  callout_path <- file.path("modules", "shared", "lib", "callouts", "callout_registry.R")
}
if (file.exists(callout_path)) source(callout_path)

skip_if_not(exists("turas_callout", mode = "function"),
            message = "Callout registry not available")


# ==============================================================================
# CALLOUT LOADING
# ==============================================================================

test_that("callout registry loads without errors", {
  # Clear cache first
  turas_callout_clear_cache()
  expect_silent(turas_callout_text("keydriver", "shapley_importance"))
})

test_that("turas_callout_list returns data frame with expected columns", {
  turas_callout_clear_cache()
  df <- turas_callout_list()
  expect_s3_class(df, "data.frame")
  expect_true("module" %in% names(df))
  expect_true("key" %in% names(df))
  expect_true("title" %in% names(df))
  expect_true(nrow(df) > 0)
})


# ==============================================================================
# CALLOUT LOOKUP
# ==============================================================================

test_that("turas_callout_text returns entry for valid module/key", {
  entry <- turas_callout_text("keydriver", "shapley_importance")
  expect_true(!is.null(entry))
  expect_true(!is.null(entry$title))
  expect_true(!is.null(entry$text))
  expect_true(nzchar(entry$title))
  expect_true(nzchar(entry$text))
})

test_that("turas_callout_text returns NULL for invalid module", {
  entry <- turas_callout_text("nonexistent_module", "some_key")
  expect_null(entry)
})

test_that("turas_callout_text returns NULL for invalid key", {
  entry <- turas_callout_text("keydriver", "nonexistent_key")
  expect_null(entry)
})


# ==============================================================================
# HTML GENERATION
# ==============================================================================

test_that("turas_callout returns HTML string for valid entry", {
  html <- turas_callout("keydriver", "shapley_importance")
  expect_true(is.character(html))
  expect_true(nzchar(html))
  expect_true(grepl("t-callout", html))
  expect_true(grepl("data-turas-callout", html))
  expect_true(grepl("How is the final importance", html))
})

test_that("turas_callout returns empty string for invalid entry", {
  html <- turas_callout("nonexistent", "nonexistent")
  expect_equal(html, "")
})

test_that("turas_callout respects collapsed parameter", {
  html_open <- turas_callout("keydriver", "shapley_importance", collapsed = FALSE)
  html_closed <- turas_callout("keydriver", "shapley_importance", collapsed = TRUE)

  # Check the CSS class on the div, not the onclick handler which always contains "collapsed"
  expect_false(grepl("t-callout collapsed", html_open))
  expect_true(grepl("t-callout collapsed", html_closed))
})

test_that("turas_callout_html builds from direct content", {
  html <- turas_callout_html(
    title = "Test Title",
    body = "Test body content"
  )

  expect_true(grepl("t-callout", html))
  expect_true(grepl("Test Title", html))
  expect_true(grepl("Test body content", html))
})

test_that("turas_callout_html includes registry key tag", {
  html <- turas_callout_html(
    title = "Test",
    body = "Body",
    registry_key = "module / key_name"
  )

  expect_true(grepl("t-callout-key", html))
  expect_true(grepl("module / key_name", html))
})

test_that("callouts are excluded from pins via data attribute", {
  html <- turas_callout("confidence", "results_overview")
  expect_true(grepl('data-turas-callout="true"', html))
})


# ==============================================================================
# CACHE
# ==============================================================================

test_that("turas_callout_clear_cache forces reload", {
  # Load once
  turas_callout_text("keydriver", "shapley_importance")
  # Clear
  result <- turas_callout_clear_cache()
  expect_true(result)
  # Load again (should work from fresh)
  entry <- turas_callout_text("keydriver", "shapley_importance")
  expect_true(!is.null(entry))
})


# ==============================================================================
# MODULE COVERAGE
# ==============================================================================

test_that("all analytical modules have callout entries", {
  df <- turas_callout_list()
  modules_with_callouts <- unique(df$module)

  # These modules should all have callout entries
  expected_modules <- c(
    "keydriver", "catdriver", "confidence", "conjoint",
    "maxdiff", "segment", "weighting", "pricing", "tracker", "tabs"
  )

  for (mod in expected_modules) {
    expect_true(
      mod %in% modules_with_callouts,
      info = paste0("Module '", mod, "' is missing from callouts.json")
    )
  }
})

test_that("all callout entries have required fields", {
  turas_callout_clear_cache()
  df <- turas_callout_list()

  for (i in seq_len(nrow(df))) {
    entry <- turas_callout_text(df$module[i], df$key[i])
    expect_true(!is.null(entry$title),
                info = paste0(df$module[i], "/", df$key[i], " missing title"))
    expect_true(!is.null(entry$text),
                info = paste0(df$module[i], "/", df$key[i], " missing text"))
    expect_true(nzchar(entry$title),
                info = paste0(df$module[i], "/", df$key[i], " has empty title"))
    expect_true(nzchar(entry$text),
                info = paste0(df$module[i], "/", df$key[i], " has empty text"))
  }
})
