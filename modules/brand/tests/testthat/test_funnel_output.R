# ==============================================================================
# BRAND MODULE TESTS - FUNNEL OUTPUT (Excel + CSV per FUNNEL_SPEC §7)
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
for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard_role_map.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03a_funnel_derive.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03b_funnel_metrics.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03_funnel.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03c_funnel_panel_data.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03e_funnel_legacy_adapter.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03d_funnel_output.R"))


# --- Fixture -----------------------------------------------------------------

.brand_list_ircc <- function() {
  data.frame(BrandCode = c("IPK", "ROB", "CART"),
             BrandLabel = c("IPK", "Robertsons", "Cartwright"),
             stringsAsFactors = FALSE)
}

.optionmap_attitude <- function() {
  data.frame(Scale = rep("attitude_scale", 5),
             ClientCode = as.character(1:5),
             Role = c("attitude.love","attitude.prefer",
                      "attitude.ambivalent","attitude.reject",
                      "attitude.no_opinion"),
             ClientLabel = c("L","P","A","R","N"),
             OrderIndex = 1:5, stringsAsFactors = FALSE)
}

.questionmap_transactional <- function() {
  data.frame(
    Role = c("funnel.awareness","funnel.attitude",
             "funnel.transactional.bought_long",
             "funnel.transactional.bought_target",
             "funnel.transactional.frequency",
             "system.respondent.id","system.respondent.weight"),
    ClientCode = c("BRANDAWARE","QBRANDATT1",
                   "BRANDPENTRANS1","BRANDPENTRANS2","BRANDPENTRANS3",
                   "Respondent_ID","Weight"),
    QuestionText = c("Heard of?", "Attitude", "Bought in 12m?",
                     "Bought in last month?", "How often?", "ID", "Weight"),
    QuestionTextShort = NA_character_,
    Variable_Type = c("Multi_Mention","Single_Response",
                      "Multi_Mention","Multi_Mention","Numeric",
                      "Single_Response","Numeric"),
    ColumnPattern = c("{code}_{brand_code}","{code}_{brand_code}",
                      "{code}_{brand_code}","{code}_{brand_code}",
                      "{code}_{brand_code}","{code}","{code}"),
    OptionMapScale = c("","attitude_scale","","","","",""),
    Notes = NA_character_, stringsAsFactors = FALSE)
}

.structure_transactional <- function() {
  list(questionmap = .questionmap_transactional(),
       optionmap = .optionmap_attitude(),
       brands = .brand_list_ircc(),
       ceps = data.frame(), dba_assets = data.frame())
}

.run_fixture <- function() {
  data <- read.csv(
    file.path(TURAS_ROOT, "modules", "brand", "tests", "fixtures",
              "funnel_transactional_10resp.csv"),
    stringsAsFactors = FALSE)
  rm <- load_role_map(.structure_transactional())
  list(result = run_funnel(data, rm, .brand_list_ircc(), list(
    `category.type` = "transactional", focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0, `funnel.suppress_base` = 0,
    `funnel.significance_level` = 0.05)),
       role_map = rm)
}


# --- Excel tests -------------------------------------------------------------

test_that("write_funnel_excel creates a 4-sheet workbook", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_excel(bundle$result, .brand_list_ircc(),
                     bundle$role_map, tmp,
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

  write_funnel_excel(bundle$result, .brand_list_ircc(),
                     bundle$role_map, tmp)
  sm <- openxlsx::read.xlsx(tmp, sheet = "Stage_Matrix", colNames = FALSE)
  # Row 1: label "ClientCode" + blank + client codes
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

  write_funnel_excel(bundle$result, .brand_list_ircc(),
                     bundle$role_map, tmp)
  sm <- openxlsx::read.xlsx(tmp, sheet = "Stage_Matrix", colNames = FALSE)
  # Find IPK row — somewhere after the 3 header rows
  ipk_row <- which(as.character(unlist(sm[, 1])) == "IPK")
  expect_length(ipk_row, 1)
  aware_pct <- as.numeric(sm[ipk_row, 3])  # col1=code, col2=label, col3=stage1
  expect_equal(aware_pct, 90, tolerance = 0.01)  # 90% from hand calc
})


test_that("Attitude_Decomposition sheet covers all 5 positions per brand", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_excel(bundle$result, .brand_list_ircc(),
                     bundle$role_map, tmp)
  att <- openxlsx::read.xlsx(tmp, sheet = "Attitude_Decomposition")
  expect_true(all(c("Love", "Prefer", "Ambivalent", "Reject",
                    "No.Opinion", "Aware_Base_Unweighted")
                  %in% names(att)))
  expect_equal(nrow(att), 3)  # 3 brands
  # IPK Love = 3/9 ≈ 33.33%
  ipk_row <- att[att$BrandCode == "IPK", ]
  expect_equal(ipk_row$Love, 33.33, tolerance = 0.01)
})


test_that("Metadata sheet records category_type, focal, and n counts", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_excel(bundle$result, .brand_list_ircc(),
                     bundle$role_map, tmp)
  md <- openxlsx::read.xlsx(tmp, sheet = "Metadata")
  md_lookup <- stats::setNames(md$Value, md$Key)
  expect_equal(md_lookup[["category_type"]], "transactional")
  expect_equal(md_lookup[["focal_brand"]], "IPK")
  expect_equal(md_lookup[["n_unweighted"]], "10")
})


# --- CSV tests ---------------------------------------------------------------

test_that("write_funnel_csv produces one row per brand x stage", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_csv(bundle$result, .brand_list_ircc(), bundle$role_map,
                   tmp, list(category_code = "FMCG_TEST", wave_label = "W1"))
  df <- utils::read.csv(tmp, stringsAsFactors = FALSE)
  expect_equal(nrow(df), 15)  # 5 stages x 3 brands
  expect_setequal(unique(df$brand_code), c("IPK", "ROB", "CART"))
})


test_that("CSV carries ClientCode and QuestionText on every row", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_csv(bundle$result, .brand_list_ircc(), bundle$role_map, tmp,
                   list(category_code = "FMCG_TEST"))
  df <- utils::read.csv(tmp, stringsAsFactors = FALSE)
  expect_true("client_code" %in% names(df))
  expect_true("question_text" %in% names(df))
  aware_rows <- df[df$stage_key == "aware", ]
  expect_true(all(aware_rows$client_code == "BRANDAWARE"))
  expect_true(all(grepl("Heard", aware_rows$question_text)))
})


test_that("CSV pct values round-trip at full precision", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_csv(bundle$result, .brand_list_ircc(), bundle$role_map, tmp,
                   list(category_code = "FMCG_TEST"))
  df <- utils::read.csv(tmp, stringsAsFactors = FALSE)
  ipk_aware <- df[df$brand_code == "IPK" & df$stage_key == "aware", ]
  expect_equal(ipk_aware$pct_weighted, 0.9, tolerance = 1e-9)
})


test_that("CSV includes wave_label and category_code metadata columns", {
  bundle <- .run_fixture()
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  write_funnel_csv(bundle$result, .brand_list_ircc(), bundle$role_map, tmp,
                   list(category_code = "FMCG_TEST", wave_label = "W1"))
  df <- utils::read.csv(tmp, stringsAsFactors = FALSE)
  expect_true(all(df$category_code == "FMCG_TEST"))
  expect_true(all(df$wave_label == "W1"))
})


# --- Refusal tests -----------------------------------------------------------

test_that("write_funnel_excel refuses on a REFUSED result", {
  tmp <- tempfile(fileext = ".xlsx")
  res <- brand_with_refusal_handler(
    write_funnel_excel(list(status = "REFUSED"),
                       .brand_list_ircc(), NULL, tmp)
  )
  expect_true(res$refused)
  expect_equal(res$code, "DATA_FUNNEL_EMPTY")
})


test_that("write_funnel_csv refuses on a REFUSED result", {
  tmp <- tempfile(fileext = ".csv")
  res <- brand_with_refusal_handler(
    write_funnel_csv(list(status = "REFUSED"),
                     .brand_list_ircc(), NULL, tmp)
  )
  expect_true(res$refused)
  expect_equal(res$code, "DATA_FUNNEL_EMPTY")
})
