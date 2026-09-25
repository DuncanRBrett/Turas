# ==============================================================================
# CONJOINT - REFERENCE GATE: BEST-WORST CONJOINT (sequential)
# ==============================================================================
# Recovery on a correctly specified simulation: best from exp(V) / sum exp(V),
# then worst from exp(-V) / sum exp(-V) over the alternatives left. The best
# model estimates b and the worst model -b, so (b_best - b_worst) / 2 must
# land within 3 of its reported SE of the truth. The reported SE treats the
# two models as independent, sqrt((se_b^2 + se_w^2) / 4); they share
# respondents and sets, so that SE is approximate (listed for the docs).
# ==============================================================================

test_that("sequential best-worst recovers known part-worths within 3 reported SEs", {
  skip_if_not_installed("mlogit")
  set.seed(31)
  attrs <- list(Brand = c("Alpha", "Beta", "Gamma"), Price = c("$10", "$20", "$30"))
  truth <- c(BrandBeta = 0.8, BrandGamma = -0.5, "Price$20" = -0.4, "Price$30" = -1.0)
  rows <- list()
  for (r in 1:250) for (t in 1:8) {
    al <- lapply(1:3, function(a) vapply(attrs, function(l) sample(l, 1), ""))
    v <- vapply(al, function(x) sum(truth[intersect(paste0(names(x), x), names(truth))]), numeric(1))
    best <- sample(1:3, 1, prob = exp(v) / sum(exp(v)))
    rest <- setdiff(1:3, best)
    worst <- rest[sample(length(rest), 1, prob = exp(-v[rest]) / sum(exp(-v[rest])))]
    for (a in 1:3) rows[[length(rows) + 1]] <- data.frame(
      resp_id = r, choice_set_id = (r - 1) * 8 + t, alt_id = a, best = as.integer(a == best),
      worst = as.integer(a == worst), Brand = al[[a]][["Brand"]], Price = al[[a]][["Price"]],
      stringsAsFactors = FALSE)
  }
  bws <- generate_bws_data(n_respondents = 2, n_tasks = 1, seed = 1)
  data_list <- list(data = do.call(rbind, rows), n_alternatives_per_set = 3)
  suppressWarnings(capture.output(
    model <- estimate_best_worst_model(data_list, bws$config, method = "sequential", verbose = FALSE),
    type = "output"))
  est <- model$coefficients[names(truth)]
  se <- model$std_errors[names(truth)]
  expect_false(anyNA(est))
  z <- (est - truth) / se
  expect_true(all(abs(z) < 3), info = paste(names(truth), round(z, 2), collapse = "; "))
})
