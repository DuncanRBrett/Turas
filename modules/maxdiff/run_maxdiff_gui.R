# ==============================================================================
# TURAS>MAXDIFF GUI - LAUNCHER
# ==============================================================================
# Purpose: Launch MaxDiff design and analysis GUI
# Location: modules/maxdiff/run_maxdiff_gui.R
# Usage: source("modules/maxdiff/run_maxdiff_gui.R") then run_maxdiff_gui()
# ==============================================================================

run_maxdiff_gui <- function() {

  # Required packages - NO shinyFiles
  required_packages <- c("shiny")

  # Install missing packages
  missing_packages <- required_packages[!required_packages %in% installed.packages()[,"Package"]]
  if (length(missing_packages) > 0) {
    message("Installing required packages: ", paste(missing_packages, collapse = ", "))
    install.packages(missing_packages)
  }

  # Load packages
  suppressPackageStartupMessages({
    library(shiny)
  })

  # === CONFIGURATION ===

  # Turas home directory
  TURAS_HOME <- getwd()

  # Module directory
  MODULE_DIR <- file.path(TURAS_HOME, "modules", "maxdiff")

  # Recent projects file
  RECENT_PROJECTS_FILE <- file.path(TURAS_HOME, ".recent_maxdiff_projects.rds")

  # === HELPER FUNCTIONS ===

  load_recent_projects <- function() {
    if (file.exists(RECENT_PROJECTS_FILE)) {
      tryCatch(readRDS(RECENT_PROJECTS_FILE), error = function(e) list())
    } else {
      list()
    }
  }

  save_recent_projects <- function(projects) {
    tryCatch(saveRDS(projects, RECENT_PROJECTS_FILE), error = function(e) NULL)
  }

  add_recent_project <- function(project_info) {
    recent <- load_recent_projects()
    recent <- c(list(project_info), recent)
    recent <- recent[!duplicated(sapply(recent, function(x) x$config_path))]
    recent <- recent[1:min(5, length(recent))]
    save_recent_projects(recent)
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
          color: white;
          padding: 10px 20px;
          border-radius: 5px;
          cursor: pointer;
        }
        .btn-primary:hover {
          background: #6d28d9;
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
        .mode-selector {
          display: flex;
          gap: 10px;
          margin: 15px 0;
        }
        .mode-btn {
          flex: 1;
          padding: 15px;
          border: 2px solid #e2e8f0;
          border-radius: 8px;
          background: white;
          cursor: pointer;
          text-align: center;
        }
        .mode-btn:hover {
          border-color: #8b5cf6;
        }
        .mode-btn.active {
          border-color: #8b5cf6;
          background-color: #f3e8ff;
        }
        .path-input {
          width: 100%;
          padding: 10px;
          border: 1px solid #e2e8f0;
          border-radius: 5px;
          font-family: monospace;
          font-size: 14px;
        }
        .example-path {
          font-family: monospace;
          font-size: 12px;
          color: #666;
          background: #f7fafc;
          padding: 5px 10px;
          border-radius: 3px;
          display: inline-block;
          margin-top: 5px;
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
          div(class = "mode-selector",
            actionButton("mode_design", "",
              class = "mode-btn",
              tags$h5("DESIGN"),
              tags$p("Generate experimental design")
            ),
            actionButton("mode_analysis", "",
              class = "mode-btn active",
              tags$h5("ANALYSIS"),
              tags$p("Analyze survey responses")
            )
          ),
          textOutput("mode_description")
        ),

        # Step 2: File Selection - Simple text input
        div(class = "card",
          h3("2. Select Configuration File"),
          p("Enter the full path to your MaxDiff configuration Excel file:"),
          textInput("config_path", NULL,
                    value = "",
                    placeholder = "e.g., /path/to/your/maxdiff_config.xlsx",
                    width = "100%"),
          div(
            tags$small("Example path: "),
            tags$span(class = "example-path",
              file.path(MODULE_DIR, "examples", "basic", "example_maxdiff_config.xlsx"))
          ),
          br(),
          uiOutput("file_status"),
          uiOutput("recent_ui")
        ),

        # Step 3: Run Button
        uiOutput("run_ui"),

        # Step 4: Console Output
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
      mode = "ANALYSIS"
    )

    console_output <- reactiveVal("")
    is_running <- reactiveVal(FALSE)

    # Mode selection
    observeEvent(input$mode_design, {
      rv$mode <- "DESIGN"
      updateActionButton(session, "mode_design", class = "mode-btn active")
      updateActionButton(session, "mode_analysis", class = "mode-btn")
    })

    observeEvent(input$mode_analysis, {
      rv$mode <- "ANALYSIS"
      updateActionButton(session, "mode_design", class = "mode-btn")
      updateActionButton(session, "mode_analysis", class = "mode-btn active")
    })

    output$mode_description <- renderText({
      if (rv$mode == "DESIGN") {
        "Generate an optimal experimental design for your MaxDiff study"
      } else {
        "Analyze survey responses and compute preference utilities"
      }
    })

    # File status
    output$file_status <- renderUI({
      path <- trimws(input$config_path)
      if (!nzchar(path)) {
        div(class = "status-info", "Enter a file path above")
      } else if (file.exists(path)) {
        div(class = "status-success", paste("File found:", basename(path)))
      } else {
        div(class = "status-warning", "File not found - please check the path")
      }
    })

    # Recent projects
    output$recent_ui <- renderUI({
      recent <- load_recent_projects()
      # Filter to only existing files
      recent <- Filter(function(x) file.exists(x$config_path), recent)
      if (length(recent) == 0) return(NULL)

      div(
        tags$hr(),
        h4("Recent Projects"),
        lapply(seq_along(recent), function(i) {
          proj <- recent[[i]]
          tags$div(
            class = "recent-project-item",
            onclick = sprintf("Shiny.setInputValue('select_recent', %d, {priority: 'event'})", i),
            tags$strong(basename(proj$config_path)),
            tags$span(style = "float: right; color: #8b5cf6;", proj$mode),
            tags$br(),
            tags$small(style = "color: #666;", dirname(proj$config_path))
          )
        })
      )
    })

    # Handle recent project selection
    observeEvent(input$select_recent, {
      recent <- load_recent_projects()
      recent <- Filter(function(x) file.exists(x$config_path), recent)
      if (input$select_recent <= length(recent)) {
        proj <- recent[[input$select_recent]]
        updateTextInput(session, "config_path", value = proj$config_path)
        rv$mode <- proj$mode
        if (proj$mode == "DESIGN") {
          updateActionButton(session, "mode_design", class = "mode-btn active")
          updateActionButton(session, "mode_analysis", class = "mode-btn")
        } else {
          updateActionButton(session, "mode_design", class = "mode-btn")
          updateActionButton(session, "mode_analysis", class = "mode-btn active")
        }
      }
    })

    # Run button UI
    output$run_ui <- renderUI({
      path <- trimws(input$config_path)
      can_run <- nzchar(path) && file.exists(path) && !is_running()

      div(class = "card",
        h3("3. Run MaxDiff"),
        div(style = "text-align: center; margin: 20px 0;",
          actionButton("run_btn",
                      paste("RUN MAXDIFF", rv$mode),
                      class = "btn-run",
                      disabled = !can_run)
        )
      )
    })

    # Console output
    output$console_text <- renderText({
      current_output <- console_output()

      if (is.null(current_output) || length(current_output) == 0 || nchar(current_output[1]) == 0) {
        "Console output will appear here when you run MaxDiff..."
      } else {
        if (length(current_output) > 1) {
          paste(current_output, collapse = "\n")
        } else {
          current_output
        }
      }
    })

    # Run analysis
    observeEvent(input$run_btn, {
      config_path <- trimws(input$config_path)
      req(nzchar(config_path))
      req(file.exists(config_path))

      is_running(TRUE)

      # Clear previous console output
      console_output("")

      # Create progress indicator
      progress <- Progress$new(session)
      progress$set(message = paste("Running MaxDiff", rv$mode), value = 0)
      on.exit(progress$close())

      # Save current working directory
      old_wd <- getwd()

      # Capture all warnings
      all_warnings <- character(0)
      warning_handler <- function(w) {
        all_warnings <<- c(all_warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }

      tryCatch(withCallingHandlers({
        # Validate path
        config_path <- normalizePath(config_path, mustWork = FALSE)

        progress$set(value = 0.1, detail = "Validating inputs...")

        if (!file.exists(config_path)) {
          stop("Config file not found: ", config_path)
        }

        # Build paths
        run_script <- file.path(MODULE_DIR, "R", "00_main.R")

        if (!file.exists(run_script)) {
          stop("Could not find MaxDiff module at: ", run_script)
        }

        # Change to module directory
        setwd(MODULE_DIR)

        # Source main module
        progress$set(value = 0.2, detail = "Loading MaxDiff modules...")
        source(file.path("R", "00_main.R"))

        # Run analysis and capture ALL console output
        progress$set(value = 0.3, detail = "Running MaxDiff analysis...")

        output_capture_file <- tempfile()
        sink(output_capture_file, type = "output")

        analysis_result <- tryCatch({
          result <- run_maxdiff(
            config_path = config_path,
            verbose = TRUE
          )
          list(success = TRUE, result = result, error = NULL)

        }, error = function(e) {
          list(success = FALSE, result = NULL, error = e)

        }, finally = {
          sink(type = "output")
        })

        progress$set(value = 0.9, detail = "Finalizing...")

        # Read captured output
        captured_output <- readLines(output_capture_file, warn = FALSE)
        unlink(output_capture_file)

        # Display captured output in console
        if (length(captured_output) > 0) {
          console_output(paste(captured_output, collapse = "\n"))
        } else {
          console_output("MaxDiff completed but produced no console output.")
        }

        # Handle error from analysis
        if (!analysis_result$success) {
          stop(analysis_result$error$message)
        }

        # Save to recent projects
        add_recent_project(list(
          config_path = config_path,
          mode = rv$mode
        ))

        # Update console with completion message
        output_path <- if (!is.null(analysis_result$result$output_path)) {
          analysis_result$result$output_path
        } else {
          "See output folder"
        }

        console_output(paste0(
          console_output(),
          sprintf("\n%s\n ANALYSIS COMPLETE\n%s\n", strrep("=", 80), strrep("=", 80)),
          sprintf("\nOutput file saved to:\n%s\n", output_path)
        ))

        # Display warnings
        if (length(all_warnings) > 0) {
          warning_msg <- paste0("\n\nWarnings:\n", paste(all_warnings, collapse = "\n"))
          console_output(paste0(console_output(), "\n", warning_msg))
        }

        progress$set(value = 1.0, detail = "Complete!")
        showNotification("MaxDiff analysis completed!", type = "message", duration = 5)

      }, warning = warning_handler), error = function(e) {
        error_msg <- paste0(strrep("=", 80), "\nERROR: ", e$message, "\n", strrep("=", 80), "\n\n")
        error_msg <- paste0(error_msg, "Full error:\n", paste(capture.output(print(e)), collapse = "\n"))
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

  shinyApp(ui = ui, server = server)
}
