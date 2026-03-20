# ==============================================================================
# MAXDIFF TESTS - VALIDATION & DATA MODULES
# ==============================================================================
# Comprehensive tests for 02_validation.R and 03_data.R
# Covers: validate_design, compute_pair_frequencies, estimate_d_efficiency,
#         validate_survey_data, validate_maxdiff_weights,
#         validate_filter_expression, build_maxdiff_long, compute_study_summary


# ==============================================================================
# HELPER: Build a balanced design matrix compatible with validate_design()
# ==============================================================================

make_test_design <- function(n_versions = 2, n_tasks = 4, items_per_task = 3,
                             n_items = 6) {
  set.seed(42)
  item_ids <- paste0("I", seq_len(n_items))
  rows <- list()
  for (v in seq_len(n_versions)) {
    for (t in seq_len(n_tasks)) {
      shown <- sample(item_ids, items_per_task)
      row <- data.frame(Version = v, Task_Number = t, stringsAsFactors = FALSE)
      for (p in seq_along(shown)) {
        row[[paste0("Item", p, "_ID")]] <- shown[p]
      }
      rows[[length(rows) + 1]] <- row
    }
  }
  do.call(rbind, rows)
}

make_test_items <- function(n_items = 6) {
  data.frame(
    Item_ID = paste0("I", seq_len(n_items)),
    Item_Label = paste("Item", LETTERS[seq_len(n_items)]),
    Item_Group = "Test",
    Include = rep(1, n_items),
    Anchor_Item = rep(0, n_items),
    Display_Order = seq_len(n_items),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# 1. validate_design() - design validation
# ==============================================================================

test_that("validate_design passes for a valid design", {
  skip_if(!exists("validate_design", mode = "function"))

  design <- make_test_design()
  items <- make_test_items()

  result <- validate_design(design, items, verbose = FALSE)

  expect_true(result$valid)
  expect_equal(length(result$issues), 0)
  expect_true(!is.null(result$summary))
  expect_equal(result$summary$n_versions, 2)
  expect_equal(result$summary$n_tasks, 4L)
  expect_equal(result$summary$items_per_task, 3)
})


test_that("validate_design detects missing required columns", {
  skip_if(!exists("validate_design", mode = "function"))

  items <- make_test_items()

  # Missing Version column
  design_no_version <- data.frame(
    Task_Number = 1:4,
    Item1_ID = "I1", Item2_ID = "I2", Item3_ID = "I3",
    stringsAsFactors = FALSE
  )
  result <- validate_design(design_no_version, items, verbose = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("Version", result$issues)))

  # Missing all item columns
  design_no_items <- data.frame(
    Version = c(1, 1), Task_Number = c(1, 2),
    stringsAsFactors = FALSE
  )
  result2 <- validate_design(design_no_items, items, verbose = FALSE)
  expect_false(result2$valid)
  expect_true(any(grepl("item columns", result2$issues, ignore.case = TRUE)))
})


test_that("validate_design detects invalid item IDs not in items config", {
  skip_if(!exists("validate_design", mode = "function"))

  items <- make_test_items(n_items = 4)

  # Design references I5 and I6 which are not in items (only I1-I4)
  design <- data.frame(
    Version = c(1, 1),
    Task_Number = c(1, 2),
    Item1_ID = c("I1", "I3"),
    Item2_ID = c("I2", "I5"),
    Item3_ID = c("I3", "I6"),
    stringsAsFactors = FALSE
  )

  result <- validate_design(design, items, verbose = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("unknown", result$issues, ignore.case = TRUE)))
})


test_that("validate_design reports unbalanced item frequencies", {
  skip_if(!exists("validate_design", mode = "function"))

  items <- make_test_items(n_items = 6)

  # Heavily unbalanced: I1 appears in every task, others rarely
  design <- data.frame(
    Version = rep(1, 6),
    Task_Number = 1:6,
    Item1_ID = rep("I1", 6),
    Item2_ID = c("I2", "I2", "I2", "I2", "I2", "I2"),
    Item3_ID = c("I3", "I3", "I4", "I4", "I5", "I6"),
    stringsAsFactors = FALSE
  )

  result <- validate_design(design, items, verbose = FALSE)
  # Should produce a warning about unbalanced frequencies
  has_balance_warning <- any(grepl("unbalanced|CV", result$warnings, ignore.case = TRUE))
  # Also check the CV value in summary
  expect_true(has_balance_warning || result$summary$item_frequency_cv > 0.2)
})


test_that("validate_design detects NA values in item columns", {
  skip_if(!exists("validate_design", mode = "function"))

  items <- make_test_items(n_items = 4)

  design <- data.frame(
    Version = c(1, 1),
    Task_Number = c(1, 2),
    Item1_ID = c("I1", "I2"),
    Item2_ID = c("I2", NA),
    Item3_ID = c("I3", "I4"),
    stringsAsFactors = FALSE
  )

  result <- validate_design(design, items, verbose = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("NA", result$issues)))
})


# ==============================================================================
# 2. compute_pair_frequencies()
# ==============================================================================

test_that("compute_pair_frequencies returns correct structure", {
  skip_if(!exists("compute_pair_frequencies", mode = "function"))

  design <- data.frame(
    Version = c(1, 1),
    Task_Number = c(1, 2),
    Item1_ID = c("A", "B"),
    Item2_ID = c("B", "C"),
    Item3_ID = c("C", "D"),
    stringsAsFactors = FALSE
  )
  item_cols <- c("Item1_ID", "Item2_ID", "Item3_ID")

  freq <- compute_pair_frequencies(design, item_cols)

  expect_true(is.numeric(freq))
  expect_true(length(freq) > 0)
  # All values should be positive integers

  expect_true(all(freq > 0))
  expect_true(all(freq == floor(freq)))
})


test_that("compute_pair_frequencies is symmetric (pair keys are sorted)", {
  skip_if(!exists("compute_pair_frequencies", mode = "function"))

  design <- data.frame(
    Version = c(1, 1),
    Task_Number = c(1, 2),
    Item1_ID = c("A", "C"),
    Item2_ID = c("B", "A"),
    Item3_ID = c("C", "B"),
    stringsAsFactors = FALSE
  )
  item_cols <- c("Item1_ID", "Item2_ID", "Item3_ID")

  freq <- compute_pair_frequencies(design, item_cols)

  # Pair A_B should appear in both tasks (A,B,C appear together twice)
  expect_true("A_B" %in% names(freq))
  expect_equal(freq[["A_B"]], 2)

  # A_C also appears in both tasks
  expect_true("A_C" %in% names(freq))
  expect_equal(freq[["A_C"]], 2)
})


test_that("compute_pair_frequencies counts co-occurrences correctly", {
  skip_if(!exists("compute_pair_frequencies", mode = "function"))

  # 3 tasks, items_per_task = 2. Pairs: A-B, C-D, A-C
  design <- data.frame(
    Version = c(1, 1, 1),
    Task_Number = c(1, 2, 3),
    Item1_ID = c("A", "C", "A"),
    Item2_ID = c("B", "D", "C"),
    stringsAsFactors = FALSE
  )
  item_cols <- c("Item1_ID", "Item2_ID")

  freq <- compute_pair_frequencies(design, item_cols)

  expect_equal(freq[["A_B"]], 1)
  expect_equal(freq[["C_D"]], 1)
  expect_equal(freq[["A_C"]], 1)
  # B_D never co-occur — should not appear in the frequency table
  expect_false("B_D" %in% names(freq))
})


# ==============================================================================
# 3. estimate_d_efficiency()
# ==============================================================================

test_that("estimate_d_efficiency returns numeric between 0 and 1", {
  skip_if(!exists("estimate_d_efficiency", mode = "function"))

  design <- make_test_design(n_versions = 1, n_tasks = 6, items_per_task = 3, n_items = 6)
  item_cols <- grep("^Item\\d+_ID$", names(design), value = TRUE)
  item_ids <- paste0("I", 1:6)

  d_eff <- estimate_d_efficiency(design, item_cols, item_ids)

  expect_true(is.numeric(d_eff))
  expect_true(length(d_eff) == 1)
  expect_true(d_eff >= 0 && d_eff <= 1)
})


test_that("balanced design has higher efficiency than random unbalanced design", {
  skip_if(!exists("estimate_d_efficiency", mode = "function"))

  set.seed(99)
  n_items <- 6
  item_ids <- paste0("I", 1:n_items)

  # Balanced design: each item appears equally often
  balanced <- data.frame(
    Version = rep(1, 6),
    Task_Number = 1:6,
    Item1_ID = c("I1", "I2", "I3", "I4", "I5", "I6"),
    Item2_ID = c("I2", "I3", "I4", "I5", "I6", "I1"),
    Item3_ID = c("I3", "I4", "I5", "I6", "I1", "I2"),
    stringsAsFactors = FALSE
  )

  # Unbalanced design: I1 appears in every task
  unbalanced <- data.frame(
    Version = rep(1, 6),
    Task_Number = 1:6,
    Item1_ID = rep("I1", 6),
    Item2_ID = rep("I2", 6),
    Item3_ID = c("I3", "I3", "I4", "I4", "I5", "I5"),
    stringsAsFactors = FALSE
  )

  item_cols <- c("Item1_ID", "Item2_ID", "Item3_ID")

  eff_balanced <- estimate_d_efficiency(balanced, item_cols, item_ids)
  eff_unbalanced <- estimate_d_efficiency(unbalanced, item_cols, item_ids)

  expect_true(eff_balanced > eff_unbalanced)
})


test_that("estimate_d_efficiency works with small designs", {
  skip_if(!exists("estimate_d_efficiency", mode = "function"))

  # Minimal design: 1 task, 2 items
  design <- data.frame(
    Version = 1,
    Task_Number = 1,
    Item1_ID = "I1",
    Item2_ID = "I2",
    stringsAsFactors = FALSE
  )
  item_cols <- c("Item1_ID", "Item2_ID")
  item_ids <- c("I1", "I2")

  d_eff <- estimate_d_efficiency(design, item_cols, item_ids)

  # With minimal design, may return NA or a valid value
  expect_true(is.numeric(d_eff))
  expect_true(is.na(d_eff) || (d_eff >= 0 && d_eff <= 1))
})


# ==============================================================================
# 4. validate_survey_data()
# ==============================================================================

test_that("validate_survey_data passes for valid data", {
  skip_if(!exists("validate_survey_data", mode = "function"))

  items <- make_test_items(n_items = 4)

  design <- data.frame(
    Version = c(1, 1),
    Task_Number = c(1, 2),
    Item1_ID = c("I1", "I3"),
    Item2_ID = c("I2", "I4"),
    Item3_ID = c("I3", "I1"),
    stringsAsFactors = FALSE
  )

  survey_mapping <- data.frame(
    Field_Name = c("resp_id", "version_col", "best_1", "best_2", "worst_1", "worst_2"),
    Field_Type = c("RESPONDENT_ID", "VERSION", "BEST_CHOICE", "BEST_CHOICE",
                   "WORST_CHOICE", "WORST_CHOICE"),
    Task_Number = c(NA, NA, 1, 2, 1, 2),
    stringsAsFactors = FALSE
  )

  survey_data <- data.frame(
    resp_id = c("R1", "R2"),
    version_col = c(1, 1),
    best_1 = c("I1", "I2"),
    best_2 = c("I3", "I4"),
    worst_1 = c("I3", "I1"),
    worst_2 = c("I1", "I3"),
    stringsAsFactors = FALSE
  )

  result <- validate_survey_data(survey_data, survey_mapping, design, items, verbose = FALSE)

  expect_true(result$valid)
  expect_equal(length(result$issues), 0)
  expect_equal(result$summary$n_respondents, 2)
})


test_that("validate_survey_data detects missing columns", {
  skip_if(!exists("validate_survey_data", mode = "function"))

  items <- make_test_items(n_items = 4)
  design <- make_test_design(n_versions = 1, n_tasks = 2, items_per_task = 3, n_items = 4)

  survey_mapping <- data.frame(
    Field_Name = c("resp_id", "version_col", "best_1", "worst_1"),
    Field_Type = c("RESPONDENT_ID", "VERSION", "BEST_CHOICE", "WORST_CHOICE"),
    Task_Number = c(NA, NA, 1, 1),
    stringsAsFactors = FALSE
  )

  # Data is missing the version_col and worst_1 columns
  survey_data <- data.frame(
    resp_id = c("R1", "R2"),
    best_1 = c("I1", "I2"),
    stringsAsFactors = FALSE
  )

  result <- validate_survey_data(survey_data, survey_mapping, design, items, verbose = FALSE)

  expect_false(result$valid)
  expect_true(any(grepl("missing", result$issues, ignore.case = TRUE)))
})


test_that("validate_survey_data detects missing best/worst columns in mapping", {
  skip_if(!exists("validate_survey_data", mode = "function"))

  items <- make_test_items(n_items = 4)
  design <- make_test_design(n_versions = 1, n_tasks = 2, items_per_task = 3, n_items = 4)

  # Mapping includes best_1 and worst_1 but data is missing worst_1
  survey_mapping <- data.frame(
    Field_Name = c("resp_id", "version_col", "best_1", "worst_1"),
    Field_Type = c("RESPONDENT_ID", "VERSION", "BEST_CHOICE", "WORST_CHOICE"),
    Task_Number = c(NA, NA, 1, 1),
    stringsAsFactors = FALSE
  )

  survey_data <- data.frame(
    resp_id = c("R1"),
    version_col = c(1),
    best_1 = c("I1"),
    stringsAsFactors = FALSE
  )

  result <- validate_survey_data(survey_data, survey_mapping, design, items, verbose = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("worst_1", result$issues)))
})


# ==============================================================================
# 5. validate_maxdiff_weights()
# ==============================================================================

test_that("validate_maxdiff_weights passes for valid positive weights", {
  skip_if(!exists("validate_maxdiff_weights", mode = "function"))

  weights <- c(1.0, 1.2, 0.8, 1.5, 0.9)
  result <- validate_maxdiff_weights(weights, verbose = FALSE)

  expect_true(result$valid)
  expect_equal(length(result$issues), 0)
})


test_that("validate_maxdiff_weights passes for NULL weights", {
  skip_if(!exists("validate_maxdiff_weights", mode = "function"))

  result <- validate_maxdiff_weights(NULL, verbose = FALSE)

  expect_true(result$valid)
  expect_equal(length(result$issues), 0)
})


test_that("validate_maxdiff_weights detects zero weights", {
  skip_if(!exists("validate_maxdiff_weights", mode = "function"))

  weights <- c(1.0, 0.0, 1.5, 0.0, 0.8)
  result <- validate_maxdiff_weights(weights, verbose = FALSE)

  expect_false(result$valid)
  expect_true(any(grepl("non-positive", result$issues)))
})


test_that("validate_maxdiff_weights detects negative weights", {
  skip_if(!exists("validate_maxdiff_weights", mode = "function"))

  weights <- c(1.0, -0.5, 1.5, 0.8)
  result <- validate_maxdiff_weights(weights, verbose = FALSE)

  expect_false(result$valid)
  expect_true(any(grepl("non-positive", result$issues)))
})


test_that("validate_maxdiff_weights detects NA weights", {
  skip_if(!exists("validate_maxdiff_weights", mode = "function"))

  weights <- c(1.0, NA, 1.5, NA, 0.8)
  result <- validate_maxdiff_weights(weights, verbose = FALSE)

  expect_false(result$valid)
  expect_true(any(grepl("NA", result$issues)))
})


test_that("validate_maxdiff_weights warns on extreme weight ratios", {
  skip_if(!exists("validate_maxdiff_weights", mode = "function"))

  # Ratio of 20 (max/min = 20) exceeds threshold of 10
  weights <- c(0.5, 10.0, 1.0, 1.0, 1.0)
  result <- validate_maxdiff_weights(weights, verbose = FALSE)

  expect_true(result$valid)  # Still valid, just warnings
  expect_true(any(grepl("ratio|large", result$warnings, ignore.case = TRUE)))
})


# ==============================================================================
# 6. validate_filter_expression() - filter security
# ==============================================================================

test_that("validate_filter_expression accepts valid R filter expressions", {
  skip_if(!exists("validate_filter_expression", mode = "function"))

  allowed <- c("age", "gender", "wave")

  expect_true(validate_filter_expression("age > 25", allowed))
  expect_true(validate_filter_expression("gender == 'M'", allowed))
  expect_true(validate_filter_expression("wave %in% c(1, 2, 3)", allowed))
  expect_true(validate_filter_expression("age >= 18 & gender != 'X'", allowed))
})


test_that("validate_filter_expression rejects system calls", {
  skip_if(!exists("validate_filter_expression", mode = "function"))

  allowed <- c("x", "y")

  result <- tryCatch(
    validate_filter_expression("system('ls')", allowed),
    error = function(e) list(status = "REFUSED", message = conditionMessage(e))
  )
  expect_true(grepl("unsafe|REFUSED|Unsafe", paste(result$status, result$message), ignore.case = TRUE))
})


test_that("validate_filter_expression rejects file operations", {
  skip_if(!exists("validate_filter_expression", mode = "function"))

  allowed <- c("x")

  for (dangerous in c("file.remove('/tmp/x')", "unlink('/tmp')", "file.create('x')")) {
    result <- tryCatch(
      validate_filter_expression(dangerous, allowed),
      error = function(e) list(status = "REFUSED", message = conditionMessage(e))
    )
    expect_true(
      grepl("unsafe|REFUSED|Unsafe", paste(result$status, result$message), ignore.case = TRUE),
      info = sprintf("Expression '%s' should be rejected", dangerous)
    )
  }
})


test_that("validate_filter_expression returns TRUE for empty string", {
  skip_if(!exists("validate_filter_expression", mode = "function"))

  expect_true(validate_filter_expression("", c("x")))
  expect_true(validate_filter_expression("   ", c("x")))
  expect_true(validate_filter_expression(NULL, c("x")))
})


test_that("validate_filter_expression rejects assignment operators", {
  skip_if(!exists("validate_filter_expression", mode = "function"))

  allowed <- c("x")

  result <- tryCatch(
    validate_filter_expression("x <- 5", allowed),
    error = function(e) list(status = "REFUSED", message = conditionMessage(e))
  )
  expect_true(grepl("assignment|REFUSED", paste(result$status, result$message), ignore.case = TRUE))
})


# ==============================================================================
# 7. build_maxdiff_long() - long format conversion
# ==============================================================================

test_that("build_maxdiff_long produces correct long format structure", {
  skip_if(!exists("build_maxdiff_long", mode = "function"))

  n_resp <- 3
  n_tasks <- 2
  items_per_task <- 3

  items <- make_test_items(n_items = 6)

  design <- data.frame(
    Version = c(1, 1),
    Task_Number = c(1, 2),
    Item1_ID = c("I1", "I4"),
    Item2_ID = c("I2", "I5"),
    Item3_ID = c("I3", "I6"),
    stringsAsFactors = FALSE
  )

  survey_mapping <- data.frame(
    Field_Name = c("resp_id", "version", "best_1", "best_2", "worst_1", "worst_2"),
    Field_Type = c("RESPONDENT_ID", "VERSION", "BEST_CHOICE", "BEST_CHOICE",
                   "WORST_CHOICE", "WORST_CHOICE"),
    Task_Number = c(NA, NA, 1, 2, 1, 2),
    stringsAsFactors = FALSE
  )

  survey_data <- data.frame(
    resp_id = paste0("R", 1:n_resp),
    version = rep(1, n_resp),
    best_1 = c("I1", "I2", "I3"),
    best_2 = c("I4", "I5", "I6"),
    worst_1 = c("I3", "I1", "I2"),
    worst_2 = c("I6", "I4", "I5"),
    stringsAsFactors = FALSE
  )

  config <- list(
    project_settings = list(
      Respondent_ID_Variable = "resp_id",
      Weight_Variable = NULL
    )
  )

  long <- build_maxdiff_long(survey_data, survey_mapping, design, config, verbose = FALSE)

  # Expected rows: n_resp * n_tasks * items_per_task
  expected_rows <- n_resp * n_tasks * items_per_task
  expect_equal(nrow(long), expected_rows)

  # Check required columns
  required_cols <- c("resp_id", "version", "task", "item_id", "is_best", "is_worst")
  expect_true(all(required_cols %in% names(long)))
})


test_that("build_maxdiff_long has exactly one best and one worst per task per respondent", {
  skip_if(!exists("build_maxdiff_long", mode = "function"))

  items <- make_test_items(n_items = 4)

  design <- data.frame(
    Version = c(1, 1),
    Task_Number = c(1, 2),
    Item1_ID = c("I1", "I3"),
    Item2_ID = c("I2", "I4"),
    stringsAsFactors = FALSE
  )

  survey_mapping <- data.frame(
    Field_Name = c("resp_id", "version", "best_1", "best_2", "worst_1", "worst_2"),
    Field_Type = c("RESPONDENT_ID", "VERSION", "BEST_CHOICE", "BEST_CHOICE",
                   "WORST_CHOICE", "WORST_CHOICE"),
    Task_Number = c(NA, NA, 1, 2, 1, 2),
    stringsAsFactors = FALSE
  )

  survey_data <- data.frame(
    resp_id = c("R1", "R2"),
    version = c(1, 1),
    best_1 = c("I1", "I2"),
    best_2 = c("I3", "I4"),
    worst_1 = c("I2", "I1"),
    worst_2 = c("I4", "I3"),
    stringsAsFactors = FALSE
  )

  config <- list(
    project_settings = list(
      Respondent_ID_Variable = "resp_id",
      Weight_Variable = NULL
    )
  )

  long <- build_maxdiff_long(survey_data, survey_mapping, design, config, verbose = FALSE)

  # For each respondent-task combo, exactly one best and one worst
  by_task <- aggregate(cbind(is_best, is_worst) ~ resp_id + task,
                       data = long, FUN = sum)
  expect_true(all(by_task$is_best == 1))
  expect_true(all(by_task$is_worst == 1))
})


test_that("build_maxdiff_long contains only valid item IDs from design", {
  skip_if(!exists("build_maxdiff_long", mode = "function"))

  items <- make_test_items(n_items = 4)

  design <- data.frame(
    Version = c(1, 1),
    Task_Number = c(1, 2),
    Item1_ID = c("I1", "I3"),
    Item2_ID = c("I2", "I4"),
    stringsAsFactors = FALSE
  )

  survey_mapping <- data.frame(
    Field_Name = c("resp_id", "version", "best_1", "best_2", "worst_1", "worst_2"),
    Field_Type = c("RESPONDENT_ID", "VERSION", "BEST_CHOICE", "BEST_CHOICE",
                   "WORST_CHOICE", "WORST_CHOICE"),
    Task_Number = c(NA, NA, 1, 2, 1, 2),
    stringsAsFactors = FALSE
  )

  survey_data <- data.frame(
    resp_id = c("R1"),
    version = c(1),
    best_1 = c("I1"),
    best_2 = c("I3"),
    worst_1 = c("I2"),
    worst_2 = c("I4"),
    stringsAsFactors = FALSE
  )

  config <- list(
    project_settings = list(
      Respondent_ID_Variable = "resp_id",
      Weight_Variable = NULL
    )
  )

  long <- build_maxdiff_long(survey_data, survey_mapping, design, config, verbose = FALSE)

  design_items <- unique(c(design$Item1_ID, design$Item2_ID))
  expect_true(all(long$item_id %in% design_items))
})


test_that("build_maxdiff_long assigns default weight of 1 when no weight variable", {
  skip_if(!exists("build_maxdiff_long", mode = "function"))

  items <- make_test_items(n_items = 4)

  design <- data.frame(
    Version = 1, Task_Number = 1,
    Item1_ID = "I1", Item2_ID = "I2",
    stringsAsFactors = FALSE
  )

  survey_mapping <- data.frame(
    Field_Name = c("resp_id", "version", "best_1", "worst_1"),
    Field_Type = c("RESPONDENT_ID", "VERSION", "BEST_CHOICE", "WORST_CHOICE"),
    Task_Number = c(NA, NA, 1, 1),
    stringsAsFactors = FALSE
  )

  survey_data <- data.frame(
    resp_id = "R1", version = 1, best_1 = "I1", worst_1 = "I2",
    stringsAsFactors = FALSE
  )

  config <- list(
    project_settings = list(
      Respondent_ID_Variable = "resp_id",
      Weight_Variable = NULL
    )
  )

  long <- build_maxdiff_long(survey_data, survey_mapping, design, config, verbose = FALSE)

  expect_true("weight" %in% names(long))
  expect_true(all(long$weight == 1))
})


# ==============================================================================
# 8. compute_study_summary()
# ==============================================================================

test_that("compute_study_summary returns correct respondent count", {
  skip_if(!exists("compute_study_summary", mode = "function"))

  long_data <- data.frame(
    resp_id = rep(paste0("R", 1:5), each = 6),
    version = rep(1, 30),
    task = rep(rep(1:3, each = 2), 5),
    item_id = rep(c("I1", "I2"), 15),
    is_best = rep(c(1, 0), 15),
    is_worst = rep(c(0, 1), 15),
    weight = rep(1, 30),
    stringsAsFactors = FALSE
  )

  config <- list(
    project_settings = list(
      Weight_Variable = NULL
    )
  )

  result <- compute_study_summary(long_data, config, verbose = FALSE)

  expect_equal(result$n_respondents, 5)
})


test_that("compute_study_summary returns correct item and task counts", {
  skip_if(!exists("compute_study_summary", mode = "function"))

  long_data <- data.frame(
    resp_id = rep("R1", 12),
    version = rep(1, 12),
    task = rep(1:4, each = 3),
    item_id = rep(c("I1", "I2", "I3"), 4),
    is_best = c(1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1),
    is_worst = c(0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0),
    weight = rep(1, 12),
    stringsAsFactors = FALSE
  )

  config <- list(
    project_settings = list(
      Weight_Variable = NULL
    )
  )

  result <- compute_study_summary(long_data, config, verbose = FALSE)

  expect_equal(result$n_items, 3)
  expect_equal(result$n_tasks, 4)
  expect_equal(result$n_observations, 12)
})


test_that("compute_study_summary handles weighted data", {
  skip_if(!exists("compute_study_summary", mode = "function"))

  long_data <- data.frame(
    resp_id = rep(c("R1", "R2"), each = 4),
    version = rep(1, 8),
    task = rep(1:2, each = 2, times = 2),
    item_id = rep(c("I1", "I2"), 4),
    is_best = rep(c(1, 0), 4),
    is_worst = rep(c(0, 1), 4),
    weight = rep(c(1.5, 0.5), each = 4),
    stringsAsFactors = FALSE
  )

  config <- list(
    project_settings = list(
      Weight_Variable = "weight"
    )
  )

  result <- compute_study_summary(long_data, config, verbose = FALSE)

  expect_equal(result$n_respondents, 2)
  expect_true(result$weighted)
  expect_true(result$effective_n <= result$n_respondents)
  expect_true(result$design_effect >= 1)
})


test_that("compute_study_summary reports unweighted correctly", {
  skip_if(!exists("compute_study_summary", mode = "function"))

  long_data <- data.frame(
    resp_id = rep("R1", 4),
    version = rep(1, 4),
    task = rep(1:2, each = 2),
    item_id = rep(c("I1", "I2"), 2),
    is_best = c(1, 0, 0, 1),
    is_worst = c(0, 1, 1, 0),
    weight = rep(1, 4),
    stringsAsFactors = FALSE
  )

  config <- list(
    project_settings = list(
      Weight_Variable = NULL
    )
  )

  result <- compute_study_summary(long_data, config, verbose = FALSE)

  expect_false(result$weighted)
  expect_equal(result$effective_n, 1)
  expect_equal(result$design_effect, 1)
})
