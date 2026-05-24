# ==============================================================================
# Tests for BrandCodeAlias support.
# ==============================================================================
# Reason this exists: IPK 2026 Wave 1 had Forage and Feast in POS programmed
# with option-value 'FNF' in the Alchemer survey, even though the canonical
# BrandCode in Survey_Structure_Brand.xlsx is 'FNFPS' (consistent with the
# other 6 categories). The mismatch made every F&F per-brand column (BRANDATT,
# WOM_COUNT) invisible to the engine — F&F appeared as 0 across the POS WOM
# panel and POS attribute matrix even though the underlying data was complete.
#
# BrandCodeAlias on the Brands sheet declares the alternate suffix /
# slot-option-value. The brand-matrix helpers in 00_data_access.R fall back
# to the alias when the canonical column / value is absent. The same alias
# applies to both shapes:
#   * multi_mention_brand_matrix() — slot value lookup (BRANDAWARE_, BRANDPEN2_)
#   * single_response_brand_matrix() — per-brand column suffix (BRANDATT1_<cat>_)
#   * slot_paired_numeric_matrix() — code-slot value lookup (BRANDPEN2 piped)
#   * respondent_picked() — single-brand slot value lookup
# ==============================================================================

library(testthat)

.find_root_alias <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_alias()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))


# Synthetic fixture: 6 respondents, 3 brands. Brand "AAA" is well-formed.
# Brand "BBB" has an alias: canonical BrandCode = "BBB" but the survey used
# the option-value "B" in slots and "B" as the column suffix. Brand "CCC"
# has no alias (sanity baseline).
mk_alias_fixture <- function() {
  data <- data.frame(
    # Multi-mention awareness slots (slot value = option code)
    AWARE_POS_1 = c("AAA",  "BBB", "B",   "AAA", NA,    "CCC"),
    AWARE_POS_2 = c("CCC",  NA,    "AAA", "B",   "AAA", NA),
    AWARE_POS_3 = rep(NA_character_, 6),
    # Slot-paired buyer flag (multi-mention) + frequency
    PEN_POS_1   = c("AAA", "B",   NA,    "AAA", NA,    "CCC"),
    PEN_POS_2   = c(NA,    NA,    "AAA", "B",   "CCC", NA),
    FREQ_POS_1  = c(5L,    3L,    NA,    4L,    NA,    1L),
    FREQ_POS_2  = c(NA,    NA,    2L,    1L,    1L,    NA),
    # Per-brand attitude columns. Note: BBB's data column is named with the
    # alias suffix "B" (Alchemer programmer used a different SKU than the
    # canonical BrandCode).
    ATT_POS_AAA = c(1, 2, 3, 1, 4, 2),
    ATT_POS_B   = c(2, 1, NA, 3, 1, 2),  # alias suffix for BBB
    ATT_POS_CCC = c(3, 3, 4, 2, 2, 1),
    stringsAsFactors = FALSE
  )

  brand_list <- data.frame(
    BrandCode      = c("AAA", "BBB", "CCC"),
    BrandLabel     = c("Alpha", "Bravo", "Charlie"),
    BrandCodeAlias = c(NA,    "B",   NA),
    stringsAsFactors = FALSE
  )
  list(data = data, brand_list = brand_list)
}


test_that(".brand_aliases_from_list extracts only declared aliases", {
  fx <- mk_alias_fixture()
  aliases <- .brand_aliases_from_list(fx$brand_list)
  expect_identical(aliases, c(BBB = "B"))
})


test_that(".brand_aliases_from_list returns NULL when column absent", {
  bl <- data.frame(BrandCode = "X", BrandLabel = "X",
                   stringsAsFactors = FALSE)
  expect_null(.brand_aliases_from_list(bl))
})


test_that(".brand_aliases_from_list returns NULL when every alias is blank", {
  bl <- data.frame(
    BrandCode = c("X", "Y"),
    BrandCodeAlias = c(NA, ""),
    stringsAsFactors = FALSE
  )
  expect_null(.brand_aliases_from_list(bl))
})


test_that(".brand_aliases_from_list drops self-aliases", {
  bl <- data.frame(
    BrandCode = c("X", "Y"),
    BrandCodeAlias = c("X", "Y2"),  # X aliased to itself = no-op
    stringsAsFactors = FALSE
  )
  expect_identical(.brand_aliases_from_list(bl), c(Y = "Y2"))
})


test_that("multi_mention_brand_matrix resolves slot values via the alias", {
  fx <- mk_alias_fixture()
  brand_codes <- c("AAA", "BBB", "CCC")
  aliases <- .brand_aliases_from_list(fx$brand_list)

  # Without aliases: BBB matches only the canonical "BBB" slot value in
  # row 2 (slot 1). Rows 3 + 4 (slot values "B") are missed.
  no_alias <- multi_mention_brand_matrix(fx$data, "AWARE_POS", brand_codes)
  expect_identical(no_alias[, "BBB"],
                   c(FALSE, TRUE, FALSE, FALSE, FALSE, FALSE))

  # With aliases: BBB picks up the canonical row 2 PLUS the alias rows 3
  # (slot 1 = "B") and 4 (slot 2 = "B").
  with_alias <- multi_mention_brand_matrix(fx$data, "AWARE_POS", brand_codes,
                                            brand_aliases = aliases)
  expect_identical(with_alias[, "BBB"],
                   c(FALSE, TRUE, TRUE, TRUE, FALSE, FALSE))

  # AAA + CCC unaffected — exact match wins:
  expect_identical(with_alias[, "AAA"],
                   c(TRUE, FALSE, TRUE, TRUE, TRUE, FALSE))
  expect_identical(with_alias[, "CCC"],
                   c(TRUE, FALSE, FALSE, FALSE, FALSE, TRUE))
})


test_that("multi_mention_brand_matrix accepts brand_list data frame and auto-detects aliases", {
  fx <- mk_alias_fixture()
  mat <- multi_mention_brand_matrix(fx$data, "AWARE_POS", fx$brand_list)
  # Same as the explicit-alias path above
  expect_identical(mat[, "BBB"],
                   c(FALSE, TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_identical(colnames(mat), c("AAA", "BBB", "CCC"))
})


test_that("single_response_brand_matrix falls back to alias column suffix", {
  fx <- mk_alias_fixture()
  brand_codes <- c("AAA", "BBB", "CCC")
  aliases <- .brand_aliases_from_list(fx$brand_list)

  # Without alias: BBB column is all NA (no ATT_POS_BBB in data).
  no_alias <- single_response_brand_matrix(fx$data, "ATT", "POS", brand_codes)
  expect_true(all(is.na(no_alias[, "BBB"])))

  # With alias: BBB picks up the ATT_POS_B column.
  with_alias <- single_response_brand_matrix(fx$data, "ATT", "POS",
                                              brand_codes,
                                              brand_aliases = aliases)
  expect_identical(as.character(with_alias[, "BBB"]),
                   as.character(c(2, 1, NA, 3, 1, 2)))
  # AAA + CCC unchanged.
  expect_identical(as.character(with_alias[, "AAA"]),
                   as.character(c(1, 2, 3, 1, 4, 2)))
})


test_that("single_response_brand_matrix prefers exact match over alias", {
  # If both the exact column AND an alias column exist, the exact one wins.
  fx <- mk_alias_fixture()
  fx$data$ATT_POS_BBB <- c(9, 9, 9, 9, 9, 9)  # exact match column
  aliases <- .brand_aliases_from_list(fx$brand_list)
  mat <- single_response_brand_matrix(fx$data, "ATT", "POS",
                                       c("AAA", "BBB", "CCC"),
                                       brand_aliases = aliases)
  expect_identical(as.character(mat[, "BBB"]), rep("9", 6))
})


test_that("slot_paired_numeric_matrix sums values via alias", {
  fx <- mk_alias_fixture()
  brand_codes <- c("AAA", "BBB", "CCC")
  aliases <- .brand_aliases_from_list(fx$brand_list)

  # Without alias: BBB column is 0 for every respondent.
  no_alias <- slot_paired_numeric_matrix(fx$data, "PEN_POS", "FREQ_POS",
                                          brand_codes)
  expect_true(all(no_alias[, "BBB"] == 0))

  # With alias: BBB rows 2 (3, slot 1) and 4 (1, slot 2) match.
  with_alias <- slot_paired_numeric_matrix(fx$data, "PEN_POS", "FREQ_POS",
                                            brand_codes,
                                            brand_aliases = aliases)
  expect_equal(with_alias[, "BBB"], c(0, 3, 0, 1, 0, 0))
})


test_that("respondent_picked honours aliases for the focal brand", {
  fx <- mk_alias_fixture()
  # Without aliases, picking 'BBB' catches only row 2 (slot 1 = "BBB").
  no_alias <- respondent_picked(fx$data, "AWARE_POS", "BBB")
  expect_identical(no_alias, c(FALSE, TRUE, FALSE, FALSE, FALSE, FALSE))

  # With the alias passed explicitly, rows 3 and 4 (slot value "B") join.
  with_alias <- respondent_picked(fx$data, "AWARE_POS", "BBB",
                                   aliases = "B")
  expect_identical(with_alias, c(FALSE, TRUE, TRUE, TRUE, FALSE, FALSE))
})


test_that("alias union: canonical and alias values both count toward the same brand", {
  # IPK case: some categories used the canonical BrandCode, others used an
  # alias SKU. The match should be a UNION so every respondent who picked
  # EITHER value counts as picking BBB.
  fx <- mk_alias_fixture()
  aliases <- .brand_aliases_from_list(fx$brand_list)
  mat <- multi_mention_brand_matrix(fx$data, "AWARE_POS",
                                     c("AAA", "BBB", "CCC"),
                                     brand_aliases = aliases)
  # Row 2: slot 1 = "BBB" (canonical)
  # Row 3: slot 1 = "B"   (alias)
  # Row 4: slot 2 = "B"   (alias)
  expect_identical(mat[, "BBB"],
                   c(FALSE, TRUE, TRUE, TRUE, FALSE, FALSE))
})


# ------------------------------------------------------------------------------
# End-to-end: WOM path with an alias-bearing brand
# ------------------------------------------------------------------------------

test_that("run_wom resolves WOM panel values via BrandCodeAlias", {
  source(file.path(ROOT, "modules", "brand", "R", "05_wom.R"))
  set.seed(1)
  n <- 50
  data <- data.frame(
    # Heard / shared / received slots (multi-mention): some respondents
    # recorded 'B', others recorded 'BBB' for the same brand.
    wom_pos_rec_POS_1   = sample(c("AAA", "B", NA), n, replace = TRUE),
    wom_pos_rec_POS_2   = sample(c("BBB", "CCC", NA), n, replace = TRUE),
    wom_neg_rec_POS_1   = sample(c("AAA", "B", NA), n, replace = TRUE),
    wom_pos_share_POS_1 = sample(c("AAA", "B", NA), n, replace = TRUE),
    wom_neg_share_POS_1 = sample(c("AAA", NA), n, replace = TRUE),
    # Per-brand frequency columns — BBB's column suffix is "B" (alias).
    wom_pos_count_POS_AAA = sample(c(0, 1, 2, NA), n, replace = TRUE),
    wom_pos_count_POS_B   = sample(c(0, 1, 2, NA), n, replace = TRUE),
    wom_pos_count_POS_CCC = sample(c(0, 1, 2, NA), n, replace = TRUE),
    wom_neg_count_POS_AAA = sample(c(0, 1, NA),    n, replace = TRUE),
    wom_neg_count_POS_B   = sample(c(0, 1, NA),    n, replace = TRUE),
    wom_neg_count_POS_CCC = sample(c(0, 1, NA),    n, replace = TRUE),
    stringsAsFactors = FALSE
  )

  brand_list <- data.frame(
    BrandCode      = c("AAA", "BBB", "CCC"),
    BrandLabel     = c("Alpha", "Bravo", "Charlie"),
    BrandCodeAlias = c(NA,    "B",   NA),
    stringsAsFactors = FALSE
  )

  role_map <- list(
    wom.pos_rec.POS   = list(column_root = "wom_pos_rec_POS"),
    wom.neg_rec.POS   = list(column_root = "wom_neg_rec_POS"),
    wom.pos_share.POS = list(column_root = "wom_pos_share_POS"),
    wom.neg_share.POS = list(column_root = "wom_neg_share_POS"),
    wom.pos_count.POS = list(client_code = "wom_pos_count"),
    wom.neg_count.POS = list(client_code = "wom_neg_count")
  )

  out <- run_wom(data, role_map, "POS", brand_list)
  expect_identical(out$status, "PASS")
  # BBB row must NOT be all-zero — the alias resolves its data.
  bbb_row <- out$wom_metrics[out$wom_metrics$BrandCode == "BBB", ]
  expect_true(nrow(bbb_row) == 1L)
  expect_true(bbb_row$ReceivedPos_Pct > 0 ||
               bbb_row$SharedPos_Pct  > 0 ||
               bbb_row$SharedPosFreq_Mean > 0,
              info = "BBB's WOM metrics should pick up the alias-suffix data")
})
