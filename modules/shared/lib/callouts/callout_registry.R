# ==============================================================================
# TURAS CALLOUT REGISTRY
# ==============================================================================
# Centralised lookup for all educational callout text across Turas modules.
# Callout text is stored in callouts.json (same directory) and can be
# edited there without touching any module code.
#
# FUNCTIONS:
# - turas_callout()      - Get a single callout as styled HTML
# - turas_callout_text() - Get raw callout data (title + text)
# - turas_callout_html() - Build callout HTML with standard styling
#
# VERSION: 1.0.0
# ==============================================================================


# --- Internal: load and cache the callout registry ---
.callout_cache <- new.env(parent = emptyenv())

.load_callouts <- function() {
  if (!is.null(.callout_cache$data)) return(.callout_cache$data)

  json_path <- file.path(
    dirname(sys.frame(1)$ofile %||% ""),
    "callouts.json"
  )

  # Fallback paths (TURAS_ROOT-aware for Shiny / test environments)
  if (!file.exists(json_path)) {
    tr <- Sys.getenv("TURAS_ROOT", "")
    candidates <- c(
      if (nzchar(tr)) file.path(tr, "modules", "shared", "lib", "callouts", "callouts.json") else NULL,
      file.path("modules", "shared", "lib", "callouts", "callouts.json"),
      file.path("..", "modules", "shared", "lib", "callouts", "callouts.json")
    )
    for (cand in candidates) {
      if (file.exists(cand)) {
        json_path <- cand
        break
      }
    }
  }

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
