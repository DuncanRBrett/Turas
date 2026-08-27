# ==============================================================================
# TABS MODULE - CONJOINT CONTRIBUTION ISLAND
# ==============================================================================
#
# A conjoint study contributes a JSON file; a tabs run for the same project
# embeds it as the data-cj island and the shell shows a Conjoint tab. This is
# the same arrangement the tracker uses for prior waves — the two modules meet
# through one file.
#
# The load-bearing property is that NOTHING changes for a report without
# conjoint. The tab appears only when TR.CJ has content, and cj_json defaults
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

test_that("the template carries a data-cj island", {
  tpl <- paste(readLines(file.path(v2_dir, "assets", "template.html"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('id="data-cj"', tpl, fixed = TRUE))
  expect_true(grepl("{{DATA_CJ}}", tpl, fixed = TRUE))
})

test_that("cj_json defaults to NULL, so existing callers are unchanged", {
  src <- paste(readLines(file.path(v2_dir, "build_report_v2.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl("cj_json = NULL", src, fixed = TRUE))
  # Absent, the token renders "null" — not an empty string, which would be
  # invalid JSON and would take the whole report down.
  expect_true(grepl('cj_inlined <- if (!is.null(cj_json)', src, fixed = TRUE))
  expect_true(grepl('"{{DATA_CJ}}"     = cj_inlined', src, fixed = TRUE))
})

test_that("the island is escaped like every other island", {
  src <- paste(readLines(file.path(v2_dir, "build_report_v2.R"), warn = FALSE),
               collapse = "\n")
  # escape_island turns every "<" into its JSON unicode escape. A conjoint
  # attribute called "Size < 6 inch" must not be able to break the island.
  expect_true(grepl("escape_island(cj_json)", src, fixed = TRUE))
})

test_that("conjoint_island is a recognised tabs setting", {
  # A tabs config key that is not in build_config_object reads back NULL
  # forever, with no warning.
  cfg <- paste(readLines(file.path(root, "modules", "tabs", "lib", "crosstabs",
                                   "crosstabs_config.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('conjoint_island = get_config_value(config, "conjoint_island", "")',
                    cfg, fixed = TRUE))
  expect_true(grepl('"conjoint_island",', cfg, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# The view
# ---------------------------------------------------------------------------

test_that("the conjoint view is present and parses", {
  view <- file.path(v2_dir, "assets", "js", "27x_conjoint.js")
  expect_true(file.exists(view))

  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")
  expect_equal(system2(node, c("--check", shQuote(view)),
                       stdout = FALSE, stderr = FALSE), 0L)
})

test_that("the view is safe to inline", {
  view <- paste(readLines(file.path(v2_dir, "assets", "js", "27x_conjoint.js"),
                          warn = FALSE), collapse = "\n")
  # bundle_report_v2_js refuses a bundle containing either sequence.
  expect_false(grepl("</script", view, fixed = TRUE))
  expect_false(grepl("<!--", view, fixed = TRUE))
})

test_that("the shell shows the tab only when there is a contribution", {
  shell <- paste(readLines(file.path(v2_dir, "assets", "js", "24_shell.js"),
                           warn = FALSE), collapse = "\n")

  expect_true(grepl('TR.CJ = parseIsland("data-cj")', shell, fixed = TRUE))
  expect_true(grepl("TR.conjoint && TR.conjoint.available()", shell, fixed = TRUE))
  expect_true(grepl('d2.state.tab === "conjoint") TR.conjoint.render(host)',
                    shell, fixed = TRUE))

  # Frozen: the audience filter cannot apply, so the bar is hidden — the same
  # treatment Tracking gets, for the same reason.
  expect_true(grepl('d2.state.tab === "conjoint";', shell, fixed = TRUE))
})

test_that("the view reports availability correctly", {
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")

  script <- tempfile(fileext = ".js")
  on.exit(unlink(script), add = TRUE)

  writeLines(c(
    'global.window = global;',
    'global.TR = {};',
    'require(' , shQuote(file.path(v2_dir, "assets", "js", "27x_conjoint.js")), ');',
    'var cj = global.TR.conjoint;',
    'var out = [];',
    'global.TR.CJ = null;                       out.push(cj.available() === false);',
    'global.TR.CJ = {};                         out.push(cj.available() === false);',
    'global.TR.CJ = { meta: {}, utilities: [] }; out.push(cj.available() === false);',
    'global.TR.CJ = { meta: { method: "hb" }, utilities: [{ attribute: "Brand" }] };',
    'out.push(cj.available() === true);',
    'console.log(out.every(Boolean) ? "OK" : "FAIL " + out.join(","));'
  ), script)

  out <- paste(suppressWarnings(
    system2(node, shQuote(script), stdout = TRUE, stderr = TRUE)), collapse = " ")
  expect_equal(out, "OK")
})

test_that("the view renders a real island without throwing", {
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")

  script <- tempfile(fileext = ".js")
  on.exit(unlink(script), add = TRUE)

  writeLines(c(
    'global.window = global;',
    'global.TR = {};',
    'require(', shQuote(file.path(v2_dir, "assets", "js", "27x_conjoint.js")), ');',
    'global.TR.CJ = {',
    '  meta: { methodLabel: "Hierarchical Bayes", method: "hierarchical_bayes",',
    '          nRespondents: 300, nChoiceSets: 3600, converged: true,',
    '          zeroCentred: true, frozen: true,',
    '          filterNote: "Does not respond to the audience filter.",',
    '          unweightedNote: "Estimated unweighted." },',
    '  utilities: [{ attribute: "Brand & Co <script>", levels: ["Alpha", "Beta"],',
    '                utility: [0.5, -0.5], se: [0.1, 0.1],',
    '                ciLower: [0.3, -0.7], ciUpper: [0.7, -0.3],',
    '                heterogeneity: [0.8, 0.9], pValue: [0.001, 0.001],',
    '                isBaseline: [true, false] }],',
    '  importance: { method: "individual", attribute: ["Brand"],',
    '                importance: [100], sd: [12] },',
    '  fit: { mcFaddenR2: 0.31, hitRate: 0.65, chanceRate: 0.33,',
    '         logLikelihoodFitted: -284.7, logLikelihoodNull: -438.6,',
    '         nObservations: 1200, nParameters: 7 },',
    '  wtp: { priceAttribute: "Price", currency: "R", attribute: ["Brand"],',
    '         level: ["Beta"], wtp: [42.5], ciLower: [30], ciUpper: [55],',
    '         isBaseline: [false], intervalNote: "Approximate." }',
    '};',
    'var host = { innerHTML: "" };',
    'global.TR.conjoint.render(host);',
    'var h = host.innerHTML;',
    'var checks = [',
    '  h.indexOf("Hierarchical Bayes") !== -1,',
    '  h.indexOf("Attribute importance") !== -1,',
    '  h.indexOf("Part-worth utilities") !== -1,',
    '  h.indexOf("Model fit") !== -1,',
    '  h.indexOf("Willingness to pay") !== -1,',
    '  h.indexOf("Heterogeneity (SD)") !== -1,',
    '  h.indexOf("audience filter") !== -1,',
    '  h.indexOf("&lt;script&gt;") !== -1,',   # the attribute name is escaped
    '  h.indexOf("<script>") === -1',
    '];',
    'console.log(checks.every(Boolean) ? "OK" : "FAIL " + checks.join(","));'
  ), script)

  out <- paste(suppressWarnings(
    system2(node, shQuote(script), stdout = TRUE, stderr = TRUE)), collapse = " ")
  expect_equal(out, "OK")
})

test_that("an empty island renders a message rather than throwing", {
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")

  script <- tempfile(fileext = ".js")
  on.exit(unlink(script), add = TRUE)

  writeLines(c(
    'global.window = global;',
    'global.TR = {};',
    'require(', shQuote(file.path(v2_dir, "assets", "js", "27x_conjoint.js")), ');',
    'global.TR.CJ = null;',
    'var host = { innerHTML: "" };',
    'global.TR.conjoint.render(host);',
    'console.log(host.innerHTML.indexOf("no conjoint results") !== -1 ? "OK" : "FAIL");'
  ), script)

  out <- paste(suppressWarnings(
    system2(node, shQuote(script), stdout = TRUE, stderr = TRUE)), collapse = " ")
  expect_equal(out, "OK")
})
