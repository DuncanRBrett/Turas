# ==============================================================================
# BRAND MODULE TESTS - FUNNEL (TRANSACTIONAL CATEGORY TYPE)
# ==============================================================================
# Known-answer tests against fixtures/funnel_transactional_10resp.csv.
#
# Hand-calculated derivation (10 respondents, 3 brands: IPK / ROB / CART):
#
# Row   Aware              Attitude            Bought_Long       Bought_Target     Frequency
#       I R C              I R C               I R C             I R C             I R C
#  1    1 1 1              1 3 5               1 1 0             1 1 0             5 2 0
#  2    1 1 1              2 1 4               1 1 0             1 1 0             4 4 0  (I/R tie)
#  3    1 0 1              3 5 2               1 0 1             0 0 1             3 0 6
#  4    1 1 1              4 2 1               0 1 1             0 1 1             0 3 2
#  5    0 1 0              5 3 5               0 1 0             0 0 0             0 0 0
#  6    1 1 1              1 4 3               1 0 1             1 0 0             2 0 3
#  7    1 0 0              3 5 5               0 0 0             0 0 0             0 0 0
#  8    1 1 1              2 4 2               1 0 1             1 0 1             3 0 2
#  9    1 1 1              5 2 1               0 1 1             0 0 1             0 2 5
# 10    1 1 0              1 1 5               1 1 0             1 1 0             4 4 0  (I/R tie)
#
# Stage counts per brand (unweighted %, weights all 1):
#   Aware         IPK=9 (90%) ROB=8 (80%) CART=7 (70%)
#   Consideration IPK=7 (70%) ROB=6 (60%) CART=5 (50%)
#   Bought_Long   IPK=6 (60%) ROB=6 (60%) CART=5 (50%)
#   Bought_Target IPK=5 (50%) ROB=4 (40%) CART=4 (40%)
#
# Transactional funnel has 4 stages (FUNNEL_SPEC_v2 §3.1). Heavy-buyer /
# frequency analysis lives in the Repertoire / Frequency element, not the
# funnel — so the Frequency column in the fixture is retained for integration
# tests of that element but is not consumed here.
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


# --- Fixture loaders ---------------------------------------------------------

.fixture_transactional <- function() {
  fp <- file.path(TURAS_ROOT, "modules", "brand", "tests", "fixtures",
                  "funnel_transactional_10resp.csv")
  read.csv(fp, stringsAsFactors = FALSE)
}

.brand_list_ircc <- function() {
  data.frame(BrandCode = c("IPK", "ROB", "CART"),
             BrandLabel = c("IPK", "Robertsons", "Cartwright"),
             stringsAsFactors = FALSE)
}

.optionmap_attitude <- function() {
  data.frame(
    Scale = rep("attitude_scale", 5),
    ClientCode = as.character(1:5),
    Role = c("attitude.love", "attitude.prefer",
             "attitude.ambivalent", "attitude.reject",
             "attitude.no_opinion"),
    ClientLabel = c("Love", "Prefer", "Ambivalent", "Reject", "No opinion"),
    OrderIndex = 1:5,
    stringsAsFactors = FALSE
  )
}

.questionmap_transactional <- function() {
  data.frame(
    Role = c("funnel.awareness", "funnel.attitude",
             "funnel.transactional.bought_long",
             "funnel.transactional.bought_target",
             "funnel.transactional.frequency",
             "system.respondent.id", "system.respondent.weight"),
    ClientCode = c("BRANDAWARE", "QBRANDATT1",
                   "BRANDPENTRANS1", "BRANDPENTRANS2", "BRANDPENTRANS3",
                   "Respondent_ID", "Weight"),
    QuestionText = c("Which brands?", "Attitude?", "Bought long?",
                     "Bought target?", "How often?", "ID", "Weight"),
    QuestionTextShort = NA_character_,
    Variable_Type = c("Multi_Mention", "Single_Response",
                      "Multi_Mention", "Multi_Mention",
                      "Numeric",
                      "Single_Response", "Numeric"),
    ColumnPattern = c("{code}_{brand_code}", "{code}_{brand_code}",
                      "{code}_{brand_code}", "{code}_{brand_code}",
                      "{code}_{brand_code}",
                      "{code}", "{code}"),
    OptionMapScale = c("", "attitude_scale", "", "", "", "", ""),
    Notes = NA_character_,
    stringsAsFactors = FALSE
  )
}

.structure_transactional <- function() {
  list(questionmap = .questionmap_transactional(),
       optionmap = .optionmap_attitude(),
       brands = .brand_list_ircc(),
       ceps = data.frame(),
       dba_assets = data.frame())
}

.config_transactional <- function() {
  list(
    `category.type` = "transactional",
    focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0,
    `funnel.suppress_base` = 0,
    `funnel.significance_level` = 0.05
  )
}


# --- Expected values (hand-calculated; see header comment) -------------------

.expected_pct <- list(
  aware         = c(IPK = 0.9, ROB = 0.8, CART = 0.7),
  consideration = c(IPK = 0.7, ROB = 0.6, CART = 0.5),
  bought_long   = c(IPK = 0.6, ROB = 0.6, CART = 0.5),
  bought_target = c(IPK = 0.5, ROB = 0.4, CART = 0.4)
)

.expected_base_unweighted <- list(
  aware         = c(IPK = 9, ROB = 8, CART = 7),
  consideration = c(IPK = 7, ROB = 6, CART = 5),
  bought_long   = c(IPK = 6, ROB = 6, CART = 5),
  bought_target = c(IPK = 5, ROB = 4, CART = 4)
)


# --- Tests: stage metrics ----------------------------------------------------

.pct_for <- function(df, stage_key, brand_code) {
  row <- df[df$stage_key == stage_key & df$brand_code == brand_code, ,
            drop = FALSE]
  if (nrow(row) == 0) return(NA_real_)
  row$pct_weighted
}

.base_for <- function(df, stage_key, brand_code) {
  row <- df[df$stage_key == stage_key & df$brand_code == brand_code, ,
            drop = FALSE]
  if (nrow(row) == 0) return(NA_real_)
  row$base_unweighted
}


test_that("run_funnel returns PASS status on complete transactional fixture", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_transactional())
  expect_equal(res$status, "PASS")
})


test_that("Aware stage matches hand calculation for every brand", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_transactional())

  for (b in names(.expected_pct$aware)) {
    expect_equal(.pct_for(res$stages, "aware", b),
                 .expected_pct$aware[[b]], tolerance = 1e-9,
                 info = sprintf("Aware pct for %s", b))
    expect_equal(.base_for(res$stages, "aware", b),
                 .expected_base_unweighted$aware[[b]],
                 info = sprintf("Aware base for %s", b))
  }
})


test_that("Consideration stage matches hand calculation", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_transactional())

  for (b in names(.expected_pct$consideration)) {
    expect_equal(.pct_for(res$stages, "consideration", b),
                 .expected_pct$consideration[[b]], tolerance = 1e-9,
                 info = sprintf("Consideration pct for %s", b))
  }
})


test_that("Bought_Long stage matches hand calculation and nests in Consideration", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_transactional())

  for (b in names(.expected_pct$bought_long)) {
    expect_equal(.pct_for(res$stages, "bought_long", b),
                 .expected_pct$bought_long[[b]], tolerance = 1e-9,
                 info = sprintf("Bought_Long pct for %s", b))
  }
})


test_that("Bought_Target stage matches hand calculation", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_transactional())

  for (b in names(.expected_pct$bought_target)) {
    expect_equal(.pct_for(res$stages, "bought_target", b),
                 .expected_pct$bought_target[[b]], tolerance = 1e-9,
                 info = sprintf("Bought_Target pct for %s", b))
  }
})


test_that("Preferred-era stages are not materialised (funnel terminates at Target Period)", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_transactional())

  expect_false("preferred" %in% res$stages$stage_key)
  expect_false("heavy_buyer" %in% res$stages$stage_key)
})


# --- Tests: conversions ------------------------------------------------------

test_that("IPK conversion ratios match hand-calculated drops", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_transactional())

  ipk <- res$conversions[res$conversions$brand_code == "IPK", ]
  # Aware -> Consideration = 0.7 / 0.9 = 0.7778
  expect_equal(
    ipk$value[ipk$from_stage == "aware" & ipk$to_stage == "consideration"],
    0.7 / 0.9, tolerance = 1e-6)
  # Consideration -> Bought_Long = 0.6 / 0.7
  expect_equal(
    ipk$value[ipk$from_stage == "consideration" &
              ipk$to_stage == "bought_long"],
    0.6 / 0.7, tolerance = 1e-6)
  # Bought_Long -> Bought_Target = 0.5 / 0.6
  expect_equal(
    ipk$value[ipk$from_stage == "bought_long" &
              ipk$to_stage == "bought_target"],
    0.5 / 0.6, tolerance = 1e-6)
})


test_that("absolute_gap method returns percentage-point drops", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  cfg <- .config_transactional()
  cfg$`funnel.conversion_metric` <- "absolute_gap"
  res <- run_funnel(data, rm, .brand_list_ircc(), cfg)

  ipk <- res$conversions[res$conversions$brand_code == "IPK", ]
  expect_equal(
    ipk$value[ipk$from_stage == "aware" & ipk$to_stage == "consideration"],
    0.7 - 0.9, tolerance = 1e-9)
})


# --- Tests: attitude decomposition ------------------------------------------

test_that("IPK attitude decomposition sums to 100% and matches hand calc", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_transactional())

  ipk <- res$attitude_decomposition[
    res$attitude_decomposition$brand_code == "IPK", ]
  # Aware respondents for IPK: 9 (R1,R2,R3,R4,R6,R7,R8,R9,R10)
  # Attitude codes: 1,2,3,4,1,3,2,5,1
  # Love (1): R1,R6,R10 = 3/9
  # Prefer (2): R2,R8 = 2/9
  # Ambivalent (3): R3,R7 = 2/9
  # Reject (4): R4 = 1/9
  # No opinion (5): R9 = 1/9
  expect_equal(ipk$pct[ipk$attitude_role == "attitude.love"],
               3 / 9, tolerance = 1e-9)
  expect_equal(ipk$pct[ipk$attitude_role == "attitude.prefer"],
               2 / 9, tolerance = 1e-9)
  expect_equal(ipk$pct[ipk$attitude_role == "attitude.reject"],
               1 / 9, tolerance = 1e-9)
  expect_equal(sum(ipk$pct), 1.0, tolerance = 1e-9)
})


# --- Tests: metrics summary --------------------------------------------------

test_that("metrics_summary carries focal_by_stage with every stage", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_transactional())

  ms <- res$metrics_summary
  expect_equal(ms$focal_brand, "IPK")
  expect_equal(length(ms$focal_by_stage), 4)
  expect_equal(ms$focal_by_stage$aware, 0.9, tolerance = 1e-9)
  expect_equal(ms$focal_by_stage$bought_target, 0.5, tolerance = 1e-9)
})


test_that("biggest_drop identifies IPK's weakest stage-to-stage", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_transactional())

  ms <- res$metrics_summary
  expect_true(!is.null(ms$biggest_drop))
  # IPK ratios:
  #   aware->consideration  0.778  <- weakest
  #   consideration->BL     0.857
  #   BL->BT                0.833
  expect_equal(ms$biggest_drop$from_stage, "aware")
  expect_equal(ms$biggest_drop$to_stage, "consideration")
})


# --- Tests: meta -------------------------------------------------------------

test_that("meta records category type, focal, and stage keys", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  res <- run_funnel(data, rm, .brand_list_ircc(), .config_transactional())

  expect_equal(res$meta$category_type, "transactional")
  expect_equal(res$meta$focal_brand, "IPK")
  expect_equal(res$meta$n_unweighted, 10)
  expect_equal(res$meta$stage_count, 4)
  expect_setequal(res$meta$stage_keys,
    c("aware", "consideration", "bought_long", "bought_target"))
})
