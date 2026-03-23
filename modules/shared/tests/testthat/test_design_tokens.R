# ==============================================================================
# TESTS: design_tokens.R
# ==============================================================================
# Tests for the shared design system tokens.
# Covers: token completeness, CSS variable generation, prefix support.
# ==============================================================================

library(testthat)

# Source design tokens
turas_root <- Sys.getenv("TURAS_ROOT", getwd())
tokens_path <- file.path(turas_root, "modules", "shared", "lib", "design_system", "design_tokens.R")
if (!file.exists(tokens_path)) {
  tokens_path <- file.path("modules", "shared", "lib", "design_system", "design_tokens.R")
}
if (file.exists(tokens_path)) source(tokens_path)

skip_if_not(exists("turas_design_tokens", mode = "function"),
            message = "Design tokens not available")


# ==============================================================================
# TOKEN STRUCTURE
# ==============================================================================

test_that("turas_design_tokens returns complete token set", {
  tokens <- turas_design_tokens()

  # Typography
  expect_true(!is.null(tokens$font_family))
  expect_true(!is.null(tokens$font_family_mono))
  expect_true(!is.null(tokens$font_size_base))
  expect_true(!is.null(tokens$font_weight_normal))
  expect_true(!is.null(tokens$line_height_normal))

  # Spacing
  expect_true(!is.null(tokens$space_1))
  expect_true(!is.null(tokens$space_4))
  expect_true(!is.null(tokens$space_8))

  # Colours
  expect_true(!is.null(tokens$brand))
  expect_true(!is.null(tokens$accent))
  expect_true(!is.null(tokens$text_primary))
  expect_true(!is.null(tokens$text_secondary))
  expect_true(!is.null(tokens$bg_page))
  expect_true(!is.null(tokens$bg_surface))

  # Borders & Radii
  expect_true(!is.null(tokens$border_default))
  expect_true(!is.null(tokens$radius_sm))
  expect_true(!is.null(tokens$radius_md))

  # Shadows
  expect_true(!is.null(tokens$shadow_sm))
  expect_true(!is.null(tokens$shadow_card))

  # Chart tokens
  expect_true(!is.null(tokens$chart_bar_radius))
  expect_true(!is.null(tokens$chart_label_colour))
  expect_true(!is.null(tokens$chart_value_weight))

  # Table tokens
  expect_true(!is.null(tokens$table_header_bg))
  expect_true(!is.null(tokens$table_row_hover))
})

test_that("turas_design_tokens accepts custom brand colours", {
  tokens <- turas_design_tokens(brand_colour = "#FF0000", accent_colour = "#00FF00")
  expect_equal(tokens$brand, "#FF0000")
  expect_equal(tokens$accent, "#00FF00")
})

test_that("turas_design_tokens defaults are valid hex colours", {
  tokens <- turas_design_tokens()

  hex_pattern <- "^#[0-9a-fA-F]{6}$"
  expect_true(grepl(hex_pattern, tokens$brand))
  expect_true(grepl(hex_pattern, tokens$accent))
  expect_true(grepl(hex_pattern, tokens$text_primary))
  expect_true(grepl(hex_pattern, tokens$text_secondary))
  expect_true(grepl(hex_pattern, tokens$bg_page))
  expect_true(grepl(hex_pattern, tokens$bg_surface))
  expect_true(grepl(hex_pattern, tokens$border_default))
  expect_true(grepl(hex_pattern, tokens$status_success))
  expect_true(grepl(hex_pattern, tokens$status_error))
})

test_that("turas_design_tokens spacing scale is consistent", {
  tokens <- turas_design_tokens()

  # Extract px values
  px <- function(token) as.numeric(gsub("px", "", token))

  expect_equal(px(tokens$space_1), 4)
  expect_equal(px(tokens$space_2), 8)
  expect_equal(px(tokens$space_4), 16)
  expect_equal(px(tokens$space_8), 32)
})


# ==============================================================================
# CSS VARIABLE GENERATION
# ==============================================================================

test_that("turas_css_variables generates valid CSS", {
  skip_if_not(exists("turas_css_variables", mode = "function"),
              message = "turas_css_variables not available")

  css <- turas_css_variables()

  expect_true(is.character(css))
  expect_true(nzchar(css))
  expect_true(grepl(":root", css))
  expect_true(grepl("--t-brand:", css))
  expect_true(grepl("--t-accent:", css))
  expect_true(grepl("--t-text-primary:", css))
  expect_true(grepl("--t-bg-page:", css))
})

test_that("turas_css_variables supports custom prefix", {
  skip_if_not(exists("turas_css_variables", mode = "function"),
              message = "turas_css_variables not available")

  css <- turas_css_variables(prefix = "kd")
  expect_true(grepl("--kd-brand:", css))
  expect_true(grepl("--kd-accent:", css))

  css2 <- turas_css_variables(prefix = "ct")
  expect_true(grepl("--ct-brand:", css2))
})

test_that("turas_css_variables includes legacy aliases", {
  skip_if_not(exists("turas_css_variables", mode = "function"),
              message = "turas_css_variables not available")

  css <- turas_css_variables()
  expect_true(grepl("--brand-colour:", css))
  expect_true(grepl("--ct-brand:", css))
})

test_that("turas_css_variables injects custom brand colour", {
  skip_if_not(exists("turas_css_variables", mode = "function"),
              message = "turas_css_variables not available")

  css <- turas_css_variables(brand_colour = "#ABCDEF")
  expect_true(grepl("#ABCDEF", css))
})
