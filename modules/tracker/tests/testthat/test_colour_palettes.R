# ==============================================================================
# Tests: Shared Colour Palette System
# ==============================================================================
# Exercises hsl_to_hex, hex_to_rgb, hex_to_hsl, get_sentiment_palette,
# get_segment_palette, get_categorical_palette, and get_rag_palette from
# modules/shared/lib/colour_palettes.R.
# ==============================================================================

library(testthat)
context("Shared Colour Palettes")

turas_root <- normalizePath(file.path(getwd(), "..", "..", "..", ".."), mustWork = FALSE)
palette_path <- file.path(turas_root, "modules", "shared", "lib", "colour_palettes.R")
source(palette_path)

# Helper: check a string matches #RRGGBB
is_valid_hex <- function(x) grepl("^#[0-9a-fA-F]{6}$", x)


# ==============================================================================
# HSL / RGB Conversion Tests
# ==============================================================================

test_that("hsl_to_hex returns black for (0, 0, 0)", {
  expect_equal(hsl_to_hex(0, 0, 0), "#000000")
})

test_that("hsl_to_hex returns white for (0, 0, 1)", {
  expect_equal(hsl_to_hex(0, 0, 1), "#ffffff")
})

test_that("hsl_to_hex returns pure red for (0, 1, 0.5)", {
  expect_equal(hsl_to_hex(0, 1, 0.5), "#ff0000")
})

test_that("hsl_to_hex returns pure green for (120, 1, 0.5)", {
  expect_equal(hsl_to_hex(120, 1, 0.5), "#00ff00")
})

test_that("hsl_to_hex returns pure blue for (240, 1, 0.5)", {
  expect_equal(hsl_to_hex(240, 1, 0.5), "#0000ff")
})

test_that("hsl_to_hex returns mid-grey for (0, 0, 0.5)", {
  result <- hsl_to_hex(0, 0, 0.5)
  rgb <- hex_to_rgb(result)
  # Mid-grey: all channels equal, near 128
  expect_equal(rgb[1], rgb[2])
  expect_equal(rgb[2], rgb[3])
  expect_true(abs(rgb[1] - 128) <= 1)
})

test_that("hex_to_rgb parses black correctly", {
  expect_equal(hex_to_rgb("#000000"), c(0, 0, 0))
})

test_that("hex_to_rgb parses white correctly", {
  expect_equal(hex_to_rgb("#ffffff"), c(255, 255, 255))
})

test_that("hex_to_rgb parses pure red correctly", {
  expect_equal(hex_to_rgb("#ff0000"), c(255, 0, 0))
})

test_that("hex_to_hsl converts pure red to h=0, s=1, l=0.5", {
  hsl <- hex_to_hsl("#ff0000")
  expect_equal(hsl$h, 0)
  expect_equal(hsl$s, 1)
  expect_equal(hsl$l, 0.5)
})

test_that("hex_to_hsl converts black to s=0, l=0", {
  hsl <- hex_to_hsl("#000000")
  expect_equal(hsl$s, 0)
  expect_equal(hsl$l, 0)
})

test_that("hex_to_hsl converts white to s=0, l=1", {
  hsl <- hex_to_hsl("#ffffff")
  expect_equal(hsl$s, 0)
  expect_equal(hsl$l, 1)
})

test_that("round-trip hex -> HSL -> hex is consistent for known colours", {
  test_colours <- c("#b85450", "#4a7c6f", "#4682b4", "#c9a96e", "#323367")
  for (hex in test_colours) {
    hsl <- hex_to_hsl(hex)
    reconstructed <- hsl_to_hex(hsl$h, hsl$s, hsl$l)
    # Allow +-1 per channel due to rounding
    rgb_orig <- hex_to_rgb(hex)
    rgb_recon <- hex_to_rgb(reconstructed)
    expect_true(all(abs(rgb_orig - rgb_recon) <= 1),
      info = paste("Round-trip failed for", hex, "-> got", reconstructed))
  }
})


# ==============================================================================
# Sentiment Palette Tests
# ==============================================================================

test_that("all named sentiment presets return 7 named elements", {
  presets <- c("warm", "cool", "research", "teal", "red")
  expected_names <- c("negative", "mod_negative", "neutral",
                      "mod_positive", "positive", "dk_na", "other")
  for (p in presets) {
    pal <- get_sentiment_palette(preset = p)
    expect_equal(length(pal), 7, info = paste("Preset:", p))
    expect_equal(sort(names(pal)), sort(expected_names), info = paste("Preset:", p))
  }
})

test_that("all sentiment palette colours are valid hex", {
  presets <- c("warm", "cool", "research", "teal", "red", "brand")
  for (p in presets) {
    pal <- get_sentiment_palette(preset = p)
    for (nm in names(pal)) {
      expect_true(is_valid_hex(pal[[nm]]),
        info = paste("Invalid hex in preset", p, "element", nm, ":", pal[[nm]]))
    }
  }
})

test_that("brand sentiment preset returns 7 named elements", {
  pal <- get_sentiment_palette(preset = "brand",
    overrides = list(brand_colour = "#2e8b57"))
  expect_equal(length(pal), 7)
  expect_true(all(c("negative", "positive", "dk_na") %in% names(pal)))
})

test_that("brand sentiment preset uses brand_colour hue", {
  brand <- "#0072B2"
  pal <- get_sentiment_palette(preset = "brand",
    overrides = list(brand_colour = brand))
  # All five gradient colours should share approximately the same hue
  hues <- vapply(pal[c("negative", "mod_negative", "neutral",
                        "mod_positive", "positive")],
    function(hex) hex_to_hsl(hex)$h, numeric(1))
  hue_range <- max(hues) - min(hues)
  expect_true(hue_range < 5,
    info = paste("Hue range too wide:", hue_range))
})

test_that("brand preset without brand_colour in overrides uses default #323367", {
  pal <- get_sentiment_palette(preset = "brand", overrides = NULL)
  default_hue <- hex_to_hsl("#323367")$h
  actual_hue <- hex_to_hsl(pal$neutral)$h
  expect_true(abs(actual_hue - default_hue) < 5,
    info = paste("Expected hue near", default_hue, "got", actual_hue))
})

test_that("sentiment overrides replace individual colours", {
  override_red <- "#ff0000"
  override_green <- "#00ff00"
  pal <- get_sentiment_palette(preset = "warm", overrides = list(
    chart_negative_colour = override_red,
    chart_positive_colour = override_green
  ))
  expect_equal(pal$negative, override_red)
  expect_equal(pal$positive, override_green)
  # Non-overridden colours should be unchanged from warm preset
  expect_equal(pal$neutral, "#c9a96e")
})

test_that("invalid preset falls back to warm", {
  pal_invalid <- get_sentiment_palette(preset = "nonexistent")
  pal_warm <- get_sentiment_palette(preset = "warm")
  expect_equal(pal_invalid, pal_warm)
})

test_that("preset matching is case-insensitive", {
  pal_upper <- get_sentiment_palette(preset = "COOL")
  pal_lower <- get_sentiment_palette(preset = "cool")
  expect_equal(pal_upper, pal_lower)
})


# ==============================================================================
# Segment Palette Tests
# ==============================================================================

test_that("segment palette returns correct length n", {
  for (n in c(1, 3, 5, 8, 10)) {
    pal <- get_segment_palette(n = n)
    expect_equal(length(pal), n, info = paste("n =", n))
  }
})

test_that("segment palette default preset starts with brand_colour", {
  brand <- "#abcdef"
  pal <- get_segment_palette(preset = "default", brand_colour = brand, n = 5)
  expect_equal(pal[1], brand)
})

test_that("segment palette brand preset generates monochromatic gradient", {
  brand <- "#2e8b57"
  pal <- get_segment_palette(preset = "brand", brand_colour = brand, n = 6)
  expect_equal(length(pal), 6)
  # All colours should be valid hex
  expect_true(all(vapply(pal, is_valid_hex, logical(1))))
  # Lightness should increase from first to last
  lightness_vals <- vapply(pal, function(h) hex_to_hsl(h)$l, numeric(1))
  expect_true(all(diff(lightness_vals) > 0),
    info = "Brand segment palette should have increasing lightness")
})

test_that("segment palette cycles when n > 10", {
  pal <- get_segment_palette(preset = "cool", n = 15)
  expect_equal(length(pal), 15)
  # Colours 11-15 should repeat colours 1-5
  base <- get_segment_palette(preset = "cool", n = 10)
  expect_equal(pal[11], base[1])
  expect_equal(pal[12], base[2])
})

test_that("segment palette invalid preset falls back to default", {
  pal_bad <- get_segment_palette(preset = "nonexistent", n = 5)
  pal_def <- get_segment_palette(preset = "default", n = 5)
  expect_equal(pal_bad, pal_def)
})

test_that("all segment palette colours are valid hex", {
  for (p in c("default", "cool", "warm", "research", "brand")) {
    pal <- get_segment_palette(preset = p, n = 8)
    for (i in seq_along(pal)) {
      expect_true(is_valid_hex(pal[i]),
        info = paste("Invalid hex in segment preset", p, "index", i))
    }
  }
})


# ==============================================================================
# Categorical Palette Tests
# ==============================================================================

test_that("categorical palette returns correct length", {
  for (n in c(1, 5, 10)) {
    pal <- get_categorical_palette(n = n)
    expect_equal(length(pal), n, info = paste("n =", n))
  }
})

test_that("categorical palette cycles when n > 10", {
  pal <- get_categorical_palette(n = 13)
  expect_equal(length(pal), 13)
  base <- get_categorical_palette(n = 10)
  # 11th colour should equal 1st
  expect_equal(pal[11], base[1])
  expect_equal(pal[12], base[2])
  expect_equal(pal[13], base[3])
})

test_that("categorical palette colours are all valid hex", {
  pal <- get_categorical_palette(n = 10)
  expect_true(all(vapply(pal, is_valid_hex, logical(1))))
})

test_that("categorical palette has 10 distinct colours", {
  pal <- get_categorical_palette(n = 10)
  expect_equal(length(unique(pal)), 10)
})


# ==============================================================================
# RAG Palette Tests
# ==============================================================================

test_that("RAG palette has green, amber, red names", {
  pal <- get_rag_palette()
  expect_true(all(c("green", "amber", "red") %in% names(pal)))
  expect_equal(length(pal), 3)
})

test_that("RAG palette colours are valid hex", {
  pal <- get_rag_palette()
  for (nm in names(pal)) {
    expect_true(is_valid_hex(pal[[nm]]),
      info = paste("Invalid hex for RAG", nm))
  }
})
