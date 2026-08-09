# ==============================================================================
# TESTS: Cell/Interlocked Weighting (cell_weights.R)
# ==============================================================================

test_that("calculate_cell_weights produces correct weights", {
  data <- create_simple_survey(n = 200)

  # Define 2x3 cell targets (Gender x Age)
  cell_targets <- data.frame(
    Gender = rep(c("Male", "Female"), each = 3),
    Age = rep(c("18-34", "35-54", "55+"), 2),
    target_percent = c(14, 20, 14, 16, 20, 16),
    stringsAsFactors = FALSE
  )

  result <- calculate_cell_weights(
    data = data,
    cell_targets = cell_targets,
    cell_variables = c("Gender", "Age"),
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_length(result$weights, 200)
  expect_equal(result$method, "cell")
  # Most weights should be assigned (some cells might be empty)
  expect_true(sum(!is.na(result$weights)) > 180)
})

test_that("cell weights sum preserves sample size", {
  data <- create_simple_survey(n = 200)

  cell_targets <- data.frame(
    Gender = rep(c("Male", "Female"), each = 3),
    Age = rep(c("18-34", "35-54", "55+"), 2),
    target_percent = c(14, 20, 14, 16, 20, 16),
    stringsAsFactors = FALSE
  )

  result <- calculate_cell_weights(
    data = data,
    cell_targets = cell_targets,
    cell_variables = c("Gender", "Age"),
    verbose = FALSE
  )

  valid_weights <- result$weights[!is.na(result$weights)]
  # Sum of weights should approximately equal n for valid observations
  expect_equal(sum(valid_weights), sum(!is.na(result$weights)), tolerance = 0.1)
})

test_that("cell weights with balanced data produce uniform weights", {
  # Create perfectly balanced data: 10 in each of 4 cells
  data <- data.frame(
    Gender = rep(c("Male", "Female"), each = 20),
    Age = rep(c("Young", "Old"), 20),
    stringsAsFactors = FALSE
  )

  cell_targets <- data.frame(
    Gender = rep(c("Male", "Female"), each = 2),
    Age = rep(c("Young", "Old"), 2),
    target_percent = c(25, 25, 25, 25),  # Equal distribution
    stringsAsFactors = FALSE
  )

  result <- calculate_cell_weights(
    data = data,
    cell_targets = cell_targets,
    cell_variables = c("Gender", "Age"),
    verbose = FALSE
  )

  # All weights should be very close to 1.0
  expect_true(all(abs(result$weights - 1.0) < 0.01))
})

test_that("cell weights handle missing cell variable", {
  data <- create_simple_survey(n = 200)
  cell_targets <- data.frame(
    NonExistent = c("A", "B"),
    target_percent = c(50, 50),
    stringsAsFactors = FALSE
  )

  expect_error(
    calculate_cell_weights(data, cell_targets, "NonExistent"),
    class = "turas_refusal"
  )
})

test_that("cell weights handle empty data", {
  data <- data.frame(Gender = character(0), Age = character(0))
  cell_targets <- data.frame(
    Gender = "Male",
    Age = "Young",
    target_percent = 100,
    stringsAsFactors = FALSE
  )

  expect_error(
    calculate_cell_weights(data, cell_targets, c("Gender", "Age")),
    class = "turas_refusal"
  )
})

test_that("cell weights refuse when targets don't sum to 100", {
  data <- create_simple_survey(n = 200)

  cell_targets <- data.frame(
    Gender = c("Male", "Female"),
    target_percent = c(60, 60),  # sums to 120
    stringsAsFactors = FALSE
  )

  expect_error(
    calculate_cell_weights(data, cell_targets, "Gender"),
    class = "turas_refusal"
  )
})

test_that("cell weights refuse when a target cell has nobody in it", {
  # Male-Young and Female-Old exist; Male-Old and Female-Young do not. Those two
  # cells carry 50% of the target population between them, and no respondent can
  # represent them — so every weighted total loses that half. This used to be a
  # warning and the run carried on.
  data <- data.frame(
    Gender = c(rep("Male", 50), rep("Female", 50)),
    Age = c(rep("Young", 50), rep("Old", 50)),
    stringsAsFactors = FALSE
  )

  cell_targets <- data.frame(
    Gender = c("Male", "Male", "Female", "Female"),
    Age = c("Young", "Old", "Young", "Old"),
    target_percent = c(25, 25, 25, 25),
    stringsAsFactors = FALSE
  )

  refusal <- tryCatch(
    suppressWarnings(
      calculate_cell_weights(data, cell_targets, c("Gender", "Age"), verbose = FALSE)
    ),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "DATA_UNWEIGHTED_ROWS")
  # It must say which cells and how much of the population they carry.
  expect_match(conditionMessage(refusal), "Male x Old")
  expect_match(conditionMessage(refusal), "50.0%")
})

empty_cell_fixture <- function() {
  list(
    data = data.frame(
      Gender = c(rep("Male", 50), rep("Female", 50)),
      Age = c(rep("Young", 50), rep("Old", 50)),
      stringsAsFactors = FALSE
    ),
    targets = data.frame(
      Gender = c("Male", "Male", "Female", "Female"),
      Age = c("Young", "Old", "Young", "Old"),
      target_percent = c(25, 25, 25, 25),
      stringsAsFactors = FALSE
    )
  )
}

test_that("allow_unmatched does not silence the empty-target refusal", {
  # These were one setting, so an analyst excluding a few respondents with a
  # missing value also switched off the empty-cell guard. An empty target is a
  # population-side problem and allow_unmatched is the respondent-side opt-in;
  # it must not answer for the other.
  f <- empty_cell_fixture()

  refusal <- tryCatch(
    calculate_cell_weights(f$data, f$targets, c("Gender", "Age"),
                           allow_unmatched = TRUE, verbose = FALSE),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "DATA_UNWEIGHTED_ROWS")
  expect_match(refusal$how_to_fix, "allow_empty_targets = YES")
})

test_that("allow_empty_targets redistributes the orphaned share instead of shrinking the base", {
  # Two of four cells are empty and carry 50% of the population between them.
  # The opt-in used to leave the weights summing to 50 on a sample of 100 —
  # every weighted base in the report short by half, disclosed as "0 of 100
  # respondents left with no weight". The share is now redistributed across the
  # cells that do have respondents.
  f <- empty_cell_fixture()

  result <- calculate_cell_weights(
    f$data, f$targets, c("Gender", "Age"),
    allow_empty_targets = TRUE, verbose = FALSE
  )

  expect_equal(result$n_cells_empty, 2)
  expect_true(all(c("Male x Old", "Female x Young") %in% result$empty_cells))

  # Nobody in the sample loses a weight — the loss was on the population side.
  expect_equal(result$n_unweighted, 0)
  expect_false(any(is.na(result$weights)))

  # The weighted base matches the sample, which is the whole point.
  expect_equal(sum(result$weights), 100, tolerance = 1e-9)
  expect_equal(result$n_base, 100)
  expect_equal(result$empty_target_share, 50)
  # 25% surviving x 2 cells = 50%, scaled by 100/50 = 2.
  expect_equal(result$redistribution_factor, 2, tolerance = 1e-12)
  # Each surviving cell now carries 50% of the population over 50 respondents.
  expect_equal(unique(round(result$weights, 10)), 1, tolerance = 1e-9)
})

test_that("a missing value in a cell variable is reported as missing, not as an undefined cell", {
  # paste() renders NA as the characters "NA", so a respondent with a missing
  # Age used to be routed to a cell literally keyed "Male|NA" and then counted
  # as belonging to an undefined cell. The cause was disguised as a different
  # problem, and the fix the message suggested would never have worked.
  data <- data.frame(
    Gender = c(rep("Male", 50), rep("Female", 50)),
    Age = c(rep("Young", 25), rep("Old", 24), NA, rep("Young", 25), rep("Old", 25)),
    stringsAsFactors = FALSE
  )

  cell_targets <- data.frame(
    Gender = c("Male", "Male", "Female", "Female"),
    Age = c("Young", "Old", "Young", "Old"),
    target_percent = c(25, 25, 25, 25),
    stringsAsFactors = FALSE
  )

  refusal <- tryCatch(
    suppressWarnings(
      calculate_cell_weights(data, cell_targets, c("Gender", "Age"), verbose = FALSE)
    ),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_match(conditionMessage(refusal), "missing value in a cell variable")
  expect_match(conditionMessage(refusal), "Age: 1")
  # And it must NOT be described as an undefined cell.
  expect_false(grepl("Male x NA", conditionMessage(refusal), fixed = TRUE))

  allowed <- calculate_cell_weights(
    data, cell_targets, c("Gender", "Age"),
    allow_unmatched = TRUE, verbose = FALSE
  )
  expect_equal(allowed$n_missing_cell_data, 1)
  expect_equal(allowed$n_unweighted, 1)
  expect_equal(unname(allowed$na_by_variable[["Age"]]), 1)
  expect_equal(sum(is.na(allowed$weights)), 1)
})

test_that("a category value containing the key separator is refused, not silently merged", {
  # Cell keys join category values with the ASCII unit separator. A value that
  # contains it could collide with a different combination of categories and
  # merge two cells into one weight.
  sep <- "\x1F"
  data <- data.frame(
    Gender = c(rep(paste0("Male", sep, "X"), 50), rep("Female", 50)),
    Age = c(rep("Young", 50), rep("Old", 50)),
    stringsAsFactors = FALSE
  )

  cell_targets <- data.frame(
    Gender = c("Male", "Female"),
    Age = c("Young", "Old"),
    target_percent = c(50, 50),
    stringsAsFactors = FALSE
  )

  refusal <- tryCatch(
    suppressWarnings(
      calculate_cell_weights(data, cell_targets, c("Gender", "Age"), verbose = FALSE)
    ),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "DATA_KEY_SEPARATOR_IN_VALUE")
})

test_that("a pipe in a category value no longer collides two cells", {
  # The old separator was "|". "A|B" x "C" and "A" x "B|C" both keyed to
  # "A|B|C", so the two cells merged and shared one weight. With the unit
  # separator they stay distinct.
  data <- data.frame(
    V1 = c(rep("A|B", 40), rep("A", 60)),
    V2 = c(rep("C", 40), rep("B|C", 60)),
    stringsAsFactors = FALSE
  )

  cell_targets <- data.frame(
    V1 = c("A|B", "A"),
    V2 = c("C", "B|C"),
    target_percent = c(50, 50),
    stringsAsFactors = FALSE
  )

  result <- calculate_cell_weights(data, cell_targets, c("V1", "V2"), verbose = FALSE)

  # Two distinct cells, each with its own count and its own weight.
  expect_equal(nrow(result$cell_summary), 2)
  expect_equal(sort(result$cell_summary$sample_count), c(40, 60))
  # (0.5 * 100) / 40 = 1.25 and (0.5 * 100) / 60 = 0.8333
  expect_equal(sort(round(result$cell_summary$weight, 4)), c(0.8333, 1.25))
})

test_that("cell weights return correct summary", {
  data <- create_simple_survey(n = 200)

  cell_targets <- data.frame(
    Gender = c("Male", "Female"),
    target_percent = c(48, 52),
    stringsAsFactors = FALSE
  )

  result <- calculate_cell_weights(
    data = data,
    cell_targets = cell_targets,
    cell_variables = "Gender",
    verbose = FALSE
  )

  expect_true(is.data.frame(result$cell_summary))
  expect_equal(nrow(result$cell_summary), 2)
  expect_true("target_pct" %in% names(result$cell_summary))
  expect_true("sample_count" %in% names(result$cell_summary))
  expect_true("weight" %in% names(result$cell_summary))
})

test_that("validate_cell_config catches duplicate cells", {
  data <- create_simple_survey(n = 200)

  cell_targets <- data.frame(
    Gender = c("Male", "Male", "Female"),
    target_percent = c(25, 25, 50),
    stringsAsFactors = FALSE
  )

  result <- validate_cell_config(data, cell_targets, "w1", "Gender")
  expect_false(result$valid)
  expect_true(any(grepl("Duplicate", result$errors)))
})

test_that("validate_cell_config catches negative targets", {
  data <- create_simple_survey(n = 200)

  cell_targets <- data.frame(
    Gender = c("Male", "Female"),
    target_percent = c(110, -10),
    stringsAsFactors = FALSE
  )

  result <- validate_cell_config(data, cell_targets, "w1", "Gender")
  expect_false(result$valid)
})

test_that("calculate_cell_weights_from_config works with config", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_cell_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  result <- calculate_cell_weights_from_config(
    data = data,
    config = config,
    weight_name = "cell_weight",
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_length(result$weights, 200)
  expect_true(sum(!is.na(result$weights)) > 150)
})

test_that("integration: run_weighting with cell weights", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_cell_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- with_refusal_handler({
    run_weighting(config_path, verbose = FALSE)
  }, module = "WEIGHTING")

  expect_false(is_refusal(result))
  expect_equal(result$status, "PASS")
  expect_true("cell_weight" %in% names(result$data))
  expect_equal(nrow(result$data), 200)
})

test_that("get_cell_targets returns correct data", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_cell_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  targets <- get_cell_targets(config, "cell_weight")

  expect_true(is.data.frame(targets))
  expect_equal(nrow(targets), 6)  # 2 genders x 3 ages
  expect_true("Gender" %in% names(targets))
  expect_true("Age" %in% names(targets))
  expect_true("target_percent" %in% names(targets))
  # weight_name should have been removed
  expect_false("weight_name" %in% names(targets))
})

test_that("get_cell_targets returns NULL for non-existent weight", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_cell_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  targets <- get_cell_targets(config, "nonexistent_weight")
  expect_equal(nrow(targets), 0)
})
