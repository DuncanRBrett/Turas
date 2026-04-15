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

  # --- Load scan directories from saved preferences (or use provided dirs) ---
  if (is.null(project_dirs) || length(project_dirs) == 0) {
    # Load preferences to get saved scan directories
    source(file.path(
      Sys.getenv("TURAS_ROOT", getwd()),
      "modules", "hub_app", "lib", "preferences.R"
    ), local = TRUE)
    saved_prefs <- get_hub_preferences()
    saved_dirs <- unlist(saved_prefs$scan_directories)

    if (!is.null(saved_dirs) && length(saved_dirs) > 0) {
      # Use saved scan directories (keep only existing ones)
      project_dirs <- saved_dirs[dir.exists(saved_dirs)]
      cat("[Hub App] Loaded", length(project_dirs),
          "scan directories from preferences\n")
    } else {
      # First launch — no saved directories, start empty
      project_dirs <- character(0)
      cat("[Hub App] No scan directories configured.",
          "Use Preferences to add folders.\n")
    }
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
  source(file.path(TURAS_HOME, "modules", "hub_app", "lib", "preferences.R"),
         local = TRUE)

  # Helper: safely parse JSON from Shiny input values.
  # jsonlite::fromJSON() auto-detects files vs JSON strings. When a Shiny
  # input value doesn't look like inline JSON, fromJSON tries to open it
  # as a file, which fails. parse_json() always treats input as a string.
  safe_from_json <- function(input_val) {
    if (is.null(input_val)) return(NULL)
    val <- as.character(input_val)
    if (!nzchar(val)) return(NULL)
    jsonlite::parse_json(val, simplifyVector = FALSE)
  }

  # Helper: persist scan directories to preferences file
  save_scan_dirs_to_prefs <- function(dirs, turas_home) {
    tryCatch({
      prefs <- get_hub_preferences()
      prefs$scan_directories <- as.list(dirs)
      save_hub_preferences(prefs)
    }, error = function(e) {
      cat("[Hub App] WARNING: Could not persist scan dirs:", e$message, "\n")
    })
  }

  # Helper: scan with exclusion filtering
  scan_with_exclusions <- function(include_dirs, exclude_dirs, max_depth = 6) {
    result <- scan_for_projects(include_dirs, max_depth = max_depth)
    if (result$status %in% c("PASS", "PARTIAL") && length(exclude_dirs) > 0) {
      norm_exclude <- normalizePath(unlist(exclude_dirs),
                                     winslash = "/", mustWork = FALSE)
      result$result$projects <- Filter(function(p) {
        norm_path <- normalizePath(p$path, winslash = "/", mustWork = FALSE)
        !any(vapply(norm_exclude, function(ex) {
          startsWith(norm_path, paste0(ex, "/")) || norm_path == ex
        }, logical(1)))
      }, result$result$projects)
      result$message <- sprintf("Found %d project(s) after exclusions",
                                 length(result$result$projects))
    }
    result
  }

  # Helper: save a recent view to preferences (FIFO, max 5)
  save_recent_view <- function(include_dirs, exclude_dirs) {
    tryCatch({
      prefs <- get_hub_preferences()
      # Build label from folder names
      label <- paste(basename(include_dirs), collapse = ", ")
      if (nchar(label) > 60) label <- paste0(substr(label, 1, 57), "...")

      view <- list(
        label = label,
        include_dirs = as.list(include_dirs),
        exclude_dirs = as.list(exclude_dirs),
        timestamp = as.numeric(Sys.time())
      )

      # Remove duplicate views (same include+exclude dirs)
      views <- prefs$recent_views %||% list()
      views <- Filter(function(v) {
        !identical(sort(unlist(v$include_dirs)), sort(include_dirs)) ||
        !identical(sort(unlist(v$exclude_dirs)), sort(exclude_dirs))
      }, views)

      # Prepend new view, keep max TURAS_MAX_RECENTS
      views <- c(list(view), views)
      if (length(views) > TURAS_MAX_RECENTS) views <- views[seq_len(TURAS_MAX_RECENTS)]

      prefs$recent_views <- views
      prefs$scan_directories <- as.list(include_dirs)
      prefs$exclude_directories <- as.list(exclude_dirs)
      save_hub_preferences(prefs)
    }, error = function(e) {
      cat("[Hub App] WARNING: Could not save recent view:", e$message, "\n")
    })
  }

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
                     "Choose a folder to scan for projects",
                     class = "btn"),
      shinyDirButton("hub_exclude_dir_choose", "Exclude Folder",
                     "Choose a folder to exclude from scanning",
                     class = "btn"),
      span(class = "hub-dir-path", id = "hub-dir-display",
           "Choose folders to scan, then click Scan for Projects."
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
      exclude_dirs = character(0),
      setup_mode = TRUE,
      active_project_path = NULL,
      active_project_reports = list()
    )

    # --- Directory choosers ---
    volumes <- turas_gui_volumes()
    shinyDirChoose(input, "hub_dir_choose", roots = volumes, session = session)
    shinyDirChoose(input, "hub_exclude_dir_choose", roots = volumes,
                   session = session)

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

      if (rv$setup_mode) {
        # In setup mode: notify frontend, don't auto-scan
        session$sendCustomMessage("hub_dir_picked",
          jsonlite::toJSON(list(type = "include", path = selected),
                            auto_unbox = TRUE))
      } else {
        # Normal mode: persist and rescan
        save_scan_dirs_to_prefs(rv$scan_dirs, TURAS_HOME)
        shinyjs::html("hub-dir-display",
          paste("Scanning:", paste(rv$scan_dirs, collapse = ", ")))

        result <- scan_with_exclusions(rv$scan_dirs, rv$exclude_dirs,
                                        max_depth = 6)
        if (result$status %in% c("PASS", "PARTIAL")) {
          rv$projects <- result$result$projects
          project_json <- jsonlite::toJSON(
            result$result$projects, auto_unbox = TRUE, pretty = FALSE)
          session$sendCustomMessage("hub_projects", project_json)
          cat("[Hub App]", result$message, "\n")
        } else {
          session$sendCustomMessage("hub_projects", "[]")
        }
      }
    })

    # --- Exclude directory chooser ---
    observeEvent(input$hub_exclude_dir_choose, {
      if (is.integer(input$hub_exclude_dir_choose)) return()

      selected <- parseDirPath(volumes, input$hub_exclude_dir_choose)
      if (length(selected) == 0 || !nzchar(selected)) return()

      selected <- normalizePath(as.character(selected),
                                 winslash = "/", mustWork = FALSE)
      cat("[Hub App] Exclude directory added:", selected, "\n")

      # Add to exclude list (avoid duplicates)
      current <- rv$exclude_dirs
      if (!(selected %in% current)) {
        rv$exclude_dirs <- c(current, selected)
      }

      # Notify frontend
      session$sendCustomMessage("hub_dir_picked",
        jsonlite::toJSON(list(type = "exclude", path = selected),
                          auto_unbox = TRUE))
    })

    # --- Handle remove directory ---
    observeEvent(input$hub_remove_dir, {
      dir_to_remove <- input$hub_remove_dir
      if (is.null(dir_to_remove) || !nzchar(dir_to_remove)) return()

      cat("[Hub App] Removing directory:", dir_to_remove, "\n")

      # Find which scan_dir is the parent (or matches)
      current <- rv$scan_dirs
      # Remove any dir that matches or is a parent of the removed path
      new_dirs <- current[!sapply(current, function(d) {
        norm_d <- normalizePath(d, winslash = "/", mustWork = FALSE)
        norm_r <- normalizePath(dir_to_remove, winslash = "/", mustWork = FALSE)
        # Remove if the scan dir IS the folder, or the folder starts with scan dir
        norm_d == norm_r || startsWith(norm_r, paste0(norm_d, "/"))
      })]

      if (length(new_dirs) == length(current)) {
        cat("[Hub App] Folder not in scan roots, rescanning...\n")
      } else {
        rv$scan_dirs <- new_dirs
        # Persist to preferences
        save_scan_dirs_to_prefs(rv$scan_dirs, TURAS_HOME)
        cat("[Hub App] Scan directories now:", paste(new_dirs, collapse = ", "), "\n")
      }

      # Update display
      if (length(rv$scan_dirs) > 0) {
        shinyjs::html("hub-dir-display",
          paste("Scanning:", paste(rv$scan_dirs, collapse = ", ")))
      } else {
        shinyjs::html("hub-dir-display",
          "No directories configured. Click 'Add Folder' to choose.")
      }

      # Rescan
      if (length(rv$scan_dirs) > 0) {
        result <- scan_with_exclusions(rv$scan_dirs, rv$exclude_dirs,
                                        max_depth = 6)
        if (result$status %in% c("PASS", "PARTIAL")) {
          rv$projects <- result$result$projects
          project_json <- jsonlite::toJSON(
            result$result$projects, auto_unbox = TRUE, pretty = FALSE)
          session$sendCustomMessage("hub_projects", project_json)
          cat("[Hub App]", result$message, "\n")
        } else {
          session$sendCustomMessage("hub_projects", "[]")
        }
      } else {
        rv$projects <- list()
        session$sendCustomMessage("hub_projects", "[]")
      }
    })

    # --- Session init: wait for frontend ready, then send preferences ---
    observeEvent(input$hub_frontend_ready, {
      cat("[Hub App] Frontend ready — sending preferences for session setup\n")
      prefs <- get_hub_preferences()
      pref_json <- jsonlite::toJSON(prefs, auto_unbox = TRUE, pretty = FALSE)
      session$sendCustomMessage("hub_session_init", pref_json)
    }, once = TRUE)

    # --- Handle session start from frontend setup screen ---
    observeEvent(input$hub_start_session, {
      # Write diagnostic log to file (visible even without console)
      debug_log <- file.path(TURAS_HOME, ".hub_debug.log")
      tryCatch({
        raw_input <- input$hub_start_session
        cat(format(Sys.time()), "hub_start_session received\n",
            "  class:", paste(class(raw_input), collapse=","), "\n",
            "  typeof:", typeof(raw_input), "\n",
            "  length:", length(raw_input), "\n",
            "  value:", substr(paste(capture.output(str(raw_input)), collapse=" "), 1, 300), "\n",
            file = debug_log, append = TRUE)

        payload <- raw_input
        if (is.null(payload)) {
          session$sendCustomMessage("hub_error",
            "Invalid session data received. Please try again.")
          return()
        }

        # Handle both: list (native Shiny) or string (JSON.stringify)
        if (is.character(payload)) {
          payload <- jsonlite::fromJSON(payload, simplifyVector = FALSE)
        }

        include_dirs <- unlist(payload$include_dirs)
        exclude_dirs <- unlist(payload$exclude_dirs)
        if (is.null(include_dirs)) include_dirs <- character(0)
        if (is.null(exclude_dirs)) exclude_dirs <- character(0)

        if (length(include_dirs) == 0) {
          session$sendCustomMessage("hub_error",
            "No scan directories selected. Add at least one folder.")
          return()
        }

        # Validate directories exist
        valid_include <- include_dirs[dir.exists(include_dirs)]
        valid_exclude <- if (length(exclude_dirs) > 0) {
          exclude_dirs[dir.exists(exclude_dirs)]
        } else character(0)

        if (length(valid_include) == 0) {
          session$sendCustomMessage("hub_error",
            "None of the selected directories exist.")
          return()
        }

        cat("[Hub App] Starting session with", length(valid_include),
            "include dir(s) and", length(valid_exclude), "exclude dir(s)\n")

        rv$scan_dirs <- valid_include
        rv$exclude_dirs <- valid_exclude
        rv$setup_mode <- FALSE

        # Update dir-bar display
        shinyjs::html("hub-dir-display",
          paste("Scanning:", paste(valid_include, collapse = ", ")))

        # Scan
        result <- scan_with_exclusions(valid_include, valid_exclude,
                                        max_depth = 6)
        if (result$status %in% c("PASS", "PARTIAL")) {
          rv$projects <- result$result$projects
          project_json <- jsonlite::toJSON(
            result$result$projects, auto_unbox = TRUE, pretty = FALSE)
          session$sendCustomMessage("hub_projects", project_json)
          cat("[Hub App]", result$message, "\n")
        } else {
          session$sendCustomMessage("hub_projects", "[]")
        }

        # Save this as a recent view
        save_recent_view(valid_include, valid_exclude)

      }, error = function(e) {
        # Write error details to debug log
        cat(format(Sys.time()), "ERROR in hub_start_session:", e$message, "\n",
            "  call:", paste(deparse(e$call), collapse=" "), "\n",
            file = debug_log, append = TRUE)
        cat("[Hub App] Session start error:", e$message, "\n")
        session$sendCustomMessage("hub_error",
          paste("Failed to start session:", e$message))
      })
    })

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
      result <- scan_with_exclusions(rv$scan_dirs, rv$exclude_dirs,
                                      max_depth = 6)

      if (result$status %in% c("PASS", "PARTIAL")) {
        rv$projects <- result$result$projects
        project_json <- jsonlite::toJSON(
          result$result$projects, auto_unbox = TRUE, pretty = FALSE)
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
        prefs <- get_hub_preferences()
        pref_json <- jsonlite::toJSON(prefs, auto_unbox = TRUE, pretty = FALSE)
        session$sendCustomMessage("hub_preferences_loaded", pref_json)
      }, error = function(e) {
        cat("[Hub App] ERROR loading preferences:", e$message, "\n")
      })
    })

    observeEvent(input$hub_save_preferences, {
      tryCatch({
        prefs <- safe_from_json(input$hub_save_preferences)
        result <- save_hub_preferences(prefs)

        if (result$status == "PASS") {
          # Replace scan and exclude directories from saved preferences
          new_dirs <- unlist(prefs$scan_directories)
          new_exclude <- unlist(prefs$exclude_directories)

          if (!is.null(new_dirs) && length(new_dirs) > 0) {
            valid_dirs <- new_dirs[dir.exists(new_dirs)]
            valid_exclude <- if (length(new_exclude) > 0) {
              new_exclude[dir.exists(new_exclude)]
            } else character(0)

            rv$scan_dirs <- valid_dirs
            rv$exclude_dirs <- valid_exclude
            cat("[Hub App] Scan directories updated:",
                paste(valid_dirs, collapse = ", "), "\n")

            if (length(valid_dirs) > 0) {
              shinyjs::html("hub-dir-display",
                paste("Scanning:", paste(rv$scan_dirs, collapse = ", ")))
              scan_result <- scan_with_exclusions(rv$scan_dirs, rv$exclude_dirs,
                                                   max_depth = 6)
              if (scan_result$status %in% c("PASS", "PARTIAL")) {
                rv$projects <- scan_result$result$projects
                project_json <- jsonlite::toJSON(
                  scan_result$result$projects,
                  auto_unbox = TRUE, pretty = FALSE)
                session$sendCustomMessage("hub_projects", project_json)
              } else {
                session$sendCustomMessage("hub_projects", "[]")
              }
            } else {
              shinyjs::html("hub-dir-display",
                "No valid directories. Click 'Add Folder' to choose.")
              session$sendCustomMessage("hub_projects", "[]")
            }
          } else {
            rv$scan_dirs <- character(0)
            rv$exclude_dirs <- character(0)
            shinyjs::html("hub-dir-display",
              "No directories configured. Click 'Add Folder' or use Preferences.")
            session$sendCustomMessage("hub_projects", "[]")
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
        payload <- safe_from_json(input$hub_generate_hub)

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
        payload <- safe_from_json(input$hub_export_pptx)

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
        payload <- safe_from_json(input$hub_export_pngs_zip)

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

    # --- Handle HTML report open in system browser ---
    observeEvent(input$hub_open_html_in_browser, {
      file_path <- input$hub_open_html_in_browser
      if (is.null(file_path) || !nzchar(file_path)) return()

      if (!file.exists(file_path)) {
        cat("[Hub App] ERROR: HTML file not found:", file_path, "\n")
        session$sendCustomMessage("hub_error",
          paste("File not found:", file_path))
        return()
      }

      cat("[Hub App] Opening HTML in browser:", file_path, "\n")
      tryCatch({
        browseURL(paste0("file://",
          normalizePath(file_path, winslash = "/")))
        session$sendCustomMessage("hub_file_opened",
          jsonlite::toJSON(list(success = TRUE,
            filename = basename(file_path)), auto_unbox = TRUE))
      }, error = function(e) {
        cat("[Hub App] ERROR opening HTML:", e$message, "\n")
        session$sendCustomMessage("hub_error",
          paste("Failed to open:", e$message))
      })
    })

    # --- Handle file open requests from frontend ---
    observeEvent(input$hub_open_file, {
      file_path <- input$hub_open_file
      if (is.null(file_path) || !nzchar(file_path)) return()

      if (!file.exists(file_path)) {
        cat("[Hub App] ERROR: File not found:", file_path, "\n")
        session$sendCustomMessage("hub_error",
          paste("File not found:", file_path))
        return()
      }

      cat("[Hub App] Opening file:", file_path, "\n")

      tryCatch({
        os_type <- .Platform$OS.type
        if (Sys.info()["sysname"] == "Darwin") {
          system2("open", shQuote(file_path), wait = FALSE)
        } else if (os_type == "windows") {
          shell.exec(file_path)
        } else {
          system2("xdg-open", shQuote(file_path), wait = FALSE)
        }
        session$sendCustomMessage("hub_file_opened",
          jsonlite::toJSON(list(
            success = TRUE,
            filename = basename(file_path)
          ), auto_unbox = TRUE))
      }, error = function(e) {
        cat("[Hub App] ERROR opening file:", e$message, "\n")
        session$sendCustomMessage("hub_error",
          paste("Failed to open file:", e$message))
      })
    })

    # --- Handle folder open requests ---
    observeEvent(input$hub_open_folder, {
      folder_path <- input$hub_open_folder
      if (is.null(folder_path) || !nzchar(folder_path)) return()

      if (!dir.exists(folder_path)) {
        cat("[Hub App] ERROR: Folder not found:", folder_path, "\n")
        session$sendCustomMessage("hub_error",
          paste("Folder not found:", folder_path))
        return()
      }

      cat("[Hub App] Opening folder:", folder_path, "\n")

      tryCatch({
        if (Sys.info()["sysname"] == "Darwin") {
          system2("open", shQuote(folder_path), wait = FALSE)
        } else if (.Platform$OS.type == "windows") {
          shell.exec(folder_path)
        } else {
          system2("xdg-open", shQuote(folder_path), wait = FALSE)
        }
      }, error = function(e) {
        cat("[Hub App] ERROR opening folder:", e$message, "\n")
        session$sendCustomMessage("hub_error",
          paste("Failed to open folder:", e$message))
      })
    })

    # --- Handle project note save ---
    observeEvent(input$hub_save_project_note, {
      payload <- tryCatch(
        safe_from_json(input$hub_save_project_note),
        error = function(e) NULL
      )
      if (is.null(payload)) return()

      project_path <- payload$path
      note <- payload$note %||% ""

      if (is.null(project_path) || !dir.exists(project_path)) {
        cat("[Hub App] ERROR: Cannot save note, project not found:",
            project_path, "\n")
        return()
      }

      result <- save_project_note(project_path, note)
      if (result$status == "PASS") {
        cat("[Hub App] Project note saved for:", basename(project_path), "\n")
        session$sendCustomMessage("hub_note_saved",
          jsonlite::toJSON(list(
            success = TRUE,
            path = project_path
          ), auto_unbox = TRUE))
      } else {
        session$sendCustomMessage("hub_error", result$message)
      }
    })

    # --- Handle module launch requests ---
    observeEvent(input$hub_launch_module, {
      payload <- tryCatch(
        safe_from_json(input$hub_launch_module),
        error = function(e) NULL
      )
      if (is.null(payload)) return()

      module_id <- payload$module
      config_path <- payload$config_path
      script <- payload$script

      if (is.null(module_id) || is.null(script)) {
        cat("[Hub App] ERROR: Missing module or script in launch request\n")
        session$sendCustomMessage("hub_error",
          "Missing module or script in launch request")
        return()
      }

      turas_root <- Sys.getenv("TURAS_ROOT", getwd())
      script_path <- file.path(turas_root, script)

      if (!file.exists(script_path)) {
        cat("[Hub App] ERROR: Module script not found:", script_path, "\n")
        session$sendCustomMessage("hub_error",
          paste("Module script not found:", script))
        return()
      }

      cat("[Hub App] Launching module:", module_id,
          "with config:", config_path %||% "(none)", "\n")

      tryCatch({
        # Build launch script (same pattern as launch_turas.R)
        config_lines <- ""
        if (!is.null(config_path) && nzchar(config_path)) {
          config_lines <- sprintf(
            'Sys.setenv(TURAS_MODULE_CONFIG = "%s")\n', config_path)
          if (module_id == "report_hub") {
            config_lines <- paste0(config_lines, sprintf(
              'Sys.setenv(TURAS_HUB_CONFIG = "%s")\n', config_path))
          }
        }

        launch_script <- sprintf('
Sys.setenv(TURAS_ROOT = "%s")
Sys.setenv(TURAS_LAUNCHED_FROM_HUB = "1")
%ssetwd("%s")
TURAS_LAUNCHER_ACTIVE <- TRUE
source("%s")
app <- run_%s_gui()
shiny::runApp(app, launch.browser = TRUE)
',
          turas_root,
          config_lines,
          turas_root,
          script_path,
          module_id)

        temp_script <- tempfile(fileext = ".R")
        log_file <- tempfile(fileext = ".log")

        launch_wrapped <- paste0(
          'tryCatch({\n',
          launch_script,
          '}, error = function(e) {\n',
          '  cat("ERROR:", conditionMessage(e), "\\n",',
          ' file = "', log_file, '")\n',
          '})\n'
        )

        writeLines(launch_wrapped, temp_script)

        old_env <- Sys.getenv("TURAS_SKIP_RENV")
        Sys.setenv(TURAS_SKIP_RENV = "1")
        on.exit({
          if (old_env == "") {
            Sys.unsetenv("TURAS_SKIP_RENV")
          } else {
            Sys.setenv(TURAS_SKIP_RENV = old_env)
          }
        }, add = TRUE)

        system2("Rscript",
                args = c(temp_script),
                wait = FALSE,
                stdout = log_file,
                stderr = log_file)

        labels <- get_module_labels()
        module_label <- labels[[module_id]] %||% module_id

        session$sendCustomMessage("hub_module_launched",
          jsonlite::toJSON(list(
            success = TRUE,
            module = module_id,
            label = module_label
          ), auto_unbox = TRUE))

        cat("[Hub App] Module", module_label, "launched in background\n")

      }, error = function(e) {
        cat("[Hub App] ERROR launching module:", e$message, "\n")
        session$sendCustomMessage("hub_error",
          paste("Failed to launch module:", e$message))
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
