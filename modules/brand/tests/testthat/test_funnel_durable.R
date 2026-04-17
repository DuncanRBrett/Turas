# ==============================================================================
# BRAND MODULE TESTS - FUNNEL (DURABLE CATEGORY TYPE)
# ==============================================================================
# Known-answer tests against fixtures/funnel_durable_10resp.csv.
# tenure_threshold = 3 (≥ 3 counts as long-tenured).
#
# Derivation (all weights = 1):
#
# Row   AW_I AW_R AW_C   ATT   OWNER  TENURE
#   1     1    1    1   1/3/5  IPK       3
#   2     1    1    1   2/1/4  ROB       2
#   3     1    0    1   3/5/2  CART      4
#   4     1    1    1   4/2/1  ROB       1
#   5     0    1    0   5/3/5  (none)   NA
#   6     1    1    1   1/4/3  IPK       2
#   7     1    0    0   3/5/5  (none)   NA
#   8     1    1    1   2/4/2  IPK       3
#   9     1    1    1   5/2/1  CART      1
#  10     1    1    0   1/1/5  IPK       3
#
# Stage counts:
#   Aware         IPK=9 ROB=8 CART=7                          (pct 90/80/70)
#   Consideration IPK=7 ROB=6 CART=5                          (pct 70/60/50)
#   Current owner IPK=4 ROB=2 CART=2
#     IPK: R1,R6,R8,R10 (all in consideration; owner = IPK)   (40%)
#     ROB: R2,R4                                              (20%)
#     CART: R3,R9                                             (20%)
#   Long-tenured  IPK=3 ROB=0 CART=1
#     IPK tenures for owners: R1=3, R6=2, R8=3, R10=3
#       → owners with ten ≥ 3: R1, R8, R10                     (30%)
#     ROB tenures for owners: R2=2, R4=1                      (0%)
#     CART tenures for owners: R3=4, R9=1 → only R3            (10%)
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


# --- Fixture builders --------------------------------------------------------

.fixture_durable <- function() {
  fp <- file.path(TURAS_ROOT, "modules", "brand", "tests", "fixtures",
                  "funnel_durable_10resp.csv")
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

.questionmap_durable <- function() {
  data.frame(
    Role = c("funnel.awareness", "funnel.attitude",
             "funnel.durable.current_owner", "funnel.durable.tenure",
             "system.respondent.id", "system.respondent.weight"),
    ClientCode = c("BRANDAWARE", "QBRANDATT1",
                   "BRANDPENDUR1", "BRANDPENDUR2",
                   "Respondent_ID", "Weight"),
    QuestionText = c("Aware?", "Attitude?", "Current owner?",
                     "Tenure?", "ID", "Weight"),
    QuestionTextShort = NA_character_,
    Variable_Type = c("Multi_Mention", "Single_Response",
                      "Single_Response", "Single_Response",
                      "Single_Response", "Numeric"),
    ColumnPattern = c("{code}_{brand_code}", "{code}_{brand_code}",
                      "{code}", "{code}",
                      "{code}", "{code}"),
    OptionMapScale = c("", "attitude_scale", "", "", "", ""),
    Notes = NA_character_,
    stringsAsFactors = FALSE
  )
}

.structure_durable <- function() {
  list(questionmap = .questionmap_durable(),
       optionmap = .optionmap_attitude(),
       brands = .brand_list_ircc(),
       ceps = data.frame(), dba_assets = data.frame())
}

.config_durable <- function(tenure_threshold = 3) {
  list(
    `category.type` = "durable",
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


# --- Hand-calculated expected values -----------------------------------------

.expected_pct <- list(
  aware              = c(IPK = 0.9, ROB = 0.8, CART = 0.7),
  consideration      = c(IPK = 0.7, ROB = 0.6, CART = 0.5),
  current_owner_d    = c(IPK = 0.4, ROB = 0.2, CART = 0.2),
  long_tenured_d     = c(IPK = 0.3, ROB = 0.0, CART = 0.1)
)


# --- Tests -------------------------------------------------------------------

test_that("Aware and Consideration match transactional hand-calc (same data shape)", {
  data <- .fixture_durable()
  rm <- load_role_map(.structure_durable())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_durable())

  for (b in names(.expected_pct$aware)) {
    expect_equal(.pct_for(res$stages, "aware", b),
                 .expected_pct$aware[[b]], tolerance = 1e-9,
                 info = sprintf("aware %s", b))
    expect_equal(.pct_for(res$stages, "consideration", b),
                 .expected_pct$consideration[[b]], tolerance = 1e-9,
                 info = sprintf("consideration %s", b))
  }
})


test_that("Current owner stage matches hand calculation (nested in consideration)", {
  data <- .fixture_durable()
  rm <- load_role_map(.structure_durable())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_durable())

  for (b in names(.expected_pct$current_owner_d)) {
    expect_equal(.pct_for(res$stages, "current_owner_d", b),
                 .expected_pct$current_owner_d[[b]], tolerance = 1e-9,
                 info = sprintf("current_owner %s", b))
  }
})


test_that("Long-tenured stage matches hand calc with threshold = 3", {
  data <- .fixture_durable()
  rm <- load_role_map(.structure_durable())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_durable())

  for (b in names(.expected_pct$long_tenured_d)) {
    expect_equal(.pct_for(res$stages, "long_tenured_d", b),
                 .expected_pct$long_tenured_d[[b]], tolerance = 1e-9,
                 info = sprintf("long_tenured %s", b))
  }
})


test_that("Changing tenure_threshold shifts only the long-tenured stage", {
  data <- .fixture_durable()
  rm <- load_role_map(.structure_durable())
  # Threshold = 2: additional owners qualify.
  # IPK owners tenures: 3,2,3,3 -> at ten≥2, all 4 qualify = 40%
  # ROB owners tenures: 2,1 -> at ten≥2, only R2 = 10%
  # CART owners tenures: 4,1 -> at ten≥2, only R3 = 10%
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_durable(tenure_threshold = 2))

  expect_equal(.pct_for(res$stages, "long_tenured_d", "IPK"), 0.4, tolerance = 1e-9)
  expect_equal(.pct_for(res$stages, "long_tenured_d", "ROB"), 0.1, tolerance = 1e-9)
  expect_equal(.pct_for(res$stages, "long_tenured_d", "CART"), 0.1, tolerance = 1e-9)

  # Current_owner unchanged:
  expect_equal(.pct_for(res$stages, "current_owner_d", "IPK"), 0.4, tolerance = 1e-9)
})


test_that("Missing tenure_threshold drops Long-tenured and records a warning", {
  data <- .fixture_durable()
  rm <- load_role_map(.structure_durable())
  cfg <- .config_durable(tenure_threshold = NULL)
  res <- run_funnel(data, rm, .brand_list_ircc(), cfg)

  # Stage absent
  expect_equal(nrow(res$stages[res$stages$stage_key == "long_tenured_d", ]), 0)
  # Status partial due to dropped stage
  expect_equal(res$status, "PARTIAL")
  expect_true(any(grepl("Long-tenured", res$warnings)))
})


test_that("Stage count reflects 4-stage durable shape", {
  data <- .fixture_durable()
  rm <- load_role_map(.structure_durable())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_durable())
  expect_equal(res$meta$stage_count, 4)
  expect_setequal(res$meta$stage_keys,
    c("aware", "consideration", "current_owner_d", "long_tenured_d"))
})
