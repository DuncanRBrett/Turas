# ==============================================================================
# TABS MODULE - AUTHORED REPORT TEXT (v2)
# ==============================================================================
#
# Tests modules/tabs/lib/html_report_v2/report_text.R — the build-time contract
# between the renderer and the text an author writes in the Callout Editor.
#
# The point of these tests is the REFUSALS. There is deliberately no fallback
# wording in the renderer, so the only thing standing between an editing slip
# and a client's report is this validator. Each case below is a slip that has a
# realistic path into the registry: an entry deleted, a placeholder mistyped, a
# tag left open, markup pasted in from somewhere else.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_report_text.R")
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(getwd(), file.path(getwd(), "../.."),
                  file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()
assign(".tabs_lib_dir", file.path(turas_root, "modules/tabs/lib"), envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/html_report_v2/build_report_v2.R"))
source(file.path(turas_root, "modules/tabs/lib/html_report_v2/report_text.R"))
source(file.path(turas_root, "modules/shared/lib/callouts/callout_registry.R"))
# The override path spans the config side too: the template that ships the
# ReportText sheet, and the loader that reads it back. The template generator
# finds its shared styles relative to the working directory, so source it from
# the project root.
local({
  owd <- setwd(turas_root); on.exit(setwd(owd), add = TRUE)
  source(file.path(turas_root, "modules/tabs/lib/generate_config_templates.R"))
  source(file.path(turas_root, "modules/tabs/lib/crosstabs/crosstabs_config.R"))
})

assets_dir <- file.path(turas_root, "modules/tabs/lib/html_report_v2/assets")

# A manifest and a matching set of entries, small enough to reason about.
man <- list(
  "a.plain"  = list(page = "Report", context = "x", tokens = list()),
  "a.token"  = list(page = "Report", context = "x", tokens = list("company"))
)
entry <- function(text) list(title = "t", text = text, context = "c", page = "Report")
good <- list("a.plain" = entry("A plain sentence."),
             "a.token" = entry("Produced by {company}."))

errs <- function(m, e, keys = character(0)) validate_report_text(m, e, keys)$errors
warns <- function(m, e, keys = character(0)) validate_report_text(m, e, keys)$warnings


# ==============================================================================
# 1. The happy path
# ==============================================================================

context("report_text: valid authored text")

test_that("well-formed text passes with no errors or warnings", {
  expect_length(errs(man, good), 0)
  expect_length(warns(man, good), 0)
})

test_that("deliberately blank text is allowed - it means 'do not show this'", {
  blanked <- good
  blanked[["a.plain"]]$text <- ""
  expect_length(errs(man, blanked), 0)
})

test_that("permitted inline markup passes", {
  ok <- good
  ok[["a.plain"]]$text <- "A <strong>bold</strong> claim.<br>And a <em>softer</em> one."
  expect_length(errs(man, ok), 0)
})


# ==============================================================================
# 2. Refusals
# ==============================================================================

context("report_text: refusals")

test_that("a key deleted in the editor refuses, and names the key and its page", {
  missing <- good
  missing[["a.plain"]] <- NULL
  e <- errs(man, missing)
  expect_length(e, 1)
  expect_true(grepl("a.plain", e[1], fixed = TRUE))
  expect_true(grepl("Callout Editor", e[1], fixed = TRUE))
  expect_true(grepl("Report", e[1], fixed = TRUE))
})

test_that("a mistyped placeholder refuses and lists what is available", {
  typo <- good
  typo[["a.token"]]$text <- "Produced by {compny}."
  e <- errs(man, typo)
  expect_true(any(grepl("{compny}", e, fixed = TRUE)))
  expect_true(any(grepl("{company}", e, fixed = TRUE)))
})

test_that("an unclosed tag refuses rather than distorting the page", {
  broken <- good
  broken[["a.plain"]]$text <- "A <strong>bold claim."
  expect_true(any(grepl("unclosed", errs(man, broken))))
})

test_that("a mismatched closing tag refuses", {
  broken <- good
  broken[["a.plain"]]$text <- "A <strong>bold</em> claim."
  expect_true(length(errs(man, broken)) > 0)
})

test_that("a tag outside the whitelist refuses", {
  broken <- good
  broken[["a.plain"]]$text <- "<div>Layout is not the author's to set.</div>"
  expect_true(any(grepl("not allowed", errs(man, broken))))
})

test_that("attributes refuse, so authored text cannot style or script", {
  broken <- good
  broken[["a.plain"]]$text <- "<span onclick=\"steal()\">Click</span>"
  expect_true(any(grepl("attributes", errs(man, broken))))
})

test_that("a renderer call with no manifest entry refuses, naming the key", {
  e <- errs(man, good, keys = c("a.plain", "a.token", "cards.not_declared"))
  expect_true(any(grepl("cards.not_declared", e, fixed = TRUE)))
})


# ==============================================================================
# 3. Warnings - worth saying, not worth stopping a build for
# ==============================================================================

context("report_text: warnings")

test_that("an author who drops a placeholder is warned, not refused", {
  dropped <- good
  dropped[["a.token"]]$text <- "Produced in-house."
  expect_length(errs(man, dropped), 0)
  expect_true(any(grepl("does not use", warns(man, dropped))))
})

test_that("text nobody renders is flagged - this is how the registry silted up", {
  w <- warns(man, good, keys = c("a.plain"))
  expect_true(any(grepl("never asks for it", w)))
})


# ==============================================================================
# 4. Against the real manifest and registry
# ==============================================================================

context("report_text: the shipped catalogue")

test_that("every key the real renderer calls is declared and authored", {
  js <- bundle_report_v2_js(assets_dir)
  keys <- report_text_keys_used(js)
  expect_true(length(keys) > 0)

  real_man <- load_report_text_manifest(report_text_manifest_path(assets_dir))
  real_entries <- turas_callout_module("tabs")
  expect_length(validate_report_text(real_man, real_entries, keys)$errors, 0)
})

test_that("the registry resolves from any working directory", {
  # The path used to be resolved from the working directory, so callouts simply
  # did not load under testthat - and every module that renders one carried on
  # silently. Assert the file is actually found, not merely that no error was
  # raised.
  expect_true(file.exists(turas_callouts_path()))
  expect_true(length(turas_callout_module("tabs")) > 0)
})

test_that("the island carries the text and nothing else", {
  js <- bundle_report_v2_js(assets_dir)
  res <- build_report_text_json(assets_dir, js_bundle = js)
  expect_equal(res$status, "PASS")

  parsed <- jsonlite::fromJSON(res$json, simplifyVector = FALSE)
  expect_true(all(vapply(parsed, is.character, logical(1))))
  # authoring aids stay in the registry; only the words ship
  expect_false(any(grepl("\"context\"", res$json, fixed = TRUE)))
})

test_that("a missing key in the real build stops the report, loudly", {
  js <- bundle_report_v2_js(assets_dir)
  gutted <- turas_callout_module("tabs")
  gutted[["report.construction.produced"]] <- NULL
  expect_error(
    build_report_text_json(assets_dir, js_bundle = js, entries = gutted),
    "CFG_REPORT_TEXT_INVALID")
})


# ==============================================================================
# 5. Per-project overrides (the config's ReportText sheet)
# ==============================================================================

context("report_text: per-project overrides")

test_that("an override replaces the platform wording for this build only", {
  js <- bundle_report_v2_js(assets_dir)
  base <- turas_callout_module("tabs")
  res <- build_report_text_json(assets_dir, js_bundle = js, entries = base,
    overrides = list("report.construction.stock" = "Figures come out of R."))
  payload <- jsonlite::fromJSON(res$json, simplifyVector = FALSE)
  expect_equal(payload[["report.construction.stock"]], "Figures come out of R.")
  # the registry itself is untouched — the override lives for this build only
  expect_false(identical(base[["report.construction.stock"]]$text,
                         "Figures come out of R."))
})

test_that("an override naming nothing refuses, rather than being ignored", {
  js <- bundle_report_v2_js(assets_dir)
  expect_error(
    build_report_text_json(assets_dir, js_bundle = js,
                           overrides = list("cards.sig.lettres" = "typo'd key")),
    "CFG_REPORT_TEXT_OVERRIDE")
})

test_that("an override is validated like any other authored text", {
  js <- bundle_report_v2_js(assets_dir)
  expect_error(
    build_report_text_json(assets_dir, js_bundle = js,
      overrides = list("report.construction.stock" = "A <strong>broken claim.")),
    "CFG_REPORT_TEXT_INVALID")
  expect_error(
    build_report_text_json(assets_dir, js_bundle = js,
      overrides = list("report.construction.produced" = "Produced by {compny}.")),
    "CFG_REPORT_TEXT_INVALID")
})

test_that("no overrides leaves the platform text exactly as authored", {
  js <- bundle_report_v2_js(assets_dir)
  plain <- build_report_text_json(assets_dir, js_bundle = js)
  empty <- build_report_text_json(assets_dir, js_bundle = js, overrides = list())
  expect_equal(as.character(plain$json), as.character(empty$json))
})

test_that("the generated config template ships a ReportText sheet, and it is empty", {
  tmp <- file.path(tempdir(), "reporttext_tpl.xlsx")
  on.exit(unlink(tmp), add = TRUE)
  generate_crosstab_config_template(tmp)
  expect_true("ReportText" %in% openxlsx::getSheetNames(tmp))
  # Empty means empty: the loader must find nothing to override, so a fresh
  # config can never quietly carry a stale copy of the platform wording.
  expect_null(load_report_text_sheet(tmp))
})
