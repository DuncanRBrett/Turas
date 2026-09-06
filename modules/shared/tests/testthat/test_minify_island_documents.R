# ==============================================================================
# TESTS: Embedded documents carried as islands (turas_minify step 2c)
# ==============================================================================
# A composed report is built by stitching finished pages into a report that has
# already been hardened. The VAS integrated report does this: nineteen whole
# pages travel as `<script type="application/json">` islands and reach their
# iframe as a srcdoc PROPERTY, so step 2b (which matches the srcdoc ATTRIBUTE)
# never saw them and step 6b skips application/json by design. They shipped
# readable inside a file that was otherwise hardened.
#
# These tests cover the two halves of the fix:
#   1. a marked island is hardened, and its payload still decodes to the page
#   2. a page whose script is NOT wrapped is caught rather than shipped
#
# The second is the one that matters. Hardening an unwrapped page LOOKS like it
# worked (comments go, the core scrambles) while every function name survives,
# because the obfuscator runs with renameGlobals false by design.
# ==============================================================================

library(testthat)

turas_root <- Sys.getenv("TURAS_ROOT", getwd())
shared_paths <- c(
  file.path(turas_root, "modules", "shared", "lib"),
  file.path("modules", "shared", "lib"),
  file.path("..", "..", "lib")
)
shared_lib <- shared_paths[dir.exists(shared_paths)]
if (length(shared_lib) == 0L) skip("Cannot locate modules/shared/lib directory")
shared_lib <- shared_lib[1]

source(file.path(shared_lib, "turas_minify_verify.R"), local = FALSE)
source(file.path(shared_lib, "turas_minify_watermark.R"), local = FALSE)
source(file.path(shared_lib, "turas_release_audit.R"), local = FALSE)
source(file.path(shared_lib, "turas_minify.R"), local = FALSE)
trs_path <- file.path(shared_lib, "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path, local = FALSE)

.has_obf <- function() nzchar(.minify_find_tool("javascript-obfuscator"))
.has_terser <- function() nzchar(.minify_find_tool("terser"))


# -- Fixtures -----------------------------------------------------------------

# The embedded page. Shaped like a real VAS section report: one script block
# opening with a data constant, then the analytical functions.
.island_page <- function(wrapped) {
  body <- paste0(
    'const SECTIONDATA = {"section":"Bills","n":1100,"rows":[1,0,1]};\n',
    'function itemStatistics(d) { return d.rows.length; }\n',
    'function renderTheSummary(d) {\n',
    '  document.getElementById("out").textContent = "n=" + d.n;\n',
    '}\n',
    'function medianValueOf(a) { return a[Math.floor(a.length / 2)]; }\n',
    'renderTheSummary(SECTIONDATA);\n'
  )
  if (wrapped) body <- paste0('(function(){"use strict";\n', body, '\n})();')
  paste0(
    '<!DOCTYPE html>\n<html lang="en">\n<head>\n',
    '<meta charset="UTF-8"/>\n<title>Section</title>\n',
    '<style>.wrap { padding: 8px; } /* a note */</style>\n',
    '</head>\n<body>\n',
    '<!-- an architecture note that must not ship -->\n',
    '<div class="wrap"><span id="out"></span></div>\n',
    '<script>\n', body, '\n</script>\n',
    '</body>\n</html>\n'
  )
}

# The composed report: a shell with its own script, plus the page as a marked
# island. The `</` escape mirrors island() in build_vas_integrated_report.py.
.composed_html <- function(wrapped = TRUE, marker = 'data-embed="document"') {
  payload <- gsub("</", "<\\\\/",
                  as.character(jsonlite::toJSON(.island_page(wrapped),
                                                auto_unbox = TRUE)),
                  fixed = TRUE)
  paste0(
    '<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="UTF-8"/>\n',
    '<title>Composed</title>\n<style>body { margin: 0; }</style>\n</head>\n',
    '<body>\n<div id="app"></div>\n',
    '<script type="application/json" id="page-bills" ', marker, '>',
    payload, '</script>\n',
    '<script>\n(function(){"use strict";\n',
    '  var host = document.getElementById("app");\n',
    '  var page = JSON.parse(document.getElementById("page-bills").textContent);\n',
    '  host.innerHTML = "<iframe></iframe>";\n',
    '  host.querySelector("iframe").srcdoc = page;\n',
    '})();\n</script>\n</body>\n</html>\n'
  )
}

.write_tmp <- function(html) {
  p <- tempfile(pattern = "turas_composed_", fileext = ".html")
  writeLines(html, p, useBytes = TRUE)
  p
}

.read <- function(p) paste(readLines(p, warn = FALSE, encoding = "UTF-8"),
                           collapse = "\n")

# Pull one island body back out and undo both the `</` escape and the JSON.
.island_payload <- function(html, id) {
  blocks <- .minify_document_island_blocks(html)
  hit <- Filter(function(b) identical(.minify_block_id(b$open_tag), id), blocks)
  if (length(hit) == 0L) return(NA_character_)
  jsonlite::fromJSON(gsub("<\\/", "</", hit[[1]]$content, fixed = TRUE))
}


# -- 1. Finding the marked islands --------------------------------------------

test_that("only islands marked data-embed=document are picked up", {
  marked <- .minify_document_island_blocks(.composed_html())
  expect_length(marked, 1L)
  expect_identical(.minify_block_id(marked[[1]]$open_tag), "page-bills")

  # An unmarked island is somebody else's data, and must be left alone.
  expect_length(.minify_document_island_blocks(.composed_html(marker = "")), 0L)

  # data-island="v2" is the OTHER mechanism (step 8c encoding) and must not by
  # itself pull a payload into this step.
  expect_length(
    .minify_document_island_blocks(.composed_html(marker = 'data-island="v2"')),
    0L)
})


# -- 2. The leak gate, in isolation -------------------------------------------

test_that("leaked top-level names are detected and clean output is not flagged", {
  src <- "function itemStatistics(d){return 1}\nconst SECTIONDATA = {}\n"
  # setequal, not identical: sort() is locale-aware, so the order of a mixed
  # case pair is not the same everywhere and is not what this test is about.
  expect_setequal(
    .minify_leaked_top_level_names(
      src, "function itemStatistics(a){}var SECTIONDATA={}"),
    c("SECTIONDATA", "itemStatistics"))
  expect_length(.minify_leaked_top_level_names(src, "var _0x1=1;_0x1()"), 0L)
})

test_that("a name that survives as markup or a data key is not a leak", {
  # The regression that made this gate usable. `shares()` in the VAS betting
  # page also names a <div id="shares"> and a flags.shares data key. The
  # obfuscator preserves markup and property names on purpose, so searching the
  # output for the bare word refused a page whose function HAD been renamed.
  src <- "function shares(m){return m}\n"
  out <- paste0('<div id="shares"></div><div id="sharessub"></div>',
                "var _0x3f=function(_0x1){};{'flags':{'shares':!0x1}}")
  expect_length(.minify_leaked_top_level_names(src, out), 0L)

  # The same name, genuinely left as a declaration, is still caught.
  expect_identical(
    .minify_leaked_top_level_names(src, '<div id="shares"></div>function shares(m){}'),
    "shares")
})

test_that("the leak gate only reads declarations that start a line", {
  # An indented declaration is inside something, so it is already one scope
  # down and the obfuscator will rename it.
  src <- "(function(){\n  function innerHelper(){}\n})();\n"
  expect_length(.minify_leaked_top_level_names(src, "innerHelper"), 0L)
})


# -- 3. The round trip ---------------------------------------------------------

test_that("a marked island is hardened and still decodes to its page", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obf(), "javascript-obfuscator not available")

  input <- .write_tmp(.composed_html(wrapped = TRUE))
  out <- tempfile(pattern = "turas_composed_min_", fileext = ".html")
  res <- turas_minify(input, output_path = out, deliverable = TRUE,
                      verbose = FALSE)

  # PASS or PARTIAL. These fixtures are a few hundred bytes, so the string
  # array the obfuscator adds outweighs the document and trips the verifier's
  # "grew more than 200%" rule. A real composed report does not come close:
  # the nineteen VAS pages measured 5.95 MB in and 9.70 MB out, up 63%.
  expect_true(res$status %in% c("PASS", "PARTIAL"))
  expect_equal(res$island_documents_hardened, 1L)

  html <- .read(out)
  page <- .island_payload(html, "page-bills")

  # Still a whole document, still carrying the element the shell needs.
  expect_true(grepl("<html", page, fixed = TRUE))
  expect_true(grepl('id="out"', page, fixed = TRUE))

  # And hardened: names gone, comment gone.
  for (nm in c("itemStatistics", "renderTheSummary", "medianValueOf",
               "SECTIONDATA")) {
    expect_false(grepl(nm, page, fixed = TRUE), info = nm)
  }
  expect_false(grepl("architecture note", page, fixed = TRUE))
})

test_that("the escape survives, so the island cannot close its own script tag", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obf(), "javascript-obfuscator not available")

  input <- .write_tmp(.composed_html(wrapped = TRUE))
  out <- tempfile(pattern = "turas_composed_min_", fileext = ".html")
  turas_minify(input, output_path = out, deliverable = TRUE, verbose = FALSE)

  blocks <- .minify_document_island_blocks(.read(out))
  expect_length(blocks, 1L)
  # A bare `</` inside the body would have ended the element early, which means
  # extraction would have returned a truncated island or none at all.
  expect_false(grepl("</", blocks[[1]]$content, fixed = TRUE))
})


# -- 4. The gate on a real build -----------------------------------------------

test_that("an unwrapped page refuses the deliverable rather than shipping names", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obf(), "javascript-obfuscator not available")

  input <- .write_tmp(.composed_html(wrapped = FALSE))
  out <- tempfile(pattern = "turas_composed_min_", fileext = ".html")

  err <- tryCatch({
    turas_minify(input, output_path = out, deliverable = TRUE, verbose = FALSE)
    NULL
  }, turas_refusal = function(e) e, error = function(e) e)

  expect_false(is.null(err))
  expect_true(grepl("CALC_MINIFY_ISLAND_NAMES_LEAKED", conditionMessage(err),
                    fixed = TRUE))
  # It must name what leaked, or the operator cannot act on it.
  expect_true(grepl("itemStatistics", conditionMessage(err), fixed = TRUE))
})

test_that("a development build warns about the same page and still writes it", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obf(), "javascript-obfuscator not available")

  # deliverable = FALSE means step 2c does not run at all, so nothing is
  # hardened and nothing is claimed. This is the documented behaviour of 2b
  # too: the dev copy keeps its readable pages on purpose.
  input <- .write_tmp(.composed_html(wrapped = FALSE))
  out <- tempfile(pattern = "turas_composed_dev_", fileext = ".html")
  res <- turas_minify(input, output_path = out, deliverable = FALSE,
                      verbose = FALSE)
  expect_equal(res$island_documents_hardened, 0L)
  expect_true(file.exists(out))
})


# -- 5. Refusals on a malformed island ----------------------------------------

test_that("a page with a doctype but no <html> tag is still a document", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obf(), "javascript-obfuscator not available")

  # The html element's start tag is optional. Three of the nineteen VAS pages
  # omit it and open the doctype straight into <meta charset>, which an earlier
  # version of the guard refused as "not a whole HTML document".
  page <- paste0(
    '<!doctype html>\n<meta charset="utf-8">\n<title>Dash</title>\n',
    '<div id="out"></div>\n',
    '<script>\n(function(){"use strict";\n',
    'const DASHDATA = {"n": 1100};\n',
    'function renderTheDash(d){ document.getElementById("out").textContent = d.n; }\n',
    'renderTheDash(DASHDATA);\n})();\n</script>\n')
  payload <- gsub("</", "<\\\\/",
                  as.character(jsonlite::toJSON(page, auto_unbox = TRUE)),
                  fixed = TRUE)
  html <- paste0(
    '<!DOCTYPE html>\n<html><head><title>C</title>',
    '<style>body{margin:0}</style></head><body>\n',
    '<script type="application/json" id="dash" data-embed="document">',
    payload, '</script>\n',
    '<script>(function(){"use strict";var shellCounter=1;})();</script>\n',
    '</body></html>\n')

  input <- .write_tmp(html)
  out <- tempfile(fileext = ".html")
  res <- turas_minify(input, output_path = out, deliverable = TRUE,
                      verbose = FALSE)

  expect_equal(res$island_documents_hardened, 1L)
  page_back <- .island_payload(.read(out), "dash")
  expect_true(grepl("<!doctype", page_back, ignore.case = TRUE))
  expect_false(grepl("renderTheDash", page_back, fixed = TRUE))
  expect_false(grepl("DASHDATA", page_back, fixed = TRUE))
})

test_that("an island marked as a document but holding a fragment refuses", {
  skip_if_not(.has_terser(), "terser not available")

  html <- paste0(
    '<!DOCTYPE html>\n<html><head><title>T</title></head><body>\n',
    '<script type="application/json" id="not-a-page" data-embed="document">',
    '"<div>fragment only<\\/div>"</script>\n',
    '<script>var x = 1;</script>\n</body></html>\n')
  input <- .write_tmp(html)
  out <- tempfile(fileext = ".html")

  err <- tryCatch({
    turas_minify(input, output_path = out, deliverable = TRUE, verbose = FALSE)
    NULL
  }, turas_refusal = function(e) e, error = function(e) e)

  expect_false(is.null(err))
  expect_true(grepl("CALC_MINIFY_ISLAND_DOC_FAILED", conditionMessage(err),
                    fixed = TRUE))
})

test_that("an island whose body is not a JSON string refuses", {
  skip_if_not(.has_terser(), "terser not available")

  html <- paste0(
    '<!DOCTYPE html>\n<html><head><title>T</title></head><body>\n',
    '<script type="application/json" id="an-object" data-embed="document">',
    '{"not":"a document"}</script>\n',
    '<script>var x = 1;</script>\n</body></html>\n')
  input <- .write_tmp(html)
  out <- tempfile(fileext = ".html")

  err <- tryCatch({
    turas_minify(input, output_path = out, deliverable = TRUE, verbose = FALSE)
    NULL
  }, turas_refusal = function(e) e, error = function(e) e)

  expect_false(is.null(err))
  expect_true(grepl("CALC_MINIFY_ISLAND_DOC_FAILED", conditionMessage(err),
                    fixed = TRUE))
})


# -- 6. Nothing changes for a report that has no such islands -----------------

test_that("a report with no marked islands is untouched by step 2c", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obf(), "javascript-obfuscator not available")

  html <- paste0(
    '<!DOCTYPE html>\n<html><head><title>T</title>',
    '<style>body{margin:0}</style></head><body>\n',
    '<script type="application/json" id="plain-data">{"a":1}</script>\n',
    '<script>(function(){"use strict";var counterValue = 1;})();</script>\n',
    '</body></html>\n')
  input <- .write_tmp(html)
  out <- tempfile(fileext = ".html")
  res <- turas_minify(input, output_path = out, deliverable = TRUE,
                      verbose = FALSE)

  expect_equal(res$island_documents_hardened, 0L)
  expect_true(grepl('"a"', .read(out), fixed = TRUE))
})
