# ==============================================================================
# TABS MODULE - SHARED REPORT HELPERS TESTS
# ==============================================================================
# Tests for lib/report_shared.R. The row/banner shape helpers and the chart
# colour palette that the v2 data-layer writer classifies and colours through.
#
# These helpers lived inside the classic HTML report until it was retired
# (2026-08); the palette tests below came with them from test_chart_builder.R.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_report_shared.R")
# ==============================================================================

library(testthat)

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
source(file.path(turas_root, "modules/tabs/lib/report_shared.R"))

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
# normalize_question_table()
# ==============================================================================

test_that("normalize_question_table forward-fills the option label onto sub-rows", {
  tbl <- data.frame(
    RowLabel = c("Very good", "", "", "Poor", "", ""),
    RowType  = c("Frequency", "Column %", "Sig.", "Frequency", "Column %", "Sig."),
    stringsAsFactors = FALSE
  )
  out <- normalize_question_table(tbl)
  expect_equal(out$RowLabel, c(rep("Very good", 3), rep("Poor", 3)))
})

test_that("a dual-alpha Sig row inherits its option label instead of setting one", {
  # In dual-alpha mode the Sig rows carry a confidence label ("Sig. (95%)"),
  # not the option label. It must not become the label every later row inherits.
  tbl <- data.frame(
    RowLabel = c("Very good", "", "Sig. (95%)", "Sig. (80%)", ""),
    RowType  = c("Frequency", "Column %", "Sig.", "Sig.2", "Column %"),
    stringsAsFactors = FALSE
  )
  out <- normalize_question_table(tbl)
  expect_equal(unique(out$RowLabel), "Very good")
})

test_that("RowSource is forward-filled when present", {
  tbl <- data.frame(
    RowLabel  = c("Top 2 box", "", "Agree", ""),
    RowType   = c("Frequency", "Column %", "Frequency", "Column %"),
    RowSource = c("boxcategory", "", "individual", ""),
    stringsAsFactors = FALSE
  )
  out <- normalize_question_table(tbl)
  expect_equal(out$RowSource, c("boxcategory", "boxcategory", "individual", "individual"))
})

# ==============================================================================
# classify_row_labels()
# ==============================================================================

test_that("RowSource decides the class when it is present", {
  tbl <- data.frame(
    RowLabel  = c("Agree", "Top 2 box", "Average"),
    RowType   = c("Frequency", "Frequency", "Average"),
    RowSource = c("individual", "boxcategory", "summary"),
    stringsAsFactors = FALSE
  )
  cls <- classify_row_labels(tbl)
  expect_equal(unname(cls[c("Agree", "Top 2 box", "Average")]),
               c("category", "net", "mean"))
})

test_that("without RowSource, NET-shaped labels still classify as net", {
  tbl <- data.frame(
    RowLabel = c("NET POSITIVE", "Promoter", "Blue"),
    RowType  = rep("Frequency", 3),
    stringsAsFactors = FALSE
  )
  cls <- classify_row_labels(tbl)
  expect_equal(unname(cls["NET POSITIVE"]), "net")
  expect_equal(unname(cls["Promoter"]), "net")
  expect_equal(unname(cls["Blue"]), "category")
})

# ==============================================================================
# detect_available_stats()
# ==============================================================================

test_that("detect_available_stats reports exactly the row types present", {
  tbl <- data.frame(RowType = c("Frequency", "Column %", "Sig.", "Average"),
                    stringsAsFactors = FALSE)
  st <- detect_available_stats(tbl)
  expect_true(st$has_freq)
  expect_true(st$has_col_pct)
  expect_true(st$has_sig)
  expect_true(st$has_mean)
  expect_false(st$has_sig2)
  expect_false(st$has_index)
  expect_false(st$has_sd)
})
