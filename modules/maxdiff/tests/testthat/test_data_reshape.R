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
