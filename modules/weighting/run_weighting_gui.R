# ==============================================================================
# TURAS WEIGHTING MODULE - SHINY GUI
# ==============================================================================
#
# Version: 1.0
# Date: 2025-12-24
#
# DESCRIPTION:
# Graphical user interface for the weighting module.
# Provides point-and-click access to weight calculation.
#
# USAGE:
#   source("modules/weighting/run_weighting_gui.R")
#   run_weighting_gui()
#
# ==============================================================================

library(shiny)
library(shinyFiles)

#' Run Weighting Module GUI
#'
#' Launches the Shiny interface for weight calculation.
#'
#' @param launch_browser Logical, open in browser (default: TRUE)
#' @export
run_weighting_gui <- function(launch_browser = TRUE) {

  # Get module directory
  module_dir <- tryCatch({
    if (!is.null(sys.frame(1)$ofile)) {
      dirname(sys.frame(1)$ofile)
    } else {
      # Fallback methods
      if (file.exists("run_weighting_gui.R")) {
        getwd()
      } else if (file.exists("modules/weighting/run_weighting_gui.R")) {
        file.path(getwd(), "modules/weighting")
      } else {
        getwd()
      }
    }
  }, error = function(e) getwd())

  # Find TURAS root for shared utilities
  turas_root <- tryCatch({
    root <- Sys.getenv("TURAS_ROOT", "")
    if (nzchar(root) && dir.exists(file.path(root, "modules"))) {
      root
    } else {
      # Try to find from module directory
      check <- dirname(dirname(module_dir))
      if (dir.exists(file.path(check, "modules", "shared"))) {
        check
      } else {
        NULL
      }
    }
  }, error = function(e) NULL)

  # Source shared console capture for TRS compliance (no silent failures in GUI)
  if (!is.null(turas_root)) {
    console_capture_file <- file.path(turas_root, "modules", "shared", "lib", "console_capture.R")
    if (file.exists(console_capture_file)) {
      source(console_capture_file, local = FALSE)
    }
  }

  # Source module libraries
  lib_dir <- file.path(module_dir, "lib")
  if (dir.exists(lib_dir)) {
    lib_files <- c("00_guard.R", "validation.R", "config_loader.R",
                   "design_weights.R", "rim_weights.R", "trimming.R",
                   "diagnostics.R", "output.R")
    for (f in lib_files) {
      lib_path <- file.path(lib_dir, f)
      if (file.exists(lib_path)) {
        source(lib_path, local = FALSE)
      }
    }
  }

  # Source main run file
  main_file <- file.path(module_dir, "run_weighting.R")
  if (file.exists(main_file)) {
    source(main_file, local = FALSE)
  }

  # ===========================================================================
  # UI DEFINITION
  # ===========================================================================
  ui <- fluidPage(

    # Custom CSS
    tags$head(
      tags$style(HTML("
        body {
          background-color: #f8f9fa;
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        .main-container {
          max-width: 900px;
          margin: 30px auto;
          padding: 30px;
          background-color: white;
          border-radius: 10px;
          box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
          text-align: center;
          margin-bottom: 30px;
          padding-bottom: 20px;
          border-bottom: 2px solid #4a90d9;
        }
        .header h1 {
          color: #2c3e50;
          margin-bottom: 5px;
        }
        .header p {
          color: #7f8c8d;
          font-size: 14px;
        }
        .section-title {
          color: #2c3e50;
          font-size: 18px;
          font-weight: 600;
          margin-top: 25px;
          margin-bottom: 15px;
          padding-bottom: 8px;
          border-bottom: 1px solid #e0e0e0;
        }
        .btn-primary {
          background-color: #4a90d9;
          border-color: #4a90d9;
          padding: 12px 30px;
          font-size: 16px;
          font-weight: 600;
        }
        .btn-primary:hover {
          background-color: #3a7fc8;
          border-color: #3a7fc8;
        }
        .results-box {
          background-color: #f8f9fa;
          border: 1px solid #dee2e6;
          border-radius: 6px;
          padding: 20px;
          margin-top: 20px;
        }
        .status-success {
          color: #28a745;
          font-weight: 600;
        }
        .status-error {
          color: #dc3545;
          font-weight: 600;
        }
        .status-warning {
          color: #ffc107;
          font-weight: 600;
        }
        .log-output {
          font-family: 'Consolas', 'Monaco', monospace;
          font-size: 12px;
          background-color: #1e1e1e;
          color: #d4d4d4;
          padding: 15px;
          border-radius: 6px;
          max-height: 400px;
          overflow-y: auto;
          white-space: pre-wrap;
        }
        .help-text {
          color: #6c757d;
          font-size: 12px;
          margin-top: 5px;
        }
        .summary-table {
          width: 100%;
          border-collapse: collapse;
          margin-top: 15px;
        }
        .summary-table th, .summary-table td {
          padding: 10px;
          text-align: left;
          border-bottom: 1px solid #dee2e6;
        }
        .summary-table th {
          background-color: #f8f9fa;
          font-weight: 600;
        }
        .metric-good { color: #28a745; }
        .metric-acceptable { color: #ffc107; }
        .metric-poor { color: #dc3545; }
        .shiny-notification {
          position: fixed;
          top: calc(50% - 100px);
          left: calc(50% - 200px);
          width: 400px;
        }
        .progress {
          height: 25px;
          border-radius: 6px;
          margin-bottom: 10px;
        }
        .progress-bar {
          font-size: 14px;
          line-height: 25px;
          font-weight: 600;
        }
        .shiny-progress .progress-text {
          font-size: 14px;
          font-weight: 500;
        }
      "))
    ),

    div(class = "main-container",

      # Header
      div(class = "header",
        h1("TURAS Weighting Module"),
        p("Calculate survey weights using design or rim weighting methods")
      ),

      # Folder Selection
      div(class = "section-title", "1. Select Project Folder"),

      # Recent folders dropdown
      conditionalPanel(
        condition = "output.has_recent_folders",
        selectInput("recent_folder", "Recent Folders",
                    choices = NULL,
                    width = "100%"),
        div(class = "help-text", style = "margin-top: -10px; margin-bottom: 15px;",
            "Select from recently used folders or browse/enter path below")
      ),

      # Folder path with browse button
      fluidRow(
        column(9,
          textInput("project_folder", "Project Folder Path",
                    placeholder = "e.g., /Users/duncan/Documents/Turas/modules/weighting/examples/example2_rim_weights",
                    width = "100%")
        ),
        column(3,
          div(style = "margin-top: 25px;",
            shinyDirButton("folder_browse", "Browse...",
                         title = "Select project folder",
                         class = "btn btn-default")
          )
        )
      ),
      div(class = "help-text",
          "Select or enter the folder path containing your Weight_Config.xlsx and data file"),

      textInput("config_filename", "Config File Name",
                value = "Weight_Config.xlsx",
                width = "100%"),
      div(class = "help-text",
          "Name of the config file in the folder above"),

      # Options Section
      div(class = "section-title", "2. Options"),

      fluidRow(
        column(6,
          checkboxInput("save_output", "Save weighted data to file", value = TRUE)
        ),
        column(6,
          checkboxInput("save_diagnostics", "Save diagnostic report", value = TRUE)
        )
      ),

      # Run Button
      div(style = "text-align: center; margin-top: 30px;",
        actionButton("run_weighting", "Calculate Weights",
                    class = "btn btn-primary",
                    icon = icon("calculator"))
      ),

      # Progress Section
      div(class = "section-title", "3. Progress"),
      verbatimTextOutput("progress_log"),

      # Results Section
      conditionalPanel(
        condition = "output.has_results",
        div(class = "section-title", "4. Results"),
        div(class = "results-box",
          uiOutput("results_summary")
        ),

        div(class = "section-title", "Weight Diagnostics"),
        tableOutput("diagnostics_table"),

        div(class = "section-title", "Output Files"),
        uiOutput("output_files")
      )
    )
  )

  # ===========================================================================
  # SERVER LOGIC
  # ===========================================================================
  server <- function(input, output, session) {

    # Reactive values
    rv <- reactiveValues(
      result = NULL,
      log = "",
      running = FALSE,
      recent_folders = character(0)
    )

    # Recent folders file location (persistent across sessions)
    # Use user's home directory to persist between sessions
    recent_folders_file <- file.path(fs::path_home(), ".turas_weighting_recent_folders.rds")

    # Load recent folders on startup
    observe({
      if (file.exists(recent_folders_file)) {
        rv$recent_folders <- tryCatch(
          readRDS(recent_folders_file),
          error = function(e) character(0)
        )
      }
    })

    # Update recent folders dropdown
    observe({
      if (length(rv$recent_folders) > 0) {
        # Create named list for dropdown (display basename, value is full path)
        choices <- setNames(rv$recent_folders, basename(rv$recent_folders))
        updateSelectInput(session, "recent_folder",
                         choices = c("-- Select recent folder --" = "", choices))
      }
    })

    # Flag for whether recent folders exist
    output$has_recent_folders <- reactive({
      length(rv$recent_folders) > 0
    })
    outputOptions(output, "has_recent_folders", suspendWhenHidden = FALSE)

    # When recent folder selected, update text input
    observeEvent(input$recent_folder, {
      if (!is.null(input$recent_folder) && input$recent_folder != "") {
        updateTextInput(session, "project_folder", value = input$recent_folder)
      }
    })

    # Folder browser setup
    volumes <- c(Home = fs::path_home(), getVolumes()())
    shinyDirChoose(input, "folder_browse", roots = volumes, session = session)

    # Update text input when folder is selected via browser
    observeEvent(input$folder_browse, {
      if (!is.null(input$folder_browse)) {
        # Get selected path
        selected_path <- parseDirPath(volumes, input$folder_browse)
        if (length(selected_path) > 0) {
          updateTextInput(session, "project_folder", value = selected_path)
        }
      }
    })

    # Function to add folder to recent list
    add_to_recent_folders <- function(folder_path) {
      if (!is.null(folder_path) && nzchar(folder_path) && dir.exists(folder_path)) {
        # Normalize path
        folder_path <- normalizePath(folder_path, winslash = "/")

        # Remove if already exists (will re-add at top)
        rv$recent_folders <- setdiff(rv$recent_folders, folder_path)

        # Add to front, limit to 10 most recent
        rv$recent_folders <- c(folder_path, rv$recent_folders)
        if (length(rv$recent_folders) > 10) {
          rv$recent_folders <- rv$recent_folders[1:10]
        }

        # Save to file
        tryCatch({
          saveRDS(rv$recent_folders, recent_folders_file)
        }, error = function(e) {
          # Silently fail if can't save
        })
      }
    }

    # Log capture function
    add_log <- function(msg) {
      rv$log <- paste0(rv$log, msg, "\n")
    }

    # Progress log output (R 4.2+ compatible - use renderPrint with cat)
    output$progress_log <- renderPrint({
      cat(rv$log)
    })

    # Has results flag
    output$has_results <- reactive({
      !is.null(rv$result)
    })
    outputOptions(output, "has_results", suspendWhenHidden = FALSE)

    # Run weighting analysis
    observeEvent(input$run_weighting, {

      # Reset state
      rv$result <- NULL
      rv$log <- ""
      rv$running <- TRUE

      add_log("Starting weighting analysis...")

      # Use withProgress for visual progress bar
      withProgress(message = "Calculating Weights", value = 0, {

        tryCatch({
          # Validate inputs
          req(input$project_folder)
          req(input$config_filename)

          project_folder <- input$project_folder
          config_filename <- input$config_filename

          # Validate folder exists
          if (!dir.exists(project_folder)) {
            stop(paste0(
              "[REFUSE] IO_PROJECT_DIR_NOT_FOUND: Project Folder Not Found\n\n",
              "Problem: Project folder not found: ", project_folder, "\n\n",
              "How to fix: Select a valid project folder using the Browse button."
            ), call. = FALSE)
          }

          config_path <- file.path(project_folder, config_filename)

          # Validate config file exists
          if (!file.exists(config_path)) {
            stop(paste0(
              "[REFUSE] IO_CONFIG_FILE_NOT_FOUND: Config File Not Found\n\n",
              "Problem: Config file not found: ", config_path, "\n\n",
              "How to fix: Ensure the Weight_Config.xlsx file exists in the project folder."
            ), call. = FALSE)
          }

          # Add to recent folders
          add_to_recent_folders(project_folder)

          add_log(paste("Project folder:", project_folder))
          add_log(paste("Config file:", config_filename))
          add_log(strrep("-", 50))

          # Don't override data_file - let config resolve it
          data_path <- NULL

          # Create progress callback for run_weighting
          progress_callback <- function(value, message) {
            setProgress(value = value, detail = message)
          }

          # Run weighting with progress updates
          add_log("Loading configuration...")

          # Use capture.output for TRS compliance - all console output visible in GUI
          output_capture <- capture.output({
            result <- withCallingHandlers({
              run_weighting(
                config_file = config_path,
                data_file = data_path,
                verbose = TRUE,
                progress_callback = progress_callback
              )
            }, message = function(m) {
              cat(conditionMessage(m), "\n")
              invokeRestart("muffleMessage")
            }, warning = function(w) {
              cat("WARNING:", conditionMessage(w), "\n")
              invokeRestart("muffleWarning")
            })
          }, type = "output")

          # Add captured output to log
          if (length(output_capture) > 0) {
            add_log(paste(output_capture, collapse = "\n"))
          }

          rv$result <- result

          add_log(strrep("-", 50))
          add_log("Weighting completed successfully!")
          add_log(paste("Weights created:", paste(result$weight_names, collapse = ", ")))

        }, error = function(e) {
          add_log(strrep("=", 50))
          add_log("ERROR:")
          add_log(conditionMessage(e))
          add_log(strrep("=", 50))
        })

      })  # End withProgress

      rv$running <- FALSE
    })

    # Results summary
    output$results_summary <- renderUI({
      req(rv$result)
      result <- rv$result

      n_weights <- length(result$weight_names)
      n_rows <- nrow(result$data)

      div(
        h4(class = "status-success", icon("check-circle"), " Analysis Complete"),
        p(sprintf("Project: %s", result$config$general$project_name)),
        p(sprintf("Records processed: %s", format(n_rows, big.mark = ","))),
        p(sprintf("Weight columns created: %d", n_weights)),
        tags$ul(
          lapply(result$weight_names, function(w) {
            tags$li(w)
          })
        )
      )
    })

    # Diagnostics table
    output$diagnostics_table <- renderTable({
      req(rv$result)

      summary_df <- create_weight_summary_df(rv$result)

      if (nrow(summary_df) > 0) {
        # Format for display
        summary_df$efficiency <- paste0(round(summary_df$efficiency, 1), "%")
        summary_df$design_effect <- round(summary_df$design_effect, 2)
        summary_df$cv <- round(summary_df$cv, 3)
        summary_df$min <- round(summary_df$min, 3)
        summary_df$max <- round(summary_df$max, 2)

        # Select display columns
        summary_df[, c("weight_name", "method", "n_valid", "effective_n",
                      "design_effect", "efficiency", "quality_status")]
      }
    }, striped = TRUE, hover = TRUE, width = "100%")

    # Output files info
    output$output_files <- renderUI({
      req(rv$result)

      files <- list()

      if (!is.null(rv$result$output_file)) {
        files <- c(files, list(
          p(icon("file-excel"), " Weighted data: ", code(basename(rv$result$output_file)))
        ))
      }

      if (!is.null(rv$result$diagnostics_file)) {
        files <- c(files, list(
          p(icon("file-alt"), " Diagnostics: ", code(basename(rv$result$diagnostics_file)))
        ))
      }

      if (length(files) > 0) {
        div(files)
      } else {
        p("No output files saved (configure in Weight_Config.xlsx)")
      }
    })
  }

  # ===========================================================================
  # LAUNCH APP
  # ===========================================================================
  shinyApp(ui = ui, server = server)
}

# ==============================================================================
# AUTO-RUN
# ==============================================================================

# Don't auto-run if being sourced by launcher
if (!exists("TURAS_LAUNCHER_ACTIVE") || !TURAS_LAUNCHER_ACTIVE) {
  if (interactive()) {
    run_weighting_gui()
  }
}
