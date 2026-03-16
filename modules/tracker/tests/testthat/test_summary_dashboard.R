# ==============================================================================
# Tests for Tracker Summary Dashboard (03c_summary_builder.R)
# ==============================================================================
# Covers: build_metadata_strip, build_kpi_hero_cards, build_wave_pulse_bar,
#         build_sig_heatmap, build_sig_changes_section,
#         build_summary_type_filter, build_summary_metrics_table
# ==============================================================================

library(testthat)
context("Tracker Summary Dashboard")

# --- Source dependencies ------------------------------------------------------

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

palette_path <- file.path(turas_root, "modules", "shared", "lib", "colour_palettes.R")
if (file.exists(palette_path)) source(palette_path)

source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "html_report", "05_chart_builder.R"))
source(file.path(tracker_root, "lib", "html_report", "01_data_transformer.R"))
source(file.path(tracker_root, "lib", "html_report", "03c_summary_builder.R"))

# --- Helpers ------------------------------------------------------------------

#' Build a mock html_data list with controllable metric / wave counts
mock_html_data <- function(n_metrics = 2, n_waves = 3) {
  waves <- paste0("W", seq_len(n_waves))
  wave_labels <- paste("Wave", seq_len(n_waves))
  wave_lookup <- setNames(wave_labels, waves)

  metric_rows <- list()
  for (i in seq_len(n_metrics)) {
    vals <- sort(runif(n_waves, 40, 80))
    cells <- list()
    for (w in seq_along(waves)) {
      cells[[waves[w]]] <- list(
        value = vals[w],
        display_value = sprintf("%.1f%%", vals[w]),
        n = 500L,
        change_vs_prev = if (w > 1) vals[w] - vals[w - 1] else NA_real_,
        sig_vs_prev = if (w > 1 && i == 1) TRUE else FALSE
      )
    }
    metric_rows[[i]] <- list(
      metric_id = paste0("Q", i, "_pct"),
      metric_label = paste("Metric", i),
      metric_name = "top2_box",
      section = "Section A",
      segment_cells = list(Total = cells)
    )
  }

  list(
    metadata = list(
      project_name = "Test Project",
      generated_at = Sys.time(),
      confidence_level = 0.95
    ),
    n_metrics = n_metrics,
    waves = waves,
    wave_labels = wave_labels,
    wave_lookup = wave_lookup,
    baseline_wave = waves[1],
    segments = c("Total"),
    metric_rows = metric_rows
  )
}

mock_config <- list(settings = list(brand_colour = "#323367"))


# ==============================================================================
# build_metadata_strip
# ==============================================================================

test_that("build_metadata_strip returns div with class tk-meta-strip", {
  html <- as.character(build_metadata_strip(5, 3, 200L, "", "Wave 1", "Wave 3"))
  expect_true(grepl("tk-meta-strip", html))
})

test_that("build_metadata_strip contains 4 tk-meta-card divs", {
  html <- as.character(build_metadata_strip(5, 3, 200L, "", "Wave 1", "Wave 3"))
  card_count <- length(gregexpr("tk-meta-card", html)[[1]])
  expect_equal(card_count, 4L)
})

test_that("build_metadata_strip shows em dash when latest_n is NA", {
  html <- as.character(build_metadata_strip(5, 3, NA, "", "Wave 1", "Wave 3"))
  # Unicode em dash U+2014
  expect_true(grepl("\u2014", html))
})

test_that("build_metadata_strip shows fieldwork text when provided", {
  html <- as.character(build_metadata_strip(5, 3, 200L, "Jan 2025 \u2013 Mar 2025",
                                            "Wave 1", "Wave 3"))
  expect_true(grepl("Fieldwork", html))
  expect_true(grepl("Jan 2025", html))
})

test_that("build_metadata_strip shows baseline arrow latest when no fieldwork", {
  html <- as.character(build_metadata_strip(5, 3, 200L, "", "Wave 1", "Wave 3"))
  # Should show Wave 1 -> Wave 3 direction and label "Baseline"

  expect_true(grepl("Wave 1", html))
  expect_true(grepl("Wave 3", html))
  expect_true(grepl("Baseline", html))
})


# ==============================================================================
# build_kpi_hero_cards
# ==============================================================================

test_that("build_kpi_hero_cards returns tk-hero-strip", {
  hd <- mock_html_data(n_metrics = 2, n_waves = 3)
  html <- as.character(build_kpi_hero_cards(hd, mock_config))
  expect_true(grepl("tk-hero-strip", html))
})

test_that("build_kpi_hero_cards contains one card per metric", {
  hd <- mock_html_data(n_metrics = 4, n_waves = 3)
  html <- as.character(build_kpi_hero_cards(hd, mock_config))
  card_count <- length(gregexpr("tk-hero-card", html)[[1]])
  expect_equal(card_count, 4L)
})

test_that("build_kpi_hero_cards respects hero_filter config", {
  hd <- mock_html_data(n_metrics = 3, n_waves = 3)
  cfg <- list(settings = list(
    brand_colour = "#323367",
    dashboard_hero_metrics = "Q1_pct,Q3_pct"
  ))
  html <- as.character(build_kpi_hero_cards(hd, cfg))
  card_count <- length(gregexpr("tk-hero-card", html)[[1]])
  expect_equal(card_count, 2L)
})

test_that("build_kpi_hero_cards returns empty div for zero metrics", {
  hd <- mock_html_data(n_metrics = 0, n_waves = 3)
  hd$metric_rows <- list()
  html <- as.character(build_kpi_hero_cards(hd, mock_config))
  expect_false(grepl("tk-hero-strip", html))
})

test_that("build_kpi_hero_cards shows sparkline when 2+ waves", {
  hd <- mock_html_data(n_metrics = 1, n_waves = 3)
  html <- as.character(build_kpi_hero_cards(hd, mock_config))
  expect_true(grepl("tk-hero-sparkline", html))
  # Sparkline should contain an SVG element
  expect_true(grepl("<svg", html, fixed = TRUE))
})

test_that("build_kpi_hero_cards shows trend arrow for increasing metric", {
  hd <- mock_html_data(n_metrics = 1, n_waves = 2)
  # Force an increase: ensure latest > previous
  hd$metric_rows[[1]]$segment_cells$Total$W1$value <- 40
  hd$metric_rows[[1]]$segment_cells$Total$W1$display_value <- "40.0%"
  hd$metric_rows[[1]]$segment_cells$Total$W2$value <- 60
  hd$metric_rows[[1]]$segment_cells$Total$W2$display_value <- "60.0%"
  hd$metric_rows[[1]]$segment_cells$Total$W2$change_vs_prev <- 20
  hd$metric_rows[[1]]$segment_cells$Total$W2$sig_vs_prev <- TRUE

  html <- as.character(build_kpi_hero_cards(hd, mock_config))
  expect_true(grepl("tk-hero-trend-up", html))
  # Up arrow U+25B2
  expect_true(grepl("\u25B2", html))
})

test_that("build_kpi_hero_cards shows trend arrow for decreasing metric", {
  hd <- mock_html_data(n_metrics = 1, n_waves = 2)
  hd$metric_rows[[1]]$segment_cells$Total$W1$value <- 60
  hd$metric_rows[[1]]$segment_cells$Total$W1$display_value <- "60.0%"
  hd$metric_rows[[1]]$segment_cells$Total$W2$value <- 40
  hd$metric_rows[[1]]$segment_cells$Total$W2$display_value <- "40.0%"
  hd$metric_rows[[1]]$segment_cells$Total$W2$change_vs_prev <- -20
  hd$metric_rows[[1]]$segment_cells$Total$W2$sig_vs_prev <- TRUE

  html <- as.character(build_kpi_hero_cards(hd, mock_config))
  expect_true(grepl("tk-hero-trend-down", html))
  # Down arrow U+25BC
  expect_true(grepl("\u25BC", html))
})

test_that("build_kpi_hero_cards stable metric has no trend-up or trend-down", {
  hd <- mock_html_data(n_metrics = 1, n_waves = 2)
  hd$metric_rows[[1]]$segment_cells$Total$W2$change_vs_prev <- 0
  hd$metric_rows[[1]]$segment_cells$Total$W2$sig_vs_prev <- FALSE

  html <- as.character(build_kpi_hero_cards(hd, mock_config))
  expect_true(grepl("tk-hero-trend-stable", html))
  expect_false(grepl("tk-hero-trend-up", html))
  expect_false(grepl("tk-hero-trend-down", html))
})


# ==============================================================================
# build_wave_pulse_bar
# ==============================================================================

test_that("build_wave_pulse_bar returns tk-pulse-bar", {
  hd <- mock_html_data(n_metrics = 3, n_waves = 3)
  html <- as.character(build_wave_pulse_bar(hd))
  expect_true(grepl("tk-pulse-bar", html))
})

test_that("build_wave_pulse_bar counts sig increases/decreases/stable correctly", {
  hd <- mock_html_data(n_metrics = 3, n_waves = 2)
  # Metric 1: sig increase
  hd$metric_rows[[1]]$segment_cells$Total$W2$change_vs_prev <- 5
  hd$metric_rows[[1]]$segment_cells$Total$W2$sig_vs_prev <- TRUE
  # Metric 2: sig decrease
  hd$metric_rows[[2]]$segment_cells$Total$W2$change_vs_prev <- -5
  hd$metric_rows[[2]]$segment_cells$Total$W2$sig_vs_prev <- TRUE
  # Metric 3: stable (no sig)
  hd$metric_rows[[3]]$segment_cells$Total$W2$change_vs_prev <- 1
  hd$metric_rows[[3]]$segment_cells$Total$W2$sig_vs_prev <- FALSE

  html <- as.character(build_wave_pulse_bar(hd))
  expect_true(grepl("tk-pulse-up", html))
  expect_true(grepl("tk-pulse-down", html))
  expect_true(grepl("1 significant increase", html))
  expect_true(grepl("1 significant decrease", html))
  expect_true(grepl("1 stable", html))
})

test_that("build_wave_pulse_bar returns empty div for single wave", {
  hd <- mock_html_data(n_metrics = 2, n_waves = 1)
  html <- as.character(build_wave_pulse_bar(hd))
  expect_false(grepl("tk-pulse-bar", html))
})


# ==============================================================================
# build_sig_heatmap
# ==============================================================================

test_that("build_sig_heatmap returns heatmap-section", {
  hd <- mock_html_data(n_metrics = 3, n_waves = 3)
  html <- as.character(build_sig_heatmap(hd, mock_config))
  expect_true(grepl("tk-heatmap-section", html))
})

test_that("build_sig_heatmap rows match metric count", {
  hd <- mock_html_data(n_metrics = 4, n_waves = 3)
  html <- as.character(build_sig_heatmap(hd, mock_config))
  row_count <- length(gregexpr("tk-heatmap-row", html)[[1]])
  expect_equal(row_count, 4L)
})

test_that("build_sig_heatmap returns empty div for single wave", {
  hd <- mock_html_data(n_metrics = 3, n_waves = 1)
  html <- as.character(build_sig_heatmap(hd, mock_config))
  expect_false(grepl("tk-heatmap-section", html))
})

test_that("build_sig_heatmap colour-codes sig up cells", {
  hd <- mock_html_data(n_metrics = 1, n_waves = 2)
  hd$metric_rows[[1]]$segment_cells$Total$W2$change_vs_prev <- 10
  hd$metric_rows[[1]]$segment_cells$Total$W2$sig_vs_prev <- TRUE

  html <- as.character(build_sig_heatmap(hd, mock_config))
  expect_true(grepl("tk-heatmap-up", html))
})

test_that("build_sig_heatmap colour-codes sig down cells", {
  hd <- mock_html_data(n_metrics = 1, n_waves = 2)
  hd$metric_rows[[1]]$segment_cells$Total$W2$change_vs_prev <- -10
  hd$metric_rows[[1]]$segment_cells$Total$W2$sig_vs_prev <- TRUE

  html <- as.character(build_sig_heatmap(hd, mock_config))
  expect_true(grepl("tk-heatmap-down", html))
})


# ==============================================================================
# build_sig_changes_section
# ==============================================================================

test_that("build_sig_changes_section shows cards for sig changes", {
  hd <- mock_html_data(n_metrics = 2, n_waves = 3)
  # Metric 1 has sig_vs_prev = TRUE by default in mock
  html <- as.character(build_sig_changes_section(hd))
  expect_true(grepl("dash-sig-card", html))
  expect_true(grepl("Significant Changes", html))
})

test_that("build_sig_changes_section shows empty state when no sig changes", {
  hd <- mock_html_data(n_metrics = 2, n_waves = 3)
  # Disable all significance flags
  for (i in seq_along(hd$metric_rows)) {
    for (wid in hd$waves) {
      hd$metric_rows[[i]]$segment_cells$Total[[wid]]$sig_vs_prev <- FALSE
    }
  }
  html <- as.character(build_sig_changes_section(hd))
  expect_true(grepl("no significant findings", html, ignore.case = TRUE))
  expect_false(grepl("dash-sig-card", html))
})

test_that("build_sig_changes_section shows direction symbols", {
  hd <- mock_html_data(n_metrics = 1, n_waves = 2)
  hd$metric_rows[[1]]$segment_cells$Total$W2$change_vs_prev <- 5
  hd$metric_rows[[1]]$segment_cells$Total$W2$sig_vs_prev <- TRUE

  html <- as.character(build_sig_changes_section(hd))
  # Should contain up triangle and "increase"
  expect_true(grepl("\u25B2", html))
  expect_true(grepl("increase", html, ignore.case = TRUE))
})


# ==============================================================================
# build_summary_type_filter
# ==============================================================================

test_that("build_summary_type_filter returns empty string for single type", {
  hd <- mock_html_data(n_metrics = 2, n_waves = 3)
  # Both metrics are top2_box -> pct type
  result <- build_summary_type_filter(hd)
  expect_equal(result, "")
})

test_that("build_summary_type_filter returns chips when multiple types present", {
  hd <- mock_html_data(n_metrics = 2, n_waves = 3)
  # Make second metric a mean type
  hd$metric_rows[[2]]$metric_name <- "mean"
  html <- build_summary_type_filter(hd)
  expect_true(grepl("summary-type-filter", html))
  expect_true(grepl("summary-type-chip", html))
  # Should have "All" chip plus at least pct and mean
  expect_true(grepl("All", html))
})


# ==============================================================================
# build_summary_metrics_table
# ==============================================================================

test_that("build_summary_metrics_table returns table with correct wave columns", {
  hd <- mock_html_data(n_metrics = 2, n_waves = 4)
  html <- as.character(build_summary_metrics_table(hd))
  expect_true(grepl("summary-metrics-table", html))
  # Should have a header for each wave
  for (wl in hd$wave_labels) {
    expect_true(grepl(wl, html, fixed = TRUE))
  }
})

test_that("build_summary_metrics_table shows section headers", {
  hd <- mock_html_data(n_metrics = 2, n_waves = 3)
  html <- as.character(build_summary_metrics_table(hd))
  expect_true(grepl("tk-section-row", html))
  expect_true(grepl("Section A", html))
})

test_that("build_summary_metrics_table shows low base warning for n < 30", {
  hd <- mock_html_data(n_metrics = 1, n_waves = 2)
  # Set n to a low value for the latest wave
  hd$metric_rows[[1]]$segment_cells$Total$W2$n <- 15L
  html <- as.character(build_summary_metrics_table(hd, min_base = 30L))
  expect_true(grepl("tk-low-base", html))
})

test_that("build_summary_metrics_table has base row at top", {
  hd <- mock_html_data(n_metrics = 2, n_waves = 3)
  html <- as.character(build_summary_metrics_table(hd))
  expect_true(grepl("tk-base-row", html))
  expect_true(grepl("Base \\(n=\\)", html))
})

test_that("build_summary_metrics_table displays metric labels", {
  hd <- mock_html_data(n_metrics = 3, n_waves = 2)
  html <- as.character(build_summary_metrics_table(hd))
  expect_true(grepl("Metric 1", html))
  expect_true(grepl("Metric 2", html))
  expect_true(grepl("Metric 3", html))
})

test_that("build_summary_metrics_table applies low-base-dim class to value cells", {
  hd <- mock_html_data(n_metrics = 1, n_waves = 2)
  # Low base on wave 1 only
  hd$metric_rows[[1]]$segment_cells$Total$W1$n <- 10L
  html <- as.character(build_summary_metrics_table(hd, min_base = 30L))
  expect_true(grepl("tk-low-base-dim", html))
})
