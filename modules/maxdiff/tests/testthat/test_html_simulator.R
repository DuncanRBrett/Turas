# ==============================================================================
# MAXDIFF TESTS - HTML SIMULATOR
# ==============================================================================

test_that("validate_simulator_inputs catches missing utilities", {
  skip_if(!exists("validate_simulator_inputs", mode = "function"))

  result <- validate_simulator_inputs(NULL, list(items = data.frame(Item_ID = "A")))
  expect_false(result$valid)
  expect_true(length(result$issues) > 0)
})

test_that("validate_simulator_inputs passes with valid input", {
  skip_if(!exists("validate_simulator_inputs", mode = "function"))

  result <- validate_simulator_inputs(
    list(population_utilities = data.frame(Item_ID = "A", HB_Utility_Mean = 1)),
    list(items = data.frame(Item_ID = "A", Include = 1))
  )
  expect_true(result$valid)
})

test_that("is_valid_hex_colour validates correctly", {
  skip_if(!exists("is_valid_hex_colour", mode = "function"))

  expect_true(is_valid_hex_colour("#1e3a5f"))
  expect_true(is_valid_hex_colour("#AABBCC"))
  expect_false(is_valid_hex_colour("red"))
  expect_false(is_valid_hex_colour("#abc"))
  expect_false(is_valid_hex_colour(NULL))
  expect_false(is_valid_hex_colour(123))
})

test_that("build_simulator_data returns correct structure", {
  skip_if(!exists("build_simulator_data", mode = "function"))

  td <- generate_test_data()

  hb_results <- list(
    population_utilities = data.frame(
      Item_ID = td$items$Item_ID, Item_Label = td$items$Item_Label,
      HB_Utility_Mean = td$true_utils, HB_Utility_SD = rep(0.3, td$n_items),
      stringsAsFactors = FALSE
    ),
    individual_utilities = td$individual_utils,
    respondent_ids = sprintf("R%03d", seq_len(td$n_resp))
  )

  config <- list(
    project_settings = list(Project_Name = "Test Sim", Brand_Colour = "#1e3a5f"),
    items = td$items,
    segment_settings = data.frame(
      Segment_ID = "seg1", Segment_Label = "Segment 1", Variable_Name = "Group",
      stringsAsFactors = FALSE
    )
  )

  sim_data <- build_simulator_data(hb_results, NULL, config)

  expect_true(is.list(sim_data))
  expect_equal(sim_data$project_name, "Test Sim")
  expect_equal(length(sim_data$items), td$n_items)
  expect_equal(sim_data$n_respondents, td$n_resp)
  expect_equal(sim_data$n_items, td$n_items)

  # Each item should have id, label, utility
  first_item <- sim_data$items[[1]]
  expect_true("id" %in% names(first_item))
  expect_true("label" %in% names(first_item))
  expect_true("utility" %in% names(first_item))
})

test_that("JS files have valid syntax", {
  js_dir <- file.path(TURAS_ROOT, "modules", "maxdiff", "lib", "html_simulator", "js")
  skip_if(!dir.exists(js_dir))

  js_files <- list.files(js_dir, pattern = "\\.js$", full.names = TRUE)
  skip_if(length(js_files) == 0, "No JS files found")

  # Find node binary
  node_path <- Sys.which("node")
  if (!nzchar(node_path)) node_path <- "/usr/local/bin/node"
  if (!file.exists(node_path)) {
    skip("node not available for JS syntax checking")
  }

  for (js_file in js_files) {
    exit_code <- tryCatch(
      system2(node_path, args = c("--check", js_file), stdout = FALSE, stderr = FALSE),
      error = function(e) -1
    )

    if (exit_code != -1) {
      expect_equal(exit_code, 0, info = sprintf("JS syntax error in %s", basename(js_file)))
    }
  }
})

# ------------------------------------------------------------------------------
# The engine filters respondents by segments[variable] === value. A group-level
# SEGMENT_SETTINGS row (the shape the loader takes since Session A) used to
# become ONE filter entry with an empty value that matched nobody: choosing it
# in the simulator zeroed every share. It must expand into the data's levels.
# ------------------------------------------------------------------------------

test_that("a group-level segment row expands into one filter entry per observed level", {
  td <- generate_test_data(n_resp = 12, n_items = 4, n_tasks = 4, items_per_task = 3)
  indiv <- cbind(resp_id = sprintf("R%03d", 1:12), as.data.frame(td$individual_utils),
                 stringsAsFactors = FALSE)
  hb <- list(population_utilities = data.frame(Item_ID = td$items$Item_ID,
                                               HB_Utility_Mean = colMeans(td$individual_utils)),
             individual_utilities = indiv,
             model_fit = list(method = "empirical_bayes_shrinkage"))
  raw <- data.frame(RespID = sprintf("R%03d", 1:12),
                    Region = rep(c("North", "South", "West"), 4),
                    stringsAsFactors = FALSE)
  config <- list(
    items = td$items,
    project_settings = list(Project_Name = "Seg", Respondent_ID_Variable = "RespID"),
    segment_settings = data.frame(Segment_ID = c("Region", "Northerners"),
                                  Segment_Label = c("Region", "The north"),
                                  Variable_Name = c("Region", "Region"),
                                  Segment_Def = c("", 'Region == "North"'),
                                  Include_in_Output = 1L, stringsAsFactors = FALSE)
  )
  sd <- build_simulator_data(hb, NULL, config, raw_data = raw)

  values <- vapply(sd$segments, function(s) s$value, character(1))
  labels <- vapply(sd$segments, function(s) s$label, character(1))
  # Three levels from the group row, then the explicit one: no empty value.
  expect_equal(values, c("North", "South", "West", "North"))
  expect_equal(labels[1:3], c("Region: North", "Region: South", "Region: West"))
  expect_true(all(nzchar(values)))
  # Every respondent carries the level the filter compares against.
  expect_equal(unname(sd$individual_utils[[2]]$segments$Region), "South")

  # The estimator is named honestly for the fallback.
  expect_equal(sd$method_code, "empirical_bayes")
  expect_true(sd$approximate)
  expect_match(sd$method, "Empirical Bayes", fixed = TRUE)
  expect_match(sd$estimation_note, "not Bayesian posterior", fixed = TRUE)
})

test_that("a Stan run is named as such and not stamped approximate", {
  td <- generate_test_data(n_resp = 6, n_items = 3, n_tasks = 3, items_per_task = 3)
  indiv <- cbind(resp_id = sprintf("R%03d", 1:6), as.data.frame(td$individual_utils),
                 stringsAsFactors = FALSE)
  hb <- list(population_utilities = data.frame(Item_ID = td$items$Item_ID,
                                               HB_Utility_Mean = colMeans(td$individual_utils)),
             individual_utilities = indiv, model_fit = list(method = "cmdstanr"))
  config <- list(items = td$items, project_settings = list(Project_Name = "Stan"))
  sd <- build_simulator_data(hb, NULL, config)
  expect_equal(sd$method_code, "stan_hb")
  expect_false(sd$approximate)
  expect_match(sd$method, "Stan", fixed = TRUE)
})

test_that("per-respondent utilities are aligned to the item order, not the column order", {
  # The EB fallback's reshape() writes item columns alphabetically; the config
  # lists items in its own order; the engine pairs utilities[i] with items[i].
  items <- data.frame(Item_ID = c("ZEBRA", "APPLE", "MANGO"),
                      Item_Label = c("Zebra", "Apple", "Mango"),
                      Include = 1L, Display_Order = 1:3, stringsAsFactors = FALSE)
  indiv <- data.frame(resp_id = c("R1", "R2"),
                      APPLE = c(1.0, 1.5), MANGO = c(2.0, 2.5), ZEBRA = c(3.0, 3.5),
                      stringsAsFactors = FALSE)
  hb <- list(population_utilities = data.frame(Item_ID = items$Item_ID,
                                               HB_Utility_Mean = c(3, 1, 2)),
             individual_utilities = indiv, model_fit = list(method = "cmdstanr"))
  config <- list(items = items, project_settings = list(Project_Name = "Order"))
  sd <- build_simulator_data(hb, NULL, config)

  expect_equal(vapply(sd$items, function(it) it$id, character(1)), c("ZEBRA", "APPLE", "MANGO"))
  # utilities[i] belongs to items[i]: ZEBRA first, so 3.0 first.
  expect_equal(sd$individual_utils[[1]]$utilities, c(3.0, 1.0, 2.0))
  expect_equal(sd$individual_utils[[2]]$utilities, c(3.5, 1.5, 2.5))
  expect_equal(sd$items[[1]]$utility, 3)
})
