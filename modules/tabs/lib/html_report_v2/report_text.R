# ==============================================================================
# TABS — AUTHORED REPORT TEXT (v2)
# ==============================================================================
# The v2 report's interpretive prose — the explainers, legends and method
# notes a client reads — is authored in the shared callout registry
# (modules/shared/lib/callouts/callouts.json, module "tabs") and edited in the
# Callout Editor. It is NOT written in the renderer.
#
# This file is the build-time half of that arrangement:
#
#   1. reads the "tabs" block out of the registry;
#   2. validates it against the renderer's manifest (assets/text_manifest.json);
#   3. serialises it to the JSON inlined as the report's #data-text island.
#
# The renderer's half is assets/js/02_text.js (TR.txt).
#
# WHY IT REFUSES RATHER THAN FALLS BACK
# There is deliberately no wording in the renderer to fall back to. A report
# whose text is half-authored and half-invented would be worse than one that
# does not build: the analyst would have no way to tell which sentences were
# theirs. So a missing key, an undeclared placeholder or unsafe markup stops
# the v2 build with a TRS refusal naming the key. The Excel workbook and every
# other output are unaffected (run_crosstabs.R builds the v2 report inside its
# own tryCatch).
#
# THE THREE CHECKS
#   - every key the renderer calls (TR.txt("...")) is declared in the manifest;
#   - every manifest key exists in the registry;
#   - every {placeholder} in the authored text is declared for that key, and
#     the markup uses only the small whitelist of inline tags.
#
# ADDING A NEW AUTHORED BLOCK is therefore a closed loop: call TR.txt("x.y") in
# the renderer, add "x.y" to the manifest, add the text in the Callout Editor.
# Miss either of the last two and the next build tells you which one, by name.
#
# VERSION: 1.0.0
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Inline tags an author may use. Deliberately small: enough to emphasise and to
# write a list, not enough to lay anything out. Layout is the renderer's job,
# and an unbalanced <div> typed into the editor would distort a client report.
.REPORT_TEXT_TAGS <- c("strong", "em", "b", "i", "br", "p", "ul", "ol", "li",
                       "h3", "h4", "span", "code", "sup", "sub")

# Tags with no closing partner — excluded from the balance check.
.REPORT_TEXT_VOID_TAGS <- c("br")

# What counts as a placeholder: {lower_snake_case}. Anything else between
# braces is left alone, so an author can write "{n}" or "{see below}" in prose
# without it being mistaken for a token they got wrong.
.REPORT_TEXT_TOKEN_RE <- "\\{([a-z][a-z0-9_]*)\\}"


#' Path to the renderer's text manifest
#'
#' @param assets_dir The vendored v2 assets directory
#' @return Absolute or relative path to text_manifest.json
#' @export
report_text_manifest_path <- function(assets_dir = report_v2_assets_dir()) {
  file.path(assets_dir, "text_manifest.json")
}


#' Load the renderer's text manifest
#'
#' The manifest is the renderer's declaration of what text it needs: one entry
#' per key, naming the placeholders that key may use and where it appears. It
#' lives beside the JS because it belongs to the renderer — the registry holds
#' the words, the manifest holds the contract.
#'
#' @param path Path to text_manifest.json
#' @return Named list of key -> list(tokens, page, context). `_meta` removed.
#' @export
load_report_text_manifest <- function(path = report_text_manifest_path()) {
  if (!file.exists(path)) {
    stop(sprintf("[IO_REPORT_TEXT_MANIFEST] text manifest missing at %s", path))
  }
  man <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  man[["_meta"]] <- NULL
  man
}


# A direct call: TR.txt("x.y") / TR.txt.block("x.y").
.REPORT_TEXT_CALL_RE <- "TR\\.txt(?:\\.block)?\\(\\s*[\"']([^\"']+)[\"']"

# Any quoted dotted lower-case key ANYWHERE in the bundle. The renderer reaches
# its text three ways — directly, through a local one-line wrapper
# (li("cards.reading.heatmap")), and through a ternary inside the call
# (TR.txt(cond ? "a.b" : "c.d")) — and only the first is a call-position match.
# Since this is intersected with the manifest before use, a key named in a
# comment counts as referenced, which is the right answer for a check whose only
# job is to notice text nobody renders.
.REPORT_TEXT_ALIAS_RE <- "[\"']([a-z][a-z0-9_]*(?:\\.[a-z0-9_]+)+)[\"']"

.report_text_matches <- function(txt, pattern) {
  m <- gregexpr(pattern, txt, perl = TRUE)
  hits <- regmatches(txt, m)[[1]]
  if (length(hits) == 0) return(character(0))
  unique(sub(pattern, "\\1", hits, perl = TRUE))
}


#' Every text key the renderer directly asks for
#'
#' Scans the bundled JS for TR.txt("key") / TR.txt.block("key"). This is what
#' makes the manifest impossible to forget: a direct call with no manifest entry
#' is a build refusal, not a blank space in a client's report.
#'
#' Note it scans the bundle as text, so a call inside a comment counts. That is
#' intentional — a commented-out key is either coming back (keep it declared) or
#' it is dead (delete both).
#'
#' @param js_bundle The concatenated renderer JS
#' @return Character vector of unique keys, sorted
#' @export
report_text_keys_used <- function(js_bundle) {
  sort(.report_text_matches(js_bundle, .REPORT_TEXT_CALL_RE))
}


#' Manifest keys the renderer references at all, including through a wrapper
#'
#' Several renderers alias TR.txt.block behind a one-line local helper so a
#' block of markup reads cleanly — li("cards.reading.heatmap") rather than the
#' full call with its options object. Those are real uses, and counting only
#' direct calls reported two thirds of the catalogue as unused.
#'
#' This deliberately only ever CONFIRMS keys the manifest already declares, so a
#' coincidental dotted string can never invent a refusal. The one gap it leaves —
#' a wrapper call to a key nobody declared — renders empty and is reported by the
#' in-browser selftest (TR.txt.misses, 31_selftest.js) during development.
#'
#' @param js_bundle The concatenated renderer JS
#' @param manifest The loaded manifest
#' @return Character vector of unique keys, sorted
#' @export
report_text_keys_referenced <- function(js_bundle, manifest) {
  candidates <- .report_text_matches(js_bundle, .REPORT_TEXT_ALIAS_RE)
  sort(unique(c(report_text_keys_used(js_bundle),
                intersect(candidates, names(manifest)))))
}


# --- Internal: markup checks --------------------------------------------------

# Every tag used, in document order, as c(name, name, ...) with a leading "/"
# on closers.
.report_text_tags <- function(txt) {
  m <- gregexpr("</?[A-Za-z][A-Za-z0-9]*[^>]*>", txt, perl = TRUE)
  raw <- regmatches(txt, m)[[1]]
  if (length(raw) == 0) return(character(0))
  raw
}

# Returns a character vector of problems (empty when the markup is acceptable).
.report_text_markup_problems <- function(txt) {
  problems <- character(0)
  tags <- .report_text_tags(txt)
  if (length(tags) == 0) return(problems)

  stack <- character(0)
  for (tag in tags) {
    closing <- grepl("^</", tag)
    name <- tolower(sub("^</?([A-Za-z][A-Za-z0-9]*).*$", "\\1", tag))
    attrs <- sub("^</?[A-Za-z][A-Za-z0-9]*", "", sub("/?>$", "", tag))

    if (!name %in% .REPORT_TEXT_TAGS) {
      problems <- c(problems, sprintf("tag <%s> is not allowed (permitted: %s)",
                                      name, paste(.REPORT_TEXT_TAGS, collapse = ", ")))
      next
    }
    if (!closing && nzchar(trimws(attrs))) {
      problems <- c(problems, sprintf("tag <%s> carries attributes (%s) — authored text may not style or script; ask for a renderer change instead",
                                      name, trimws(attrs)))
    }
    if (name %in% .REPORT_TEXT_VOID_TAGS) next

    if (closing) {
      if (length(stack) == 0 || stack[length(stack)] != name) {
        problems <- c(problems, sprintf("closing </%s> does not match the open tag", name))
      } else {
        stack <- stack[-length(stack)]
      }
    } else {
      stack <- c(stack, name)
    }
  }
  if (length(stack) > 0) {
    problems <- c(problems, sprintf("unclosed tag(s): %s",
                                    paste0("<", rev(stack), ">", collapse = " ")))
  }
  problems
}


#' Validate authored text against the renderer's manifest
#'
#' @param manifest Named list from load_report_text_manifest()
#' @param entries Named list of registry entries for the "tabs" module
#' @param keys_used Character vector from report_text_keys_used() — DIRECT calls,
#'   checked against the manifest
#' @param referenced Character vector from report_text_keys_referenced() — every
#'   key the renderer touches, used only for the "authored but never rendered"
#'   note. Defaults to keys_used.
#' @return list(errors = character, warnings = character)
#' @export
validate_report_text <- function(manifest, entries, keys_used = character(0),
                                 referenced = keys_used) {
  errors <- character(0)
  warnings <- character(0)

  # 1. Every key the renderer calls must be declared.
  undeclared <- setdiff(keys_used, names(manifest))
  if (length(undeclared)) {
    errors <- c(errors, sprintf(
      "the renderer calls TR.txt(\"%s\") but the key is not in text_manifest.json", undeclared))
  }

  # 2. Every declared key must be authored. Empty text is legitimate — it means
  #    "do not show this block on any report" — but the key must be present, so
  #    that deleting an entry in the editor is a loud act rather than a silent
  #    hole in the page.
  for (key in names(manifest)) {
    entry <- entries[[key]]
    if (is.null(entry)) {
      errors <- c(errors, sprintf(
        "no text authored for \"%s\" — add it in the Callout Editor under module 'tabs' (page: %s)",
        key, manifest[[key]]$page %||% "?"))
      next
    }

    txt <- as.character(entry$text %||% "")
    if (!nzchar(trimws(txt))) next   # deliberately blank: render nothing

    # 3. Placeholders must be declared for this key.
    declared <- unlist(manifest[[key]]$tokens %||% list())
    m <- gregexpr(.REPORT_TEXT_TOKEN_RE, txt, perl = TRUE)
    found <- regmatches(txt, m)[[1]]
    used <- unique(sub(.REPORT_TEXT_TOKEN_RE, "\\1", found, perl = TRUE))
    unknown <- setdiff(used, declared)
    if (length(unknown)) {
      errors <- c(errors, sprintf(
        "\"%s\" uses {%s}, which this text cannot supply (available: %s)",
        key, unknown,
        if (length(declared)) paste0("{", declared, "}", collapse = " ") else "none"))
    }
    # A declared token the author chose not to use is their call, not an error —
    # but say so, because it is also what a mistyped sentence looks like.
    unused <- setdiff(declared, used)
    if (length(unused)) {
      warnings <- c(warnings, sprintf("\"%s\" does not use {%s}", key, unused))
    }

    # 4. Markup must be inline, balanced and attribute-free.
    for (p in .report_text_markup_problems(txt)) {
      errors <- c(errors, sprintf("\"%s\": %s", key, p))
    }
  }

  # 5. Text nobody renders. Not fatal — a key may be declared ahead of the code
  #    that uses it — but it is how the registry silted up before. `referenced`
  #    is the wider list (wrapper calls included) so this stays quiet about text
  #    that IS rendered; leave it NULL to skip the check entirely.
  if (length(referenced)) {
    unused_keys <- setdiff(names(manifest), referenced)
    if (length(unused_keys)) {
      warnings <- c(warnings, sprintf(
        "\"%s\" is authored but the renderer never asks for it", unused_keys))
    }
  }

  list(errors = errors, warnings = warnings)
}


#' Build the authored-text island for a v2 report
#'
#' Reads the registry, validates it against the manifest, and returns the JSON
#' to inline. Refuses — loudly, naming the key — rather than shipping a report
#' with a hole in it.
#'
#' @param assets_dir The vendored v2 assets directory
#' @param js_bundle The bundled renderer JS (for the key scan). NULL skips the
#'   scan, which is only appropriate in unit tests of this function itself.
#' @param entries Optional pre-loaded registry entries (tests inject here);
#'   defaults to the "tabs" block of the shared registry.
#' @param overrides Optional named list of key -> text from the config's
#'   ReportText sheet. Applied on top of the platform wording for this build
#'   only, and validated exactly like it.
#' @return list(status = "PASS"|"REFUSED", json = character, warnings = character)
#' @export
build_report_text_json <- function(assets_dir = report_v2_assets_dir(),
                                   js_bundle = NULL,
                                   entries = NULL,
                                   overrides = NULL) {
  manifest <- load_report_text_manifest(report_text_manifest_path(assets_dir))

  if (is.null(entries)) {
    if (!exists("turas_callout_module", mode = "function")) {
      stop("[IO_REPORT_TEXT_REGISTRY] callout_registry.R is not loaded — the v2 report cannot read its authored text.")
    }
    entries <- turas_callout_module("tabs")
  }

  # Per-project overrides (config ReportText sheet). A key that names nothing is
  # an error, not a no-op: a typo there looks exactly like an override that is
  # working, and the analyst would only find out by reading the client's copy.
  if (length(overrides)) {
    unknown <- setdiff(names(overrides), names(manifest))
    if (length(unknown)) {
      stop(sprintf(paste0("[CFG_REPORT_TEXT_OVERRIDE] the config's ReportText sheet ",
                          "names text this report does not have: %s.\n  Check the key ",
                          "against the Callout Editor (module 'tabs'), or delete the row."),
                   paste(unknown, collapse = ", ")))
    }
    for (key in names(overrides)) {
      entry <- entries[[key]] %||% list()
      entry$text <- as.character(overrides[[key]])
      entries[[key]] <- entry
    }
  }

  keys_used <- if (is.null(js_bundle)) character(0) else report_text_keys_used(js_bundle)
  referenced <- if (is.null(js_bundle)) character(0)
                else report_text_keys_referenced(js_bundle, manifest)
  check <- validate_report_text(manifest, entries, keys_used, referenced)

  if (length(check$errors)) {
    stop(sprintf(
      "[CFG_REPORT_TEXT_INVALID] the v2 report's authored text does not match the renderer:\n  - %s\n  Fix in the Callout Editor (module 'tabs') or in %s.",
      paste(check$errors, collapse = "\n  - "),
      basename(report_text_manifest_path(assets_dir))))
  }

  # Ship only what the manifest declares, and only the text itself: title,
  # context and page are authoring aids for the editor, not report content.
  payload <- list()
  for (key in names(manifest)) {
    payload[[key]] <- as.character(entries[[key]]$text %||% "")
  }

  list(status = "PASS",
       json = jsonlite::toJSON(payload, auto_unbox = TRUE),
       warnings = check$warnings)
}
