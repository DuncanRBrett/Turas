# ==============================================================================
# RENDER GATE. What a client opens, rendered, before and after minification
# ==============================================================================
#
# turas_minify() changes every Turas deliverable across every module. Until this
# file existed, nothing rendered the result. run_minify_verification() checks
# that sizes fell and that forbidden strings went, which is not the same as
# checking that the report still works.
#
# Two things are gated here.
#
#   1. The v2 tabs report, in all three delivery modes (respondent records,
#      aggregate cube, published tables only) plus one carrying every
#      contribution island. Development build and client
#      deliverable are each rendered in headless Chrome, and the gate asserts:
#      no fatal panel, no console errors, the same island contents loaded, and
#      the rendered table cells identical text for text. The fixture comes from
#      the committed parity islands, so no pipeline run and no examples/ output
#      is involved.
#
#   2. Every legacy report in examples/ that still carries inline handlers. The
#      obfuscator profile is shared, so a change made for the v2 report reaches
#      the pricing, maxdiff, conjoint and v1 tabs reports too. There, an
#      onclick="foo()" that no longer resolves is a dead button and nothing
#      else says so. .verify_js_handler_functions() is skipped once a file is
#      obfuscated, so this was untested. The gate evaluates every unique handler
#      name in the rendered page and fails on any that is not a function.
#
# Skips, loudly, when Google Chrome or the node build tools are absent.
#
# Run: Rscript -e 'testthat::test_file("modules/shared/tests/testthat/test_minify_render_gate.R")'
# ==============================================================================

library(testthat)

turas_root <- local({
  path <- Sys.getenv("TURAS_ROOT", getwd())
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "tabs"))) {
      return(normalizePath(path, mustWork = FALSE))
    }
    path <- dirname(path)
  }
  ""
})

shared_lib <- file.path(turas_root, "modules", "shared", "lib")
if (nzchar(turas_root) && dir.exists(shared_lib)) {
  for (f in c("trs_refusal.R", "turas_minify_verify.R", "turas_minify_watermark.R",
              "turas_release_audit.R", "turas_minify.R")) {
    suppressWarnings(source(file.path(shared_lib, f)))
  }
}

CHROME <- "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

.gate_ready <- function() {
  nzchar(turas_root) && file.exists(CHROME) &&
    exists("turas_minify", mode = "function") &&
    nzchar(.minify_find_tool("terser")) &&
    nzchar(.minify_find_tool("javascript-obfuscator"))
}

.gate_skip_reason <- function() {
  if (!nzchar(turas_root)) return("Turas root not found")
  if (!file.exists(CHROME)) {
    return(paste("Google Chrome not found at", CHROME,
                 "- the render gate cannot run, so nothing here was checked"))
  }
  if (!exists("turas_minify", mode = "function")) return("turas_minify.R not loaded")
  if (!nzchar(.minify_find_tool("terser"))) return("terser not installed")
  if (!nzchar(.minify_find_tool("javascript-obfuscator"))) {
    return("javascript-obfuscator not installed")
  }
  "ready"
}

# -- The probe -----------------------------------------------------------------
# Appended to a copy of the report, never to the report itself. Runs 2.5 seconds
# after load so an async boot has finished, then writes one JSON blob into a
# <pre> the harness reads out of the dumped DOM. Reading the cells out of a
# dedicated element rather than off the page avoids matching the development
# bundle's own template strings, which contain <td> markup as text.

.probe_js <- function(handler_names = character(0)) {
  handlers <- if (length(handler_names)) {
    paste0("[", paste(sprintf('"%s"', handler_names), collapse = ","), "]")
  } else "[]"
  paste0(
    '<script>window.addEventListener("load",function(){setTimeout(function(){',
    'var o={};try{',
    'o.fatal=!!document.querySelector(".fatal");',
    'o.els=document.querySelectorAll("#app *").length;',
    'o.cells=Array.prototype.map.call(document.querySelectorAll("#app td"),',
    'function(t){return t.textContent.trim()});',
    'o.micro=(window.TR&&TR.MICRO)?TR.MICRO.n:null;',
    'o.agg=(window.TR&&TR.AGG)?Object.keys(TR.AGG).length:null;',
    'o.cube=(window.TR&&TR.CUBE)?Object.keys(TR.CUBE).length:null;',
    'o.bad=', handlers, '.filter(function(n){return typeof window[n]!=="function"});',
    # What saveCopy() writes. It clones documentElement and rewrites only
    # user-state, so every other island should leave with its encoding and its
    # data-k intact, and should still decode. Checked here, in a real browser on
    # a real deliverable, rather than against a stubbed DOM.
    'o.clone=(function(){var c=document.documentElement.cloneNode(true);',
    'var u=c.querySelector("#user-state");if(u){u.textContent="{}"}',
    'var a=c.querySelector("#data-agg");if(!a){return "no-agg"}',
    'var k=a.getAttribute("data-k"),body=a.textContent,plain=true;',
    'try{JSON.parse(body)}catch(e){plain=false}',
    'var dec=false;try{JSON.parse(TR.shell._decodeIsland(body,k));dec=true}catch(e){}',
    'return{k:k||null,bodyIsJson:plain,decodes:dec}})();',
    '}catch(e){o.probeError=String(e)}',
    'var p=document.createElement("pre");p.id="turas-probe";',
    'p.textContent=JSON.stringify(o);document.body.appendChild(p)},2500)})</script>'
  )
}

# -- The srcdoc probe ----------------------------------------------------------
# The maxdiff report embeds its whole simulator in an iframe srcdoc attribute.
# A srcdoc document reports its origin as null, so the worry was that nothing
# could check it. It can: the top document reaches iframe.contentDocument and
# contentWindow fine (measured 4 September 2026). This probe walks in and
# reports what the simulator actually loaded, which is the only way a change to
# the embedded simulator can be gated at all.

.iframe_probe_js <- function() {
  paste0(
    '<script>window.addEventListener("load",function(){setTimeout(function(){',
    'var o={};try{',
    'var f=document.querySelector("#panel-simulator iframe")||document.querySelector("iframe[srcdoc]");',
    'o.frame=!!f;',
    'var d=f?f.contentDocument:null;var w=f?f.contentWindow:null;',
    'o.reachable=!!d;',
    'o.innerScripts=d?d.querySelectorAll("script").length:null;',
    'o.innerBodyEls=d?d.querySelectorAll("body *").length:null;',
    'o.innerTitle=d?(d.title||""):null;',
    # The simulator's public surface. Obfuscation keeps object property names,
    # and it has to: the pin buttons are built at runtime carrying
    # onclick="TurasPins.move(...)", so those names are load-bearing.
    'o.globals=["SimEngine","SimUI","SimCharts","SimExport","TurasPins"].filter(',
    'function(n){return w&&typeof w[n]!=="undefined"});',
    'o.pinMethods=["move","copyToClipboard","exportCard","exportSinglePptx"].filter(',
    'function(n){return w&&w.TurasPins&&typeof w.TurasPins[n]==="function"});',
    'o.engineKeys=(w&&w.SimEngine)?Object.keys(w.SimEngine).sort():null;',
    # The simulator carries its own islands and has no decoder, so they must
    # come back as plain JSON or it boots blank.
    'o.islandsPlain=(function(){if(!d){return null}',
    'var ids=["sim-data","pinned-views-data"],ok=[];',
    'for(var i=0;i<ids.length;i++){var el=d.getElementById(ids[i]);',
    'if(el){try{JSON.parse(el.textContent);ok.push(ids[i])}catch(e){}}}',
    'return ok})();',
    '}catch(e){o.probeError=String(e)}',
    'var p=document.createElement("pre");p.id="turas-probe";',
    'p.textContent=JSON.stringify(o);document.body.appendChild(p)},3000)})</script>'
  )
}

#' Render one HTML file in headless Chrome and read the probe back
#'
#' @param path HTML file to render. Not modified: a probed copy is rendered.
#' @param fragment URL fragment, e.g. "#tab=crosstabs&q=Q001".
#' @param handler_names Inline handler names to check resolve to functions.
#' @param probe The script to splice in. Defaults to the top-document probe;
#'   the srcdoc gate passes .iframe_probe_js() to read the simulator instead.
#' @return List with the probe fields plus console_errors.
.render_probe <- function(path, fragment = "", handler_names = character(0),
                          probe = NULL) {
  html <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  # Before the LAST </body>, not the first. The maxdiff report embeds its
  # simulator in an iframe srcdoc attribute, so the first </body> in the file is
  # inside that attribute value, and a probe spliced there would be swallowed by
  # the attribute and its quotes would terminate it.
  ends <- gregexpr("</body>", html, fixed = TRUE)[[1]]
  if (ends[1] == -1L) stop("no </body> in ", path)
  at <- ends[length(ends)]
  probe_script <- if (is.null(probe)) .probe_js(handler_names) else probe
  probed <- paste0(substr(html, 1L, at - 1L), probe_script,
                   substr(html, at, nchar(html)))
  tmp_html <- file.path(dirname(path),
                        paste0("probe_", basename(tempfile()), ".html"))
  writeLines(probed, tmp_html, useBytes = TRUE)
  out_file <- tempfile(fileext = ".dom")
  err_file <- tempfile(fileext = ".log")
  on.exit(unlink(c(tmp_html, out_file, err_file)), add = TRUE)

  # No --user-data-dir. Pointed at a fresh temporary profile, headless Chrome
  # runs first-run setup and never exits, which hangs the gate rather than
  # failing it (measured on this machine, 4 September 2026). The default
  # profile renders and exits in about four seconds. The timeout is the
  # backstop: a render that hangs must fail the gate, not block it.
  status <- tryCatch(
    system2(CHROME,
            args = c("--headless=new", "--disable-gpu", "--no-sandbox",
                     "--virtual-time-budget=8000", "--enable-logging=stderr", "--v=0",
                     "--dump-dom", shQuote(paste0("file://", tmp_html, fragment))),
            stdout = out_file, stderr = err_file, timeout = 90),
    error = function(e) e
  )
  if (inherits(status, "error")) {
    return(list(found = FALSE, console_errors = character(0),
                stderr_tail = paste("Chrome did not finish in 90 seconds:",
                                    conditionMessage(status))))
  }

  dom <- paste(readLines(out_file, warn = FALSE), collapse = "\n")
  err_lines <- readLines(err_file, warn = FALSE)
  console_errors <- grep("Error|Uncaught", err_lines, value = TRUE)

  m <- regexpr('<pre id="turas-probe">[\\s\\S]*?</pre>', dom, perl = TRUE)
  if (m == -1L) {
    return(list(found = FALSE, console_errors = console_errors,
                stderr_tail = utils::tail(err_lines, 5)))
  }
  blob <- substr(dom, m + nchar('<pre id="turas-probe">'),
                 m + attr(m, "match.length") - nchar("</pre>") - 1L)
  blob <- gsub("&lt;", "<", blob, fixed = TRUE)
  blob <- gsub("&gt;", ">", blob, fixed = TRUE)
  blob <- gsub("&quot;", '"', blob, fixed = TRUE)
  blob <- gsub("&amp;", "&", blob, fixed = TRUE)
  parsed <- jsonlite::fromJSON(blob, simplifyVector = TRUE)
  parsed$found <- TRUE
  parsed$console_errors <- console_errors
  parsed
}

#' Reduce a Chrome stderr console line to its message
#'
#' Drops the process and timestamp prefix, any file:// URL, and the trailing
#' "source: <file> (<line>)". The line number is the point: minification
#' collapses a report to a handful of lines, so the identical error is reported
#' at line 9340 in the development copy and at line 4 in the deliverable. What
#' the gate compares is whether the deliverable introduced an error the
#' development build did not have, and that is the message text.
.normalise_console <- function(lines) {
  x <- sub("^\\[[^]]*\\]\\s*", "", lines)
  x <- sub(",?\\s*source:.*$", "", x)
  x <- gsub("file://[^\"', ]*", "<url>", x)
  unique(trimws(x))
}

#' Every unique inline handler name in an HTML file
.inline_handler_names <- function(html) {
  m <- gregexpr('on(click|change|input)="([A-Za-z_$][\\w$]*)\\(', html, perl = TRUE)[[1]]
  if (m[1] == -1L) return(character(0))
  starts <- attr(m, "capture.start")[, 2]
  lens <- attr(m, "capture.length")[, 2]
  unique(substring(html, starts, starts + lens - 1L))
}

# ==============================================================================
# 1. The v2 tabs report, three delivery modes, development against deliverable
# ==============================================================================

test_that("the v2 report renders identically before and after a deliverable build", {
  reason <- .gate_skip_reason()
  if (!identical(reason, "ready")) {
    cat("\n  [RENDER GATE SKIPPED]", reason, "\n")
    skip(reason)
  }

  source(file.path(turas_root, "modules/tabs/tests/fixtures/parity_project",
                   "build_gate_reports.R"))
  work <- tempfile(pattern = "render_gate"); dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  built <- build_gate_reports(work, turas_root)

  for (mode in names(built)) {
    dev_path <- built[[mode]]
    prod_path <- file.path(work, sprintf("%s_min.html", mode))
    res <- suppressWarnings(turas_minify(dev_path, output_path = prod_path,
                                         verbose = FALSE, deliverable = TRUE))
    expect_true(res$status %in% c("PASS", "PARTIAL"),
                info = sprintf("%s: minify status %s", mode, res$status))
    expect_true(res$js_blocks_obfuscated >= 1L,
                info = sprintf("%s: nothing was obfuscated", mode))

    frag <- "#tab=crosstabs"
    d <- .render_probe(dev_path, frag)
    p <- .render_probe(prod_path, frag)

    expect_true(d$found, info = sprintf("%s: development build produced no probe", mode))
    expect_true(p$found, info = sprintf("%s: deliverable produced no probe", mode))
    expect_false(isTRUE(d$fatal), info = sprintf("%s: development build showed the fatal panel", mode))
    expect_false(isTRUE(p$fatal), info = sprintf("%s: deliverable showed the fatal panel", mode))
    expect_equal(length(p$console_errors), 0L,
                 info = sprintf("%s: console errors: %s", mode,
                                paste(utils::head(p$console_errors, 3), collapse = " | ")))

    expect_equal(p$agg, d$agg, info = sprintf("%s: TR.AGG key count moved", mode))
    expect_equal(p$micro %||% NA, d$micro %||% NA,
                 info = sprintf("%s: TR.MICRO moved", mode))
    expect_equal(p$cube %||% NA, d$cube %||% NA,
                 info = sprintf("%s: TR.CUBE moved", mode))
    expect_true(length(d$cells) > 0L, info = sprintf("%s: no cells rendered", mode))
    expect_identical(p$cells, d$cells,
                     info = sprintf("%s: rendered cell text differs", mode))

    # The islands are encoded in the deliverable and plain in the development
    # build, and a saved copy of the deliverable carries the encoding forward.
    expect_true(res$islands_encoded >= 1L,
                info = sprintf("%s: no islands were encoded", mode))
    expect_null(d$clone$k, info = sprintf("%s: development build carries data-k", mode))
    expect_true(isTRUE(d$clone$bodyIsJson),
                info = sprintf("%s: development island is not plain JSON", mode))
    expect_false(is.null(p$clone$k),
                 info = sprintf("%s: deliverable island has no data-k", mode))
    expect_false(isTRUE(p$clone$bodyIsJson),
                 info = sprintf("%s: deliverable island still parses as JSON", mode))
    expect_true(isTRUE(p$clone$decodes),
                info = sprintf("%s: a saved copy's island no longer decodes", mode))

    # Module stripping, both directions. The three reports built without
    # contribution islands must not carry their renderers; gate_contrib carries
    # all four islands and must carry all four renderers, or shell.boot()
    # refuses and the fatal check above would already have failed.
    dev_html <- paste(readLines(dev_path, warn = FALSE, encoding = "UTF-8"),
                      collapse = "\n")
    wanted <- identical(mode, "contrib")
    for (marker in c("TR.conjoint = {}", "TR.maxdiff = {}", "TR.pricing = {}",
                     "TR.qual || {}")) {
      expect_equal(grepl(marker, dev_html, fixed = TRUE), wanted,
                   info = sprintf("%s: renderer %s presence is wrong", mode, marker))
    }
  }
})

test_that("the aggregate cube survives a deliverable build and answers a filter", {
  reason <- .gate_skip_reason()
  if (!identical(reason, "ready")) {
    cat("\n  [RENDER GATE SKIPPED]", reason, "\n")
    skip(reason)
  }

  source(file.path(turas_root, "modules/tabs/tests/fixtures/parity_project",
                   "build_gate_reports.R"))
  work <- tempfile(pattern = "cube_gate"); dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  built <- build_gate_reports(work, turas_root)

  dev_path <- built[["cube"]]
  prod_path <- file.path(work, "cube_min.html")
  suppressWarnings(turas_minify(dev_path, output_path = prod_path,
                                verbose = FALSE, deliverable = TRUE))

  # The cube is the source a live filter recomputes from when the respondent
  # island is absent. A cube that loads but recomputes wrong is the silent
  # failure this asserts against: same filtered cells, development and shipped.
  frag <- "#tab=crosstabs"
  d <- .render_probe(dev_path, frag)
  p <- .render_probe(prod_path, frag)
  expect_true(d$found && p$found)
  expect_true(d$cube > 0L, info = "the fixture carries no cube")
  expect_equal(p$cube, d$cube)
  expect_identical(p$cells, d$cells)
})

# ==============================================================================
# 2. Legacy reports with inline handlers
# ==============================================================================

test_that("legacy reports still resolve every inline handler after a deliverable build", {
  reason <- .gate_skip_reason()
  if (!identical(reason, "ready")) {
    cat("\n  [RENDER GATE SKIPPED]", reason, "\n")
    skip(reason)
  }

  legacy <- c(
    "examples/pricing/Output/Karoo_Pricing_Results.html",
    "examples/maxdiff/Output/Karoo_MaxDiff_Results.html",
    "examples/tabs/demo_survey/Output/Demo_CX_Crosstabs.html",
    "examples/integrated_demo/Output/tabs/report/Karoo_Conjoint_Results_simulator.html",
    "examples/integrated_demo/Output/tabs/report/Karoo_MaxDiff_Results_simulator.html",
    "examples/integrated_demo/Output/tabs/report/Karoo_Pricing_Results_simulator.html"
  )
  present <- legacy[file.exists(file.path(turas_root, legacy))]
  if (length(present) == 0L) {
    cat("\n  [RENDER GATE SKIPPED] no legacy example reports on disk.",
        "Build them from examples/ to run this check.\n")
    skip("no legacy example reports on disk")
  }

  work <- tempfile(pattern = "legacy_gate"); dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)

  for (rel in present) {
    src <- file.path(turas_root, rel)
    dev_path <- file.path(work, basename(src))
    file.copy(src, dev_path, overwrite = TRUE)
    prod_path <- file.path(work, sub("\\.html$", "_min.html", basename(src)))

    html <- paste(readLines(dev_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    handlers <- .inline_handler_names(html)

    res <- suppressWarnings(turas_minify(dev_path, output_path = prod_path,
                                         verbose = FALSE, deliverable = TRUE))
    expect_true(res$status %in% c("PASS", "PARTIAL"),
                info = sprintf("%s: minify status %s", basename(src), res$status))

    d <- .render_probe(dev_path, handler_names = handlers)
    p <- .render_probe(prod_path, handler_names = handlers)
    expect_true(p$found, info = sprintf("%s: deliverable produced no probe", basename(src)))

    # Against the development build, not against zero. Two of these example
    # reports already log a console error before minification touches them
    # (the maxdiff simulator calls history.replaceState from inside an opaque
    # srcdoc iframe; the v1 tabs report references TurasPins before it loads).
    # Those are defects in the reports, recorded in the build note. What this
    # gate must catch is an error the deliverable introduced.
    introduced <- setdiff(.normalise_console(p$console_errors),
                          .normalise_console(d$console_errors))
    expect_equal(length(introduced), 0L,
                 info = sprintf("%s: console errors the deliverable introduced: %s",
                                basename(src),
                                paste(utils::head(introduced, 3), collapse = " | ")))
    expect_equal(length(p$bad), 0L,
                 info = sprintf("%s: %d inline handler(s) no longer resolve: %s",
                                basename(src), length(p$bad),
                                paste(utils::head(p$bad, 8), collapse = ", ")))
    cat(sprintf("  %-46s %3d handlers resolve, %d pre-existing console error(s), 0 introduced\n",
                basename(src), length(handlers),
                length(.normalise_console(d$console_errors))))
  }
})

# ==============================================================================
# 3. The maxdiff simulator inside its srcdoc iframe
# ==============================================================================
#
# The simulator is embedded as escaped attribute text, so every step of
# turas_minify() ran straight past it and it shipped readable. Step 2b now
# takes the embedded document out, puts it through the same pipeline, and puts
# it back. Nothing else in the suite can see inside that iframe, so this is the
# only check that the hardened simulator still boots.
#
# The fixture is built the way the report builds it: the standalone simulator,
# the tab-hiding injection, the builder's own two gsub() calls, embedded in a
# panel. Then the whole thing goes through turas_minify(deliverable = TRUE),
# which is the shipping path.

test_that("the simulator still boots after the deliverable hardens its srcdoc", {
  reason <- .gate_skip_reason()
  if (!identical(reason, "ready")) {
    cat("\n  [RENDER GATE SKIPPED]", reason, "\n")
    skip(reason)
  }

  sim_src <- file.path(
    turas_root,
    "examples/integrated_demo/Output/tabs/report/Karoo_MaxDiff_Results_simulator.html")
  if (!file.exists(sim_src)) {
    cat("\n  [RENDER GATE SKIPPED] no maxdiff simulator on disk.",
        "Build examples/integrated_demo to run this check.\n")
    skip("no maxdiff simulator on disk")
  }

  sim <- paste(readLines(sim_src, warn = FALSE, encoding = "UTF-8"),
               collapse = "\n")

  # modules/maxdiff/lib/html_report/03_page_builder.R, in miniature.
  inject <- '<style>[data-tab="overview"]{display:none!important}</style>'
  body <- sub("</head>", paste0(inject, "</head>"), sim, fixed = TRUE)
  esc <- gsub("&", "&amp;", body, fixed = TRUE)
  esc <- gsub('"', "&quot;", esc, fixed = TRUE)
  page <- sprintf(paste0(
    '<!DOCTYPE html><html><head><meta charset="utf-8"><title>gate</title>',
    '</head><body><div id="panel-simulator">',
    '<iframe srcdoc="%s" style="width:100%%;height:80vh;"></iframe>',
    '</div></body></html>'), esc)

  work <- tempfile(pattern = "srcdoc_gate"); dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  dev_path <- file.path(work, "report_dev.html")
  prod_path <- file.path(work, "report.html")
  writeLines(page, dev_path, useBytes = TRUE)

  res <- suppressWarnings(turas_minify(dev_path, output_path = prod_path,
                                       verbose = FALSE, deliverable = TRUE))
  # PARTIAL only ever means html-minifier-terser found nothing to collapse in a
  # page that is one big attribute. Verification is what must pass.
  expect_true(res$status %in% c("PASS", "PARTIAL"), info = res$status)
  expect_true(res$verification_passed)
  expect_equal(res$srcdoc_documents_hardened, 1L,
               info = "the embedded simulator was not hardened")

  # The internals must be gone from the delivered file. These are function
  # names from the simulator's own JavaScript, present in the readable build.
  delivered <- paste(readLines(prod_path, warn = FALSE, encoding = "UTF-8"),
                     collapse = "\n")
  for (nm in c("updateShares", "buildH2HSVG", "buildSharesSnapshot")) {
    if (grepl(nm, page, fixed = TRUE)) {
      expect_false(grepl(nm, delivered, fixed = TRUE),
                   info = sprintf("%s still readable in the deliverable", nm))
    }
  }

  d <- .render_probe(dev_path, probe = .iframe_probe_js())
  p <- .render_probe(prod_path, probe = .iframe_probe_js())

  expect_true(d$found, info = "the development build produced no probe")
  expect_true(p$found, info = "the deliverable produced no probe")
  expect_true(isTRUE(p$reachable), info = "could not reach into the iframe")

  # Everything the simulator needs, read from inside the iframe and compared
  # against the development build rather than against a hard-coded list.
  expect_equal(p$innerScripts, d$innerScripts,
               info = "the hardened simulator loaded a different number of scripts")
  expect_equal(p$innerBodyEls, d$innerBodyEls,
               info = "the hardened simulator rendered a different element count")
  expect_equal(p$innerTitle, d$innerTitle)
  expect_equal(sort(p$globals), sort(d$globals),
               info = sprintf("globals lost: %s",
                              paste(setdiff(d$globals, p$globals), collapse = ", ")))
  expect_equal(sort(p$pinMethods), sort(d$pinMethods),
               info = "a TurasPins method the pin buttons call did not survive")
  expect_equal(p$engineKeys, d$engineKeys,
               info = "the simulator engine's public surface changed")
  expect_equal(sort(p$islandsPlain), sort(d$islandsPlain),
               info = "an island stopped parsing as JSON, so the simulator boots blank")

  introduced <- setdiff(.normalise_console(p$console_errors),
                        .normalise_console(d$console_errors))
  expect_equal(length(introduced), 0L,
               info = sprintf("console errors the deliverable introduced: %s",
                              paste(utils::head(introduced, 3), collapse = " | ")))

  cat(sprintf("  srcdoc simulator: %d scripts, %d elements, %d globals, %d pin methods, islands %s\n",
              p$innerScripts, p$innerBodyEls, length(p$globals),
              length(p$pinMethods), paste(p$islandsPlain, collapse = "+")))
  cat(sprintf("  report carrying it: %s -> %s bytes\n",
              format(file.info(dev_path)$size, big.mark = ","),
              format(file.info(prod_path)$size, big.mark = ",")))
})
