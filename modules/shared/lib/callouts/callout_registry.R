# ==============================================================================
# TURAS CALLOUT REGISTRY
# ==============================================================================
# Centralised lookup for all educational callout text across Turas modules.
# Callout text is stored in callouts.json (same directory) and can be
# edited there without touching any module code.
#
# FUNCTIONS:
# - turas_callout()        - Get a single callout as styled HTML
# - turas_callout_text()   - Get raw callout data (title + text)
# - turas_callout_html()   - Build callout HTML with standard styling
# - turas_callout_module() - Get every entry for one module
# - turas_callouts_path()  - Resolve the on-disk registry path
# - turas_callouts_write() - Write the registry back, atomically, with backups
#
# VERSION: 1.1.0
# ==============================================================================


# --- Internal: load and cache the callout registry ---
.callout_cache <- new.env(parent = emptyenv())

# Where this file was sourced from, captured AT SOURCE TIME.
#
# source() records the file it is reading as `ofile` on its own evaluation
# frame, and that frame only exists while the file is being read — so this has
# to be resolved here, at the top level, not inside a function called later.
# Reading sys.frame(1)$ofile from inside a function is what the registry used
# to do, and it silently returned nothing: the lookup then fell through to
# working-directory-relative paths, which happen to work when a report is built
# from the project root and fail everywhere else (testthat runs from
# modules/tabs/tests/testthat, and found no callouts at all).
.CALLOUTS_SOURCE_DIR <- local({
  ofile <- NULL
  for (i in seq_len(sys.nframe())) {
    f <- sys.frame(i)
    if (!is.null(f$ofile)) ofile <- f$ofile
  }
  if (is.null(ofile)) "" else dirname(normalizePath(ofile, mustWork = FALSE))
})


#' Resolve the Callout Registry Path
#'
#' Single place that knows where callouts.json lives, so the reader, the
#' editor and the Tabs v2 text loader can never disagree about it. Tries, in
#' order: the directory this file was sourced from, TURAS_ROOT, then two
#' working-directory-relative paths (Shiny and test environments run from
#' different places).
#'
#' @return Character path. The best candidate even when nothing exists yet,
#'   so callers can report a useful "not found" against a real path.
#' @export
turas_callouts_path <- function() {
  here <- .CALLOUTS_SOURCE_DIR
  candidates <- c(
    if (nzchar(here)) file.path(here, "callouts.json") else NULL,
    local({
      tr <- Sys.getenv("TURAS_ROOT", "")
      if (nzchar(tr)) file.path(tr, "modules", "shared", "lib", "callouts", "callouts.json") else NULL
    }),
    file.path("modules", "shared", "lib", "callouts", "callouts.json"),
    file.path("..", "modules", "shared", "lib", "callouts", "callouts.json")
  )
  candidates <- candidates[!is.na(candidates)]
  for (cand in candidates) if (file.exists(cand)) return(cand)
  candidates[length(candidates)]
}


.load_callouts <- function() {
  if (!is.null(.callout_cache$data)) return(.callout_cache$data)

  json_path <- turas_callouts_path()

  if (!file.exists(json_path)) {
    warning("Callout registry not found at: ", json_path)
    return(list())
  }

  data <- tryCatch(
    jsonlite::fromJSON(json_path, simplifyVector = FALSE),
    error = function(e) {
      warning("Failed to parse callouts.json: ", e$message)
      list()
    }
  )

  # Remove _meta key
  data[["_meta"]] <- NULL

  .callout_cache$data <- data
  data
}


#' Get Callout Text Data
#'
#' Returns the raw title and text for a specific callout.
#'
#' @param module Character. Module name (e.g., "keydriver", "conjoint")
#' @param key Character. Callout key (e.g., "shapley_importance")
#' @return Named list with title, text, context. NULL if not found.
#' @export
turas_callout_text <- function(module, key) {
  data <- .load_callouts()
  mod <- data[[module]]
  if (is.null(mod)) return(NULL)
  entry <- mod[[key]]
  if (is.null(entry)) return(NULL)
  entry
}


#' Generate Callout HTML
#'
#' Returns a styled HTML string for a callout, using the standard Turas
#' callout design (collapsible, with info icon, distinct from insights).
#' Callouts are tagged with class "t-callout" and data-turas-callout="true"
#' so they are excluded from pins and exports.
#'
#' @param module Character. Module name
#' @param key Character. Callout key
#' @param collapsed Logical. Whether callout starts collapsed (default FALSE)
#' @return Character HTML string. Empty string if callout not found.
#' @export
turas_callout <- function(module, key, collapsed = FALSE) {
  entry <- turas_callout_text(module, key)
  if (is.null(entry)) return("")

  turas_callout_html(
    title = entry$title,
    body = entry$text,
    collapsed = collapsed,
    registry_key = paste0(module, " / ", key)
  )
}


#' Build Callout HTML from Direct Content
#'
#' Builds the standard callout HTML block from provided title and body.
#' Use this when you have custom callout text not from the registry.
#'
#' @param title Character. Callout heading
#' @param body Character. Callout body (can contain HTML)
#' @param collapsed Logical. Start collapsed (default FALSE)
#' @param id Character or NULL. Optional DOM id for the callout
#' @param registry_key Character or NULL. Optional registry identifier shown as
#'   a subtle tag (e.g. "confidence / results_overview") so users can match
#'   the rendered callout to its entry in the Callout Editor.
#' @return Character HTML string
#' @export
turas_callout_html <- function(title, body, collapsed = FALSE, id = NULL,
                                registry_key = NULL) {
  collapsed_class <- if (collapsed) " collapsed" else ""
  id_attr <- if (!is.null(id)) paste0(' id="', id, '"') else ""
  key_tag <- if (!is.null(registry_key)) {
    sprintf('<span class="t-callout-key">%s</span>', registry_key)
  } else {
    ""
  }

  sprintf(
    '<div class="t-callout%s" data-turas-callout="true"%s>
  <div class="t-callout-header" onclick="this.parentElement.classList.toggle(\'collapsed\')">
    <span class="t-callout-icon">i</span>
    <span class="t-callout-title">%s</span>
    %s
    <span class="t-callout-chevron">&#x25BC;</span>
  </div>
  <div class="t-callout-body">%s</div>
</div>',
    collapsed_class, id_attr, title, key_tag, body
  )
}


#' List All Available Callouts
#'
#' Returns a data frame of all registered callouts with module, key,
#' title, and context.
#'
#' @return Data frame with columns: module, key, title, context
#' @export
turas_callout_list <- function() {
  data <- .load_callouts()
  rows <- list()
  for (mod_name in names(data)) {
    mod <- data[[mod_name]]
    for (key_name in names(mod)) {
      entry <- mod[[key_name]]
      rows[[length(rows) + 1]] <- data.frame(
        module = mod_name,
        key = key_name,
        title = entry$title %||% "",
        context = entry$context %||% "",
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0) return(data.frame(
    module = character(), key = character(),
    title = character(), context = character(),
    stringsAsFactors = FALSE
  ))
  do.call(rbind, rows)
}


#' Get Every Callout for One Module
#'
#' Returns the whole `module` block as a named list of entries. Used by
#' consumers that need the entries themselves rather than rendered HTML —
#' notably the Tabs v2 report, which ships the text into the browser and
#' renders it with its own markup.
#'
#' @param module Character. Module name (e.g. "tabs")
#' @return Named list of entries (each with title/text/context/page).
#'   Empty list when the module has no entries.
#' @export
turas_callout_module <- function(module) {
  data <- .load_callouts()
  mod <- data[[module]]
  if (is.null(mod)) list() else mod
}


#' Write the Callout Registry Back to Disk
#'
#' Atomic, with backups. The editor rewrites the WHOLE file on every save, and
#' every Turas module that renders callouts — and, from v2, every Tabs report
#' build — depends on that file parsing. A plain write that dies half way
#' through would leave a truncated registry and break all of them, so the new
#' contents are written to a temporary file in the same directory, parsed back
#' to prove they are valid JSON, and only then moved into place. The move is
#' atomic on the same filesystem, which is why the temp file is a sibling and
#' not in tempdir().
#'
#' @param data List. The complete registry (including `_meta`)
#' @param path Character. Destination; defaults to the resolved registry path
#' @param backups Integer. How many timestamped copies to keep (0 = none)
#' @return Invisibly, the path written
#' @export
turas_callouts_write <- function(data, path = turas_callouts_path(), backups = 10L) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("[REFUSE] PKG_MISSING_DEPENDENCY: jsonlite is required to write the callout registry.",
         call. = FALSE)
  }

  dir <- dirname(path)
  tmp <- file.path(dir, paste0(".", basename(path), ".tmp-", Sys.getpid()))
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)

  jsonlite::write_json(data, tmp, pretty = TRUE, auto_unbox = TRUE)

  # Parse the file we are about to install, not the object we serialised — this
  # is what catches a truncated or partially-flushed write.
  check <- tryCatch(jsonlite::fromJSON(tmp, simplifyVector = FALSE),
                    error = function(e) e)
  if (inherits(check, "error")) {
    stop(sprintf("[REFUSE] IO_CALLOUTS_WRITE: the new registry did not parse back (%s). The existing %s is untouched.",
                 conditionMessage(check), basename(path)), call. = FALSE)
  }

  if (backups > 0 && file.exists(path)) {
    bdir <- file.path(dir, "backups")
    if (!dir.exists(bdir)) dir.create(bdir, showWarnings = FALSE)
    file.copy(path, file.path(bdir, sprintf("callouts-%s.json",
                                            format(Sys.time(), "%Y%m%d-%H%M%S"))),
              overwrite = TRUE)
    kept <- sort(list.files(bdir, pattern = "^callouts-.*\\.json$", full.names = TRUE),
                 decreasing = TRUE)
    if (length(kept) > backups) unlink(kept[(backups + 1L):length(kept)])
  }

  if (!file.rename(tmp, path)) {
    stop(sprintf("[REFUSE] IO_CALLOUTS_WRITE: could not move the new registry into place at %s.", path),
         call. = FALSE)
  }

  .callout_cache$data <- NULL   # next read picks up what was just written
  invisible(path)
}


#' Clear Callout Cache
#'
#' Forces reload of callouts.json on next access.
#' Useful during development when editing the JSON file.
#'
#' @export
turas_callout_clear_cache <- function() {
  .callout_cache$data <- NULL
  invisible(TRUE)
}


# Null-coalescing operator (local)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
