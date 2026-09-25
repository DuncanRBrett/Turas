# ==============================================================================
# TURAS PRICING - PIPELINE GATE (robustness gates 2 and 4)
# ==============================================================================
#
# Runs the shipped Karoo configs from their workbooks in a child Rscript and
# reads every headline number back from the files the client gets: the
# Results workbook, the stats pack, the v2 island, the standalone simulator,
# and the v2 Pricing tab rendered from the island by the shipped
# 27z_pricing.js. Each is compared with a reference computed here from the
# data file (psm_analysis_weighted, weighted means, isoreg, glm), never with
# the engine's return value.
#
# Only the bootstrap iteration counts are edited (20 instead of 300), to keep
# the run fast; no interval is reference-checked here.
# ==============================================================================

source(file.path(pricing_repo_root_for_tests <- (function() {
  d <- normalizePath(getwd())
  for (i in 1:10) { if (file.exists(file.path(d, "launch_turas.R"))) return(d); d <- dirname(d) }
  getwd()
})(), "modules", "pricing", "tests", "testthat", "helper_pipeline_fixture.R"))

skip_if_not(file.exists(file.path(pricing_repo_root(), "examples", "pricing", "Karoo_Pricing_Data.xlsx")),
            "examples/pricing/Karoo_Pricing_Data.xlsx is missing")

KAROO <- openxlsx::read.xlsx(file.path(pricing_repo_root(), "examples", "pricing", "Karoo_Pricing_Data.xlsx"))
FAST <- c("cfg$van_westendorp$bootstrap_iterations <- 20",
          "cfg$gabor_granger$bootstrap_iterations <- 20",
          "cfg$monadic$bootstrap_iterations <- 20")

# The documented rounding rule for the recommended price (see
# test_reference_synthesis.R for every branch).
ref_psych <- function(p) {
  r <- if (p < 10) floor(p) + 0.99 else if (p < 100) {
    b <- floor(p / 5) * 5; if (p - b < 2.5) b - 0.01 else b + 4.99
  } else round(p / 5) * 5 - 0.01
  if (abs(r - p) / p > 0.10) round(p, 2) else r
}
kish <- function(w) sum(w)^2 / sum(w^2)
num <- function(x) as.numeric(as.character(x))

# Respondents the both-methods run analyses, derived from the config's rules
# (Validation sheet: Price_Min 5, Price_Max 500, all four VW answers present,
# strictly ascending; a usable weight).
karoo_vw_keep <- function(d) {
  vw <- d[, c("VW_TooCheap", "VW_Cheap", "VW_Expensive", "VW_TooExpensive")]
  ok_w <- is.finite(d$Weight) & d$Weight > 0
  complete <- stats::complete.cases(vw)
  in_range <- apply(vw, 1, function(r) all(is.na(r) | (r >= 5 & r <= 500)))
  strict <- complete & vw[[1]] < vw[[2]] & vw[[2]] < vw[[3]] & vw[[3]] < vw[[4]]
  ok_w & complete & in_range & strict
}

ref_gg <- function(d, cols, prices, cost) {
  raw <- vapply(cols, function(cc) weighted.mean(d[[cc]], d$Weight), numeric(1))
  sm <- -isoreg(prices, -raw)$yf
  rev <- prices * sm
  list(raw = unname(raw), smooth = sm, opt = prices[which.max(rev)],
       opt_profit = prices[which.max((prices - cost) * sm)], n = nrow(d))
}

# ------------------------------------------------------------------------------
# Van Westendorp + Gabor-Granger (Karoo_Pricing_Config.xlsx), weighted
# ------------------------------------------------------------------------------
BOTH <- pricing_pipeline_run("Karoo_Pricing_Config.xlsx", edits = FAST)

keep <- karoo_vw_keep(KAROO)
KB <- KAROO[keep, ]
gg_cols <- c("GG_R60", "GG_R80", "GG_R100", "GG_R120", "GG_R140")
KB <- KB[stats::complete.cases(KB[, gg_cols]), ]
REF_VW <- local({
  des <- survey::svydesign(ids = ~1, weights = ~Weight,
                           data = data.frame(tc = KB$VW_TooCheap, ch = KB$VW_Cheap,
                                             ex = KB$VW_Expensive, te = KB$VW_TooExpensive,
                                             Weight = KB$Weight))
  p <- suppressWarnings(pricesensitivitymeter::psm_analysis_weighted(
    toocheap = "tc", cheap = "ch", expensive = "ex", tooexpensive = "te",
    design = des, validate = TRUE, interpolate = TRUE, interpolation_steps = 0.1))
  c(PMC = p$pricerange_lower, OPP = p$opp, IDP = p$idp, PME = p$pricerange_upper)
})
REF_GG <- ref_gg(KB, gg_cols, c(60, 80, 100, 120, 140), cost = 38)

test_that("both-methods run: the run completes PASS and writes every deliverable", {
  expect_equal(BOTH$status, "PASS", info = paste(tail(BOTH$log, 30), collapse = "\n"))
  for (f in c(BOTH$workbook, BOTH$stats_pack, BOTH$island, BOTH$simulator)) {
    expect_true(file.exists(f), info = f)
  }
  rs <- pricing_kv(BOTH$workbook, "Run_Status")
  expect_equal(unname(rs["Status"]), "PASS")
})

test_that("both-methods run: the analysed base matches the config's own rules", {
  expect_equal(sum(keep), 356L)
  sm <- pricing_kv(BOTH$workbook, "Summary")
  expect_equal(num(sm["Valid Respondents"]), 356)
  expect_equal(num(sm["Effective Sample Size (Kish, analysed cases)"]),
               round(kish(KB$Weight), 1))
})

test_that("both-methods run: VW price points on the sheet equal psm_analysis_weighted", {
  pp <- pricing_sheet(BOTH$workbook, "VW_Price_Points", colNames = FALSE)
  got <- setNames(num(pp$X3[2:5]), pp$X1[2:5])
  expect_equal(got[c("PMC", "OPP", "IDP", "PME")], REF_VW, tolerance = 1e-9)
})

test_that("both-methods run: GG demand, optimum and profit optimum on the sheets equal the reference", {
  dc <- pricing_sheet(BOTH$workbook, "GG_Demand_Curve")
  expect_equal(dc$price, c(60, 80, 100, 120, 140))
  expect_equal(dc$n_respondents, rep(REF_GG$n, 5))
  expect_equal(dc$purchase_intent_raw, REF_GG$raw, tolerance = 1e-9)
  expect_equal(dc$purchase_intent, REF_GG$smooth, tolerance = 1e-9)
  opt <- pricing_kv(BOTH$workbook, "GG_Optimal_Revenue")
  expect_equal(num(opt["Revenue-Maximizing Price"]), REF_GG$opt)
  prof <- pricing_kv(BOTH$workbook, "GG_Optimal_Profit")
  expect_equal(num(prof["Profit-Maximizing Price"]), REF_GG$opt_profit)
})

test_that("both-methods run: the recommended price is the GG optimum under the rounding rule", {
  rec <- pricing_sheet(BOTH$workbook, "Recommendation", colNames = FALSE)
  got <- rec$X2[which(rec$X1 == "Recommended Price")]
  expect_equal(got, sprintf("R%.2f", ref_psych(REF_GG$opt)))
})

test_that("both-methods run: segment price points equal psm_analysis_weighted on each segment", {
  sc <- pricing_sheet(BOTH$workbook, "Segment_Comparison")
  sc <- sc[!is.na(sc$n) & sc$segment != "Total", ]
  expect_setequal(sc$segment, c("Budget", "New Customer", "Premium", "Standard"))
  for (s in sc$segment) {
    k <- KB[KB$Segment == s, ]
    des <- survey::svydesign(ids = ~1, weights = ~Weight,
                             data = data.frame(tc = k$VW_TooCheap, ch = k$VW_Cheap,
                                               ex = k$VW_Expensive, te = k$VW_TooExpensive,
                                               Weight = k$Weight))
    p <- suppressWarnings(pricesensitivitymeter::psm_analysis_weighted(
      toocheap = "tc", cheap = "ch", expensive = "ex", tooexpensive = "te",
      design = des, validate = TRUE, interpolate = TRUE, interpolation_steps = 0.1))
    row <- sc[sc$segment == s, ]
    expect_equal(num(row$n), nrow(k), info = s)
    expect_equal(num(unlist(row[c("PMC", "OPP", "IDP", "PME")])),
                 round(c(p$pricerange_lower, p$opp, p$idp, p$pricerange_upper), 2),
                 tolerance = 1e-9, info = s)
  }
})

test_that("both-methods run: the stats pack carries the workbook's numbers", {
  sp <- pricing_kv(BOTH$stats_pack, "Assumptions")
  expect_equal(num(sp["VW: OPP"]), round(REF_VW[["OPP"]], 2))
  expect_equal(num(sp["VW: PME"]), round(REF_VW[["PME"]], 2))
  expect_equal(num(sp["GG: optimal_price"]), REF_GG$opt)
  expect_equal(num(sp["GG: profit_optimal_price"]), REF_GG$opt_profit)
  expect_equal(num(sp["Effective N (Kish)"]), round(kish(KB$Weight), 1))
  expect_equal(unname(sp["TRS Status"]), "PASS")
})

test_that("both-methods run: the v2 island carries the workbook's numbers", {
  isl <- jsonlite::fromJSON(BOTH$island)
  expect_equal(isl$vw$point, c("PMC", "OPP", "IDP", "PME"))
  expect_equal(isl$vw$value, unname(REF_VW), tolerance = 1e-5)
  expect_equal(isl$gg$acceptancePct, REF_GG$raw * 100, tolerance = 1e-4)
  expect_equal(isl$gg$optimalRevenuePrice, REF_GG$opt)
  expect_equal(isl$gg$optimalProfitPrice, REF_GG$opt_profit)
  expect_equal(isl$recommendation$price, ref_psych(REF_GG$opt))
  expect_equal(isl$meta$nValid, 356L)
  expect_equal(isl$meta$effectiveN, kish(KB$Weight), tolerance = 1e-3)
  rec <- pricing_sheet(BOTH$workbook, "Recommendation", colNames = FALSE)
  score <- rec$X2[which(rec$X1 == "Confidence Score")]
  expect_equal(sprintf("%.0f%%", isl$recommendation$confidenceScore * 100), score)
})

test_that("both-methods run: the simulator's data island carries the published GG curve", {
  sim <- pricing_simulator_data(BOTH$simulator)
  expect_equal(sim$price_range, c(60, 80, 100, 120, 140))
  expect_equal(sim$demand_curve, REF_GG$smooth, tolerance = 1e-5)
  expect_equal(sim$optimal_price, REF_GG$opt)
})

test_that("both-methods run: the rendered Pricing tab shows the workbook's numbers", {
  txt <- pricing_render_tab(BOTH$island)
  for (v in REF_VW) expect_true(grepl(sprintf("R%.2f", v), txt, fixed = TRUE), info = sprintf("R%.2f", v))
  expect_true(grepl(sprintf("Recommended price R%.2f", ref_psych(REF_GG$opt)), txt, fixed = TRUE))
  expect_true(grepl(sprintf("Revenue is highest at R%.2f, where %.1f%% would buy",
                            REF_GG$opt, 100 * REF_GG$smooth[which(c(60, 80, 100, 120, 140) == REF_GG$opt)]),
                    txt, fixed = TRUE))
  for (i in seq_along(gg_cols)) {
    expect_true(grepl(sprintf("%.1f%%", 100 * REF_GG$raw[i]), txt, fixed = TRUE), info = gg_cols[i])
  }
  expect_true(grepl(sprintf("%d after validation", sum(keep)), txt, fixed = TRUE))
})

# ------------------------------------------------------------------------------
# Monadic (Karoo_Pricing_Config_Monadic.xlsx): scale intent, 4+ = would buy
# ------------------------------------------------------------------------------
MON <- pricing_pipeline_run("Karoo_Pricing_Config_Monadic.xlsx", edits = FAST)

REF_MON <- local({
  d <- KAROO[is.finite(KAROO$Weight) & KAROO$Weight > 0 & !is.na(KAROO$MON_Price) &
               !is.na(KAROO$MON_Intent), ]
  d$buy <- as.numeric(d$MON_Intent >= 4)
  d$w1 <- d$Weight / mean(d$Weight)
  g <- suppressWarnings(glm(buy ~ MON_Price, family = binomial, data = d, weights = w1))
  grid <- seq(min(d$MON_Price), max(d$MON_Price), length.out = 100)
  pr <- plogis(coef(g)[1] + coef(g)[2] * grid)
  cells <- vapply(split(d, d$MON_Price), function(s) sum(s$Weight * s$buy) / sum(s$Weight), numeric(1))
  list(g = g, n = nrow(d), opt = grid[which.max(grid * pr)],
       opt_profit = grid[which.max((grid - 38) * pr)], cells = cells)
})

test_that("monadic run: model fit and optima on the sheets equal glm", {
  expect_equal(MON$status, "PASS", info = paste(tail(MON$log, 30), collapse = "\n"))
  ms <- pricing_kv(MON$workbook, "Mon_Model_Summary")
  expect_equal(num(ms["Observations"]), REF_MON$n)
  expect_equal(num(ms["AIC"]), round(AIC(REF_MON$g), 1))
  expect_equal(num(ms["Residual Deviance"]), round(REF_MON$g$deviance, 2))
  expect_equal(num(ms["Pseudo R-squared"]),
               round(1 - REF_MON$g$deviance / REF_MON$g$null.deviance, 4))
  op <- pricing_sheet(MON$workbook, "Mon_Optimal_Price", colNames = FALSE)
  expect_equal(num(op$X2[which(op$X1 == "Revenue-Maximizing Price")]), REF_MON$opt, tolerance = 1e-9)
  expect_equal(num(op$X2[which(op$X1 == "Profit-Maximizing Price")]), REF_MON$opt_profit, tolerance = 1e-9)
  ob <- pricing_sheet(MON$workbook, "Mon_Observed_Data")
  expect_equal(ob$observed_intent, unname(REF_MON$cells), tolerance = 1e-9)
})

test_that("monadic run: island, stats pack and Pricing tab carry the sheet's numbers", {
  isl <- jsonlite::fromJSON(MON$island)
  expect_equal(isl$monadic$optimalPrice, REF_MON$opt, tolerance = 1e-5)
  expect_equal(isl$monadic$cellIntentPct, unname(REF_MON$cells) * 100, tolerance = 1e-4)
  expect_equal(isl$monadic$pValue, summary(REF_MON$g)$coefficients[2, 4], tolerance = 1e-6)
  sp <- pricing_kv(MON$stats_pack, "Assumptions")
  expect_equal(num(sp["Mon: optimal_price"]), round(REF_MON$opt, 2))
  txt <- pricing_render_tab(MON$island)
  expect_true(grepl(sprintf("R%.2f", REF_MON$opt), txt, fixed = TRUE))
})

# ------------------------------------------------------------------------------
# Stop-early ladders
# ------------------------------------------------------------------------------
test_that("stop-early ladder without imputation refuses and writes no workbook", {
  se <- pricing_pipeline_run("Karoo_Pricing_Config_StopEarly.xlsx", edits = FAST)
  expect_equal(se$status, "REFUSED")
  expect_true(any(grepl("DATA_GG_UNEQUAL_BASES", se$log)))
  expect_false(file.exists(se$workbook))
})

test_that("stop-early ladder with NO_AFTER_STOP equals the hand-imputed ladder", {
  sei <- pricing_pipeline_run("Karoo_Pricing_Config_StopEarly_Imputed.xlsx", edits = FAST)
  expect_equal(sei$status, "PASS", info = paste(tail(sei$log, 30), collapse = "\n"))
  cols <- c("GGS_R60", "GGS_R80", "GGS_R100", "GGS_R120", "GGS_R140")
  m <- as.matrix(KAROO[, cols])
  # A gap is explained when an earlier rung already said No; then it is a No.
  # Any other gap is unexplained and that respondent leaves.
  unexplained <- apply(m, 1, function(r) {
    na <- which(is.na(r)); if (!length(na)) return(FALSE)
    first_no <- which(!is.na(r) & r == 0)[1]
    is.na(first_no) || any(na < first_no)
  })
  m2 <- m[!unexplained, , drop = FALSE]
  m2[is.na(m2)] <- 0
  w <- KAROO$Weight[!unexplained]
  raw <- colSums(m2 * w) / sum(w)
  sm <- -isoreg(c(60, 80, 100, 120, 140), -raw)$yf
  dc <- pricing_sheet(sei$workbook, "GG_Demand_Curve")
  expect_equal(dc$n_respondents, rep(nrow(m2), 5))
  expect_equal(dc$purchase_intent_raw, unname(raw), tolerance = 1e-9)
  expect_equal(dc$purchase_intent, sm, tolerance = 1e-9)
  opt <- pricing_kv(sei$workbook, "GG_Optimal_Revenue")
  expect_equal(num(opt["Revenue-Maximizing Price"]), c(60, 80, 100, 120, 140)[which.max(c(60, 80, 100, 120, 140) * sm)])
})
