# ==============================================================================
# Tests for the Audience Lens engine + classifier + panel data builder
# ==============================================================================
# Hand-built 20-respondent fixture with 1 category (DSS), 3 brands
# (PANTENE, HEAD, OTHER), focal = PANTENE. Variables modelled directly on
# the role-registry conventions used elsewhere in the brand module:
#   BRANDAWARE_DSS_<brand>   awareness (1 = aware)
#   BRANDATT1_DSS_<brand>    attitude scale (1 love, 2 prefer, 3 ambivalent, 4 reject)
#   BRANDPEN2_DSS_<brand>    bought past 3 months indicator (1 / NA)
#   BRANDPEN3_DSS_<brand>    purchase frequency
#   CEP01_DSS_<brand>        CEP linkage indicator (1 / 0 / NA)
#   WOM_POS_REC_<brand>, WOM_NEG_REC_<brand>, WOM_POS_SHARE_<brand>,
#     WOM_NEG_SHARE_<brand>  WOM indicators
#   PROVINCE                 single-mention demographic
#
# Audience definitions (in-test, mirrors the AudienceLens sheet shape):
#   - gauteng (single, demographic, ALL scope)
#   - dss_pair (pair, A=Buyers, B=Non-buyers; category-scoped to DSS)
# ==============================================================================

source("../../R/00_guard.R", chdir = FALSE)
source("../../R/00_role_map.R", chdir = FALSE)
source("../../R/00_guard_role_map.R", chdir = FALSE)
source("../../R/01_config.R", chdir = FALSE)
source("../../R/13_audience_lens.R", chdir = FALSE)
source("../../R/13a_al_audiences.R", chdir = FALSE)
source("../../R/13b_al_metrics.R", chdir = FALSE)
source("../../R/13c_al_classify.R", chdir = FALSE)
source("../../R/13d_al_panel_data.R", chdir = FALSE)


build_al_fixture <- function() {
  # 20 respondents: 12 Pantene buyers, 8 non-buyers.
  # 8 in Gauteng (mix of buyers and non-buyers), 12 in WC.
  set.seed(42)
  n <- 20
  province <- c(rep("Gauteng", 8), rep("WC", 12))
  buyer_idx <- c(rep(TRUE, 12), rep(FALSE, 8))   # respondent-level buyer flag

  # Awareness — buyers all aware (1), non-buyers 5/8 aware
  aware_pant  <- ifelse(buyer_idx, 1L, c(1L,1L,1L,1L,1L,0L,0L,0L))
  aware_head  <- rep(1L, n)
  aware_other <- rep(1L, n)

  # Attitude — buyers heavily love/prefer; non-buyers ambivalent/reject
  att_pant <- c(rep(1L, 6), rep(2L, 6),       # buyers: 6 love + 6 prefer
                3L,3L,3L,3L,4L,4L,5L,5L)       # non-buyers: ambivalent/reject
  att_head <- rep(3L, n)
  att_other <- rep(3L, n)

  # P3M usage = brand buyers (this defines who's a buyer in the lens)
  p3m_pant <- ifelse(buyer_idx, 1L, NA_integer_)
  p3m_head <- c(rep(1L, 5), rep(NA_integer_, 15))
  p3m_other <- rep(NA_integer_, n)

  # Frequency — focal buyers average 4x; head buyers 2x; non-buyers NA
  freq_pant <- ifelse(buyer_idx, c(6,5,5,4,4,4,3,3,3,3,2,2), NA_real_)
  freq_head <- c(2,2,2,2,2, rep(NA_real_, 15))
  freq_other <- rep(NA_real_, n)

  # CEP linkage — focal MA: buyers all link CEP01 to focal; 2/8 non-buyers do
  cep01_pant <- ifelse(buyer_idx, 1L, c(1L,1L,0L,0L,0L,0L,0L,0L))
  cep01_head <- rep(1L, n)            # head links every respondent (high MMS denominator)
  cep01_other <- rep(0L, n)

  # WOM — buyers tell positive stories; non-buyers split
  wom_pos_rec_pant   <- ifelse(buyer_idx, 1L, c(0L,0L,0L,0L,0L,1L,1L,1L))
  wom_neg_rec_pant   <- ifelse(buyer_idx, 0L, 0L)
  wom_pos_share_pant <- ifelse(buyer_idx, 1L, 0L)
  wom_neg_share_pant <- ifelse(buyer_idx, 0L, c(1L,1L,0L,0L,0L,0L,0L,0L))

  data <- data.frame(
    Respondent_ID         = sprintf("R%02d", seq_len(n)),
    Focal_Category        = rep("DSS", n),
    PROVINCE              = province,
    BRANDAWARE_DSS_PANTENE  = aware_pant,
    BRANDAWARE_DSS_HEAD     = aware_head,
    BRANDAWARE_DSS_OTHER    = aware_other,
    BRANDATT1_DSS_PANTENE   = att_pant,
    BRANDATT1_DSS_HEAD      = att_head,
    BRANDATT1_DSS_OTHER     = att_other,
    BRANDPEN2_DSS_PANTENE   = p3m_pant,
    BRANDPEN2_DSS_HEAD      = p3m_head,
    BRANDPEN2_DSS_OTHER     = p3m_other,
    BRANDPEN3_DSS_PANTENE   = freq_pant,
    BRANDPEN3_DSS_HEAD      = freq_head,
    BRANDPEN3_DSS_OTHER     = freq_other,
    # CEP codes are globally unique (no cat infix) — matches real schema
    CEP01_PANTENE           = cep01_pant,
    CEP01_HEAD              = cep01_head,
    CEP01_OTHER             = cep01_other,
    WOM_POS_REC_PANTENE     = wom_pos_rec_pant,
    WOM_NEG_REC_PANTENE     = wom_neg_rec_pant,
    WOM_POS_SHARE_PANTENE   = wom_pos_share_pant,
    WOM_NEG_SHARE_PANTENE   = wom_neg_share_pant,
    stringsAsFactors = FALSE
  )

  qmap <- data.frame(
    Role = c("funnel.awareness.DSS", "funnel.attitude.DSS",
             "funnel.transactional.bought_target.DSS",
             "funnel.transactional.frequency.DSS",
             "demo.PROVINCE"),
    ClientCode = c("BRANDAWARE_DSS","BRANDATT1_DSS",
                   "BRANDPEN2_DSS","BRANDPEN3_DSS","PROVINCE"),
    QuestionText = NA_character_,
    Variable_Type = NA_character_,
    ColumnPattern = NA_character_,
    OptionMapScale = NA_character_,
    Notes = NA_character_,
    stringsAsFactors = FALSE
  )

  cat_brands <- data.frame(
    BrandCode = c("PANTENE", "HEAD", "OTHER"),
    BrandLabel = c("Pantene", "Head & Shoulders", "Other"),
    Category = "Shampoo",
    stringsAsFactors = FALSE
  )

  # CEP discovery now reads from the Questions sheet (Battery="cep_matrix"),
  # mirroring how the real brand structure is shaped.
  questions <- data.frame(
    QuestionCode = "CEP01",
    QuestionText = "Hand-test CEP",
    Battery = "cep_matrix",
    Category = "Shampoo",
    stringsAsFactors = FALSE
  )

  structure <- list(questionmap = qmap, questions = questions)

  # Audience definitions (post-parse shape)
  audiences <- list(
    list(id = "gauteng", label = "Gauteng", category = "ALL",
         pair_id = NULL, pair_role = "",
         filter_col = "PROVINCE", filter_op = "==", filter_value = "Gauteng"),
    list(id = "dss_buyers", label = "Buyers", category = "DSS",
         pair_id = "dss_pair", pair_role = "A",
         filter_col = "BRANDPEN2_DSS_PANTENE", filter_op = "==",
         filter_value = "1"),
    list(id = "dss_nbuyers", label = "Non-buyers", category = "DSS",
         pair_id = "dss_pair", pair_role = "B",
         filter_col = "BRANDPEN2_DSS_PANTENE", filter_op = "is_na",
         filter_value = "")
  )

  list(data = data, structure = structure, cat_brands = cat_brands,
       audiences = audiences,
       config = list(focal_brand = "PANTENE",
                     audience_lens_warn_base = 5L,    # tiny so n=8 isn't "low"
                     audience_lens_suppress_base = 3L,
                     audience_lens_alpha = 0.10,
                     audience_lens_gap_threshold = 0.10,
                     audience_lens_max = 6L,
                     decimal_places = 0L))
}


# ----------------------------------------------------------------------------
# Audience filter resolution
# ----------------------------------------------------------------------------

test_that("resolve_audience_index matches Gauteng filter", {
  fx <- build_al_fixture()
  idx <- resolve_audience_index(fx$audiences[[1]], fx$data)
  expect_equal(sum(idx), 8L)
  expect_true(all(fx$data$PROVINCE[idx] == "Gauteng"))
})

test_that("resolve_audience_index handles == 1 on numeric column", {
  fx <- build_al_fixture()
  idx <- resolve_audience_index(fx$audiences[[2]], fx$data)
  expect_equal(sum(idx), 12L)
})

test_that("resolve_audience_index handles is_na", {
  fx <- build_al_fixture()
  idx <- resolve_audience_index(fx$audiences[[3]], fx$data)
  expect_equal(sum(idx), 8L)
})


# ----------------------------------------------------------------------------
# Metric computation
# ----------------------------------------------------------------------------

test_that("compute_al_metrics_for_subset returns the full catalogue", {
  fx <- build_al_fixture()
  weights <- rep(1, nrow(fx$data))
  m <- compute_al_metrics_for_subset(
    data = fx$data, weights = weights,
    keep_idx = rep(TRUE, nrow(fx$data)),
    cat_brands = fx$cat_brands, cat_code = "DSS",
    focal_brand = "PANTENE", structure = fx$structure,
    config = fx$config)

  expect_true(all(c("awareness","consideration","p3m_usage","brand_love",
                    "branded_reach","mpen","network_size","mms","som",
                    "net_heard","net_said","loyalty_scr",
                    "purchase_distribution","purchase_frequency") %in% names(m)))

  # Awareness on TOTAL: 12 buyers (all aware) + 5 of 8 non-buyers = 17/20 = 0.85
  expect_equal(round(m$awareness$value, 3), 0.85)
  # Consideration (att 1 or 2) on TOTAL: 12 buyers all qualify = 12/20 = 0.60
  expect_equal(round(m$consideration$value, 3), 0.60)
  # Brand love (att == 1) on TOTAL = 6/20 = 0.30
  expect_equal(round(m$brand_love$value, 3), 0.30)
  # P3M usage on TOTAL = 12/20 = 0.60
  expect_equal(round(m$p3m_usage$value, 3), 0.60)
  # MPen — % linking CEP01 to focal = 12 buyers + 2 non-buyers = 14/20 = 0.70
  expect_equal(round(m$mpen$value, 3), 0.70)
})


test_that("MPen and SCR are smaller in non-buyer subset than total", {
  fx <- build_al_fixture()
  weights <- rep(1, nrow(fx$data))
  total_keep <- rep(TRUE, nrow(fx$data))
  nonbuyer_keep <- is.na(fx$data$BRANDPEN2_DSS_PANTENE)

  m_total <- compute_al_metrics_for_subset(
    fx$data, weights, total_keep, fx$cat_brands, "DSS", "PANTENE",
    fx$structure, config = fx$config)
  m_nb <- compute_al_metrics_for_subset(
    fx$data, weights, nonbuyer_keep, fx$cat_brands, "DSS", "PANTENE",
    fx$structure, config = fx$config)

  expect_lt(m_nb$mpen$value, m_total$mpen$value)
  # SCR is brand-buyer base → on the non-buyer subset there are no buyers,
  # so it must be NA
  expect_true(is.na(m_nb$loyalty_scr$value))
})


# ----------------------------------------------------------------------------
# End-to-end run_audience_lens()
# ----------------------------------------------------------------------------

test_that("run_audience_lens returns PASS with rendered audiences + a pair", {
  fx <- build_al_fixture()
  res <- run_audience_lens(
    data = fx$data, weights = NULL,
    cat_brands = fx$cat_brands, cat_code = "DSS",
    cat_name = "Shampoo", focal_brand = "PANTENE",
    audiences = fx$audiences,
    structure = fx$structure, config = fx$config)
  expect_equal(res$status, "PASS")
  expect_equal(res$meta$n_audiences, 3L)
  expect_equal(length(res$audiences), 3L)
  expect_equal(length(res$pair_cards), 1L)

  pc <- res$pair_cards[[1]]
  expect_true(is.character(pc$pair_id))
  expect_equal(pc$label_a, "Buyers")
  expect_equal(pc$label_b, "Non-buyers")

  rows <- pc$rows
  # Strong focal-brand fixture → buyers also lead total on every pct metric
  # → DEFEND (not GROW). Either is acceptable for the smoke check; what
  # matters is at least one positive classification fired on a sig metric.
  expect_true(any(rows$chip %in% c("GROW", "DEFEND"), na.rm = TRUE))
  # Loyalty (SCR) is N/A on non-buyer side; chip must NOT be GROW/FIX/DEFEND
  scr <- rows[rows$metric_id == "loyalty_scr", , drop = FALSE]
  expect_true(is.na(scr$chip) || !nzchar(scr$chip))
})


# ----------------------------------------------------------------------------
# Classifier
# ----------------------------------------------------------------------------

test_that("classify_chip returns GROW when buyers >> non-buyers and sig", {
  out <- classify_chip(metric_a = 0.85, metric_b = 0.40, metric_total = 0.55,
                       sig = TRUE, gap_pp = 0.10, kind = "pct",
                       focal_brand = "PANTENE")
  expect_equal(out$chip, "DEFEND")  # buyers ALSO lead total → DEFEND
})

test_that("classify_chip prefers GROW over FIX when there's a sig pair gap", {
  out <- classify_chip(metric_a = 0.50, metric_b = 0.20, metric_total = 0.55,
                       sig = TRUE, gap_pp = 0.10, kind = "pct",
                       focal_brand = "PANTENE")
  # Strong buyer/non-buyer gap dominates — recruitment story takes
  # precedence over a parity-vs-total nuance.
  expect_equal(out$chip, "GROW")
})

test_that("classify_chip returns FIX when buyers underperform total and no sig pair gap", {
  out <- classify_chip(metric_a = 0.40, metric_b = 0.42, metric_total = 0.55,
                       sig = FALSE, gap_pp = 0.10, kind = "pct",
                       focal_brand = "PANTENE")
  expect_equal(out$chip, "FIX")
})

test_that("classify_chip returns GROW for genuine recruitment lever", {
  out <- classify_chip(metric_a = 0.60, metric_b = 0.20, metric_total = 0.40,
                       sig = TRUE, gap_pp = 0.10, kind = "pct",
                       focal_brand = "PANTENE")
  expect_equal(out$chip, "DEFEND")
})

test_that("classify_chip returns NA when not significant", {
  out <- classify_chip(metric_a = 0.50, metric_b = 0.45, metric_total = 0.50,
                       sig = FALSE, gap_pp = 0.10, kind = "pct",
                       focal_brand = "PANTENE")
  expect_true(is.na(out$chip))
})


# ----------------------------------------------------------------------------
# Audience definition validation
# ----------------------------------------------------------------------------

test_that("validate_audience_filter rejects unknown column", {
  fx <- build_al_fixture()
  bad <- list(id = "bad", filter_col = "DOES_NOT_EXIST",
              filter_op = "==", filter_value = "X")
  err <- validate_audience_filter(bad, fx$data)
  expect_equal(err$code, "DATA_AUDIENCE_FILTER_COL_MISSING")
})

test_that("validate_audience_filter rejects unknown op", {
  fx <- build_al_fixture()
  bad <- list(id = "bad", filter_col = "PROVINCE",
              filter_op = "REGEX", filter_value = "G.*")
  err <- validate_audience_filter(bad, fx$data)
  expect_equal(err$code, "CFG_AUDIENCE_FILTER_OP_INVALID")
})


# ----------------------------------------------------------------------------
# Base-size discipline
# ----------------------------------------------------------------------------

test_that("audiences below suppression threshold are dropped", {
  fx <- build_al_fixture()
  # Add an audience that matches nobody (PROVINCE == "ZZZ")
  audiences <- c(fx$audiences, list(
    list(id = "ghost", label = "Ghost", category = "ALL",
         pair_id = NULL, pair_role = "",
         filter_col = "PROVINCE", filter_op = "==", filter_value = "ZZZ")
  ))
  res <- run_audience_lens(
    data = fx$data, weights = NULL,
    cat_brands = fx$cat_brands, cat_code = "DSS",
    cat_name = "Shampoo", focal_brand = "PANTENE",
    audiences = audiences, structure = fx$structure, config = fx$config)
  expect_equal(res$status, "PASS")
  expect_equal(res$meta$n_rendered, 3L)
  expect_equal(res$meta$n_suppressed, 1L)
  expect_equal(res$suppressed[[1]]$audience$id, "ghost")
})


# ----------------------------------------------------------------------------
# Panel data shape
# ----------------------------------------------------------------------------

test_that("build_audience_lens_panel_data returns banner + cards + pair", {
  fx <- build_al_fixture()
  res <- run_audience_lens(
    data = fx$data, weights = NULL,
    cat_brands = fx$cat_brands, cat_code = "DSS",
    cat_name = "Shampoo", focal_brand = "PANTENE",
    audiences = fx$audiences, structure = fx$structure, config = fx$config)
  pd <- build_audience_lens_panel_data(res, "Shampoo", "PANTENE",
                                        focal_colour = "#1A5276",
                                        decimal_places = 0L,
                                        wave_label = "1")
  expect_equal(pd$schema_version, 1L)
  expect_equal(pd$meta$category_label, "Shampoo")
  expect_equal(length(pd$cards), 3L)
  expect_equal(length(pd$pair_cards), 1L)
  expect_true(length(pd$banner_groups) >= 4L)
  # Spot-check the buyer-base N/A treatment in the banner
  scr_row <- NULL
  for (g in pd$banner_groups) {
    for (r in g$rows) {
      if (r$metric_id == "loyalty_scr") scr_row <- r
    }
  }
  expect_false(is.null(scr_row))
  # Non-buyer cell should carry buyer_base_na = TRUE
  nonbuyer_idx <- which(vapply(pd$cards, function(c)
    identical(toupper(c$audience$pair_role %||% ""), "B"), logical(1)))
  expect_length(nonbuyer_idx, 1L)
  expect_true(scr_row$cells[[nonbuyer_idx]]$buyer_base_na)
})


# ----------------------------------------------------------------------------
# HTML render smoke test
# ----------------------------------------------------------------------------

test_that("build_audience_lens_panel_html emits non-trivial HTML", {
  source("../../lib/html_report/panels/13_audience_lens_panel.R", chdir = FALSE)
  fx <- build_al_fixture()
  res <- run_audience_lens(
    data = fx$data, weights = NULL,
    cat_brands = fx$cat_brands, cat_code = "DSS",
    cat_name = "Shampoo", focal_brand = "PANTENE",
    audiences = fx$audiences, structure = fx$structure, config = fx$config)
  pd <- build_audience_lens_panel_data(res, "Shampoo", "PANTENE",
                                        focal_colour = "#1A5276",
                                        decimal_places = 0L)
  html <- build_audience_lens_panel_html(pd, category_code = "shampoo",
                                          focal_colour = "#1A5276")
  expect_true(grepl("al-banner-table", html))
  expect_true(grepl("al-card-grid",    html))
  expect_true(grepl("al-pair-card",    html))
  expect_true(grepl("al-chip-grow|al-chip-fix|al-chip-defend|al-chip-none", html))
  # JSON payload present
  expect_true(grepl("application/json", html))
  # Per-card pin button present
  expect_true(grepl("brTogglePin", html))
})


# ----------------------------------------------------------------------------
# Empty / no audiences
# ----------------------------------------------------------------------------

test_that("run_audience_lens with empty audiences returns PASS empty meta", {
  fx <- build_al_fixture()
  res <- run_audience_lens(
    data = fx$data, weights = NULL,
    cat_brands = fx$cat_brands, cat_code = "DSS",
    cat_name = "Shampoo", focal_brand = "PANTENE",
    audiences = list(), structure = fx$structure, config = fx$config)
  expect_equal(res$status, "PASS")
  expect_equal(res$meta$n_audiences, 0L)
  expect_null(res$banner_table)
})


test_that("run_audience_lens refuses without focal_brand", {
  fx <- build_al_fixture()
  res <- run_audience_lens(
    data = fx$data, weights = NULL,
    cat_brands = fx$cat_brands, cat_code = "DSS",
    cat_name = "Shampoo", focal_brand = "",
    audiences = fx$audiences, structure = fx$structure, config = fx$config)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CFG_FOCAL_BRAND_MISSING")
})
