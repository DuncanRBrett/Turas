# ==============================================================================
# Tests for modules/brand/R/00_brand_colour_utils.R
# build_full_brand_colour_map() — position-based colour assignment
# ==============================================================================

library(testthat)

# Source the utils directly so this file can run standalone
source(testthat::test_path("../../R/00_brand_colour_utils.R"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

make_brands <- function(codes, colours = NULL) {
  df <- data.frame(BrandCode = codes, stringsAsFactors = FALSE)
  if (!is.null(colours)) df$Colour <- colours
  df
}


# ---------------------------------------------------------------------------
# 1. Input validation
# ---------------------------------------------------------------------------

test_that("returns empty list for NULL brand_list", {
  expect_equal(build_full_brand_colour_map(NULL), list())
})

test_that("returns empty list for zero-row data frame", {
  expect_equal(build_full_brand_colour_map(data.frame(BrandCode = character(0))), list())
})

test_that("returns empty list when BrandCode column is missing", {
  df <- data.frame(Code = c("A", "B"))
  expect_equal(build_full_brand_colour_map(df), list())
})


# ---------------------------------------------------------------------------
# 2. Basic assignment — no explicit colours, no focal
# ---------------------------------------------------------------------------

test_that("assigns a colour to every brand", {
  brands <- make_brands(c("A", "B", "C"))
  result <- build_full_brand_colour_map(brands)
  expect_equal(sort(names(result)), c("A", "B", "C"))
  expect_true(all(nzchar(unlist(result))))
})

test_that("assigned colours are valid hex strings", {
  brands <- make_brands(c("A", "B", "C"))
  result <- build_full_brand_colour_map(brands)
  for (col in unlist(result)) {
    expect_true(grepl("^#[0-9A-Fa-f]{6}$", col),
                info = paste("invalid hex:", col))
  }
})

test_that("three brands get three distinct colours", {
  brands <- make_brands(c("A", "B", "C"))
  result <- build_full_brand_colour_map(brands)
  expect_equal(length(unique(unlist(result))), 3)
})

test_that("sequential brands use sequential palette entries", {
  brands <- make_brands(c("A", "B", "C"))
  result <- build_full_brand_colour_map(brands)
  expect_equal(result[["A"]], BRAND_COLOUR_PALETTE[[1]])
  expect_equal(result[["B"]], BRAND_COLOUR_PALETTE[[2]])
  expect_equal(result[["C"]], BRAND_COLOUR_PALETTE[[3]])
})


# ---------------------------------------------------------------------------
# 3. Focal brand handling
# ---------------------------------------------------------------------------

test_that("focal brand gets focal_colour, not palette slot", {
  brands <- make_brands(c("FOC", "A", "B"))
  result <- build_full_brand_colour_map(brands, focal_code = "FOC",
                                         focal_colour = "#123456")
  expect_equal(result[["FOC"]], "#123456")
})

test_that("non-focal brands are unaffected by focal_colour", {
  brands  <- make_brands(c("FOC", "A", "B"))
  result  <- build_full_brand_colour_map(brands, focal_code = "FOC",
                                          focal_colour = "#123456")
  expect_false(result[["A"]] == "#123456")
  expect_false(result[["B"]] == "#123456")
})

test_that("focal brand skipped in palette slot count so non-focal get contiguous slots", {
  # FOC is focal → skips palette. A and B should take palette[1] and palette[2].
  brands <- make_brands(c("FOC", "A", "B"))
  result <- build_full_brand_colour_map(brands, focal_code = "FOC",
                                         focal_colour = "#111111")
  expect_equal(result[["A"]], BRAND_COLOUR_PALETTE[[1]])
  expect_equal(result[["B"]], BRAND_COLOUR_PALETTE[[2]])
})


# ---------------------------------------------------------------------------
# 4. Explicit Colour column overrides
# ---------------------------------------------------------------------------

test_that("explicit hex in Colour column takes priority", {
  brands <- make_brands(c("A", "B"), colours = c("#aabbcc", NA))
  result <- build_full_brand_colour_map(brands)
  expect_equal(result[["A"]], "#aabbcc")
})

test_that("explicit colour brand does not consume a palette slot", {
  # A has explicit hex; B should still get palette[1]
  brands <- make_brands(c("A", "B"), colours = c("#aabbcc", NA))
  result <- build_full_brand_colour_map(brands)
  expect_equal(result[["B"]], BRAND_COLOUR_PALETTE[[1]])
})

test_that("invalid hex in Colour column falls back to palette assignment", {
  brands <- make_brands(c("A", "B"), colours = c("notahex", NA))
  result <- build_full_brand_colour_map(brands)
  expect_equal(result[["A"]], BRAND_COLOUR_PALETTE[[1]])
  expect_equal(result[["B"]], BRAND_COLOUR_PALETTE[[2]])
})

test_that("explicit colour overrides focal_colour for the focal brand", {
  brands <- make_brands(c("FOC"), colours = c("#aabbcc"))
  result <- build_full_brand_colour_map(brands, focal_code = "FOC",
                                         focal_colour = "#112233")
  expect_equal(result[["FOC"]], "#aabbcc")
})


# ---------------------------------------------------------------------------
# 5. Large study — wraps palette without crashing
# ---------------------------------------------------------------------------

test_that("wraps palette gracefully when more brands than palette entries", {
  n      <- length(BRAND_COLOUR_PALETTE) + 3L
  brands <- make_brands(paste0("B", seq_len(n)))
  result <- build_full_brand_colour_map(brands)
  expect_equal(length(result), n)
  for (col in unlist(result)) {
    expect_true(grepl("^#[0-9A-Fa-f]{6}$", col))
  }
})


# ---------------------------------------------------------------------------
# 6. Known-answer: 15-brand study matches expected palette assignments
# ---------------------------------------------------------------------------

test_that("known 15-brand study produces correct first three assignments", {
  # IPK is focal. First three non-focal brands in order: A, B, C.
  codes  <- c("IPK", "A", "B", "C", paste0("X", 4:15))
  brands <- make_brands(codes)
  result <- build_full_brand_colour_map(brands, focal_code = "IPK",
                                         focal_colour = "#1A5276")
  expect_equal(result[["IPK"]], "#1A5276")
  expect_equal(result[["A"]], BRAND_COLOUR_PALETTE[[1]])
  expect_equal(result[["B"]], BRAND_COLOUR_PALETTE[[2]])
  expect_equal(result[["C"]], BRAND_COLOUR_PALETTE[[3]])
})
