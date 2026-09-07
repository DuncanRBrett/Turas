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
# These tests cover five things:
#   1. a marked island is hardened, and its payload still decodes to the page
#   2. a page whose script is NOT wrapped is caught rather than shipped
#   3. a page that was never marked at all is caught rather than shipped
#   4. hardening a report that was already hardened refuses, and says so
#   5. the mask under the extractor keeps its positions (section 8)
#
# The last two are the ones that matter, and they cover the two ways this can
# look like it worked when it did not. Hardening an unwrapped page strips its
# comments and scrambles the core while leaving every function name, because the
# obfuscator runs with renameGlobals false by design. And an unmarked island is
# not hardened at all, silently, which is how the VAS report shipped in the
# first place.
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
.island_page <- function(wrapped, indent = "") {
  body <- paste0(
    'const SECTIONDATA = {"section":"Bills","n":1100,"rows":[1,0,1]};\n',
    'function itemStatistics(d) { return d.rows.length; }\n',
    'function renderTheSummary(d) {\n',
    '  document.getElementById("out").textContent = "n=" + d.n;\n',
    '}\n',
    'function medianValueOf(a) { return a[Math.floor(a.length / 2)]; }\n',
    'renderTheSummary(SECTIONDATA);\n'
  )
  # `indent` is what a Python template does to a page script it embeds inside
  # an indented block: every line moves right, and the scope does not move at
  # all.
  if (nzchar(indent)) body <- gsub("(?m)^", indent, body, perl = TRUE)
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
.composed_html <- function(wrapped = TRUE, marker = 'data-embed="document"',
                           indent = "") {
  payload <- gsub("</", "<\\\\/",
                  as.character(jsonlite::toJSON(.island_page(wrapped, indent),
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

test_that("the leak gate reads a declaration wherever it sits on the line", {
  # Scope is syntactic, not typographic. A Python template that indents the
  # page script it embeds still declares at top level, and the obfuscator
  # leaves those names alone exactly as it would at column 0. An earlier
  # version of the gate anchored to the line start and let such a page ship
  # with every name intact (independent review, 7 September 2026).
  src <- "    function itemStatistics(d){return 1}\n    const SECTIONDATA = {}\n"
  expect_setequal(
    .minify_leaked_top_level_names(
      src, "    function itemStatistics(a){}\n    const SECTIONDATA={}"),
    c("SECTIONDATA", "itemStatistics"))

  # Minified source: declarations after a semicolon on one line.
  src1 <- "const A={};function bOne(){};function cTwo(){}"
  expect_setequal(
    .minify_leaked_top_level_names(src1, "const A={};function bOne(){}"),
    c("A", "bOne"))

  # An inner declaration is renamed by the obfuscator and so never survives
  # into the output as a declaration. Nothing to flag.
  src2 <- "(function(){\n  function innerHelper(){}\n})();\n"
  expect_length(.minify_leaked_top_level_names(src2, "var _0x1=function(){}"), 0L)

  # `$` is legal in an identifier and an anchor in a regex. Quote it.
  src3 <- "function $helper(d){return d}\n"
  expect_identical(.minify_leaked_top_level_names(src3, "function $helper(d){}"),
                   "$helper")
  expect_length(.minify_leaked_top_level_names(src3, "function $helperX(d){}"), 0L)

  # A keyword inside a longer word is not a declaration.
  src4 <- "var count = 1;\n"
  expect_length(.minify_leaked_top_level_names(src4, "myvar count = 1"), 0L)
})

test_that("script source excludes data islands, so verbatim text is not a declaration", {
  # A JSON island quoting "we let staff go" looks like `let staff` to an
  # unanchored regex. .minify_script_source() drops JSON and text/plain blocks,
  # which is the same set step 6b never hands to the obfuscator.
  html <- paste0(
    '<html><body>',
    '<script type="application/json" id="verbatim">',
    '{"c":["we let staff go","the var count rose","function names"]}</script>',
    '<script type="text/plain" id="hub">bGV0IHN0YWZm</script>',
    '<script>(function(){"use strict";var a=1;})();</script>',
    '</body></html>')
  src <- .minify_script_source(html)
  expect_false(grepl("staff", src, fixed = TRUE))
  expect_true(grepl("var a=1", src, fixed = TRUE))
  expect_identical(.minify_script_source("<html><body>no script</body></html>"), "")
})

test_that("obfuscator-shaped names are told apart from a page builder's", {
  expect_true(.minify_names_are_obfuscator_output(c("_0x1a2b", "a0_0x5f3a")))
  expect_false(.minify_names_are_obfuscator_output(c("_0x1a2b", "itemStats")))
  expect_false(.minify_names_are_obfuscator_output(character(0)))
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

test_that("an unwrapped page whose script is indented is refused just the same", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obf(), "javascript-obfuscator not available")

  # The case the line-anchored gate missed: PARTIAL, one island hardened, and
  # itemStatistics, renderTheSummary and SECTIONDATA all readable in the output.
  input <- .write_tmp(.composed_html(wrapped = FALSE, indent = "    "))
  out <- tempfile(pattern = "turas_composed_min_", fileext = ".html")

  err <- tryCatch({
    turas_minify(input, output_path = out, deliverable = TRUE, verbose = FALSE)
    NULL
  }, turas_refusal = function(e) e, error = function(e) e)

  expect_false(is.null(err))
  expect_true(grepl("CALC_MINIFY_ISLAND_NAMES_LEAKED", conditionMessage(err),
                    fixed = TRUE))
  expect_true(grepl("itemStatistics", conditionMessage(err), fixed = TRUE))
  expect_false(file.exists(out))
})

test_that("hardening a hardened composed report refuses and says so", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obf(), "javascript-obfuscator not available")

  # Compose first, harden last, once. A second pass finds the obfuscator's own
  # top-level names in the page and must not send the operator looking for a
  # wrapper that is already there.
  input <- .write_tmp(.composed_html(wrapped = TRUE))
  once <- tempfile(pattern = "turas_composed_once_", fileext = ".html")
  res <- turas_minify(input, output_path = once, deliverable = TRUE,
                      verbose = FALSE)
  expect_equal(res$island_documents_hardened, 1L)

  twice <- tempfile(pattern = "turas_composed_twice_", fileext = ".html")
  err <- tryCatch({
    turas_minify(once, output_path = twice, deliverable = TRUE, verbose = FALSE)
    NULL
  }, turas_refusal = function(e) e, error = function(e) e)

  expect_false(is.null(err))
  expect_true(grepl("CALC_MINIFY_ISLAND_ALREADY_HARDENED", conditionMessage(err),
                    fixed = TRUE))
  expect_false(grepl("CALC_MINIFY_ISLAND_NAMES_LEAKED", conditionMessage(err),
                     fixed = TRUE))
  expect_false(file.exists(twice))
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


# -- 7. The island nobody marked ----------------------------------------------
# The gate in section 4 protects the careful case: marked, but the page inside
# is not wrapped. This protects the forgetful one, which is likelier on the next
# composed report and is how VAS shipped readable in the first place.

test_that("an unmarked island carrying a page refuses the deliverable", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obf(), "javascript-obfuscator not available")

  input <- .write_tmp(.composed_html(wrapped = TRUE, marker = ""))
  out <- tempfile(fileext = ".html")

  err <- tryCatch({
    turas_minify(input, output_path = out, deliverable = TRUE, verbose = FALSE)
    NULL
  }, turas_refusal = function(e) e, error = function(e) e)

  expect_false(is.null(err))
  expect_true(grepl("CALC_MINIFY_ISLAND_DOC_UNMARKED", conditionMessage(err),
                    fixed = TRUE))
  # It has to name the island, or nobody can act on it.
  expect_true(grepl("page-bills", conditionMessage(err), fixed = TRUE))
})

test_that("the unmarked check does not fire on ordinary data islands", {
  # A manifest, a table island and a user-state island are all objects or
  # arrays, not bare strings, so none of them can be mistaken for a page.
  html <- paste0(
    '<!DOCTYPE html>\n<html><head><title>C</title></head><body>\n',
    '<script type="application/json" id="manifest">',
    '{"sections":[{"key":"a","html":"<html><script>x<\\/script><\\/html>"}]}',
    '</script>\n',
    '<script type="application/json" id="rows">[1,2,3]</script>\n',
    '<script type="application/json" id="user-state">null</script>\n',
    '<script type="application/json" id="empty"></script>\n',
    '</body></html>\n')
  expect_length(.minify_unmarked_document_islands(html), 0L)
})

test_that("the unmarked check does not fire on a string that is not a page", {
  # A verbatim comment quoting markup is a JSON string, but it is not a
  # document and carries no script.
  html <- paste0(
    '<!DOCTYPE html>\n<html><head><title>C</title></head><body>\n',
    '<script type="application/json" id="verbatim">',
    '"They said <b>the app<\\/b> was slow"</script>\n',
    '</body></html>\n')
  expect_length(.minify_unmarked_document_islands(html), 0L)
})

test_that("the unmarked check skips islands the other two mechanisms own", {
  page <- .island_page(TRUE)
  payload <- gsub("</", "<\\\\/",
                  as.character(jsonlite::toJSON(page, auto_unbox = TRUE)),
                  fixed = TRUE)
  # Marked for step 2c: that path handles it, so this must stay quiet.
  marked <- paste0('<!DOCTYPE html><html><head><title>C</title></head><body>',
                   '<script type="application/json" id="m" data-embed="document">',
                   payload, '</script></body></html>')
  expect_length(.minify_unmarked_document_islands(marked), 0L)

  # Already encoded by step 8c: the body is base64 and cannot be read as a
  # document, so re-running a minify over a finished file must not refuse.
  encoded <- paste0('<!DOCTYPE html><html><head><title>C</title></head><body>',
                    '<script type="application/json" id="e" data-island="v2" data-k="42">',
                    'd2hhdGV2ZXI=</script></body></html>')
  expect_length(.minify_unmarked_document_islands(encoded), 0L)
})

test_that("a development build is not refused for an unmarked island", {
  skip_if_not(.has_terser(), "terser not available")

  # Step 2c does not run at all without deliverable = TRUE, and a dev copy is
  # not a client file, so there is nothing here to protect.
  input <- .write_tmp(.composed_html(wrapped = TRUE, marker = ""))
  out <- tempfile(fileext = ".html")
  res <- turas_minify(input, output_path = out, deliverable = FALSE,
                      verbose = FALSE)
  expect_equal(res$island_documents_hardened, 0L)
  expect_true(file.exists(out))
})


# -- 8. The mask under the extractor ------------------------------------------
# .minify_mask_island_bodies() blanks every JSON island body before the
# extractor matches, so a page carried inside an island cannot contribute a
# stray opening tag. Every report goes through it, island or not. The premise
# is that blanking preserves length so positions index the original. These
# tests attack that premise directly, which the round-trip tests above only
# exercise by accident.

test_that("the mask preserves character positions through multi-byte text", {
  page <- paste0("<!doctype html><html><head><style>.a{color:red}</style></head>",
                 "<body>caf\u00e9 \u2014 \u00b7 \u4e2d\u6587 \U0001F600 ",
                 "<script>function pageFn(){return \"\u00e9\"}</script></body></html>")
  esc <- function(doc) gsub("</", "<\\\\/",
                            as.character(jsonlite::toJSON(doc, auto_unbox = TRUE)),
                            fixed = TRUE)
  html <- paste0(
    "<!DOCTYPE html><html><head><title>na\u00efve \u2014</title>",
    "<style>body{margin:0} /* before */</style></head><body>\u00e9\u00e9\u00e9",
    '<script type="application/json" id="p1" data-embed="document">', esc(page),
    "</script>",
    "<script>(function(){\"use strict\";var x=\"\u00e9\u4e2d\";})();</script>",
    "<style>.after{color:blue} /* after island */</style>",
    '<script type="application/json" id="rows">[1,2,3]</script>',
    "<script>var tail=\"\u2014\";</script></body></html>")

  masked <- .minify_mask_island_bodies(html)
  expect_identical(nchar(masked), nchar(html))
  # Idempotent: a masked copy has nothing left to mask.
  expect_identical(.minify_mask_island_bodies(masked), masked)
  # Outside the island bodies, byte for byte the same document.
  expect_identical(substr(masked, 1L, regexpr('id="p1"', html, fixed = TRUE)),
                   substr(html, 1L, regexpr('id="p1"', html, fixed = TRUE)))

  # The style element AFTER the islands is found, with its own content and not
  # a span that starts inside a page.
  styles <- .minify_extract_blocks(html, "style")
  expect_length(styles, 2L)
  expect_identical(styles[[2]]$content, ".after{color:blue} /* after island */")

  scripts <- .minify_extract_blocks(html, "script")
  expect_length(scripts, 4L)
  expect_identical(vapply(scripts, function(b) b$type, character(1)),
                   c("application/json", "", "application/json", ""))
  # The island's content is extracted from the ORIGINAL, not the blanks.
  p1 <- scripts[[1]]
  expect_identical(jsonlite::fromJSON(gsub("<\\/", "</", p1$content, fixed = TRUE)),
                   page)
  expect_identical(scripts[[4]]$content, "var tail=\"\u2014\";")
})

test_that("the mask is the identity on a report with no islands", {
  plain <- paste0("<html><head><style>a{}</style></head><body>\u00e9",
                  "<script>var a=1;</script></body></html>")
  expect_identical(.minify_mask_island_bodies(plain), plain)
})

test_that("an island with no closing tag is left alone, at the same length", {
  broken <- paste0('<html><body><script type="application/json" id="x">',
                   '{"a":1}<div>')
  masked <- .minify_mask_island_bodies(broken)
  expect_identical(masked, broken)
  expect_length(.minify_extract_blocks(broken, "script"), 0L)
})

test_that("an island open tag quoted inside a page or a JS string does no harm", {
  # A page inside an island brings its own <script type="application/json">
  # opening tag; the mask sees that tag too, and must not let it start a second
  # mask that runs past the island's real close.
  page <- paste0('<!doctype html><html><body>',
                 '<script type="application/json" id="inner">{"k":"v"}</script>',
                 '<script>function f(){}</script></body></html>')
  esc <- gsub("</", "<\\\\/",
              as.character(jsonlite::toJSON(page, auto_unbox = TRUE)),
              fixed = TRUE)
  html <- paste0('<html><head><style>q{}</style></head><body>',
                 '<script type="application/json" id="outer">', esc, '</script>',
                 '<style>.z{}</style><script>var end=1;</script></body></html>')
  expect_identical(nchar(.minify_mask_island_bodies(html)), nchar(html))
  styles <- .minify_extract_blocks(html, "style")
  expect_identical(vapply(styles, function(b) b$content, character(1)),
                   c("q{}", ".z{}"))
  scripts <- .minify_extract_blocks(html, "script")
  expect_length(scripts, 2L)
  expect_identical(scripts[[2]]$content, "var end=1;")

  # The same tag as text inside a real JS block. The mask blanks the tail of
  # that block in the search copy, and the extractor still returns the block
  # whole from the original.
  js <- paste0('<html><head><style>h{}</style></head><body>',
               '<script>var s="<script type=\\"application/json\\">";var t=1;</script>',
               '<style>.after{}</style>',
               '<script type="application/json" id="d">{"a":1}</script></body></html>')
  scripts <- .minify_extract_blocks(js, "script")
  expect_length(scripts, 2L)
  expect_identical(scripts[[1]]$content,
                   'var s="<script type=\\"application/json\\">";var t=1;')
  expect_identical(scripts[[2]]$content, '{"a":1}')
  expect_identical(vapply(.minify_extract_blocks(js, "style"),
                          function(b) b$content, character(1)),
                   c("h{}", ".after{}"))
})
