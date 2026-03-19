# ==============================================================================
# INTEGRATION TESTS: SIMULATOR CONFIDENCE INTERVALS
# ==============================================================================
#
# Tests predict_shares_with_ci() which bootstraps individual-level betas
# to produce market share confidence intervals.
#
# Coverage:
#   - CI computation with valid individual betas
#   - Lower < Share < Upper ordering
#   - SE > 0
#   - Fallback when no individual betas (returns NA CIs)
#   - Multiple products handled correctly
#
# ==============================================================================

# --- Locate project root and source module ----------------------------------
.find_turas_root <- function() {
  candidates <- c(
    getwd(),
    Sys.getenv("TURAS_ROOT", unset = ""),
    tryCatch(file.path(dirname(dirname(testthat::test_path())), "..", ".."),
             error = function(e) "")
  )
  for (cand in candidates) {
    if (nzchar(cand) && file.exists(file.path(cand, "modules", "conjoint", "R", "00_main.R"))) {
      return(normalizePath(cand))
    }
  }
  NULL
}

turas_root <- .find_turas_root()

if (is.null(turas_root)) {
  test_that("project root found (skip guard)", {
    skip("Cannot locate Turas project root")
  })
} else {

  old_wd <- setwd(turas_root)
  on.exit(setwd(old_wd), add = TRUE)

  source(file.path(turas_root, "modules", "conjoint", "R", "00_main.R"))

  # Load synthetic data generators
  fixture_path <- file.path(
    turas_root, "modules", "conjoint", "tests",
    "fixtures", "synthetic_data", "generate_conjoint_test_data.R"
  )
  if (file.exists(fixture_path)) source(fixture_path, local = TRUE)

  # --- Helper: generate synthetic individual betas and attribute_map ---------
  .make_synthetic_betas <- function(n_respondents = 50, seed = 42) {
    set.seed(seed)

    # Simulated parameter names matching dummy coding for 4 attributes:
    # Brand (3 levels, 2 dummies), Price (3 levels, 2 dummies),
    # Size (3 levels, 2 dummies), Color (2 levels, 1 dummy)
    col_names <- c(
      "Brand_Beta", "Brand_Gamma",
      "Price_$20", "Price_$30",
      "Size_Medium", "Size_Large",
      "Color_Blue"
    )

    # True population-level utilities with heterogeneity
    true_means <- c(0.8, -0.3, -0.5, -1.2, 0.4, 0.6, 0.2)
    n_params <- length(col_names)

    # Individual betas = population mean + noise
    betas <- matrix(
      rep(true_means, each = n_respondents) + rnorm(n_respondents * n_params, 0, 0.3),
      nrow = n_respondents, ncol = n_params
    )
    colnames(betas) <- col_names

    # Build attribute_map (list mapping column index -> attribute/level)
    attribute_map <- list(
      list(attribute = "Brand", level = "Beta"),
      list(attribute = "Brand", level = "Gamma"),
      list(attribute = "Price", level = "$20"),
      list(attribute = "Price", level = "$30"),
      list(attribute = "Size",  level = "Medium"),
      list(attribute = "Size",  level = "Large"),
      list(attribute = "Color", level = "Blue")
    )

    list(betas = betas, attribute_map = attribute_map)
  }

  # ============================================================================
  # TEST 1: CIs computed with individual betas
  # ============================================================================
  test_that("predict_shares_with_ci: CIs computed with individual betas", {
    skip_if(!exists("predict_shares_with_ci", mode = "function"),
            "predict_shares_with_ci not loaded")

    synth_betas <- .make_synthetic_betas(n_respondents = 50, seed = 42)
    utils <- generate_utilities_df(with_price = TRUE)

    products <- list(
      list(Brand = "Beta", Price = "$20", Size = "Medium", Color = "Blue"),
      list(Brand = "Gamma", Price = "$30", Size = "Large")
    )

    set.seed(123)
    result <- predict_shares_with_ci(
      products = products,
      utilities = utils,
      individual_betas = synth_betas$betas,
      attribute_map = synth_betas$attribute_map,
      method = "logit",
      n_boot = 200,
      conf_level = 0.95,
      verbose = FALSE
    )

    # Should return a data frame
    expect_true(is.data.frame(result))

    # Required columns
    expect_true("Share_Percent" %in% names(result))
    expect_true("Lower" %in% names(result))
    expect_true("Upper" %in% names(result))
    expect_true("SE" %in% names(result))

    # Two products
    expect_equal(nrow(result), 2)
  })

  # ============================================================================
  # TEST 2: Lower < Share < Upper for each product
  # ============================================================================
  test_that("predict_shares_with_ci: Lower < Share_Percent < Upper", {
    skip_if(!exists("predict_shares_with_ci", mode = "function"),
            "predict_shares_with_ci not loaded")

    synth_betas <- .make_synthetic_betas(n_respondents = 50, seed = 42)
    utils <- generate_utilities_df(with_price = TRUE)

    products <- list(
      list(Brand = "Beta",  Price = "$20", Size = "Medium", Color = "Blue"),
      list(Brand = "Gamma", Price = "$30", Size = "Large")
    )

    set.seed(123)
    result <- predict_shares_with_ci(
      products = products,
      utilities = utils,
      individual_betas = synth_betas$betas,
      attribute_map = synth_betas$attribute_map,
      method = "logit",
      n_boot = 200,
      conf_level = 0.95,
      verbose = FALSE
    )

    for (i in seq_len(nrow(result))) {
      expect_lt(result$Lower[i], result$Share_Percent[i],
                label = sprintf("Product %d: Lower (%.2f) < Share (%.2f)",
                                i, result$Lower[i], result$Share_Percent[i]))
      expect_gt(result$Upper[i], result$Share_Percent[i],
                label = sprintf("Product %d: Share (%.2f) < Upper (%.2f)",
                                i, result$Share_Percent[i], result$Upper[i]))
    }
  })

  # ============================================================================
  # TEST 3: SE > 0 for all products
  # ============================================================================
  test_that("predict_shares_with_ci: SE > 0 for all products", {
    skip_if(!exists("predict_shares_with_ci", mode = "function"),
            "predict_shares_with_ci not loaded")

    synth_betas <- .make_synthetic_betas(n_respondents = 50, seed = 42)
    utils <- generate_utilities_df(with_price = TRUE)

    products <- list(
      list(Brand = "Beta",  Price = "$20", Size = "Medium"),
      list(Brand = "Gamma", Price = "$30", Size = "Large")
    )

    set.seed(456)
    result <- predict_shares_with_ci(
      products = products,
      utilities = utils,
      individual_betas = synth_betas$betas,
      attribute_map = synth_betas$attribute_map,
      method = "logit",
      n_boot = 200,
      conf_level = 0.95,
      verbose = FALSE
    )

    expect_true(all(result$SE > 0),
                info = "All standard errors should be positive")
  })

  # ============================================================================
  # TEST 4: Fallback when no individual betas (returns NA CIs)
  # ============================================================================
  test_that("predict_shares_with_ci: fallback returns NA CIs without individual betas", {
    skip_if(!exists("predict_shares_with_ci", mode = "function"),
            "predict_shares_with_ci not loaded")

    utils <- generate_utilities_df(with_price = TRUE)

    products <- list(
      list(Brand = "Beta",  Size = "Medium", Price = "$20"),
      list(Brand = "Gamma", Size = "Large",  Price = "$30")
    )

    # No individual_betas or attribute_map
    result <- predict_shares_with_ci(
      products = products,
      utilities = utils,
      individual_betas = NULL,
      attribute_map = NULL,
      method = "logit",
      verbose = FALSE
    )

    expect_true(is.data.frame(result))
    expect_equal(nrow(result), 2)

    # CIs should be NA
    expect_true(all(is.na(result$Lower)))
    expect_true(all(is.na(result$Upper)))
    expect_true(all(is.na(result$SE)))

    # But shares should still be computed
    expect_true(all(!is.na(result$Share_Percent)))
    expect_true(all(result$Share_Percent >= 0))
  })

  # ============================================================================
  # TEST 5: Shares sum to approximately 100%
  # ============================================================================
  test_that("predict_shares_with_ci: shares sum to ~100%", {
    skip_if(!exists("predict_shares_with_ci", mode = "function"),
            "predict_shares_with_ci not loaded")

    synth_betas <- .make_synthetic_betas(n_respondents = 50, seed = 42)
    utils <- generate_utilities_df(with_price = TRUE)

    products <- list(
      list(Brand = "Beta",  Price = "$20", Size = "Small"),
      list(Brand = "Gamma", Price = "$30", Size = "Large"),
      list(Brand = "Alpha", Price = "$10", Size = "Medium")
    )

    set.seed(789)
    result <- predict_shares_with_ci(
      products = products,
      utilities = utils,
      individual_betas = synth_betas$betas,
      attribute_map = synth_betas$attribute_map,
      method = "logit",
      n_boot = 100,
      conf_level = 0.95,
      verbose = FALSE
    )

    expect_equal(sum(result$Share_Percent), 100, tolerance = 0.5)
    expect_equal(nrow(result), 3)
  })

  # ============================================================================
  # TEST 6: RFC method also works
  # ============================================================================
  test_that("predict_shares_with_ci: RFC method produces valid output", {
    skip_if(!exists("predict_shares_with_ci", mode = "function"),
            "predict_shares_with_ci not loaded")

    synth_betas <- .make_synthetic_betas(n_respondents = 50, seed = 42)
    utils <- generate_utilities_df(with_price = TRUE)

    products <- list(
      list(Brand = "Beta",  Price = "$20", Size = "Medium"),
      list(Brand = "Gamma", Price = "$30", Size = "Large")
    )

    set.seed(101)
    result <- predict_shares_with_ci(
      products = products,
      utilities = utils,
      individual_betas = synth_betas$betas,
      attribute_map = synth_betas$attribute_map,
      method = "rfc",
      n_boot = 100,
      conf_level = 0.95,
      verbose = FALSE
    )

    expect_true(is.data.frame(result))
    expect_equal(nrow(result), 2)
    expect_true(all(!is.na(result$Share_Percent)))
    expect_true(all(!is.na(result$Lower)))
    expect_true(all(!is.na(result$Upper)))
    expect_true(all(result$SE > 0))

    # Shares should sum to ~100
    expect_equal(sum(result$Share_Percent), 100, tolerance = 1.0)
  })

} # end turas_root guard
