# ==============================================================================
# TABS MODULE - PRICING CONTRIBUTION ISLAND
# ==============================================================================
#
# A pricing study contributes a JSON file; a tabs run for the same project
# embeds it as the data-pr island and the shell shows a Pricing tab. The same
# arrangement as the conjoint island (test_conjoint_island.R) and the maxdiff
# one (test_maxdiff_island.R). The two modules meet through one file.
#
# The load-bearing property is that NOTHING changes for a report without
# pricing. The tab appears only when TR.PR has content, and pr_json defaults
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

test_that("the template carries a data-pr island", {
  tpl <- paste(readLines(file.path(v2_dir, "assets", "template.html"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('id="data-pr"', tpl, fixed = TRUE))
  expect_true(grepl("{{DATA_PR}}", tpl, fixed = TRUE))
})

test_that("pr_json defaults to NULL, so existing callers are unchanged", {
  src <- paste(readLines(file.path(v2_dir, "build_report_v2.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl("pr_json = NULL", src, fixed = TRUE))
  expect_true(grepl('pr_inlined <- if (!is.null(pr_json)', src, fixed = TRUE))
  expect_true(grepl('"{{DATA_PR}}"     = pr_inlined', src, fixed = TRUE))
  expect_true(grepl("escape_island(pr_json)", src, fixed = TRUE))
  # Both signatures, not just the inner one.
  expect_equal(length(gregexpr("pr_json = NULL", src, fixed = TRUE)[[1]]), 2L)
})

test_that("pricing_island is a recognised tabs setting", {
  # A tabs config key that is not in build_config_object reads back NULL
  # forever, with no warning; and one not in TABS_KNOWN_SETTINGS warns as
  # unknown. Both places or the setting is dead.
  cfg <- paste(readLines(file.path(root, "modules", "tabs", "lib", "crosstabs",
                                   "crosstabs_config.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('pricing_island = get_config_value(config, "pricing_island", "")',
                    cfg, fixed = TRUE))
  expect_true(grepl('"conjoint_island", "maxdiff_island", "pricing_island",',
                    cfg, fixed = TRUE))

  tpl <- paste(readLines(file.path(root, "modules", "tabs", "lib",
                                   "generate_config_templates.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('name = "pricing_island"', tpl, fixed = TRUE))

  run <- paste(readLines(file.path(root, "modules", "tabs", "lib", "run_crosstabs.R"),
                         warn = FALSE), collapse = "\n")
  expect_true(grepl(".read_pricing_contribution <- function(config_obj)", run, fixed = TRUE))
  expect_true(grepl("pr_json = pr_json_main", run, fixed = TRUE))
})

test_that("build_config_object actually returns the key", {
  # The grep above proves the line is written; this proves the assembled
  # object carries it. config_obj is a whitelist, so a key absent here reads
  # back NULL forever with no warning.
  env <- new.env(parent = globalenv())
  lib <- file.path(root, "modules", "tabs", "lib")
  # Some lib files print a TRS box when a sibling they expect is not beside
  # them; that is noise here, not a failure, so it is captured.
  invisible(capture.output(suppressWarnings(suppressMessages({
    for (f in sort(list.files(lib, pattern = "[.]R$", full.names = TRUE))) {
      try(sys.source(f, envir = env), silent = TRUE)
    }
    sys.source(file.path(lib, "crosstabs", "crosstabs_config.R"), envir = env)
  }))))
  obj <- get("build_config_object", envir = env)(list())
  expect_true("pricing_island" %in% names(obj))
  expect_equal(obj$pricing_island, "")

  named <- get("build_config_object", envir = env)(
    list(pricing_island = "Output/Study_pr_island.json"))
  expect_equal(named$pricing_island, "Output/Study_pr_island.json")
})

# ---------------------------------------------------------------------------
# The reader
# ---------------------------------------------------------------------------

test_that("the reader takes a pricing island and refuses anything else", {
  run_file <- file.path(root, "modules", "tabs", "lib", "run_crosstabs.R")
  env <- new.env(parent = globalenv())
  src <- readLines(run_file, warn = FALSE)
  start <- grep("^.read_pricing_contribution <- function", src)
  skip_if(length(start) != 1, "reader not found")
  # The function ends at the first line that is exactly "}".
  ends <- grep("^}$", src)
  stop_at <- min(ends[ends > start])
  eval(parse(text = paste(src[start:stop_at], collapse = "\n")), envir = env)
  reader <- get(".read_pricing_contribution", envir = env)

  expect_null(reader(list(pricing_island = "")))
  expect_null(reader(list()))

  tmp <- file.path(tempdir(), "pr_reader")
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)

  missing_path <- file.path(tmp, "not_there.json")
  expect_output(expect_null(reader(list(pricing_island = missing_path))), "not there")

  wrong <- file.path(tmp, "wrong.json")
  writeLines('{"meta":{"kind":"maxdiff"}}', wrong)
  expect_output(expect_null(reader(list(pricing_island = wrong))), "not a pricing contribution")

  right <- file.path(tmp, "right.json")
  writeLines('{"meta":{"kind":"pricing","schema":1},"gg":{"price":[10]}}', right)
  txt <- reader(list(pricing_island = right))
  expect_true(is.character(txt))
  expect_true(grepl('"kind":"pricing"', txt, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# The view
# ---------------------------------------------------------------------------

test_that("the pricing view is present, parses, and is safe to inline", {
  view <- file.path(v2_dir, "assets", "js", "27z_pricing.js")
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
  expect_true(grepl('TR.PR = parseIsland("data-pr")', shell, fixed = TRUE))
  expect_true(grepl("TR.pricing && TR.pricing.available()", shell, fixed = TRUE))
  expect_true(grepl('d2.state.tab === "pricing") TR.pricing.render(host)',
                    shell, fixed = TRUE))
  # Frozen: the filter bar hides, as it does for Conjoint, MaxDiff and Tracking.
  expect_true(grepl('d2.state.tab === "pricing" ||', shell, fixed = TRUE))
})

test_that("the view has a stylesheet block of its own", {
  css <- paste(readLines(file.path(v2_dir, "assets", "styles.css"), warn = FALSE),
               collapse = "\n")
  for (sel in c(".pr-view", ".pr-panel", ".pr-table", ".pr-chart", ".pr-stamp")) {
    expect_true(grepl(sel, css, fixed = TRUE), info = sel)
  }
})

test_that("the node gate for the view passes", {
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")
  gate <- file.path(v2_dir, "tests", "pricing_view_tests.mjs")
  expect_true(file.exists(gate))
  out <- suppressWarnings(system2(node, shQuote(gate), stdout = TRUE, stderr = TRUE))
  expect_true(any(grepl("0 failed", out, fixed = TRUE)), info = paste(out, collapse = "\n"))
})

# ---------------------------------------------------------------------------
# The built report
# ---------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  for (f in sort(list.files(file.path(root, "modules", "shared", "lib"),
                            pattern = "[.]R$", full.names = TRUE))) {
    try(source(f), silent = TRUE)
  }
  source(file.path(v2_dir, "build_report_v2.R"))
}))
V2_ASSETS <- file.path(v2_dir, "assets")

test_that("a report without pricing is identical whether or not pr_json is named", {
  data_json <- '{"questions":[],"project":{"name":"t"}}'
  cfg <- list(project_title = "t")
  a <- build_report_v2_html(data_json, cfg, assets_dir = V2_ASSETS, generated = "fixed")
  b <- build_report_v2_html(data_json, cfg, assets_dir = V2_ASSETS, generated = "fixed",
                            pr_json = NULL)
  expect_identical(a, b)
  # The island tag is there but empty, so no Pricing tab can appear.
  expect_true(grepl('id="data-pr"', a, fixed = TRUE))
  expect_true(grepl('id="data-pr">\nnull', a, fixed = TRUE))
})

test_that("a pricing island is inlined and escaped into the built report", {
  island <- paste0('{"meta":{"kind":"pricing","schema":1,"currency":"R",',
                   '"projectName":"</script><script>alert(1)"},',
                   '"gg":{"price":[80],"acceptancePct":[73.2]}}')
  html <- build_report_v2_html('{"questions":[],"project":{"name":"t"}}',
                               list(project_title = "t"), assets_dir = V2_ASSETS,
                               generated = "fixed", pr_json = island)
  expect_true(grepl('"kind":"pricing"', html, fixed = TRUE))
  # escape_island turns every "<" into \u003c, so the island cannot close the
  # script element it lives in.
  expect_false(grepl("</script><script>alert(1)", html, fixed = TRUE))
  expect_true(grepl("\\u003c/script", html, fixed = TRUE))
})
