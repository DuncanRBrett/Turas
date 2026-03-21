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
    # TRS v1.0: Print structured refusal to console then return invisible
    cat("\n================================================================================\n")
    cat("  [REFUSE] PKG_MISSING_DEPENDENCY: Missing Required Packages\n")
    cat("================================================================================\n\n")
    cat("Problem:\n")
    cat(sprintf("  The following required packages are not installed: %s\n\n",
                paste(missing_packages, collapse = ", ")))
    cat("Why it matters:\n")
    cat("  The MaxDiff GUI cannot run without these packages.\n\n")
    cat("How to fix:\n")
    cat(sprintf("  Run the following command in R:\n    install.packages(c(%s))\n\n",
                paste(sprintf('"%s"', missing_packages), collapse = ", ")))
    cat("================================================================================\n")
    return(invisible(list(
      status = "REFUSED",
      code = "PKG_MISSING_DEPENDENCY",
      message = sprintf("Missing packages: %s", paste(missing_packages, collapse = ", ")),
      how_to_fix = sprintf("install.packages(c(%s))",
                           paste(sprintf('"%s"', missing_packages), collapse = ", "))
    )))
  }

  # Load packages
  suppressPackageStartupMessages({
    library(shiny)
    library(shinyFiles)
  })

  # === CONFIGURATION ===

  TURAS_HOME <- Sys.getenv("TURAS_ROOT", getwd())

  # Load shared GUI theme
  source(file.path(TURAS_HOME, "modules", "shared", "lib", "gui_theme.R"))
  theme <- turas_gui_theme("MaxDiff", "Best-Worst Scaling Design & Analysis")
  hide_recents <- turas_hide_recents()

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
    theme$head,
    tags$head(
      tags$style(HTML("
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
          border-color: #4f46e5;
          background: #eef2ff;
        }
      "))
    ),

    # Header
    theme$header,

    # Main content
    div(class = "turas-content",

        # Step 1: Mode Selection
        div(class = "turas-card",
          h3(class = "turas-card-title", "1. Select Mode"),
          fluidRow(
            column(6, actionButton("mode_design", "DESIGN\nGenerate experimental design", class = "mode-btn")),
            column(6, actionButton("mode_analysis", "ANALYSIS\nAnalyze survey responses", class = "mode-btn active"))
          )
        ),

        # Step 2: File Selection
        div(class = "turas-card",
          h3(class = "turas-card-title", "2. Select Configuration File"),
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
          if (!hide_recents) uiOutput("recent_ui")
        ),

        # Step 3: Run Button
        uiOutput("run_ui"),

        # Step 4: Console Output (static UI - always visible)
        div(class = "turas-card",
          h3(class = "turas-card-title", "4. Analysis Output"),
          div(class = "turas-console",
            verbatimTextOutput("console_text")
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

    # Auto-load config from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config) && file.exists(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      rv$config_path <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
    }

    # File chooser volumes
    volumes <- turas_gui_volumes()

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
        div(class = "turas-status-info",
          icon("info-circle"), " No file selected"
        )
      } else {
        div(class = "turas-file-display",
          tags$strong(basename(rv$config_path)),
          tags$br(),
          tags$small(rv$config_path),
          if (file.exists(rv$config_path)) {
            div(class = "turas-status-success", style = "margin-top: 10px;",
              icon("check-circle"), " File found"
            )
          } else {
            div(class = "turas-status-warning", style = "margin-top: 10px;",
              icon("exclamation-triangle"), " File not found"
            )
          }
        )
      }
    })

    # Recent projects
    output$recent_ui <- renderUI({
      if (hide_recents) return(NULL)
      recent <- load_recent()
      recent <- Filter(function(x) file.exists(x$path), recent)
      if (length(recent) == 0) return(NULL)

      div(class = "turas-recent-section",
        tags$hr(),
        h4("Recent Projects"),
        lapply(seq_along(recent), function(i) {
          proj <- recent[[i]]
          tags$div(
            class = "turas-recent-item",
            onclick = sprintf("Shiny.setInputValue('select_recent', %d, {priority: 'event'})", i),
            tags$strong(basename(proj$path)),
            tags$span(style = "float:right; color:#4f46e5;", proj$mode),
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

      div(class = "turas-card",
        h3(class = "turas-card-title", "3. Run MaxDiff"),
        if (!can_run) {
          div(class = "turas-status-warning",
            icon("exclamation-triangle"), " Please select a valid configuration file to continue"
          )
        },
        div(style = "text-align: center; margin: 20px 0;",
          actionButton("run_btn",
                      paste("RUN MAXDIFF", rv$mode),
                      class = "turas-btn-run",
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
