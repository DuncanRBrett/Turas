# ==============================================================================
# TESTS — Shopper context + focal engagement engines (14_shopper_summary.R)
# ==============================================================================
# Two thin sample-wide engines. Tests cover:
#   - happy-path percentages
#   - NULL-safety when source columns are absent
#   - conditional base on focal-brand recipe question (RECIPE != Never)
#   - panel HTML renders + skips sections cleanly when engines return NULL
# ==============================================================================

context("Shopper summary engines + panel")

source_brand_module <- function() {
  if (!exists("compute_shopper_context", mode = "function") ||
      !exists("compute_focal_engagement", mode = "function")) {
    source(file.path("..", "..", "R", "00_main.R"), local = FALSE)
  }
}

source_brand_module()

panels_dir <- file.path("..", "..", "lib", "html_report", "panels")
if (dir.exists(panels_dir) &&
    !exists("build_shopper_summary_sections", mode = "function")) {
  for (f in sort(list.files(panels_dir, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}


# Minimal 4-respondent fixture covering every question. Hand-verified counts
# below — engines should match exactly.
.fixture_data <- function() {
  data.frame(
    GroceryChains_1 = c("Checkers", "Checkers", NA, "Pick n Pay"),
    GroceryChains_2 = c("Woolworths", NA, "Woolworths", NA),
    MEDIA_1         = c("YouTube", "YouTube", "TV", NA),
    MEDIA_2         = c(NA, "Facebook", NA, "Facebook"),
    RECIPE          = c("Always", "Sometimes", "Never", "Often"),
    IPKWEB          = c("Yes", "Yes", "No", "No"),
    IPKBOOK         = c("Yes", "No", "No", "No"),
    IPK_RECIPE      = c("Yes", "Yes", "No", NA),
    stringsAsFactors = FALSE
  )
}


# Stub Options sheet (engines fall back to data-derived values when absent).
.fixture_structure <- function() list()


test_that("compute_shopper_context: grocery + media + recipe percentages match hand-counts", {
  ctx <- compute_shopper_context(.fixture_data(), .fixture_structure())
  expect_false(is.null(ctx))
  expect_equal(ctx$n_total, 4L)

  # Grocery: Checkers=2, Woolworths=2, Pick n Pay=1 → 50/50/25%
  groc_by_label <- setNames(
    vapply(ctx$grocery$rows, function(r) r$n, integer(1)),
    vapply(ctx$grocery$rows, function(r) r$label, character(1)))
  expect_equal(groc_by_label[["Checkers"]],     2L)
  expect_equal(groc_by_label[["Woolworths"]],   2L)
  expect_equal(groc_by_label[["Pick n Pay"]],   1L)

  # Media: YouTube=2, Facebook=2, TV=1 → 50/50/25%
  media_by_label <- setNames(
    vapply(ctx$media$rows, function(r) r$pct_weighted, numeric(1)),
    vapply(ctx$media$rows, function(r) r$label, character(1)))
  expect_equal(media_by_label[["YouTube"]], 50)
  expect_equal(media_by_label[["TV"]], 25)

  # Recipe-use distribution: each of 4 respondents gives a different value
  expect_equal(length(ctx$recipe_use$rows), 4L)
})


test_that("compute_shopper_context: returns NULL when all source columns absent", {
  data <- data.frame(other = 1:3, stringsAsFactors = FALSE)
  expect_null(compute_shopper_context(data, list()))
})


test_that("compute_focal_engagement: yes-percent + conditional base on focal recipe", {
  eng <- compute_focal_engagement(.fixture_data(), focal_brand = "IPK")
  expect_false(is.null(eng))
  expect_equal(eng$focal_brand, "IPK")

  # IPKWEB: 2 Yes of 4 → 50%
  expect_equal(eng$website$n_total, 4L)
  expect_equal(eng$website$n_yes, 2L)
  expect_equal(eng$website$pct_yes, 50)

  # IPKBOOK: 1 Yes of 4 → 25%
  expect_equal(eng$books$pct_yes, 25)

  # IPK_RECIPE: conditional on RECIPE != Never. RECIPE has 1 "Never" row, so
  # base = 3 respondents; of those 3, the Yes/No data is Yes/Yes/NA
  # (no respondent with Never), so n_total=2 (NA excluded), n_yes=2 → 100%.
  expect_equal(eng$recipes_tried$n_total, 2L)
  expect_equal(eng$recipes_tried$n_yes,   2L)
  expect_equal(eng$recipes_tried$pct_yes, 100)
  expect_true(grepl("RECIPE", eng$recipes_tried$base_note))
})


test_that("compute_focal_engagement: returns NULL when focal-brand columns absent", {
  data <- data.frame(GroceryChains_1 = c("Checkers"), stringsAsFactors = FALSE)
  expect_null(compute_focal_engagement(data, focal_brand = "XYZ"))
})


test_that("build_shopper_summary_sections: renders sections when data present", {
  skip_if_not(exists("build_shopper_summary_sections", mode = "function"))
  ctx <- compute_shopper_context(.fixture_data(), .fixture_structure())
  eng <- compute_focal_engagement(.fixture_data(), focal_brand = "IPK")
  html <- build_shopper_summary_sections(
    list(shopper_context = ctx, focal_engagement = eng),
    list(focal_brand = "IPK", colour_focal = "#000000",
         brand_colours = list(IPK = "#000000")))
  expect_true(nchar(html) > 0)
  expect_true(grepl("brss-section", html))
  expect_true(grepl("IPK engagement", html))
  expect_true(grepl("Grocery chains", html))
})


test_that("build_shopper_summary_sections: returns empty when both engines NULL", {
  skip_if_not(exists("build_shopper_summary_sections", mode = "function"))
  html <- build_shopper_summary_sections(
    list(shopper_context = NULL, focal_engagement = NULL),
    list(focal_brand = "IPK"))
  expect_equal(html, "")
})


test_that("compute_buying_location: picks up CHANNEL_<CAT> slot pattern", {
  data <- data.frame(
    CHANNEL_DSS_1 = c("SPMKT", "SPMKT", "DELI", NA),
    CHANNEL_DSS_2 = c("DELI", NA, NA, "ONLINE"),
    stringsAsFactors = FALSE
  )
  res <- compute_buying_location(data, "DSS", structure = list())
  expect_false(is.null(res))
  expect_equal(res$cat_code, "DSS")
  expect_equal(res$n_total, 4L)
  by_label <- setNames(vapply(res$rows, function(r) r$n, integer(1)),
                       vapply(res$rows, function(r) r$label, character(1)))
  expect_equal(by_label[["SPMKT"]], 2L)
  expect_equal(by_label[["DELI"]],  2L)
  expect_equal(by_label[["ONLINE"]], 1L)
})


test_that("compute_buying_location: falls back to CAT_LOC_<CAT> legacy naming", {
  data <- data.frame(
    CAT_LOC_BAK_1 = c("SPMKT", "DELI"),
    CAT_LOC_BAK_2 = c(NA, NA),
    stringsAsFactors = FALSE
  )
  res <- compute_buying_location(data, "BAK", structure = list())
  expect_false(is.null(res))
  expect_equal(res$n_total, 2L)
  expect_equal(length(res$rows), 2L)
})


test_that("compute_buying_location: NULL when neither root present", {
  data <- data.frame(other = 1:3, stringsAsFactors = FALSE)
  expect_null(compute_buying_location(data, "DSS", structure = list()))
})


test_that("infer_role_map: CAT_FREQ + CAT_LOC aliases produce expected roles", {
  brands <- data.frame(
    CategoryCode = c("DSS", "BAK"), Category = c("DSS", "BAK"),
    BrandCode = c("IPK", "IPK"), BrandLabel = c("IPK", "IPK"),
    stringsAsFactors = FALSE)
  questions <- data.frame(
    QuestionCode = c("CATBUY_DSS", "CAT_FREQ_BAK",
                     "CHANNEL_DSS", "CAT_LOC_BAK"),
    Variable_Type = c("Single_Response", "Single_Response",
                       "Multi_Mention", "Multi_Mention"),
    stringsAsFactors = FALSE)
  rm <- infer_role_map(questions, brands, active_cats = c("DSS", "BAK"))
  # Frequency: both DSS (legacy CATBUY) and BAK (new CAT_FREQ) resolve
  expect_true("cat_buying.frequency.DSS" %in% names(rm))
  expect_true("cat_buying.frequency.BAK" %in% names(rm))
  # Channels: each column emits BOTH role aliases
  expect_true("cat_buying.channel.DSS" %in% names(rm))
  expect_true("channel.purchase.DSS"   %in% names(rm))
  expect_true("cat_buying.channel.BAK" %in% names(rm))
  expect_true("channel.purchase.BAK"   %in% names(rm))
  expect_equal(rm[["channel.purchase.BAK"]]$column_root, "CAT_LOC_BAK")
})
