# ==============================================================================
# TurasPins PPTX Export — R Integration Tests
# ==============================================================================
#
# Verifies that the PptxGenJS vendor library is correctly bundled into the
# shared TurasPins JavaScript output and that the load order is correct.
#
# These tests validate the R-side plumbing — browser-side functionality
# is tested separately in modules/shared/tests/js/test_pptx_export.html
# ==============================================================================

library(testthat)

# Resolve project root (same pattern as other shared tests)
turas_root <- Sys.getenv("TURAS_ROOT")
if (!nzchar(turas_root)) turas_root <- getwd()
js_dir <- file.path(turas_root, "modules", "shared", "js")
if (!dir.exists(js_dir)) {
  # Fallback: testthat may cd into the test directory
  turas_root <- normalizePath(file.path(getwd(), "..", "..", "..", ".."), mustWork = FALSE)
  js_dir <- file.path(turas_root, "modules", "shared", "js")
}

lib_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")

# Helper: source and call turas_pins_js() with correct root
load_js_bundle <- function() {
  # Set TURAS_ROOT so the loader finds the JS directory
  old_root <- Sys.getenv("TURAS_ROOT", "")
  Sys.setenv(TURAS_ROOT = turas_root)
  on.exit(Sys.setenv(TURAS_ROOT = old_root))

  source(lib_path, local = TRUE)
  turas_pins_js()
}

# Skip all tests if project structure not found
skip_if_not <- function() {
  if (!file.exists(lib_path)) skip("turas_pins_js.R not found — run from project root")
  if (!dir.exists(js_dir)) skip("shared JS directory not found — run from project root")
}

test_that("turas_pins_js() returns string containing PptxGenJS", {
  skip_if_not()
  js <- load_js_bundle()

  expect_true(nzchar(js), info = "JS output is not empty")
  expect_true(
    grepl("PptxGenJS", js, fixed = TRUE),
    info = "PptxGenJS library is included in bundle"
  )
})

test_that("turas_pins_js() includes PPTX export module", {
  skip_if_not()
  js <- load_js_bundle()

  expect_true(
    grepl("exportPptx", js, fixed = TRUE),
    info = "exportPptx function is included"
  )
  expect_true(
    grepl("exportSinglePptx", js, fixed = TRUE),
    info = "exportSinglePptx function is included"
  )
})

test_that("PptxGenJS loads before TurasPins export code", {
  skip_if_not()
  js <- load_js_bundle()

  pptxgen_pos <- regexpr("PptxGenJS", js, fixed = TRUE)
  export_pos <- regexpr("TurasPins.exportPptx", js, fixed = TRUE)

  expect_true(pptxgen_pos > 0, info = "PptxGenJS found in output")
  expect_true(export_pos > 0, info = "exportPptx found in output")
  expect_true(
    pptxgen_pos < export_pos,
    info = "PptxGenJS appears before exportPptx (correct load order)"
  )
})

test_that("Bundle size is within expected range", {
  skip_if_not()
  js <- load_js_bundle()

  size_kb <- nchar(js) / 1024

  # html2canvas ~199KB + PptxGenJS ~466KB + TurasPins ~80KB = ~745KB minimum
  # Allow up to 900KB for growth
  expect_true(
    size_kb > 700,
    info = paste0("Bundle too small (", round(size_kb), "KB) — vendor libs may not be included")
  )
  expect_true(
    size_kb < 900,
    info = paste0("Bundle too large (", round(size_kb), "KB) — check for accidental duplication")
  )
})

test_that("Quality presets are defined in output", {
  skip_if_not()
  js <- load_js_bundle()

  expect_true(
    grepl("QUALITY_PRESETS", js, fixed = TRUE),
    info = "Quality presets constant is included"
  )
  expect_true(
    grepl("EXPORT_QUALITY", js, fixed = TRUE),
    info = "Export quality setting is included"
  )
})

test_that("Vendor directory structure is correct", {
  skip_if_not()
  vendor_path <- file.path(js_dir, "vendor", "pptxgen.bundle.js")
  expect_true(
    file.exists(vendor_path),
    info = "PptxGenJS vendor bundle file exists"
  )

  size_bytes <- file.info(vendor_path)$size
  expect_true(
    size_bytes > 400000,
    info = paste0("Vendor file too small (", size_bytes, " bytes)")
  )
})

test_that("All expected JS files exist", {
  skip_if_not()

  expected_files <- c(
    "turas_pins_utils.js",
    "turas_pins.js",
    "turas_pins_render.js",
    "turas_pins_drag.js",
    "turas_pins_insight_svg.js",
    "turas_pins_table.js",
    "turas_pins_export.js",
    "turas_pins_pptx.js"
  )

  for (f in expected_files) {
    expect_true(
      file.exists(file.path(js_dir, f)),
      info = paste0("Missing JS file: ", f)
    )
  }
})
