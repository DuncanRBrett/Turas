# ==============================================================================
# TESTS: SHARED PIN ISLAND IS SCRIPT-TAG HARDENED
# ==============================================================================
#
# TurasPins writes its pins into a <script> island with textContent and reads
# them back with JSON.parse. When a saved report is serialised via outerHTML, a
# markup-significant sequence in a pin title or insight breaks the island open:
# the closing tag no longer closes it and the next island is swallowed.
#
# Escaping only "</" is not the whole answer — "<!--" followed by "<script"
# enters the HTML parser's script double-escaped state, which is how a
# respondent pasting an HTML email into an open-end produced a blank tabs
# report (review 2026-08, I14). The R side answers this by escaping EVERY "<";
# this is the matching JS-side fix.
#
# Requires node. Skips honestly if absent.
# ==============================================================================

root <- Sys.getenv("TURAS_ROOT", unset = "")
if (!nzchar(root)) {
  dir <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in 1:8) {
    if (file.exists(file.path(dir, "modules", "shared", "js", "turas_pins.js"))) {
      root <- dir
      break
    }
    parent <- dirname(dir)
    if (parent == dir) break
    dir <- parent
  }
}
pins_js <- file.path(root, "modules", "shared", "js", "turas_pins.js")

test_that("the shared pins library is present and parses", {
  expect_true(file.exists(pins_js))

  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")

  status <- suppressWarnings(
    system2(node, c("--check", shQuote(pins_js)), stdout = FALSE, stderr = FALSE)
  )
  expect_equal(status, 0L)
})

test_that("_save escapes every < , not only </", {
  src <- paste(readLines(pins_js, warn = FALSE), collapse = "\n")

  expect_true(grepl('.replace(/</g, "\\\\u003c")', src, fixed = TRUE))
  expect_false(grepl("store.textContent = JSON.stringify(_pins);", src, fixed = TRUE))
})

# The two behavioural tests execute the exact write and read expressions
# _save/_load use, against payloads that have broken reports before.

run_node <- function(lines) {
  node <- unname(Sys.which("node"))
  if (!nzchar(node)) return(NA_character_)
  script <- tempfile(fileext = ".js")
  on.exit(unlink(script), add = TRUE)
  writeLines(lines, script)
  paste(suppressWarnings(
    system2(node, shQuote(script), stdout = TRUE, stderr = TRUE)
  ), collapse = " ")
}

test_that("a hostile pin round-trips through save and load intact", {
  skip_if(!nzchar(Sys.which("node")), "node not on PATH")

  out <- run_node(c(
    'var payloads = [',
    '  "plain text",',
    '  "Driver\'s assist",',
    '  "</script><script>alert(1)</script>",',
    '  "<!-- <script> double escaped",',
    '  "a < b && c > d",',
    '  "accents éè and \\"quotes\\""',
    '];',
    'var pins = payloads.map(function (p, i) {',
    '  return { type: "pin", id: "p" + i, title: p, insightText: p };',
    '});',
    'var written = JSON.stringify(pins).replace(/</g, "\\\\u003c");',
    'if (written.indexOf("<") !== -1) { console.log("FAIL raw-lt"); process.exit(0); }',
    'var back = JSON.parse(written);',
    'for (var i = 0; i < pins.length; i++) {',
    '  if (back[i].title !== pins[i].title) { console.log("FAIL title " + i); process.exit(0); }',
    '  if (back[i].insightText !== pins[i].insightText) { console.log("FAIL insight " + i); process.exit(0); }',
    '}',
    'console.log("OK " + pins.length);'
  ))

  expect_equal(out, "OK 6")
})

test_that("the escaped island cannot close its own script tag", {
  skip_if(!nzchar(Sys.which("node")), "node not on PATH")

  out <- run_node(c(
    'var pins = [{ type: "pin", id: "x", title: "</script>", insightText: "<!--<script>" }];',
    'var closing = "</scr" + "ipt";',
    'var island = "<script id=\\"s\\">" +',
    '  JSON.stringify(pins).replace(/</g, "\\\\u003c") + closing + ">";',
    'var hits = island.split(closing).length - 1;',
    'console.log(hits === 1 ? "OK" : "FAIL " + hits);'
  ))

  expect_equal(out, "OK")
})

test_that("the report hub's island is hardened the same way", {
  hub_js <- file.path(root, "modules", "report_hub", "js", "hub_pins.js")
  skip_if(!file.exists(hub_js), "report_hub not present")

  src <- paste(readLines(hub_js, warn = FALSE), collapse = "\n")

  # The hub writes its own island rather than going through TurasPins, so the
  # shared fix does not reach it. It had the identical vulnerability.
  expect_true(grepl('.replace(/</g, "\\\\u003c")', src, fixed = TRUE))
  expect_false(
    grepl('store.textContent = JSON.stringify(ReportHub.pinnedItems);',
          src, fixed = TRUE)
  )
})

test_that("no other file writes a pin island without escaping", {
  # W3b: the shared library and the hub are the only two writers. A third
  # would need the same hardening, and this is how it gets noticed.
  js_files <- list.files(file.path(root, "modules"), pattern = "_pins[.]js$",
                         recursive = TRUE, full.names = TRUE)
  expect_gt(length(js_files), 5)

  unescaped <- character(0)
  for (f in js_files) {
    src <- paste(readLines(f, warn = FALSE), collapse = "\n")
    writes <- grepl("textContent = JSON.stringify", src, fixed = TRUE)
    escaped <- grepl('.replace(/</g, "\\\\u003c")', src, fixed = TRUE)
    if (writes && !escaped) unescaped <- c(unescaped, basename(f))
  }

  expect_equal(unescaped, character(0))
})
