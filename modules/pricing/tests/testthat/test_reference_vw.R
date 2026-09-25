# ==============================================================================
# TURAS PRICING - VAN WESTENDORP REFERENCE CHECKS (robustness gate 1)
# ==============================================================================
#
# The four price points against two references that share no Turas code:
#   1. pricesensitivitymeter::psm_analysis / psm_analysis_weighted, called
#      directly in the test on the raw columns;
#   2. the textbook definition written out below (ref_vw_points), so the
#      check does not rest only on the package Turas itself wraps.
# Each is run through validate_pricing_data() first, exactly as the pipeline
# does, so the monotonicity behaviour (drop / fix / flag_only) is covered.
# ==============================================================================

quiet <- function(expr) { capture.output(r <- suppressWarnings(expr)); r }

ref_vw_cfg <- function(behavior = "drop", weight_var = NA_character_) {
  list(
    analysis_method = "van_westendorp", weight_var = weight_var, dk_codes = numeric(0),
    currency_symbol = "R",
    van_westendorp = list(col_too_cheap = "tc", col_cheap = "ch",
                          col_expensive = "ex", col_too_expensive = "te",
                          validate_monotonicity = TRUE, violation_threshold = 0.5,
                          calculate_confidence = FALSE),
    vw_monotonicity_behavior = behavior,
    validation = list(min_completeness = 0.8, min_sample = 5, price_min = 0, price_max = 10000)
  )
}

# Integer prices, 60 respondents, 8 of them intransitive in different ways
# (a tie, a reversed pair, a fully reversed row).
ref_vw_data <- function(seed = 11) {
  set.seed(seed)
  n <- 60
  base <- sample(40:80, n, replace = TRUE)
  d <- data.frame(id = 1:n,
                  tc = base - sample(15:25, n, replace = TRUE),
                  ch = base - sample(3:12, n, replace = TRUE),
                  ex = base + sample(3:12, n, replace = TRUE),
                  te = base + sample(15:30, n, replace = TRUE),
                  w = round(runif(n, 0.4, 2.2), 2))
  d$ch[1] <- d$tc[1]                       # tie: too cheap == cheap
  d$ex[2] <- d$ch[2]                       # tie: cheap == expensive
  d[3, c("ch", "ex")] <- d[3, c("ex", "ch")]  # cheap above expensive
  d[4, c("tc", "ch", "ex", "te")] <- rev(d[4, c("tc", "ch", "ex", "te")])  # fully reversed
  d$te[5] <- d$ex[5] - 1                   # too expensive below expensive
  d$tc[6] <- d$te[6] + 5                   # too cheap above everything
  d[7, c("tc", "ch")] <- d[7, c("ch", "tc")]
  d$ex[8] <- d$te[8]                       # tie at the top
  d
}

# ------------------------------------------------------------------------------
# The textbook definition, independent of the package:
#   price grid  = every price any respondent gave, sorted;
#   F_x(p)      = weighted share with answer x <= p, forced to 0 at or below
#                 the lowest answer and 1 at or above the highest (the
#                 package's convention, pinned here so the two can be compared);
#   too cheap   = 1 - F_tc,   not cheap = F_ch,
#   not exp.    = 1 - F_ex,   too exp.  = F_te,   cheap = 1 - F_ch, exp. = F_ex;
#   PMC = too cheap x not cheap, PME = too expensive x not expensive,
#   OPP = too cheap x too expensive, IDP = cheap x expensive,
#   each the LOWEST price where the difference changes sign, located by
#   linear interpolation between the two grid prices around it.
# ------------------------------------------------------------------------------
ref_vw_points <- function(tc, ch, ex, te, w = rep(1, length(tc))) {
  grid <- sort(unique(c(tc, ch, ex, te)))
  F <- function(x) {
    v <- vapply(grid, function(p) sum(w[x <= p]) / sum(w), numeric(1))
    v[grid >= max(x)] <- 1
    v[grid <= min(x)] <- 0
    v
  }
  too_cheap <- 1 - F(tc); not_cheap <- F(ch); cheap <- 1 - F(ch)
  expensive <- F(ex); not_expensive <- 1 - F(ex); too_expensive <- F(te)
  cross <- function(a, b) {
    dlt <- a - b
    s <- which(diff(sign(dlt)) != 0)
    if (length(s) == 0) return(NA_real_)
    xs <- vapply(s, function(i) {
      if (dlt[i + 1] == dlt[i]) return((grid[i] + grid[i + 1]) / 2)
      grid[i] - dlt[i] * (grid[i + 1] - grid[i]) / (dlt[i + 1] - dlt[i])
    }, numeric(1))
    min(xs)
  }
  c(PMC = cross(not_cheap, too_cheap), OPP = cross(too_expensive, too_cheap),
    IDP = cross(expensive, cheap), PME = cross(too_expensive, not_expensive))
}

strict_ok <- function(d) d$tc < d$ch & d$ch < d$ex & d$ex < d$te

turas_vw <- function(d, cfg) {
  v <- quiet(validate_pricing_data(d, cfg))
  r <- quiet(run_van_westendorp(v$clean_data, cfg, validation = v))
  list(points = unlist(r$price_points[c("PMC", "OPP", "IDP", "PME")]), r = r, v = v)
}

test_that("unweighted drop: price points equal psm_analysis and the textbook definition", {
  d <- ref_vw_data()
  t <- turas_vw(d, ref_vw_cfg("drop"))
  psm <- suppressWarnings(pricesensitivitymeter::psm_analysis(
    toocheap = d$tc, cheap = d$ch, expensive = d$ex, tooexpensive = d$te,
    validate = TRUE, interpolate = TRUE, interpolation_steps = 0.1))
  expect_equal(unname(t$points),
               c(psm$pricerange_lower, psm$opp, psm$idp, psm$pricerange_upper), tolerance = 1e-9)
  keep <- strict_ok(d)
  expect_equal(sum(!keep), 8L)
  ref <- ref_vw_points(d$tc[keep], d$ch[keep], d$ex[keep], d$te[keep])
  expect_equal(unname(t$points), unname(ref), tolerance = 1e-6)
  # The base on every sheet is the analysed base: 60 minus the 8 intransitive.
  expect_equal(t$r$diagnostics$n_analysed, 52L)
  expect_equal(t$r$diagnostics$n_violations_before_handling, 8L)
})

test_that("unweighted flag_only keeps the intransitive rows, as psm validate = FALSE does", {
  d <- ref_vw_data()
  t <- turas_vw(d, ref_vw_cfg("flag_only"))
  psm <- suppressWarnings(pricesensitivitymeter::psm_analysis(
    toocheap = d$tc, cheap = d$ch, expensive = d$ex, tooexpensive = d$te,
    validate = FALSE, interpolate = TRUE, interpolation_steps = 0.1))
  expect_equal(unname(t$points),
               c(psm$pricerange_lower, psm$opp, psm$idp, psm$pricerange_upper), tolerance = 1e-9)
  expect_equal(unname(t$points), unname(ref_vw_points(d$tc, d$ch, d$ex, d$te)), tolerance = 1e-6)
  expect_equal(t$r$diagnostics$n_analysed, 60L)
})

test_that("unweighted fix sorts each intransitive row; rows left tied are set aside", {
  d <- ref_vw_data()
  t <- turas_vw(d, ref_vw_cfg("fix"))
  s <- d
  bad <- !strict_ok(d)
  for (i in which(bad)) s[i, c("tc", "ch", "ex", "te")] <- sort(unlist(d[i, c("tc", "ch", "ex", "te")]))
  keep <- strict_ok(s)          # a sorted tie is still not strictly increasing
  ref <- ref_vw_points(s$tc[keep], s$ch[keep], s$ex[keep], s$te[keep])
  expect_equal(unname(t$points), unname(ref), tolerance = 1e-6)
  expect_equal(t$r$diagnostics$n_analysed, sum(keep))
})

test_that("weighted drop: equal to psm_analysis_weighted and to the weighted textbook ECDF", {
  d <- ref_vw_data()
  t <- turas_vw(d, ref_vw_cfg("drop", weight_var = "w"))
  keep <- strict_ok(d)
  k <- d[keep, ]
  design <- survey::svydesign(ids = ~1, weights = ~w,
                              data = data.frame(tc = k$tc, ch = k$ch, ex = k$ex, te = k$te, w = k$w))
  psm <- suppressWarnings(pricesensitivitymeter::psm_analysis_weighted(
    toocheap = "tc", cheap = "ch", expensive = "ex", tooexpensive = "te",
    design = design, validate = TRUE, interpolate = TRUE, interpolation_steps = 0.1))
  expect_equal(unname(t$points),
               c(psm$pricerange_lower, psm$opp, psm$idp, psm$pricerange_upper), tolerance = 1e-9)
  ref <- ref_vw_points(k$tc, k$ch, k$ex, k$te, k$w)
  expect_equal(unname(t$points), unname(ref), tolerance = 1e-6)
  # And the weight really moved them.
  un <- ref_vw_points(k$tc, k$ch, k$ex, k$te)
  expect_gt(max(abs(ref - un)), 0.1)
})

test_that("grossed weights give the same price points as the same weights at mean 1", {
  d <- ref_vw_data()
  d$w_gross <- d$w * 25000
  a <- turas_vw(d, ref_vw_cfg("drop", weight_var = "w"))
  b <- turas_vw(d, ref_vw_cfg("drop", weight_var = "w_gross"))
  expect_equal(a$points, b$points, tolerance = 1e-9)
})

test_that("the ranges on the sheet are built from the four points", {
  d <- ref_vw_data()
  r <- turas_vw(d, ref_vw_cfg("drop"))$r
  expect_equal(r$acceptable_range$width, r$price_points$PME - r$price_points$PMC)
  expect_equal(r$optimal_range$lower, r$price_points$OPP)
  expect_equal(r$optimal_range$upper, r$price_points$IDP)
})

test_that("NMS is refused before any price point is computed", {
  d <- ref_vw_data()
  d$pic <- 3
  cfg <- ref_vw_cfg("drop")
  cfg$van_westendorp$col_pi_cheap <- "pic"
  expect_error(quiet(validate_pricing_data(d, cfg)), class = "turas_refusal")
  err <- tryCatch(quiet(validate_pricing_data(d, cfg)), turas_refusal = function(e) e)
  expect_equal(err$code, "FEATURE_NMS_WITHDRAWN")
})
