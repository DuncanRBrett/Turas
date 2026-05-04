# ==============================================================================
# BRAND MODULE TESTS — PANEL BUILDER SMOKE TESTS
# ==============================================================================
# Verifies that each panel HTML builder function:
#   1. Handles NULL / empty / REFUSED inputs gracefully (returns empty-state HTML
#      string, not an error).
#   2. Produces valid non-empty HTML for minimal valid inputs.
#
# These are structural smoke tests. Detailed behaviour is covered by:
#   test_funnel_panel_table.R  — funnel table chrome + heatmap
#   test_cat_buying_panel.R    — cat-buying panel data contract
#   test_shopper_panel.R       — shopper / location sub-tabs
# ==============================================================================

library(testthat)

.find_root_smoke <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_smoke()

# --- shared helpers + guard ---
shared_lib <- file.path(ROOT, "modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))

# --- analytics R files (pipeline-based happy-path helpers) ---
for (f in c("00_data_access.R", "00_role_inference.R", "00_role_map.R",
            "02_mental_availability.R", "02b_mental_advantage.R",
            "02a_ma_panel_data.R",
            "03a_funnel_derive.R", "03b_funnel_metrics.R", "03_funnel.R",
            "03c_funnel_panel_data.R", "03e_funnel_legacy_adapter.R",
            "05_wom.R", "05a_wom_panel_data.R",
            "13b_al_metrics.R")) {
  fp <- file.path(ROOT, "modules", "brand", "R", f)
  if (file.exists(fp)) tryCatch(source(fp, local = FALSE), error = function(e) NULL)
}

# callout no-op so panel renderers do not crash when registry is absent
if (!exists("turas_callout", mode = "function")) {
  turas_callout <- function(module, key, ...) ""
}

# --- source all panel HTML renderers ---
panels_dir <- file.path(ROOT, "modules", "brand", "lib", "html_report", "panels")
for (f in sort(list.files(panels_dir, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}


# ==============================================================================
# SECTION A: NULL / EMPTY GUARD PATHS
# Every panel builder must return a non-NULL character string when given
# NULL or an empty / REFUSED payload — never throw, never return NULL.
# ==============================================================================

test_that("build_funnel_panel_html: NULL → graceful empty-state character", {
  html <- build_funnel_panel_html(NULL)
  expect_true(is.character(html) && nzchar(html))
  expect_true(grepl("fn-panel-empty", html))
})

test_that("build_ma_panel_html: NULL → graceful empty-state character", {
  html <- build_ma_panel_html(NULL)
  expect_true(is.character(html) && nzchar(html))
  expect_true(grepl("ma-panel-empty", html))
})

test_that("build_wom_panel_html: NULL → graceful empty-state character", {
  html <- build_wom_panel_html(NULL)
  expect_true(is.character(html) && nzchar(html))
  expect_true(grepl("wom-panel-empty", html))
})

test_that("build_branded_reach_panel_html: REFUSED panel_data → empty-state character", {
  pd <- list(meta = list(status = "REFUSED", message = "No data"),
             ads = list(), misattribution = list(), media_mix = list())
  html <- build_branded_reach_panel_html(pd, category_code = "TST")
  expect_true(is.character(html) && nzchar(html))
  expect_true(grepl("br-reach-empty", html))
})

test_that("build_adhoc_panel_html: NULL → graceful empty-state character", {
  html <- build_adhoc_panel_html(NULL)
  expect_true(is.character(html) && nzchar(html))
  expect_true(grepl("adhoc-panel-empty", html))
})

test_that("build_adhoc_panel_html: empty scopes → graceful empty-state character", {
  pd <- list(meta = list(status = "EMPTY",
                          message = "No ad hoc questions configured."),
             scopes = list())
  html <- build_adhoc_panel_html(pd)
  expect_true(is.character(html) && nzchar(html))
  expect_true(grepl("adhoc-panel-empty", html))
})

test_that("build_audience_lens_panel_html: NULL → graceful empty-state character", {
  html <- build_audience_lens_panel_html(NULL, category_code = "TST")
  expect_true(is.character(html) && nzchar(html))
  expect_true(grepl("al-panel-empty", html))
})

test_that("build_audience_lens_panel_html: empty cards → graceful empty-state character", {
  pd <- list(meta = list(status = "PASS"), cards = list(),
             banner_groups = list(), total = list())
  html <- build_audience_lens_panel_html(pd, category_code = "TST")
  expect_true(is.character(html) && nzchar(html))
  expect_true(grepl("al-panel-empty", html))
})

test_that("build_br_portfolio_panel: REFUSED portfolio → graceful empty-state character", {
  results <- list(
    status = "PASS",
    config = list(focal_brand = "IPK", colour_focal = "#1A5276"),
    structure = NULL,
    results = list(portfolio = list(status = "REFUSED",
                                     message = "No portfolio data"))
  )
  html <- build_br_portfolio_panel(results, list(focal_brand = "IPK",
                                                   colour_focal = "#1A5276"))
  expect_true(is.character(html) && nzchar(html))
})

test_that("build_brand_summary_panel: empty categories → graceful empty-state character", {
  results <- list(status = "PASS", config = list(),
                  results = list(categories = list()))
  html <- build_brand_summary_panel(results, list(focal_brand = "IPK",
                                                    colour_focal = "#1A5276"))
  expect_true(is.character(html) && nzchar(html))
})

test_that("build_brand_summary_panel: all REFUSED categories → graceful empty-state character", {
  results <- list(
    status = "PASS",
    config = list(focal_brand = "IPK"),
    results = list(categories = list(
      "DSS" = list(
        category = "DSS",
        funnel = list(status = "REFUSED"),
        mental_availability = list(status = "REFUSED")
      )
    ))
  )
  html <- build_brand_summary_panel(results, list(focal_brand = "IPK",
                                                    colour_focal = "#1A5276"))
  expect_true(is.character(html) && nzchar(html))
})


# ==============================================================================
# SECTION B: HAPPY-PATH SMOKE TESTS
# Verify the panel produces non-empty HTML with key structural markers.
# ==============================================================================

# --- Funnel panel helpers (minimal transactional dataset, 10 respondents) ---

.sp_pack_mm <- function(picks, root) {
  n_slots <- max(vapply(picks, length, integer(1)), 1L)
  as.data.frame(
    setNames(
      lapply(seq_len(n_slots), function(j)
        vapply(picks, function(p)
          if (j <= length(p)) p[j] else NA_character_, character(1))),
      paste0(root, "_", seq_len(n_slots))),
    stringsAsFactors = FALSE)
}

.sp_mm_entry <- function(role, cat, client, column_root, n_slots) {
  list(role = role, category = cat, client_code = client,
       variable_type = "Multi_Mention",
       column_root = column_root, per_brand = FALSE,
       columns = paste0(column_root, "_", seq_len(n_slots)),
       applicable_brands = NULL, question_text = "",
       option_scale = NA, option_map = NULL, notes = "")
}

.sp_att_entry <- function(cat, brands) {
  colroot <- paste0("BRANDATT1_", cat)
  list(role = "funnel.attitude", category = cat, client_code = "BRANDATT1",
       variable_type = "Single_Response_Brand",
       column_root = colroot, per_brand = TRUE,
       columns = setNames(paste0(colroot, "_", brands), brands),
       applicable_brands = brands,
       question_text = "", option_scale = NA,
       option_map = NULL, notes = "")
}

.sp_trans_data <- function() {
  aware <- list(c("IPK","ROB"), c("IPK","ROB"), c("IPK"), c("ROB"), c("IPK","ROB"),
                c("IPK"), c("ROB"), c("IPK","ROB"), c("IPK"), c("ROB"))
  pen   <- list(c("IPK"), c("IPK","ROB"), c("IPK"), character(0), c("ROB"),
                c("IPK"), character(0), c("IPK","ROB"), c("IPK"), c("ROB"))
  data  <- cbind(
    data.frame(Respondent_ID = 1:10, Weight = 1, stringsAsFactors = FALSE),
    .sp_pack_mm(aware, "BRANDAWARE_TSX"),
    .sp_pack_mm(pen,   "BRANDPEN1_TSX"))
  data$BRANDPEN2_TSX_1 <- c("IPK", NA, NA, NA, NA, "IPK", NA, NA, "IPK", NA)
  data$BRANDATT1_TSX_IPK <- c(2L, 3L, 4L, 1L, 1L, 3L, 2L, 4L, 5L, 1L)
  data$BRANDATT1_TSX_ROB <- c(1L, 2L, 1L, 4L, 3L, 1L, 4L, 2L, 1L, 3L)
  data
}

.sp_trans_brands <- function() {
  data.frame(BrandCode = c("IPK", "ROB"), BrandLabel = c("IPK", "Robertsons"),
             stringsAsFactors = FALSE)
}

.sp_trans_rm <- function() {
  aw <- .sp_mm_entry("funnel.awareness",          "TSX", "BRANDAWARE", "BRANDAWARE_TSX", 2)
  at <- .sp_att_entry("TSX", c("IPK", "ROB"))
  pl <- .sp_mm_entry("funnel.penetration_long",   "TSX", "BRANDPEN1",  "BRANDPEN1_TSX",  2)
  pt <- list(role = "funnel.penetration_target", category = "TSX",
             client_code = "BRANDPEN2",
             variable_type = "Multi_Mention",
             column_root = "BRANDPEN2_TSX", per_brand = FALSE,
             columns = "BRANDPEN2_TSX_1",
             applicable_brands = NULL, question_text = "",
             option_scale = NA, option_map = NULL, notes = "")
  list(
    "funnel.awareness"                   = aw,
    "funnel.attitude"                    = at,
    "funnel.penetration_long"            = pl,
    "funnel.penetration_target"          = pt,
    "funnel.transactional.bought_long"   = pl,
    "funnel.transactional.bought_target" = pt
  )
}

test_that("build_funnel_panel_html: valid panel data → non-empty HTML", {
  res <- run_funnel(.sp_trans_data(), .sp_trans_rm(), .sp_trans_brands(), list(
    `category.type` = "transactional", focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0, `funnel.suppress_base` = 0))
  pd <- build_funnel_panel_data(res, .sp_trans_brands(), list())
  html <- build_funnel_panel_html(pd, category_code = "TSX",
                                  focal_colour = "#1A5276")
  expect_true(is.character(html) && nchar(html) > 500)
  expect_true(grepl('class="fn-panel"', html))
  expect_true(grepl("fn-panel-data", html))
})


# --- WOM panel: directly constructed wom_result (bypasses pipeline) ---

.sp_wom_brands <- function() {
  data.frame(BrandCode = c("IPK", "ROB"),
             BrandLabel = c("IPK", "Robertsons"),
             stringsAsFactors = FALSE)
}

.sp_wom_result <- function() {
  list(
    status = "PASS",
    wom_metrics = data.frame(
      BrandCode          = c("IPK", "ROB"),
      ReceivedPos_Pct    = c(60,  40),
      ReceivedNeg_Pct    = c(10,  15),
      SharedPos_Pct      = c(20,  15),
      SharedNeg_Pct      = c(5,    8),
      SharedPosFreq_Mean = c(2.5,  2.0),
      SharedNegFreq_Mean = c(1.5,  1.2),
      stringsAsFactors   = FALSE
    ),
    net_balance = data.frame(
      BrandCode    = c("IPK", "ROB"),
      Net_Received = c(50, 25),
      Net_Shared   = c(15,  7),
      stringsAsFactors = FALSE
    ),
    n_respondents   = 100,
    n_brands        = 2,
    metrics_summary = list(focal_brand = "IPK")
  )
}

test_that("build_wom_panel_html: valid wom_result → non-empty HTML", {
  pd <- build_wom_panel_data(.sp_wom_result(), .sp_wom_brands(),
                              list(focal_brand_code = "IPK",
                                   category_label = "Dry Seasonings"))
  skip_if(is.null(pd), "build_wom_panel_data returned NULL")

  html <- build_wom_panel_html(pd, category_code = "DSS",
                                focal_colour = "#1A5276")
  expect_true(is.character(html) && nchar(html) > 500)
  expect_true(grepl('class="wom-panel"', html))
  expect_true(grepl("wom-panel-data", html))
})


# --- MA panel: directly constructed linkage object (20 respondents, 2 brands, 3 CEPs) ---

.sp_ma_linkage <- function() {
  n     <- 20L
  codes <- c("C1", "C2", "C3")
  set.seed(99)
  ipk <- matrix(rbinom(n * 3L, 1L, 0.6), nrow = n,
                dimnames = list(NULL, codes))
  rob <- matrix(rbinom(n * 3L, 1L, 0.4), nrow = n,
                dimnames = list(NULL, codes))
  list(
    linkage_tensor       = list(IPK = ipk, ROB = rob),
    brand_codes          = c("IPK", "ROB"),
    cep_codes            = codes,
    n_respondents        = n,
    respondent_cep_matrix = pmax(ipk, rob)
  )
}

.sp_ma_brand_list <- function() {
  data.frame(BrandCode = c("IPK", "ROB"),
             BrandLabel = c("IPK", "Robertsons"),
             stringsAsFactors = FALSE)
}

.sp_ma_cep_list <- function() {
  data.frame(CEPCode = c("C1", "C2", "C3"),
             CEPText = c("CEP One", "CEP Two", "CEP Three"),
             stringsAsFactors = FALSE)
}

test_that("build_ma_panel_html: valid MA result → non-empty HTML", {
  ma_res <- run_mental_availability(.sp_ma_linkage(),
                                     focal_brand = "IPK")
  skip_if(is.null(ma_res) || identical(ma_res$status, "REFUSED"),
          "run_mental_availability returned REFUSED — skip MA smoke test")

  pd <- build_ma_panel_data(ma_res, .sp_ma_brand_list(), .sp_ma_cep_list(),
                             attribute_list = NULL,
                             config = list(focal_brand_code = "IPK",
                                           focal_colour = "#1A5276",
                                           category_label = "Test Category"))
  html <- build_ma_panel_html(pd, category_code = "TST",
                               focal_colour = "#1A5276")
  expect_true(is.character(html) && nchar(html) > 200)
  expect_true(grepl('class="ma-panel"', html) ||
              grepl("ma-panel-empty", html))
})


# ==============================================================================
# SECTION C: STRUCTURAL ASSERTIONS — panel wrappers + JSON data containers
# Only for the pipeline-driven panels above (null guard already tested in A).
# ==============================================================================

test_that("build_funnel_panel_html includes JSON data container", {
  res <- run_funnel(.sp_trans_data(), .sp_trans_rm(), .sp_trans_brands(), list(
    `category.type` = "transactional", focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0, `funnel.suppress_base` = 0))
  pd <- build_funnel_panel_data(res, .sp_trans_brands(), list())
  html <- build_funnel_panel_html(pd, category_code = "TSX")
  expect_true(grepl('class="fn-panel-data"', html))
  expect_true(grepl('data-fn-subtab', html))
})

test_that("build_funnel_panel_html encodes focal_colour in panel div", {
  res <- run_funnel(.sp_trans_data(), .sp_trans_rm(), .sp_trans_brands(), list(
    `category.type` = "transactional", focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0, `funnel.suppress_base` = 0))
  pd <- build_funnel_panel_data(res, .sp_trans_brands(), list())
  html <- build_funnel_panel_html(pd, focal_colour = "#2E4057")
  expect_true(grepl("#2E4057", html, fixed = TRUE))
})
