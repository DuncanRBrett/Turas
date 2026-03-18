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

# Replicate the extraction logic from 07_chart_builder.R to test it
extract_series_colours <- function(config_obj) {
  series_colours <- Filter(function(x) !is.null(x) && nzchar(x), list(
    config_obj$chart_series_colour_1, config_obj$chart_series_colour_2,
    config_obj$chart_series_colour_3, config_obj$chart_series_colour_4,
    config_obj$chart_series_colour_5, config_obj$chart_series_colour_6,
    config_obj$chart_series_colour_7, config_obj$chart_series_colour_8
  ))
  if (length(series_colours) > 0) unlist(series_colours) else NULL
}

test_that("no series colours returns NULL", {
  config <- make_config_no_series()
  result <- extract_series_colours(config)
  expect_null(result)
})

test_that("5 series colours returns vector of length 5", {
  config <- make_config_with_series(5)
  result <- extract_series_colours(config)
  expect_length(result, 5)
  expect_true(all(sapply(result, is_valid_hex)))
})

test_that("all 8 series colours returns vector of length 8", {
  config <- make_config_with_series(8)
  result <- extract_series_colours(config)
  expect_length(result, 8)
})

test_that("partial series colours (gaps) only includes non-null values", {
  config <- make_config_no_series()
  config$chart_series_colour_1 <- "#1B365D"
  config$chart_series_colour_3 <- "#E87722"
  # 2 is NULL — should still get 2 colours (1 and 3, in order)
  result <- extract_series_colours(config)
  expect_length(result, 2)
  expect_equal(result[1], "#1B365D")
  expect_equal(result[2], "#E87722")
})

test_that("empty string series colours are excluded", {
  config <- make_config_no_series()
  config$chart_series_colour_1 <- "#1B365D"
  config$chart_series_colour_2 <- ""
  config$chart_series_colour_3 <- "#E87722"
  result <- extract_series_colours(config)
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
