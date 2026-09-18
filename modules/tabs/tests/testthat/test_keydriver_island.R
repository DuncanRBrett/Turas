# ==============================================================================
# TABS MODULE - KEYDRIVER CONTRIBUTION ISLAND
# ==============================================================================
#
# A key driver study contributes a JSON file; a tabs run for the same project
# embeds it as the data-kd island and the shell shows a Key drivers tab. The
# same arrangement as the conjoint island (test_conjoint_island.R), the maxdiff
# one and the pricing one. The two modules meet through one file.
#
# The load-bearing property is that NOTHING changes for a report without a key
# driver study. The tab appears only when TR.KD has content, and kd_json
# defaults to NULL so every existing call site is untouched.
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

ISLAND_JSON <- paste0(
  '{"meta":{"schema_version":1,"kind":"keydriver","analysis_name":"Test study",',
  '"outcome":{"var":"y","label":"Overall satisfaction"},"n_drivers":2,',
  '"base":{"n":900,"n_excluded":0,"weighted":false},"frozen":true,',
  '"filter_note":"Report filters do not apply here."},',
  '"importance":{"methods":[{"key":"shapley","label":"Shapley value","unit":"pct",',
  '"interval":false,"note":"no interval available"}],',
  '"drivers":[{"driver":"digital","label":"Digital banking","values":{"shapley":45.8},',
  '"ranks":{"shapley":1},"direction":1},',
  '{"driver":"fees","label":"Clarity of fees","values":{"shapley":21.1},',
  '"ranks":{"shapley":2},"direction":1}]}}')

# ---------------------------------------------------------------------------
# The config setting
# ---------------------------------------------------------------------------

test_that("keydriver_island is on the settings whitelist", {
  # config_obj is an explicit whitelist: a key that is not registered here
  # reads as NULL downstream however carefully the analyst typed it.
  src <- paste(readLines(file.path(root, "modules", "tabs", "lib", "crosstabs",
                                   "crosstabs_config.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('keydriver_island = get_config_value(config, "keydriver_island", "")',
                    src, fixed = TRUE))
  # And on the known-settings list, so a typo in the workbook is named rather
  # than ignored.
  expect_true(grepl('"pricing_island", "keydriver_island"', src, fixed = TRUE))
})

test_that("the tabs config template offers the setting", {
  gen <- paste(readLines(file.path(root, "modules", "tabs", "lib",
                                   "generate_config_templates.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('name = "keydriver_island"', gen, fixed = TRUE))
  expect_true(grepl("_kd_island.json", gen, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# The contribution reader
# ---------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  for (f in sort(list.files(file.path(root, "modules", "shared", "lib"),
                            pattern = "[.]R$", full.names = TRUE))) {
    try(source(f), silent = TRUE)
  }
}))

# Sourced on its own: run_crosstabs.R is large and the reader is self-contained.
kd_reader <- local({
  src <- readLines(file.path(root, "modules", "tabs", "lib", "run_crosstabs.R"),
                   warn = FALSE)
  start <- grep("^\\.read_keydriver_contribution <- function", src)
  expect_equal(length(start), 1L)
  end <- start
  depth <- 0L
  repeat {
    depth <- depth + lengths(regmatches(src[end], gregexpr("\\{", src[end]))) -
      lengths(regmatches(src[end], gregexpr("\\}", src[end])))
    if (depth <= 0 && end > start) break
    end <- end + 1L
    if (end > length(src)) break
  }
  eval(parse(text = paste(src[start:end], collapse = "\n")))
})

test_that("an ordinary tabs run reads no contribution", {
  expect_null(kd_reader(list()))
  expect_null(kd_reader(list(keydriver_island = "")))
  expect_null(kd_reader(list(keydriver_island = "   ")))
})

test_that("a named file that is not there warns and carries on", {
  out <- capture.output(res <- kd_reader(list(keydriver_island = "/no/such/file.json")))
  expect_null(res)
  expect_true(any(grepl("is not there", out, fixed = TRUE)))
  expect_true(any(grepl("without the Key drivers tab", out, fixed = TRUE)))
})

test_that("a file that is not a keydriver contribution is refused by kind", {
  p <- tempfile(fileext = ".json")
  on.exit(unlink(p), add = TRUE)
  writeLines('{"meta":{"kind":"pricing"}}', p)
  out <- capture.output(res <- kd_reader(list(keydriver_island = p)))
  expect_null(res)
  expect_true(any(grepl("not a keydriver contribution", out, fixed = TRUE)))
})

test_that("a real contribution is read", {
  p <- tempfile(fileext = ".json")
  on.exit(unlink(p), add = TRUE)
  writeLines(ISLAND_JSON, p)
  res <- kd_reader(list(keydriver_island = p))
  expect_true(is.character(res))
  expect_true(grepl('"kind":"keydriver"', res, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# The view and its gate
# ---------------------------------------------------------------------------

test_that("the view, the island slot and the styles are all present", {
  expect_true(file.exists(file.path(v2_dir, "assets", "js", "27k_keydriver.js")))

  tpl <- paste(readLines(file.path(v2_dir, "assets", "template.html"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('id="data-kd" data-island="v2"', tpl, fixed = TRUE))
  expect_true(grepl("{{DATA_KD}}", tpl, fixed = TRUE))

  css <- paste(readLines(file.path(v2_dir, "assets", "styles.css"), warn = FALSE),
               collapse = "\n")
  for (sel in c(".kd-view", ".kd-panel", ".kd-table", ".kd-whisker", ".kd-quadrant",
                ".kd-stamp")) {
    expect_true(grepl(sel, css, fixed = TRUE), info = sel)
  }
})

test_that("the shell gates the tab on the island and freezes it", {
  shell <- paste(readLines(file.path(v2_dir, "assets", "js", "24_shell.js"), warn = FALSE),
                 collapse = "\n")
  expect_true(grepl('TR.keydriver.available()', shell, fixed = TRUE))
  expect_true(grepl('parseIsland("data-kd")', shell, fixed = TRUE))
  expect_true(grepl('TR.keydriver.render(host)', shell, fixed = TRUE))
  # An island with no renderer must be reported, not silently ignored.
  expect_true(grepl('["keydriver",   TR.KD,   TR.keydriver]', shell, fixed = TRUE))
  # Frozen: the filter bar is hidden while the tab is open.
  expect_true(grepl('d2.state.tab === "keydriver" ||', shell, fixed = TRUE))
})

test_that("the node gate for the view passes", {
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")
  gate <- file.path(v2_dir, "tests", "keydriver_view_tests.mjs")
  expect_true(file.exists(gate))
  out <- suppressWarnings(system2(node, shQuote(gate), stdout = TRUE, stderr = TRUE))
  expect_true(any(grepl("0 failed", out, fixed = TRUE)), info = paste(out, collapse = "\n"))
})

# ---------------------------------------------------------------------------
# The built report
# ---------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  source(file.path(v2_dir, "build_report_v2.R"))
}))
V2_ASSETS <- file.path(v2_dir, "assets")

minimal_dl <- function() {
  '{"project":{"name":"T"},"questions":[],"banner":{"columns":[]}}'
}

test_that("a report without a key driver study carries no keydriver content", {
  html <- build_report_v2_html(minimal_dl(), list(), V2_ASSETS)
  expect_true(is.character(html))
  # The island slot is present and empty, exactly as the other contributions do it.
  expect_true(grepl('id="data-kd"', html, fixed = TRUE))
  # The renderer is stripped, so its bytes are not in a report that cannot use it.
  expect_false(grepl("TR.keydriver = {}", html, fixed = TRUE))
  # The island itself is empty. The literal "Key drivers" IS in the bundle
  # either way, because the shell's tab list names every optional tab; what
  # gates the tab is TR.keydriver.available(), and with a null island there is
  # no TR.keydriver at all.
  kd_slot <- sub('.*id="data-kd"[^>]*>', "", html)
  kd_slot <- substr(kd_slot, 1, 40)
  expect_true(grepl("null", kd_slot, fixed = TRUE))
  expect_false(grepl('"kind":"keydriver"', html, fixed = TRUE))
})

test_that("a report with a key driver study carries the island and the view", {
  html <- build_report_v2_html(minimal_dl(), list(), V2_ASSETS, kd_json = ISLAND_JSON)
  expect_true(grepl('"kind":"keydriver"', html, fixed = TRUE))
  expect_true(grepl("TR.keydriver", html, fixed = TRUE))
  # The island's own content reached the page.
  expect_true(grepl("Digital banking", html, fixed = TRUE))
})

test_that("kd_json defaults to NULL, so every existing call site is untouched", {
  fn <- formals(build_report_v2_html)
  expect_true("kd_json" %in% names(fn))
  expect_null(eval(fn$kd_json))

  fn2 <- formals(write_html_report_v2)
  expect_true("kd_json" %in% names(fn2))
  expect_null(eval(fn2$kd_json))
})
