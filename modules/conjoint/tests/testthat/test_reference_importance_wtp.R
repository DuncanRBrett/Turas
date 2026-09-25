# ==============================================================================
# CONJOINT - REFERENCE GATE: IMPORTANCE AND WILLINGNESS TO PAY
# ==============================================================================

source(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint", "tests", "testthat",
                 "helper_reference_mnl.R"), local = TRUE)

.imp_cfg <- function() {
  cfg <- list(attributes = data.frame(AttributeName = c("Brand", "Price"), NumLevels = c(3, 3),
                                      LevelNames = c("A,B,C", "$10,$20,$30"),
                                      stringsAsFactors = FALSE),
              confidence_level = 0.95)
  cfg$attributes$levels_list <- list(c("A", "B", "C"), c("$10", "$20", "$30"))
  cfg
}

test_that("aggregate importance is each attribute's range over the sum of ranges", {
  # Brand (-0.5, 0.2, 0.3): range 0.8. Price (0.6, 0, -0.6): range 1.2.
  # Total 2.0 -> Brand 40%, Price 60%.
  u <- data.frame(Attribute = rep(c("Brand", "Price"), each = 3),
                  Level = c("A", "B", "C", "$10", "$20", "$30"),
                  Utility = c(-0.5, 0.2, 0.3, 0.6, 0, -0.6), stringsAsFactors = FALSE)
  imp <- calculate_attribute_importance(u, .imp_cfg(), verbose = FALSE)
  expect_equal(imp$Importance[match(c("Brand", "Price"), imp$Attribute)], c(40, 60))
})

test_that("HB importance is each respondent's importance, then averaged", {
  # R1: Brand (0, 1, 0) range 1; Price (0, -2, -1) range 2 -> 33.333 / 66.667
  # R2: Brand (0, -1, 2) range 3; Price (0, 0.5, -0.5) range 1 -> 75 / 25
  # Mean: Brand 54.1667, Price 45.8333.
  # (Importance of the MEAN part-worths would differ: Brand (0, 0, 1) range 1,
  #  Price (0, -0.75, -0.75) range 0.75 -> 57.14 / 42.86.)
  betas <- rbind(R1 = c(1, 0, -2, -1), R2 = c(-1, 2, 0.5, -0.5))
  colnames(betas) <- c("Brand_B", "Brand_C", "Price_$20", "Price_$30")
  hb <- list(individual_betas = betas, col_names = colnames(betas))
  imp <- calculate_attribute_importance_hb(hb, .imp_cfg(), verbose = FALSE)
  expect_equal(imp$Importance[match(c("Brand", "Price"), imp$Attribute)],
               c(54.1667, 45.8333), tolerance = 1e-4)
  ri <- attr(imp, "respondent_importance")
  expect_equal(unname(ri["R1", ]), c(100 / 3, 200 / 3), tolerance = 1e-9)
})

# ------------------------------------------------------------------------------
# WTP. With price levels x_k and contrasts b_k (b_1 = 0), the price slope is
# the least-squares line through the part-worths:
#   s = sum_k c_k b_k,  c_k = (x_k - xbar) / sum_j (x_j - xbar)^2
# WTP of level l of another attribute = -b_l / s. Its SE by the delta method,
# from the model's covariance V of all the contrasts:
#   Var(WTP) = Var(b_l) / s^2 + b_l^2 Var(s) / s^4 - 2 b_l Cov(b_l, s) / s^3
#   Var(s) = c' V_pp c,  Cov(b_l, s) = V_lp c
# Before the fix, Var(s) came from the residuals of lm(part-worth ~ price):
# that measures how far price departs from a straight line, not how well the
# slope is estimated, and it is exactly 0 when the part-worths are linear.
# ------------------------------------------------------------------------------

test_that("WTP and its SE equal the delta method on the model's covariance", {
  skip_if_not(requireNamespace("survival", quietly = TRUE), "survival not installed")
  s <- generate_synthetic_cbc(n_respondents = 200, n_tasks = 8, n_alts = 3, seed = 21)
  m <- estimate_with_clogit(s$data, s$config, verbose = FALSE)
  ref <- cj_ref_mnl(s$data, s$attributes, "task_id")
  cfg <- s$config
  cfg$zero_center_utilities <- TRUE
  cfg$wtp_price_attribute <- "Price"
  u <- calculate_utilities(m, cfg, verbose = FALSE)
  w <- calculate_wtp(u, cfg, model_result = m, verbose = FALSE)$wtp_table

  x <- c(10, 20, 30); cc <- (x - mean(x)) / sum((x - mean(x))^2)
  pn <- c("Price$20", "Price$30")
  slope <- sum(cc[-1] * ref$coef[pn])
  V <- ref$vcov
  var_s <- drop(t(cc[-1]) %*% V[pn, pn] %*% cc[-1])
  for (lvl in c("Beta", "Gamma")) {
    nm <- paste0("Brand", lvl)
    b <- unname(ref$coef[nm])
    cov_bs <- drop(V[nm, pn] %*% cc[-1])
    se <- sqrt(V[nm, nm] / slope^2 + b^2 * var_s / slope^4 - 2 * b * cov_bs / slope^3)
    row <- w[w$Attribute == "Brand" & w$Level == lvl, ]
    expect_equal(row$WTP, -b / slope, tolerance = 1e-4, info = lvl)
    expect_equal(row$WTP_SE, unname(se), tolerance = 1e-4, info = lvl)
  }
})
