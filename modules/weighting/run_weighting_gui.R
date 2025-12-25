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
      "))
    ),

    div(class = "main-container",

      # Header
      div(class = "header",
        h1("TURAS Weighting Module"),
        p("Calculate survey weights using design or rim weighting methods")
      ),

      # Method Selection
      div(class = "section-title", "1. Select Input Method"),

      radioButtons("input_method", NULL,
                   choices = c("Browse to folder (recommended for large files)" = "folder",
                              "Upload files" = "upload"),
                   selected = "folder"),

      # Folder Selection (conditional)
      conditionalPanel(
        condition = "input.input_method == 'folder'",

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
            "Name of the config file in the folder above")
      ),

      # File Upload (conditional)
      conditionalPanel(
        condition = "input.input_method == 'upload'",

        fileInput("config_file", "Weight_Config.xlsx",
                  accept = c(".xlsx", ".xls"),
                  width = "100%"),
        div(class = "help-text",
            "Upload your Weight_Config.xlsx file"),

        fileInput("data_file", "Survey Data (CSV, XLSX, or SPSS)",
                  accept = c(".csv", ".xlsx", ".xls", ".sav"),
                  width = "100%"),
        div(class = "help-text",
            "Upload your survey data file")
      ),

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
      running = FALSE
    )

    # Folder browser setup
    volumes <- c(Home = fs::path_home(), getVolumes()())
    shinyDirChoose(input, "folder_browse", roots = volumes, session = session)

    # Update text input when folder is selected
    observeEvent(input$folder_browse, {
      if (!is.null(input$folder_browse)) {
        # Get selected path
        selected_path <- parseDirPath(volumes, input$folder_browse)
        if (length(selected_path) > 0) {
          updateTextInput(session, "project_folder", value = selected_path)
        }
      }
    })

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

      tryCatch({
        # Determine config and data paths based on input method
        if (input$input_method == "folder") {
          # Folder method - validate inputs
          req(input$project_folder)
          req(input$config_filename)

          project_folder <- input$project_folder
          config_filename <- input$config_filename

          # Validate folder exists
          if (!dir.exists(project_folder)) {
            stop("Project folder not found: ", project_folder)
          }

          config_path <- file.path(project_folder, config_filename)

          # Validate config file exists
          if (!file.exists(config_path)) {
            stop("Config file not found: ", config_path)
          }

          add_log(paste("Project folder:", project_folder))
          add_log(paste("Config file:", config_filename))
          add_log("Using files in place (no upload - memory efficient)")

          # Don't override data_file - let config resolve it
          data_path <- NULL

        } else {
          # Upload method - validate files uploaded
          req(input$config_file)
          req(input$data_file)

          config_path <- input$config_file$datapath
          data_path <- input$data_file$datapath

          add_log(paste("Config file:", input$config_file$name))
          add_log(paste("Data file:", input$data_file$name))
          add_log("Using uploaded files")
        }

        add_log(strrep("-", 50))

        # Run weighting with progress updates
        add_log("Loading configuration...")

        # Use capture.output for TRS compliance - all console output visible in GUI
        output_capture <- capture.output({
          result <- withCallingHandlers({
            run_weighting(
              config_file = config_path,
              data_file = data_path,
              verbose = TRUE
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
