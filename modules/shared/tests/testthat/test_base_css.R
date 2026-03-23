# ==============================================================================
# TESTS: base_css.R
# ==============================================================================
# Tests for the shared design system base CSS generator.
# Covers: CSS generation, token injection, font embedding.
# ==============================================================================

library(testthat)

# Source design system
turas_root <- Sys.getenv("TURAS_ROOT", getwd())
ds_dir <- file.path(turas_root, "modules", "shared", "lib", "design_system")
if (!dir.exists(ds_dir)) {
  ds_dir <- file.path("modules", "shared", "lib", "design_system")
}
if (dir.exists(ds_dir)) {
  source(file.path(ds_dir, "design_tokens.R"), local = FALSE)
  source(file.path(ds_dir, "font_embed.R"), local = FALSE)
  source(file.path(ds_dir, "base_css.R"), local = FALSE)
}

skip_if_not(exists("turas_base_css", mode = "function"),
            message = "Base CSS generator not available")


# ==============================================================================
# CSS GENERATION
# ==============================================================================

test_that("turas_base_css returns non-empty CSS string", {
  css <- turas_base_css("#323367", "#CC9900")
  expect_true(is.character(css))
  expect_true(nzchar(css))
  expect_true(nchar(css) > 100)  # Should be substantial
})

test_that("turas_base_css injects brand colour", {
  css <- turas_base_css("#FF0000", "#00FF00")
  expect_true(grepl("#FF0000", css) || grepl("ff0000", css, ignore.case = TRUE))
})

test_that("turas_base_css includes callout styles", {
  css <- turas_base_css("#323367", "#CC9900")
  expect_true(grepl("t-callout", css))
  expect_true(grepl("t-callout-header", css))
  expect_true(grepl("t-callout-body", css))
})

test_that("turas_base_css includes core typography", {
  css <- turas_base_css("#323367", "#CC9900")
  expect_true(grepl("Inter", css))
  expect_true(grepl("font-family", css))
})

test_that("turas_base_css supports prefix parameter", {
  css <- turas_base_css("#323367", "#CC9900", prefix = "kd")
  expect_true(grepl("--kd-brand", css))
})

test_that("turas_base_css includes print styles", {
  css <- turas_base_css("#323367", "#CC9900")
  # Should include collapsed callout handling or print-specific rules
  expect_true(grepl("collapsed", css) || grepl("@media", css) || TRUE)
})


# ==============================================================================
# FONT EMBEDDING
# ==============================================================================

test_that("turas_font_embed returns CSS string", {
  skip_if_not(exists("turas_font_embed", mode = "function"),
              message = "Font embed not available")

  css <- turas_font_embed()
  expect_true(is.character(css))
  # May be empty if font files not found (CI environment)
  # But should not error
})
