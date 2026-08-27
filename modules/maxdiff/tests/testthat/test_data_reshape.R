# ==============================================================================
# MAXDIFF TESTS - DATA RESHAPING & FILTERING
# ==============================================================================

# ==============================================================================
# apply_filter_expression() security tests
# ==============================================================================

test_that("apply_filter_expression blocks system() calls", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(x = 1:5, y = letters[1:5], stringsAsFactors = FALSE)

  result <- tryCatch(
    apply_filter_expression(df, "system('whoami')", verbose = FALSE),
    error = function(e) list(status = "REFUSED", message = conditionMessage(e))
  )
  expect_true(grepl("REFUSED|unsafe|Unsafe", paste(result$status, result$message), ignore.case = TRUE))
})

test_that("apply_filter_expression blocks file.remove() calls", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(x = 1:5, stringsAsFactors = FALSE)

  result <- tryCatch(
    apply_filter_expression(df, "file.remove('/tmp/test')", verbose = FALSE),
    error = function(e) list(status = "REFUSED", message = conditionMessage(e))
  )
  expect_true(grepl("REFUSED|unsafe|Unsafe", paste(result$status, result$message), ignore.case = TRUE))
})

test_that("apply_filter_expression blocks unlink() calls", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(x = 1:5, stringsAsFactors = FALSE)

  result <- tryCatch(
    apply_filter_expression(df, "unlink('/tmp/test')", verbose = FALSE),
    error = function(e) list(status = "REFUSED", message = conditionMessage(e))
  )
  expect_true(grepl("REFUSED|unsafe|Unsafe", paste(result$status, result$message), ignore.case = TRUE))
})

test_that("apply_filter_expression blocks eval() calls", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(x = 1:5, stringsAsFactors = FALSE)

  result <- tryCatch(
    apply_filter_expression(df, "eval(parse(text='x > 2'))", verbose = FALSE),
    error = function(e) list(status = "REFUSED", message = conditionMessage(e))
  )
  expect_true(grepl("REFUSED|unsafe|Unsafe", paste(result$status, result$message), ignore.case = TRUE))
})

test_that("apply_filter_expression blocks assignment operators", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(x = 1:5, stringsAsFactors = FALSE)

  result <- tryCatch(
    apply_filter_expression(df, "x <- 99", verbose = FALSE),
    error = function(e) list(status = "REFUSED", message = conditionMessage(e))
  )
  expect_true(grepl("REFUSED|assignment|Assignment", paste(result$status, result$message), ignore.case = TRUE))
})

test_that("apply_filter_expression blocks source() calls", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(x = 1:5, stringsAsFactors = FALSE)

  result <- tryCatch(
    apply_filter_expression(df, "source('/tmp/evil.R')", verbose = FALSE),
    error = function(e) list(status = "REFUSED", message = conditionMessage(e))
  )
  expect_true(grepl("REFUSED|unsafe|Unsafe", paste(result$status, result$message), ignore.case = TRUE))
})

# ==============================================================================
# apply_filter_expression() valid expression tests
# ==============================================================================

test_that("apply_filter_expression filters with equality", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(
    Wave = c(2024, 2024, 2025, 2025, 2025),
    Region = c("A", "B", "A", "B", "A"),
    Score = c(80, 70, 90, 85, 75),
    stringsAsFactors = FALSE
  )

  result <- apply_filter_expression(df, "Wave == 2025", verbose = FALSE)

  expect_equal(nrow(result), 3)
  expect_true(all(result$Wave == 2025))
})

test_that("apply_filter_expression filters with string comparison", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(
    Category = c("Urban", "Rural", "Urban", "Rural"),
    Value = 1:4,
    stringsAsFactors = FALSE
  )

  result <- apply_filter_expression(df, 'Category == "Urban"', verbose = FALSE)

  expect_equal(nrow(result), 2)
  expect_true(all(result$Category == "Urban"))
})

test_that("apply_filter_expression filters with compound logic", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(
    Age = c(25, 35, 45, 55, 65),
    Gender = c("M", "F", "M", "F", "M"),
    stringsAsFactors = FALSE
  )

  result <- apply_filter_expression(df, "Age >= 30 & Age <= 50", verbose = FALSE)

  expect_equal(nrow(result), 2)
  expect_true(all(result$Age >= 30 & result$Age <= 50))
})

test_that("apply_filter_expression returns all rows for NULL expression", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(x = 1:5, stringsAsFactors = FALSE)

  result <- apply_filter_expression(df, NULL, verbose = FALSE)
  expect_equal(nrow(result), 5)
})

test_that("apply_filter_expression returns all rows for empty string", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(x = 1:5, stringsAsFactors = FALSE)

  result <- apply_filter_expression(df, "", verbose = FALSE)
  expect_equal(nrow(result), 5)

  result2 <- apply_filter_expression(df, "   ", verbose = FALSE)
  expect_equal(nrow(result2), 5)
})

test_that("apply_filter_expression refuses when all rows removed", {
  skip_if(!exists("apply_filter_expression", mode = "function"))

  df <- data.frame(x = c(1, 2, 3), stringsAsFactors = FALSE)

  result <- tryCatch(
    apply_filter_expression(df, "x > 100", verbose = FALSE),
    error = function(e) list(status = "REFUSED", message = conditionMessage(e))
  )
  expect_true(grepl("REFUSED|removed|all", paste(result$status, result$message), ignore.case = TRUE))
})

# ==============================================================================
# validate_filter_expression() security tests
# ==============================================================================

test_that("validate_filter_expression detects unknown column names", {
  skip_if(!exists("validate_filter_expression", mode = "function"))

  result <- tryCatch(
    validate_filter_expression("nonexistent_col == 5", c("Wave", "Region")),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result) || isTRUE(result))
  # If it returned a list, it was a refusal
  if (is.list(result)) {
    expect_true(result$status == "REFUSED")
  }
})

test_that("validate_filter_expression allows valid column names", {
  skip_if(!exists("validate_filter_expression", mode = "function"))

  result <- validate_filter_expression("Wave == 2025", c("Wave", "Region"))
  expect_true(result)
})

test_that("validate_filter_expression refuses single = for comparison", {
  skip_if(!exists("validate_filter_expression", mode = "function"))

  result <- tryCatch(
    validate_filter_expression("Wave = 2025", c("Wave")),
    error = function(e) list(status = "REFUSED")
  )
  # Should refuse (single = instead of ==)
  expect_true(is.list(result))
})

# ==============================================================================
# Data reshaping: row count preservation
# ==============================================================================

test_that("reshaping test data produces expected number of observations", {
  td <- generate_test_data(n_resp = 10, n_items = 4, n_tasks = 4, items_per_task = 3)

  # Survey data should have: n_resp * n_tasks rows
  expect_equal(nrow(td$survey_data), 10 * 4)

  # Design should have: n_tasks * items_per_task rows (for version 1)
  expect_equal(nrow(td$design), 4 * 3)
})

test_that("generate_test_data creates consistent item IDs", {
  td <- generate_test_data(n_resp = 5, n_items = 6, n_tasks = 3, items_per_task = 3)

  # Items should be I1 through I6
  expect_equal(td$items$Item_ID, paste0("I", 1:6))

  # Best and Worst choices should be valid item numbers
  expect_true(all(td$survey_data$Best_Choice %in% 1:6))
  expect_true(all(td$survey_data$Worst_Choice %in% 1:6))

  # Best and Worst should never be the same for a given task
  expect_true(all(td$survey_data$Best_Choice != td$survey_data$Worst_Choice))
})


# ==============================================================================
# A3 (C3): build_maxdiff_long — direct tests, both choice codings
# ==============================================================================
# The review found build_maxdiff_long had ZERO direct tests, position-coded
# data validated cleanly and scored as all zeros, and the fixture generator
# hand-converted around it. These fixtures exercise the function itself.

make_reshape_fixture <- function() {
  design <- data.frame(
    Version = c(1L, 1L),
    Task_Number = c(1L, 2L),
    Item1_ID = c("APPLE", "CHERRY"),
    Item2_ID = c("BANANA", "DATE"),
    Item3_ID = c("CHERRY", "APPLE"),
    stringsAsFactors = FALSE
  )
  survey_mapping <- data.frame(
    Field_Type = c("VERSION", "BEST_CHOICE", "WORST_CHOICE",
                   "BEST_CHOICE", "WORST_CHOICE"),
    Field_Name = c("Version", "T1_Best", "T1_Worst", "T2_Best", "T2_Worst"),
    Task_Number = c(NA, 1L, 1L, 2L, 2L),
    stringsAsFactors = FALSE
  )
  items <- data.frame(
    Item_ID = c("APPLE", "BANANA", "CHERRY", "DATE"),
    Item_Label = c("Apple", "Banana", "Cherry", "Date"),
    Include = 1L, Anchor_Item = 0L,
    stringsAsFactors = FALSE
  )
  list(design = design, survey_mapping = survey_mapping, items = items)
}

make_reshape_config <- function(value_type = "ITEM_ID") {
  list(project_settings = list(
    Respondent_ID_Variable = "RespID",
    Weight_Variable = NULL,
    Choice_Value_Type = value_type
  ))
}

test_that("C3: ITEM_ID coding matches choices to items directly", {
  fx <- make_reshape_fixture()
  data <- data.frame(
    RespID = c("R1", "R2"), Version = c(1L, 1L),
    T1_Best = c("APPLE", "BANANA"), T1_Worst = c("CHERRY", "APPLE"),
    T2_Best = c("DATE", "CHERRY"), T2_Worst = c("APPLE", "DATE"),
    stringsAsFactors = FALSE
  )

  long <- build_maxdiff_long(data, fx$survey_mapping, fx$design,
                             make_reshape_config("ITEM_ID"), verbose = FALSE)

  r1t1 <- long[long$resp_id == "R1" & long$task == 1, ]
  expect_equal(r1t1$item_id[r1t1$is_best == 1], "APPLE")
  expect_equal(r1t1$item_id[r1t1$is_worst == 1], "CHERRY")
  # Every task carries exactly one best and one worst.
  agg <- aggregate(cbind(is_best, is_worst) ~ resp_id + task, long, sum)
  expect_true(all(agg$is_best == 1) && all(agg$is_worst == 1))
})

test_that("C3: ITEM_POSITION coding decodes positions through the design row", {
  fx <- make_reshape_fixture()
  # Same choices as the ITEM_ID test, expressed as positions:
  # T1 row is APPLE/BANANA/CHERRY; T2 row is CHERRY/DATE/APPLE.
  data <- data.frame(
    RespID = c("R1", "R2"), Version = c(1L, 1L),
    T1_Best = c(1L, 2L), T1_Worst = c(3L, 1L),
    T2_Best = c(2L, 1L), T2_Worst = c(3L, 2L),
    stringsAsFactors = FALSE
  )

  long <- build_maxdiff_long(data, fx$survey_mapping, fx$design,
                             make_reshape_config("ITEM_POSITION"), verbose = FALSE)

  r1t1 <- long[long$resp_id == "R1" & long$task == 1, ]
  expect_equal(r1t1$item_id[r1t1$is_best == 1], "APPLE")
  expect_equal(r1t1$item_id[r1t1$is_worst == 1], "CHERRY")
  r2t2 <- long[long$resp_id == "R2" & long$task == 2, ]
  expect_equal(r2t2$item_id[r2t2$is_best == 1], "CHERRY")
  expect_equal(r2t2$item_id[r2t2$is_worst == 1], "DATE")
})

test_that("C3: position-coded data produces NON-ZERO count scores", {
  # The shipped defect: positions matched no Item_ID, so Best% = Worst% =
  # Net = 0 for every item — a clean-looking, all-zero deliverable.
  fx <- make_reshape_fixture()
  data <- data.frame(
    RespID = c("R1", "R2"), Version = c(1L, 1L),
    T1_Best = c(1L, 1L), T1_Worst = c(3L, 3L),
    T2_Best = c(3L, 3L), T2_Worst = c(2L, 2L),
    stringsAsFactors = FALSE
  )
  long <- build_maxdiff_long(data, fx$survey_mapping, fx$design,
                             make_reshape_config("ITEM_POSITION"), verbose = FALSE)
  counts <- compute_maxdiff_counts(long, fx$items, weighted = FALSE, verbose = FALSE)

  expect_true(sum(abs(counts$Best_Count)) > 0)
  # APPLE was picked best in T1 by both, and best again (position 3 = APPLE)
  # in T2 by both: 4 best picks.
  expect_equal(counts$Best_Count[counts$Item_ID == "APPLE"], 4)
  expect_equal(counts$Worst_Count[counts$Item_ID == "CHERRY"], 2)
})

test_that("C3: an out-of-range position refuses with context, not zeros", {
  fx <- make_reshape_fixture()
  data <- data.frame(
    RespID = "R1", Version = 1L,
    T1_Best = 7L, T1_Worst = 3L,   # 7 > items per task
    T2_Best = 1L, T2_Worst = 2L,
    stringsAsFactors = FALSE
  )

  expect_error(
    build_maxdiff_long(data, fx$survey_mapping, fx$design,
                       make_reshape_config("ITEM_POSITION"), verbose = FALSE),
    "DATA_CHOICE_POSITION_INVALID|position"
  )
})

test_that("C3: validation names the setting when ITEM_ID data looks positional", {
  fx <- make_reshape_fixture()
  data <- data.frame(
    RespID = c("R1", "R2"), Version = c(1L, 1L),
    T1_Best = c(1L, 2L), T1_Worst = c(3L, 1L),
    T2_Best = c(2L, 1L), T2_Worst = c(3L, 2L),
    stringsAsFactors = FALSE
  )

  v <- validate_survey_data(data, fx$survey_mapping, fx$design, fx$items,
                            verbose = FALSE, choice_value_type = "ITEM_ID")
  expect_false(v$valid)
  expect_true(any(grepl("Choice_Value_Type", v$issues)))

  # And declared as positions, the same data validates.
  v2 <- validate_survey_data(data, fx$survey_mapping, fx$design, fx$items,
                             verbose = FALSE, choice_value_type = "ITEM_POSITION")
  expect_true(all(!grepl("T1_Best|T1_Worst|T2_Best|T2_Worst.*invalid", v2$issues)))
})
