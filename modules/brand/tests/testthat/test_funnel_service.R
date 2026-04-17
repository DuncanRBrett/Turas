# ==============================================================================
# BRAND MODULE TESTS - FUNNEL (SERVICE CATEGORY TYPE)
# ==============================================================================
# Known-answer tests against fixtures/funnel_service_10resp.csv. The service
# fixture mirrors the durable fixture row-for-row (same data shape) but
# swaps OWNER+TENURE for CUSTOMER+TENURE+PRIOR. Prior-brand is declared as
# a role but MUST NOT render as a funnel stage (FUNNEL_SPEC §3.3).
#
# Stage counts match durable exactly; see test_funnel_durable.R for the
# derivation tables.
# ==============================================================================

.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) {
      return(dir)
    }
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


# --- Fixtures ----------------------------------------------------------------

.fixture_service <- function() {
  fp <- file.path(TURAS_ROOT, "modules", "brand", "tests", "fixtures",
                  "funnel_service_10resp.csv")
  read.csv(fp, stringsAsFactors = FALSE)
}

.brand_list_ircc <- function() {
  data.frame(BrandCode = c("IPK", "ROB", "CART"),
             BrandLabel = c("IPK", "Robertsons", "Cartwright"),
             stringsAsFactors = FALSE)
}

.optionmap_attitude <- function() {
  data.frame(Scale = rep("attitude_scale", 5),
             ClientCode = as.character(1:5),
             Role = c("attitude.love", "attitude.prefer",
                      "attitude.ambivalent", "attitude.reject",
                      "attitude.no_opinion"),
             ClientLabel = c("Love", "Prefer", "Ambivalent", "Reject", "No opinion"),
             OrderIndex = 1:5,
             stringsAsFactors = FALSE)
}

.questionmap_service <- function() {
  data.frame(
    Role = c("funnel.awareness", "funnel.attitude",
             "funnel.service.current_customer", "funnel.service.tenure",
             "funnel.service.prior_brand",
             "system.respondent.id", "system.respondent.weight"),
    ClientCode = c("BRANDAWARE", "QBRANDATT1",
                   "BRANDPENSERV1", "BRANDPENSERV2", "BRANDPENSERV3",
                   "Respondent_ID", "Weight"),
    QuestionText = c("Aware?", "Attitude?", "Current customer?",
                     "Tenure?", "Prior brand?", "ID", "Weight"),
    QuestionTextShort = NA_character_,
    Variable_Type = c("Multi_Mention", "Single_Response",
                      "Single_Response", "Single_Response",
                      "Single_Response",
                      "Single_Response", "Numeric"),
    ColumnPattern = c("{code}_{brand_code}", "{code}_{brand_code}",
                      "{code}", "{code}", "{code}",
                      "{code}", "{code}"),
    OptionMapScale = c("", "attitude_scale", "", "", "", "", ""),
    Notes = NA_character_,
    stringsAsFactors = FALSE
  )
}

.structure_service <- function() {
  list(questionmap = .questionmap_service(),
       optionmap = .optionmap_attitude(),
       brands = .brand_list_ircc(),
       ceps = data.frame(), dba_assets = data.frame())
}

.config_service <- function(tenure_threshold = 3) {
  list(
    `category.type` = "service",
    focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0,
    `funnel.suppress_base` = 0,
    `funnel.significance_level` = 0.05,
    `funnel.tenure_threshold` = tenure_threshold
  )
}

.pct_for <- function(df, stage_key, brand_code) {
  row <- df[df$stage_key == stage_key & df$brand_code == brand_code, ,
            drop = FALSE]
  if (nrow(row) == 0) return(NA_real_)
  row$pct_weighted
}


# --- Expected values ---------------------------------------------------------

.expected_pct <- list(
  aware               = c(IPK = 0.9, ROB = 0.8, CART = 0.7),
  consideration       = c(IPK = 0.7, ROB = 0.6, CART = 0.5),
  current_customer_s  = c(IPK = 0.4, ROB = 0.2, CART = 0.2),
  long_tenured_s      = c(IPK = 0.3, ROB = 0.0, CART = 0.1)
)


# --- Tests -------------------------------------------------------------------

test_that("Stage count is 4 and prior_brand is NOT a stage", {
  data <- .fixture_service()
  rm <- load_role_map(.structure_service())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_service())

  expect_equal(res$meta$stage_count, 4)
  expect_false("prior_brand" %in% res$meta$stage_keys)
  expect_false("funnel.service.prior_brand" %in% res$meta$stage_keys)
  expect_setequal(res$meta$stage_keys,
    c("aware", "consideration", "current_customer_s", "long_tenured_s"))
})


test_that("All four service stages match hand-calculated expectations", {
  data <- .fixture_service()
  rm <- load_role_map(.structure_service())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_service())

  for (stage in names(.expected_pct)) {
    for (b in names(.expected_pct[[stage]])) {
      expect_equal(.pct_for(res$stages, stage, b),
                   .expected_pct[[stage]][[b]], tolerance = 1e-9,
                   info = sprintf("%s %s", stage, b))
    }
  }
})


test_that("prior_brand role is visible in the role map but not rendered", {
  # The loader sees the role; the derivation simply doesn't consume it.
  rm <- load_role_map(.structure_service())
  expect_true("funnel.service.prior_brand" %in% names(rm))

  # Derivation output should not reference prior_brand as a stage key.
  data <- .fixture_service()
  derived <- derive_funnel_stages(
    data, rm, category_type = "service",
    brand_list = .brand_list_ircc(), tenure_threshold = 3)
  expect_false("prior_brand" %in% names(derived$stages))
})


test_that("Service run_funnel status is PASS when all roles present", {
  data <- .fixture_service()
  rm <- load_role_map(.structure_service())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_service())
  expect_equal(res$status, "PASS")
})
