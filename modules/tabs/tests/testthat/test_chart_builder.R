# ==============================================================================
# TABS MODULE - CHART BUILDER TESTS
# ==============================================================================
#
# Tests for chart generation functions in lib/html_report/07_chart_builder.R:
#   - get_palette_colours()
#   - .generate_mono_palette()
#   - hex_to_rgb()
#   - get_semantic_colour()
#   - get_categorical_colour()
#   - build_stacked_bar_svg()
#   - build_horizontal_bars_svg()
#   - get_chart_row_indices()
#   - extract_all_column_chart_data()
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_chart_builder.R")
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

# Source shared + tabs dependencies
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))

# Source HTML report submodules
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/html_report/99_html_report_main.R"))


# ==============================================================================
# get_palette_colours()
# ==============================================================================

test_that("get_palette_colours returns 7 named colours for warm preset", {
  pal <- get_palette_colours("warm")

  expect_type(pal, "list")
  expected_names <- c("negative", "mod_negative", "neutral", "mod_positive",
                       "positive", "dk_na", "other")
  expect_true(all(expected_names %in% names(pal)))
  expect_equal(length(pal), 7)
})

test_that("get_palette_colours returns valid hex colours", {
  pal <- get_palette_colours("cool")

  for (colour in pal) {
    expect_true(grepl("^#[0-9a-fA-F]{6}$", colour),
                info = paste("Invalid hex colour:", colour))
  }
})

test_that("get_palette_colours supports all preset names", {
  for (preset in c("warm", "cool", "research", "teal", "red")) {
    pal <- get_palette_colours(preset)
    expect_equal(length(pal), 7, info = paste("Preset:", preset))
  }
})

test_that("get_palette_colours falls back to warm for unknown preset", {
  pal_unknown <- get_palette_colours("nonexistent")
  pal_warm <- get_palette_colours("warm")

  expect_equal(pal_unknown, pal_warm)
})

test_that("get_palette_colours supports brand preset", {
  pal <- get_palette_colours("brand", overrides = list(brand_colour = "#ff0000"))

  expect_type(pal, "list")
  expect_equal(length(pal), 7)
  # DK/NA should still be default grey
  expect_equal(pal$dk_na, "#d1cdc7")
})

test_that("get_palette_colours applies individual overrides", {
  overrides <- list(chart_negative_colour = "#111111")
  pal <- get_palette_colours("warm", overrides = overrides)

  expect_equal(pal$negative, "#111111")
  # Non-overridden colours should stay at warm defaults
  expect_equal(pal$dk_na, "#d1cdc7")
})


# ==============================================================================
# .generate_mono_palette()
# ==============================================================================

test_that(".generate_mono_palette generates 7 colours from hex", {
  pal <- .generate_mono_palette("#323367")

  expect_type(pal, "list")
  expect_equal(length(pal), 7)
  expect_true(all(grepl("^#[0-9a-fA-F]{6}$", unlist(pal))))
})

test_that(".generate_mono_palette produces different stops for different hues", {
  pal_blue <- .generate_mono_palette("#0000ff")
  pal_red <- .generate_mono_palette("#ff0000")

  # The palettes should differ since they have different hues
  expect_false(identical(pal_blue$positive, pal_red$positive))
})


# ==============================================================================
# hex_to_rgb()
# ==============================================================================

test_that("hex_to_rgb parses valid hex colour", {
  rgb <- hex_to_rgb("#b85450")

  expect_equal(length(rgb), 3)
  expect_equal(rgb[1], 184)  # R
  expect_equal(rgb[2], 84)   # G
  expect_equal(rgb[3], 80)   # B
})

test_that("hex_to_rgb parses black and white", {
  expect_equal(hex_to_rgb("#000000"), c(0, 0, 0))
  expect_equal(hex_to_rgb("#ffffff"), c(255, 255, 255))
})


# ==============================================================================
# get_semantic_colour()
# ==============================================================================

test_that("get_semantic_colour maps known sentiment labels", {
  pal <- get_palette_colours("warm")

  expect_equal(get_semantic_colour("Positive", palette = pal), pal$positive)
  expect_equal(get_semantic_colour("Negative", palette = pal), pal$negative)
  expect_equal(get_semantic_colour("Neutral", palette = pal), pal$neutral)
  expect_equal(get_semantic_colour("DK/NA", palette = pal), pal$dk_na)
})

test_that("get_semantic_colour is case-insensitive", {
  pal <- get_palette_colours("warm")

  expect_equal(
    get_semantic_colour("POSITIVE", palette = pal),
    get_semantic_colour("positive", palette = pal)
  )
})

test_that("get_semantic_colour falls back to gradient for unknown labels", {
  pal <- get_palette_colours("warm")

  # Unknown label should return a valid hex colour
  result <- get_semantic_colour("Unknown Category", index = 2, n_total = 5,
                                 palette = pal)

  expect_true(grepl("^#[0-9a-fA-F]{6}$", result))
})

test_that("get_semantic_colour returns neutral for single-item lists", {
  pal <- get_palette_colours("warm")

  result <- get_semantic_colour("Unknown", index = 1, n_total = 1,
                                 palette = pal)

  expect_equal(result, pal$neutral)
})


# ==============================================================================
# get_categorical_colour()
# ==============================================================================

test_that("get_categorical_colour returns valid hex colours", {
  for (i in 1:15) {
    colour <- get_categorical_colour(i)
    expect_true(grepl("^#[0-9a-fA-F]{6}$", colour),
                info = paste("Index:", i))
  }
})

test_that("get_categorical_colour wraps around after 10 colours", {
  expect_equal(get_categorical_colour(1), get_categorical_colour(11))
  expect_equal(get_categorical_colour(3), get_categorical_colour(13))
})


# ==============================================================================
# build_stacked_bar_svg()
# ==============================================================================

test_that("build_stacked_bar_svg returns SVG markup", {
  items <- data.frame(
    label = c("Positive", "Neutral", "Negative"),
    value = c(45, 30, 25),
    colour = c("#4a7c6f", "#c9a96e", "#b85450"),
    stringsAsFactors = FALSE
  )

  result <- build_stacked_bar_svg(items, chart_id = "test-chart")

  expect_type(result, "character")
  expect_true(grepl("<svg", result))
  expect_true(grepl("</svg>", result))
  expect_true(grepl("Positive", result))
})

test_that("build_stacked_bar_svg returns empty for empty items", {
  items <- data.frame(
    label = character(0),
    value = numeric(0),
    colour = character(0),
    stringsAsFactors = FALSE
  )

  result <- build_stacked_bar_svg(items)

  expect_equal(result, "")
})

test_that("build_stacked_bar_svg returns empty when total is zero", {
  items <- data.frame(
    label = c("A", "B"),
    value = c(0, 0),
    colour = c("#aaa", "#bbb"),
    stringsAsFactors = FALSE
  )

  result <- build_stacked_bar_svg(items)

  expect_equal(result, "")
})


# ==============================================================================
# build_horizontal_bars_svg()
# ==============================================================================

test_that("build_horizontal_bars_svg returns SVG markup", {
  items <- data.frame(
    label = c("Option A", "Option B", "Option C"),
    value = c(40, 35, 25),
    stringsAsFactors = FALSE
  )

  result <- build_horizontal_bars_svg(items, brand_colour = "#323367")

  expect_type(result, "character")
  expect_true(grepl("<svg", result))
  expect_true(grepl("</svg>", result))
  expect_true(grepl("Option A", result))
})

test_that("build_horizontal_bars_svg returns empty for empty items", {
  items <- data.frame(
    label = character(0),
    value = numeric(0),
    stringsAsFactors = FALSE
  )

  result <- build_horizontal_bars_svg(items)

  expect_equal(result, "")
})


# ==============================================================================
# get_chart_row_indices()
# ==============================================================================

test_that("get_chart_row_indices returns category rows by default", {
  table_data <- data.frame(
    .row_label = c("Total", "Option A", "Option B", "Mean"),
    .row_type = c("total", "category", "category", "stat"),
    `TOTAL::Total` = c(100, 45, 55, 7.2),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  result <- get_chart_row_indices(table_data, box_cat_labels = NULL)

  expect_equal(result, c(2, 3))
})

test_that("get_chart_row_indices filters by box category labels", {
  table_data <- data.frame(
    .row_label = c("Positive", "Neutral", "Negative", "DK/NA"),
    .row_type = c("net", "net", "net", "category"),
    `TOTAL::Total` = c(60, 25, 15, 5),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  result <- get_chart_row_indices(table_data,
                                   box_cat_labels = c("Positive", "Negative"))

  expect_equal(length(result), 2)
  expect_true(1 %in% result)  # Positive
  expect_true(3 %in% result)  # Negative
})


# ==============================================================================
# extract_all_column_chart_data()
# ==============================================================================

test_that("extract_all_column_chart_data returns correct structure", {
  table_data <- data.frame(
    .row_label = c("Option A", "Option B"),
    .row_type = c("category", "category"),
    `TOTAL::Total` = c(60, 40),
    `Gender::Male` = c(55, 45),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  result <- extract_all_column_chart_data(table_data, c(1, 2),
                                           use_box_categories = FALSE)

  expect_type(result, "list")
  expect_true("labels" %in% names(result))
  expect_true("columns" %in% names(result))
  expect_equal(result$labels, c("Option A", "Option B"))
  expect_true("TOTAL::Total" %in% names(result$columns))
  expect_equal(result$columns[["TOTAL::Total"]]$values, c(60, 40))
})

test_that("extract_all_column_chart_data returns NULL for empty input", {
  table_data <- data.frame(
    .row_label = character(0),
    .row_type = character(0),
    stringsAsFactors = FALSE
  )

  result <- extract_all_column_chart_data(table_data, integer(0),
                                           use_box_categories = FALSE)

  expect_null(result)
})
