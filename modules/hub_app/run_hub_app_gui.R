# ==============================================================================
# TURAS > HUB APP GUI
# ==============================================================================
# Purpose: Shiny application for the Hub App working environment.
#          Serves HTML reports via addResourcePath, communicates with
#          vanilla JS frontend via custom messages and input bindings.
# Location: modules/hub_app/run_hub_app_gui.R
# ==============================================================================

run_hub_app_gui <- function(project_dirs = NULL) {

  # Null-coalescing operator
  `%||%` <- function(a, b) if (is.null(a)) b else a

  # --- Default directories if none provided ---
  if (is.null(project_dirs) || length(project_dirs) == 0) {
    home <- Sys.getenv("HOME", path.expand("~"))
    project_dirs <- c(
      file.path(home, "Documents"),
      file.path(home, "Desktop")
    )
    # Keep only existing directories
    project_dirs <- project_dirs[dir.exists(project_dirs)]
  }

  # --- Package check (TRS v1.0: no auto-install) ---
  required_packages <- c("shiny", "shinyjs", "shinyFiles", "jsonlite")
  missing_packages <- required_packages[
    !sapply(required_packages, requireNamespace, quietly = TRUE)
  ]
  if (length(missing_packages) > 0) {
    cat("\n┌─── TURAS HUB APP ERROR ───────────────────────────────┐\n")
    cat("│ Code: PKG_MISSING_DEPENDENCY\n")
    cat("│ Missing:", paste(missing_packages, collapse = ", "), "\n")
    cat("│ Fix: install.packages(c(",
        paste(sprintf('"%s"', missing_packages), collapse = ", "), "))\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    return(list(
      status = "REFUSED",
      code = "PKG_MISSING_DEPENDENCY",
      message = sprintf("Missing packages: %s", paste(missing_packages, collapse = ", ")),
      how_to_fix = sprintf(
        "Install with: install.packages(c(%s))",
        paste(sprintf('"%s"', missing_packages), collapse = ", ")
      ),
      context = list(missing = missing_packages)
    ))
  }

  suppressPackageStartupMessages({
    library(shiny)
    library(shinyjs)
    library(shinyFiles)
  })

  # --- Configuration ---
  TURAS_HOME <- Sys.getenv("TURAS_ROOT", getwd())

  # Source dependencies
  source(file.path(TURAS_HOME, "modules", "hub_app", "lib", "project_scanner.R"),
         local = TRUE)
  source(file.path(TURAS_HOME, "modules", "hub_app", "lib", "export_pptx.R"),
         local = TRUE)

  # Load shared GUI theme
  source(file.path(TURAS_HOME, "modules", "shared", "lib", "gui_theme.R"),
         local = TRUE)
  theme <- turas_gui_theme("Hub App", "Browse, Annotate & Export Across Reports")

  # Determine frontend static files path
  app_static_dir <- file.path(TURAS_HOME, "modules", "hub_app", "app")

  # Register static file path BEFORE UI renders (UI iframe references this)
  shiny::addResourcePath("hub-app-static", app_static_dir)
  cat("[Hub App] Frontend served from:", app_static_dir, "\n")

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

        /* Directory chooser bar */
        .hub-dir-bar {
          display: flex;
          align-items: center;
          gap: 10px;
          padding: 8px 24px;
          background: #f1f5f9;
          border-bottom: 1px solid #e2e8f0;
          font-size: 13px;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          color: #64748b;
        }
        .hub-dir-bar .btn {
          display: inline-flex;
          align-items: center;
          gap: 6px;
          padding: 5px 12px;
          font-size: 12px;
          font-weight: 500;
          border: 1px solid #e2e8f0;
          border-radius: 6px;
          background: #fff;
          color: #1e293b;
          cursor: pointer;
        }
        .hub-dir-bar .btn:hover {
          border-color: #94a3b8;
        }
        .hub-dir-path {
          flex: 1;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }
      "))
    ),

    # Header
    theme$header,

    # Directory chooser bar
    div(class = "hub-dir-bar",
      shinyDirButton("hub_dir_choose", "Add Folder",
                     "Choose a folder containing Turas projects",
                     class = "btn"),
      span(class = "hub-dir-path", id = "hub-dir-display",
           if (length(project_dirs) > 0)
             paste("Scanning:", paste(project_dirs, collapse = ", "))
           else
             "No directories configured. Click 'Add Folder' to choose."
      )
    ),

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
          var dirBar = document.querySelector('.hub-dir-bar');
          var headerH = (header ? header.offsetHeight : 0) +
                        (dirBar ? dirBar.offsetHeight : 0);
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

    # --- Reactive state ---
    rv <- reactiveValues(
      projects = list(),
      scan_dirs = project_dirs,
      active_project_path = NULL,
      active_project_reports = list()
    )

    # --- Directory chooser ---
    volumes <- turas_gui_volumes()
    shinyDirChoose(input, "hub_dir_choose", roots = volumes, session = session)

    observeEvent(input$hub_dir_choose, {
      if (is.integer(input$hub_dir_choose)) return()  # User cancelled

      selected <- parseDirPath(volumes, input$hub_dir_choose)
      if (length(selected) == 0 || !nzchar(selected)) return()

      selected <- normalizePath(as.character(selected),
                                 winslash = "/", mustWork = FALSE)
      cat("[Hub App] Directory added:", selected, "\n")

      # Add to scan list (avoid duplicates)
      current <- rv$scan_dirs
      if (!(selected %in% current)) {
        rv$scan_dirs <- c(current, selected)
      }

      # Update display
      shinyjs::html("hub-dir-display",
        paste("Scanning:", paste(rv$scan_dirs, collapse = ", ")))

      # Trigger rescan with new directories
      result <- scan_for_projects(rv$scan_dirs, max_depth = 3)

      if (result$status %in% c("PASS", "PARTIAL")) {
        rv$projects <- result$result$projects
        project_json <- jsonlite::toJSON(
          result$result$projects,
          auto_unbox = TRUE,
          pretty = FALSE
        )
        session$sendCustomMessage("hub_projects", project_json)
        cat("[Hub App]", result$message, "\n")
      } else {
        session$sendCustomMessage("hub_projects", "[]")
      }
    })

    # --- Initial project scan ---
    observe({
      cat("[Hub App] Scanning for projects...\n")
      result <- scan_for_projects(rv$scan_dirs, max_depth = 3)

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
      result <- scan_for_projects(rv$scan_dirs, max_depth = 3)

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

    # --- Handle search ---
    observeEvent(input$hub_search, {
      query <- input$hub_search
      if (is.null(query) || !nzchar(trimws(query))) return()

      tryCatch({
        source(file.path(TURAS_HOME, "modules", "hub_app", "lib",
                          "search_index.R"), local = TRUE)

        # Build index from current projects
        index_result <- build_search_index(rv$projects)
        if (index_result$status != "PASS") {
          session$sendCustomMessage("hub_search_results",
            jsonlite::toJSON(list(query = query, results = list()),
                              auto_unbox = TRUE))
          return()
        }

        # Search
        results <- search_index(index_result$result$index, query)

        response <- jsonlite::toJSON(
          list(query = query, results = results),
          auto_unbox = TRUE, pretty = FALSE
        )
        session$sendCustomMessage("hub_search_results", response)
        cat("[Hub App] Search for '", query, "' returned ",
            length(results), " results\n", sep = "")

      }, error = function(e) {
        cat("[Hub App] Search error:", e$message, "\n")
        session$sendCustomMessage("hub_search_results",
          jsonlite::toJSON(list(query = query, results = list()),
                            auto_unbox = TRUE))
      })
    })

    # --- Handle preferences ---

    observeEvent(input$hub_load_preferences, {
      tryCatch({
        source(file.path(TURAS_HOME, "modules", "hub_app", "lib",
                          "preferences.R"), local = TRUE)
        prefs <- get_hub_preferences()
        pref_json <- jsonlite::toJSON(prefs, auto_unbox = TRUE, pretty = FALSE)
        session$sendCustomMessage("hub_preferences_loaded", pref_json)
      }, error = function(e) {
        cat("[Hub App] ERROR loading preferences:", e$message, "\n")
      })
    })

    observeEvent(input$hub_save_preferences, {
      tryCatch({
        source(file.path(TURAS_HOME, "modules", "hub_app", "lib",
                          "preferences.R"), local = TRUE)
        prefs <- jsonlite::fromJSON(input$hub_save_preferences,
                                     simplifyVector = FALSE)
        result <- save_hub_preferences(prefs)

        if (result$status == "PASS") {
          # If scan directories changed, trigger rescan
          new_dirs <- prefs$scan_directories
          if (!is.null(new_dirs) && length(new_dirs) > 0) {
            existing <- rv$scan_dirs
            all_dirs <- unique(c(existing, unlist(new_dirs)))
            valid_dirs <- all_dirs[dir.exists(all_dirs)]
            if (length(valid_dirs) > length(existing)) {
              rv$scan_dirs <- valid_dirs
              shinyjs::html("hub-dir-display",
                paste("Scanning:", paste(rv$scan_dirs, collapse = ", ")))
              scan_result <- scan_for_projects(rv$scan_dirs, max_depth = 3)
              if (scan_result$status %in% c("PASS", "PARTIAL")) {
                rv$projects <- scan_result$result$projects
                project_json <- jsonlite::toJSON(
                  scan_result$result$projects,
                  auto_unbox = TRUE, pretty = FALSE)
                session$sendCustomMessage("hub_projects", project_json)
              }
            }
          }
        }
      }, error = function(e) {
        cat("[Hub App] ERROR saving preferences:", e$message, "\n")
        session$sendCustomMessage("hub_error",
          paste("Failed to save preferences:", e$message))
      })
    })

    # --- Handle annotation operations ---

    # Save annotations to sidecar JSON
    observeEvent(input$hub_save_annotations, {
      req(rv$active_project_path)
      ann_data <- input$hub_save_annotations

      sidecar_path <- file.path(rv$active_project_path, ".turas_annotations.json")

      tryCatch({
        writeLines(ann_data, sidecar_path, useBytes = TRUE)
        cat("[Hub App] Annotations saved to:", sidecar_path, "\n")
        session$sendCustomMessage("hub_save_annotations_confirm", "annotations")
      }, error = function(e) {
        cat("[Hub App] ERROR saving annotations:", e$message, "\n")
        session$sendCustomMessage("hub_error",
          paste("Failed to save annotations:", e$message))
      })
    })

    # Load annotations from sidecar JSON (triggered when opening a project)
    observeEvent(input$hub_load_annotations, {
      req(rv$active_project_path)

      sidecar_path <- file.path(rv$active_project_path, ".turas_annotations.json")

      if (file.exists(sidecar_path)) {
        tryCatch({
          ann_json <- paste(readLines(sidecar_path, warn = FALSE),
                             collapse = "\n")
          session$sendCustomMessage("hub_annotations_loaded", ann_json)
          cat("[Hub App] Annotations loaded from:", sidecar_path, "\n")
        }, error = function(e) {
          cat("[Hub App] ERROR loading annotations:", e$message, "\n")
          session$sendCustomMessage("hub_annotations_loaded", "null")
        })
      } else {
        session$sendCustomMessage("hub_annotations_loaded", "null")
      }
    })

    # --- Handle hub generation ---
    observeEvent(input$hub_generate_hub, {
      req(rv$active_project_path)

      tryCatch({
        payload <- jsonlite::fromJSON(input$hub_generate_hub,
                                       simplifyVector = FALSE)

        cat("[Hub App] Hub generation requested for:",
            payload$project_name %||% "Unknown", "\n")

        # Source and call the hub generator
        source(file.path(TURAS_HOME, "modules", "hub_app", "lib",
                          "hub_generator.R"), local = TRUE)

        result <- generate_hub_from_project(
          project_path = rv$active_project_path,
          project_name = payload$project_name %||% basename(rv$active_project_path)
        )

        if (result$status %in% c("PASS", "PARTIAL")) {
          response <- jsonlite::toJSON(list(
            success = TRUE,
            path = result$result$output_path,
            filename = basename(result$result$output_path),
            n_reports = result$result$n_reports
          ), auto_unbox = TRUE)
        } else {
          response <- jsonlite::toJSON(list(
            success = FALSE,
            error = result$message
          ), auto_unbox = TRUE)
        }

        session$sendCustomMessage("hub_generate_complete", response)

      }, error = function(e) {
        cat("[Hub App] Hub generation error:", e$message, "\n")
        response <- jsonlite::toJSON(list(
          success = FALSE,
          error = e$message
        ), auto_unbox = TRUE)
        session$sendCustomMessage("hub_generate_complete", response)
      })
    })

    # --- Handle export requests ---

    # PPTX export
    observeEvent(input$hub_export_pptx, {
      req(rv$active_project_path)

      tryCatch({
        payload <- jsonlite::fromJSON(input$hub_export_pptx,
                                       simplifyVector = FALSE)

        cat("[Hub App] PPTX export requested for:",
            payload$project_name %||% "Unknown", "\n")

        # Export to the project directory
        result <- export_pins_to_pptx(
          items = payload$items,
          project_name = payload$project_name %||% "Turas Export",
          output_dir = rv$active_project_path
        )

        if (result$status == "PASS") {
          response <- jsonlite::toJSON(list(
            success = TRUE,
            path = result$result$path,
            filename = result$result$filename
          ), auto_unbox = TRUE)
        } else {
          response <- jsonlite::toJSON(list(
            success = FALSE,
            error = result$message
          ), auto_unbox = TRUE)
        }

        session$sendCustomMessage("hub_export_complete", response)

      }, error = function(e) {
        cat("[Hub App] PPTX export error:", e$message, "\n")
        response <- jsonlite::toJSON(list(
          success = FALSE,
          error = e$message
        ), auto_unbox = TRUE)
        session$sendCustomMessage("hub_export_complete", response)
      })
    })

    # PNG ZIP export
    observeEvent(input$hub_export_pngs_zip, {
      req(rv$active_project_path)

      tryCatch({
        payload <- jsonlite::fromJSON(input$hub_export_pngs_zip,
                                       simplifyVector = FALSE)

        cat("[Hub App] PNG ZIP export requested\n")

        images <- payload$images
        if (is.null(images) || length(images) == 0) {
          session$sendCustomMessage("hub_export_pngs_complete",
            jsonlite::toJSON(list(success = FALSE, error = "No images"),
                              auto_unbox = TRUE))
          return()
        }

        # Check for zip package (base R utils::zip)
        zip_dir <- file.path(tempdir(), "hub_export_pngs")
        if (dir.exists(zip_dir)) unlink(zip_dir, recursive = TRUE)
        dir.create(zip_dir, showWarnings = FALSE)

        # Decode each PNG
        for (img in images) {
          if (!is.null(img$dataUrl) && nzchar(img$dataUrl)) {
            img_path <- file.path(zip_dir, img$filename %||% "pin.png")
            b64 <- sub("^data:image/[^;]+;base64,", "", img$dataUrl)
            raw_bytes <- base64enc::base64decode(b64)
            writeBin(raw_bytes, img_path)
          }
        }

        # Create ZIP
        safe_name <- gsub("[^a-zA-Z0-9_ -]", "",
                           payload$project_name %||% "Turas")
        safe_name <- gsub("\\s+", "_", trimws(safe_name))
        if (nchar(safe_name) == 0) safe_name <- "Turas"

        zip_filename <- paste0(safe_name, "_pins_",
                                format(Sys.time(), "%Y%m%d_%H%M%S"),
                                ".zip")
        zip_path <- file.path(rv$active_project_path, zip_filename)

        png_files <- list.files(zip_dir, full.names = TRUE)
        utils::zip(zip_path, files = png_files, flags = "-j")

        # Clean up
        unlink(zip_dir, recursive = TRUE)

        cat("[Hub App] PNG ZIP saved:", zip_path, "\n")

        response <- jsonlite::toJSON(list(
          success = TRUE,
          path = zip_path,
          filename = zip_filename
        ), auto_unbox = TRUE)
        session$sendCustomMessage("hub_export_pngs_complete", response)

      }, error = function(e) {
        cat("[Hub App] PNG ZIP export error:", e$message, "\n")
        response <- jsonlite::toJSON(list(
          success = FALSE,
          error = e$message
        ), auto_unbox = TRUE)
        session$sendCustomMessage("hub_export_pngs_complete", response)
      })
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
