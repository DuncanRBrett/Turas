# ==============================================================================
# BRAND MODULE TESTS — FUNNEL OUTPUT (Excel + CSV) — v2 port
# ==============================================================================
# Tests for write_funnel_excel() and write_funnel_csv() on the same
# 10-respondent transactional fixture used in test_funnel_transactional.R.
# Role map includes output-layer alias keys ("funnel.transactional.bought_long"
# etc.) so 03d_funnel_output.R's .role_map_lookup_for_stages() can find them.
# ==============================================================================
library(testthat)

.find_root <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root()

shared_lib <- file.path(ROOT, "modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(ROOT, "modules", "brand", "R", "03a_funnel_derive.R"))
source(file.path(ROOT, "modules", "brand", "R", "03b_funnel_metrics.R"))
source(file.path(ROOT, "modules", "brand", "R", "03_funnel.R"))
source(file.path(ROOT, "modules", "brand", "R", "03c_funnel_panel_data.R"))
source(file.path(ROOT, "modules", "brand", "R", "03e_funnel_legacy_adapter.R"))
source(file.path(ROOT, "modules", "brand", "R", "03d_funnel_output.R"))


# ==============================================================================
# Shared fixture
# ==============================================================================

.pack_mm <- function(picks, root) {
  n_slots <- max(vapply(picks, length, integer(1)), 1L)
  as.data.frame(
    setNames(
      lapply(seq_len(n_slots), function(j)
        vapply(picks, function(p)
          if (j <= length(p)) p[j] else NA_character_,
          character(1))),
      paste0(root, "_", seq_len(n_slots))),
    stringsAsFactors = FALSE)
}

.mm_entry <- function(role, cat, client, column_root, n_slots, qtext = "") {
  list(role = role, category = cat, client_code = client,
       variable_type = "Multi_Mention",
       column_root = column_root, per_brand = FALSE,
       columns = paste0(column_root, "_", seq_len(n_slots)),
       applicable_brands = NULL,
       question_text = qtext, option_scale = NA,
       option_map = NULL, notes = "")
}

.att_entry <- function(cat, brands) {
  colroot <- paste0("BRANDATT1_", cat)
  named_cols <- setNames(paste0(colroot, "_", brands), brands)
  list(role = "funnel.attitude", category = cat, client_code = "BRANDATT1",
       variable_type = "Single_Response_Brand",
       column_root = colroot, per_brand = TRUE,
       columns = named_cols,
       applicable_brands = brands,
       question_text = "Attitude?", option_scale = NA,
       option_map = NULL, notes = "")
}

.trans_data <- function() {
  aware <- list(
    c("IPK","ROB","CART"), c("IPK","ROB","CART"), c("IPK","CART"),
    c("IPK","ROB","CART"), c("ROB"),              c("IPK","ROB","CART"),
    c("IPK"),              c("IPK","ROB","CART"), c("IPK","ROB","CART"),
    c("IPK","ROB"))
  pen1 <- list(
    c("IPK","ROB"), c("IPK","ROB"), c("IPK","CART"), c("ROB","CART"),
    c("ROB"),       c("IPK","CART"), character(0),   c("IPK","CART"),
    c("ROB","CART"), c("IPK","ROB"))
  pen2 <- list(
    c("IPK","ROB"), c("IPK","ROB"), c("CART"),       c("ROB","CART"),
    character(0),   c("IPK"),       character(0),    c("IPK","CART"),
    c("CART"),      c("IPK","ROB"))
  data <- cbind(
    data.frame(Respondent_ID = 1:10, Weight = 1, stringsAsFactors = FALSE),
    .pack_mm(aware, "BRANDAWARE_TSX"),
    .pack_mm(pen1,  "BRANDPEN1_TSX"),
    .pack_mm(pen2,  "BRANDPEN2_TSX"))
  data$BRANDATT1_TSX_IPK  <- c(1, 2, 3, 4, 5, 1, 3, 2, 5, 1)
  data$BRANDATT1_TSX_ROB  <- c(3, 1, 5, 2, 3, 4, 5, 4, 2, 1)
  data$BRANDATT1_TSX_CART <- c(5, 4, 2, 1, 5, 3, 5, 2, 1, 5)
  data
}

.trans_brands <- function() {
  data.frame(BrandCode  = c("IPK","ROB","CART"),
             BrandLabel = c("IPK","Robertsons","Cartwright"),
             stringsAsFactors = FALSE)
}

.trans_rm <- function() {
  aw <- .mm_entry("funnel.awareness", "TSX", "BRANDAWARE",
                  "BRANDAWARE_TSX", 3, "Heard of?")
  at <- .att_entry("TSX", c("IPK","ROB","CART"))
  pl <- .mm_entry("funnel.penetration_long", "TSX", "BRANDPEN1",
                  "BRANDPEN1_TSX", 2, "Bought in 12m?")
  pt <- .mm_entry("funnel.penetration_target", "TSX", "BRANDPEN2",
                  "BRANDPEN2_TSX", 2, "Bought last month?")
  list(
    "funnel.awareness"                   = aw,
    "funnel.attitude"                    = at,
    "funnel.penetration_long"            = pl,
    "funnel.penetration_target"          = pt,
    "funnel.transactional.bought_long"   = pl,
    "funnel.transactional.bought_target" = pt
  )
}

.run_fixture <- function() {
  rm <- .trans_rm()
  list(
    result   = run_funnel(.trans_data(), rm, .trans_brands(), list(
      `category.type` = "transactional", focal_brand = "IPK",
      `funnel.conversion_metric` = "ratio",
      `funnel.warn_base` = 0, `funnel.suppress_base` = 0,
      `funnel.significance_level` = 0.05)),
    role_map = rm
  )
}


# ==============================================================================
# Excel tests
# ==============================================================================

test_that("write_funnel_excel creates a 4-sheet workbook", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_excel(bundle$result, .trans_brands(), bundle$role_map, tmp,
                     config = list(`funnel.conversion_metric` = "ratio"))
  expect_true(file.exists(tmp))
  sheets <- openxlsx::getSheetNames(tmp)
  expect_setequal(sheets, c("Stage_Matrix", "Conversions",
                            "Attitude_Decomposition", "Metadata"))
})


test_that("Stage_Matrix sheet carries ClientCode and QuestionText header rows", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_excel(bundle$result, .trans_brands(), bundle$role_map, tmp)
  sm <- openxlsx::read.xlsx(tmp, sheet = "Stage_Matrix", colNames = FALSE)
  # Row 1: label "ClientCode" + blank + client codes per stage
  expect_equal(sm[1, 1], "ClientCode")
  expect_true("BRANDAWARE" %in% as.character(unlist(sm[1, ])))
  # Row 2: "QuestionText"
  expect_equal(sm[2, 1], "QuestionText")
  expect_true(any(grepl("Heard", as.character(unlist(sm[2, ])))))
})


test_that("Stage_Matrix body values match hand-calculated percentages", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_excel(bundle$result, .trans_brands(), bundle$role_map, tmp)
  sm <- openxlsx::read.xlsx(tmp, sheet = "Stage_Matrix", colNames = FALSE)
  # Find IPK row (after 3 header rows)
  ipk_row <- which(as.character(unlist(sm[, 1])) == "IPK")
  expect_length(ipk_row, 1L)
  aware_pct <- as.numeric(sm[ipk_row, 3])  # col1=code, col2=label, col3=stage1
  expect_equal(aware_pct, 90, tolerance = 0.01)  # 9/10 = 90%
})


test_that("Attitude_Decomposition sheet covers all 5 positions per brand", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_excel(bundle$result, .trans_brands(), bundle$role_map, tmp)
  att <- openxlsx::read.xlsx(tmp, sheet = "Attitude_Decomposition")
  expect_true(all(c("Love", "Prefer", "Ambivalent", "Reject",
                    "No.Opinion", "Aware_Base_Unweighted") %in% names(att)))
  expect_equal(nrow(att), 3L)  # 3 brands
  # IPK Love = 3/10 = 30%
  ipk_row <- att[att$BrandCode == "IPK", ]
  expect_equal(ipk_row$Love, 30, tolerance = 0.01)
})


test_that("Metadata sheet records category_type, focal, and n counts", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_excel(bundle$result, .trans_brands(), bundle$role_map, tmp)
  md <- openxlsx::read.xlsx(tmp, sheet = "Metadata")
  md_lookup <- stats::setNames(md$Value, md$Key)
  expect_equal(md_lookup[["category_type"]], "transactional")
  expect_equal(md_lookup[["focal_brand"]],   "IPK")
  expect_equal(md_lookup[["n_unweighted"]],  "10")
})


# ==============================================================================
# CSV tests
# ==============================================================================

test_that("write_funnel_csv produces one row per brand x stage", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_csv(bundle$result, .trans_brands(), bundle$role_map, tmp,
                   list(category_code = "FMCG_TEST", wave_label = "W1"))
  df <- utils::read.csv(tmp, stringsAsFactors = FALSE)
  expect_equal(nrow(df), 12L)  # 4 stages x 3 brands
  expect_setequal(unique(df$brand_code), c("IPK","ROB","CART"))
})


test_that("CSV carries ClientCode and QuestionText on every row", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_csv(bundle$result, .trans_brands(), bundle$role_map, tmp,
                   list(category_code = "FMCG_TEST"))
  df <- utils::read.csv(tmp, stringsAsFactors = FALSE)
  expect_true("client_code"   %in% names(df))
  expect_true("question_text" %in% names(df))
  aware_rows <- df[df$stage_key == "aware", ]
  expect_true(all(aware_rows$client_code == "BRANDAWARE"))
  expect_true(all(grepl("Heard", aware_rows$question_text)))
})


test_that("CSV pct values round-trip at full precision", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_csv(bundle$result, .trans_brands(), bundle$role_map, tmp,
                   list(category_code = "FMCG_TEST"))
  df <- utils::read.csv(tmp, stringsAsFactors = FALSE)
  ipk_aware <- df[df$brand_code == "IPK" & df$stage_key == "aware", ]
  expect_equal(ipk_aware$pct_weighted, 0.9, tolerance = 1e-9)
})


test_that("CSV includes wave_label and category_code metadata columns", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_csv(bundle$result, .trans_brands(), bundle$role_map, tmp,
                   list(category_code = "FMCG_TEST", wave_label = "W1"))
  df <- utils::read.csv(tmp, stringsAsFactors = FALSE)
  expect_true(all(df$category_code == "FMCG_TEST"))
  expect_true(all(df$wave_label == "W1"))
})


# ==============================================================================
# Refusal tests
# ==============================================================================

test_that("write_funnel_excel refuses on a REFUSED result", {
  tmp <- tempfile(fileext = ".xlsx")
  res <- brand_with_refusal_handler(
    write_funnel_excel(list(status = "REFUSED"),
                       .trans_brands(), NULL, tmp)
  )
  expect_true(res$refused)
  expect_equal(res$code, "DATA_FUNNEL_EMPTY")
})


test_that("write_funnel_csv refuses on a REFUSED result", {
  tmp <- tempfile(fileext = ".csv")
  res <- brand_with_refusal_handler(
    write_funnel_csv(list(status = "REFUSED"),
                     .trans_brands(), NULL, tmp)
  )
  expect_true(res$refused)
  expect_equal(res$code, "DATA_FUNNEL_EMPTY")
})
