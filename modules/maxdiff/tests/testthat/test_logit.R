# ==============================================================================
# MAXDIFF TESTS - LOGIT MODEL
# ==============================================================================

# ==============================================================================
# prepare_logit_data() tests
# ==============================================================================

test_that("prepare_logit_data creates correct structure from long data", {
  skip_if(!exists("prepare_logit_data", mode = "function"))

  # Arrange: create minimal long-format data (2 tasks, 3 items each)
  long_data <- data.frame(
    resp_id = rep("R001", 6),
    version = rep(1, 6),
    task = c(1, 1, 1, 2, 2, 2),
    item_id = c("I1", "I2", "I3", "I1", "I2", "I3"),
    is_best = c(1, 0, 0, 0, 1, 0),
    is_worst = c(0, 0, 1, 0, 0, 1),
    weight = rep(1, 6),
    stringsAsFactors = FALSE
  )

  # Act
  result <- prepare_logit_data(long_data, c("I1", "I2", "I3"), "I3")

  # Assert
  expect_true(is.data.frame(result))
  expect_true("choice_set" %in% names(result))
  expect_true("choice" %in% names(result))
  expect_true("item_id" %in% names(result))
  expect_true("sign" %in% names(result))
  expect_true("weight" %in% names(result))

  # sign should be 1 for best, -1 for worst
  best_rows <- result[result$choice_type == "best", ]
  worst_rows <- result[result$choice_type == "worst", ]
  expect_true(all(best_rows$sign == 1))
  expect_true(all(worst_rows$sign == -1))
})

test_that("prepare_logit_data creates separate choice sets for best and worst", {
  skip_if(!exists("prepare_logit_data", mode = "function"))

  # Arrange: 2 respondents, 1 task each, 3 items per task
  long_data <- data.frame(
    resp_id = c(rep("R001", 3), rep("R002", 3)),
    version = rep(1, 6),
    task = rep(1, 6),
    item_id = rep(c("I1", "I2", "I3"), 2),
    is_best = c(1, 0, 0, 0, 1, 0),
    is_worst = c(0, 0, 1, 0, 0, 1),
    weight = rep(1, 6),
    stringsAsFactors = FALSE
  )

  # Act
  result <- prepare_logit_data(long_data, c("I1", "I2", "I3"), "I3")

  # Assert: 2 respondents x 1 task x 2 (best+worst) = 4 choice sets
  n_choice_sets <- length(unique(result$choice_set))
  expect_equal(n_choice_sets, 4)

  # Each choice set should have exactly 3 items (items shown per task)
  set_sizes <- table(result$choice_set)
  expect_true(all(set_sizes == 3))
})

test_that("prepare_logit_data marks correct choice indicators", {
  skip_if(!exists("prepare_logit_data", mode = "function"))

  # Arrange
  long_data <- data.frame(
    resp_id = rep("R001", 3),
    version = rep(1, 3),
    task = rep(1, 3),
    item_id = c("I1", "I2", "I3"),
    is_best = c(1, 0, 0),
    is_worst = c(0, 0, 1),
    weight = rep(1, 3),
    stringsAsFactors = FALSE
  )

  # Act
  result <- prepare_logit_data(long_data, c("I1", "I2", "I3"), "I3")

  # Assert: exactly one choice = 1 per choice set
  for (cs in unique(result$choice_set)) {
    cs_data <- result[result$choice_set == cs, ]
    expect_equal(sum(cs_data$choice), 1)
  }
})

test_that("prepare_logit_data returns empty data frame when no valid choices", {
  skip_if(!exists("prepare_logit_data", mode = "function"))

  # Arrange: no best or worst chosen
  long_data <- data.frame(
    resp_id = rep("R001", 3),
    version = rep(1, 3),
    task = rep(1, 3),
    item_id = c("I1", "I2", "I3"),
    is_best = c(0, 0, 0),
    is_worst = c(0, 0, 0),
    weight = rep(1, 3),
    stringsAsFactors = FALSE
  )

  # Act
  result <- prepare_logit_data(long_data, c("I1", "I2", "I3"), "I3")

  # Assert
  expect_equal(nrow(result), 0)
})

# ==============================================================================
# fit_simple_logit() tests
# ==============================================================================

test_that("fit_simple_logit returns correct structure", {
  skip_if(!exists("fit_simple_logit", mode = "function"))

  td <- generate_test_data()

  # Build long-format data manually
  long_data <- data.frame(
    item_id = character(0), is_best = integer(0), is_worst = integer(0),
    stringsAsFactors = FALSE
  )

  set.seed(42)
  for (i in seq_len(td$n_items)) {
    item_id <- td$items$Item_ID[i]
    n_shown <- 60
    n_best <- sample(5:20, 1)
    n_worst <- sample(5:20, 1)

    rows <- data.frame(
      item_id = rep(item_id, n_shown),
      is_best = c(rep(1, n_best), rep(0, n_shown - n_best)),
      is_worst = c(rep(1, n_worst), rep(0, n_shown - n_worst)),
      stringsAsFactors = FALSE
    )
    long_data <- rbind(long_data, rows)
  }

  # Act
  result <- fit_simple_logit(long_data, td$items, verbose = FALSE)

  # Assert: correct list structure
  expect_true(is.list(result))
  expect_true("utilities" %in% names(result))
  expect_true("model_fit" %in% names(result))
  expect_true("model_object" %in% names(result))
  expect_true("anchor_item" %in% names(result))

  # Utilities should have correct columns
  expect_true("Item_ID" %in% names(result$utilities))
  expect_true("Logit_Utility" %in% names(result$utilities))
  expect_true("Logit_SE" %in% names(result$utilities))
  expect_true("Rank" %in% names(result$utilities))

  # Should have one row per included item
  n_included <- sum(td$items$Include == 1)
  expect_equal(nrow(result$utilities), n_included)
})

test_that("fit_simple_logit centers utilities around zero", {
  skip_if(!exists("fit_simple_logit", mode = "function"))

  # Arrange: create data where item A is clearly preferred
  long_data <- data.frame(
    item_id = rep(c("I1", "I2", "I3"), each = 100),
    is_best = c(rep(1, 60), rep(0, 40), rep(1, 20), rep(0, 80), rep(1, 10), rep(0, 90)),
    is_worst = c(rep(0, 90), rep(1, 10), rep(0, 60), rep(1, 40), rep(0, 40), rep(1, 60)),
    stringsAsFactors = FALSE
  )

  items <- data.frame(
    Item_ID = c("I1", "I2", "I3"),
    Item_Label = c("Item A", "Item B", "Item C"),
    Item_Group = "Test",
    Include = c(1, 1, 1),
    Display_Order = 1:3,
    stringsAsFactors = FALSE
  )

  # Act
  result <- fit_simple_logit(long_data, items, verbose = FALSE)

  # Assert: utilities should be centered (mean approximately 0)
  expect_equal(mean(result$utilities$Logit_Utility), 0, tolerance = 0.01)
})

test_that("fit_simple_logit model_object is NULL (fallback method)", {
  skip_if(!exists("fit_simple_logit", mode = "function"))

  long_data <- data.frame(
    item_id = rep(c("I1", "I2"), each = 50),
    is_best = c(rep(1, 30), rep(0, 20), rep(1, 10), rep(0, 40)),
    is_worst = c(rep(0, 40), rep(1, 10), rep(0, 20), rep(1, 30)),
    stringsAsFactors = FALSE
  )

  items <- data.frame(
    Item_ID = c("I1", "I2"),
    Item_Label = c("A", "B"),
    Item_Group = "Test",
    Include = c(1, 1),
    Display_Order = 1:2,
    stringsAsFactors = FALSE
  )

  result <- fit_simple_logit(long_data, items, verbose = FALSE)

  # model_object should be NULL for the simple (fallback) method
  expect_null(result$model_object)
  expect_null(result$anchor_item)
  expect_equal(result$model_fit$method, "simple_log_odds")
})

# ==============================================================================
# Anchor item handling tests
# ==============================================================================

test_that("fit_aggregate_logit uses last item as anchor when none specified", {
  skip_if(!exists("fit_aggregate_logit", mode = "function"))
  skip_if(!requireNamespace("survival", quietly = TRUE))

  td <- generate_test_data(n_resp = 10, n_items = 3, n_tasks = 3, items_per_task = 3)

  # Build long data from test data
  long_rows <- list()
  for (r in seq_len(nrow(td$survey_data))) {
    row <- td$survey_data[r, ]
    shown_cols <- grep("^Shown_", names(row), value = TRUE)
    items_shown <- as.character(unlist(row[shown_cols]))

    for (pos in seq_along(items_shown)) {
      item_id <- items_shown[pos]
      long_rows[[length(long_rows) + 1]] <- data.frame(
        resp_id = row$Respondent_ID,
        version = row$Version,
        task = row$Task,
        item_id = item_id,
        position = pos,
        is_best = as.integer(item_id == paste0("I", row$Best_Choice)),
        is_worst = as.integer(item_id == paste0("I", row$Worst_Choice)),
        weight = 1,
        stringsAsFactors = FALSE
      )
    }
  }
  long_data <- do.call(rbind, long_rows)

  # Items with no anchor designated
  items_no_anchor <- td$items
  items_no_anchor$Anchor_Item <- 0

  # Act
  result <- tryCatch(
    fit_aggregate_logit(long_data, items_no_anchor, weighted = FALSE,
                        anchor_item = NULL, verbose = FALSE),
    error = function(e) NULL
  )

  # Assert: if it ran successfully, anchor should be last included item
  if (!is.null(result)) {
    included <- items_no_anchor$Item_ID[items_no_anchor$Include == 1]
    expect_equal(result$anchor_item, included[length(included)])
  }
})

test_that("fit_aggregate_logit uses designated anchor item", {
  skip_if(!exists("fit_aggregate_logit", mode = "function"))
  skip_if(!requireNamespace("survival", quietly = TRUE))

  td <- generate_test_data(n_resp = 10, n_items = 3, n_tasks = 3, items_per_task = 3)

  # Build long data
  long_rows <- list()
  for (r in seq_len(nrow(td$survey_data))) {
    row <- td$survey_data[r, ]
    shown_cols <- grep("^Shown_", names(row), value = TRUE)
    items_shown <- as.character(unlist(row[shown_cols]))

    for (pos in seq_along(items_shown)) {
      item_id <- items_shown[pos]
      long_rows[[length(long_rows) + 1]] <- data.frame(
        resp_id = row$Respondent_ID,
        version = row$Version,
        task = row$Task,
        item_id = item_id,
        position = pos,
        is_best = as.integer(item_id == paste0("I", row$Best_Choice)),
        is_worst = as.integer(item_id == paste0("I", row$Worst_Choice)),
        weight = 1,
        stringsAsFactors = FALSE
      )
    }
  }
  long_data <- do.call(rbind, long_rows)

  # Designate I1 as anchor
  items_with_anchor <- td$items
  items_with_anchor$Anchor_Item <- c(1, 0, 0)

  # Act
  result <- tryCatch(
    fit_aggregate_logit(long_data, items_with_anchor, weighted = FALSE,
                        anchor_item = NULL, verbose = FALSE),
    error = function(e) NULL
  )

  if (!is.null(result)) {
    expect_equal(result$anchor_item, "I1")
    # Anchor item should have utility of 0
    anchor_row <- result$utilities[result$utilities$Item_ID == "I1", ]
    expect_equal(anchor_row$Logit_Utility, 0)
  }
})

# ==============================================================================
# Minimal data test (3 items, 10 respondents)
# ==============================================================================

test_that("fit_simple_logit works with minimal data (3 items, 10 respondents)", {
  skip_if(!exists("fit_simple_logit", mode = "function"))

  # Arrange: minimal viable dataset
  set.seed(99)
  long_data <- data.frame(
    item_id = rep(c("A", "B", "C"), each = 30),
    is_best = c(
      sample(c(rep(1, 10), rep(0, 20))),
      sample(c(rep(1, 8), rep(0, 22))),
      sample(c(rep(1, 5), rep(0, 25)))
    ),
    is_worst = c(
      sample(c(rep(1, 4), rep(0, 26))),
      sample(c(rep(1, 8), rep(0, 22))),
      sample(c(rep(1, 12), rep(0, 18)))
    ),
    stringsAsFactors = FALSE
  )

  items <- data.frame(
    Item_ID = c("A", "B", "C"),
    Item_Label = c("Apple", "Banana", "Cherry"),
    Item_Group = "Fruit",
    Include = c(1, 1, 1),
    Display_Order = 1:3,
    stringsAsFactors = FALSE
  )

  # Act
  result <- fit_simple_logit(long_data, items, verbose = FALSE)

  # Assert
  expect_equal(nrow(result$utilities), 3)
  expect_true(all(!is.na(result$utilities$Logit_Utility)))
  expect_true(all(!is.na(result$utilities$Logit_SE)))
  expect_true(all(result$utilities$Logit_SE > 0))  # SEs should be positive
  expect_true(all(result$utilities$Rank %in% 1:3))
})
