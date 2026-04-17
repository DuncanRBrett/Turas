# ==============================================================================
# BRAND MODULE TESTS - FUNNEL NESTING INVARIANT (§3.4)
# ==============================================================================
# Validates that:
# 1. Stage counts decrease monotonically by construction (nested derivation).
# 2. Fabricating a nesting violation triggers CALC_NESTING_VIOLATED.
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

.brand_list <- function() {
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
             ClientLabel = c("L","P","A","R","N"),
             OrderIndex = 1:5,
             stringsAsFactors = FALSE)
}

.minimal_transactional <- function() {
  qm <- data.frame(
    Role = c("funnel.awareness","funnel.attitude",
             "funnel.transactional.bought_target",
             "funnel.transactional.frequency",
             "system.respondent.id","system.respondent.weight"),
    ClientCode = c("AW","ATT","BT","FR","RID","W"),
    QuestionText = c("Aware","Att","BT","FR","RID","W"),
    QuestionTextShort = NA, Variable_Type = c("Multi_Mention","Single_Response",
      "Multi_Mention","Numeric","Single_Response","Numeric"),
    ColumnPattern = c("{code}_{brand_code}","{code}_{brand_code}",
      "{code}_{brand_code}","{code}_{brand_code}","{code}","{code}"),
    OptionMapScale = c("","attitude_scale","","","",""),
    Notes = NA, stringsAsFactors = FALSE)
  list(questionmap = qm, optionmap = .optionmap_attitude(),
       brands = .brand_list(), ceps = data.frame(), dba_assets = data.frame())
}


# --- Tests -------------------------------------------------------------------

test_that("derived stages are nested by construction across a large fixture", {
  set.seed(42)
  n <- 100
  brands <- c("IPK", "ROB", "CART")
  data <- data.frame(RID = 1:n, W = runif(n, 0.5, 1.5),
                     stringsAsFactors = FALSE)
  for (b in brands) {
    data[[paste0("AW_", b)]] <- sample(0:1, n, replace = TRUE)
    data[[paste0("ATT_", b)]] <- sample(1:5, n, replace = TRUE)
    data[[paste0("BT_", b)]] <- sample(0:1, n, replace = TRUE)
    data[[paste0("FR_", b)]] <- sample(0:10, n, replace = TRUE)
  }
  rm <- load_role_map(.minimal_transactional())
  res <- run_funnel(data, rm, .brand_list(), list(
    `category.type` = "transactional", focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0, `funnel.suppress_base` = 0))

  stage_keys <- unique(res$stages$stage_key)
  for (b in brands) {
    bases <- res$stages$base_unweighted[
      res$stages$brand_code == b & res$stages$stage_key %in% stage_keys]
    stages_in_order <- res$stages$stage_key[
      res$stages$brand_code == b & res$stages$stage_key %in% stage_keys]
    # Order by the stage_keys' appearance
    ord <- match(stage_keys, stages_in_order)
    bases_ordered <- bases[ord[!is.na(ord)]]
    expect_true(
      all(diff(bases_ordered) <= 0),
      info = sprintf("Stage counts for %s should be monotonically non-increasing", b)
    )
  }
})


test_that("validate_nesting refuses loud on a fabricated violation", {
  # Build two stages where stage 2 has MORE respondents than stage 1.
  m1 <- matrix(c(1,1,0,  0,0,0), nrow = 2, ncol = 3, byrow = TRUE,
               dimnames = list(NULL, c("IPK","ROB","CART")))
  m2 <- matrix(c(1,1,1,  1,1,1), nrow = 2, ncol = 3, byrow = TRUE,
               dimnames = list(NULL, c("IPK","ROB","CART")))
  stages <- list(
    aware         = list(key = "aware",         label = "Aware",
                         matrix = m1 == 1),
    consideration = list(key = "consideration", label = "Consideration",
                         matrix = m2 == 1)
  )
  res <- brand_with_refusal_handler(validate_nesting(stages))
  expect_true(res$refused)
  expect_equal(res$code, "CALC_NESTING_VIOLATED")
})


test_that("validate_nesting passes when stage counts equal the previous", {
  m <- matrix(c(1,1,0,  1,1,0), nrow = 2, ncol = 3, byrow = TRUE,
              dimnames = list(NULL, c("IPK","ROB","CART")))
  stages <- list(
    a = list(key="a", label="A", matrix = m == 1),
    b = list(key="b", label="B", matrix = m == 1)
  )
  expect_true(validate_nesting(stages))
})


test_that("validate_nesting is a no-op with fewer than 2 stages", {
  expect_true(validate_nesting(list()))
  expect_true(validate_nesting(list(
    only = list(key="only", label="Only",
                matrix = matrix(TRUE, nrow = 3, ncol = 2,
                                dimnames = list(NULL, c("A","B"))))
  )))
})
