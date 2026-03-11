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
