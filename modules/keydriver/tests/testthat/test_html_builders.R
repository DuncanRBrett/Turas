# ==============================================================================
# KEYDRIVER HTML BUILDER TESTS
# ==============================================================================
#
# Tests for HTML report builder components:
#   - 03_page_builder.R  (build_kd_insight_area, section builders)
#   - 05_chart_builder.R (SVG chart functions)
#   - 02_table_builder.R (HTML table functions)
#
# ==============================================================================

library(testthat)

context("Keydriver HTML Builders")

# ==============================================================================
# SETUP - Module path resolution & sourcing
# ==============================================================================

# module_dir and project_root are provided by helper-paths.R

# Null-coalescing operator
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Source shared TRS infrastructure
shared_lib <- file.path(project_root, "modules", "shared", "lib")
tryCatch(source(file.path(shared_lib, "trs_refusal.R")),
         error = function(e) NULL)

# Source keydriver guard (needed by page builder dependencies)
tryCatch(source(file.path(module_dir, "R", "00_guard.R")),
         error = function(e) NULL)

# Source HTML report submodules
html_report_dir <- file.path(module_dir, "lib", "html_report")
if (dir.exists(html_report_dir)) {
  for (f in list.files(html_report_dir, pattern = "\\.R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
}


# ==============================================================================
# INSIGHT AREA - build_kd_insight_area()
# ==============================================================================

test_that("build_kd_insight_area returns default '+ Add Insight' button without config", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_insight_area", mode = "function"),
          message = "build_kd_insight_area not available")

  result <- build_kd_insight_area("test-section")

  expect_true(inherits(result, "shiny.tag") || inherits(result, "shiny.tag.list"))
  html_str <- as.character(result)
  expect_true(grepl("\\+ Add Insight", html_str))
  expect_true(grepl('data-kd-insight-section="test-section"', html_str, fixed = TRUE))
})

test_that("build_kd_insight_area shows 'Edit Insight' when config has insights", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_insight_area", mode = "function"),
          message = "build_kd_insight_area not available")

  config <- list(
    insights = data.frame(
      section = "exec-summary",
      insight_text = "This is a pre-populated insight.",
      image_path = NA_character_,
      stringsAsFactors = FALSE
    )
  )

  result <- build_kd_insight_area("exec-summary", config = config)

  html_str <- as.character(result)
  expect_true(grepl("Edit Insight", html_str))
  expect_true(grepl("This is a pre-populated insight", html_str))
})

test_that("build_kd_insight_area encodes image to base64 when image_path provided", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_insight_area", mode = "function"),
          message = "build_kd_insight_area not available")

  # Create a minimal PNG file (1x1 pixel)
  tmp_png <- tempfile(fileext = ".png")
  on.exit(unlink(tmp_png), add = TRUE)

  # Write a minimal valid PNG (1x1 red pixel)
  if (requireNamespace("png", quietly = TRUE)) {
    png::writePNG(array(c(1, 0, 0), dim = c(1, 1, 3)), tmp_png)
  } else {
    # Fallback: create a minimal PNG via raw bytes
    # Minimal 1x1 PNG header
    writeBin(as.raw(c(
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,  # PNG signature
      0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
      0xde, 0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41,
      0x54, 0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0x00,
      0x00, 0x00, 0x02, 0x00, 0x01, 0xe2, 0x21, 0xbc,
      0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
      0x44, 0xae, 0x42, 0x60, 0x82
    )), tmp_png)
  }

  config <- list(
    insights = data.frame(
      section = "importance",
      insight_text = "Chart insight text",
      image_path = tmp_png,
      stringsAsFactors = FALSE
    )
  )

  result <- build_kd_insight_area("importance", config = config)

  html_str <- as.character(result)
  expect_true(grepl("data:image/png;base64,", html_str, fixed = TRUE))
  expect_true(grepl("<img", html_str))
})

test_that("build_kd_insight_area applies htmlEscape to prevent HTML injection", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_insight_area", mode = "function"),
          message = "build_kd_insight_area not available")

  malicious_text <- '<script>alert("xss")</script>'
  config <- list(
    insights = data.frame(
      section = "diagnostics",
      insight_text = malicious_text,
      image_path = NA_character_,
      stringsAsFactors = FALSE
    )
  )

  result <- build_kd_insight_area("diagnostics", config = config)

  html_str <- as.character(result)
  # The raw <script> tag must NOT appear; it should be escaped
  expect_false(grepl("<script>", html_str, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;", html_str, fixed = TRUE))
})


# ==============================================================================
# CHART BUILDERS
# ==============================================================================

test_that("build_kd_importance_chart returns htmltools tag for valid data", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_importance_chart", mode = "function"),
          message = "build_kd_importance_chart not available")

  importance <- list(
    list(rank = 1, label = "Price",   pct = 35, top3 = TRUE),
    list(rank = 2, label = "Quality", pct = 28, top3 = TRUE),
    list(rank = 3, label = "Service", pct = 20, top3 = TRUE),
    list(rank = 4, label = "Brand",   pct = 12, top3 = FALSE),
    list(rank = 5, label = "Speed",   pct = 5,  top3 = FALSE)
  )

  result <- build_kd_importance_chart(importance)

  expect_true(!is.null(result))
  expect_true(inherits(result, "shiny.tag") || inherits(result, "shiny.tag.list"))
  html_str <- as.character(result)
  expect_true(grepl("<svg", html_str))
  expect_true(grepl("Price", html_str))
})

test_that("build_kd_importance_chart returns NULL for NULL input", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_importance_chart", mode = "function"),
          message = "build_kd_importance_chart not available")

  expect_null(build_kd_importance_chart(NULL))
  expect_null(build_kd_importance_chart(list()))
})

test_that("build_kd_effect_size_chart returns htmltools tag for valid data", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_effect_size_chart", mode = "function"),
          message = "build_kd_effect_size_chart not available")

  effect_sizes <- data.frame(
    Driver = c("Price", "Quality", "Service"),
    Effect_Value = c(0.42, 0.18, 0.05),
    Effect_Size = c("Large", "Medium", "Small"),
    stringsAsFactors = FALSE
  )

  result <- build_kd_effect_size_chart(effect_sizes)

  expect_true(!is.null(result))
  expect_true(inherits(result, "shiny.tag") || inherits(result, "shiny.tag.list"))
  html_str <- as.character(result)
  expect_true(grepl("<svg", html_str))
})

test_that("build_kd_effect_size_chart returns NULL for empty data", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_effect_size_chart", mode = "function"),
          message = "build_kd_effect_size_chart not available")

  expect_null(build_kd_effect_size_chart(NULL))
  expect_null(build_kd_effect_size_chart(data.frame()))
})

test_that("build_kd_bootstrap_ci_chart returns htmltools tag for valid data", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_bootstrap_ci_chart", mode = "function"),
          message = "build_kd_bootstrap_ci_chart not available")

  bootstrap_ci <- data.frame(
    Driver = c("Price", "Quality", "Service"),
    Method = rep("Correlation", 3),
    Point_Estimate = c(0.55, 0.40, 0.25),
    CI_Lower = c(0.42, 0.28, 0.12),
    CI_Upper = c(0.68, 0.52, 0.38),
    stringsAsFactors = FALSE
  )

  result <- build_kd_bootstrap_ci_chart(bootstrap_ci)

  expect_true(!is.null(result))
  expect_true(inherits(result, "shiny.tag") || inherits(result, "shiny.tag.list"))
  html_str <- as.character(result)
  expect_true(grepl("<svg", html_str))
})

test_that("build_kd_bootstrap_ci_chart returns NULL for NULL input", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_bootstrap_ci_chart", mode = "function"),
          message = "build_kd_bootstrap_ci_chart not available")

  expect_null(build_kd_bootstrap_ci_chart(NULL))
})


# ==============================================================================
# TABLE BUILDERS
# ==============================================================================

test_that("build_kd_importance_table returns valid tag for list-of-lists input", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_importance_table", mode = "function"),
          message = "build_kd_importance_table not available")

  importance_data <- list(
    list(rank = 1, label = "Price",   importance_pct = 35, top_method = "Relative Weight"),
    list(rank = 2, label = "Quality", importance_pct = 28, top_method = "Correlation"),
    list(rank = 3, label = "Service", importance_pct = 20, top_method = "Beta Weight")
  )

  result <- build_kd_importance_table(importance_data)

  expect_true(!is.null(result))
  expect_true(inherits(result, "shiny.tag") || inherits(result, "shiny.tag.list"))
  html_str <- as.character(result)
  expect_true(nchar(html_str) > 0)
  expect_true(grepl("Price", html_str))
})

test_that("build_kd_model_summary_table returns valid tag for model info", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_model_summary_table", mode = "function"),
          message = "build_kd_model_summary_table not available")

  model_info <- list(
    r_squared = 0.6543,
    adj_r_squared = 0.6321,
    f_statistic = 42.15,
    p_value = 0.00001,
    rmse = 1.234,
    n = 200,
    n_drivers = 5
  )

  result <- build_kd_model_summary_table(model_info)

  expect_true(!is.null(result))
  expect_true(inherits(result, "shiny.tag") || inherits(result, "shiny.tag.list"))
  html_str <- as.character(result)
  expect_true(grepl("0.6543", html_str))
})

test_that("build_kd_model_summary_table returns NULL for NULL input", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_model_summary_table", mode = "function"),
          message = "build_kd_model_summary_table not available")

  expect_null(build_kd_model_summary_table(NULL))
  expect_null(build_kd_model_summary_table(list()))
})

test_that("build_kd_vif_table returns valid tag for named numeric vector", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_vif_table", mode = "function"),
          message = "build_kd_vif_table not available")

  vif_values <- c(Price = 1.23, Quality = 3.45, Service = 7.89, Brand = 12.5)

  result <- build_kd_vif_table(vif_values)

  expect_true(!is.null(result))
  expect_true(inherits(result, "shiny.tag") || inherits(result, "shiny.tag.list"))
  html_str <- as.character(result)
  # Should contain concern levels
  expect_true(grepl("None", html_str) || grepl("Moderate", html_str) || grepl("High", html_str))
})

test_that("build_kd_vif_table returns NULL for NULL input", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_vif_table", mode = "function"),
          message = "build_kd_vif_table not available")

  expect_null(build_kd_vif_table(NULL))
})


# ==============================================================================
# SECTION BUILDERS (v10.4) - NULL return when data missing
# ==============================================================================

test_that("build_kd_elastic_net_section returns NULL when elastic_net is missing", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_elastic_net_section", mode = "function"),
          message = "build_kd_elastic_net_section not available")

  html_data <- list(elastic_net = NULL)
  expect_null(build_kd_elastic_net_section(html_data))
})

test_that("build_kd_elastic_net_section returns valid tag when data present", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_elastic_net_section", mode = "function"),
          message = "build_kd_elastic_net_section not available")

  html_data <- list(
    elastic_net = list(
      alpha = 0.5,
      selected_drivers = c("x1", "x2", "x3"),
      coefficients = data.frame(
        Driver = c("x1", "x2", "x3", "x4"),
        Coefficient_1se = c(0.45, 0.30, 0.12, 0.00),
        Importance_Pct = c(40, 30, 20, 10),
        Selected_1se = c(TRUE, TRUE, TRUE, FALSE),
        stringsAsFactors = FALSE
      )
    )
  )

  result <- build_kd_elastic_net_section(html_data)

  expect_true(!is.null(result))
  expect_true(inherits(result, "shiny.tag") || inherits(result, "shiny.tag.list"))
  html_str <- as.character(result)
  expect_true(grepl("Elastic Net", html_str))
  expect_true(grepl("Retained", html_str))
  expect_true(grepl("Zeroed", html_str))
})

test_that("build_kd_gam_section returns NULL when gam data is missing", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_gam_section", mode = "function"),
          message = "build_kd_gam_section not available")

  html_data <- list(gam = NULL)
  expect_null(build_kd_gam_section(html_data))
})

test_that("build_kd_nca_section returns NULL when nca data is missing", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_nca_section", mode = "function"),
          message = "build_kd_nca_section not available")

  html_data <- list(nca = NULL)
  expect_null(build_kd_nca_section(html_data))
})

test_that("build_kd_nca_section returns valid tag when data present", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_nca_section", mode = "function"),
          message = "build_kd_nca_section not available")

  html_data <- list(
    nca = list(
      n_necessary = 2,
      n_analysed = 4,
      nca_summary = data.frame(
        Driver = c("x1", "x2", "x3", "x4"),
        NCA_Effect_Size = c(0.35, 0.22, 0.08, 0.02),
        NCA_p_value = c(0.001, 0.012, 0.450, 0.890),
        Is_Necessary = c(TRUE, TRUE, FALSE, FALSE),
        Classification = c("Necessary Condition", "Necessary Condition",
                           "Not Necessary", "Not Necessary"),
        stringsAsFactors = FALSE
      )
    )
  )

  result <- build_kd_nca_section(html_data)

  expect_true(!is.null(result))
  html_str <- as.character(result)
  expect_true(grepl("Necessary Condition Analysis", html_str))
  expect_true(grepl("Necessary Condition", html_str))
})

test_that("build_kd_dominance_section returns NULL when dominance data is missing", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_dominance_section", mode = "function"),
          message = "build_kd_dominance_section not available")

  html_data <- list(dominance = NULL)
  expect_null(build_kd_dominance_section(html_data))
})

test_that("build_kd_dominance_section returns valid tag when data present", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_dominance_section", mode = "function"),
          message = "build_kd_dominance_section not available")

  html_data <- list(
    dominance = list(
      total_r_squared = 0.654,
      n_drivers = 3,
      summary = data.frame(
        Rank = c(1, 2, 3),
        Driver = c("x1", "x2", "x3"),
        General_Dominance = c(0.30, 0.22, 0.12),
        General_Pct = c(46.9, 34.4, 18.7),
        stringsAsFactors = FALSE
      )
    )
  )

  result <- build_kd_dominance_section(html_data)

  expect_true(!is.null(result))
  html_str <- as.character(result)
  expect_true(grepl("Dominance Analysis", html_str))
  expect_true(grepl("0.654", html_str) || grepl("General", html_str))
})
