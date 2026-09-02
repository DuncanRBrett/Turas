# ==============================================================================
# TABS MODULE - MAXDIFF CONTRIBUTION ISLAND
# ==============================================================================
#
# A MaxDiff study contributes a JSON file; a tabs run for the same project
# embeds it as the data-md island and the shell shows a MaxDiff tab. The same
# arrangement as the conjoint island (test_conjoint_island.R) and the tracker's
# prior waves. The two modules meet through one file.
#
# The load-bearing property is that NOTHING changes for a report without
# MaxDiff. The tab appears only when TR.MD has content, and md_json defaults
# to NULL so every existing call site is untouched.
# ==============================================================================

library(testthat)

detect_root <- function() {
  home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(home) && dir.exists(file.path(home, "modules"))) return(normalizePath(home))
  d <- normalizePath(getwd(), mustWork = FALSE)
  for (i in 1:8) {
    if (dir.exists(file.path(d, "modules", "tabs"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("cannot find the Turas root")
}
root <- detect_root()
v2_dir <- file.path(root, "modules", "tabs", "lib", "html_report_v2")

# ---------------------------------------------------------------------------
# The template and builder contract
# ---------------------------------------------------------------------------

test_that("the template carries a data-md island", {
  tpl <- paste(readLines(file.path(v2_dir, "assets", "template.html"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('id="data-md"', tpl, fixed = TRUE))
  expect_true(grepl("{{DATA_MD}}", tpl, fixed = TRUE))
})

test_that("md_json defaults to NULL, so existing callers are unchanged", {
  src <- paste(readLines(file.path(v2_dir, "build_report_v2.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl("md_json = NULL", src, fixed = TRUE))
  expect_true(grepl('md_inlined <- if (!is.null(md_json)', src, fixed = TRUE))
  expect_true(grepl('"{{DATA_MD}}"     = md_inlined', src, fixed = TRUE))
  expect_true(grepl("escape_island(md_json)", src, fixed = TRUE))
})

test_that("maxdiff_island is a recognised tabs setting", {
  # A tabs config key that is not in build_config_object reads back NULL
  # forever, with no warning; and one not in TABS_KNOWN_SETTINGS warns as
  # unknown.
  cfg <- paste(readLines(file.path(root, "modules", "tabs", "lib", "crosstabs",
                                   "crosstabs_config.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('maxdiff_island = get_config_value(config, "maxdiff_island", "")',
                    cfg, fixed = TRUE))
  expect_true(grepl('"conjoint_island", "maxdiff_island",', cfg, fixed = TRUE))

  tpl <- paste(readLines(file.path(root, "modules", "tabs", "lib",
                                   "generate_config_templates.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('name = "maxdiff_island"', tpl, fixed = TRUE))

  run <- paste(readLines(file.path(root, "modules", "tabs", "lib", "run_crosstabs.R"),
                         warn = FALSE), collapse = "\n")
  expect_true(grepl(".read_maxdiff_contribution <- function(config_obj)", run, fixed = TRUE))
  expect_true(grepl("md_json = md_json_main", run, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# The view
# ---------------------------------------------------------------------------

test_that("the maxdiff view is present, parses, and is safe to inline", {
  view <- file.path(v2_dir, "assets", "js", "27y_maxdiff.js")
  expect_true(file.exists(view))
  src <- paste(readLines(view, warn = FALSE), collapse = "\n")
  expect_false(grepl("</script", src, fixed = TRUE))
  expect_false(grepl("<!--", src, fixed = TRUE))

  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")
  expect_equal(system2(node, c("--check", shQuote(view)),
                       stdout = FALSE, stderr = FALSE), 0L)
})

test_that("the shell shows the tab only when there is a contribution", {
  shell <- paste(readLines(file.path(v2_dir, "assets", "js", "24_shell.js"),
                           warn = FALSE), collapse = "\n")
  expect_true(grepl('TR.MD = parseIsland("data-md")', shell, fixed = TRUE))
  expect_true(grepl("TR.maxdiff && TR.maxdiff.available()", shell, fixed = TRUE))
  expect_true(grepl('d2.state.tab === "maxdiff") TR.maxdiff.render(host)',
                    shell, fixed = TRUE))
  # Frozen: the filter bar hides, as it does for Conjoint and Tracking.
  expect_true(grepl('d2.state.tab === "maxdiff" ||', shell, fixed = TRUE))
})

test_that("the node gate for the view passes", {
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")
  gate <- file.path(v2_dir, "tests", "maxdiff_view_tests.mjs")
  expect_true(file.exists(gate))
  out <- suppressWarnings(system2(node, shQuote(gate), stdout = TRUE, stderr = TRUE))
  expect_true(any(grepl("0 failed", out, fixed = TRUE)), info = paste(out, collapse = "\n"))
})
