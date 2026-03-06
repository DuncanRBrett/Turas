# ==============================================================================
# TESTS: HTML Report Generation
# ==============================================================================

# --- Guard Validation Tests ---

test_that("validate_html_report_inputs rejects NULL results", {
  skip_if(!exists("validate_html_report_inputs", mode = "function"),
          "validate_html_report_inputs not available")

  result <- validate_html_report_inputs(NULL)

  expect_false(result$valid)
  expect_true(length(result$errors) > 0)
  expect_true(any(grepl("NULL", result$errors)))
})

test_that("validate_html_report_inputs rejects results without data", {
  skip_if(!exists("validate_html_report_inputs", mode = "function"),
          "validate_html_report_inputs not available")

  result <- validate_html_report_inputs(list(
    data = NULL,
    weight_names = "w1",
    weight_results = list(w1 = list())
  ))

  expect_false(result$valid)
  expect_true(any(grepl("data frame", result$errors)))
})

test_that("validate_html_report_inputs rejects results without weight_names", {
  skip_if(!exists("validate_html_report_inputs", mode = "function"),
          "validate_html_report_inputs not available")

  result <- validate_html_report_inputs(list(
    data = data.frame(x = 1:5),
    weight_names = character(0),
    weight_results = list()
  ))

  expect_false(result$valid)
  expect_true(any(grepl("[Nn]o weight", result$errors)))
})

test_that("validate_html_report_inputs accepts valid results", {
  skip_if(!exists("validate_html_report_inputs", mode = "function"),
          "validate_html_report_inputs not available")
  skip_if_not_installed("htmltools")

  result <- validate_html_report_inputs(list(
    data = data.frame(id = 1:10, w = runif(10)),
    weight_names = "w",
    weight_results = list(w = list(diagnostics = list()))
  ))

  expect_true(result$valid)
  expect_equal(length(result$errors), 0)
})

# --- Data Transformer Tests ---

test_that("transform_for_html creates proper structure", {
  skip_if(!exists("transform_for_html", mode = "function"),
          "transform_for_html not available")

  mock_results <- list(
    data = data.frame(id = 1:100, w1 = runif(100, 0.5, 2)),
    weight_names = "w1",
    weight_results = list(
      w1 = list(
        weights = runif(100, 0.5, 2),
        diagnostics = list(
          design_effect = 1.2,
          efficiency = 83.3,
          cv = 0.35,
          min = 0.5,
          max = 2.0,
          mean = 1.0,
          n_valid = 100,
          effective_n = 83
        )
      )
    ),
    config = list(
      general = list(project_name = "Test Project"),
      weight_specifications = data.frame(
        weight_name = "w1",
        method = "design",
        stringsAsFactors = FALSE
      )
    )
  )

  html_data <- transform_for_html(mock_results, list())

  expect_true(is.list(html_data))
  expect_true(!is.null(html_data$summary))
  expect_true(!is.null(html_data$weight_details))
  expect_equal(html_data$summary$project_name, "Test Project")
  expect_equal(html_data$summary$n_weights, 1)
  expect_equal(length(html_data$weight_details), 1)
})

# --- Table Builder Tests ---

test_that("build_summary_table produces non-empty HTML", {
  skip_if(!exists("build_summary_table", mode = "function"),
          "build_summary_table not available")

  weight_details <- list(
    list(
      weight_name = "w1",
      method = "design",
      diagnostics = list(
        sample_size = list(n_total = 100, n_valid = 100),
        effective_sample = list(design_effect = 1.2, efficiency = 83.3, effective_n = 83),
        distribution = list(min = 0.5, max = 2.0, mean = 1.0, cv = 0.35),
        quality = list(status = "GOOD", message = "Weight quality is good")
      )
    )
  )

  table <- build_summary_table(weight_details)

  expect_true(is.character(table))
  expect_true(nzchar(table))
  expect_true(grepl("<table", table))
  expect_true(grepl("w1", table))
})

# --- Chart Builder Tests ---

test_that("build_histogram_svg produces valid SVG", {
  skip_if(!exists("build_histogram_svg", mode = "function"),
          "build_histogram_svg not available")
  skip_if(!exists("build_histogram_data", mode = "function"),
          "build_histogram_data not available")

  weights <- rnorm(200, mean = 1, sd = 0.3)
  weights[weights < 0.1] <- 0.1  # ensure positive

  hist_data <- build_histogram_data(weights)
  svg <- build_histogram_svg(hist_data, "test_weight", "#1e3a5f")

  expect_true(is.character(svg))
  expect_true(nzchar(svg))
  expect_true(grepl("<svg", svg))
  expect_true(grepl("test_weight", svg))
})

test_that("build_quality_gauge_svg produces valid SVG", {
  skip_if(!exists("build_quality_gauge_svg", mode = "function"),
          "build_quality_gauge_svg not available")

  svg <- build_quality_gauge_svg("Good", 83.3)

  expect_true(is.character(svg))
  expect_true(nzchar(svg))
  expect_true(grepl("<svg", svg))
})

# --- Writer Tests ---

test_that("write_weighting_html_report rejects empty path", {
  skip_if(!exists("write_weighting_html_report", mode = "function"),
          "write_weighting_html_report not available")

  result <- write_weighting_html_report(htmltools::tags$div("test"), "")

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})

test_that("write_weighting_html_report writes file successfully", {
  skip_if(!exists("write_weighting_html_report", mode = "function"),
          "write_weighting_html_report not available")
  skip_if_not_installed("htmltools")

  output_path <- file.path(tempdir(), "test_html_report.html")
  on.exit(unlink(output_path))

  page <- htmltools::tagList(
    htmltools::tags$div(class = "test", "Test content")
  )

  result <- write_weighting_html_report(page, output_path)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(output_path))
  expect_true(result$file_size_bytes > 0)
})

# --- Integration: Full Report Generation ---

test_that("generate_weighting_html_report produces valid report from design weights", {
  skip_if(!exists("generate_weighting_html_report", mode = "function"),
          "generate_weighting_html_report not available")
  skip_if_not_installed("htmltools")
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_design_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  # Run weighting to get results
  result <- run_weighting(config_path, verbose = FALSE)
  expect_equal(result$status, "PASS")

  # Generate HTML report
  output_path <- file.path(tempdir(), "test_weighting_report.html")
  on.exit(unlink(output_path), add = TRUE)

  html_result <- generate_weighting_html_report(
    result,
    output_path,
    config = list(brand_colour = "#1e3a5f", accent_colour = "#2aa198")
  )

  expect_equal(html_result$status, "PASS")
  expect_true(file.exists(output_path))
  expect_true(html_result$file_size_bytes > 100)

  # Check HTML content
  html_content <- paste(readLines(output_path), collapse = "\n")
  expect_true(grepl("turas-report-type", html_content))
  expect_true(grepl("weighting", html_content))
  expect_true(grepl("design_weight", html_content))
})

test_that("generate_weighting_html_report handles rim weights", {
  skip_if(!exists("generate_weighting_html_report", mode = "function"),
          "generate_weighting_html_report not available")
  skip_if_not_installed("htmltools")
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 150)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_rim_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- run_weighting(config_path, verbose = FALSE)
  expect_equal(result$status, "PASS")

  output_path <- file.path(tempdir(), "test_rim_report.html")
  on.exit(unlink(output_path), add = TRUE)

  html_result <- generate_weighting_html_report(result, output_path, config = list())

  expect_equal(html_result$status, "PASS")
  expect_true(file.exists(output_path))
})

test_that("generate_weighting_html_report refuses NULL results", {
  skip_if(!exists("generate_weighting_html_report", mode = "function"),
          "generate_weighting_html_report not available")

  output_path <- file.path(tempdir(), "test_null_report.html")
  on.exit(unlink(output_path))

  html_result <- generate_weighting_html_report(NULL, output_path)

  expect_equal(html_result$status, "REFUSED")
  expect_false(file.exists(output_path))
})

test_that("generate_weighting_html_report includes notes when provided", {
  skip_if(!exists("generate_weighting_html_report", mode = "function"),
          "generate_weighting_html_report not available")
  skip_if_not_installed("htmltools")
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_config_with_notes(data_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- run_weighting(config_path, verbose = FALSE)
  expect_equal(result$status, "PASS")

  output_path <- file.path(tempdir(), "test_notes_report.html")
  on.exit(unlink(output_path), add = TRUE)

  html_result <- generate_weighting_html_report(result, output_path, config = list())

  expect_equal(html_result$status, "PASS")
  expect_true(file.exists(output_path))

  html_content <- paste(readLines(output_path), collapse = "\n")
  expect_true(grepl("Method Notes", html_content))
})

# --- New Feature Tests: Config Colours, Header, Callouts ---

test_that("build_weighting_header includes researcher and client names", {
  skip_if(!exists("build_weighting_header", mode = "function"),
          "build_weighting_header not available")

  summary <- list(project_name = "Test Project", n_weights = 2, total_n = 100)
  config <- list(researcher_name = "Jane Smith", client_name = "Acme Corp")

  header <- build_weighting_header(summary, "#1e3a5f", config)

  expect_true(grepl("Jane Smith", header))
  expect_true(grepl("Acme Corp", header))
  expect_true(grepl("Prepared by", header))
})

test_that("build_weighting_header shows only researcher when no client", {
  skip_if(!exists("build_weighting_header", mode = "function"),
          "build_weighting_header not available")

  summary <- list(project_name = "Test", n_weights = 1, total_n = 50)
  config <- list(researcher_name = "Bob", client_name = NULL)

  header <- build_weighting_header(summary, "#1e3a5f", config)

  expect_true(grepl("Prepared by Bob", header))
  expect_false(grepl(" for ", header))
})

test_that("build_weighting_header shows only client when no researcher", {
  skip_if(!exists("build_weighting_header", mode = "function"),
          "build_weighting_header not available")

  summary <- list(project_name = "Test", n_weights = 1, total_n = 50)
  config <- list(researcher_name = NULL, client_name = "BigCo")

  header <- build_weighting_header(summary, "#1e3a5f", config)

  expect_true(grepl("Prepared for BigCo", header))
})

test_that("build_weighting_header subtitle is sentence case", {
  skip_if(!exists("build_weighting_header", mode = "function"),
          "build_weighting_header not available")

  summary <- list(project_name = "Test", n_weights = 1, total_n = 50)
  header <- build_weighting_header(summary, "#1e3a5f", list())

  expect_true(grepl("Sample weighting report", header))
  expect_false(grepl("SAMPLE WEIGHTING REPORT", header))
})

test_that("build_diagnostics_table includes explanatory callout", {
  skip_if(!exists("build_diagnostics_table", mode = "function"),
          "build_diagnostics_table not available")

  diag <- list(
    sample_size = list(n_total = 100, n_valid = 95, n_na = 3, n_zero = 2),
    distribution = list(min = 0.3, q1 = 0.7, median = 1.0, q3 = 1.3,
                         max = 3.0, mean = 1.0, sd = 0.4, cv = 0.4),
    effective_sample = list(effective_n = 80, design_effect = 1.25, efficiency = 80.0)
  )

  table_html <- build_diagnostics_table(diag)

  expect_true(grepl("wt-callout", table_html))
  expect_true(grepl("Design Effect", table_html))
  expect_true(grepl("Efficiency", table_html))
  expect_true(grepl("CV", table_html))
})

test_that("summary table headers have wt-num class for alignment", {
  skip_if(!exists("build_summary_table", mode = "function"),
          "build_summary_table not available")

  weight_details <- list(
    list(
      weight_name = "w1", method = "design",
      diagnostics = list(
        sample_size = list(n_total = 100, n_valid = 100),
        effective_sample = list(design_effect = 1.2, efficiency = 83.3, effective_n = 83),
        distribution = list(min = 0.5, max = 2.0, mean = 1.0, cv = 0.35),
        quality = list(status = "GOOD", message = "OK")
      )
    )
  )

  table <- build_summary_table(weight_details)

  # Numeric column headers should have wt-num class
  expect_true(grepl('<th class="wt-num">N</th>', table))
  expect_true(grepl('<th class="wt-num">Eff\\. N</th>', table))
  expect_true(grepl('<th class="wt-num">DEFF</th>', table))
})

test_that("build_report_tab_nav includes Save Report button", {
  skip_if(!exists("build_report_tab_nav", mode = "function"),
          "build_report_tab_nav not available")

  nav <- build_report_tab_nav("#1e3a5f")

  expect_true(grepl("Save Report", nav))
  expect_true(grepl("wt-save-tab", nav))
  expect_true(grepl("saveReportHTML", nav))
})

test_that("Method Notes tab includes editable comments textarea", {
  skip_if(!exists("build_notes_panel", mode = "function"),
          "build_notes_panel not available")

  notes <- data.frame(
    Section = "Assumptions",
    Note = "Data is representative",
    stringsAsFactors = FALSE
  )

  panel <- build_notes_panel(notes)

  expect_true(grepl("wt-comments-box", panel))
  expect_true(grepl("textarea", panel))
  expect_true(grepl("analyst-comments", panel))
})

test_that("config_loader parses brand_colour and accent_colour", {
  skip_if(!exists("load_weighting_config", mode = "function"),
          "load_weighting_config not available")
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 50)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  # Create config with colours
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "General")
  general_df <- data.frame(
    Setting = c("project_name", "data_file", "output_file",
                "brand_colour", "accent_colour"),
    Value = c("Colour Test", data_path, file.path(tempdir(), "out.csv"),
              "#ff0000", "#00ff00"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "General", general_df)

  openxlsx::addWorksheet(wb, "Weight_Specifications")
  spec_df <- data.frame(
    weight_name = "design_weight", method = "design", id_column = "respondent_id",
    weight_column = "design_weight", stratum_variable = "Age",
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Weight_Specifications", spec_df)

  openxlsx::addWorksheet(wb, "Design_Targets")
  targets_df <- data.frame(
    weight_name = rep("design_weight", 3),
    stratum_variable = rep("Age", 3),
    stratum_category = c("18-34", "35-54", "55+"),
    population_size = c(30000, 40000, 30000),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Design_Targets", targets_df)

  config_path <- file.path(tempdir(), "test_colour_config.xlsx")
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  expect_equal(config$general$brand_colour, "#ff0000")
  expect_equal(config$general$accent_colour, "#00ff00")
})

test_that("config_loader warns on missing logo file", {
  skip_if(!exists("load_weighting_config", mode = "function"),
          "load_weighting_config not available")
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 50)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "General")
  general_df <- data.frame(
    Setting = c("project_name", "data_file", "output_file", "logo_file"),
    Value = c("Logo Test", data_path, file.path(tempdir(), "out.csv"),
              "nonexistent_logo.png"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "General", general_df)

  openxlsx::addWorksheet(wb, "Weight_Specifications")
  spec_df <- data.frame(
    weight_name = "design_weight", method = "design", id_column = "respondent_id",
    weight_column = "design_weight", stratum_variable = "Age",
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Weight_Specifications", spec_df)

  openxlsx::addWorksheet(wb, "Design_Targets")
  targets_df <- data.frame(
    weight_name = rep("design_weight", 3),
    stratum_variable = rep("Age", 3),
    stratum_category = c("18-34", "35-54", "55+"),
    population_size = c(30000, 40000, 30000),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Design_Targets", targets_df)

  config_path <- file.path(tempdir(), "test_logo_config.xlsx")
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  on.exit(unlink(config_path), add = TRUE)

  expect_warning(
    config <- load_weighting_config(config_path, verbose = FALSE),
    "Logo file not found"
  )
  expect_null(config$general$logo_file_resolved)
})

test_that("full HTML report includes brand colour and header features", {
  skip_if(!exists("generate_weighting_html_report", mode = "function"),
          "generate_weighting_html_report not available")
  skip_if_not_installed("htmltools")
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_design_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- run_weighting(config_path, verbose = FALSE)
  expect_equal(result$status, "PASS")

  output_path <- file.path(tempdir(), "test_features_report.html")
  on.exit(unlink(output_path), add = TRUE)

  html_result <- generate_weighting_html_report(
    result, output_path,
    config = list(
      brand_colour = "#336699",
      accent_colour = "#cc6600",
      researcher_name = "Test Researcher",
      client_name = "Test Client"
    )
  )

  expect_equal(html_result$status, "PASS")
  html_content <- paste(readLines(output_path), collapse = "\n")

  # Check brand colour applied
  expect_true(grepl("#336699", html_content))

  # Check header features
  expect_true(grepl("Test Researcher", html_content))
  expect_true(grepl("Test Client", html_content))
  expect_true(grepl("Prepared by", html_content))

  # Check callouts present
  expect_true(grepl("wt-callout", html_content))

  # Check comments box present
  expect_true(grepl("wt-comments-box", html_content))

  # Check save button in tab bar
  expect_true(grepl("wt-save-tab", html_content))
})

test_that("lazy submodule loader returns TRS refusal for missing files", {
  skip_if(!exists(".whr_load_submodules", mode = "function"),
          ".whr_load_submodules not available")

  # Temporarily point to a non-existent directory
  orig_dir <- get(".weighting_html_report_dir", envir = .GlobalEnv)
  orig_loaded <- get0(".whr_submodules_loaded", envir = .GlobalEnv)

  assign(".weighting_html_report_dir", file.path(tempdir(), "nonexistent_html_report"), envir = .GlobalEnv)
  assign(".whr_submodules_loaded", FALSE, envir = .GlobalEnv)

  on.exit({
    assign(".weighting_html_report_dir", orig_dir, envir = .GlobalEnv)
    assign(".whr_submodules_loaded", orig_loaded, envir = .GlobalEnv)
  })

  result <- .whr_load_submodules()

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_HTML_SUBMODULE_MISSING")
})
