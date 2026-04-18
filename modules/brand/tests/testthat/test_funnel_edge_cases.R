# ==============================================================================
# BRAND MODULE TESTS - FUNNEL EDGE CASES
# ==============================================================================
# Covers the non-happy paths listed in FUNNEL_SPEC_v2.md §10.2:
#   - Zero awareness (all stages 0%, conversions NA not NaN)
#   - All aware, none positive (Consideration = 0, later stages = 0)
#   - Missing optional role → stage omitted + warning, rest renders
#   - OptionMap omits Ambivalent → Consideration = Love + Prefer only
#   - Inverted attitude scale (codes reversed) → same stage counts
#   - Weights all equal 1 → weighted == unweighted
#   - Weights sum to zero handled at guard layer (covered in guard tests)
#   - suppress_base renders "suppress" flag on stages below threshold
#   - Frequency role absent → funnel still renders at 4 stages (heavy-buyer
#     analysis is not a funnel stage in v2.1, so frequency is never required).
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

.brand_list <- function(codes = c("IPK","ROB","CART")) {
  data.frame(BrandCode = codes, BrandLabel = codes, stringsAsFactors = FALSE)
}

.optionmap_attitude <- function(omit_ambivalent = FALSE, inverted = FALSE) {
  roles <- c("attitude.love","attitude.prefer","attitude.ambivalent",
             "attitude.reject","attitude.no_opinion")
  codes <- if (inverted) as.character(5:1) else as.character(1:5)
  om <- data.frame(
    Scale = rep("attitude_scale", 5),
    ClientCode = codes,
    Role = roles,
    ClientLabel = c("Love","Prefer","Ambivalent","Reject","No opinion"),
    OrderIndex = if (inverted) 5:1 else 1:5,
    stringsAsFactors = FALSE)
  if (omit_ambivalent) om$Role[om$Role == "attitude.ambivalent"] <- NA
  om
}

.qm_transactional <- function() {
  data.frame(
    Role = c("funnel.awareness","funnel.attitude",
             "funnel.transactional.bought_long",
             "funnel.transactional.bought_target",
             "funnel.transactional.frequency",
             "system.respondent.id","system.respondent.weight"),
    ClientCode = c("BRANDAWARE","QBRANDATT1",
                   "BRANDPENTRANS1","BRANDPENTRANS2","BRANDPENTRANS3",
                   "Respondent_ID","Weight"),
    QuestionText = c("Aware?","Att?","Bought_Long?","Bought_Target?","Freq?","ID","W"),
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

.structure <- function(questionmap, optionmap) {
  list(questionmap = questionmap, optionmap = optionmap,
       brands = .brand_list(), ceps = data.frame(), dba_assets = data.frame())
}

.config <- function(...) {
  defaults <- list(
    `category.type` = "transactional", focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0, `funnel.suppress_base` = 0)
  modifyList(defaults, list(...))
}

.fixture_transactional <- function() {
  read.csv(file.path(TURAS_ROOT, "modules", "brand", "tests", "fixtures",
                     "funnel_transactional_10resp.csv"),
           stringsAsFactors = FALSE)
}

.pct <- function(df, key, b) {
  row <- df[df$stage_key == key & df$brand_code == b, , drop = FALSE]
  if (nrow(row) == 0) NA_real_ else row$pct_weighted
}


# --- Zero awareness ----------------------------------------------------------

test_that("Zero awareness for all brands yields 0% at every stage, NA conversions", {
  n <- 10
  data <- data.frame(Respondent_ID = seq_len(n), Weight = 1,
                     stringsAsFactors = FALSE)
  for (b in c("IPK","ROB","CART")) {
    data[[paste0("BRANDAWARE_", b)]] <- 0
    data[[paste0("QBRANDATT1_", b)]] <- as.character(5)
    data[[paste0("BRANDPENTRANS1_", b)]] <- 0
    data[[paste0("BRANDPENTRANS2_", b)]] <- 0
    data[[paste0("BRANDPENTRANS3_", b)]] <- 0
  }
  rm <- load_role_map(.structure(.qm_transactional(), .optionmap_attitude()))
  res <- run_funnel(data, rm, .brand_list(), .config())

  for (b in c("IPK","ROB","CART")) {
    expect_equal(.pct(res$stages, "aware", b), 0)
    expect_equal(.pct(res$stages, "bought_target", b), 0)
  }
  # Conversions should be NA (not NaN / not division error)
  expect_true(all(is.na(res$conversions$value)))
})


# --- All aware, none positive ------------------------------------------------

test_that("All aware + none positive gives Consideration = 0 and later stages = 0", {
  n <- 10
  data <- data.frame(Respondent_ID = seq_len(n), Weight = 1,
                     stringsAsFactors = FALSE)
  for (b in c("IPK","ROB","CART")) {
    data[[paste0("BRANDAWARE_", b)]] <- 1
    data[[paste0("QBRANDATT1_", b)]] <- as.character(4)  # all reject
    data[[paste0("BRANDPENTRANS1_", b)]] <- 1
    data[[paste0("BRANDPENTRANS2_", b)]] <- 1
    data[[paste0("BRANDPENTRANS3_", b)]] <- 3
  }
  rm <- load_role_map(.structure(.qm_transactional(), .optionmap_attitude()))
  res <- run_funnel(data, rm, .brand_list(), .config())

  for (b in c("IPK","ROB","CART")) {
    expect_equal(.pct(res$stages, "aware", b), 1)
    expect_equal(.pct(res$stages, "consideration", b), 0)
    expect_equal(.pct(res$stages, "bought_long", b), 0)
  }
})


# --- Missing optional role --------------------------------------------------

test_that("Dropping the frequency role leaves the funnel intact (4 stages, no warning)", {
  # In v2.1 frequency is consumed by the Repertoire / Frequency element,
  # not the funnel. Absent → funnel is unaffected; no preferred/heavy_buyer
  # stage is produced in either case.
  qm <- .qm_transactional()
  qm <- qm[qm$Role != "funnel.transactional.frequency", , drop = FALSE]
  rm <- load_role_map(.structure(qm, .optionmap_attitude()))

  data <- .fixture_transactional()
  res <- run_funnel(data, rm, .brand_list(), .config())

  expect_equal(res$status, "PASS")
  expect_false("preferred" %in% res$meta$stage_keys)
  expect_false("heavy_buyer" %in% res$meta$stage_keys)
  expect_equal(res$meta$stage_count, 4)
  expect_equal(.pct(res$stages, "aware", "IPK"), 0.9, tolerance = 1e-9)
})


test_that("Dropping bought_long and bought_target still yields a 2-stage minimum funnel", {
  qm <- .qm_transactional()
  qm <- qm[!qm$Role %in% c("funnel.transactional.bought_long",
                            "funnel.transactional.bought_target",
                            "funnel.transactional.frequency"),
           , drop = FALSE]
  rm <- load_role_map(.structure(qm, .optionmap_attitude()))
  data <- .fixture_transactional()

  res <- run_funnel(data, rm, .brand_list(), .config())
  expect_equal(res$meta$stage_count, 2)
  expect_setequal(res$meta$stage_keys, c("aware", "consideration"))
})


# --- OptionMap omits Ambivalent ---------------------------------------------

test_that("Omitting Ambivalent in OptionMap reduces Consideration to Love + Prefer only", {
  rm <- load_role_map(.structure(.qm_transactional(),
                                 .optionmap_attitude(omit_ambivalent = TRUE)))
  data <- .fixture_transactional()
  res <- run_funnel(data, rm, .brand_list(), .config())

  # IPK consideration had R3(att=3) and R7(att=3) in the full set. Dropping
  # ambivalent removes them → 7 - 2 = 5 → 50%.
  expect_equal(.pct(res$stages, "consideration", "IPK"), 0.5, tolerance = 1e-9)
})


# --- Inverted attitude scale ------------------------------------------------

test_that("Inverted attitude scale (5=love..1=no_opinion) yields same stage counts", {
  data <- .fixture_transactional()
  # Invert attitude codes in the data: map 1->5, 2->4, 3->3, 4->2, 5->1
  for (b in c("IPK","ROB","CART")) {
    col <- paste0("QBRANDATT1_", b)
    data[[col]] <- as.character(6 - as.integer(data[[col]]))
  }
  rm <- load_role_map(.structure(.qm_transactional(),
                                 .optionmap_attitude(inverted = TRUE)))
  res <- run_funnel(data, rm, .brand_list(), .config())

  expect_equal(.pct(res$stages, "consideration", "IPK"), 0.7, tolerance = 1e-9)
  expect_equal(.pct(res$stages, "bought_target", "IPK"), 0.5, tolerance = 1e-9)
})


# --- Weight parity ----------------------------------------------------------

test_that("Weights all equal 1 produce weighted == unweighted", {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure(.qm_transactional(), .optionmap_attitude()))
  res_u <- run_funnel(data, rm, .brand_list(), .config())
  res_w <- run_funnel(data, rm, .brand_list(), .config(),
                     weights = rep(1, nrow(data)))

  expect_equal(res_u$stages$pct_weighted, res_w$stages$pct_weighted)
  expect_equal(res_u$stages$base_weighted, res_w$stages$base_weighted)
})


# --- Suppress base flag ------------------------------------------------------

test_that("suppress_base = 50 marks stages with base 30-49 as 'suppress'", {
  # Tiny fixture where Target Period base randomly falls below 50 at the
  # brand level while Aware base (60) sits in the warn band (50..<75).
  set.seed(7)
  n <- 60
  data <- data.frame(Respondent_ID = seq_len(n), Weight = 1)
  for (b in c("IPK","ROB","CART")) {
    data[[paste0("BRANDAWARE_", b)]]  <- rep(1, n)
    data[[paste0("QBRANDATT1_", b)]]  <- as.character(sample(1:2, n, replace = TRUE))
    data[[paste0("BRANDPENTRANS1_", b)]] <- rep(1, n)
    # Target period: only random subset → narrower base at stage 4
    data[[paste0("BRANDPENTRANS2_", b)]] <- sample(0:1, n, replace = TRUE)
    data[[paste0("BRANDPENTRANS3_", b)]] <- 1
  }
  rm <- load_role_map(.structure(.qm_transactional(), .optionmap_attitude()))
  cfg <- .config(`funnel.suppress_base` = 50, `funnel.warn_base` = 75)
  res <- run_funnel(data, rm, .brand_list(), cfg)

  aware_flags  <- res$stages$warning_flag[res$stages$stage_key == "aware"]
  target_flags <- res$stages$warning_flag[res$stages$stage_key == "bought_target"]
  # Aware for every brand is 60 → between 50 and 75 → warn
  expect_true(all(aware_flags == "warn"))
  # Target Period bases (randomish) likely below 50 → suppress
  expect_true(any(target_flags == "suppress"))
})


# --- Category type refusal --------------------------------------------------

test_that("Unknown category.type refuses with CFG_CATEGORY_TYPE_INVALID", {
  rm <- load_role_map(.structure(.qm_transactional(), .optionmap_attitude()))
  data <- .fixture_transactional()
  res <- brand_with_refusal_handler(
    run_funnel(data, rm, .brand_list(),
               .config(`category.type` = "mystery"))
  )
  expect_true(res$refused)
  expect_equal(res$code, "CFG_CATEGORY_TYPE_INVALID")
})
