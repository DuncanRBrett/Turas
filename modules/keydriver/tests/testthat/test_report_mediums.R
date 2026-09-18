# ==============================================================================
# KEYDRIVER - REPORT LAYER MEDIUMS (review M14, M17 to M24)
# ==============================================================================
# Each of these reached a reader as a wrong or missing thing on the page: a
# column that vanished, a chart column of invisible dots, a chart that
# disagreed with the table under it, a caveat that could not be exported, and
# a Print view full of literal markup.
# ==============================================================================

# The chart builders live in lib/html_report, which kd_ensure_module_loaded()
# deliberately does not source (its orchestrator's guard reports every file
# missing against a working directory of "."). This one file sources cleanly on
# its own, so the chart tests below load it rather than skipping, which is what
# they did at first and what review F19 is about.
if (!exists("build_kd_correlation_heatmap", mode = "function")) {
  try(source(file.path(module_dir, "lib", "html_report", "05_chart_builder.R")),
      silent = TRUE)
}

js_dir <- file.path(module_dir, "lib", "html_report", "js")
read_js <- function(name) paste(readLines(file.path(js_dir, name), warn = FALSE),
                                collapse = "\n")

test_that("the Total chip and the Total column agree (M17)", {
  nav <- read_js("kd_navigation.js")
  # Chips carry the label "Total"; the table's total cells are keyed "total".
  builders <- paste(readLines(file.path(module_dir, "lib", "html_report",
                                        "03c_section_builders.R"), warn = FALSE),
                    collapse = "\n")
  tables <- paste(readLines(file.path(module_dir, "lib", "html_report",
                                      "02_table_builder.R"), warn = FALSE),
                  collapse = "\n")
  expect_true(grepl('all_names <- c("Total", seg_names)', builders, fixed = TRUE))
  expect_true(grepl('`data-kd-seg-col` = "total"', tables, fixed = TRUE))

  # So both the filter and the sort must translate, through one helper.
  expect_true(grepl("function kdSegColKey(segName)", nav, fixed = TRUE))
  expect_true(grepl("activeSegs[kdSegColKey(seg)] = true", nav, fixed = TRUE))
  expect_true(grepl("var colName = kdSegColKey(segName);", nav, fixed = TRUE))
  # The old raw comparison is gone.
  expect_false(grepl("activeSegs[seg] = true", nav, fixed = TRUE))
})

test_that("some page is always open, whatever the toggles say (M18)", {
  nav <- read_js("kd_navigation.js")
  expect_true(grepl("function kdEnsureAPageIsActive()", nav, fixed = TRUE))
  # It runs on load, and it runs before hydration restores saved state.
  expect_true(grepl("kdEnsureAPageIsActive();", nav, fixed = TRUE))
  expect_lt(regexpr("kdEnsureAPageIsActive();", nav, fixed = TRUE)[1],
            regexpr("kdHydratePage();", nav, fixed = TRUE)[1])
})

test_that("section visibility reads Yes as yes (M14, report layer)", {
  for (f in c("03_page_builder.R", "03b_page_components.R")) {
    src <- paste(readLines(file.path(module_dir, "lib", "html_report", f),
                           warn = FALSE), collapse = "\n")
    expect_true(grepl("as_logical_setting(val, default)", src, fixed = TRUE),
                info = f)
  }
})

test_that("the method agreement chart never draws a dot at NA (M19)", {
  expect_true(exists("build_kd_method_agreement_chart", mode = "function"))

  # The grouped path sets one rank column and leaves the rest NA, which is
  # what produced cy="NA" and a column of circles the browser dropped.
  mc <- data.frame(
    Driver         = c("a", "b", "c"),
    Rank_Correlation = c(1, 2, 3),
    Rank_Beta        = c(2, 1, 3),
    Rank_RelWeight   = c(NA_real_, NA_real_, NA_real_),
    Rank_Shapley     = c(NA_real_, NA_real_, NA_real_),
    stringsAsFactors = FALSE)
  out <- build_kd_method_agreement_chart(mc)
  expect_false(is.null(out))
  svg <- as.character(out)
  expect_false(grepl('cy="NA"', svg, fixed = TRUE))
  expect_false(grepl('cx="NA"', svg, fixed = TRUE))
  expect_false(grepl("NaN", svg, fixed = TRUE))
  # The empty methods are not given a column header either.
  expect_false(grepl("RelWeight", svg, fixed = TRUE))
  expect_true(grepl("Correlation", svg, fixed = TRUE))

  # A single missing rank inside a usable method leaves a gap, not an NA.
  mc2 <- data.frame(
    Driver         = c("a", "b", "c"),
    Rank_Correlation = c(1, NA_real_, 3),
    Rank_Beta        = c(2, 1, 3),
    stringsAsFactors = FALSE)
  svg2 <- as.character(build_kd_method_agreement_chart(mc2))
  expect_false(grepl('cy="NA"', svg2, fixed = TRUE))
  expect_false(grepl("NaN", svg2, fixed = TRUE))

  # And two methods with nothing in them is not a chart.
  mc3 <- data.frame(Driver = c("a", "b"),
                    Rank_Correlation = c(NA_real_, NA_real_),
                    Rank_Beta = c(NA_real_, NA_real_))
  expect_null(build_kd_method_agreement_chart(mc3))
})

test_that("the bootstrap chart names the method it is showing (M20)", {
  expect_true(exists("build_kd_bootstrap_ci_chart", mode = "function"))

  # Three rows of Relative_Weight and one of Correlation. "First seen" gave
  # Correlation; the most common is Relative_Weight.
  ci <- data.frame(
    driver = c("a", "b", "c", "d"),
    method = c("Correlation", "Relative_Weight", "Relative_Weight", "Relative_Weight"),
    point_estimate = c(0.4, 0.3, 0.2, 0.1),
    ci_lower = c(0.3, 0.2, 0.1, 0.05),
    ci_upper = c(0.5, 0.4, 0.3, 0.15),
    stringsAsFactors = FALSE)
  svg <- as.character(build_kd_bootstrap_ci_chart(ci))
  expect_true(grepl("Intervals shown for the Relative_Weight method", svg, fixed = TRUE))
  expect_true(grepl("The table below lists every method", svg, fixed = TRUE))
  # Three rows kept, not the single Correlation row.
  expect_equal(length(gregexpr('class="kd-ci-row"', svg, fixed = TRUE)[[1]]), 3L)

  # One method only: no caption, because there is nothing to disambiguate.
  ci1 <- ci[ci$method == "Relative_Weight", ]
  svg1 <- as.character(build_kd_bootstrap_ci_chart(ci1))
  expect_false(grepl("Intervals shown for", svg1, fixed = TRUE))
})

test_that("pinning Diagnostics captures the VIF table too (M23)", {
  pins <- read_js("kd_pins.js")
  # The class the old branch looked for is assigned by no builder.
  builders <- c("02_table_builder.R", "03c_section_builders.R", "03_page_builder.R")
  for (f in builders) {
    src <- paste(readLines(file.path(module_dir, "lib", "html_report", f),
                           warn = FALSE), collapse = "\n")
    expect_false(grepl("kd-diagnostics-table", src, fixed = TRUE), info = f)
  }
  expect_false(grepl("kd-diagnostics-table", pins, fixed = TRUE))

  # Both diagnostics tables are kd-table, and both are captured.
  tables <- paste(readLines(file.path(module_dir, "lib", "html_report",
                                      "02_table_builder.R"), warn = FALSE),
                  collapse = "\n")
  expect_true(grepl('class = "kd-table kd-model-summary-table"', tables, fixed = TRUE))
  expect_true(grepl('class = "kd-table kd-vif-table"', tables, fixed = TRUE))
  expect_true(grepl('section.querySelectorAll("table.kd-table")', pins, fixed = TRUE))
  expect_true(grepl("kdNearestPanelHeading", pins, fixed = TRUE))

  # The heading it emits has a style to land on.
  css <- paste(readLines(file.path(module_dir, "lib", "html_report",
                                   "03a_page_styling.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl(".kd-pinned-table-heading {", css, fixed = TRUE))
})

test_that("Print and PDF show commentary, not its markup (M22)", {
  extras <- read_js("kd_pins_extras.js")
  # A qual slide stores its commentary as HTML.
  expect_true(grepl('"<p>" + text.replace(', extras, fixed = TRUE))
  # The print overlay renders it the way the pinned cards do, rather than
  # escaping it into visible tags.
  expect_true(grepl("function kdRenderInsight(text)", extras, fixed = TRUE))
  expect_true(grepl("kdRenderInsight(item.insightText)", extras, fixed = TRUE))
  expect_false(grepl("kdEscapeHtml(item.insightText)", extras, fixed = TRUE))
  # Titles are still escaped: they are plain text.
  expect_true(grepl("kdEscapeHtml(item.sectionTitle", extras, fixed = TRUE))
})

test_that("the dead pin forks are gone and the docs agree (M24)", {
  for (f in c("kd_pinned_views.js", "kd_slide_export.js")) {
    expect_false(file.exists(file.path(js_dir, f)), info = f)
  }
  # What is on disk is exactly what the embed list and the guard list name.
  on_disk <- sort(basename(list.files(js_dir, pattern = "\\.js$")))
  comp <- paste(readLines(file.path(module_dir, "lib", "html_report",
                                    "03b_page_components.R"), warn = FALSE),
                collapse = "\n")
  main <- paste(readLines(file.path(module_dir, "lib", "html_report",
                                    "99_html_report_main.R"), warn = FALSE),
                collapse = "\n")
  for (f in on_disk) {
    expect_true(grepl(f, comp, fixed = TRUE), info = paste("embed list:", f))
    expect_true(grepl(f, main, fixed = TRUE), info = paste("guard list:", f))
  }

  # And no doc still lists a file that is not there.
  docs <- c(file.path(module_dir, "README.md"),
            file.path(module_dir, "docs", "01_README.md"),
            file.path(module_dir, "docs", "05_TECHNICAL_DOCS.md"))
  for (d in docs) {
    if (!file.exists(d)) next
    src <- paste(readLines(d, warn = FALSE), collapse = "\n")
    expect_false(grepl("kd_pinned_views.js", src, fixed = TRUE), info = d)
    expect_false(grepl("kd_slide_export.js", src, fixed = TRUE), info = d)
  }
})

test_that("the report layer has no pin button without a function (M24)", {
  # build_kd_component_pin_btn emitted kdPinComponent(), which was defined in
  # no JS file, live or dead. Nothing called the builder, so no reader ever
  # met the broken button, but it was one call site away from shipping.
  comp <- paste(readLines(file.path(module_dir, "lib", "html_report",
                                    "03b_page_components.R"), warn = FALSE),
                collapse = "\n")
  expect_false(grepl("kdPinComponent", comp, fixed = TRUE))
  expect_false(grepl("build_kd_component_pin_btn", comp, fixed = TRUE))
})

test_that("no em dash reaches a reader from the report layer", {
  # Duncan reads an em dash as an AI watermark, so none may appear in a
  # string that reaches him or a client. Code comments are not that.
  em <- "—"
  pins <- read_js("kd_pins.js")
  expect_true(grepl('content.panelLabel + ": " + content.sectionTitle', pins, fixed = TRUE))

  v104 <- readLines(file.path(module_dir, "lib", "html_report",
                              "07_v104_sections.R"), warn = FALSE)
  warn_lines <- v104[grepl("cat\\(", v104)]
  for (ln in warn_lines) {
    expect_false(grepl(em, ln, fixed = TRUE), info = trimws(ln))
  }
})


# ==============================================================================
# THE CORRELATION MATRIX (Duncan, 18 Sep 2026)
# ==============================================================================
# It drew the full symmetric matrix: every number twice, plus a diagonal of
# 1.00 in the strongest colour, which put the eye on the only cells that carry
# no information. The longest column label also ran past the viewBox, so
# "product_range" rendered as "product_ran".

test_that("the correlation heatmap draws each pair once (lower triangle)", {
  expect_true(exists("build_kd_correlation_heatmap", mode = "function"))

  vars <- c("outcome", "d1", "d2", "d3")
  m <- matrix(c(1.00, 0.77, 0.61, 0.43,
                0.77, 1.00, 0.41, 0.34,
                0.61, 0.41, 1.00, 0.36,
                0.43, 0.34, 0.36, 1.00), 4, 4,
              dimnames = list(vars, vars))

  svg <- as.character(build_kd_correlation_heatmap(m))

  # Four variables: 6 pairs, so 6 cells. The full matrix drew 16.
  n_cells <- length(gregexpr("<rect ", svg, fixed = TRUE)[[1]])
  expect_equal(n_cells, 6L)

  # Every off-diagonal value appears exactly once.
  for (v in c("0.77", "0.61", "0.43", "0.41", "0.34", "0.36")) {
    expect_equal(length(gregexpr(v, svg, fixed = TRUE)[[1]]), 1L, info = v)
  }
  # And the diagonal is gone: no 1.00 anywhere.
  expect_false(grepl("1.00", svg, fixed = TRUE))
})

test_that("the heatmap's box is wide enough for its rotated labels", {
  expect_true(exists("build_kd_correlation_heatmap", mode = "function"))

  # A long name in the last labelled column is the case that used to clip.
  vars <- c("outcome", "d1", "a_very_long_driver", "d3")
  m <- diag(4); dimnames(m) <- list(vars, vars)
  m[lower.tri(m)] <- 0.5; m[upper.tri(m)] <- 0.5

  svg <- as.character(build_kd_correlation_heatmap(m))
  vb <- regmatches(svg, regexpr('viewBox="0 0 [0-9]+ [0-9]+"', svg))
  expect_true(length(vb) == 1)
  dims <- as.numeric(regmatches(vb, gregexpr("[0-9]+", vb))[[1]])
  width <- dims[3]

  # The grid itself ends here; the rest of the width is for the labels that
  # lean up and to the right of it.
  grid_right <- 140 + (4 - 1) * 44
  expect_gt(width, grid_right)
  # Long labels must buy more room than short ones.
  short <- as.character(build_kd_correlation_heatmap(
    `dimnames<-`(m, list(c("o", "a", "b", "c"), c("o", "a", "b", "c")))))
  vb2 <- regmatches(short, regexpr('viewBox="0 0 [0-9]+ [0-9]+"', short))
  w2 <- as.numeric(regmatches(vb2, gregexpr("[0-9]+", vb2))[[1]])[3]
  expect_gt(width, w2)
})


test_that("the correlations section says on what basis it was computed", {
  # A weighted study's correlations ARE weighted, and the section said nothing,
  # so checking a figure against the raw data gave a different number with no
  # explanation. On the Suiderland example the outcome-to-fees_clarity cell is
  # 0.61 weighted and 0.59 unweighted, which is exactly big enough to look
  # like an error and small enough to be dismissed as rounding.
  expect_true(exists("build_kd_correlation_section", mode = "function") ||
                file.exists(file.path(module_dir, "lib", "html_report",
                                      "03c_section_builders.R")))
  src <- paste(readLines(file.path(module_dir, "lib", "html_report",
                                   "03c_section_builders.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl("Correlations are weighted by", src, fixed = TRUE))
  expect_true(grepl("will not match an unweighted calculation", src, fixed = TRUE))
  expect_true(grepl("Correlations are unweighted.", src, fixed = TRUE))
  # Driven by the config, not typed per study.
  expect_true(grepl("wv <- config$weight_var", src, fixed = TRUE))
})
