# ==============================================================================
# Tests for 00_role_inference.R + 00_role_map.R
# ==============================================================================
library(testthat)

source(file.path("..", "..", "R", "00_role_inference.R"))
source(file.path("..", "..", "R", "00_role_map.R"))


# Common fixtures
mk_questions <- function() {
  data.frame(
    QuestionCode = c(
      "Focal_Category", "Wave", "SQ1", "SQ2",
      "BRANDAWARE_DSS", "BRANDAWARE_POS",
      "BRANDPEN1_DSS", "BRANDPEN2_DSS", "BRANDPEN3_DSS",
      "BRANDATT1_DSS_IPK", "BRANDATT1_DSS_ROB",
      "BRANDATT2_DSS_IPK",
      "BRANDATTR_DSS_CEP01", "BRANDATTR_DSS_CEP02",
      "BRANDATTR_DSS_ATT01",
      "WOM_POS_REC_DSS", "WOM_POS_SHARE_DSS",
      "WOM_NEG_REC_DSS", "WOM_NEG_SHARE_DSS",
      "WOM_POS_COUNT_DSS_IPK", "WOM_NEG_COUNT_DSS_IPK",
      "CATBUY_DSS", "CATCOUNT_DSS",
      "CHANNEL_DSS", "PACK_DSS",
      "DEMO_AGE", "DEMO_GENDER",
      "ADHOC_NPS", "ADHOC_FUTURE_DSS"
    ),
    QuestionText = "Q",
    Variable_Type = c(
      "Single_Response", "Single_Response", "Multi_Mention", "Multi_Mention",
      "Multi_Mention", "Multi_Mention",
      "Multi_Mention", "Multi_Mention", "Multi_Mention",
      "Single_Response", "Single_Response",
      "Open_End",
      "Multi_Mention", "Multi_Mention",
      "Multi_Mention",
      "Multi_Mention", "Multi_Mention",
      "Multi_Mention", "Multi_Mention",
      "Single_Response", "Single_Response",
      "Single_Response", "Numeric",
      "Multi_Mention", "Multi_Mention",
      "Single_Response", "Single_Response",
      "Single_Response", "Single_Response"
    ),
    Columns = 1L,
    stringsAsFactors = FALSE
  )
}

mk_brands <- function() {
  data.frame(
    Category = "Dry Seasonings", CategoryCode = c("DSS", "DSS", "DSS",
                                                  "POS", "POS"),
    BrandCode = c("IPK", "ROB", "KNORR", "IPK", "KNORR"),
    BrandLabel = c("IPK", "ROB", "KNORR", "IPK", "KNORR"),
    DisplayOrder = c(1, 2, 3, 1, 2),
    IsFocal = c("Y", "N", "N", "Y", "N"),
    stringsAsFactors = FALSE
  )
}

mk_brand_config <- function(active = c("DSS", "POS")) {
  list(categories = data.frame(
    CategoryCode = c("DSS", "POS", "PAS"),
    Active = c(if ("DSS" %in% active) "Y" else "N",
               if ("POS" %in% active) "Y" else "N",
               if ("PAS" %in% active) "Y" else "N"),
    stringsAsFactors = FALSE
  ))
}


# ------------------------------------------------------------------------------
# infer_role_map — convention-first inference
# ------------------------------------------------------------------------------

test_that("infer_role_map covers the canonical IPK pattern set", {
  rm <- infer_role_map(mk_questions(), mk_brands(), c("DSS", "POS"))

  # System
  expect_true("system.focal_category" %in% names(rm))
  expect_true("system.wave" %in% names(rm))
  expect_true("screener.sq1" %in% names(rm))
  expect_true("screener.sq2" %in% names(rm))

  # Funnel: awareness, attitude, penetration1/2/3
  expect_true("funnel.awareness.DSS" %in% names(rm))
  expect_true("portfolio.awareness.DSS" %in% names(rm))
  expect_true("funnel.awareness.POS" %in% names(rm))
  expect_true("funnel.penetration_long.DSS" %in% names(rm))
  expect_true("funnel.penetration_target.DSS" %in% names(rm))
  expect_true("funnel.frequency.DSS" %in% names(rm))
  expect_true("funnel.attitude.DSS" %in% names(rm))
  expect_true("funnel.rejection_oe.DSS" %in% names(rm))

  # MA
  expect_true("mental_avail.cep.DSS.CEP01" %in% names(rm))
  expect_true("mental_avail.cep.DSS.CEP02" %in% names(rm))
  expect_true("mental_avail.attr.DSS.ATT01" %in% names(rm))

  # WOM
  expect_true("wom.pos_rec.DSS" %in% names(rm))
  expect_true("wom.pos_share.DSS" %in% names(rm))
  expect_true("wom.neg_rec.DSS" %in% names(rm))
  expect_true("wom.neg_share.DSS" %in% names(rm))
  expect_true("wom.pos_count.DSS" %in% names(rm))
  expect_true("wom.neg_count.DSS" %in% names(rm))

  # Cat buying
  expect_true("cat_buying.frequency.DSS" %in% names(rm))
  expect_true("cat_buying.count.DSS" %in% names(rm))
  expect_true("cat_buying.channel.DSS" %in% names(rm))
  expect_true("cat_buying.packsize.DSS" %in% names(rm))

  # Demographics
  expect_true("demographics.age" %in% names(rm))
  expect_true("demographics.gender" %in% names(rm))

  # Ad hoc
  expect_true("adhoc.nps.ALL" %in% names(rm))
  expect_true("adhoc.future.DSS" %in% names(rm))
})

test_that("infer_role_map skips inactive categories", {
  rm <- infer_role_map(mk_questions(), mk_brands(), active_cats = "DSS")
  # POS is inactive -> should not appear
  expect_false("funnel.awareness.POS" %in% names(rm))
  expect_true("funnel.awareness.DSS" %in% names(rm))
})

test_that("infer_role_map populates entry shape correctly", {
  rm <- infer_role_map(mk_questions(), mk_brands(), c("DSS"))

  e <- rm[["funnel.awareness.DSS"]]
  expect_equal(e$category, "DSS")
  expect_equal(e$column_root, "BRANDAWARE_DSS")
  expect_equal(e$variable_type, "Multi_Mention")
  expect_false(e$per_brand)
  expect_equal(sort(e$applicable_brands), c("IPK", "KNORR", "ROB"))

  e <- rm[["mental_avail.cep.DSS.CEP01"]]
  expect_equal(e$category, "DSS")
  expect_equal(e$column_root, "BRANDATTR_DSS_CEP01")
  expect_equal(e$detail$item_kind, "cep")
  expect_equal(e$detail$item_code, "CEP01")

  e <- rm[["funnel.attitude.DSS"]]
  # Compound per-brand entry: aggregates all per-brand questions for the
  # role into a single entry with applicable_brands listing every brand seen.
  expect_true(e$per_brand)
  expect_equal(e$column_root, "BRANDATT1_DSS")
  expect_equal(sort(e$applicable_brands), c("IPK", "ROB"))
  expect_equal(e$detail$pattern_kind, "per_brand_compound")
})


# ------------------------------------------------------------------------------
# build_brand_role_map — full pipeline (inference + override + resolution)
# ------------------------------------------------------------------------------

test_that("build_brand_role_map resolves slot columns against data", {
  structure <- list(
    questions = mk_questions(),
    brands = mk_brands(),
    questionmap = NULL
  )
  bc <- mk_brand_config(active = c("DSS"))

  # Synthetic data with slot columns matching IPK shape
  data <- data.frame(
    BRANDAWARE_DSS_1 = c("IPK", "ROB"),
    BRANDAWARE_DSS_2 = c("ROB", NA),
    BRANDAWARE_DSS_3 = c(NA, NA),
    BRANDPEN1_DSS_1 = c("IPK", NA),
    BRANDPEN1_DSS_2 = c(NA, NA),
    BRANDATT1_DSS_IPK = c(1L, 3L),
    BRANDATT1_DSS_ROB = c(2L, 4L),
    Focal_Category = c("DSS", "DSS"),
    stringsAsFactors = FALSE
  )

  rm <- build_brand_role_map(structure, bc, data)
  expect_equal(rm[["funnel.awareness.DSS"]]$columns,
               c("BRANDAWARE_DSS_1", "BRANDAWARE_DSS_2", "BRANDAWARE_DSS_3"))
  expect_equal(rm[["funnel.penetration_long.DSS"]]$columns,
               c("BRANDPEN1_DSS_1", "BRANDPEN1_DSS_2"))
  # Per-brand compound: columns is a NAMED character vector,
  # one entry per applicable_brand whose column exists in data
  att_entry <- rm[["funnel.attitude.DSS"]]
  expect_true(att_entry$per_brand)
  expect_equal(sort(names(att_entry$columns)), c("IPK", "ROB"))
  expect_equal(unname(att_entry$columns[c("IPK", "ROB")]),
               c("BRANDATT1_DSS_IPK", "BRANDATT1_DSS_ROB"))
})

test_that("build_brand_role_map applies QuestionMap overrides", {
  structure <- list(
    questions = mk_questions(),
    brands = mk_brands(),
    questionmap = data.frame(
      Role = "funnel.awareness.DSS",
      ColumnRoot = "CUSTOM_AWARENESS_DSS",
      Variable_Type = "Multi_Mention",
      OptionMapScale = NA_character_,
      stringsAsFactors = FALSE
    )
  )
  rm <- build_brand_role_map(structure, mk_brand_config(c("DSS")))
  expect_equal(rm[["funnel.awareness.DSS"]]$column_root,
               "CUSTOM_AWARENESS_DSS")
  expect_match(rm[["funnel.awareness.DSS"]]$notes, "QuestionMap override")
})

test_that("build_brand_role_map inserts a brand-new role from QuestionMap", {
  structure <- list(
    questions = mk_questions(),
    brands = mk_brands(),
    questionmap = data.frame(
      Role = "custom.something",
      ColumnRoot = "CUSTOM_COL",
      Variable_Type = "Single_Response",
      OptionMapScale = NA_character_,
      stringsAsFactors = FALSE
    )
  )
  rm <- build_brand_role_map(structure, mk_brand_config(c("DSS")))
  expect_true("custom.something" %in% names(rm))
  expect_equal(rm[["custom.something"]]$column_root, "CUSTOM_COL")
  expect_equal(rm[["custom.something"]]$variable_type, "Single_Response")
})


# ------------------------------------------------------------------------------
# Integration test: against the real IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("role map resolves cleanly against the IPK Wave 1 fixture", {
  ss_path <- file.path("..", "..", "tests", "fixtures",
                       "ipk_wave1", "Survey_Structure.xlsx")
  bc_path <- file.path("..", "..", "tests", "fixtures",
                       "ipk_wave1", "Brand_Config.xlsx")
  data_path <- file.path("..", "..", "tests", "fixtures",
                         "ipk_wave1", "ipk_wave1_data.xlsx")
  skip_if_not(all(file.exists(c(ss_path, bc_path, data_path))),
              "IPK Wave 1 fixture not built")

  # Load the structure pieces directly
  questions <- openxlsx::read.xlsx(ss_path, sheet = "Questions")
  brands    <- openxlsx::read.xlsx(ss_path, sheet = "Brands")
  cats      <- openxlsx::read.xlsx(bc_path, sheet = "Categories")
  data      <- openxlsx::read.xlsx(data_path)

  structure <- list(questions = questions, brands = brands,
                    questionmap = NULL)
  brand_config <- list(categories = cats)

  rm <- build_brand_role_map(structure, brand_config, data)

  # DSS funnel awareness — slot columns resolved
  e <- rm[["funnel.awareness.DSS"]]
  expect_false(is.null(e))
  expect_equal(e$column_root, "BRANDAWARE_DSS")
  expect_equal(length(e$columns), 16L)  # 15 brands + NONE
  expect_true(all(grepl("^BRANDAWARE_DSS_[0-9]+$", e$columns)))

  # CEP01 — same shape
  e <- rm[["mental_avail.cep.DSS.CEP01"]]
  expect_false(is.null(e))
  expect_equal(length(e$columns), 16L)

  # Per-category single
  e <- rm[["cat_buying.frequency.DSS"]]
  expect_false(is.null(e))
  expect_equal(e$columns, "CATBUY_DSS")

  # Sample-wide ad hoc absent — no NPS in fixture
  expect_false("adhoc.nps.ALL" %in% names(rm))
})
