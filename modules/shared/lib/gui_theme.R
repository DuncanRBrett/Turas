# ==============================================================================
# TURAS GUI Theme Helper
# ==============================================================================
# Provides shared header and CSS for all module GUIs.
# Usage:
#   source(file.path(turas_root, "modules/shared/lib/gui_theme.R"))
#   theme <- turas_gui_theme("Tabs", "Cross-tabulation & Statistical Testing")
#   # In UI: theme$head, theme$header
# ==============================================================================

#' Build Turas GUI theme elements
#'
#' Returns a list with $head (tags$head for CSS) and $header (header div).
#'
#' @param module_name Display name for the header (e.g., "Tabs", "Tracker")
#' @param module_subtitle One-line description shown below title
#' @return list with $head and $header
turas_gui_theme <- function(module_name, module_subtitle = NULL) {
  # Locate CSS file
  turas_root <- Sys.getenv("TURAS_ROOT", getwd())
  css_path <- file.path(turas_root, "modules", "shared", "turas_gui_theme.css")

  # Read CSS as inline style (works across Rscript child launches)
  css_text <- if (file.exists(css_path)) {
    paste(readLines(css_path, warn = FALSE), collapse = "\n")
  } else {
    ""
  }

  # Build header HTML
  header <- shiny::tags$div(class = "turas-header",
    shiny::tags$div(class = "turas-header-inner",
      shiny::tags$div(
        shiny::tags$span(class = "turas-header-title",
          paste0("TURAS > ", toupper(module_name))),
        if (!is.null(module_subtitle)) {
          shiny::tags$div(class = "turas-header-subtitle", module_subtitle)
        }
      ),
      shiny::tags$span(class = "turas-header-meta", "Part of Turas Analytics Toolkit")
    )
  )

  list(
    head = shiny::tags$head(shiny::tags$style(shiny::HTML(css_text))),
    header = header
  )
}


#' Check if module was launched from the Turas hub
#'
#' Returns TRUE when TURAS_LAUNCHED_FROM_HUB env var is set.
#' Modules should use this to hide their recent projects section
#' since the launcher already provides that functionality.
#'
#' @return logical
turas_hide_recents <- function() {
  val <- Sys.getenv("TURAS_LAUNCHED_FROM_HUB", "")
  if (nzchar(val)) {
    Sys.unsetenv("TURAS_LAUNCHED_FROM_HUB")
    return(TRUE)
  }
  FALSE
}
