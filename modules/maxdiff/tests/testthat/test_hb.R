# ==============================================================================
# MAXDIFF TESTS - HIERARCHICAL BAYES (HB) MODULE
# ==============================================================================
# Tests for 07_hb.R: approximate HB, Stan data prep, convergence diagnostics
# ==============================================================================

# ==============================================================================
# HELPER: Build long_data suitable for HB functions
# ==============================================================================

build_hb_long_data <- function(n_resp = 10, n_items = 4, n_tasks = 4,
                               items_per_task = 3, seed = 42) {
  set.seed(seed)

  item_ids <- paste0("I", seq_len(n_items))
  true_utils <- rnorm(n_items, 0, 1)

  rows <- list()
  obs <- 0L

  for (r in seq_len(n_resp)) {
    for (t in seq_len(n_tasks)) {
      shown <- sample(item_ids, items_per_task)

      # Simulate best/worst from utilities
      utils_shown <- true_utils[match(shown, item_ids)]
      exp_u <- exp(utils_shown)
      best <- sample(shown, 1, prob = exp_u / sum(exp_u))
      remaining <- shown[shown != best]
      exp_neg <- exp(-true_utils[match(remaining, item_ids)])
      worst <- sample(remaining, 1, prob = exp_neg / sum(exp_neg))

      for (s in seq_along(shown)) {
        obs <- obs + 1L
        rows[[obs]] <- data.frame(
          resp_id = sprintf("R%03d", r),
          version = 1L,
          task = t,
          item_id = shown[s],
          is_best = as.integer(shown[s] == best),
          is_worst = as.integer(shown[s] == worst),
          weight = 1.0,
          obs_id = obs,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  do.call(rbind, rows)
}

build_hb_items <- function(n_items = 4) {
  data.frame(
    Item_ID = paste0("I", seq_len(n_items)),
    Item_Label = paste("Item", LETTERS[seq_len(n_items)]),
    Item_Group = "Test",
    Include = rep(1L, n_items),
    Anchor_Item = rep(0L, n_items),
    Display_Order = seq_len(n_items),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# fit_approximate_hb() tests
# ==============================================================================

test_that("fit_approximate_hb returns correct top-level structure", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  items <- build_hb_items(5)
  long_data <- build_hb_long_data(n_resp = 15, n_items = 5, n_tasks = 5)
  config <- list()

  result <- fit_approximate_hb(long_data, items, config, verbose = FALSE)

  expect_type(result, "list")
  expect_true("population_utilities" %in% names(result))
  expect_true("individual_utilities" %in% names(result))
  expect_true("diagnostics" %in% names(result))
  expect_true("model_fit" %in% names(result))
})

test_that("fit_approximate_hb population_utilities has correct columns", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  items <- build_hb_items(5)
  long_data <- build_hb_long_data(n_resp = 15, n_items = 5, n_tasks = 5)
  config <- list()

  result <- fit_approximate_hb(long_data, items, config, verbose = FALSE)
  pop <- result$population_utilities

  expect_true(is.data.frame(pop))
  expect_true("Item_ID" %in% names(pop))
  expect_true("Item_Label" %in% names(pop))
  expect_true("HB_Utility_Mean" %in% names(pop))
  expect_true("HB_Utility_SD" %in% names(pop))
  expect_true("Rank" %in% names(pop))

  # One row per included item

  expect_equal(nrow(pop), 5)
})

test_that("fit_approximate_hb individual_utilities has correct dimensions", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  n_resp <- 20
  n_items <- 5
  items <- build_hb_items(n_items)
  long_data <- build_hb_long_data(n_resp = n_resp, n_items = n_items, n_tasks = 5)
  config <- list()

  result <- fit_approximate_hb(long_data, items, config, verbose = FALSE)
  indiv <- result$individual_utilities

  expect_true(is.data.frame(indiv))
  # Should have one row per respondent

  expect_equal(nrow(indiv), n_resp)
  # Should have resp_id column + one column per item
  expect_true("resp_id" %in% names(indiv))
  for (item_id in items$Item_ID) {
    expect_true(item_id %in% names(indiv),
                info = sprintf("Missing column for item %s", item_id))
  }
})

test_that("fit_approximate_hb population utilities are approximately centered", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  items <- build_hb_items(6)
  long_data <- build_hb_long_data(n_resp = 50, n_items = 6, n_tasks = 6, seed = 99)
  config <- list()

  result <- fit_approximate_hb(long_data, items, config, verbose = FALSE)
  pop_means <- result$population_utilities$HB_Utility_Mean

  # BW scores are centered around 0 by construction
  # Mean of population means should be close to 0
  expect_true(abs(mean(pop_means)) < 1.0,
              info = sprintf("Mean of population utilities = %.3f, expected near 0",
                             mean(pop_means)))
})

test_that("fit_approximate_hb rankings are consistent with utility ordering", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  items <- build_hb_items(5)
  long_data <- build_hb_long_data(n_resp = 30, n_items = 5, n_tasks = 5)
  config <- list()

  result <- fit_approximate_hb(long_data, items, config, verbose = FALSE)
  pop <- result$population_utilities

  # Rank 1 should have the highest utility mean
  rank1_row <- pop[pop$Rank == 1, ]
  expect_equal(rank1_row$HB_Utility_Mean, max(pop$HB_Utility_Mean))

  # Rankings should cover 1..n_items (with possible ties)
  expect_true(min(pop$Rank) == 1)
  expect_true(max(pop$Rank) <= nrow(pop))
})

test_that("fit_approximate_hb diagnostics indicate empirical Bayes method", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  items <- build_hb_items(4)
  long_data <- build_hb_long_data(n_resp = 10, n_items = 4, n_tasks = 4)
  config <- list()

  result <- fit_approximate_hb(long_data, items, config, verbose = FALSE)

  expect_equal(result$diagnostics$method, "empirical_bayes")
  expect_true(is.numeric(result$diagnostics$shrinkage_mean))
  expect_true(result$diagnostics$shrinkage_mean >= 0)
  expect_true(result$diagnostics$shrinkage_mean <= 1)
})

test_that("fit_approximate_hb model_fit contains method metadata", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  items <- build_hb_items(4)
  long_data <- build_hb_long_data(n_resp = 10, n_items = 4, n_tasks = 4)
  config <- list()

  result <- fit_approximate_hb(long_data, items, config, verbose = FALSE)

  expect_equal(result$model_fit$method, "empirical_bayes_shrinkage")
  expect_equal(result$model_fit$n_respondents, 10)
  expect_equal(result$model_fit$n_items, 4)
})

test_that("fit_approximate_hb works with weighted data", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  items <- build_hb_items(4)
  long_data <- build_hb_long_data(n_resp = 20, n_items = 4, n_tasks = 4)

  # Assign varying weights per respondent
  set.seed(77)
  resp_weights <- data.frame(
    resp_id = unique(long_data$resp_id),
    weight = runif(20, 0.5, 2.0),
    stringsAsFactors = FALSE
  )
  long_data$weight <- NULL
  long_data <- merge(long_data, resp_weights, by = "resp_id")

  config <- list()
  result <- fit_approximate_hb(long_data, items, config, verbose = FALSE)

  # Should still return valid structure
  expect_type(result, "list")
  expect_true(is.data.frame(result$population_utilities))
  expect_true(is.data.frame(result$individual_utilities))
  expect_equal(nrow(result$individual_utilities), 20)
})

test_that("fit_approximate_hb handles single respondent", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  items <- build_hb_items(4)
  long_data <- build_hb_long_data(n_resp = 1, n_items = 4, n_tasks = 4)
  config <- list()

  # With a single respondent, variance is 0 or NA, but function should not error
  result <- tryCatch(
    fit_approximate_hb(long_data, items, config, verbose = FALSE),
    error = function(e) e
  )

  # Should either return a valid result or a graceful error, not crash R
  if (inherits(result, "error")) {
    # Acceptable: the function signals an error for degenerate input
    expect_true(TRUE)
  } else {
    expect_type(result, "list")
    expect_true("population_utilities" %in% names(result))
    expect_equal(nrow(result$individual_utilities), 1)
  }
})

test_that("fit_approximate_hb handles 2 items only", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  items <- build_hb_items(2)
  long_data <- build_hb_long_data(n_resp = 10, n_items = 2,
                                  n_tasks = 4, items_per_task = 2)
  config <- list()

  result <- tryCatch(
    fit_approximate_hb(long_data, items, config, verbose = FALSE),
    error = function(e) e
  )

  if (inherits(result, "error")) {
    # Acceptable for minimal item count
    expect_true(TRUE)
  } else {
    expect_type(result, "list")
    pop <- result$population_utilities
    expect_equal(nrow(pop), 2)
    # With 2 items, ranks should be 1 and 2
    expect_true(all(sort(pop$Rank) == c(1, 2)))
  }
})

test_that("fit_approximate_hb HB_Utility_SD values are non-negative", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  items <- build_hb_items(5)
  long_data <- build_hb_long_data(n_resp = 25, n_items = 5, n_tasks = 5)
  config <- list()

  result <- fit_approximate_hb(long_data, items, config, verbose = FALSE)
  pop <- result$population_utilities

  expect_true(all(pop$HB_Utility_SD >= 0 | is.na(pop$HB_Utility_SD)))
})

test_that("fit_approximate_hb Q5 and Q95 bracket the mean", {
  skip_if(!exists("fit_approximate_hb", mode = "function"))

  items <- build_hb_items(5)
  long_data <- build_hb_long_data(n_resp = 25, n_items = 5, n_tasks = 5)
  config <- list()

  result <- fit_approximate_hb(long_data, items, config, verbose = FALSE)
  pop <- result$population_utilities

  # Q5 should be less than or equal to Mean, Q95 should be greater than or equal
  for (i in seq_len(nrow(pop))) {
    if (!is.na(pop$HB_Utility_Q5[i]) && !is.na(pop$HB_Utility_Q95[i])) {
      expect_true(pop$HB_Utility_Q5[i] <= pop$HB_Utility_Mean[i],
                  info = sprintf("Item %s: Q5 (%.3f) > Mean (%.3f)",
                                 pop$Item_ID[i], pop$HB_Utility_Q5[i],
                                 pop$HB_Utility_Mean[i]))
      expect_true(pop$HB_Utility_Q95[i] >= pop$HB_Utility_Mean[i],
                  info = sprintf("Item %s: Q95 (%.3f) < Mean (%.3f)",
                                 pop$Item_ID[i], pop$HB_Utility_Q95[i],
                                 pop$HB_Utility_Mean[i]))
    }
  }
})


# ==============================================================================
# prepare_stan_data() tests
# ==============================================================================

test_that("prepare_stan_data returns correct structure", {
  skip_if(!exists("prepare_stan_data", mode = "function"))

  n_resp <- 10
  n_items <- 4
  items <- build_hb_items(n_items)
  long_data <- build_hb_long_data(n_resp = n_resp, n_items = n_items, n_tasks = 4)

  result <- prepare_stan_data(long_data, items)

  expect_type(result, "list")
  expect_true("N" %in% names(result))
  expect_true("R" %in% names(result))
  expect_true("J" %in% names(result))
  expect_true("K" %in% names(result))
  expect_true("resp" %in% names(result))
  expect_true("choice" %in% names(result))
  expect_true("shown" %in% names(result))
  expect_true("is_best" %in% names(result))
  expect_true("anchor_item" %in% names(result))
  expect_true("item_ids" %in% names(result))
  expect_true("resp_ids" %in% names(result))
})

test_that("prepare_stan_data computes correct respondent and item counts", {
  skip_if(!exists("prepare_stan_data", mode = "function"))

  n_resp <- 8
  n_items <- 5
  items <- build_hb_items(n_items)
  long_data <- build_hb_long_data(n_resp = n_resp, n_items = n_items, n_tasks = 3)

  result <- prepare_stan_data(long_data, items)

  expect_equal(result$R, n_resp)
  expect_equal(result$J, n_items)
  expect_equal(length(result$item_ids), n_items)
  expect_equal(length(result$resp_ids), n_resp)
})

test_that("prepare_stan_data respects Include flag in items", {
  skip_if(!exists("prepare_stan_data", mode = "function"))

  items <- build_hb_items(5)
  # Exclude item I3
  items$Include[3] <- 0

  long_data <- build_hb_long_data(n_resp = 10, n_items = 5, n_tasks = 4)

  result <- prepare_stan_data(long_data, items)

  # J should be 4 (5 items minus 1 excluded)
  expect_equal(result$J, 4)
  expect_false("I3" %in% result$item_ids)
})

test_that("prepare_stan_data arrays have consistent dimensions", {
  skip_if(!exists("prepare_stan_data", mode = "function"))

  items <- build_hb_items(4)
  long_data <- build_hb_long_data(n_resp = 10, n_items = 4,
                                  n_tasks = 4, items_per_task = 3)

  result <- prepare_stan_data(long_data, items)

  # All observation-level arrays should have length N
  expect_equal(length(result$resp), result$N)
  expect_equal(length(result$choice), result$N)
  expect_equal(length(result$is_best), result$N)
  expect_equal(nrow(result$shown), result$N)
  expect_equal(ncol(result$shown), result$K)

  # is_best should be 0 or 1
  expect_true(all(result$is_best %in% c(0L, 1L)))

  # resp indices should be in 1..R
  expect_true(all(result$resp >= 1 & result$resp <= result$R))
})


# ==============================================================================
# check_cmdstanr_availability() tests
# ==============================================================================

test_that("check_cmdstanr_availability returns correct structure", {
  skip_if(!exists("check_cmdstanr_availability", mode = "function"))

  result <- check_cmdstanr_availability(verbose = FALSE)

  expect_type(result, "list")
  expect_true("available" %in% names(result))
  expect_true("package_installed" %in% names(result))
  expect_true("cmdstan_installed" %in% names(result))
  expect_true("cmdstan_path" %in% names(result))
  expect_true("cmdstan_version" %in% names(result))
  expect_true("install_instructions" %in% names(result))

  expect_type(result$available, "logical")
  expect_type(result$package_installed, "logical")
})

test_that("check_cmdstanr_availability returns FALSE when cmdstanr not installed", {
  skip_if(!exists("check_cmdstanr_availability", mode = "function"))
  skip_if(requireNamespace("cmdstanr", quietly = TRUE),
          "cmdstanr is installed, cannot test unavailable path")

  result <- check_cmdstanr_availability(verbose = FALSE)

  expect_false(result$available)
  expect_false(result$package_installed)
  expect_false(result$cmdstan_installed)
  expect_true(length(result$install_instructions) > 0)
})


# ==============================================================================
# check_hb_convergence_auto() tests
# ==============================================================================

test_that("check_hb_convergence_auto returns correct default structure", {
  skip_if(!exists("check_hb_convergence_auto", mode = "function"))

  # Create a mock fit object that will fail on $summary()
  # to test the NULL/error path
  mock_fit <- list(
    summary = function() stop("no summary")
  )

  result <- check_hb_convergence_auto(mock_fit, verbose = FALSE)

  expect_type(result, "list")
  expect_true("converged" %in% names(result))
  expect_true("rhat_max" %in% names(result))
  expect_true("rhat_issues" %in% names(result))
  expect_true("ess_min" %in% names(result))
  expect_true("ess_issues" %in% names(result))
  expect_true("n_divergences" %in% names(result))
  expect_true("n_max_treedepth" %in% names(result))
  expect_true("recommendations" %in% names(result))
  expect_true("quality_score" %in% names(result))
})

test_that("check_hb_convergence_auto handles NULL summary gracefully", {
  skip_if(!exists("check_hb_convergence_auto", mode = "function"))

  # Mock fit where summary() throws an error
  mock_fit <- list(
    summary = function() stop("model not fitted")
  )

  result <- check_hb_convergence_auto(mock_fit, verbose = FALSE)

  # Should return a diagnostics list (graceful handling)
  expect_true(is.list(result))
  expect_true("quality_score" %in% names(result))
  expect_true("converged" %in% names(result))
})

test_that("check_hb_convergence_auto scores well-converged model highly", {
  skip_if(!exists("check_hb_convergence_auto", mode = "function"))

  # Mock a well-converged fit object
  mock_summary <- data.frame(
    variable = c("mu[1]", "mu[2]", "mu[3]"),
    mean = c(0.5, -0.3, 0.1),
    sd = c(0.1, 0.08, 0.12),
    q5 = c(0.3, -0.45, -0.1),
    q95 = c(0.7, -0.15, 0.3),
    rhat = c(1.001, 1.002, 1.000),
    ess_bulk = c(2000, 1800, 2200),
    stringsAsFactors = FALSE
  )

  mock_fit <- list(
    summary = function() mock_summary,
    sampler_diagnostics = function() {
      matrix(c(rep(0, 100), rep(5, 100)),
             ncol = 2,
             dimnames = list(NULL, c("divergent__", "treedepth__")))
    }
  )

  result <- check_hb_convergence_auto(mock_fit, verbose = FALSE)

  expect_true(result$converged)
  expect_true(result$quality_score >= 90)
  expect_equal(result$n_divergences, 0)
  expect_equal(length(result$rhat_issues), 0)
})

test_that("check_hb_convergence_auto detects high R-hat", {
  skip_if(!exists("check_hb_convergence_auto", mode = "function"))

  # Mock a poorly-converged fit with high R-hat
  mock_summary <- data.frame(
    variable = c("mu[1]", "mu[2]"),
    mean = c(0.5, -0.3),
    sd = c(0.1, 0.08),
    q5 = c(0.3, -0.45),
    q95 = c(0.7, -0.15),
    rhat = c(1.15, 1.08),
    ess_bulk = c(2000, 1800),
    stringsAsFactors = FALSE
  )

  mock_fit <- list(
    summary = function() mock_summary,
    sampler_diagnostics = function() {
      matrix(c(rep(0, 100), rep(5, 100)),
             ncol = 2,
             dimnames = list(NULL, c("divergent__", "treedepth__")))
    }
  )

  result <- check_hb_convergence_auto(mock_fit, verbose = FALSE)

  # R-hat > 1.10 should mark as not converged
  expect_false(result$converged)
  expect_true(result$rhat_max > 1.10)
  expect_true(length(result$rhat_issues) > 0)
  expect_true(result$quality_score < 70)
})


# ==============================================================================
# summarize_hb_convergence() tests
# ==============================================================================

test_that("summarize_hb_convergence returns a summary string", {
  skip_if(!exists("summarize_hb_convergence", mode = "function"))

  diag <- list(
    converged = TRUE,
    quality_score = 95,
    rhat_max = 1.002,
    ess_min = 1500,
    n_divergences = 0
  )

  result <- summarize_hb_convergence(diag)

  expect_type(result, "character")
  expect_true(grepl("OK", result))
  expect_true(grepl("95", result))
})

test_that("summarize_hb_convergence shows FAIL for non-converged", {
  skip_if(!exists("summarize_hb_convergence", mode = "function"))

  diag <- list(
    converged = FALSE,
    quality_score = 30,
    rhat_max = 1.2,
    ess_min = 50,
    n_divergences = 15
  )

  result <- summarize_hb_convergence(diag)

  expect_type(result, "character")
  expect_true(grepl("FAIL", result))
})


# ==============================================================================
# get_recommended_hb_settings() tests
# ==============================================================================

test_that("get_recommended_hb_settings returns valid defaults", {
  skip_if(!exists("get_recommended_hb_settings", mode = "function"))

  result <- get_recommended_hb_settings(
    n_respondents = 100,
    n_items = 10,
    n_tasks_per_resp = 12
  )

  expect_type(result, "list")
  expect_true(result$chains >= 1)
  expect_true(result$warmup >= 100)
  expect_true(result$iterations >= result$warmup)
  expect_true(result$adapt_delta > 0 && result$adapt_delta < 1)
  expect_true(result$max_treedepth >= 1)
  expect_true(length(result$notes) > 0)
})

test_that("get_recommended_hb_settings increases iterations for large studies", {
  skip_if(!exists("get_recommended_hb_settings", mode = "function"))

  small <- get_recommended_hb_settings(50, 8, 12)
  large <- get_recommended_hb_settings(500, 25, 12)

  # Large study should have more iterations and/or higher adapt_delta
  expect_true(large$iterations >= small$iterations ||
              large$adapt_delta >= small$adapt_delta)
})
