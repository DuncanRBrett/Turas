# ==============================================================================
# TURAS > HUB APP — Cross-Project Search Index
# ==============================================================================
# Purpose: Build and query a simple in-memory search index across all
#          discovered projects. Indexes report titles, pin titles, insights,
#          question codes, and sidecar content.
# Location: modules/hub_app/lib/search_index.R
# ==============================================================================

#' Build Search Index from Projects
#'
#' Scans all discovered projects and builds a flat list of searchable items.
#' Each item has: project_name, project_path, source (report filename or "pins"),
#' title, snippet, type ("report" | "pin" | "section" | "annotation").
#'
#' @param projects List of project objects (from scan_for_projects)
#' @return TRS-compliant list with status and index (list of searchable items)
#'
#' @export
build_search_index <- function(projects) {

  if (is.null(projects) || length(projects) == 0) {
    return(list(
      status = "PASS",
      result = list(index = list(), project_count = 0, item_count = 0),
      message = "No projects to index"
    ))
  }

  index <- list()

  for (proj in projects) {
    proj_name <- proj$name %||% basename(proj$path)
    proj_path <- proj$path

    # Index each report's metadata
    for (report in (proj$reports %||% list())) {
      index[[length(index) + 1]] <- list(
        type = "report",
        project_name = proj_name,
        project_path = proj_path,
        source = report$filename %||% "",
        title = report$label %||% report$filename %||% "",
        snippet = sprintf("%s report (%s)",
          report$type %||% "unknown",
          report$size_label %||% ""),
        report_type = report$type %||% ""
      )
    }

    # Index pins from sidecar if it exists
    sidecar_path <- file.path(proj_path, ".turas_pins.json")
    if (file.exists(sidecar_path)) {
      tryCatch({
        pin_data <- jsonlite::fromJSON(sidecar_path, simplifyVector = FALSE)

        for (pin in (pin_data$pins %||% list())) {
          index[[length(index) + 1]] <- list(
            type = "pin",
            project_name = proj_name,
            project_path = proj_path,
            source = pin$sourceLabel %||% pin$source %||% "",
            title = pin$title %||% "Untitled pin",
            snippet = truncate_text(
              pin$insight %||% pin$insightText %||% pin$subtitle %||% "", 120),
            pin_id = pin$id %||% ""
          )
        }

        for (sec in (pin_data$sections %||% list())) {
          index[[length(index) + 1]] <- list(
            type = "section",
            project_name = proj_name,
            project_path = proj_path,
            source = "pins",
            title = sec$title %||% "Section",
            snippet = ""
          )
        }
      }, error = function(e) {
        # Skip malformed sidecar files silently
      })
    }

    # Index annotations from sidecar
    ann_path <- file.path(proj_path, ".turas_annotations.json")
    if (file.exists(ann_path)) {
      tryCatch({
        ann_data <- jsonlite::fromJSON(ann_path, simplifyVector = FALSE)

        if (nzchar(ann_data$executive_summary %||% "")) {
          index[[length(index) + 1]] <- list(
            type = "annotation",
            project_name = proj_name,
            project_path = proj_path,
            source = "Executive Summary",
            title = paste(proj_name, "- Executive Summary"),
            snippet = truncate_text(ann_data$executive_summary, 120)
          )
        }

        if (nzchar(ann_data$background %||% "")) {
          index[[length(index) + 1]] <- list(
            type = "annotation",
            project_name = proj_name,
            project_path = proj_path,
            source = "Background",
            title = paste(proj_name, "- Background"),
            snippet = truncate_text(ann_data$background, 120)
          )
        }
      }, error = function(e) {
        # Skip silently
      })
    }
  }

  list(
    status = "PASS",
    result = list(
      index = index,
      project_count = length(projects),
      item_count = length(index)
    ),
    message = sprintf("Indexed %d items across %d projects",
                       length(index), length(projects))
  )
}


#' Search the Index
#'
#' Performs case-insensitive substring matching across title, snippet,
#' source, and project_name fields.
#'
#' @param index List of searchable items (from build_search_index)
#' @param query Character string to search for
#' @param max_results Maximum results to return (default: 50)
#'
#' @return List of matching items with match_field indicator
#'
#' @export
search_index <- function(index, query, max_results = 50) {

  if (is.null(query) || !nzchar(trimws(query))) {
    return(list())
  }

  query_lower <- tolower(trimws(query))
  results <- list()

  for (item in index) {
    # Search across all text fields
    fields <- list(
      title = tolower(item$title %||% ""),
      snippet = tolower(item$snippet %||% ""),
      source = tolower(item$source %||% ""),
      project = tolower(item$project_name %||% "")
    )

    matched_field <- NULL
    for (fname in names(fields)) {
      if (grepl(query_lower, fields[[fname]], fixed = TRUE)) {
        matched_field <- fname
        break
      }
    }

    if (!is.null(matched_field)) {
      item$match_field <- matched_field
      results[[length(results) + 1]] <- item

      if (length(results) >= max_results) break
    }
  }

  results
}


#' Truncate Text to a Maximum Length
#'
#' @param text Character string
#' @param max_len Maximum character length
#' @return Truncated string with "..." if needed
#' @keywords internal
truncate_text <- function(text, max_len = 120) {
  if (is.null(text)) return("")
  text <- gsub("\\s+", " ", trimws(text))
  # Strip markdown formatting for snippets
  text <- gsub("\\*\\*(.+?)\\*\\*", "\\1", text)
  text <- gsub("\\*(.+?)\\*", "\\1", text)
  text <- gsub("^##\\s+", "", text)
  text <- gsub("^>\\s+", "", text)
  text <- gsub("^-\\s+", "", text)

  if (nchar(text) > max_len) {
    paste0(substr(text, 1, max_len - 3), "...")
  } else {
    text
  }
}


#' Null-coalescing operator (local)
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a
