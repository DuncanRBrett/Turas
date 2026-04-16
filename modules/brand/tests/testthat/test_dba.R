# ==============================================================================
# BRAND MODULE TESTS - DBA ELEMENT
# ==============================================================================

.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
TURAS_ROOT <- .find_turas_root_for_test()
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "07_dba.R"))


# ==============================================================================
# KNOWN-DATA TESTS
# ==============================================================================

test_that("DBA Fame calculated correctly", {
  # 5 respondents
  # Asset LOGO: fame col = 1 (Yes), 3 (Not sure), 2 (No), 1 (Yes), NA
  data <- data.frame(
    DBA_FAME_LOGO = c(1, 3, 2, 1, NA),
    DBA_UNIQUE_LOGO = c("IPK", "OTHER", NA, "IPK", NA),
    stringsAsFactors = FALSE
  )

  assets <- data.frame(
    AssetCode = "LOGO", AssetLabel = "Brand Logo",
    FameQuestionCode = "DBA_FAME_LOGO",
    UniqueQuestionCode = "DBA_UNIQUE_LOGO",
    stringsAsFactors = FALSE
  )

  result <- run_dba(data, assets, focal_brand = "IPK")

  expect_equal(result$status, "PASS")
  # Recognised = Yes(1) + Not Sure(3) = codes 1,3 -> 3 out of 5 = 60%
  expect_equal(result$dba_metrics$Fame_Pct, 60)
  expect_equal(result$dba_metrics$Fame_n, 3)
})

test_that("DBA Uniqueness calculated correctly (open-ended)", {
  # 4 recognisers, 2 correctly attributed to IPK
  data <- data.frame(
    DBA_FAME_LOGO = c(1, 1, 3, 1),  # all recognised
    DBA_UNIQUE_LOGO = c("IPK", "OTHER", "ipk", "COMPETITOR"),
    stringsAsFactors = FALSE
  )

  assets <- data.frame(
    AssetCode = "LOGO", AssetLabel = "Logo",
    FameQuestionCode = "DBA_FAME_LOGO",
    UniqueQuestionCode = "DBA_UNIQUE_LOGO",
    stringsAsFactors = FALSE
  )

  result <- run_dba(data, assets, focal_brand = "IPK",
                    attribution_type = "open")

  # Correct attribution: "IPK" and "ipk" (case-insensitive) -> 2 of 4 = 50%
  expect_equal(result$dba_metrics$Uniqueness_Pct, 50)
  expect_equal(result$dba_metrics$Uniqueness_n, 2)
})

test_that("DBA quadrant classification correct", {
  data <- data.frame(
    # Asset 1: high fame, high uniqueness -> Use or Lose
    DBA_F_1 = c(1, 1, 1, 1, 2),  # 80% fame
    DBA_U_1 = c("IPK", "IPK", "IPK", "OTHER", NA),  # 75% uniqueness among recognisers
    # Asset 2: high fame, low uniqueness -> Avoid Alone
    DBA_F_2 = c(1, 1, 1, 1, 2),  # 80% fame
    DBA_U_2 = c("IPK", "OTHER", "OTHER", "OTHER", NA),  # 25% uniqueness
    # Asset 3: low fame, high uniqueness -> Invest to Build
    DBA_F_3 = c(1, 2, 2, 2, 2),  # 20% fame
    DBA_U_3 = c("IPK", NA, NA, NA, NA),  # 100% uniqueness
    # Asset 4: low fame, low uniqueness -> Ignore or Test
    DBA_F_4 = c(1, 2, 2, 2, 2),  # 20% fame
    DBA_U_4 = c("OTHER", NA, NA, NA, NA),  # 0% uniqueness
    stringsAsFactors = FALSE
  )

  assets <- data.frame(
    AssetCode = c("A1", "A2", "A3", "A4"),
    AssetLabel = c("Logo", "Colour", "Mascot", "Sonic"),
    FameQuestionCode = c("DBA_F_1", "DBA_F_2", "DBA_F_3", "DBA_F_4"),
    UniqueQuestionCode = c("DBA_U_1", "DBA_U_2", "DBA_U_3", "DBA_U_4"),
    stringsAsFactors = FALSE
  )

  result <- run_dba(data, assets, focal_brand = "IPK")

  m <- result$dba_metrics
  expect_equal(m$Quadrant[m$AssetCode == "A1"], "Use or Lose")
  expect_equal(m$Quadrant[m$AssetCode == "A2"], "Avoid Alone")
  expect_equal(m$Quadrant[m$AssetCode == "A3"], "Invest to Build")
  expect_equal(m$Quadrant[m$AssetCode == "A4"], "Ignore or Test")
})

test_that("DBA with custom thresholds", {
  data <- data.frame(
    DBA_F = c(1, 1, 2, 2, 2),  # 40% fame
    DBA_U = c("IPK", "IPK", NA, NA, NA),  # 100% uniqueness
    stringsAsFactors = FALSE
  )
  assets <- data.frame(
    AssetCode = "A1", AssetLabel = "Logo",
    FameQuestionCode = "DBA_F", UniqueQuestionCode = "DBA_U",
    stringsAsFactors = FALSE
  )

  # Default thresholds (50/50): 40% fame = low -> Invest to Build
  result_default <- run_dba(data, assets, "IPK")
  expect_equal(result_default$dba_metrics$Quadrant, "Invest to Build")

  # Lower threshold (30/30): 40% fame = high, 100% unique = high -> Use or Lose
  result_low <- run_dba(data, assets, "IPK",
                        fame_threshold = 0.30, uniqueness_threshold = 0.30)
  expect_equal(result_low$dba_metrics$Quadrant, "Use or Lose")
})

test_that("DBA metrics_summary populated correctly", {
  data <- data.frame(
    DBA_F = c(1, 1, 1),
    DBA_U = c("IPK", "IPK", "OTHER"),
    stringsAsFactors = FALSE
  )
  assets <- data.frame(
    AssetCode = "LOGO", AssetLabel = "Logo",
    FameQuestionCode = "DBA_F", UniqueQuestionCode = "DBA_U",
    stringsAsFactors = FALSE
  )

  result <- run_dba(data, assets, "IPK")

  ms <- result$metrics_summary
  expect_equal(ms$focal_brand, "IPK")
  expect_equal(ms$n_assets, 1)
  expect_true(ms$n_use_or_lose + ms$n_avoid_alone +
              ms$n_invest + ms$n_ignore == 1)
})

test_that("DBA with weights", {
  data <- data.frame(
    DBA_F = c(1, 2),  # resp 1 recognised, resp 2 not
    DBA_U = c("IPK", NA),
    stringsAsFactors = FALSE
  )
  assets <- data.frame(
    AssetCode = "LOGO", AssetLabel = "Logo",
    FameQuestionCode = "DBA_F", UniqueQuestionCode = "DBA_U",
    stringsAsFactors = FALSE
  )

  # Unweighted: fame = 50%
  result_unw <- run_dba(data, assets, "IPK")
  expect_equal(result_unw$dba_metrics$Fame_Pct, 50)

  # Weighted: resp 1 (recognised) weight=3 -> fame = 75%
  result_wtd <- run_dba(data, assets, "IPK", weights = c(3, 1))
  expect_equal(result_wtd$dba_metrics$Fame_Pct, 75)
})

test_that("DBA refuses empty data", {
  result <- run_dba(data.frame(), data.frame(), "IPK")
  expect_equal(result$status, "REFUSED")
})

test_that("DBA refuses no assets", {
  result <- run_dba(data.frame(x = 1), data.frame(), "IPK")
  expect_equal(result$status, "REFUSED")
})

test_that("DBA closed_list attribution type works", {
  data <- data.frame(
    DBA_F = c(1, 1, 1),
    DBA_U = c("IPK", "COMP", "IPK"),  # 2/3 correct
    stringsAsFactors = FALSE
  )
  assets <- data.frame(
    AssetCode = "LOGO", AssetLabel = "Logo",
    FameQuestionCode = "DBA_F", UniqueQuestionCode = "DBA_U",
    stringsAsFactors = FALSE
  )

  result <- run_dba(data, assets, "IPK", attribution_type = "closed_list")
  expect_equal(result$dba_metrics$Uniqueness_Pct, round(2/3 * 100, 1))
})
