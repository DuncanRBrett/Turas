# ==============================================================================
# Vendor JS Stripping Tests
# ==============================================================================
#
# Verifies that the hub assembler's vendor-stripping regex correctly removes
# TURAS_VENDOR_START/END-wrapped code from embedded report HTML.
# ==============================================================================

library(testthat)

# The regex used by 07_page_assembler.R
strip_vendor <- function(html) {
  gsub(
    "/\\* TURAS_VENDOR_START \\*/[\\s\\S]*?/\\* TURAS_VENDOR_END \\*/",
    "/* vendor JS loaded at hub level */",
    html,
    perl = TRUE
  )
}

test_that("vendor stripping removes content between paired markers", {
  html <- paste(
    "before code",
    "/* TURAS_VENDOR_START */",
    "var bigLibrary = 'lots of code here';",
    "function doStuff() { return 42; }",
    "/* TURAS_VENDOR_END */",
    "after code",
    sep = "\n"
  )
  result <- strip_vendor(html)
  expect_true(grepl("before code", result, fixed = TRUE))
  expect_true(grepl("after code", result, fixed = TRUE))
  expect_true(grepl("vendor JS loaded at hub level", result, fixed = TRUE))
  expect_false(grepl("bigLibrary", result, fixed = TRUE))
  expect_false(grepl("TURAS_VENDOR_START", result, fixed = TRUE))
})

test_that("vendor stripping handles multiple vendor blocks", {
  html <- paste(
    "/* TURAS_VENDOR_START */",
    "var pptxgen = 'library 1';",
    "/* TURAS_VENDOR_END */",
    "",
    "/* TURAS_VENDOR_START */",
    "var html2canvas = 'library 2';",
    "/* TURAS_VENDOR_END */",
    sep = "\n"
  )
  result <- strip_vendor(html)
  expect_false(grepl("pptxgen", result, fixed = TRUE))
  expect_false(grepl("html2canvas", result, fixed = TRUE))
  expect_equal(length(gregexpr("vendor JS loaded at hub level", result)[[1]]), 2)
})

test_that("vendor stripping is a no-op when no markers present", {
  html <- "var myCode = 'no vendor markers here';\nfunction test() {}"
  result <- strip_vendor(html)
  expect_equal(result, html)
})

test_that("vendor stripping leaves orphaned START marker intact", {
  html <- paste(
    "before",
    "/* TURAS_VENDOR_START */",
    "vendor code without end marker",
    sep = "\n"
  )
  result <- strip_vendor(html)
  # Without END marker, the regex should NOT match — HTML stays unchanged
  expect_true(grepl("TURAS_VENDOR_START", result, fixed = TRUE))
  expect_true(grepl("vendor code without end marker", result, fixed = TRUE))
})

test_that("vendor stripping works with actual turas_pins_js output", {
  turas_root <- Sys.getenv("TURAS_ROOT")
  if (!nzchar(turas_root)) turas_root <- getwd()
  lib_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")
  if (!file.exists(lib_path)) {
    turas_root <- normalizePath(file.path(getwd(), "..", "..", "..", ".."), mustWork = FALSE)
    lib_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")
  }
  skip_if(!file.exists(lib_path), "turas_pins_js.R not found")

  old_root <- Sys.getenv("TURAS_ROOT", "")
  Sys.setenv(TURAS_ROOT = turas_root)
  on.exit(Sys.setenv(TURAS_ROOT = old_root))

  source(lib_path, local = TRUE)
  js_with_vendor <- turas_pins_js(include_vendor = TRUE)

  # Verify markers exist in the full bundle
  expect_true(grepl("TURAS_VENDOR_START", js_with_vendor, fixed = TRUE))
  expect_true(grepl("TURAS_VENDOR_END", js_with_vendor, fixed = TRUE))

  # Strip and verify
  result <- strip_vendor(js_with_vendor)
  expect_false(grepl("TURAS_VENDOR_START", result, fixed = TRUE))
  expect_false(grepl("TURAS_VENDOR_END", result, fixed = TRUE))
  expect_true(grepl("vendor JS loaded at hub level", result, fixed = TRUE))

  # Application code should survive (these are in turas_pins_pptx.js, not vendor)
  expect_true(grepl("exportPptx", result, fixed = TRUE))
  expect_true(grepl("exportSinglePptx", result, fixed = TRUE))

  # Vendor code should be gone (PptxGenJS internals)
  expect_false(grepl("slideLayout", result, fixed = TRUE))
})

test_that("stripped bundle is significantly smaller than full bundle", {
  turas_root <- Sys.getenv("TURAS_ROOT")
  if (!nzchar(turas_root)) turas_root <- getwd()
  lib_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")
  if (!file.exists(lib_path)) {
    turas_root <- normalizePath(file.path(getwd(), "..", "..", "..", ".."), mustWork = FALSE)
    lib_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")
  }
  skip_if(!file.exists(lib_path), "turas_pins_js.R not found")

  old_root <- Sys.getenv("TURAS_ROOT", "")
  Sys.setenv(TURAS_ROOT = turas_root)
  on.exit(Sys.setenv(TURAS_ROOT = old_root))

  source(lib_path, local = TRUE)
  full <- turas_pins_js(include_vendor = TRUE)
  stripped <- strip_vendor(full)

  # Vendor libs are ~676KB; stripped should be at least 500KB smaller
  savings_kb <- (nchar(full) - nchar(stripped)) / 1024
  expect_true(savings_kb > 500, info = sprintf("Savings: %.0f KB", savings_kb))
})
