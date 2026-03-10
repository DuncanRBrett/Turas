# ==============================================================================
# TESTS: CONJOINT ESTIMATION (03_estimation.R)
# ==============================================================================

# Load synthetic data generators
fixture_path <- file.path(
  dirname(dirname(testthat::test_path())),
  "fixtures", "synthetic_data", "generate_conjoint_test_data.R"
)
if (file.exists(fixture_path)) source(fixture_path, local = TRUE)


test_that("generate_synthetic_cbc creates valid data", {
  synth <- generate_synthetic_cbc(n_respondents = 20, n_tasks = 4, n_alts = 3, seed = 1)

  expect_is(synth$data, "data.frame")
  expect_equal(nrow(synth$data), 20 * 4 * 3)
  expect_true("resp_id" %in% names(synth$data))
  expect_true("task_id" %in% names(synth$data))
  expect_true("chosen" %in% names(synth$data))

  # Exactly one chosen per task
  chosen_per_task <- tapply(synth$data$chosen, synth$data$task_id, sum)
  expect_true(all(chosen_per_task == 1))
})


test_that("estimation method routing rejects invalid methods", {
  # This tests the dispatch logic without requiring mlogit/bayesm
  config <- list(estimation_method = "invalid_method", analysis_type = "choice")
  data_list <- list(data = data.frame(x = 1))

  # If conjoint_refuse is available, it should trigger a refusal
  if (exists("conjoint_refuse", mode = "function")) {
    expect_error(
      estimate_choice_model(data_list, config, verbose = FALSE),
      regexp = NULL
    )
  }
})


test_that("build_mlogit_formula handles special characters", {
  config <- list(
    attributes = data.frame(
      AttributeName = c("Brand", "I+G", "Price Level"),
      NumLevels = c(3, 2, 3),
      stringsAsFactors = FALSE
    ),
    chosen_column = "chosen"
  )

  if (exists("build_mlogit_formula", mode = "function")) {
    formula <- build_mlogit_formula(config)
    formula_str <- deparse(formula)
    # Special chars should be backtick-escaped
    expect_true(grepl("`I\\+G`", formula_str))
    expect_true(grepl("`Price Level`", formula_str))
    expect_true(grepl("Brand", formula_str))
  }
})


test_that("build_mlogit_formula includes interaction terms from config", {
  config <- list(
    attributes = data.frame(
      AttributeName = c("Brand", "Price", "Size"),
      NumLevels = c(3, 3, 3),
      stringsAsFactors = FALSE
    ),
    chosen_column = "chosen",
    interaction_terms = "Brand:Price"
  )

  if (exists("build_mlogit_formula", mode = "function") &&
      exists("parse_interactions_from_config", mode = "function")) {
    formula <- build_mlogit_formula(config)
    formula_str <- deparse(formula)
    expect_true(grepl("Brand:Price", formula_str))
  }
})
