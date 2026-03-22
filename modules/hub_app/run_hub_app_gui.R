# ==============================================================================
# TURAS > HUB APP GUI
# ==============================================================================
# Purpose: Shiny application for the Hub App working environment.
#          Serves HTML reports via addResourcePath, communicates with
#          vanilla JS frontend via custom messages and input bindings.
# Location: modules/hub_app/run_hub_app_gui.R
# ==============================================================================

run_hub_app_gui <- function(project_dirs = NULL) {

  # --- Package check (TRS v1.0: no auto-install) ---
  required_packages <- c("shiny", "shinyjs", "jsonlite")
  missing_packages <- required_packages[
    !sapply(required_packages, requireNamespace, quietly = TRUE)
  ]
  if (length(missing_packages) > 0) {
    cat("\n=== TURAS HUB APP ERROR ===\n")
    cat("Code: PKG_MISSING_DEPENDENCY\n")
    cat("Missing:", paste(missing_packages, collapse = ", "), "\n")
    cat("Fix: install.packages(c(",
        paste(sprintf('"%s"', missing_packages), collapse = ", "), "))\n")
    cat("============================\n\n")
    stop(sprintf("Missing packages: %s", paste(missing_packages, collapse = ", ")),
         call. = FALSE)
  }

  suppressPackageStartupMessages({
    library(shiny)
    library(shinyjs)
  })

  # --- Configuration ---
  TURAS_HOME <- Sys.getenv("TURAS_ROOT", getwd())

  # Source dependencies
  source(file.path(TURAS_HOME, "modules", "hub_app", "lib", "project_scanner.R"),
         local = TRUE)

  # Load shared GUI theme
  source(file.path(TURAS_HOME, "modules", "shared", "lib", "gui_theme.R"),
         local = TRUE)
  theme <- turas_gui_theme("Hub App", "Browse, Annotate & Export Across Reports")

  # Determine frontend static files path
  app_static_dir <- file.path(TURAS_HOME, "modules", "hub_app", "app")

  # ============================================================================
  # UI
  # ============================================================================

  ui <- fluidPage(
    useShinyjs(),
    theme$head,

    tags$head(
      # Viewport for proper iframe sizing
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),

      tags$style(HTML("
        /* Hub App fills the viewport below the header */
        body { margin: 0; padding: 0; overflow: hidden; }
        .container-fluid { padding: 0; }
        .turas-content { padding: 0; }

        #hub-app-frame {
          width: 100%;
          border: none;
          display: block;
        }
      "))
    ),

    # Header
    theme$header,

    # Hub App frontend loaded in an iframe (same origin via addResourcePath)
    tags$iframe(
      id = "hub-app-frame",
      src = "/hub-app-static/index.html",
      style = "width: 100%; border: none;",
      allowfullscreen = "true"
    ),

    # Resize script: keep iframe filling available viewport height
    tags$script(HTML("
      (function() {
        function resizeFrame() {
          var frame = document.getElementById('hub-app-frame');
          if (!frame) return;
          var header = document.querySelector('.turas-header');
          var headerH = header ? header.offsetHeight : 0;
          frame.style.height = (window.innerHeight - headerH) + 'px';
        }
        window.addEventListener('resize', resizeFrame);
        window.addEventListener('load', resizeFrame);
        // Also resize after short delay (Shiny rendering)
        setTimeout(resizeFrame, 100);
        setTimeout(resizeFrame, 500);
      })();
    ")),

    # Hidden div for Shiny communication
    div(style = "display:none;",
      textOutput("project_data_out"),
      textOutput("report_list_out")
    )
  )

  # ============================================================================
  # SERVER
  # ============================================================================

  server <- function(input, output, session) {

    # --- Register static file paths ---

    # Serve the Hub App frontend files
    addResourcePath("hub-app-static", app_static_dir)

    cat("[Hub App] Frontend served from:", app_static_dir, "\n")

    # --- Reactive state ---
    rv <- reactiveValues(
      projects = list(),
      active_project_path = NULL,
      active_project_reports = list()
    )

    # --- Initial project scan ---
    observe({
      cat("[Hub App] Scanning for projects...\n")
      result <- scan_for_projects(project_dirs, max_depth = 3)

      if (result$status %in% c("PASS", "PARTIAL")) {
        rv$projects <- result$result$projects
        cat("[Hub App]", result$message, "\n")

        # Send project list to frontend
        project_json <- jsonlite::toJSON(
          result$result$projects,
          auto_unbox = TRUE,
          pretty = FALSE
        )
        session$sendCustomMessage("hub_projects", project_json)
      } else {
        cat("[Hub App] WARNING: Project scan returned no results\n")
        session$sendCustomMessage("hub_projects", "[]")
      }
    }) |> bindEvent(TRUE, once = TRUE)

    # --- Handle project selection from frontend ---
    observeEvent(input$hub_open_project, {
      project_path <- input$hub_open_project

      cat("[Hub App] Opening project:", project_path, "\n")

      if (!dir.exists(project_path)) {
        cat("[Hub App] ERROR: Directory not found:", project_path, "\n")
        session$sendCustomMessage("hub_error", paste(
          "Project directory not found:", project_path
        ))
        return()
      }

      # Register the project directory for report serving
      # Remove previous resource path if any
      tryCatch(
        removeResourcePath("hub-project"),
        error = function(e) NULL
      )
      addResourcePath("hub-project", project_path)
      rv$active_project_path <- project_path

      cat("[Hub App] Serving reports from:", project_path, "\n")

      # Get detailed report list
      result <- get_project_reports(project_path)

      if (result$status == "PASS") {
        rv$active_project_reports <- result$result$reports

        # Send report list to frontend
        # Include the URL prefix for iframe loading
        reports_with_urls <- lapply(result$result$reports, function(r) {
          r$url <- paste0("/hub-project/", r$filename)
          r
        })

        report_json <- jsonlite::toJSON(
          list(
            project_name = result$result$project_name,
            project_path = result$result$project_path,
            reports = reports_with_urls,
            report_count = result$result$report_count
          ),
          auto_unbox = TRUE,
          pretty = FALSE
        )

        session$sendCustomMessage("hub_report_list", report_json)
        cat("[Hub App]", result$message, "\n")
      } else {
        cat("[Hub App] ERROR:", result$message, "\n")
        session$sendCustomMessage("hub_error", result$message)
      }
    })

    # --- Handle rescan request from frontend ---
    observeEvent(input$hub_rescan, {
      cat("[Hub App] Rescanning projects...\n")
      result <- scan_for_projects(project_dirs, max_depth = 3)

      if (result$status %in% c("PASS", "PARTIAL")) {
        rv$projects <- result$result$projects
        project_json <- jsonlite::toJSON(
          result$result$projects,
          auto_unbox = TRUE,
          pretty = FALSE
        )
        session$sendCustomMessage("hub_projects", project_json)
        cat("[Hub App]", result$message, "\n")
      }
    })

    # --- Handle back-to-projects navigation ---
    observeEvent(input$hub_back_to_projects, {
      rv$active_project_path <- NULL
      rv$active_project_reports <- list()
      tryCatch(
        removeResourcePath("hub-project"),
        error = function(e) NULL
      )
      cat("[Hub App] Returned to project browser\n")
    })

    # --- Handle sidecar file operations ---

    # Save pins to sidecar JSON
    observeEvent(input$hub_save_pins, {
      req(rv$active_project_path)
      pin_data <- input$hub_save_pins

      sidecar_path <- file.path(rv$active_project_path, ".turas_pins.json")

      tryCatch({
        writeLines(pin_data, sidecar_path, useBytes = TRUE)
        cat("[Hub App] Pins saved to:", sidecar_path, "\n")
        session$sendCustomMessage("hub_save_confirm", "pins")
      }, error = function(e) {
        cat("[Hub App] ERROR saving pins:", e$message, "\n")
        session$sendCustomMessage("hub_error",
          paste("Failed to save pins:", e$message))
      })
    })

    # Load pins from sidecar JSON
    observeEvent(input$hub_load_pins, {
      req(rv$active_project_path)

      sidecar_path <- file.path(rv$active_project_path, ".turas_pins.json")

      if (file.exists(sidecar_path)) {
        tryCatch({
          pin_json <- paste(readLines(sidecar_path, warn = FALSE),
                            collapse = "\n")
          session$sendCustomMessage("hub_pins_loaded", pin_json)
          cat("[Hub App] Pins loaded from:", sidecar_path, "\n")
        }, error = function(e) {
          cat("[Hub App] ERROR loading pins:", e$message, "\n")
          session$sendCustomMessage("hub_pins_loaded", "null")
        })
      } else {
        session$sendCustomMessage("hub_pins_loaded", "null")
      }
    })

    # --- Cleanup on session end ---
    session$onSessionEnded(function() {
      tryCatch(
        removeResourcePath("hub-project"),
        error = function(e) NULL
      )
      cat("[Hub App] Session ended, resources cleaned up\n")
    })
  }

  # --- Launch ---
  cat("\n[Hub App] Launching Turas Hub App...\n\n")
  shinyApp(ui = ui, server = server)
}
