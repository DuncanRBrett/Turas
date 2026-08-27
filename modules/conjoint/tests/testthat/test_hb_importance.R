# ==============================================================================
# TESTS: IMPORTANCE FROM RESPONDENT-LEVEL PART-WORTHS (review finding M4)
# ==============================================================================
#
# 00_main.R called the aggregate importance function for every method: the
# range of the AVERAGED utilities. Where respondents disagree about an
# attribute, their disagreement cancels in the average before the range is
# taken, so that attribute's importance is understated. The correct HB method
# — importance per respondent, then averaged — existed but was orphaned except
# for latent class profiles.
#
# This also matters for the tabs export planned in Session B: the per-
# respondent importance matrix it needs was computed inside that function and
# thrown away, and the export would have disagreed visibly with the report's
# importance table.
# ==============================================================================

make_heterogeneous_hb <- function(n_respondents = 200, seed = 21) {
  set.seed(seed)

  attributes <- list(
    Brand = c("Alpha", "Beta"),
    Size  = c("Small", "Large")
  )
  col_names <- c("Brand_Beta", "Size_Large")

  # Brand splits the sample: half love Beta, half hate it, mean near zero.
  # Size is uniformly mildly positive.
  half <- n_respondents %/% 2
  brand <- c(rnorm(half, 2.0, 0.2), rnorm(n_respondents - half, -2.0, 0.2))
  size  <- rnorm(n_respondents, 0.5, 0.1)

  individual_betas <- cbind(Brand_Beta = brand, Size_Large = size)
  rownames(individual_betas) <- paste0("R", seq_len(n_respondents))

  attr_df <- data.frame(
    AttributeName = names(attributes),
    NumLevels = sapply(attributes, length),
    stringsAsFactors = FALSE
  )
  attr_df$levels_list <- unname(attributes)

  list(
    model = structure(list(
      method = "hierarchical_bayes",
      coefficients = colMeans(individual_betas),
      std_errors = apply(individual_betas, 2, sd) / sqrt(n_respondents),
      heterogeneity_sd = apply(individual_betas, 2, sd),
      individual_betas = individual_betas,
      col_names = col_names,
      attribute_map = setNames(
        list(list(attribute = "Brand", level = "Beta"),
             list(attribute = "Size", level = "Large")),
        col_names
      )
    ), class = "turas_conjoint_model"),
    config = list(attributes = attr_df, confidence_level = 0.95,
                  zero_center_utilities = FALSE)
  )
}

test_that("M4: individual-level importance differs from the aggregate method under heterogeneity", {
  f <- make_heterogeneous_hb()

  individual <- calculate_attribute_importance_hb(f$model, f$config, verbose = FALSE)

  utils_df <- calculate_utilities(f$model, f$config, verbose = FALSE)
  aggregate <- calculate_attribute_importance(utils_df, f$config, verbose = FALSE)

  get_imp <- function(df, a) df$Importance[df$Attribute == a]

  # Brand splits the sample down the middle, so it cancels in the average and
  # the aggregate method reports it as barely mattering. Every individual
  # respondent, though, is driven almost entirely by Brand.
  expect_gt(get_imp(individual, "Brand"), 80)
  expect_lt(get_imp(aggregate, "Brand"), 40)
  expect_gt(get_imp(individual, "Brand"), get_imp(aggregate, "Brand") + 20)
})

test_that("M4: per-respondent importance rows sum to 100", {
  f <- make_heterogeneous_hb()
  imp <- calculate_attribute_importance_hb(f$model, f$config, verbose = FALSE)

  mat <- attr(imp, "respondent_importance")

  expect_false(is.null(mat))
  expect_equal(nrow(mat), nrow(f$model$individual_betas))
  expect_equal(colnames(mat), f$config$attributes$AttributeName)
  expect_true(all(abs(rowSums(mat) - 100) < 1e-8))
  expect_equal(rownames(mat), rownames(f$model$individual_betas))
})

test_that("M4: respondents with flat part-worths are counted, not hidden", {
  f <- make_heterogeneous_hb(n_respondents = 20)
  f$model$individual_betas[1:3, ] <- 0

  out <- capture.output(
    imp <- calculate_attribute_importance_hb(f$model, f$config, verbose = FALSE),
    type = "output"
  )

  expect_equal(attr(imp, "n_zero_range_respondents"), 3)
  expect_true(any(grepl("CONJ_ZERO_RANGE_RESPONDENTS", out, fixed = TRUE)))

  mat <- attr(imp, "respondent_importance")
  expect_true(all(rowSums(mat[1:3, ]) == 0))
})

test_that("M4: the individual importance table matches the aggregate table's shape", {
  f <- make_heterogeneous_hb(n_respondents = 40)
  individual <- calculate_attribute_importance_hb(f$model, f$config, verbose = FALSE)

  for (col in c("Attribute", "Importance", "Rank", "Interpretation")) {
    expect_true(col %in% names(individual), info = col)
  }
  expect_equal(individual$Rank, sort(individual$Rank))
  expect_equal(attr(individual, "importance_method"), "individual")
})

test_that("M4: the pipeline chooses the individual method for HB and LC only", {
  src <- paste(readLines(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint",
                                   "R", "00_main.R"), warn = FALSE), collapse = "\n")

  expect_true(grepl("calculate_attribute_importance_hb(model_result, config", src, fixed = TRUE))
  expect_true(grepl('c("hierarchical_bayes", "latent_class")', src, fixed = TRUE))
  expect_true(grepl("respondent_importance = attr(importance,", src, fixed = TRUE))
})
