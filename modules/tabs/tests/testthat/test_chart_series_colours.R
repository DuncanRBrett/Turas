# ==============================================================================
# TABS MODULE - CHART SERIES COLOURS TESTS
# ==============================================================================
#
# Tests for custom series colour support in nominal bar charts:
#   1. Config parsing — chart_series_colour_1-8 fields
#   2. Chart data assembly — series_colours array in chart_data JSON
#   3. Backward compatibility — no series colours = existing behaviour
#   4. Stacked bar isolation — custom series colours don't affect stacked bars
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_chart_series_colours.R")
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

# Source chart builder (which contains get_palette_colours and chart data assembly)
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/html_report/07_chart_builder.R"))

# ==============================================================================
# HELPERS
# ==============================================================================

is_valid_hex <- function(x) {
  grepl("^#[0-9A-Fa-f]{6}$", x)
}

# Minimal config with no series colours (default state)
make_config_no_series <- function() {
  list(
    brand_colour = "#323367",
    chart_bar_colour = "#323367",
    chart_palette_preset = "warm",
    chart_series_colour_1 = NULL,
    chart_series_colour_2 = NULL,
    chart_series_colour_3 = NULL,
    chart_series_colour_4 = NULL,
    chart_series_colour_5 = NULL,
    chart_series_colour_6 = NULL,
    chart_series_colour_7 = NULL,
    chart_series_colour_8 = NULL
  )
}

# Config with custom series colours
make_config_with_series <- function(n = 5) {
  colours <- c("#1B365D", "#3A6EA5", "#E87722", "#5B9A7D", "#8E4585",
               "#C14D00", "#4A7C6F", "#D4918E")
  config <- make_config_no_series()
  for (i in seq_len(min(n, 8))) {
    config[[paste0("chart_series_colour_", i)]] <- colours[i]
  }
  config
}

# ==============================================================================
# 1. CONFIG PARSING TESTS
# ==============================================================================

test_that("config with no series colours has NULL for all series fields", {
  config <- make_config_no_series()
  for (i in 1:8) {
    expect_null(config[[paste0("chart_series_colour_", i)]],
                info = paste("chart_series_colour_", i, "should be NULL"))
  }
})

test_that("config with series colours stores valid hex codes", {
  config <- make_config_with_series(5)
  for (i in 1:5) {
    val <- config[[paste0("chart_series_colour_", i)]]
    expect_true(is_valid_hex(val),
                info = paste("chart_series_colour_", i, "=", val, "should be valid hex"))
  }
  # 6-8 should still be NULL
  for (i in 6:8) {
    expect_null(config[[paste0("chart_series_colour_", i)]])
  }
})

test_that("config with all 8 series colours stores all values", {
  config <- make_config_with_series(8)
  for (i in 1:8) {
    val <- config[[paste0("chart_series_colour_", i)]]
    expect_true(is_valid_hex(val),
                info = paste("chart_series_colour_", i, "=", val))
  }
})

# ==============================================================================
# 2. SERIES COLOUR EXTRACTION LOGIC TESTS
# ==============================================================================

# Legacy compact extraction (kept for backward-compat tests)
extract_series_colours_compact <- function(config_obj) {
  series_colours <- Filter(function(x) !is.null(x) && nzchar(x), list(
    config_obj$chart_series_colour_1, config_obj$chart_series_colour_2,
    config_obj$chart_series_colour_3, config_obj$chart_series_colour_4,
    config_obj$chart_series_colour_5, config_obj$chart_series_colour_6,
    config_obj$chart_series_colour_7, config_obj$chart_series_colour_8
  ))
  if (length(series_colours) > 0) unlist(series_colours) else NULL
}

# New sparse extraction (mirrors 07_chart_builder.R logic)
extract_sparse_series_colours <- function(config_obj) {
  series_colour_fields <- paste0("chart_series_colour_", 1:8)
  series_colours_raw <- lapply(series_colour_fields, function(f) {
    val <- config_obj[[f]]
    if (!is.null(val) && nzchar(val)) val else NA_character_
  })

  has_any_custom <- any(!is.na(series_colours_raw))
  if (has_any_custom) {
    last_defined <- max(which(!is.na(series_colours_raw)))
    return(series_colours_raw[1:last_defined])
  }
  NULL
}

test_that("no series colours returns NULL", {
  config <- make_config_no_series()
  result <- extract_series_colours_compact(config)
  expect_null(result)
})

test_that("5 series colours returns vector of length 5", {
  config <- make_config_with_series(5)
  result <- extract_series_colours_compact(config)
  expect_length(result, 5)
  expect_true(all(sapply(result, is_valid_hex)))
})

test_that("all 8 series colours returns vector of length 8", {
  config <- make_config_with_series(8)
  result <- extract_series_colours_compact(config)
  expect_length(result, 8)
})

test_that("partial series colours (gaps) only includes non-null values", {
  config <- make_config_no_series()
  config$chart_series_colour_1 <- "#1B365D"
  config$chart_series_colour_3 <- "#E87722"
  # 2 is NULL — should still get 2 colours (1 and 3, in order)
  result <- extract_series_colours_compact(config)
  expect_length(result, 2)
  expect_equal(result[1], "#1B365D")
  expect_equal(result[2], "#E87722")
})

test_that("empty string series colours are excluded", {
  config <- make_config_no_series()
  config$chart_series_colour_1 <- "#1B365D"
  config$chart_series_colour_2 <- ""
  config$chart_series_colour_3 <- "#E87722"
  result <- extract_series_colours_compact(config)
  expect_length(result, 2)
})

# ==============================================================================
# 3. STACKED BAR ISOLATION TESTS
# ==============================================================================

test_that("get_palette_colours ignores series colours completely", {
  config <- make_config_with_series(5)
  palette <- get_palette_colours("warm", overrides = config)

  # Palette should have standard semantic slots
  expect_true("negative" %in% names(palette))
  expect_true("positive" %in% names(palette))
  expect_true("neutral" %in% names(palette))

  # Palette values should NOT contain any series colours
  series_colours <- c("#1B365D", "#3A6EA5", "#E87722", "#5B9A7D", "#8E4585")
  palette_values <- unlist(palette)
  for (sc in series_colours) {
    expect_false(sc %in% palette_values,
                 info = paste("Series colour", sc, "should not appear in stacked palette"))
  }
})

test_that("preset palette is unchanged when series colours are defined", {
  config_no_series <- make_config_no_series()
  config_with_series <- make_config_with_series(5)

  pal_without <- get_palette_colours("research", overrides = config_no_series)
  pal_with <- get_palette_colours("research", overrides = config_with_series)

  expect_identical(pal_without, pal_with)
})

# ==============================================================================
# 4. CYCLING LOGIC TESTS (JS-equivalent)
# ==============================================================================

# Replicate the JS cycling logic in R for testing
cycle_colours <- function(series_colours, n_cols) {
  result <- character(n_cols)
  for (i in seq_len(n_cols)) {
    result[i] <- series_colours[((i - 1) %% length(series_colours)) + 1]
  }
  result
}

test_that("cycling with exact match uses all colours once", {
  colours <- c("#AA0000", "#BB0000", "#CC0000")
  result <- cycle_colours(colours, 3)
  expect_equal(result, colours)
})

test_that("cycling with more series than colours repeats from start", {
  colours <- c("#AA0000", "#BB0000", "#CC0000")
  result <- cycle_colours(colours, 5)
  expect_equal(result, c("#AA0000", "#BB0000", "#CC0000", "#AA0000", "#BB0000"))
})

test_that("cycling with single colour repeats for all series", {
  colours <- c("#AA0000")
  result <- cycle_colours(colours, 4)
  expect_equal(result, rep("#AA0000", 4))
})

test_that("cycling with fewer series than colours uses subset", {
  colours <- c("#AA0000", "#BB0000", "#CC0000", "#DD0000", "#EE0000")
  result <- cycle_colours(colours, 3)
  expect_equal(result, c("#AA0000", "#BB0000", "#CC0000"))
})

# ==============================================================================
# 5. SPARSE ARRAY EXTRACTION TESTS (hybrid mode)
# ==============================================================================

test_that("sparse extraction: no colours returns NULL", {
  config <- make_config_no_series()
  result <- extract_sparse_series_colours(config)
  expect_null(result)
})

test_that("sparse extraction: all 5 colours returns dense list of length 5", {
  config <- make_config_with_series(5)
  result <- extract_sparse_series_colours(config)
  expect_length(result, 5)
  expect_true(all(!is.na(result)))
})

test_that("sparse extraction: colours at positions 1 and 3 preserves NA gap", {
  config <- make_config_no_series()
  config$chart_series_colour_1 <- "#1B365D"
  config$chart_series_colour_3 <- "#E87722"
  result <- extract_sparse_series_colours(config)
  expect_length(result, 3)
  expect_equal(result[[1]], "#1B365D")
  expect_true(is.na(result[[2]]))
  expect_equal(result[[3]], "#E87722")
})

test_that("sparse extraction: colour at position 1 only returns list of length 1", {
  config <- make_config_no_series()
  config$chart_series_colour_1 <- "#FF0000"
  result <- extract_sparse_series_colours(config)
  expect_length(result, 1)
  expect_equal(result[[1]], "#FF0000")
})

test_that("sparse extraction: colour at position 5 only returns list of length 5 with 4 NAs", {
  config <- make_config_no_series()
  config$chart_series_colour_5 <- "#00FF00"
  result <- extract_sparse_series_colours(config)
  expect_length(result, 5)
  expect_true(is.na(result[[1]]))
  expect_true(is.na(result[[2]]))
  expect_true(is.na(result[[3]]))
  expect_true(is.na(result[[4]]))
  expect_equal(result[[5]], "#00FF00")
})

test_that("sparse extraction: trailing NAs trimmed correctly", {
  config <- make_config_no_series()
  config$chart_series_colour_1 <- "#AA0000"
  config$chart_series_colour_2 <- "#BB0000"
  # positions 3-8 are NULL → all trailing NAs trimmed
  result <- extract_sparse_series_colours(config)
  expect_length(result, 2)
  expect_equal(result[[1]], "#AA0000")
  expect_equal(result[[2]], "#BB0000")
})

test_that("sparse extraction: empty strings treated as NA gaps", {
  config <- make_config_no_series()
  config$chart_series_colour_1 <- "#AA0000"
  config$chart_series_colour_2 <- ""
  config$chart_series_colour_3 <- "#CC0000"
  result <- extract_sparse_series_colours(config)
  expect_length(result, 3)
  expect_equal(result[[1]], "#AA0000")
  expect_true(is.na(result[[2]]))
  expect_equal(result[[3]], "#CC0000")
})

# ==============================================================================
# 6. JSON SERIALIZATION TESTS (sparse array with NAs → JSON nulls)
# ==============================================================================

test_that("sparse array with NA serializes to JSON with null", {
  sparse <- list("#1B365D", NA_character_, "#E87722")
  json <- jsonlite::toJSON(sparse, auto_unbox = TRUE)
  expect_true(grepl("null", json))
  # Should be: ["#1B365D",null,"#E87722"]
  parsed <- jsonlite::fromJSON(as.character(json))
  expect_equal(parsed[1], "#1B365D")
  expect_true(is.na(parsed[2]))
  expect_equal(parsed[3], "#E87722")
})

test_that("dense array (no NAs) serializes cleanly to JSON", {
  dense <- list("#AA0000", "#BB0000", "#CC0000")
  json <- jsonlite::toJSON(dense, auto_unbox = TRUE)
  expect_false(grepl("null", json))
  parsed <- jsonlite::fromJSON(as.character(json))
  expect_length(parsed, 3)
  expect_true(all(!is.na(parsed)))
})

test_that("NULL series colours result in no series_colours field in chart_data", {
  config <- make_config_no_series()
  result <- extract_sparse_series_colours(config)
  expect_null(result)
  # Simulating chart_data assembly: NULL result means field is not attached
  chart_data <- list(chart_type = "horizontal")
  if (!is.null(result)) chart_data$series_colours <- result
  expect_null(chart_data$series_colours)
})

# ==============================================================================
# 7. COLOUR DISTINCTIVENESS VALIDATION
# ==============================================================================

# R-side simulation of the JS getDistinctPalette hue spacing logic
simulate_hue_spacing <- function(n, brand_hue_deg = 200) {
  step <- 360 / n
  hues <- ((0:(n - 1)) * step + brand_hue_deg) %% 360
  hues
}

# Circular hue distance (0-180)
hue_dist <- function(a, b) {
  d <- abs(a - b) %% 360
  min(d, 360 - d)
}

test_that("dynamic palette has adequate hue separation for 5 series", {
  hues <- simulate_hue_spacing(5)
  step <- 360 / 5
  for (i in 1:(length(hues) - 1)) {
    for (j in (i + 1):length(hues)) {
      dist <- hue_dist(hues[i], hues[j])
      expect_true(dist >= step * 0.5,
                  info = sprintf("Hues %.0f and %.0f too close: %.1f deg (min %.1f)",
                                 hues[i], hues[j], dist, step * 0.5))
    }
  }
})

test_that("dynamic palette has adequate hue separation for 8 series", {
  hues <- simulate_hue_spacing(8)
  step <- 360 / 8
  for (i in 1:(length(hues) - 1)) {
    for (j in (i + 1):length(hues)) {
      dist <- hue_dist(hues[i], hues[j])
      expect_true(dist >= step * 0.5,
                  info = sprintf("Hues %.0f and %.0f too close: %.1f deg", hues[i], hues[j], dist))
    }
  }
})

test_that("dynamic palette has adequate hue separation for 16 series", {
  hues <- simulate_hue_spacing(16)
  step <- 360 / 16
  for (i in 1:(length(hues) - 1)) {
    for (j in (i + 1):length(hues)) {
      dist <- hue_dist(hues[i], hues[j])
      expect_true(dist >= step * 0.5,
                  info = sprintf("Hues %.0f and %.0f too close: %.1f deg", hues[i], hues[j], dist))
    }
  }
})

test_that("dynamic palette works for edge case of 1 series", {
  hues <- simulate_hue_spacing(1)
  expect_length(hues, 1)
})

test_that("dynamic palette works for edge case of 20 series", {
  hues <- simulate_hue_spacing(20)
  expect_length(hues, 20)
  # All hues should be unique (within rounding)
  expect_equal(length(unique(round(hues))), 20)
})

# ==============================================================================
# 8. BACKWARD COMPATIBILITY TESTS
# ==============================================================================

test_that("stacked bars unaffected regardless of series colour config", {
  config_none <- make_config_no_series()
  config_full <- make_config_with_series(8)

  pal_none <- get_palette_colours("warm", overrides = config_none)
  pal_full <- get_palette_colours("warm", overrides = config_full)

  expect_identical(pal_none, pal_full)
})

test_that("all 8 defined produces dense array (no NAs)", {
  config <- make_config_with_series(8)
  result <- extract_sparse_series_colours(config)
  expect_length(result, 8)
  expect_true(all(!is.na(result)))
})
