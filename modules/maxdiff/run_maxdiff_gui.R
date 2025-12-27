# ==============================================================================
# TURAS>MAXDIFF GUI - LAUNCHER
# ==============================================================================
# Purpose: Launch MaxDiff design and analysis GUI
# Location: modules/maxdiff/run_maxdiff_gui.R
# Usage: source("modules/maxdiff/run_maxdiff_gui.R") then run_maxdiff_gui()
# ==============================================================================

run_maxdiff_gui <- function() {

  # Required packages - check availability (TRS v1.0: no auto-install)
  required_packages <- c("shiny", "shinyFiles")

  # Check for missing packages and refuse with clear instructions if any are missing
  missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  if (length(missing_packages) > 0) {
    stop(
      "\n================================================================================\n",
      "  [REFUSE] PKG_MISSING_DEPENDENCY: Missing Required Packages\n",
      "================================================================================\n\n",
      "Problem:\n",
      "  The following required packages are not installed: ", paste(missing_packages, collapse = ", "), "\n\n",
      "Why it matters:\n",
      "  The MaxDiff GUI cannot run without these packages.\n\n",
      "How to fix:\n",
      "  Run the following command in R:\n",
      "    install.packages(c(", paste(sprintf('"%s"', missing_packages), collapse = ", "), "))\n\n",
      "================================================================================\n",
      call. = FALSE
    )
  }

  # Load packages
  suppressPackageStartupMessages({
    library(shiny)
    library(shinyFiles)
  })

  # === CONFIGURATION ===

  TURAS_HOME <- getwd()
  MODULE_DIR <- file.path(TURAS_HOME, "modules", "maxdiff")
  RECENT_FILE <- file.path(TURAS_HOME, ".recent_maxdiff.rds")

  # === HELPER FUNCTIONS ===

  # Early refuse for TRS-compliant errors within GUI context
  early_refuse <- function(code, title, problem, why_it_matters, how_to_fix, details = NULL) {
    msg <- paste0(
      "\n", strrep("=", 80), "\n",
      "  [REFUSE] ", code, ": ", title, "\n",
      strrep("=", 80), "\n\n",
      "Problem:\n  ", problem, "\n\n",
      "Why it matters:\n  ", why_it_matters, "\n\n",
      "How to fix:\n  ", how_to_fix, "\n"
    )
    if (!is.null(details)) {
      msg <- paste0(msg, "\nDetails:\n  ", details, "\n")
    }
    msg <- paste0(msg, "\n", strrep("=", 80), "\n")
    stop(msg, call. = FALSE)
  }

  load_recent <- function() {
    if (file.exists(RECENT_FILE)) {
      tryCatch(readRDS(RECENT_FILE), error = function(e) list())
    } else {
      list()
    }
  }

  save_recent <- function(path, mode) {
    recent <- load_recent()
    recent <- c(list(list(path = path, mode = mode)), recent)
    recent <- recent[!duplicated(sapply(recent, `[[`, "path"))]
    if (length(recent) > 5) recent <- recent[1:5]
    tryCatch(saveRDS(recent, RECENT_FILE), error = function(e) NULL)
  }

  # ==============================================================================
  # SHINY UI
  # ==============================================================================

  ui <- fluidPage(
    tags$head(
      tags$style(HTML("
        .main-header {
          background: linear-gradient(135deg, #8b5cf6 0%, #6d28d9 100%);
          color: white;
          padding: 30px;
          border-radius: 10px;
          margin-bottom: 20px;
        }
        .card {
          background: white;
          border-radius: 10px;
          padding: 20px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          margin-bottom: 20px;
        }
        .status-success {
          background-color: #f0fff4;
          border-left: 4px solid #48bb78;
          padding: 15px;
          margin: 10px 0;
        }
        .status-info {
          background-color: #e7f3ff;
          border-left: 4px solid #3182ce;
          padding: 15px;
          margin: 10px 0;
        }
        .status-warning {
          background-color: #fffaf0;
          border-left: 4px solid #ed8936;
          padding: 15px;
          margin: 10px 0;
        }
        .btn-primary {
          background: #8b5cf6;
          border: none;
        }
        .btn-primary:hover {
          background: #7c3aed;
        }
        .btn-run {
          background: linear-gradient(135deg, #8b5cf6 0%, #6d28d9 100%);
          border: none;
          color: white;
          font-weight: 700;
          padding: 16px 40px;
          font-size: 18px;
          border-radius: 10px;
        }
        .file-display {
          background: #f7fafc;
          padding: 15px;
          border-radius: 8px;
          margin: 15px 0;
        }
        .console-output {
          background: #1a202c;
          color: #e2e8f0;
          padding: 20px;
          border-radius: 8px;
          font-family: monospace;
          font-size: 13px;
          max-height: 500px;
          overflow-y: auto;
          white-space: pre-wrap;
        }
        .recent-project-item {
          padding: 10px;
          margin: 5px 0;
          background: #f7fafc;
          border-radius: 5px;
          cursor: pointer;
          border: 1px solid #e2e8f0;
        }
        .recent-project-item:hover {
          background: #edf2f7;
          border-color: #8b5cf6;
        }
        .file-label {
          font-weight: 600;
          color: #2d3748;
          margin-top: 10px;
        }
        .mode-btn {
          padding: 15px;
          border: 2px solid #e5e7eb;
          border-radius: 8px;
          background: white;
          margin: 5px;
          cursor: pointer;
          width: 100%;
        }
        .mode-btn.active {
          border-color: #8b5cf6;
          background: #f3e8ff;
        }
      "))
    ),

    # Header
    div(class = "main-header",
      h1("TURAS>MAXDIFF"),
      p("Best-Worst Scaling Design & Analysis"),
      p(style = "font-size: 14px; opacity: 0.9;",
        "Part of Turas Analytics Toolkit")
    ),

    # Main content
    fluidRow(
      column(12,

        # Step 1: Mode Selection
        div(class = "card",
          h3("1. Select Mode"),
          fluidRow(
            column(6, actionButton("mode_design", "DESIGN\nGenerate experimental design", class = "mode-btn")),
            column(6, actionButton("mode_analysis", "ANALYSIS\nAnalyze survey responses", class = "mode-btn active"))
          )
        ),

        # Step 2: File Selection
        div(class = "card",
          h3("2. Select Configuration File"),
          p(style = "color: #666; font-size: 14px;",
            "Select your MaxDiff configuration Excel file"),

          div(class = "file-label", "MaxDiff Configuration:"),
          div(style = "display: inline-block; margin-right: 10px;",
            shinyFilesButton("config_btn",
                          "Browse for config.xlsx",
                          "Select MaxDiff config file",
                          class = "btn btn-primary",
                          icon = icon("file-excel"),
                          multiple = FALSE)
          ),
          uiOutput("config_display"),
          uiOutput("recent_ui")
        ),

        # Step 3: Run Button
        uiOutput("run_ui"),

        # Step 4: Console Output (static UI - always visible)
        div(class = "card",
          h3("4. Analysis Output"),
          div(class = "console-output",
            verbatimTextOutput("console_text")
          )
        )
      )
    )
  )

  # ==============================================================================
  # SHINY SERVER
  # ==============================================================================

  server <- function(input, output, session) {

    # Reactive values
    rv <- reactiveValues(
      mode = "ANALYSIS",
      config_path = NULL
    )

    console_output <- reactiveVal("")
    is_running <- reactiveVal(FALSE)

    # File chooser volumes
    volumes <- c(Home = "~", Documents = "~/Documents", Desktop = "~/Desktop")

    shinyFileChoose(input, "config_btn", roots = volumes, session = session,
                   filetypes = c("", "xlsx", "xls"))

    # Handle config file selection
    observeEvent(input$config_btn, {
      tryCatch({
        if (!is.integer(input$config_btn)) {
          file_path <- parseFilePaths(volumes, input$config_btn)
          if (nrow(file_path) > 0) {
            # Expand tilde and normalize path (fixes OneDrive/home directory paths)
            file_path_expanded <- normalizePath(path.expand(as.character(file_path$datapath[1])),
                                                winslash = "/", mustWork = FALSE)
            rv$config_path <- file_path_expanded
          }
        }
      }, error = function(e) {
        showNotification(paste("Error selecting file:", e$message), type = "error")
      })
    })

    # Mode buttons
    observeEvent(input$mode_design, {
      rv$mode <- "DESIGN"
      # Note: updateActionButton doesn't support class parameter
      # Button styling is handled by CSS based on rv$mode
    })

    observeEvent(input$mode_analysis, {
      rv$mode <- "ANALYSIS"
      # Note: updateActionButton doesn't support class parameter
      # Button styling is handled by CSS based on rv$mode
    })

    # Handle recent project selection
    observeEvent(input$select_recent, {
      req(input$select_recent)
      recent <- load_recent()
      if (input$select_recent <= length(recent)) {
        proj <- recent[[input$select_recent]]
        # Expand tilde and normalize path (fixes OneDrive/home directory paths)
        config_path_expanded <- normalizePath(path.expand(proj$path),
                                              winslash = "/", mustWork = FALSE)
        rv$config_path <- config_path_expanded
        rv$mode <- proj$mode
        # Note: updateActionButton doesn't support class parameter
        # Button styling is handled by CSS based on rv$mode
      }
    })

    # Display config file
    output$config_display <- renderUI({
      if (is.null(rv$config_path)) {
        div(class = "status-info",
          icon("info-circle"), " No file selected"
        )
      } else {
        div(class = "file-display",
          tags$strong(basename(rv$config_path)),
          tags$br(),
          tags$small(rv$config_path),
          if (file.exists(rv$config_path)) {
            div(class = "status-success", style = "margin-top: 10px;",
              icon("check-circle"), " File found"
            )
          } else {
            div(class = "status-warning", style = "margin-top: 10px;",
              icon("exclamation-triangle"), " File not found"
            )
          }
        )
      }
    })

    # Recent projects
    output$recent_ui <- renderUI({
      recent <- load_recent()
      recent <- Filter(function(x) file.exists(x$path), recent)
      if (length(recent) == 0) return(NULL)

      div(
        tags$hr(),
        h4("Recent Projects"),
        lapply(seq_along(recent), function(i) {
          proj <- recent[[i]]
          tags$div(
            class = "recent-project-item",
            onclick = sprintf("Shiny.setInputValue('select_recent', %d, {priority: 'event'})", i),
            tags$strong(basename(proj$path)),
            tags$span(style = "float:right; color:#8b5cf6;", proj$mode),
            tags$br(),
            tags$small(style = "color: #666;", dirname(proj$path))
          )
        })
      )
    })

    # Run button UI
    output$run_ui <- renderUI({
      if (is.null(rv$config_path)) return(NULL)

      can_run <- !is.null(rv$config_path) && file.exists(rv$config_path)

      div(class = "card",
        h3("3. Run MaxDiff"),
        if (!can_run) {
          div(class = "status-warning",
            icon("exclamation-triangle"), " Please select a valid configuration file to continue"
          )
        },
        div(style = "text-align: center; margin: 20px 0;",
          actionButton("run_btn",
                      paste("RUN MAXDIFF", rv$mode),
                      class = "btn-run",
                      icon = icon("play-circle"),
                      disabled = !can_run || is_running())
        )
      )
    })

    # Console output - static UI, always present
    output$console_text <- renderText({
      current_output <- console_output()

      # Ensure single string for R 4.2+ compatibility
      # If vector, collapse it; if empty/NULL, return placeholder
      if (is.null(current_output) || length(current_output) == 0 || nchar(current_output[1]) == 0) {
        "Console output will appear here when you run MaxDiff..."
      } else {
        # Ensure it's a single string
        if (length(current_output) > 1) {
          paste(current_output, collapse = "\n")
        } else {
          current_output
        }
      }
    })

    # Run analysis
    observeEvent(input$run_btn, {
      req(rv$config_path)

      is_running(TRUE)

      # Clear previous console output
      console_output("")

      # Create progress indicator
      progress <- Progress$new(session)
      progress$set(message = paste("Running MaxDiff", rv$mode), value = 0)
      on.exit(progress$close())

      # Save current working directory
      old_wd <- getwd()

      tryCatch({
        config_path <- rv$config_path
        config_path <- normalizePath(config_path, mustWork = FALSE)

        progress$set(value = 0.1, detail = "Validating inputs...")

        if (!is.character(config_path) || length(config_path) != 1) {
          early_refuse(
            code = "CFG_INVALID_PATH",
            title = "Invalid Configuration Path",
            problem = "The config path is not a valid single character string",
            why_it_matters = "MaxDiff analysis requires a valid path to the configuration file",
            how_to_fix = "Select a configuration file using the file browser"
          )
        }

        if (!file.exists(config_path)) {
          early_refuse(
            code = "IO_CONFIG_NOT_FOUND",
            title = "Configuration File Not Found",
            problem = sprintf("Config file does not exist: %s", config_path),
            why_it_matters = "MaxDiff analysis cannot proceed without the configuration file",
            how_to_fix = "Verify the file path is correct and the file exists"
          )
        }

        progress$set(value = 0.2, detail = "Loading MaxDiff module...")
        setwd(MODULE_DIR)
        source(file.path("R", "00_main.R"))

        progress$set(value = 0.3, detail = "Running analysis...")

        # Capture output
        output_capture_file <- tempfile()
        sink(output_capture_file, type = "output")

        result <- tryCatch({
          run_maxdiff(config_path = config_path, verbose = TRUE)
        }, finally = {
          sink(type = "output")
        })

        progress$set(value = 0.9, detail = "Finalizing...")

        # Read captured output
        captured_output <- readLines(output_capture_file, warn = FALSE)
        unlink(output_capture_file)

        # Display captured output
        if (length(captured_output) > 0) {
          console_output(paste(captured_output, collapse = "\n"))
        } else {
          console_output("MaxDiff completed but produced no console output.")
        }

        # Save to recent
        save_recent(config_path, rv$mode)

        # Update console with completion message
        out_path <- if (!is.null(result$output_path)) result$output_path else "output folder"
        console_output(paste0(
          console_output(),
          sprintf("\n%s\n✓ MAXDIFF %s COMPLETE\n%s\n", strrep("=", 80), rv$mode, strrep("=", 80)),
          sprintf("\nOutput saved to:\n%s\n", out_path)
        ))

        progress$set(value = 1.0, detail = "Complete!")
        showNotification("MaxDiff completed successfully!", type = "message", duration = 5)

      }, error = function(e) {
        error_msg <- paste0(strrep("=", 80), "\nERROR: ", e$message, "\n", strrep("=", 80))
        console_output(paste0(console_output(), "\n\n", error_msg))
        showNotification(paste("Error:", e$message), type = "error", duration = 10)

      }, finally = {
        setwd(old_wd)
        is_running(FALSE)
      })
    })
  }

  # Launch
  cat("\nLaunching Turas>MaxDiff GUI...\n\n")

  # Set error logging
  options(shiny.error = function() {
    log_file <- file.path(tempdir(), "maxdiff_gui_error.log")
    tryCatch({
      cat("MAXDIFF GUI ERROR\n", file = log_file)
      cat("================================================================================\n", file = log_file, append = TRUE)
      cat("Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", file = log_file, append = TRUE)
      cat("Error:", geterrmessage(), "\n\n", file = log_file, append = TRUE)
      cat("Traceback:\n", file = log_file, append = TRUE)
      cat(paste(capture.output(traceback()), collapse = "\n"), file = log_file, append = TRUE)
      cat("\n================================================================================\n", file = log_file, append = TRUE)
      cat("\n\nError log written to:", log_file, "\n")
    }, error = function(e) {})
  })

  shinyApp(ui = ui, server = server)
}
