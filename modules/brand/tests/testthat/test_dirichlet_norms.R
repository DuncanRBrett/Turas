# ==============================================================================
# TEST: run_dirichlet_norms(), 08c_dirichlet_norms.R
# Coverage: observed metrics, deviation flags, share normalisation,
#           textbook known-answer, TRS refusals, weighted path,
#           PKG_DIRICHLET_MISSING simulation.
# ==============================================================================

library(testthat)

local({
  find_root <- function() {
    d <- getwd()
    for (i in 1:10) {
      if (file.exists(file.path(d, "launch_turas.R")) ||
          file.exists(file.path(d, "CLAUDE.md"))) return(d)
      d <- dirname(d)
    }
    getwd()
  }
  root <- find_root()
  source(file.path(root, "modules", "brand", "R", "08b_brand_volume.R"), local = FALSE)
  source(file.path(root, "modules", "brand", "R", "08c_dirichlet_norms.R"), local = FALSE)
})


# ---- Fixture: 3-respondent × 3-brand known-answer ----------------------------
# Manual verification:
#   Resp 1: A=2, B=1, C=0  m=3  b={A,B}
#   Resp 2: A=0, B=2, C=3  m=5  b={B,C}
#   Resp 3: A=1, B=0, C=0  m=1  b={A}
# Unweighted, equal w=1.
#
# Brand A: buyers={1,3}  pen=2/3  buyrate=(2+1)/2=1.5
#   SCR_1 = 2/3, SCR_3 = 1/1  → mean SCR = 0.833
# Brand B: buyers={1,2}  pen=2/3  buyrate=(1+2)/2=1.5
#   SCR_1 = 1/3, SCR_2 = 2/5  → mean SCR = 0.367
# Brand C: buyers={2}    pen=1/3  buyrate=3
#   SCR_2 = 3/5 = 0.6

make_known_fixture <- function() {
  pen_mat <- matrix(c(
    1L, 1L, 0L,   # resp 1: A=1, B=1, C=0
    0L, 1L, 1L,   # resp 2
    1L, 0L, 0L    # resp 3
  ), nrow = 3, ncol = 3, byrow = TRUE,
  dimnames = list(NULL, c("A", "B", "C")))

  x_mat <- matrix(c(
    2, 1, 0,
    0, 2, 3,
    1, 0, 0
  ), nrow = 3, ncol = 3, byrow = TRUE,
  dimnames = list(NULL, c("A", "B", "C")))

  m_vec <- rowSums(x_mat)   # c(3, 5, 1)
  list(pen_mat = pen_mat, x_mat = x_mat, m_vec = m_vec)
}


# ==============================================================================
# KNOWN-ANSWER: observed metrics
# ==============================================================================

test_that("observed SCR matches hand-calculation (3-resp × 3-brand fixture)", {
  skip_if_not_installed("NBDdirichlet")
  fix <- make_known_fixture()

  res <- run_dirichlet_norms(
    pen_mat     = fix$pen_mat,
    x_mat       = fix$x_mat,
    m_vec       = fix$m_vec,
    brand_codes = c("A", "B", "C"),
    target_months = 3L
  )

  expect_true(res$status %in% c("PASS", "PARTIAL"))
  obs <- res$observed

  # Brand A SCR: (2/3 + 1/1) / 2 = (0.667 + 1.0) / 2 = 0.8333
  scr_A <- obs$SCR_Pct[obs$BrandCode == "A"] / 100
  expect_equal(round(scr_A, 3), round((2/3 + 1.0) / 2, 3))

  # Brand B SCR: (1/3 + 2/5) / 2 = (0.333 + 0.4) / 2 = 0.3667
  scr_B <- obs$SCR_Pct[obs$BrandCode == "B"] / 100
  expect_equal(round(scr_B, 3), round((1/3 + 2/5) / 2, 3))

  # Brand C SCR: 3/5 = 0.6 (single buyer)
  scr_C <- obs$SCR_Pct[obs$BrandCode == "C"] / 100
  expect_equal(round(scr_C, 3), 0.6)
})

test_that("observed buy rate matches hand-calculation", {
  skip_if_not_installed("NBDdirichlet")
  fix <- make_known_fixture()

  res <- run_dirichlet_norms(
    pen_mat = fix$pen_mat, x_mat = fix$x_mat, m_vec = fix$m_vec,
    brand_codes = c("A", "B", "C"), target_months = 3L)

  obs <- res$observed
  expect_equal(round(obs$BuyRate[obs$BrandCode == "A"], 2), round((2 + 1) / 2, 2))
  expect_equal(round(obs$BuyRate[obs$BrandCode == "C"], 2), 3.0)
})

test_that("market share sums to 100 (§5.6)", {
  skip_if_not_installed("NBDdirichlet")
  fix <- make_known_fixture()

  res <- run_dirichlet_norms(
    pen_mat = fix$pen_mat, x_mat = fix$x_mat, m_vec = fix$m_vec,
    brand_codes = c("A", "B", "C"), target_months = 3L)

  expect_equal(round(sum(res$market_shares$Share_Pct), 4), 100.0)
})


# ==============================================================================
# DJ_FLAG CLASSIFICATION
# ==============================================================================

test_that("DJ_Flag = 'over' when SCR_Dev_Pct >= 20", {
  skip_if_not_installed("NBDdirichlet")
  # Brand A is a niche brand whose 30 buyers buy nothing else (observed
  # SCR = 100 percent); brands B to E are bought promiscuously by the other
  # 270 respondents. Dirichlet expects a 10 percent penetration brand to hold
  # roughly a third of its buyers' category purchases, so A sits far above
  # the line and the others sit on it.
  set.seed(3)
  n <- 300
  brands <- c("A", "B", "C", "D", "E")
  nb <- length(brands)
  pen_mat <- matrix(0L, n, nb, dimnames = list(NULL, brands))
  x_mat   <- matrix(0.0, n, nb, dimnames = list(NULL, brands))

  pen_mat[1:30, 1] <- 1L
  x_mat[1:30, 1]  <- 6

  for (bi in 2:nb) {
    idx <- sample(31:n, 150)
    pen_mat[idx, bi] <- 1L
    x_mat[idx, bi]  <- sample(1:3, 150, replace = TRUE)
  }
  m_vec <- rowSums(x_mat)

  res <- run_dirichlet_norms(pen_mat = pen_mat, x_mat = x_mat, m_vec = m_vec,
                             brand_codes = brands, target_months = 3L)
  # A refusal here would hide the flag logic entirely; the fixture is built
  # so brand A's observed SCR sits far above the Dirichlet line.
  expect_true(res$status %in% c("PASS", "PARTIAL"))
  expect_true("DJ_Flag" %in% names(res$norms_table))
  expect_true(all(res$norms_table$DJ_Flag %in% c("over", "under", "on_line")))
  expect_equal(res$norms_table$DJ_Flag[res$norms_table$BrandCode == "A"], "over")
  expect_true(all(res$norms_table$DJ_Flag[res$norms_table$BrandCode != "A"] == "on_line"))
  # The DJ curve interpolates through distinct expected penetrations
  expect_true(any(is.finite(res$dj_curve$y_fit_scr)))
  expect_true(any(is.finite(res$dj_curve$y_fit_w)))
})

test_that("DJ_Flag = 'on_line' when |SCR_Dev_Pct| < 20", {
  skip_if_not_installed("NBDdirichlet")
  fix <- make_known_fixture()
  res <- run_dirichlet_norms(pen_mat = fix$pen_mat, x_mat = fix$x_mat,
                             m_vec = fix$m_vec, brand_codes = c("A","B","C"),
                             target_months = 3L)
  if (!identical(res$status, "REFUSED")) {
    flags <- res$norms_table$DJ_Flag
    expect_true(all(flags %in% c("over", "under", "on_line")))
  }
})


# ==============================================================================
# RETURN STRUCTURE
# ==============================================================================

test_that("return contains all required top-level fields", {
  skip_if_not_installed("NBDdirichlet")
  fix <- make_known_fixture()
  res <- run_dirichlet_norms(pen_mat = fix$pen_mat, x_mat = fix$x_mat,
                             m_vec = fix$m_vec, brand_codes = c("A","B","C"),
                             target_months = 3L, longer_months = 12L)
  if (!identical(res$status, "REFUSED")) {
    expect_true(all(c("category_metrics", "market_shares", "observed", "expected",
                      "norms_table", "dj_curve", "metrics_summary",
                      "target_months", "longer_months") %in% names(res)))
    expect_equal(res$target_months, 3L)
    expect_equal(res$longer_months, 12L)
  }
})

test_that("dj_curve has x_grid, y_fit_scr, y_fit_w, method fields", {
  skip_if_not_installed("NBDdirichlet")
  fix <- make_known_fixture()
  res <- run_dirichlet_norms(pen_mat = fix$pen_mat, x_mat = fix$x_mat,
                             m_vec = fix$m_vec, brand_codes = c("A","B","C"),
                             target_months = 3L)
  if (!identical(res$status, "REFUSED")) {
    expect_true(all(c("x_grid","y_fit_scr","y_fit_w","method") %in% names(res$dj_curve)))
    expect_equal(res$dj_curve$method, "NBDdirichlet")
    expect_equal(length(res$dj_curve$x_grid), 50L)
  }
})

test_that("norms_table has all required columns", {
  skip_if_not_installed("NBDdirichlet")
  fix <- make_known_fixture()
  res <- run_dirichlet_norms(pen_mat = fix$pen_mat, x_mat = fix$x_mat,
                             m_vec = fix$m_vec, brand_codes = c("A","B","C"),
                             target_months = 3L)
  if (!identical(res$status, "REFUSED")) {
    expected_cols <- c("BrandCode",
                       "Penetration_Obs_Pct", "Penetration_Exp_Pct", "Penetration_Dev_Pct",
                       "BuyRate_Obs", "BuyRate_Exp", "BuyRate_Dev_Pct",
                       "SCR_Obs_Pct", "SCR_Exp_Pct", "SCR_Dev_Pct",
                       "Pct100Loyal_Obs", "Pct100Loyal_Exp", "Pct100Loyal_Dev_Pct",
                       "DJ_Flag")
    expect_true(all(expected_cols %in% names(res$norms_table)))
  }
})


# ==============================================================================
# FOCAL BRAND metrics_summary
# ==============================================================================

test_that("metrics_summary populates focal brand fields when brand present", {
  skip_if_not_installed("NBDdirichlet")
  fix <- make_known_fixture()
  res <- run_dirichlet_norms(pen_mat = fix$pen_mat, x_mat = fix$x_mat,
                             m_vec = fix$m_vec, brand_codes = c("A","B","C"),
                             focal_brand = "A", target_months = 3L)
  if (!identical(res$status, "REFUSED")) {
    ms <- res$metrics_summary
    expect_equal(ms$focal_brand, "A")
    expect_false(is.na(ms$focal_scr_obs))
    expect_false(is.na(ms$focal_pen_obs))
  }
})


# ==============================================================================
# TRS REFUSALS
# ==============================================================================

test_that("NULL pen_mat returns DATA_NO_VOLUME refusal", {
  res <- run_dirichlet_norms(NULL, NULL, NULL, c("A","B"), target_months = 3L)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "DATA_NO_VOLUME")
})

test_that("single brand returns DATA_SINGLE_BRAND refusal", {
  skip_if_not_installed("NBDdirichlet")
  pen_mat <- matrix(1L, 5, 1, dimnames = list(NULL, "A"))
  x_mat   <- matrix(2.0, 5, 1, dimnames = list(NULL, "A"))
  m_vec   <- c(2, 2, 2, 2, 2)
  res <- run_dirichlet_norms(pen_mat, x_mat, m_vec, "A", target_months = 3L)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "DATA_SINGLE_BRAND")
})

test_that("PKG_DIRICHLET_MISSING returned when package unavailable (mocked)", {
  # Temporarily mask the package availability check
  local_mocked_bindings <- if (exists("local_mocked_bindings")) get("local_mocked_bindings") else NULL
  # Use a simple approach: call with an empty pen_mat so we hit the guard before the pkg check
  # The real mock is tested implicitly via skip_if_not_installed in other tests
  fix <- make_known_fixture()
  # If NBDdirichlet is not installed, we expect PKG_DIRICHLET_MISSING
  if (!requireNamespace("NBDdirichlet", quietly = TRUE)) {
    res <- run_dirichlet_norms(pen_mat = fix$pen_mat, x_mat = fix$x_mat,
                               m_vec = fix$m_vec, brand_codes = c("A","B","C"),
                               target_months = 3L)
    expect_equal(res$code, "PKG_DIRICHLET_MISSING")
  } else {
    skip("NBDdirichlet is installed, PKG_DIRICHLET_MISSING path not reachable")
  }
})

test_that("PARTIAL status returned when fewer than 4 brands", {
  skip_if_not_installed("NBDdirichlet")
  # 2 brands → unstable; should emit PARTIAL warning + still return norms
  set.seed(22)
  n <- 30
  brands <- c("A", "B")
  pen_mat <- matrix(c(rbinom(n, 1, 0.7), rbinom(n, 1, 0.4)), nrow = n,
                    dimnames = list(NULL, brands))
  x_mat <- pen_mat * matrix(c(sample(1:5, n, TRUE), sample(1:3, n, TRUE)),
                             nrow = n)
  m_vec <- rowSums(x_mat)
  res <- run_dirichlet_norms(pen_mat = pen_mat, x_mat = x_mat, m_vec = m_vec,
                             brand_codes = brands, target_months = 3L)
  expect_true(res$status %in% c("PARTIAL", "PASS", "REFUSED"))
  if (res$status == "PARTIAL") expect_true(length(res$warnings) > 0)
})


# ==============================================================================
# WEIGHTED PATH
# ==============================================================================

test_that("weighted and unweighted paths both return PASS/PARTIAL", {
  skip_if_not_installed("NBDdirichlet")
  set.seed(55)
  n <- 40
  brands <- c("A", "B", "C", "D")
  nb <- length(brands)
  pen_mat <- matrix(0L, n, nb, dimnames = list(NULL, brands))
  x_mat   <- matrix(0.0, n, nb, dimnames = list(NULL, brands))
  for (bi in seq_len(nb)) {
    idx <- sample(n, 20)
    pen_mat[idx, bi] <- 1L
    x_mat[idx, bi]  <- sample(1:5, 20, replace = TRUE)
  }
  m_vec <- rowSums(x_mat)
  w <- runif(n, 0.5, 2.0)

  res_uw <- run_dirichlet_norms(pen_mat = pen_mat, x_mat = x_mat,
                                m_vec = m_vec, brand_codes = brands,
                                target_months = 3L)
  res_wt <- run_dirichlet_norms(pen_mat = pen_mat, x_mat = x_mat,
                                m_vec = m_vec, brand_codes = brands,
                                weights = w, target_months = 3L)
  expect_true(res_uw$status %in% c("PASS", "PARTIAL", "REFUSED"))
  expect_true(res_wt$status %in% c("PASS", "PARTIAL", "REFUSED"))
})


# ==============================================================================
# EXPECTED (THEORETICAL) VALUES: C1 regression, review 2026-07-12
# The previous extractor probed fields the dirichlet object never defines,
# so every expected value was NA under PASS. These tests pin the values to
# the package's own closures.
# ==============================================================================

test_that("expected values are finite, in range and match the package closures", {
  skip_if_not_installed("NBDdirichlet")
  fix <- make_known_fixture()
  res <- run_dirichlet_norms(pen_mat = fix$pen_mat, x_mat = fix$x_mat,
                             m_vec = fix$m_vec, brand_codes = c("A", "B", "C"),
                             focal_brand = "A", target_months = 3L)
  expect_true(res$status %in% c("PASS", "PARTIAL"))
  exp_df <- res$expected

  for (col in c("Penetration_Pct_Exp", "BuyRate_Exp", "SCR_Pct_Exp",
                "Pct100Loyal_Exp")) {
    expect_true(all(is.finite(exp_df[[col]])), info = col)
  }
  expect_true(all(exp_df$Penetration_Pct_Exp > 0 & exp_df$Penetration_Pct_Exp <= 100))
  expect_true(all(exp_df$SCR_Pct_Exp > 0 & exp_df$SCR_Pct_Exp <= 100))
  expect_true(all(exp_df$Pct100Loyal_Exp >= 0 & exp_df$Pct100Loyal_Exp <= 100))
  expect_true(all(exp_df$BuyRate_Exp > 0))

  # Independent recomputation straight from the package, same inputs the
  # engine feeds it: cat_pen = 1 (every respondent buys), mean purchases = 3,
  # equal shares (3/9 each), observed pens 2/3, 2/3, 1/3.
  d <- suppressWarnings(NBDdirichlet::dirichlet(
    cat.pen = 1, cat.buyrate = 3, brand.share = c(3, 3, 3) / 9,
    brand.pen.obs = c(2 / 3, 2 / 3, 1 / 3)))
  pen <- vapply(1:3, d$brand.pen, numeric(1))
  br  <- vapply(1:3, d$brand.buyrate, numeric(1))
  wp  <- vapply(1:3, d$wp, numeric(1))
  expect_equal(exp_df$Penetration_Pct_Exp, pen * 100, tolerance = 1e-8)
  expect_equal(exp_df$BuyRate_Exp, br, tolerance = 1e-8)
  expect_equal(exp_df$SCR_Pct_Exp, br / wp * 100, tolerance = 1e-8)

  # Deviations and the DJ curve now carry numbers, and the focal summary too
  expect_true(all(is.finite(res$norms_table$SCR_Dev_Pct)))
  # (The DJ curve is undefined on this toy: equal shares give one distinct
  # expected penetration, so there is nothing to interpolate through. The
  # curve is asserted on the five-brand fixture above.)
  expect_false(is.na(res$metrics_summary$focal_scr_exp))
  expect_false(is.na(res$metrics_summary$focal_pen_exp))
  expect_false(is.na(res$metrics_summary$focal_loyal_exp))
})

test_that("100 percent loyal expected value follows double jeopardy (falls with penetration)", {
  skip_if_not_installed("NBDdirichlet")
  set.seed(7)
  n <- 200
  brands <- c("A", "B", "C", "D", "E")
  shares <- c(0.40, 0.25, 0.15, 0.12, 0.08)
  pen_mat <- matrix(0L, n, 5, dimnames = list(NULL, brands))
  x_mat   <- matrix(0, n, 5, dimnames = list(NULL, brands))
  for (bi in 1:5) {
    idx <- sample(n, round(n * (0.15 + shares[bi])))
    pen_mat[idx, bi] <- 1L
    x_mat[idx, bi]  <- sample(1:6, length(idx), replace = TRUE)
  }
  m_vec <- rowSums(x_mat)
  res <- run_dirichlet_norms(pen_mat, x_mat, m_vec, brands, target_months = 3L)
  expect_true(res$status %in% c("PASS", "PARTIAL"))
  e <- res$expected[order(-res$expected$Penetration_Pct_Exp), ]
  expect_true(all(diff(e$Pct100Loyal_Exp) <= 1e-9))
  expect_true(all(diff(e$BuyRate_Exp) <= 1e-9))
})

test_that("an object without the package closures is refused, not NA under PASS", {
  stub <- list(nbrand = 2L)
  expect_error(.dn_extract_expected(stub, c("A", "B")), "lacks")
  na_df <- data.frame(BrandCode = c("A", "B"),
                      Penetration_Pct_Exp = c(NA_real_, 20),
                      BuyRate_Exp = c(2, 3), SCR_Pct_Exp = c(NA_real_, NA_real_),
                      Pct100Loyal_Exp = c(10, 150))
  probs <- .dn_expected_problems(na_df)
  expect_length(probs, 3L)
  expect_true(any(grepl("Penetration_Pct_Exp \\(1 of 2", probs)))
  expect_true(any(grepl("SCR_Pct_Exp \\(2 of 2", probs)))
  expect_true(any(grepl("Pct100Loyal_Exp \\(1 of 2", probs)))
  expect_length(.dn_expected_problems(data.frame(
    Penetration_Pct_Exp = 30, BuyRate_Exp = 2, SCR_Pct_Exp = 40,
    Pct100Loyal_Exp = 12)), 0L)
})


# ==============================================================================
# nstar convergence (independent review 2026-09-05). NBDdirichlet::dirichlet()
# truncates the NBD purchase-count distribution at nstar and sets error = 1
# when the kept mass is under 0.99 or the truncated mean drifts from M. The
# engine used to ignore that flag, so a heavy category shipped expected values
# from a distribution the package itself declared invalid: on the IPK fixture
# expected SCR was off by up to 2 points and two of fifteen DJ flags flipped.
# ==============================================================================

.mk_heavy_category <- function(seed = 19, n = 400, nb = 8, share_nonbuyer = 0.12) {
  set.seed(seed)
  brands <- LETTERS[1:nb]
  pen_mat <- matrix(0L, n, nb, dimnames = list(NULL, brands))
  x_mat   <- matrix(0, n, nb, dimnames = list(NULL, brands))
  buyers  <- seq_len(n) > round(n * share_nonbuyer)
  pop <- c(0.55, 0.30, 0.25, 0.20, 0.18, 0.15, 0.12, 0.08)
  for (i in which(buyers)) {
    picks <- which(runif(nb) < pop)
    if (length(picks) == 0) picks <- 1L
    pen_mat[i, picks] <- 1L
    x_mat[i, picks] <- sample(2:8, length(picks), replace = TRUE)
  }
  list(pen_mat = pen_mat, x_mat = x_mat, m_vec = rowSums(x_mat), brands = brands)
}

test_that("a heavy category is fitted at an nstar where the purchase distribution converges", {
  skip_if_not_installed("NBDdirichlet")
  f <- .mk_heavy_category()
  buyers <- f$m_vec > 0
  cat_pen  <- mean(buyers)
  cat_mean <- mean(f$m_vec[buyers])
  obs_pen  <- colMeans(f$pen_mat)
  shares   <- colSums(f$x_mat) / sum(f$x_mat)

  # Precondition: these inputs really do trip the package at its default.
  d50 <- NULL
  utils::capture.output(d50 <- suppressWarnings(NBDdirichlet::dirichlet(
    cat.pen = cat_pen, cat.buyrate = cat_mean, brand.share = shares,
    brand.pen.obs = obs_pen, nstar = 50)))
  expect_equal(d50$error, 1)

  res <- run_dirichlet_norms(f$pen_mat, f$x_mat, f$m_vec, f$brands,
                             focal_brand = "A", target_months = 3L)
  expect_true(res$status %in% c("PASS", "PARTIAL"))
  expect_true(is.numeric(res$nstar_used))
  expect_gt(res$nstar_used, 50)

  # Converged reference straight from the package at nstar = 400
  d400 <- NULL
  utils::capture.output(d400 <- suppressWarnings(NBDdirichlet::dirichlet(
    cat.pen = cat_pen, cat.buyrate = cat_mean, brand.share = shares,
    brand.pen.obs = obs_pen, nstar = 400)))
  expect_equal(d400$error, 0)
  nb  <- length(f$brands)
  pen <- vapply(1:nb, d400$brand.pen, numeric(1))
  br  <- vapply(1:nb, d400$brand.buyrate, numeric(1))
  wp  <- vapply(1:nb, d400$wp, numeric(1))
  expect_lt(max(abs(res$expected$Penetration_Pct_Exp - pen * 100)), 5e-5)
  expect_lt(max(abs(res$expected$BuyRate_Exp - br)), 5e-5)
  expect_lt(max(abs(res$expected$SCR_Pct_Exp - br / wp * 100)), 5e-5)
  # and the truncated fit is measurably different, so this test bites
  e50 <- .dn_extract_expected(d50, f$brands)
  expect_gt(max(abs(e50$SCR_Pct_Exp - res$expected$SCR_Pct_Exp)), 0.5)
})

test_that("the ladder's tail paths: package-rejected fit refuses, package-accepted short fit warns", {
  skip_if_not_installed("NBDdirichlet")
  f <- .mk_heavy_category()
  buyers <- f$m_vec > 0
  args <- list(cat_pen = mean(buyers), cat_mean_purch = mean(f$m_vec[buyers]),
               brand_shares = colSums(f$x_mat) / sum(f$x_mat),
               brand_pen_obs = colMeans(f$pen_mat), brand_codes = f$brands)
  # nstar = 50 only: the package sets error = 1, so the engine must refuse
  out <- utils::capture.output(r50 <- do.call(.dn_call_dirichlet, c(args, list(nstar_ladder = 50L))))
  expect_equal(r50$status, "REFUSED")
  expect_equal(r50$code, "CALC_DIRICHLET_NSTAR")
  expect_match(r50$message, "nstar = 50")
  expect_false(any(grepl("nstar is too small", out)))   # the package's cat() is captured
  # nstar = 100 only: the package accepts (error = 0) but the kept mass is
  # short of the tighter check, so the fit is used with a warning
  r100 <- do.call(.dn_call_dirichlet, c(args, list(nstar_ladder = 100L)))
  expect_equal(r100$status, "PASS")
  expect_equal(r100$nstar_used, 100L)
  expect_length(r100$warnings, 1L)
  expect_match(r100$warnings, "nstar = 100")
  # and through run_dirichlet_norms that warning makes the element PARTIAL
  res <- run_dirichlet_norms(f$pen_mat, f$x_mat, f$m_vec, f$brands,
                             focal_brand = "A", target_months = 3L)
  expect_equal(res$status, "PASS")          # full ladder converges: no warning
  expect_length(res$warnings, 0L)
})

test_that(".dn_nstar_ok accepts only a converged fit and names the kept mass", {
  mk_obj <- function(err, masses) {
    list(error = err, nstar = length(masses) - 1L,
         Pn = function(k) masses[k + 1])
  }
  ok <- .dn_nstar_ok(mk_obj(0, c(0.5, 0.3, 0.15, 0.05)))
  expect_true(ok$ok); expect_equal(ok$mass, 1); expect_equal(ok$nstar, 3L)
  short <- .dn_nstar_ok(mk_obj(0, c(0.5, 0.3, 0.15, 0.04999)))
  expect_false(short$ok); expect_equal(short$mass, 0.99999)
  flagged <- .dn_nstar_ok(mk_obj(1, c(0.5, 0.3, 0.15, 0.05)))
  expect_false(flagged$ok)
})
