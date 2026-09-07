# ==============================================================================
# TURAS REPORT MINIFICATION PIPELINE
# ==============================================================================
#
# Post-processing pipeline that takes a finished Turas HTML report and produces
# a minified deliverable. Reduces file size and casual readability for IP
# protection. Operates on the final HTML output — does not modify R generation
# code.
#
# Dependencies:
#   - Node.js tools: terser, clean-css-cli, html-minifier-terser (optional;
#     graceful degradation if missing)
#   - R: base R only (no additional packages)
#   - turas_minify_verify.R (verification helpers, loaded via import_all.R)
#   - trs_refusal.R (TRS error handling, loaded via import_all.R)
#
# Usage:
#   result <- turas_minify("reports/Project_dev.html", verbose = TRUE)
#
# Version: 1.0
# Date: April 2026
# ==============================================================================


# -- Constants ----------------------------------------------------------------

.MINIFY_VERSION <- "2.0"

.MINIFY_COPYRIGHT_TEMPLATE <- "/*! @preserve Turas (c) TRL %s. All rights reserved. */"

.MINIFY_TERSER_ARGS <- c(
  "--compress", "passes=2,dead_code=true,drop_console=false",
  "--mangle", "toplevel=false",
  "--no-mangle-props",
  "--comments", "some",
  "--output", "beautify=false"
)

.MINIFY_CLEANCSS_ARGS <- c("-O1")

.MINIFY_HTML_ARGS <- c(
  "--collapse-whitespace",
  "--conservative-collapse",
  "--remove-comments"
)

# 180, not 60. A report with a large qualitative island takes longer to
# obfuscate than the demo's 3 seconds, and in a deliverable build a timeout is
# now a refusal rather than a quietly unobfuscated file.
.MINIFY_TOOL_TIMEOUT_SECS <- 180L

# javascript-obfuscator config, written to a temp JSON file per invocation and
# mirrored for the node gates in minify_profile.json.


# ---------------------------------------------------------------------------
# The release audit is this file's OWN dependency, loaded here rather than left
# to the caller.
#
# Step 8b below calls turas_release_audit(): it is the only thing standing
# between a client-safe declaration and a file that breaks it. Eight module GUIs
# source turas_minify.R independently and the audit was in none of their lists,
# so exists("turas_release_audit") was FALSE in every real build, the check was
# skipped in silence, and the declaration guarded nothing. Found 6 September 2026
# by running the audit by hand against a delivered SACS build and asking why the
# build had not refused.
#
# Pairing it with the file that uses it is what stops that returning: a ninth
# caller gets the audit without knowing it needs one.
.MINIFY_LIB_DIR <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) NA_character_)

.minify_load_release_audit <- function() {
  if (exists("turas_release_audit", mode = "function")) return(TRUE)
  candidates <- c(
    if (!is.na(.MINIFY_LIB_DIR)) file.path(.MINIFY_LIB_DIR, "turas_release_audit.R"),
    if (nzchar(Sys.getenv("TURAS_HOME")))
      file.path(Sys.getenv("TURAS_HOME"), "modules", "shared", "lib", "turas_release_audit.R"),
    file.path(getwd(), "modules", "shared", "lib", "turas_release_audit.R")
  )
  for (path in candidates) {
    if (!is.null(path) && file.exists(path)) {
      ok <- tryCatch({ source(path); TRUE }, error = function(e) FALSE)
      if (ok && exists("turas_release_audit", mode = "function")) return(TRUE)
    }
  }
  FALSE
}

.minify_load_release_audit()
#
# What survived the previous settings was property names and the one string in
# five that stringArrayThreshold 0.8 left alone. Raising the threshold to 1.0
# with rotation, index shift and wrappers, plus calls transform, split strings,
# transformObjectKeys, simplify and mangled-shuffled names, takes every measured
# readable identifier to zero. Measured 4 September 2026 on the Karoo demo:
# renderTab 4 to 0, encodeHash 2 to 0, coverFindings 1 to 0, zPrimary 1 to 0,
# activeQ 8 to 1. Cost is size, which Duncan has said is not a concern, and
# tens of milliseconds of boot.
#
# What is deliberately still false, and why:
#   renameGlobals       the legacy reports carry inline onclick handlers that
#                       reference top-level functions by name. 829 in the v1
#                       tabs demo, 59 in pricing. Renaming them is a dead button.
#   renameProperties    the renderer reads island keys straight off the JSON
#                       (q.code, col.base). A renamed accessor against an
#                       unrenamed key is a silent null, not an error.
#   controlFlowFlattening, deadCodeInjection
#                       measured: neither reduced any survivor count, because
#                       the settings above already reach zero. Flattening is the
#                       transform most likely to surface an edge case in a
#                       statistics engine years from now.
#   selfDefending, debugProtection, domainLock
#                       this file must still open, offline, in 2029.
#   numbersToExpressions
#                       it rewrites the constants in a statistics engine for no
#                       readability gain.
#   identifierNamesGenerator: "mangled-shuffled"
#                       measured to break the Conjoint simulator: under the
#                       seed below it produced "Uncaught TypeError: Cannot read
#                       properties of undefined (reading 'charAt')" on every
#                       build, and removing the setting cleared it on every
#                       build. Its only effect is what the already-mangled local
#                       names look like, so it buys no measured readability: the
#                       survivor counts are identical with and without it. A
#                       setting whose safety depends on which seed you picked
#                       does not belong in a file a client opens.
#   splitStrings        dropped on Duncan's instruction, 4 September 2026, to
#                       get the size back. It cost 385 KB on the Karoo demo and
#                       changed no survivor count: with stringArrayThreshold 1.0
#                       and base64 encoding every literal is already hidden in
#                       the array, so splitting them first added depth nobody
#                       could measure. Both simulators render clean without it.
#   transformObjectKeys measured to break the MaxDiff simulator. It rewrites an
#                       object literal into staged computed-key assignments, and
#                       the simulator's donut arc came out as
#                       "A 50 50 0 0 1 NaN NaN" in 3 of 20 builds, so the chart
#                       did not draw. Removing it: 0 of 34 builds. It was the
#                       only one of the five settings that changed anything.
#                       Bisected 4 September 2026 by a build-then-render loop,
#                       because at a 15 percent rate a single sample says
#                       nothing.
#
# seed is fixed on purpose. stringArrayShuffle and mangled-shuffled names
# otherwise make every build different, which is why the bisect above needed 14
# builds per variant to say anything, and which would make any future "the gate
# failed" report unreproducible. With a fixed seed the gate tests the bytes that
# ship, and a failure can be reproduced exactly.
#
# Changing any of this moves every module's deliverable at once. The gates are
# production_bundle_tests.mjs and test_minify_render_gate.R; run both.
.MINIFY_OBFUSCATOR_CONFIG_JSON <- '{
  "compact": true,
  "simplify": true,
  "stringArray": true,
  "stringArrayThreshold": 1,
  "stringArrayEncoding": ["base64"],
  "stringArrayShuffle": true,
  "stringArrayRotate": true,
  "stringArrayIndexShift": true,
  "stringArrayWrappersCount": 2,
  "stringArrayWrappersType": "function",
  "stringArrayWrappersChainedCalls": true,
  "stringArrayCallsTransform": true,
  "stringArrayCallsTransformThreshold": 0.5,
  "seed": 20260904,
  "controlFlowFlattening": false,
  "deadCodeInjection": false,
  "renameGlobals": false,
  "renameProperties": false,
  "selfDefending": false,
  "disableConsoleOutput": false,
  "log": false
}'

#' The build profile as the node gates read it
#'
#' The terser arguments and the obfuscator profile above are the single source
#' of truth. modules/shared/lib/minify_profile.json is a generated mirror of
#' them, so the node gate under
#' modules/tabs/lib/html_report_v2/tests/production_bundle_tests.mjs builds its
#' bundle with the settings the pipeline actually ships rather than a copy that
#' can drift. The obfuscator profile is spliced in as raw text, not re-encoded
#' through a list, because auto_unbox would collapse the one-element
#' stringArrayEncoding array into a string.
#'
#' Regenerate after changing either constant:
#'   Rscript -e 'source("modules/shared/lib/turas_minify.R"); .minify_write_profile_json()'
#'
#' @return Character, the exact JSON text of the generated mirror.
#' @keywords internal
.minify_profile_json_text <- function() {
  args_json <- as.character(jsonlite::toJSON(.MINIFY_TERSER_ARGS))
  paste0("{\n  \"terser_args\": ", args_json, ",\n  \"obfuscator\": ",
         .MINIFY_OBFUSCATOR_CONFIG_JSON, "\n}\n")
}

#' Write the generated profile mirror
#'
#' @param path Where to write. Defaults to the committed location.
#' @return Invisibly the path written.
#' @keywords internal
.minify_write_profile_json <- function(path = file.path("modules", "shared", "lib",
                                                        "minify_profile.json")) {
  cat(.minify_profile_json_text(), file = path)
  invisible(path)
}


.MINIFY_NODE_SEARCH_PATHS <- c(
  "/opt/homebrew/bin",       # macOS Homebrew (Apple Silicon)
  "/usr/local/bin",          # macOS Homebrew (Intel) / manual installs
  "/usr/bin",                # Linux system packages / Docker
  "/usr/lib/node_modules/.bin"  # Linux global npm fallback
)


# -- Path helpers -------------------------------------------------------------

#' Derive Output Path from Input Path
#'
#' Applies the naming convention: if input has _dev suffix, output removes it.
#' Otherwise appends _min suffix.
#'
#' @param input_path Character, path to input HTML file.
#' @return Character, derived output path.
#' @keywords internal
.minify_derive_output_path <- function(input_path) {
  dir_name <- dirname(input_path)
  base_name <- tools::file_path_sans_ext(basename(input_path))
  ext <- tools::file_ext(basename(input_path))

  if (grepl("_dev$", base_name)) {
    clean_name <- sub("_dev$", "", base_name)
  } else {
    clean_name <- paste0(base_name, "_min")
  }

  file.path(dir_name, paste0(clean_name, ".", ext))
}


# -- Tool availability --------------------------------------------------------

#' Find a Node.js Tool on the System
#'
#' Searches standard paths and PATH for a named tool (terser, cleancss, etc.).
#' Returns the full path if found, empty string if not.
#'
#' @param tool_name Character, name of the tool binary.
#' @return Character, full path to tool or empty string.
#' @keywords internal
.minify_find_tool <- function(tool_name) {
  # Try Sys.which first (respects PATH)
  found <- Sys.which(tool_name)
  if (nzchar(found)) return(as.character(found))

  # Search common Node.js install locations

  for (search_path in .MINIFY_NODE_SEARCH_PATHS) {
    candidate <- file.path(search_path, tool_name)
    if (file.exists(candidate)) return(candidate)
  }

  ""
}


#' Check All Required Tools and Return Availability Map
#'
#' @return Named list with node, terser, cleancss, html_minifier paths (empty
#'   string if not found).
#' @keywords internal
.minify_check_tools <- function() {
  list(
    node          = .minify_find_tool("node"),
    terser        = .minify_find_tool("terser"),
    cleancss      = .minify_find_tool("cleancss"),
    html_minifier = .minify_find_tool("html-minifier-terser"),
    obfuscator    = .minify_find_tool("javascript-obfuscator")
  )
}


# -- Embedded documents -------------------------------------------------------

#' Unescape one srcdoc attribute value back into a document
#'
#' Exactly reverses the escaping the maxdiff page builder applies
#' (`modules/maxdiff/lib/html_report/03_page_builder.R`): `&quot;` first, then
#' `&amp;`. Order matters and this direction is exact. An `&quot;` that was in
#' the source document is `&amp;quot;` in the attribute, which contains no
#' `&quot;` substring, so the first pass cannot touch it and the second returns
#' it intact. Verified byte for byte on the real report before this shipped.
#'
#' @keywords internal
.minify_srcdoc_unescape <- function(value) {
  value <- gsub("&quot;", '"', value, fixed = TRUE)
  gsub("&amp;", "&", value, fixed = TRUE)
}

#' Escape a document back into a srcdoc attribute value
#' @keywords internal
.minify_srcdoc_escape <- function(doc) {
  doc <- gsub("&", "&amp;", doc, fixed = TRUE)
  gsub('"', "&quot;", doc, fixed = TRUE)
}

#' Minify and obfuscate any document embedded in an iframe srcdoc attribute
#'
#' The maxdiff report embeds its whole simulator this way, about 1.2 MB of it.
#' Escaped into an attribute the simulator is text, not markup, so every step
#' below runs straight past it: .minify_extract_blocks() skips those script
#' tags on purpose, because handing attribute text to terser only produced
#' warnings. The consequence was that the one module whose simulator is the
#' interesting part shipped it readable inside an otherwise hardened file.
#'
#' The document is taken out, put through this same function, and put back. The
#' recursion terminates on its own: an embedded document contains no srcdoc of
#' its own, so the step is a no-op one level down. No depth guard is needed and
#' adding one would only hide a document that really did nest.
#'
#' Ranges are rewritten last to first so the earlier offsets stay valid.
#'
#' Runs on the deliverable path only. A development build keeps its readable
#' embedded document, which is the whole point of the dev copy: it is the file
#' someone opens when the report misbehaves.
#'
#' @param html Character. The whole document.
#' @param opts Named list of the arguments to pass down to the recursive call.
#' @param verbose Logical.
#' @return list(html, count, obfuscated). `count` is the number of embedded
#'   documents hardened; `obfuscated` says whether any of them actually had
#'   JavaScript obfuscated, which verification needs to know because a report
#'   whose only JavaScript lives inside a srcdoc has no block of its own.
#' @keywords internal
.minify_harden_srcdoc <- function(html, opts, verbose = FALSE) {
  ranges <- .minify_srcdoc_ranges(html)
  if (is.null(ranges) || nrow(ranges) == 0L) {
    return(list(html = html, count = 0L, obfuscated = FALSE))
  }

  prefix <- 'srcdoc="'
  hardened <- 0L
  obfuscated <- FALSE

  for (i in rev(seq_len(nrow(ranges)))) {
    start <- ranges$start[i]
    end <- ranges$end[i]
    value <- substr(html, start + nchar(prefix), end - 1L)
    if (!nzchar(value)) next

    inner <- .minify_srcdoc_unescape(value)
    # Only a whole document with script in it is worth the round trip, and only
    # a whole document is safe to attempt. The range regex is a text match, so
    # in principle a JavaScript string literal containing srcdoc=" could be
    # caught by it; requiring <html and <script means such a fragment is left
    # exactly as it was rather than being replaced by a minified version of
    # itself. A srcdoc carrying markup with no script has nothing to protect.
    if (!grepl("<html", inner, fixed = TRUE)) next
    if (!grepl("<script", inner, fixed = TRUE)) next

    work <- tempfile(pattern = "turas_srcdoc_", fileext = ".html")
    out <- tempfile(pattern = "turas_srcdoc_min_", fileext = ".html")
    on.exit(unlink(c(work, out)), add = TRUE)
    writeLines(inner, work, useBytes = TRUE)

    res <- tryCatch(
      turas_minify(work, output_path = out,
                   strip_meta = opts$strip_meta, minify_js = opts$minify_js,
                   minify_css = opts$minify_css, minify_html = opts$minify_html,
                   obfuscate_js = opts$obfuscate_js, watermark = opts$watermark,
                   client_safe = opts$client_safe, deliverable = opts$deliverable,
                   verbose = FALSE),
      # A refusal from the embedded document is a refusal of this build. It
      # already carries its own code, message and fix, so it passes through
      # rather than being re-wrapped into something less specific.
      turas_refusal = function(e) stop(e),
      error = function(e) e
    )

    if (inherits(res, "error")) {
      cat("\n+-- TURAS ERROR ----------------------------------------------+\n")
      cat("| Context:    Minify, embedded srcdoc document\n")
      cat("| Code:       CALC_MINIFY_SRCDOC_FAILED\n")
      cat("| Message:   ", conditionMessage(res), "\n")
      cat("+-------------------------------------------------------------+\n\n")
      turas_refuse(
        code = "CALC_MINIFY_SRCDOC_FAILED",
        title = "An embedded document could not be minified",
        problem = paste("The document inside an iframe srcdoc attribute could",
                        "not be processed:", conditionMessage(res)),
        why_it_matters = paste(
          "The maxdiff report carries its whole simulator in that attribute.",
          "Left unprocessed it ships readable inside a file that is otherwise",
          "hardened, which is the thing this build exists to stop."),
        how_to_fix = c(
          "The message above names the cause",
          "Or clear the client deliverable checkbox to keep a development build."),
        module = "MINIFY"
      )
    }

    # PASS and PARTIAL both write the file: PARTIAL only means the inner build
    # raised a warning, and any warning at all produces it. Requiring PASS here
    # would drop the hardening silently and ship the document readable, which
    # is the failure this step exists to prevent.
    if (!res$status %in% c("PASS", "PARTIAL") || !file.exists(out)) {
      cat("\n+-- TURAS ERROR ----------------------------------------------+\n")
      cat("| Context:    Minify, embedded srcdoc document\n")
      cat("| Code:       CALC_MINIFY_SRCDOC_FAILED\n")
      cat("| Message:    The embedded document came back as", res$status, "\n")
      cat("|             with no file written.\n")
      cat("+-------------------------------------------------------------+\n\n")
      turas_refuse(
        code = "CALC_MINIFY_SRCDOC_FAILED",
        title = "An embedded document could not be minified",
        problem = sprintf("The document inside an iframe srcdoc attribute returned %s and wrote no file.",
                          res$status),
        why_it_matters = paste(
          "The maxdiff report carries its whole simulator in that attribute.",
          "Left unprocessed it ships readable inside a file that is otherwise",
          "hardened, which is the thing this build exists to stop."),
        how_to_fix = c(
          "The messages above name the cause",
          "Or clear the client deliverable checkbox to keep a development build."),
        module = "MINIFY"
      )
    }
    if (length(res$warnings)) {
      for (w in res$warnings) {
        cat(sprintf("  [note] embedded document: %s\n", w))
      }
    }

    new_value <- .minify_srcdoc_escape(
      paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
    html <- paste0(substr(html, 1L, start - 1L),
                   prefix, new_value, '"',
                   substr(html, end + 1L, nchar(html)))
    hardened <- hardened + 1L
    obfuscated <- obfuscated || (res$js_blocks_obfuscated > 0L)
    if (verbose) {
      cat(sprintf("  Embedded document hardened: %d/%d JS blocks obfuscated\n",
                  res$js_blocks_obfuscated, res$js_blocks_processed))
    }
  }

  list(html = html, count = hardened, obfuscated = obfuscated)
}


# -- Embedded documents carried as islands ------------------------------------
#
# The srcdoc pair above hardens a document written into markup as an attribute.
# A composed report carries its pages the other way round: as a JSON island the
# shell reads and hands to an iframe as a srcdoc PROPERTY, which is markup to
# nobody and so was invisible to everything below.
#
# That is how the VAS integrated report shipped readable. Its thirteen section
# pages, the two cross-cutting pages, the wallet, the two profile pages and the
# dashboard all travel as `<script type="application/json">` islands, written
# by build_vas_integrated_report.py AFTER turas_minify() had already run over
# the crosstab report and closed it. Step 2b looks for `srcdoc="` and found
# none. Step 6b skips application/json by design. So nineteen whole pages, with
# their comments and their analytical function names, went out untouched inside
# a file that was otherwise hardened. Found 6 September 2026 by grepping the
# delivered file for `itemStats` and getting 65 hits.
#
# Opt-in, via data-embed="document" on the island. Automatic detection was the
# obvious alternative and is the wrong call: a page that genuinely publishes a
# global would be broken silently by hardening it, and the builder is the only
# thing that knows whether its page is self-contained.
#
# Deliberately NOT data-island="v2". These two mechanisms are independent and
# should stay that way. Once a page has been through here its data is already
# unreadable, because the obfuscator's string array swallows the JSON payload
# along with everything else; encoding it again in step 8c costs a further
# third of the file to hide what is already hidden. A caller that wants both
# can set both attributes.

#' Which script blocks are islands carrying a whole embedded document
#'
#' @param html The HTML string.
#' @return List of blocks from .minify_extract_blocks(), possibly empty.
#' @keywords internal
.minify_document_island_blocks <- function(html) {
  blocks <- .minify_extract_blocks(html, "script")
  Filter(function(b) {
    identical(b$type, "application/json") &&
      grepl("data-embed\\s*=\\s*[\"\']document[\"\']", b$open_tag, perl = TRUE) &&
      nzchar(trimws(b$content)) &&
      !identical(trimws(b$content), "null")
  }, blocks)
}


#' Names the source declared at top level that survived into the output
#'
#' The gate that stops this whole mechanism looking like it worked when it did
#' not. `minify_profile.json` sets renameGlobals false and terser runs with
#' --mangle toplevel=false, both deliberately, so a name declared in a script's
#' OUTERMOST scope is left alone. The Turas core escapes that only because its
#' bundle sits inside an IIFE, one scope down, where renaming is allowed.
#'
#' A page written without that wrapper therefore passes through the whole
#' hardening pass with every function name intact, and the file looks hardened
#' because its comments are gone and its core is scrambled. That is exactly what
#' the VAS pages did: comments 94 down to 1, and `itemStats` still there five
#' times.
#'
#' So the wrap is the page builder's job and this is the check that it was done.
#'
#' Both halves look for a DECLARATION, not for the bare name. Searching the
#' output for the name alone over-reports badly, because a function name often
#' matches something that is meant to survive: `shares()` in the VAS betting
#' page also names a `<div id="shares">` and a `flags.shares` data key, and the
#' obfuscator preserves markup and property names by design
#' (`renameProperties: false`). That produced a refusal on a page whose function
#' had in fact been renamed correctly. Matching `function shares` instead of
#' `shares` tells the two apart exactly: a renamed function leaves no
#' declaration behind under its old name.
#'
#' Declarations are collected from ANYWHERE in the source, not only from the
#' start of a line. An earlier version anchored to the line start on the
#' reasoning that an indented declaration must be inside something. Scope is
#' syntactic, not typographic: a Python template that indents its page script
#' by four spaces still declares at top level, and that version let such a
#' page ship with every name intact (found in the independent review, 7
#' September 2026). Dropping the anchor costs nothing on the other side,
#' because the obfuscator renames every binding that is not global, so an
#' inner declaration never survives verbatim into the output and can never
#' match here. The name is quoted with \\Q...\\E because `$` is legal in a
#' JavaScript identifier and a regex anchor otherwise.
#'
#' @param source_js The script body before hardening.
#' @param output The hardened script source, or the hardened document. Pass
#'   the script source where you can: a declaration can only live in a script.
#' @return Character vector of leaked names, empty when clean.
#' @keywords internal
.minify_leaked_top_level_names <- function(source_js, output) {
  decl <- "(?<![\\w$])(?:async\\s+)?(?:function|const|let|var|class)\\s+"
  m <- gregexpr(paste0(decl, "([A-Za-z_$][\\w$]*)"), source_js, perl = TRUE)[[1]]
  if (m[1] == -1L) return(character(0))
  starts <- attr(m, "capture.start")
  lens <- attr(m, "capture.length")
  names_found <- unique(substring(source_js, starts, starts + lens - 1L))
  if (length(names_found) == 0L) return(character(0))
  leaked <- vapply(names_found, function(nm) {
    grepl(paste0(decl, "\\Q", nm, "\\E(?![\\w$])"), output, perl = TRUE)
  }, logical(1))
  sort(names_found[leaked])
}


#' Names that only the obfuscator writes
#'
#' A leaked name shaped like `_0x1a2b` or `a0_0x5f3a` was not written by a page
#' builder. It is the obfuscator's own top-level string-array machinery, which
#' means the page had been hardened before it reached here. Hardening a hardened
#' page refuses, correctly, but the refusal has to say what actually happened
#' or the operator goes looking for a wrapper that is already there.
#'
#' @param nms Character vector of leaked names.
#' @return TRUE when every name is obfuscator output.
#' @keywords internal
.minify_names_are_obfuscator_output <- function(nms) {
  length(nms) > 0L && all(grepl("^\\w*_0x[0-9a-fA-F]+$", nms, perl = TRUE))
}


#' The JavaScript a document actually runs, as one string
#'
#' The script blocks that are not data: everything except application/json and
#' text/plain, which is the same set step 6b hands to the obfuscator. Used on
#' both sides of the leak gate. On the source side it keeps a JSON island's
#' text (a verbatim comment saying "we let staff go") from being read as a
#' declaration; on the output side it keeps markup out of the search.
#'
#' @param html The document.
#' @return One string, empty when the document has no script.
#' @keywords internal
.minify_script_source <- function(html) {
  blocks <- .minify_extract_blocks(html, "script")
  js <- Filter(function(b) !b$type %in% c("application/json", "text/plain"),
               blocks)
  if (length(js) == 0L) return("")
  paste(vapply(js, function(b) b$content, character(1)), collapse = "\n")
}


#' Catch a page that is carried as an island but was never marked
#'
#' The gate below (`.minify_leaked_top_level_names`) protects the careful case:
#' someone marked the island, and the page inside it turns out not to be
#' wrapped. This protects the forgetful one, which is the likelier failure on
#' the next composed report and was how the VAS report shipped readable in the
#' first place. Without this, a composing step that omits
#' `data-embed="document"` produces a deliverable carrying whole pages with
#' their comments and function names intact, and nothing anywhere says so.
#'
#' Confirmed by building exactly that on 7 September 2026: a deliverable came
#' back PASS-with-one-unrelated-warning, zero islands hardened, and the embedded
#' page's `computeTheThing` and `SECRETDATA` sitting in the output.
#'
#' Three conditions together, so this cannot fire on ordinary data. The body has
#' to parse as a single JSON string, that string has to open as an HTML
#' document, and it has to contain a script. A manifest, a table island or a
#' user-state island fails the first test, because none of them is a bare
#' string.
#'
#' @param html The HTML string.
#' @param verbose Unused, kept for symmetry with its callers.
#' @return Character vector of offending island ids, empty when clean.
#' @keywords internal
.minify_unmarked_document_islands <- function(html, verbose = FALSE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return(character(0))
  blocks <- .minify_extract_blocks(html, "script")
  hits <- character(0)
  for (b in blocks) {
    if (!identical(b$type, "application/json")) next
    # Already marked, so step 2c handles it.
    if (grepl("data-embed\\s*=\\s*[\"\']document[\"\']", b$open_tag, perl = TRUE)) next
    # Already encoded by step 8c on an earlier pass: the body is base64 and
    # cannot be read as a document without the key.
    if (grepl("data-k\\s*=", b$open_tag, perl = TRUE)) next
    body <- trimws(b$content)
    if (!nzchar(body) || identical(body, "null")) next
    # Cheap reject before the parse. A document island's body is a JSON string,
    # so it starts with a quote; a manifest starts with { or [.
    if (substr(body, 1L, 1L) != '"') next
    inner <- tryCatch(jsonlite::fromJSON(body), error = function(e) NULL)
    if (is.null(inner) || !is.character(inner) || length(inner) != 1L) next
    if (!grepl("<!doctype", inner, ignore.case = TRUE) &&
        !grepl("<html", inner, fixed = TRUE)) next
    if (!grepl("<script", inner, fixed = TRUE)) next
    hits <- c(hits, .minify_block_id(b$open_tag))
  }
  hits
}


#' Harden every embedded document carried as a marked island
#'
#' Recurses into turas_minify() exactly as .minify_harden_srcdoc() does, then
#' runs the leak gate over the result. Must run before step 8c, so that a
#' caller who marks an island both ways encodes the hardened bytes rather than
#' the readable ones.
#'
#' @param html The HTML string.
#' @param opts Named list of options to pass down, as step 2b builds it.
#' @param verbose Print per-island progress.
#' @return List with html, count, obfuscated.
#' @keywords internal
.minify_harden_document_islands <- function(html, opts, verbose = FALSE) {
  blocks <- .minify_document_island_blocks(html)
  if (length(blocks) == 0L) {
    return(list(html = html, count = 0L, obfuscated = FALSE))
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    turas_refuse(
      code = "PKG_JSONLITE_MISSING",
      title = "jsonlite is needed to harden an embedded document island",
      problem = sprintf(
        "%d island(s) are marked data-embed=\"document\" but jsonlite is not installed.",
        length(blocks)),
      why_it_matters = paste(
        "The island bodies are JSON and cannot be read without it, so the pages",
        "they carry would ship readable inside a file that is otherwise hardened."),
      how_to_fix = c("install.packages('jsonlite')",
                     "Or clear the client deliverable checkbox to keep a development build."),
      module = "MINIFY"
    )
  }

  hardened <- 0L
  obfuscated <- FALSE
  contents <- vector("list", length(blocks))

  for (i in seq_along(blocks)) {
    block <- blocks[[i]]
    id <- .minify_block_id(block$open_tag)

    inner <- tryCatch(jsonlite::fromJSON(block$content), error = function(e) e)
    if (inherits(inner, "error") || !is.character(inner) || length(inner) != 1L) {
      .minify_refuse_island_doc(
        id, "its body is not a JSON string holding a document",
        c("The island must hold ONE JSON string, which is the whole page",
          "Check the builder that wrote it"))
    }
    # A fragment is not a document, and only a whole page is safe to hand to a
    # recursive pass. A doctype OR an <html> tag, not both: the html element's
    # start tag is optional in HTML and three of the nineteen VAS pages omit it,
    # opening `<!doctype html>` straight into `<meta charset>`. Testing for
    # `<html` alone, as step 2b does for the maxdiff simulator, refused those
    # three.
    if (!grepl("<!doctype", inner, ignore.case = TRUE) &&
        !grepl("<html", inner, fixed = TRUE)) {
      .minify_refuse_island_doc(
        id, "its payload is not a whole HTML document",
        c("data-embed=\"document\" says the island carries a page",
          "A page needs a doctype or an <html> tag; this has neither",
          "Remove the attribute if it carries something else"))
    }

    source_js <- .minify_script_source(inner)

    work <- tempfile(pattern = "turas_island_", fileext = ".html")
    out <- tempfile(pattern = "turas_island_min_", fileext = ".html")
    on.exit(unlink(c(work, out)), add = TRUE)
    writeLines(inner, work, useBytes = TRUE)

    res <- tryCatch(
      turas_minify(work, output_path = out,
                   strip_meta = opts$strip_meta, minify_js = opts$minify_js,
                   minify_css = opts$minify_css, minify_html = opts$minify_html,
                   obfuscate_js = opts$obfuscate_js, watermark = opts$watermark,
                   client_safe = opts$client_safe, deliverable = opts$deliverable,
                   verbose = FALSE),
      # The embedded document's own refusal already names its code, problem and
      # fix, so it passes through rather than being rewrapped into something
      # less specific. Same choice as step 2b.
      turas_refusal = function(e) stop(e),
      error = function(e) e
    )
    if (inherits(res, "error")) {
      .minify_refuse_island_doc(id, conditionMessage(res),
        c("Extract that island's payload and run turas_minify() on it by hand",
          "Or clear the client deliverable checkbox to keep a development build."))
    }
    # Same check as step 2b. PASS and PARTIAL both write the file; anything
    # else, or a missing file, must not fall through to readLines() and fail
    # with a message about a temp path nobody can act on.
    if (!res$status %in% c("PASS", "PARTIAL") || !file.exists(out)) {
      .minify_refuse_island_doc(
        id, sprintf("the embedded page came back %s with no file written", res$status),
        c("The messages above name the cause",
          "Or clear the client deliverable checkbox to keep a development build."))
    }
    # The page's own warnings, so a PARTIAL one level down does not vanish
    # into a PASS one level up. Step 2b does the same.
    if (length(res$warnings)) {
      for (w in res$warnings) {
        cat(sprintf("  [note] embedded page '%s': %s\n", id, w))
      }
    }

    done <- paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

    # The gate. Only meaningful once obfuscation actually ran, so a build with
    # the obfuscator switched off is not failed for a thing it never attempted.
    if (isTRUE(opts$obfuscate_js) && res$js_blocks_obfuscated > 0L) {
      leaked <- .minify_leaked_top_level_names(source_js,
                                               .minify_script_source(done))
      if (length(leaked) > 0L) {
        if (.minify_names_are_obfuscator_output(leaked)) {
          # Not a missing wrapper: the page was hardened before it got here.
          code <- "CALC_MINIFY_ISLAND_ALREADY_HARDENED"
          title <- "An embedded page had already been hardened"
          msg <- sprintf(
            "Island '%s' carries a page that was hardened before this run: its top-level names are obfuscator output (%s)",
            id, paste(utils::head(leaked, 3L), collapse = ", "))
          fix <- c(
            "Hardening cannot be applied twice. Compose the report from the _dev copy, then harden once, last",
            "See scripts/turas_harden_report.R and the composed-report notes in CLAUDE.md")
          why <- paste(
            "A second pass would obfuscate the obfuscator's own machinery, roughly",
            "doubling the page again, and the names it leaves behind are not the",
            "page builder's to fix.")
        } else {
          code <- "CALC_MINIFY_ISLAND_NAMES_LEAKED"
          title <- "An embedded page shipped its function names"
          msg <- sprintf(
            "Island '%s' still exposes %d top-level name(s) after hardening: %s",
            id, length(leaked),
            paste(utils::head(leaked, 8L), collapse = ", "))
          fix <- c(
            "The page's script is not wrapped, so the outermost scope is left alone",
            "Wrap the page's script body in (function(){\"use strict\"; ... })()",
            "The page builder does this, not the minifier: only it knows the page is self-contained")
          why <- paste(
            "The file would look hardened, because its comments are gone and",
            "its core is scrambled, while the embedded page still names every",
            "function it defines. That is the state this step exists to end.")
        }
        if (isTRUE(opts$deliverable)) {
          cat("\n+-- TURAS ERROR ----------------------------------------------+\n")
          cat("| Context:    Minify, embedded document island\n")
          cat("| Code:      ", code, "\n")
          cat("| Message:   ", msg, "\n")
          for (fx in fix) cat("| How to fix:", fx, "\n")
          cat("+-------------------------------------------------------------+\n\n")
          turas_refuse(
            code = code,
            title = title,
            problem = msg,
            why_it_matters = why,
            how_to_fix = fix,
            module = "MINIFY"
          )
        } else {
          warning(msg, call. = FALSE)
        }
      }
    }

    contents[[i]] <- .minify_island_doc_payload(done)
    hardened <- hardened + 1L
    obfuscated <- obfuscated || (res$js_blocks_obfuscated > 0L)
    if (verbose) {
      cat(sprintf("  Island document hardened: %s (%d/%d JS blocks obfuscated)\n",
                  id, res$js_blocks_obfuscated, res$js_blocks_processed))
    }
  }

  html <- .minify_replace_blocks(html, blocks, contents)
  list(html = html, count = hardened, obfuscated = obfuscated)
}


#' Serialise a document back into an island body
#'
#' The `</` to `<\/` escape is not decoration. Without it the first `</div>` in
#' the payload closes the surrounding script element and the rest of the page
#' becomes markup. JSON reads `\/` as `/`, so the browser's JSON.parse returns
#' the document unchanged. This mirrors island() in
#' build_vas_integrated_report.py, which applies the same escape on the way in.
#'
#' @keywords internal
.minify_island_doc_payload <- function(doc) {
  txt <- as.character(jsonlite::toJSON(doc, auto_unbox = TRUE))
  gsub("</", "<\\\\/", txt, fixed = TRUE)
}


#' The id attribute of a block, for error messages
#' @keywords internal
.minify_block_id <- function(open_tag) {
  m <- regexpr('id\\s*=\\s*["\']([^"\']*)["\']', open_tag, perl = TRUE)
  if (m < 0) return("(no id)")
  substr(open_tag, attr(m, "capture.start")[1],
         attr(m, "capture.start")[1] + attr(m, "capture.length")[1] - 1L)
}


#' Refuse on one island, with the console output Shiny needs
#' @keywords internal
.minify_refuse_island_doc <- function(id, problem, how_to_fix) {
  msg <- sprintf("Island '%s' could not be hardened: %s", id, problem)
  cat("\n+-- TURAS ERROR ----------------------------------------------+\n")
  cat("| Context:    Minify, embedded document island\n")
  cat("| Code:       CALC_MINIFY_ISLAND_DOC_FAILED\n")
  cat("| Message:   ", msg, "\n")
  for (fx in how_to_fix) cat("| How to fix:", fx, "\n")
  cat("+-------------------------------------------------------------+\n\n")
  turas_refuse(
    code = "CALC_MINIFY_ISLAND_DOC_FAILED",
    title = "An embedded document island could not be hardened",
    problem = msg,
    why_it_matters = paste(
      "The island carries a whole page. Left unprocessed it ships readable",
      "inside a file that is otherwise hardened, which is the thing this step",
      "exists to stop."),
    how_to_fix = how_to_fix,
    module = "MINIFY"
  )
}


# -- Block extraction ---------------------------------------------------------

#' Where every iframe srcdoc attribute value sits in an HTML string
#'
#' One definition, used by two callers that must agree: the block extractor,
#' which skips script tags inside these ranges because they are attribute text
#' rather than markup, and .minify_harden_srcdoc(), which hardens what is
#' inside them. If the two ever disagreed, a block would be both skipped and
#' left unprotected, which is the bug this whole step exists to close.
#'
#' The attribute's own quotes are safe to match on: the builder escapes every
#' inner quote to &quot; before embedding, so [^"]* reaches the real closing
#' quote.
#'
#' @param html Character. The whole document.
#' @return A data frame of start/end character positions covering the entire
#'   `srcdoc="..."` match, or NULL when the document has none.
#' @keywords internal
.minify_srcdoc_ranges <- function(html) {
  dm <- gregexpr('srcdoc="[^"]*"', html, perl = TRUE)[[1]]
  if (dm[1] == -1L) return(NULL)
  data.frame(
    start = as.integer(dm),
    end   = as.integer(dm) + attr(dm, "match.length") - 1L
  )
}


#' Blank the body of every JSON island, keeping every position
#'
#' A composed report carries whole pages inside JSON islands, and a page brings
#' its own `<style>` and `<script>` OPENING tags with it. Those are text, not
#' elements, but they look identical to the extractor. Their closing tags do
#' not: the composer escapes `</` to `<\/` so the island cannot end its own
#' script element early, which is exactly what makes the opening tags dangerous.
#' An opening tag with no matching close sends the lazy `[\s\S]*?` span scanning
#' to the end of the document and back.
#'
#' On the VAS integrated report, 12.5 MB with nineteen pages aboard, that costs
#' PCRE its match limit: the `<style>` search warned "match limit exceeded" and
#' returned 2 of the blocks instead of scanning cleanly. It was correct by luck
#' of ordering, because both real style elements sit ahead of the islands. Put a
#' style element AFTER them and a page's opening tag inside an island would pair
#' with it, and the CSS pass would rewrite a span straddling island boundaries.
#'
#' So the island bodies are blanked before matching. Spaces, one for one, so
#' every position in the blanked copy is the same position in the original and
#' the caller can still extract real content from the original. Found and fixed
#' 6 September 2026, while hardening the first composed report.
#'
#' @param html The HTML string.
#' @return The same string with JSON island bodies replaced by spaces.
#' @keywords internal
.minify_mask_island_bodies <- function(html) {
  # Bounded on both sides: `[^>]*` cannot run past the end of a tag, and the
  # close is a fixed string searched forward from the open. Neither can
  # backtrack, whatever the island holds.
  om <- gregexpr('<script[^>]*type\\s*=\\s*["\']application/json["\'][^>]*>',
                 html, perl = TRUE, ignore.case = TRUE)[[1]]
  if (om[1] == -1L) return(html)
  starts <- as.integer(om)
  lens <- attr(om, "match.length")
  n <- nchar(html)

  for (i in seq_along(starts)) {
    body_start <- starts[i] + lens[i]
    if (body_start > n) next
    rel <- regexpr("</script>", substr(html, body_start, n), fixed = TRUE)
    if (rel < 0) next
    body_end <- body_start + rel - 2L
    if (body_end < body_start) next
    substr(html, body_start, body_end) <-
      strrep(" ", body_end - body_start + 1L)
  }
  html
}


#' Extract Tagged Blocks from HTML
#'
#' Extracts content and positions of <style> or <script> blocks. For script
#' blocks, also captures the type attribute to allow skipping non-JS blocks.
#'
#' @param html Character, full HTML string.
#' @param tag Character, either "style" or "script".
#' @return List of lists, each with: content, start, end, type (for script),
#'   full_match (the complete tag including opening/closing tags).
#' @keywords internal
# SIZE-EXCEPTION: Block extraction requires inline filtering of style blocks
# inside script blocks, type attribute parsing, and position tracking. Splitting
# would fragment a coherent extraction pipeline that shares regex match state.
.minify_extract_blocks <- function(html, tag) {
  # Match only standalone HTML tags, not substrings (e.g., <styleSheet> in
  # Excel export XML). The tag must be followed by > or whitespace, not a letter.
  # Case-sensitive — Turas generates lowercase HTML tags; uppercase <Style> in
  # JS string literals (Excel export) must not match.
  pattern <- paste0("(<", tag, "(?=[\\s>])[^>]*>)([\\s\\S]*?)(</", tag, ">)")

  # Match against a copy whose JSON island bodies are blanked, so a page
  # carried inside an island cannot contribute a stray opening tag. Blanking
  # preserves length, so every position below indexes the ORIGINAL html and
  # real content is still extracted from it. See .minify_mask_island_bodies().
  search_html <- .minify_mask_island_bodies(html)
  matches <- gregexpr(pattern, search_html, perl = TRUE)[[1]]
  if (matches[1] == -1L) return(list())

  # When extracting <style> blocks, filter out any that fall inside a <script>
  # block. JS string literals can contain "<style>...</style>" (e.g., the
  # dashboard styles wrapper function).
  # Script tags that live inside an iframe's srcdoc attribute are not script
  # elements: they are escaped text in an attribute value, and their bodies are
  # not valid JavaScript. The maxdiff report embeds its whole simulator that way
  # (modules/maxdiff/lib/html_report/03_page_builder.R), so eight blocks of it
  # were being handed to terser, failing, and warning on every build. The
  # attribute's own quotes are safe to match on: the builder escapes every inner
  # quote to &quot; before embedding, so [^"]* reaches the real closing quote.
  # Both of these read search_html, not html, for the same reason the main match
  # does: a page carried inside an island brings its own srcdoc attributes and
  # script tags, and neither is an element of THIS document. The script span
  # below is the same lazy pattern that hit PCRE's match limit on the composed
  # VAS report, so it needs the masked copy as much as the main match does.
  srcdoc_ranges <- if (tag == "script") .minify_srcdoc_ranges(search_html) else NULL

  script_ranges <- NULL
  if (tag == "style") {
    sp <- paste0("(<script(?=[\\s>])[^>]*>)([\\s\\S]*?)(</script>)")
    sm <- gregexpr(sp, search_html, perl = TRUE)[[1]]
    if (sm[1] != -1L) {
      script_ranges <- data.frame(
        start = as.integer(sm),
        end   = as.integer(sm) + attr(sm, "match.length") - 1L
      )
    }
  }

  match_lengths <- attr(matches, "match.length")
  blocks <- vector("list", length(matches))

  for (i in seq_along(matches)) {
    start_pos <- matches[i]
    end_pos <- start_pos + match_lengths[i] - 1L

    # Skip script tags that fall inside a srcdoc attribute value
    if (!is.null(srcdoc_ranges)) {
      inside_srcdoc <- any(
        start_pos >= srcdoc_ranges$start & start_pos <= srcdoc_ranges$end
      )
      if (inside_srcdoc) next
    }

    # Skip style blocks that fall inside a script block
    if (!is.null(script_ranges)) {
      inside_script <- any(
        start_pos >= script_ranges$start & start_pos <= script_ranges$end
      )
      if (inside_script) next
    }

    full_match <- substr(html, start_pos, end_pos)

    # Extract opening tag to get type attribute
    open_tag_match <- regexpr(sprintf("<%s[^>]*>", tag), full_match,
                              perl = TRUE, ignore.case = TRUE)
    open_tag <- regmatches(full_match, open_tag_match)

    block_type <- ""
    if (tag == "script") {
      type_match <- regexpr('type\\s*=\\s*["\']([^"\']*)["\']', open_tag,
                            perl = TRUE, ignore.case = TRUE)
      if (type_match > 0) {
        # Extract captured group
        cap_start <- attr(type_match, "capture.start")[1]
        cap_length <- attr(type_match, "capture.length")[1]
        block_type <- substr(open_tag, cap_start, cap_start + cap_length - 1L)
      }
    }

    # Extract inner content (between opening and closing tags)
    open_tag_len <- attr(open_tag_match, "match.length")
    close_tag_len <- nchar(sprintf("</%s>", tag))
    inner_start <- open_tag_len + 1L
    inner_end <- nchar(full_match) - close_tag_len
    content <- if (inner_start <= inner_end) {
      substr(full_match, inner_start, inner_end)
    } else {
      ""
    }

    blocks[[i]] <- list(
      content    = content,
      start      = start_pos,
      end        = end_pos,
      type       = block_type,
      tag_name   = tag,
      open_tag   = open_tag,
      full_match = full_match
    )
  }

  # Remove NULL entries from skipped blocks
  Filter(Negate(is.null), blocks)
}


# -- Meta tag stripping -------------------------------------------------------

#' Strip Turas Meta Tags
#'
#' Removes all <meta> tags where the name attribute starts with "turas-".
#' Preserves charset, viewport, and all other meta tags.
#'
#' @param html Character, full HTML string.
#' @return Named list with html (modified string) and count (tags removed).
#' @keywords internal
.minify_strip_meta_tags <- function(html) {
  pattern <- '<meta\\s+name\\s*=\\s*"turas-[^"]*"\\s+content\\s*=\\s*"[^"]*"\\s*/?>'
  count <- length(gregexpr(pattern, html, perl = TRUE, ignore.case = TRUE)[[1]])
  if (count == 1L && gregexpr(pattern, html, perl = TRUE, ignore.case = TRUE)[[1]][1] == -1L) {
    count <- 0L
  }
  html <- gsub(pattern, "", html, perl = TRUE, ignore.case = TRUE)
  # Also handle reversed attribute order (content before name)
  pattern_rev <- '<meta\\s+content\\s*=\\s*"[^"]*"\\s+name\\s*=\\s*"turas-[^"]*"\\s*/?>'
  count_rev <- length(gregexpr(pattern_rev, html, perl = TRUE, ignore.case = TRUE)[[1]])
  if (count_rev == 1L && gregexpr(pattern_rev, html, perl = TRUE, ignore.case = TRUE)[[1]][1] == -1L) {
    count_rev <- 0L
  }
  html <- gsub(pattern_rev, "", html, perl = TRUE, ignore.case = TRUE)

  list(html = html, count = count + count_rev)
}


# -- Comment removal ----------------------------------------------------------

#' Remove HTML Comments
#'
#' Removes <!-- ... --> comments from HTML. Protects JSON script blocks and
#' conditional comments (<!--[if ...]) from removal.
#'
#' @param html Character, full HTML string.
#' @return Named list with html (modified string) and count (comments removed).
#' @keywords internal
.minify_remove_html_comments <- function(html) {
  # Protect JSON and text/plain script blocks with placeholders
  json_blocks <- .minify_extract_blocks(html, "script")
  protected_blocks <- list()
  placeholder_idx <- 0L

  for (block in json_blocks) {
    if (block$type %in% c("application/json", "text/plain")) {
      placeholder_idx <- placeholder_idx + 1L
      placeholder <- sprintf("__TURAS_PROTECTED_BLOCK_%d__", placeholder_idx)
      protected_blocks[[placeholder]] <- block$full_match
      html <- sub(block$full_match, placeholder, html, fixed = TRUE)
    }
  }

  # Count and remove non-conditional HTML comments
  # Conditional comments start with <!--[if
  comment_pattern <- "<!--(?!\\[if\\s)[\\s\\S]*?-->"
  matches <- gregexpr(comment_pattern, html, perl = TRUE)[[1]]
  count <- if (matches[1] == -1L) 0L else length(matches)
  html <- gsub(comment_pattern, "", html, perl = TRUE)

  # Restore protected blocks
  for (placeholder in names(protected_blocks)) {
    html <- sub(placeholder, protected_blocks[[placeholder]], html, fixed = TRUE)
  }

  list(html = html, count = count)
}


# -- CSS minification ---------------------------------------------------------

#' Minify a Single CSS Block via clean-css
#'
#' Writes CSS to a temp file, runs clean-css, reads back the result.
#' Falls back to original content on failure.
#'
#' @param css_content Character, CSS content to minify.
#' @param cleancss_path Character, path to cleancss binary.
#' @return Named list with content (minified or original) and success (logical).
#' @keywords internal
.minify_css_block <- function(css_content, cleancss_path) {
  if (!nzchar(css_content) || !nzchar(cleancss_path)) {
    return(list(content = css_content, success = FALSE))
  }

  tmp_in <- tempfile(fileext = ".css")
  tmp_out <- tempfile(fileext = ".css")
  on.exit(unlink(c(tmp_in, tmp_out), force = TRUE), add = TRUE)

  writeLines(css_content, tmp_in, useBytes = TRUE)

  args <- c(.MINIFY_CLEANCSS_ARGS, "-o", tmp_out, tmp_in)
  result <- tryCatch(
    system2(cleancss_path, args = args,
            stdout = TRUE, stderr = TRUE,
            timeout = .MINIFY_TOOL_TIMEOUT_SECS),
    error = function(e) e
  )

  exit_status <- attr(result, "status")
  if (inherits(result, "error") ||
      (!is.null(exit_status) && exit_status != 0L) ||
      !file.exists(tmp_out)) {
    return(list(content = css_content, success = FALSE))
  }

  minified <- paste(readLines(tmp_out, warn = FALSE), collapse = "\n")
  if (!nzchar(minified)) {
    return(list(content = css_content, success = FALSE))
  }

  list(content = minified, success = TRUE)
}


# -- JS minification ----------------------------------------------------------

#' Minify a Single JS Block via terser
#'
#' Writes JS to a temp file, runs terser, reads back the result.
#' Injects a copyright comment at the top. Falls back to original on failure.
#'
#' @param js_content Character, JavaScript content to minify.
#' @param terser_path Character, path to terser binary.
#' @return Named list with content (minified or original) and success (logical).
#' @keywords internal
.minify_js_block <- function(js_content, terser_path) {
  if (!nzchar(js_content) || !nzchar(terser_path)) {
    return(list(content = js_content, success = FALSE))
  }

  # Extract vendor sections (already minified — skip them to avoid slow
  # re-parsing of 200KB+ compressed libraries like html2canvas, PptxGenJS).
  # Vendor sections are marked with /* TURAS_VENDOR_START */ ... /* TURAS_VENDOR_END */
  # Uses fixed string search (not regex) to avoid backtracking on large blocks.
  vendor_chunks <- list()
  js_to_minify <- js_content
  vendor_start_marker <- "/* TURAS_VENDOR_START */"
  vendor_end_marker <- "/* TURAS_VENDOR_END */"
  vendor_idx <- 0L

  repeat {
    v_start <- regexpr(vendor_start_marker, js_to_minify, fixed = TRUE)
    if (v_start == -1L) break

    v_end_pos <- regexpr(vendor_end_marker, js_to_minify, fixed = TRUE)
    if (v_end_pos == -1L) break

    v_end <- v_end_pos + nchar(vendor_end_marker) - 1L
    vendor_idx <- vendor_idx + 1L
    v_text <- substr(js_to_minify, v_start, v_end)
    placeholder <- sprintf("function __TURAS_VENDOR_%d__(){}", vendor_idx)
    vendor_chunks[[placeholder]] <- v_text
    js_to_minify <- paste0(
      substr(js_to_minify, 1L, v_start - 1L),
      placeholder,
      substr(js_to_minify, v_end + 1L, nchar(js_to_minify))
    )
  }

  # Prepend copyright notice so terser preserves it via --comments some
  copyright <- sprintf(.MINIFY_COPYRIGHT_TEMPLATE, format(Sys.Date(), "%Y"))
  js_with_copyright <- paste0(copyright, "\n", js_to_minify)

  tmp_in <- tempfile(fileext = ".js")
  tmp_out <- tempfile(fileext = ".js")
  on.exit(unlink(c(tmp_in, tmp_out), force = TRUE), add = TRUE)

  writeLines(js_with_copyright, tmp_in, useBytes = TRUE)

  args <- c(.MINIFY_TERSER_ARGS, tmp_in, "-o", tmp_out)
  result <- tryCatch(
    system2(terser_path, args = args,
            stdout = TRUE, stderr = TRUE,
            timeout = .MINIFY_TOOL_TIMEOUT_SECS),
    error = function(e) e
  )

  exit_status <- attr(result, "status")
  if (inherits(result, "error") || (!is.null(exit_status) && exit_status != 0L)) {
    return(list(content = js_content, success = FALSE))
  }

  if (!file.exists(tmp_out)) {
    return(list(content = js_content, success = FALSE))
  }

  minified <- paste(readLines(tmp_out, warn = FALSE), collapse = "\n")
  if (!nzchar(minified)) {
    return(list(content = js_content, success = FALSE))
  }

  # Re-insert vendor chunks
  for (placeholder in names(vendor_chunks)) {
    minified <- sub(placeholder, vendor_chunks[[placeholder]], minified, fixed = TRUE)
  }

  list(content = minified, success = TRUE)
}


# -- Data island encoding -----------------------------------------------------

#' Keystream for the island encoder
#'
#' A linear congruential generator, seeded per build. Every step is a multiply,
#' an add and a modulo, and 1664525 * (2^32 - 1) + 1013904223 is about 7.1e15,
#' comfortably under 2^53. That is the whole reason for this generator: R and
#' JavaScript agree on the bytes without either side needing bit operations on
#' values a double cannot hold.
#'
#' One stream is generated per build and sliced per island, because every island
#' restarts from the same seed. The JavaScript half is decodeIsland() in
#' modules/tabs/lib/html_report_v2/assets/js/24_shell.js.
#'
#' @param seed Integer seed, 1 to 2^31 - 1.
#' @param n Length in bytes.
#' @return Integer vector of n bytes, each 0 to 255.
#' @keywords internal
.minify_keystream <- function(seed, n) {
  if (n <= 0L) return(integer(0))
  out <- integer(n)
  x <- as.numeric(seed)
  for (i in seq_len(n)) {
    x <- (1664525 * x + 1013904223) %% 4294967296
    out[i] <- x %/% 16777216
  }
  out
}

#' Encode one island body
#'
#' UTF-8 bytes, XORed against the keystream, base64. Not encryption: the key is
#' in the file. It stops the report being read, grepped, or pasted into a tool
#' that expects JSON. It does not stop a developer.
#'
#' @param text The island body, exactly as it sits in the HTML.
#' @param keystream Integer vector from .minify_keystream(), at least nchar long.
#' @return Base64 character string.
#' @keywords internal
.minify_encode_island <- function(text, keystream) {
  bytes <- as.integer(charToRaw(enc2utf8(text)))
  n <- length(bytes)
  if (n == 0L) return("")
  if (length(keystream) < n) {
    stop("[CALC_MINIFY_KEYSTREAM_SHORT] keystream shorter than the island")
  }
  jsonlite::base64_enc(as.raw(bitwXor(bytes, keystream[seq_len(n)])))
}

#' Decode one island body, for the round-trip test
#'
#' @param b64 Base64 string from .minify_encode_island().
#' @param keystream The same keystream.
#' @return The original text.
#' @keywords internal
.minify_decode_island <- function(b64, keystream) {
  if (!nzchar(b64)) return("")
  bytes <- as.integer(jsonlite::base64_dec(b64))
  rawToChar(as.raw(bitwXor(bytes, keystream[seq_along(bytes)])))
}

#' Encode every marked island in a finished HTML string
#'
#' Marked means the open tag carries data-island="v2". user-state is not marked:
#' saveCopy() writes it in the browser, from JavaScript that has no encoder.
#' Islands whose body is "null" are left alone, and so is any island that
#' already carries a data-k, so that re-minifying a file, or minifying a hub
#' built from finished reports, cannot encode the same bytes twice.
#'
#' @param html The finished HTML.
#' @param seed Integer seed for this build.
#' @return List with html, count, and seed.
#' @keywords internal
.minify_encode_islands <- function(html, seed) {
  blocks <- .minify_extract_blocks(html, "script")
  targets <- Filter(function(b) {
    identical(b$type, "application/json") &&
      grepl("data-island\\s*=\\s*[\"\']v2[\"\']", b$open_tag, perl = TRUE) &&
      !grepl("data-k\\s*=", b$open_tag, perl = TRUE) &&
      nzchar(trimws(b$content)) &&
      !identical(trimws(b$content), "null")
  }, blocks)
  if (length(targets) == 0L) return(list(html = html, count = 0L, seed = seed))

  longest <- max(vapply(targets, function(b) nchar(b$content, type = "bytes"),
                        integer(1)))
  keystream <- .minify_keystream(seed, longest)

  # Back to front, so an earlier block's positions stay valid.
  ord <- order(vapply(targets, function(b) b$start, numeric(1)), decreasing = TRUE)
  for (b in targets[ord]) {
    encoded <- .minify_encode_island(b$content, keystream)
    open_tag <- sub(">$", sprintf(" data-k=\"%d\">", seed), b$open_tag)
    replacement <- paste0(open_tag, encoded, "</script>")
    html <- paste0(substr(html, 1L, b$start - 1L), replacement,
                   substr(html, b$end + 1L, nchar(html)))
  }
  list(html = html, count = length(targets), seed = seed)
}


# -- JS obfuscation ----------------------------------------------------------

#' Obfuscate a Single JS Block via javascript-obfuscator
#'
#' Writes JS to a temp file, runs javascript-obfuscator with a static config
#' file, reads back the result. Vendor blocks (TURAS_VENDOR_START/END) are
#' extracted and skipped, same as in minification.
#'
#' @param js_content Character, JavaScript content to obfuscate.
#' @param obfuscator_path Character, path to javascript-obfuscator binary.
#' @return Named list with content (obfuscated or original) and success (logical).
#' @keywords internal
.minify_obfuscate_js_block <- function(js_content, obfuscator_path) {
  if (!nzchar(js_content) || !nzchar(obfuscator_path)) {
    return(list(content = js_content, success = FALSE))
  }

  # Extract vendor sections — same pattern as .minify_js_block()
  vendor_chunks <- list()
  js_to_obfuscate <- js_content
  vendor_start_marker <- "/* TURAS_VENDOR_START */"
  vendor_end_marker <- "/* TURAS_VENDOR_END */"
  vendor_idx <- 0L

  repeat {
    v_start <- regexpr(vendor_start_marker, js_to_obfuscate, fixed = TRUE)
    if (v_start == -1L) break

    v_end_pos <- regexpr(vendor_end_marker, js_to_obfuscate, fixed = TRUE)
    if (v_end_pos == -1L) break

    v_end <- v_end_pos + nchar(vendor_end_marker) - 1L
    vendor_idx <- vendor_idx + 1L
    v_text <- substr(js_to_obfuscate, v_start, v_end)
    placeholder <- sprintf("function __TURAS_VENDOR_%d__(){}", vendor_idx)
    vendor_chunks[[placeholder]] <- v_text
    js_to_obfuscate <- paste0(
      substr(js_to_obfuscate, 1L, v_start - 1L),
      placeholder,
      substr(js_to_obfuscate, v_end + 1L, nchar(js_to_obfuscate))
    )
  }

  tmp_in <- tempfile(fileext = ".js")
  tmp_out <- tempfile(fileext = ".js")
  tmp_config <- tempfile(fileext = ".json")
  on.exit(unlink(c(tmp_in, tmp_out, tmp_config), force = TRUE), add = TRUE)

  writeLines(js_to_obfuscate, tmp_in, useBytes = TRUE)
  writeLines(.MINIFY_OBFUSCATOR_CONFIG_JSON, tmp_config)

  args <- c(tmp_in, "--output", tmp_out, "--config", tmp_config)
  result <- tryCatch(
    system2(obfuscator_path, args = args,
            stdout = TRUE, stderr = TRUE,
            timeout = .MINIFY_TOOL_TIMEOUT_SECS),
    error = function(e) e
  )

  exit_status <- attr(result, "status")
  if (inherits(result, "error") || (!is.null(exit_status) && exit_status != 0L)) {
    return(list(content = js_content, success = FALSE))
  }

  if (!file.exists(tmp_out)) {
    return(list(content = js_content, success = FALSE))
  }

  obfuscated <- paste(readLines(tmp_out, warn = FALSE), collapse = "\n")
  if (!nzchar(obfuscated)) {
    return(list(content = js_content, success = FALSE))
  }

  # Re-insert vendor chunks
  for (placeholder in names(vendor_chunks)) {
    obfuscated <- sub(placeholder, vendor_chunks[[placeholder]], obfuscated,
                      fixed = TRUE)
  }

  # Escape </script> inside the JS so the HTML parser doesn't prematurely end
  # the <script> block. The obfuscator adds '<script>document.F=Object</script>'
  # as a plaintext string in its anti-debugging code — a literal </script> inside
  # a <script> block causes the browser HTML parser to close the block early,
  # leaving switchReportTab and all subsequent code outside the script block.
  # <\/script> is valid JavaScript (backslash before / is a no-op escape) and
  # is invisible to the HTML parser.
  obfuscated <- gsub("</script>", "<\\/script>", obfuscated, fixed = TRUE)

  list(content = obfuscated, success = TRUE)
}


# -- Block replacement --------------------------------------------------------

#' Replace Extracted Blocks with Minified Content
#'
#' Replaces block content in the HTML string. Works backwards through the list
#' to preserve character positions of earlier blocks.
#'
#' @param html Character, full HTML string.
#' @param blocks List of block descriptors (from .minify_extract_blocks).
#' @param minified_contents Character vector of minified content, same length
#'   as blocks. NULL entries mean "keep original".
#' @return Character, modified HTML string.
#' @keywords internal
.minify_replace_blocks <- function(html, blocks, minified_contents) {
  # Work backwards to preserve positions
  indices <- rev(seq_along(blocks))

  for (i in indices) {
    block <- blocks[[i]]
    new_content <- minified_contents[[i]]
    if (is.null(new_content)) next

    # Reconstruct the full block with new content
    close_tag <- paste0("</", block$tag_name, ">")
    new_full <- paste0(block$open_tag, new_content, close_tag)

    html <- paste0(
      substr(html, 1L, block$start - 1L),
      new_full,
      substr(html, block$end + 1L, nchar(html))
    )
  }

  html
}


# -- HTML whitespace reduction ------------------------------------------------

#' Reduce HTML Whitespace via html-minifier-terser
#'
#' Applies conservative whitespace collapse to the full HTML string.
#' Falls back to original if the tool fails or result is larger.
#'
#' @param html Character, full HTML string.
#' @param html_minifier_path Character, path to html-minifier-terser binary.
#' @return Named list with html (processed or original) and success (logical).
#' @keywords internal
.minify_html_whitespace <- function(html, html_minifier_path) {
  if (!nzchar(html_minifier_path)) {
    return(list(html = html, success = FALSE))
  }

  tmp_in <- tempfile(fileext = ".html")
  tmp_out <- tempfile(fileext = ".html")
  on.exit(unlink(c(tmp_in, tmp_out), force = TRUE), add = TRUE)

  writeLines(html, tmp_in, useBytes = TRUE)

  args <- c(.MINIFY_HTML_ARGS, "-o", tmp_out, tmp_in)
  result <- tryCatch(
    system2(html_minifier_path, args = args,
            stdout = TRUE, stderr = TRUE,
            timeout = .MINIFY_TOOL_TIMEOUT_SECS),
    error = function(e) e
  )

  if (inherits(result, "error") || !file.exists(tmp_out)) {
    return(list(html = html, success = FALSE))
  }

  minified <- paste(readLines(tmp_out, warn = FALSE), collapse = "\n")
  if (!nzchar(minified)) {
    return(list(html = html, success = FALSE))
  }

  # Safety check: result should be smaller
  if (nchar(minified) >= nchar(html)) {
    return(list(html = html, success = FALSE))
  }

  list(html = minified, success = TRUE)
}


# -- Build tag ----------------------------------------------------------------

#' Inject Build Version Tag
#'
#' Adds a build version comment after the opening <html> tag for future
#' pipeline versioning and debugging.
#'
#' @param html Character, full HTML string.
#' @return Character, modified HTML string.
#' @keywords internal
.minify_inject_build_tag <- function(html) {
  tag <- sprintf("<!-- Turas Build v%s -->", .MINIFY_VERSION)
  sub("(<html[^>]*>)", paste0("\\1", tag), html, perl = TRUE, ignore.case = TRUE)
}


# -- Summary printer ----------------------------------------------------------

#' Print Minification Summary
#'
#' Formats and prints the minification result summary to the console.
#'
#' @param result Named list from turas_minify().
#' @keywords internal
.minify_print_summary <- function(result) {
  input_kb <- format(round(result$input_size_kb), big.mark = ",")
  output_kb <- format(round(result$output_size_kb), big.mark = ",")

  cat("\n")
  cat("Turas Minification Summary\n")
  cat(strrep("\u2500", 50), "\n")
  cat(sprintf("Input:     %s KB  (%s)\n", input_kb, basename(result$input_path)))
  cat(sprintf("Output:    %s KB  (%s)\n", output_kb, basename(result$output_path)))
  cat(sprintf("Size:      %s\n", .minify_size_phrase(result$reduction_pct)))
  cat(strrep("\u2500", 50), "\n")
  cat(sprintf("JS blocks:     %d minified\n", result$js_blocks_processed))
  cat(sprintf("JS blocks:     %d obfuscated\n", result$js_blocks_obfuscated))
  cat(sprintf("CSS blocks:    %d processed\n", result$css_blocks_processed))
  cat(sprintf("Meta tags:     %d stripped\n", result$meta_tags_stripped))
  cat(sprintf("HTML comments: %d removed\n", result$html_comments_removed))
  # Only when there were any. A crosstab report carries none of these and the
  # line would be noise on every build that is not a composed report.
  if (isTRUE(result$island_documents_hardened > 0L)) {
    cat(sprintf("Embedded pages:%d hardened\n", result$island_documents_hardened))
  }
  if (nzchar(result$watermark_client %||% "")) {
    cat(sprintf("Watermark:     %s\n", result$watermark_client))
  }
  cat(sprintf("Warnings:      %d\n", length(result$warnings)))
  cat(strrep("\u2500", 50), "\n")

  if (!is.null(result$release_audit)) {
    cat(paste0(result$release_audit$lines, collapse = "\n"), "\n")
    cat(strrep("\u2500", 50), "\n")
  }

  if (result$verification_passed) {
    cat("Verification:  ALL CHECKS PASSED\n")
  } else {
    cat("Verification:  SOME CHECKS FAILED\n")
    for (msg in result$verification_summary) {
      if (grepl("^\\[FAIL\\]", msg)) cat("  ", msg, "\n")
    }
  }
  cat("\n")
}


# -- Main function ------------------------------------------------------------
# SIZE-EXCEPTION: Orchestrator coordinates 10 pipeline steps with error
# accumulation. Decomposition would fragment the sequential flow and require
# passing a large mutable state object between functions.

#' Minify a Turas HTML Report
#'
#' Post-processes a finished Turas HTML report to produce a minified and
#' optionally obfuscated deliverable. Reduces file size via CSS/JS minification
#' and HTML whitespace collapse, obfuscates JS via string array encoding, and
#' strips internal metadata for IP protection. Optionally embeds invisible
#' client watermarks for delivery traceability.
#'
#' The pipeline is resilient: failure of any individual step produces a warning
#' and falls back to the original content. A minification failure never
#' prevents report delivery.
#'
#' @param input_path Character. Path to the finished Turas HTML report.
#' @param output_path Character or NULL. Path for the minified output. If NULL,
#'   derives from input_path: removes _dev suffix or appends _min.
#' @param keep_dev_copy Logical. If TRUE (default), the original file is
#'   preserved. If FALSE, the original is overwritten.
#' @param strip_meta Logical. Whether to remove turas-* meta tags.
#' @param minify_js Logical. Whether to minify JavaScript blocks.
#' @param minify_css Logical. Whether to minify CSS blocks.
#' @param minify_html Logical. Whether to reduce HTML whitespace.
#' @param obfuscate_js Logical. Whether to obfuscate JS with string array
#'   encoding after minification. Requires javascript-obfuscator.
#' @param watermark Character or NULL. Client name to embed as an invisible
#'   watermark. NULL or empty string skips watermarking.
#' @param client_safe Logical. TRUE when the operator has declared that this
#'   build carries no respondent-level data. The release audit then REFUSES if
#'   the microdata island is still present, because a declaration that cannot
#'   fail protects nobody. Default FALSE, which audits and reports only.
#' @param deliverable Logical. TRUE when this build is a client deliverable
#'   rather than a working copy. It turns the pipeline's silent fallbacks into
#'   refusals: obfuscation that did not happen refuses instead of writing a
#'   readable file under the deliverable name. Passed explicitly rather than
#'   read from TURAS_PREPARE_DELIVERABLE, because tests and report_hub call
#'   this function directly.
#' @param verbose Logical. If TRUE, print progress and size comparison.
#'
#' @return A named list with:
#'   \item{status}{"PASS", "PARTIAL", or "REFUSED"}
#'   \item{input_path}{Path to the original file.}
#'   \item{output_path}{Path to the minified output.}
#'   \item{input_size_kb}{Original file size in KB.}
#'   \item{output_size_kb}{Minified file size in KB.}
#'   \item{reduction_pct}{Percentage size reduction (negative = size increase).}
#'   \item{js_blocks_processed}{Number of JS blocks minified.}
#'   \item{js_blocks_obfuscated}{Number of JS blocks obfuscated.}
#'   \item{css_blocks_processed}{Number of CSS blocks minified.}
#'   \item{meta_tags_stripped}{Number of meta tags removed.}
#'   \item{html_comments_removed}{Number of HTML comments removed.}
#'   \item{watermark_client}{Client name embedded, or empty string.}
#'   \item{verification_passed}{Logical, TRUE if all checks passed.}
#'   \item{verification_summary}{Character vector of check results.}
#'   \item{warnings}{Character vector of warning messages.}
#'
#' @examples
#' \dontrun{
#'   # Basic usage — derives output path from input
#'   result <- turas_minify("reports/Project_dev.html")
#'
#'   # With client watermark
#'   result <- turas_minify("reports/Project_dev.html",
#'                          watermark = "Acme Corp", verbose = TRUE)
#'
#'   # Skip obfuscation (minify only)
#'   result <- turas_minify("reports/Project_dev.html", obfuscate_js = FALSE)
#' }
#'
#' @export
turas_minify <- function(input_path,
                         output_path = NULL,
                         keep_dev_copy = TRUE,
                         strip_meta = TRUE,
                         minify_js = TRUE,
                         minify_css = TRUE,
                         minify_html = TRUE,
                         obfuscate_js = TRUE,
                         watermark = NULL,
                         client_safe = FALSE,
                         deliverable = FALSE,
                         verbose = FALSE) {

  warnings_acc <- character(0)
  add_warning <- function(msg) {
    warnings_acc <<- c(warnings_acc, msg)
    warning(msg, call. = FALSE)
  }

  # In a deliverable build, obfuscation that did not happen is not a warning.
  # The old behaviour kept the plain minified JS, returned PARTIAL and wrote the
  # file anyway, so an obfuscator that was missing or timed out shipped readable
  # source under the clean client deliverable name. Turas runs in Shiny, so the
  # reason has to reach the console or it reaches nobody.
  refuse_obfuscation <- function(problem, how_to_fix) {
    cat("\n+-- TURAS ERROR ----------------------------------------------+\n")
    cat("| Context:    Minify, client deliverable build\n")
    cat("| Code:       CALC_MINIFY_OBFUSCATE_FAILED\n")
    cat("| Message:   ", problem, "\n")
    for (fx in how_to_fix) cat("| How to fix:", fx, "\n")
    cat("+-------------------------------------------------------------+\n\n")
    turas_refuse(
      code = "CALC_MINIFY_OBFUSCATE_FAILED",
      title = "JavaScript obfuscation failed on a client deliverable",
      problem = problem,
      why_it_matters = paste(
        "A deliverable that is not obfuscated ships the readable Turas renderer.",
        "That is the whole reason the deliverable path exists, so it refuses",
        "rather than writing a file someone will send to a client."),
      how_to_fix = how_to_fix,
      module = "MINIFY"
    )
  }

  # -- Step 0: Validate input -------------------------------------------------
  if (!is.character(input_path) || length(input_path) != 1L || !nzchar(input_path)) {
    turas_refuse(
      code = "IO_INVALID_PATH",
      title = "Invalid Input Path",
      problem = "input_path must be a single non-empty character string",
      why_it_matters = "Cannot locate the HTML report to minify",
      how_to_fix = c("Provide a valid file path as a character string",
                     "Example: turas_minify('reports/Project_dev.html')"),
      module = "MINIFY"
    )
  }

  if (!file.exists(input_path)) {
    turas_refuse(
      code = "IO_FILE_NOT_FOUND",
      title = "Input File Not Found",
      problem = sprintf("File does not exist: %s", input_path),
      why_it_matters = "Cannot minify a file that does not exist",
      how_to_fix = c("Check the file path is correct",
                     "Ensure the report has been generated before minifying",
                     sprintf("Looked for: %s", input_path)),
      module = "MINIFY"
    )
  }

  if (is.null(output_path)) {
    output_path <- .minify_derive_output_path(input_path)
  }

  input_size <- file.info(input_path)$size
  if (verbose) cat(sprintf("Minifying: %s (%.0f KB)\n", basename(input_path),
                           input_size / 1024))

  # -- Step 1: Check tools ----------------------------------------------------
  tools <- .minify_check_tools()

  if (!nzchar(tools$node)) {
    add_warning("Node.js not found. Copying file without minification.")
    file.copy(input_path, output_path, overwrite = TRUE)
    output_size <- file.info(output_path)$size
    return(list(
      status = "PARTIAL",
      input_path = input_path, output_path = output_path,
      input_size_kb = input_size / 1024, output_size_kb = output_size / 1024,
      reduction_pct = 0, js_blocks_processed = 0L, js_blocks_obfuscated = 0L,
      css_blocks_processed = 0L,
      meta_tags_stripped = 0L, html_comments_removed = 0L,
      watermark_client = "",
      verification_passed = TRUE, verification_summary = character(0),
      warnings = warnings_acc
    ))
  }

  if (minify_js && !nzchar(tools$terser)) {
    add_warning("terser not found. JS minification skipped. Install: npm install -g terser")
    minify_js <- FALSE
  }

  if (minify_css && !nzchar(tools$cleancss)) {
    add_warning("cleancss not found. CSS minification skipped. Install: npm install -g clean-css-cli")
    minify_css <- FALSE
  }

  if (minify_html && !nzchar(tools$html_minifier)) {
    add_warning("html-minifier-terser not found. HTML whitespace reduction skipped. Install: npm install -g html-minifier-terser")
    minify_html <- FALSE
  }

  if (obfuscate_js && !nzchar(tools$obfuscator)) {
    if (isTRUE(deliverable)) {
      refuse_obfuscation(
        "javascript-obfuscator was not found, so no JavaScript could be obfuscated.",
        c("Install it: npm install -g javascript-obfuscator",
          paste("Searched:", paste(.MINIFY_NODE_SEARCH_PATHS, collapse = ", ")),
          "Or clear the client deliverable checkbox to keep a development build."))
    }
    add_warning("javascript-obfuscator not found. JS obfuscation skipped. Install: npm install -g javascript-obfuscator")
    obfuscate_js <- FALSE
  }

  # -- Step 2: Read file ------------------------------------------------------
  html <- paste(readLines(input_path, warn = FALSE, encoding = "UTF-8"),
                collapse = "\n")
  original_html <- html

  # -- Step 2b: Harden any embedded srcdoc document ---------------------------
  # Before everything else, so the rest of the pipeline and the verification
  # step see the final attribute. Deliverable only: the dev copy keeps its
  # readable simulator. See .minify_harden_srcdoc().
  srcdoc_hardened <- 0L
  # A report whose only JavaScript lives inside a srcdoc has no block of its
  # own to obfuscate, so obfuscation_applied would stay FALSE and the size
  # check would apply its strict "must be smaller" rule to a file that
  # obfuscation had just made bigger. Verification needs to know the embedded
  # document was obfuscated.
  srcdoc_obfuscated <- FALSE
  if (isTRUE(deliverable)) {
    sd <- .minify_harden_srcdoc(
      html,
      opts = list(strip_meta = strip_meta, minify_js = minify_js,
                  minify_css = minify_css, minify_html = minify_html,
                  obfuscate_js = obfuscate_js, watermark = watermark,
                  client_safe = client_safe, deliverable = deliverable),
      verbose = verbose)
    html <- sd$html
    srcdoc_hardened <- sd$count
    srcdoc_obfuscated <- isTRUE(sd$obfuscated)
  }

  # -- Step 2c: Harden embedded documents carried as islands ------------------
  # The other half of 2b, for a composed report: pages that reach their iframe
  # as a srcdoc PROPERTY rather than an attribute. Before step 8c, so a caller
  # who marks an island both ways encodes hardened bytes rather than readable
  # ones. See .minify_harden_document_islands().
  island_docs_hardened <- 0L
  island_doc_obfuscated <- FALSE
  if (isTRUE(deliverable)) {
    # First, the islands nobody marked. This runs before the marked ones and
    # regardless of whether there are any, because the failure it catches is a
    # composing step that marked NOTHING, where the marked path has nothing to
    # do and would return silently. See .minify_unmarked_document_islands().
    unmarked <- .minify_unmarked_document_islands(html)
    if (length(unmarked) > 0L) {
      msg <- sprintf(
        "%d island(s) carry a whole HTML page but are not marked data-embed=\"document\": %s",
        length(unmarked), paste(utils::head(unmarked, 8L), collapse = ", "))
      fix <- c(
        "Add data-embed=\"document\" to those islands in the step that composes the report",
        "Without it the page inside ships readable: its comments, and every name it declares",
        "If the island really is data and not a page, this is a bug worth reporting")
      cat("\n+-- TURAS ERROR ----------------------------------------------+\n")
      cat("| Context:    Minify, embedded document island\n")
      cat("| Code:       CALC_MINIFY_ISLAND_DOC_UNMARKED\n")
      cat("| Message:   ", msg, "\n")
      for (fx in fix) cat("| How to fix:", fx, "\n")
      cat("+-------------------------------------------------------------+\n\n")
      turas_refuse(
        code = "CALC_MINIFY_ISLAND_DOC_UNMARKED",
        title = "A page is being shipped inside an island without being hardened",
        problem = msg,
        why_it_matters = paste(
          "The deliverable would carry whole pages in plain sight inside a file",
          "that is otherwise hardened. That is exactly how the VAS integrated",
          "report shipped sixty-five readable references to its own internals."),
        how_to_fix = fix,
        module = "MINIFY"
      )
    }

    idoc <- .minify_harden_document_islands(
      html,
      opts = list(strip_meta = strip_meta, minify_js = minify_js,
                  minify_css = minify_css, minify_html = minify_html,
                  obfuscate_js = obfuscate_js, watermark = watermark,
                  client_safe = client_safe, deliverable = deliverable),
      verbose = verbose)
    html <- idoc$html
    island_docs_hardened <- idoc$count
    island_doc_obfuscated <- isTRUE(idoc$obfuscated)
  }

  # -- Step 3: Strip meta tags ------------------------------------------------
  meta_result <- list(count = 0L)
  if (strip_meta) {
    meta_result <- .minify_strip_meta_tags(html)
    html <- meta_result$html
    if (verbose && meta_result$count > 0L) {
      cat(sprintf("  Stripped %d turas-* meta tags\n", meta_result$count))
    }
  }

  # -- Step 4: Remove HTML comments -------------------------------------------
  comment_result <- .minify_remove_html_comments(html)
  html <- comment_result$html
  if (verbose && comment_result$count > 0L) {
    cat(sprintf("  Removed %d HTML comments\n", comment_result$count))
  }

  # -- Step 5: Extract and minify CSS blocks ----------------------------------
  css_blocks <- .minify_extract_blocks(html, "style")
  original_css_combined <- paste(vapply(css_blocks, function(b) b$content, character(1)),
                                  collapse = "\n")
  css_minified_contents <- vector("list", length(css_blocks))
  css_processed <- 0L

  if (minify_css && length(css_blocks) > 0L) {
    for (i in seq_along(css_blocks)) {
      if (!nzchar(css_blocks[[i]]$content)) {
        # Not `<- NULL`. See the note in the JS minify loop below.
        next
      }
      result <- .minify_css_block(css_blocks[[i]]$content, tools$cleancss)
      if (result$success) {
        css_minified_contents[[i]] <- result$content
        css_processed <- css_processed + 1L
      } else {
        # Not `<- NULL`. See the note in the JS minify loop below.
        add_warning(sprintf("CSS block %d failed to minify, kept original", i))
      }
    }

    html <- .minify_replace_blocks(html, css_blocks, css_minified_contents)
    if (verbose) cat(sprintf("  Minified %d/%d CSS blocks\n",
                             css_processed, length(css_blocks)))
  }

  # -- Step 6: Extract and minify JS blocks -----------------------------------
  # Re-extract after CSS replacement (positions changed)
  js_blocks <- .minify_extract_blocks(html, "script")
  original_js_combined <- ""
  js_minified_contents <- vector("list", length(js_blocks))
  js_processed <- 0L

  if (minify_js && length(js_blocks) > 0L) {
    js_original_parts <- character(0)
    for (i in seq_along(js_blocks)) {
      block <- js_blocks[[i]]

      # Skip non-JS blocks
      if (block$type %in% c("application/json", "text/plain")) {
      # Leave the preallocated NULL in place rather than assigning NULL, which
      # DELETES the element and shortens the list, so every later index no
      # longer lines up with `blocks`. Real reports survived only because their
      # last script block is the JS one, and the final real assignment extended
      # the list back to length. A document whose last script block is a JSON
      # island errored in .minify_replace_blocks() with a subscript out of
      # bounds (found 4 September 2026 by the island encoding fixture).
        next
      }

      if (!nzchar(block$content)) {
      # Leave the preallocated NULL in place rather than assigning NULL, which
      # DELETES the element and shortens the list, so every later index no
      # longer lines up with `blocks`. Real reports survived only because their
      # last script block is the JS one, and the final real assignment extended
      # the list back to length. A document whose last script block is a JSON
      # island errored in .minify_replace_blocks() with a subscript out of
      # bounds (found 4 September 2026 by the island encoding fixture).
        next
      }

      js_original_parts <- c(js_original_parts, block$content)
      result <- .minify_js_block(block$content, tools$terser)
      if (result$success) {
        js_minified_contents[[i]] <- result$content
        js_processed <- js_processed + 1L
      } else {
        # Not `<- NULL`, which would delete the element and shift every later
        # index. The slot is already NULL, which .minify_replace_blocks() reads
        # as "leave this block alone".
        add_warning(sprintf("JS block %d failed to minify, kept original", i))
      }
    }

    original_js_combined <- paste(js_original_parts, collapse = "\n")
    html <- .minify_replace_blocks(html, js_blocks, js_minified_contents)
    if (verbose) cat(sprintf("  Minified %d/%d JS blocks\n",
                             js_processed, length(js_blocks)))
  } else {
    # Collect original JS for verification even if not minifying
    for (block in js_blocks) {
      if (!block$type %in% c("application/json", "text/plain")) {
        original_js_combined <- paste0(original_js_combined, block$content, "\n")
      }
    }
  }

  # -- Step 6b: JS obfuscation ------------------------------------------------
  js_obfuscated <- 0L
  obfuscation_applied <- FALSE

  if (obfuscate_js && nzchar(tools$obfuscator)) {
    # Re-extract JS blocks (positions shifted after step 6 replacement)
    obf_js_blocks <- .minify_extract_blocks(html, "script")
    obf_contents <- vector("list", length(obf_js_blocks))

    for (i in seq_along(obf_js_blocks)) {
      block <- obf_js_blocks[[i]]

      # Skip non-JS blocks
      if (block$type %in% c("application/json", "text/plain")) {
      # Leave the preallocated NULL in place rather than assigning NULL, which
      # DELETES the element and shortens the list, so every later index no
      # longer lines up with `blocks`. Real reports survived only because their
      # last script block is the JS one, and the final real assignment extended
      # the list back to length. A document whose last script block is a JSON
      # island errored in .minify_replace_blocks() with a subscript out of
      # bounds (found 4 September 2026 by the island encoding fixture).
        next
      }
      if (!nzchar(block$content)) {
      # Leave the preallocated NULL in place rather than assigning NULL, which
      # DELETES the element and shortens the list, so every later index no
      # longer lines up with `blocks`. Real reports survived only because their
      # last script block is the JS one, and the final real assignment extended
      # the list back to length. A document whose last script block is a JSON
      # island errored in .minify_replace_blocks() with a subscript out of
      # bounds (found 4 September 2026 by the island encoding fixture).
        next
      }

      result <- .minify_obfuscate_js_block(block$content, tools$obfuscator)
      if (result$success) {
        obf_contents[[i]] <- result$content
        js_obfuscated <- js_obfuscated + 1L
      } else if (isTRUE(deliverable)) {
        # Tell the two failures apart. A block terser also rejects was never
        # valid JavaScript, so the report itself is at fault and no obfuscator
        # setting will help. Only run on the failure path.
        parseable <- isTRUE(suppressWarnings(
          .minify_js_block(block$content, tools$terser))$success)
        if (parseable) {
          refuse_obfuscation(
            sprintf("JS block %d could not be obfuscated (tool error or timeout at %d seconds).",
                    i, .MINIFY_TOOL_TIMEOUT_SECS),
            c("Run javascript-obfuscator on the report by hand to see its error",
              "A very large report may need .MINIFY_TOOL_TIMEOUT_SECS raised",
              "Or clear the client deliverable checkbox to keep a development build."))
        } else {
          refuse_obfuscation(
            sprintf("JS block %d is not valid JavaScript, so it could not be protected.",
                    i),
            c("The report generator wrote a script block the parser rejects",
              "Save the report, open that script block and check it parses",
              "Or clear the client deliverable checkbox to keep a development build."))
        }
      } else {
        # Not `<- NULL`. See the note in the minify loop above.
        add_warning(sprintf("JS block %d failed to obfuscate, kept minified version", i))
      }
    }

    if (js_obfuscated > 0L) {
      html <- .minify_replace_blocks(html, obf_js_blocks, obf_contents)
      obfuscation_applied <- TRUE
    }
    if (verbose) cat(sprintf("  Obfuscated %d/%d JS blocks\n",
                             js_obfuscated, length(obf_js_blocks)))
  }

  # -- Step 6c: Watermark injection --------------------------------------------
  watermark_client <- ""
  if (is.character(watermark) && length(watermark) == 1L && nzchar(watermark)) {
    if (exists(".minify_inject_watermark", mode = "function")) {
      wm_result <- .minify_inject_watermark(html, watermark)
      if (wm_result$success) {
        html <- wm_result$html
        watermark_client <- wm_result$client
        if (verbose) {
          cat(sprintf("  Watermark: %s (ID: %s)\n",
                      wm_result$client, substr(wm_result$id, 1L, 8L)))
        }
      } else {
        add_warning("Watermark injection failed")
      }
    } else {
      add_warning("Watermark functions not loaded. Source turas_minify_watermark.R first.")
    }
  }

  # -- Step 7: HTML whitespace reduction --------------------------------------
  html_reduced <- FALSE
  if (minify_html) {
    pre_html_size <- nchar(html)
    ws_result <- .minify_html_whitespace(html, tools$html_minifier)
    if (ws_result$success) {
      html <- ws_result$html
      html_reduced <- TRUE
      if (verbose) {
        saved <- pre_html_size - nchar(html)
        cat(sprintf("  HTML whitespace: saved %.0f KB\n", saved / 1024))
      }
    } else {
      add_warning("HTML whitespace reduction skipped (tool failed or result larger)")
    }
  }

  # -- Step 8: Inject build tag -----------------------------------------------
  html <- .minify_inject_build_tag(html)

  # -- Step 8b: Release audit, BEFORE anything is written ---------------------
  # What the delivered file actually contains. Runs on the final html string,
  # which is the thing that leaves. Refuses when the caller declared client_safe
  # and the respondent island is still there: a declaration that cannot fail is
  # not a declaration. It sits before the write on purpose: an audit that ran
  # after the write left a respondent-level file on disk under the clean
  # deliverable name and then said no (found by Duncan, 4 Sep 2026).
  .minify_load_release_audit()
  release <- if (exists("turas_release_audit", mode = "function")) {
    turas_release_audit(html, client_safe = isTRUE(client_safe), refuse = TRUE)
  } else {
    # A declaration that cannot be checked must not pass quietly. On a full build
    # the audit is a report and its absence is a warning; on a client-safe one it
    # is the gate, and a missing gate is not an open one.
    if (isTRUE(client_safe)) {
      if (exists("turas_refuse", mode = "function")) {
        turas_refuse(
          code = "CFG_RELEASE_AUDIT_UNAVAILABLE",
          title = "Client-safe build cannot be checked, so it is not written",
          problem = paste(
            "This build was declared client-safe, and turas_release_audit.R could",
            "not be loaded, so nothing checked what the file actually contains."),
          why_it_matters = paste(
            "The client-safe declaration is enforced by that audit and by nothing",
            "else. Without it the build would ship on the strength of a radio",
            "button, which is what it was written to replace."),
          how_to_fix = c(
            "Check that modules/shared/lib/turas_release_audit.R exists in this checkout.",
            "It is loaded automatically beside turas_minify.R; a missing file is the usual cause.",
            "The dev copy is kept, so nothing on disk is mistaken for a client file."),
          module = "MINIFY")
      } else {
        stop("Client-safe build declared but the release audit could not be loaded",
             call. = FALSE)
      }
    }
    add_warning("Release audit unavailable: the delivered file was not checked")
    NULL
  }

  # -- Step 8c: Encode the data islands ---------------------------------------
  # After the audit, not before. The audit reads "n": out of the respondent
  # island to say what the delivered file contains, and once the island is
  # encoded it can no longer see it, so an audit run afterwards would report the
  # island absent, which is the wrong answer. Nothing after this point disturbs
  # base64: the build tag is a separate element and html-minifier-terser has
  # already run.
  islands_encoded <- 0L
  island_seed <- NA_integer_
  if (isTRUE(deliverable) && requireNamespace("jsonlite", quietly = TRUE)) {
    island_seed <- sample.int(2147483647L, 1L)
    enc <- tryCatch(.minify_encode_islands(html, island_seed), error = function(e) e)
    if (inherits(enc, "error")) {
      cat("\n+-- TURAS ERROR ----------------------------------------------+\n")
      cat("| Context:    Minify, step 8c, client deliverable build\n")
      cat("| Code:       CALC_MINIFY_ISLAND_ENCODE_FAILED\n")
      cat("| Message:   ", conditionMessage(enc), "\n")
      cat("+-------------------------------------------------------------+\n\n")
      turas_refuse(
        code = "CALC_MINIFY_ISLAND_ENCODE_FAILED",
        title = "The data islands could not be encoded",
        problem = paste("Island encoding failed:", conditionMessage(enc)),
        why_it_matters = paste(
          "The islands carry the tables, and in a records build the respondent",
          "rows. Writing them in plain sight was what this build was meant to",
          "stop, so it refuses rather than shipping them readable."),
        how_to_fix = c(
          "Report the message above, it names the island that failed",
          "Or clear the client deliverable checkbox to keep a development build."),
        module = "MINIFY"
      )
    }
    html <- enc$html
    islands_encoded <- enc$count
    if (verbose && islands_encoded > 0L) {
      cat(sprintf("  Islands encoded: %d\n", islands_encoded))
    }
  }
  if (is.list(release)) {
    release$islands_encoded <- islands_encoded > 0L
  }

  # -- Step 9: Write output ---------------------------------------------------
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  writeLines(html, output_path, useBytes = TRUE)
  output_size <- file.info(output_path)$size

  if (verbose) cat(sprintf("  Written: %s (%.0f KB)\n", basename(output_path),
                           output_size / 1024))

  # -- Step 10: Verification --------------------------------------------------
  minified_css_combined <- ""
  minified_js_combined <- ""

  # Re-extract minified blocks for verification
  minified_css_blocks <- .minify_extract_blocks(html, "style")
  minified_css_combined <- paste(vapply(minified_css_blocks,
                                         function(b) b$content, character(1)),
                                  collapse = "\n")

  minified_js_blocks <- .minify_extract_blocks(html, "script")
  for (block in minified_js_blocks) {
    if (!block$type %in% c("application/json", "text/plain")) {
      minified_js_combined <- paste0(minified_js_combined, block$content, "\n")
    }
  }

  verification <- run_minify_verification(
    original_html = original_html,
    minified_html = html,
    original_css = original_css_combined,
    minified_css = minified_css_combined,
    original_js = original_js_combined,
    minified_js = minified_js_combined,
    input_size_bytes = input_size,
    output_size_bytes = output_size,
    obfuscated = obfuscation_applied || srcdoc_obfuscated || island_doc_obfuscated,
    watermark_client = if (nzchar(watermark_client)) watermark_client else NULL
  )

  if (!verification$all_passed) {
    failed_checks <- verification$summary[grepl("^\\[FAIL\\]", verification$summary)]
    for (msg in failed_checks) {
      add_warning(paste("Verification:", msg))
    }
  }

  # -- Step 11: Build result --------------------------------------------------
  reduction_pct <- if (input_size > 0) {
    (1 - output_size / input_size) * 100
  } else {
    0
  }

  status <- if (length(warnings_acc) == 0L) "PASS" else "PARTIAL"

  result <- list(
    status = status,
    input_path = input_path,
    output_path = output_path,
    input_size_kb = input_size / 1024,
    output_size_kb = output_size / 1024,
    reduction_pct = reduction_pct,
    js_blocks_processed = js_processed,
    js_blocks_obfuscated = js_obfuscated,
    css_blocks_processed = css_processed,
    meta_tags_stripped = meta_result$count,
    html_comments_removed = comment_result$count,
    watermark_client = watermark_client,
    verification_passed = verification$all_passed,
    verification_summary = verification$summary,
    client_safe = isTRUE(client_safe),
    deliverable = isTRUE(deliverable),
    srcdoc_documents_hardened = srcdoc_hardened,
    island_documents_hardened = island_docs_hardened,
    islands_encoded = islands_encoded,
    island_seed = island_seed,
    release_audit = release,
    warnings = warnings_acc
  )

  if (verbose) .minify_print_summary(result)

  result
}


#' Say plainly whether a deliverable got smaller or larger
#'
#' The obfuscator's string array and its long generated names make a hardened
#' deliverable roughly twice the size of the development build. The old wording
#' printed that as "-115.2%% smaller", which is not a sentence anyone should
#' read on a client build.
#'
#' @param pct The reduction percentage, negative when the file grew.
#' @return A short phrase for the console.
#' @keywords internal
.minify_size_phrase <- function(pct) {
  if (!is.finite(pct)) return("size unchanged")
  if (pct >= 0) sprintf("%.1f%% smaller", pct) else sprintf("%.1f%% larger", -pct)
}

#' Prepare Client Deliverable from HTML Report
#'
#' Convenience wrapper for Shiny GUI integration. Checks the
#' TURAS_PREPARE_DELIVERABLE global flag, renames the original to _dev,
#' minifies to the clean name, and falls back safely on failure.
#'
#' Call this after a successful HTML report write. Does nothing if the
#' flag is not set or turas_minify is not available.
#'
#' @param html_path Character. Path to the HTML report just written.
#' @return Invisible NULL (side effects: renames file, creates minified copy,
#'   prints progress to console).
#'
#' @examples
#' \dontrun{
#'   # In a module run script, after HTML write succeeds:
#'   turas_prepare_deliverable(html_output_path)
#' }
#'
#' @export
turas_prepare_deliverable <- function(html_path) {
  if (!isTRUE(get0("TURAS_PREPARE_DELIVERABLE", envir = .GlobalEnv))) {
    return(invisible(NULL))
  }

  if (!is.character(html_path) || length(html_path) != 1L || !nzchar(html_path)) {
    return(invisible(NULL))
  }

  if (!file.exists(html_path)) {
    return(invisible(NULL))
  }

  cat("\n  Preparing client deliverable...\n")
  dev_path <- sub("\\.html$", "_dev.html", html_path)

  if (!file.rename(html_path, dev_path)) {
    cat("  [WARNING] Could not rename file for minification. Report preserved.\n")
    return(invisible(NULL))
  }

  # Pick up client name from global env (set by GUI)
  client_name <- get0("TURAS_CLIENT_NAME", envir = .GlobalEnv)
  if (!is.character(client_name) || length(client_name) != 1L || !nzchar(client_name)) {
    client_name <- NULL
  }

  # The delivery mode the operator chose in the GUI. FALSE (audit and report)
  # unless they positively declared the build client-safe, in which case a
  # surviving microdata island refuses rather than ships.
  client_safe <- isTRUE(get0("TURAS_DELIVERY_CLIENT_SAFE", envir = .GlobalEnv))

  # A refusal (the client-safe audit) must not abort the rest of the run: the
  # Reader and qualitative reports still follow this call. Catch it, say plainly
  # that no deliverable was written, and leave the dev copy under its _dev name
  # so nothing on disk is mistaken for a client file.
  minify_result <- tryCatch(
    turas_minify(dev_path, verbose = TRUE, watermark = client_name,
                 client_safe = client_safe, deliverable = TRUE),
    turas_refusal = function(e) {
      # The refusal text carries the code, the problem and the fix. Turas runs
      # in Shiny, so it has to reach the console here or it reaches nobody.
      cat(conditionMessage(e), "\n")
      cat("\n  [REFUSED] No client deliverable was written.\n")
      cat(sprintf("  The report is kept as %s (dev copy, not for delivery).\n",
                  basename(dev_path)))
      list(status = "REFUSED", output_path = NA_character_, reduction_pct = NA_real_)
    }
  )

  if (identical(minify_result$status, "REFUSED")) {
    # Deliberately NOT renamed back: a file under the clean deliverable name
    # is a file someone will send.
    return(invisible(NULL))
  }

  if (minify_result$status %in% c("PASS", "PARTIAL")) {
    cat(sprintf("  Client deliverable: %s (%s)\n",
        basename(minify_result$output_path),
        .minify_size_phrase(minify_result$reduction_pct)))
    cat(sprintf("  Dev copy kept: %s\n", basename(dev_path)))
  } else {
    file.rename(dev_path, html_path)
    cat("  [WARNING] Minification failed. Original report preserved.\n")
  }

  invisible(NULL)
}
