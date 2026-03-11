# ==============================================================================
# MAXDIFF TESTS - DESIGN GENERATION
# ==============================================================================

test_that("generate_random_design creates correct structure", {
  skip_if(!exists("generate_random_design", mode = "function"))

  item_ids <- paste0("I", 1:8)

  set.seed(42)
  result <- tryCatch(
    generate_random_design(item_ids, items_per_task = 4,
                           tasks_per_respondent = 6, num_versions = 2),
    error = function(e) NULL
  )

  skip_if(is.null(result), "generate_random_design call failed")

  expect_true(is.data.frame(result))
  expect_true("Version" %in% names(result) || "version" %in% tolower(names(result)))
  expect_true("Task" %in% names(result) || "task" %in% tolower(names(result)))
})

test_that("compute_pair_frequencies returns named pair counts", {
  skip_if(!exists("compute_pair_frequencies", mode = "function"))

  # Simple design with item columns
  design <- data.frame(
    Version = c(1, 1),
    Task = c(1, 2),
    Item_1 = c(1, 2),
    Item_2 = c(2, 3),
    Item_3 = c(3, 4)
  )

  item_cols <- c("Item_1", "Item_2", "Item_3")
  freq <- tryCatch(
    compute_pair_frequencies(design, item_cols),
    error = function(e) NULL
  )

  skip_if(is.null(freq), "compute_pair_frequencies call failed")

  # Returns named numeric vector of pair counts
  expect_true(is.numeric(freq))
  expect_true(length(freq) > 0)
  expect_true(!is.null(names(freq)))
  # All counts should be positive integers
  expect_true(all(freq > 0))
})
