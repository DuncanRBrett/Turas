# ==============================================================================
# TABS MODULE - DASHBOARD BUILDER TESTS
# ==============================================================================
#
# Tests for summary dashboard component builders in
# lib/html_report/06_dashboard_builder.R and 06b_dashboard_styling.R:
#   - build_colour_thresholds()
#   - get_thresholds_for_type()
#   - build_metadata_strip()
#   - build_colour_legend()
#   - build_dashboard_text_boxes()
#   - format_gauge_value()
#   - build_svg_gauge()
#   - get_gauge_colour()
#   - build_dashboard_panel() (integration)
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_dashboard_builder.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

# Source shared + tabs dependencies
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))

# Source HTML report submodules
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/html_report/99_html_report_main.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

#' Create a minimal config object for testing dashboard builders
make_test_config <- function(brand_colour = "#323367",
                              dashboard_metrics = "NET POSITIVE",
                              ...) {
  cfg <- list(
    brand_colour = brand_colour,
    dashboard_metrics = dashboard_metrics,
    project_title = "Test Project",
    company_name = "Test Company",
    fieldwork_dates = "Jan-Feb 2025"
  )
  extras <- list(...)
  for (n in names(extras)) cfg[[n]] <- extras[[n]]
  cfg
}

#' Create minimal metadata for testing
make_test_metadata <- function() {
  list(
    total_n = 1000,
    fieldwork_dates = "Jan-Feb 2025",
    n_questions = 15,
    banner_group_count = 3,
    banner_group_names = c("Gender", "Age", "Region")
  )
}

#' Create a minimal metric object for testing
make_test_metric <- function(q_code = "Q1",
                              question_text = "Overall Satisfaction",
                              metric_type = "net_positive",
                              metric_label = "NET POSITIVE",
                              total_value = 35) {
  list(
    q_code = q_code,
    question_text = question_text,
    metric_type = metric_type,
    metric_label = metric_label,
    values = list("TOTAL::Total" = total_value)
  )
}

#' Create a minimal banner_info for testing
make_test_banner_info <- function() {
  list(
    columns = c("Total", "Male", "Female"),
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    letters = c("A", "B", "C"),
    column_to_banner = c("TOTAL::Total" = "TOTAL",
                         "Gender::Male" = "Gender",
                         "Gender::Female" = "Gender"),
    key_to_display = c("TOTAL::Total" = "Total",
                       "Gender::Male" = "Male",
                       "Gender::Female" = "Female"),
    banner_headers = data.frame(
      label = c("Total", "Gender"),
      start_col = c(1, 2),
      end_col = c(1, 3),
      stringsAsFactors = FALSE
    ),
    banner_info = list(
      Gender = list(
        internal_keys = c("Gender::Male", "Gender::Female"),
        columns = c("Male", "Female"),
        letters = c("B", "C"),
        question = data.frame(
          QuestionCode = "Gender",
          QuestionText = "What is your gender?",
          stringsAsFactors = FALSE
        )
      )
    )
  )
}


# ==============================================================================
# build_colour_thresholds()
# ==============================================================================

test_that("build_colour_thresholds returns correct structure with defaults", {
  cfg <- make_test_config()
  thresholds <- build_colour_thresholds(cfg)

  expect_type(thresholds, "list")
  expect_true(all(c("net", "mean", "index", "custom") %in% names(thresholds)))

  # Check net defaults
  expect_equal(thresholds$net$green, 30)
  expect_equal(thresholds$net$amber, 0)
  expect_equal(thresholds$net$scale, 200)

  # Check mean defaults
  expect_equal(thresholds$mean$green, 7)
  expect_equal(thresholds$mean$amber, 5)
  expect_equal(thresholds$mean$scale, 10)
})

test_that("build_colour_thresholds uses config overrides", {
  cfg <- make_test_config(
    dashboard_green_net = 40,
    dashboard_amber_net = 10,
    dashboard_green_mean = 8,
    dashboard_scale_mean = 100
  )
  thresholds <- build_colour_thresholds(cfg)

  expect_equal(thresholds$net$green, 40)
  expect_equal(thresholds$net$amber, 10)
  expect_equal(thresholds$mean$green, 8)
  expect_equal(thresholds$mean$scale, 100)
})


# ==============================================================================
# get_thresholds_for_type()
# ==============================================================================

test_that("get_thresholds_for_type maps metric types correctly", {
  thresholds <- build_colour_thresholds(make_test_config())

  expect_equal(get_thresholds_for_type("net_positive", thresholds), thresholds$net)
  expect_equal(get_thresholds_for_type("nps_score", thresholds), thresholds$net)
  expect_equal(get_thresholds_for_type("average", thresholds), thresholds$mean)
  expect_equal(get_thresholds_for_type("index", thresholds), thresholds$index)
  expect_equal(get_thresholds_for_type("custom", thresholds), thresholds$custom)
})

test_that("get_thresholds_for_type falls back to mean for unknown type", {
  thresholds <- build_colour_thresholds(make_test_config())

  result <- get_thresholds_for_type("unknown_type", thresholds)

  expect_equal(result, thresholds$mean)
})


# ==============================================================================
# get_gauge_colour()
# ==============================================================================

test_that("get_gauge_colour returns green for strong values", {
  thresholds <- build_colour_thresholds(make_test_config())

  # NET >= 30 is green
  expect_equal(get_gauge_colour(35, "net_positive", thresholds), "#4a7c6f")
  expect_equal(get_gauge_colour(30, "net_positive", thresholds), "#4a7c6f")
})

test_that("get_gauge_colour returns amber for moderate values", {
  thresholds <- build_colour_thresholds(make_test_config())

  # NET >= 0 but < 30 is amber
  expect_equal(get_gauge_colour(15, "net_positive", thresholds), "#c9a96e")
  expect_equal(get_gauge_colour(0, "net_positive", thresholds), "#c9a96e")
})

test_that("get_gauge_colour returns red for concern values", {
  thresholds <- build_colour_thresholds(make_test_config())

  # NET < 0 is red
  expect_equal(get_gauge_colour(-5, "net_positive", thresholds), "#b85450")
  expect_equal(get_gauge_colour(-50, "net_positive", thresholds), "#b85450")
})

test_that("get_gauge_colour handles NA values", {
  thresholds <- build_colour_thresholds(make_test_config())

  expect_equal(get_gauge_colour(NA, "net_positive", thresholds), "#94a3b8")
})


# ==============================================================================
# format_gauge_value()
# ==============================================================================

test_that("format_gauge_value formats NET with sign prefix", {
  expect_equal(format_gauge_value(35, "net_positive"), "+35")
  expect_equal(format_gauge_value(-10, "net_positive"), "-10")
  expect_equal(format_gauge_value(0, "net_positive"), "+0")
})

test_that("format_gauge_value formats NPS with sign prefix", {
  expect_equal(format_gauge_value(42, "nps_score"), "+42")
  expect_equal(format_gauge_value(-15, "nps_score"), "-15")
})

test_that("format_gauge_value formats custom as percentage", {
  expect_equal(format_gauge_value(65, "custom"), "65%")
  expect_equal(format_gauge_value(0, "custom"), "0%")
})

test_that("format_gauge_value formats mean with 1 decimal", {
  result <- format_gauge_value(7.2, "average")
  expect_true(grepl("7\\.2", result))
})

test_that("format_gauge_value returns N/A for NULL, NA, or non-numeric", {
  expect_equal(format_gauge_value(NULL, "net_positive"), "N/A")
  expect_equal(format_gauge_value(NA, "average"), "N/A")
  expect_equal(format_gauge_value("abc", "net_positive"), "N/A")
})


# ==============================================================================
# build_metadata_strip()
# ==============================================================================

test_that("build_metadata_strip returns htmltools tag", {
  metadata <- make_test_metadata()

  result <- build_metadata_strip(metadata, "#323367")

  expect_true(inherits(result, "shiny.tag"))
  html_str <- as.character(result)
  expect_true(grepl("1,000", html_str))
  expect_true(grepl("Jan-Feb 2025", html_str))
  expect_true(grepl("15", html_str))
  expect_true(grepl("3", html_str))
})

test_that("build_metadata_strip handles NULL total_n", {
  metadata <- make_test_metadata()
  metadata$total_n <- NULL

  result <- build_metadata_strip(metadata, "#323367")

  html_str <- as.character(result)
  expect_true(grepl("N/A", html_str))
})


# ==============================================================================
# build_colour_legend()
# ==============================================================================

test_that("build_colour_legend returns HTML with colour key", {
  thresholds <- build_colour_thresholds(make_test_config())

  result <- build_colour_legend(thresholds, make_test_config())

  html_str <- as.character(result)
  expect_true(grepl("Colour Key", html_str))
  expect_true(grepl("Strong", html_str))
  expect_true(grepl("Moderate", html_str))
  expect_true(grepl("Concern", html_str))
})

test_that("build_colour_legend includes Mean thresholds when configured", {
  cfg <- make_test_config(dashboard_metrics = "NET POSITIVE, Mean")
  thresholds <- build_colour_thresholds(cfg)

  result <- build_colour_legend(thresholds, cfg)

  html_str <- as.character(result)
  expect_true(grepl("Mean", html_str))
})


# ==============================================================================
# build_dashboard_text_boxes()
# ==============================================================================

test_that("build_dashboard_text_boxes returns two text boxes", {
  result <- build_dashboard_text_boxes("#323367", make_test_config())

  html_str <- as.character(result)
  expect_true(grepl("Background", html_str))
  expect_true(grepl("Executive Summary", html_str))
})

test_that("build_dashboard_text_boxes includes prefilled text from config", {
  cfg <- make_test_config(
    background_text = "This is background content.",
    executive_summary = "Key finding here."
  )

  result <- build_dashboard_text_boxes("#323367", cfg)

  html_str <- as.character(result)
  expect_true(grepl("This is background content", html_str))
  expect_true(grepl("Key finding here", html_str))
})


# ==============================================================================
# build_svg_gauge()
# ==============================================================================

test_that("build_svg_gauge returns SVG markup", {
  thresholds <- build_colour_thresholds(make_test_config())

  result <- build_svg_gauge(35, "net_positive", "#323367", thresholds)

  expect_type(result, "character")
  expect_true(grepl("<svg", result))
  expect_true(grepl("</svg>", result))
})

test_that("build_svg_gauge handles NA value", {
  thresholds <- build_colour_thresholds(make_test_config())

  result <- build_svg_gauge(NA, "net_positive", "#323367", thresholds)

  expect_true(grepl("N/A", result))
})

test_that("build_svg_gauge supports hero mode", {
  thresholds <- build_colour_thresholds(make_test_config())

  result_normal <- build_svg_gauge(35, "net_positive", "#323367", thresholds,
                                    is_hero = FALSE)
  result_hero <- build_svg_gauge(35, "net_positive", "#323367", thresholds,
                                  is_hero = TRUE)

  # Hero has larger width attribute
  expect_true(grepl('width="240"', result_hero))
  expect_true(grepl('width="130"', result_normal))
})
