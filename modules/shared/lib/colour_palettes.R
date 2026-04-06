# ==============================================================================
# Turas Shared Colour Palette System
# ==============================================================================
# Centralised colour palettes for all Turas report modules.
# Provides:
#   - Sentiment palettes (ordinal: negative → positive) for tabs bar charts
#   - Segment palettes (categorical: multi-series lines) for tracker charts
#   - Categorical palette (10-colour nominal) for general use
#   - RAG status palette (green/amber/red thresholds)
#   - HSL utility functions for brand-generated palettes
# VERSION: 1.0.0
# ==============================================================================


# ==============================================================================
# HSL COLOUR UTILITIES
# ==============================================================================

#' Convert HSL to hex colour
#'
#' @param h Numeric. Hue (0-360)
#' @param s Numeric. Saturation (0-1)
#' @param l Numeric. Lightness (0-1)
#' @return Character. Hex colour string
#' @keywords internal
hsl_to_hex <- function(h, s, l) {
  c_val <- (1 - abs(2 * l - 1)) * s
  x <- c_val * (1 - abs((h / 60) %% 2 - 1))
  m <- l - c_val / 2
  if (h < 60)       { r1 <- c_val; g1 <- x;     b1 <- 0 }
  else if (h < 120) { r1 <- x;     g1 <- c_val; b1 <- 0 }
  else if (h < 180) { r1 <- 0;     g1 <- c_val; b1 <- x }
  else if (h < 240) { r1 <- 0;     g1 <- x;     b1 <- c_val }
  else if (h < 300) { r1 <- x;     g1 <- 0;     b1 <- c_val }
  else              { r1 <- c_val; g1 <- 0;     b1 <- x }
  ri <- round((r1 + m) * 255)
  gi <- round((g1 + m) * 255)
  bi <- round((b1 + m) * 255)
  sprintf("#%02x%02x%02x", ri, gi, bi)
}


#' Parse hex colour to RGB vector (0-255)
#'
#' @param hex Character. Hex colour string (e.g., "#b85450")
#' @return Numeric vector of length 3 (R, G, B) in 0-255 range
#' @keywords internal
hex_to_rgb <- function(hex) {
  hex_clean <- sub("^#", "", hex)
  if (!grepl("^[0-9A-Fa-f]{6}$", hex_clean)) {
    warning(sprintf("Invalid hex colour: '%s'. Expected 6-character hex (e.g. '#FF0000' or 'FF0000').", hex), call. = FALSE)
    return(rep(NA_real_, 3))
  }
  c(
    strtoi(substr(hex_clean, 1, 2), 16L),
    strtoi(substr(hex_clean, 3, 4), 16L),
    strtoi(substr(hex_clean, 5, 6), 16L)
  )
}


#' Parse hex colour to HSL
#'
#' @param hex Character. Hex colour string
#' @return Named list with h (0-360), s (0-1), l (0-1)
#' @keywords internal
hex_to_hsl <- function(hex) {
  rgb <- hex_to_rgb(hex) / 255
  if (any(is.na(rgb))) return(list(h = NA_real_, s = NA_real_, l = NA_real_))
  r <- rgb[1]; g <- rgb[2]; b <- rgb[3]

  cmax <- max(r, g, b)
  cmin <- min(r, g, b)
  delta <- cmax - cmin

  l <- (cmax + cmin) / 2

  if (delta == 0) {
    s <- 0
    h <- 0
  } else {
    s <- if (l < 0.5) delta / (cmax + cmin) else delta / (2 - cmax - cmin)
    h <- if (cmax == r) {
      60 * (((g - b) / delta) %% 6)
    } else if (cmax == g) {
      60 * ((b - r) / delta + 2)
    } else {
      60 * ((r - g) / delta + 4)
    }
    if (h < 0) h <- h + 360
  }

  list(h = h, s = s, l = l)
}


# ==============================================================================
# SENTIMENT PALETTES (Ordinal: negative → positive)
# ==============================================================================
# Used by Turas Tabs for bar charts with Likert-type scales.

#' Get Sentiment Palette Colours
#'
#' Returns an ordinal colour palette for sentiment-style bar charts.
#' Supports named presets (warm, cool, research, teal, red) and
#' brand-generated monochromatic gradients.
#'
#' @param preset Character. Palette name: "warm", "cool", "research",
#'   "teal", "red", or "brand" (generates from brand_colour)
#' @param overrides Named list. Optional individual colour overrides from
#'   config (chart_negative_colour, chart_positive_colour, etc.) and
#'   brand_colour for the "brand" preset
#' @return Named list with: negative, mod_negative, neutral, mod_positive,
#'   positive, dk_na, other
#' @export
get_sentiment_palette <- function(preset = "warm", overrides = NULL) {

  palettes <- list(
    warm = list(
      negative     = "#b85450",
      mod_negative = "#d4918e",
      neutral      = "#c9a96e",
      mod_positive = "#7daa8c",
      positive     = "#4a7c6f",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    cool = list(
      negative     = "#a65461",
      mod_negative = "#c78f93",
      neutral      = "#94a3b8",
      mod_positive = "#6f9fa8",
      positive     = "#3d7a8a",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    research = list(
      negative     = "#8e4585",
      mod_negative = "#b891b5",
      neutral      = "#b8b8b8",
      mod_positive = "#7daa8c",
      positive     = "#3d7a5f",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    teal = list(
      negative     = "#d4edea",
      mod_negative = "#a3d5cf",
      neutral      = "#6dbfb8",
      mod_positive = "#4a9e95",
      positive     = "#2d7a72",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    red = list(
      negative     = "#e8cbcb",
      mod_negative = "#cfa0a0",
      neutral      = "#b07272",
      mod_positive = "#8f4d4d",
      positive     = "#6e2b2b",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    )
  )

  preset_lower <- tolower(preset)

  if (preset_lower == "brand") {
    brand_hex <- if (!is.null(overrides$brand_colour) && nzchar(overrides$brand_colour)) {
      overrides$brand_colour
    } else {
      "#323367"
    }
    pal <- .generate_mono_sentiment(brand_hex)
  } else {
    pal <- palettes[[preset_lower]]
    if (is.null(pal)) pal <- palettes[["warm"]]
  }

  # Apply individual overrides
  if (!is.null(overrides)) {
    override_map <- list(
      chart_negative_colour     = "negative",
      chart_mod_negative_colour = "mod_negative",
      chart_neutral_colour      = "neutral",
      chart_mod_positive_colour = "mod_positive",
      chart_positive_colour     = "positive",
      chart_dk_colour           = "dk_na"
    )
    for (cfg_key in names(override_map)) {
      if (!is.null(overrides[[cfg_key]]) && nzchar(overrides[[cfg_key]])) {
        pal[[ override_map[[cfg_key]] ]] <- overrides[[cfg_key]]
      }
    }
  }

  pal
}


#' Generate monochromatic sentiment palette from a single hex colour
#'
#' Produces 5 gradient stops from light (88%) to dark (30%) lightness
#' at the same hue, desaturated slightly for a muted look.
#'
#' @param hex Character. Hex colour string
#' @return Named list matching sentiment palette structure
#' @keywords internal
.generate_mono_sentiment <- function(hex) {
  hsl <- hex_to_hsl(hex)
  s_muted <- min(hsl$s, 0.45)
  lightness_stops <- c(0.88, 0.74, 0.58, 0.44, 0.30)
  colours <- vapply(lightness_stops, function(lv) hsl_to_hex(hsl$h, s_muted, lv), character(1))
  list(
    negative     = colours[1],
    mod_negative = colours[2],
    neutral      = colours[3],
    mod_positive = colours[4],
    positive     = colours[5],
    dk_na        = "#d1cdc7",
    other        = "#c5c0b8"
  )
}


# ==============================================================================
# SEGMENT PALETTES (Categorical: multi-series lines)
# ==============================================================================
# Used by Turas Tracker for line charts with multiple segments.

#' Get Segment Palette Colours
#'
#' Returns a vector of colours for tracker segment lines/series.
#' Supports named presets and brand-generated monochromatic gradients.
#'
#' @param preset Character. Palette name: "default", "cool", "warm",
#'   "research", or "brand" (generates lightness gradient from brand_colour)
#' @param brand_colour Character. Brand hex colour (used as first colour in
#'   "default" preset, and as base for "brand" preset)
#' @param n Integer. Number of colours needed
#' @return Character vector of hex colours (length n)
#' @export
get_segment_palette <- function(preset = "default", brand_colour = "#323367", n = 8) {

  palettes <- list(
    # Default: brand-led with complementary hues for good contrast
    default = c(
      brand_colour,
      "#CC9900",  # Gold
      "#2E8B57",  # Sea green
      "#CD5C5C",  # Indian red
      "#4682B4",  # Steel blue
      "#9370DB",  # Medium purple
      "#D2691E",  # Chocolate
      "#20B2AA",  # Light sea green
      "#8B6914",  # Dark goldenrod
      "#708090"   # Slate grey
    ),
    # Cool: muted steel/slate tones — professional, subdued
    cool = c(
      "#3d7a8a",  # Deep teal
      "#4682B4",  # Steel blue
      "#6f9fa8",  # Muted teal
      "#708090",  # Slate grey
      "#5f6b7c",  # Blue grey
      "#8b99a7",  # Silver
      "#4a6670",  # Dark slate
      "#94a3b8",  # Light slate
      "#3b5998",  # Facebook blue
      "#6b8e9b"   # Cadet blue
    ),
    # Warm: amber/terracotta tones — earthy, inviting
    warm = c(
      "#b85450",  # Terracotta
      "#c9a96e",  # Goldenrod
      "#8B6914",  # Dark goldenrod
      "#CD853F",  # Peru
      "#D2691E",  # Chocolate
      "#BC8F8F",  # Rosy brown
      "#A0522D",  # Sienna
      "#DAA520",  # Goldenrod bright
      "#8B4513",  # Saddle brown
      "#D4918e"   # Dusty rose
    ),
    # Research: Wong palette — colourblind-safe categorical
    research = c(
      "#0072B2",  # Blue
      "#D55E00",  # Vermillion
      "#009E73",  # Bluish green
      "#CC79A7",  # Reddish purple
      "#E69F00",  # Orange
      "#56B4E9",  # Sky blue
      "#F0E442",  # Yellow
      "#000000",  # Black
      "#999999",  # Grey
      "#661100"   # Dark red
    )
  )

  preset_lower <- tolower(preset)

  if (preset_lower == "brand") {
    colours <- .generate_mono_segment(brand_colour, n)
    return(colours)
  }

  pal <- palettes[[preset_lower]]
  if (is.null(pal)) pal <- palettes[["default"]]

  # Ensure first colour is brand for "default" preset
  if (preset_lower == "default") {
    pal[1] <- brand_colour
  }

  if (n <= length(pal)) {
    return(pal[seq_len(n)])
  }

  # Extend by cycling
  rep_len(pal, n)
}


#' Generate monochromatic segment palette from brand colour
#'
#' Produces n colours at evenly spaced lightness stops around the
#' brand colour's hue, with slight hue rotation for visual separation.
#'
#' @param hex Character. Brand hex colour
#' @param n Integer. Number of colours needed
#' @return Character vector of hex colours
#' @keywords internal
.generate_mono_segment <- function(hex, n) {
  hsl <- hex_to_hsl(hex)
  s_muted <- min(hsl$s, 0.55)

  # Spread lightness from 0.30 to 0.75 (avoid extremes)
  if (n == 1) {
    lightness_stops <- hsl$l
  } else {
    lightness_stops <- seq(0.30, 0.75, length.out = n)
  }

  # Add slight hue rotation (±15° across the range) for visual separation
  if (n == 1) {
    hue_offsets <- 0
  } else {
    hue_offsets <- seq(-15, 15, length.out = n)
  }

  vapply(seq_len(n), function(i) {
    h <- (hsl$h + hue_offsets[i]) %% 360
    hsl_to_hex(h, s_muted, lightness_stops[i])
  }, character(1))
}


# ==============================================================================
# CATEGORICAL PALETTE (10-colour nominal)
# ==============================================================================

#' Get Categorical Palette
#'
#' Returns a general-purpose 10-colour categorical palette suitable
#' for nominal data. Colours are designed for good contrast and
#' reasonable colourblind accessibility.
#'
#' @param n Integer. Number of colours needed (max 10, cycles if exceeded)
#' @return Character vector of hex colours
#' @export
get_categorical_palette <- function(n = 10) {
  pal <- c(
    "#4a7c6f",  # Teal green
    "#b85450",  # Terracotta
    "#4682B4",  # Steel blue
    "#c9a96e",  # Goldenrod
    "#9370DB",  # Medium purple
    "#2E8B57",  # Sea green
    "#CD5C5C",  # Indian red
    "#D2691E",  # Chocolate
    "#20B2AA",  # Light sea green
    "#708090"   # Slate grey
  )
  if (n <= length(pal)) return(pal[seq_len(n)])
  rep_len(pal, n)
}


# ==============================================================================
# RAG STATUS PALETTE
# ==============================================================================

#' Get RAG Status Colours
#'
#' Returns the standard red/amber/green colours used for traffic-light
#' indicators across all Turas reports.
#'
#' @return Named list with green, amber, red hex colours
#' @export
get_rag_palette <- function() {
  list(
    green = "#4a7c6f",
    amber = "#c9a96e",
    red   = "#b85450"
  )
}
