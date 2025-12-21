# ==============================================================================
# TURAS>CONFIDENCE GUI - LAUNCHER
# ==============================================================================
# Purpose: Launch confidence intervals analysis GUI
# Location: modules/confidence/run_confidence_gui.R
# Usage: source("modules/confidence/run_confidence_gui.R") then run_confidence_gui()
# ==============================================================================

run_confidence_gui <- function() {

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
      "  The Confidence GUI cannot run without these packages.\n\n",
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

  # Turas home directory
  TURAS_HOME <- getwd()

  # Recent projects file
  RECENT_PROJECTS_FILE <- file.path(TURAS_HOME, ".recent_projects.rds")

  # === HELPER FUNCTIONS ===

  load_recent_projects <- function() {
    if (file.exists(RECENT_PROJECTS_FILE)) {
      tryCatch(readRDS(RECENT_PROJECTS_FILE), error = function(e) character(0))
    } else {
      character(0)
    }
  }

  save_recent_projects <- function(projects) {
    tryCatch(saveRDS(projects, RECENT_PROJECTS_FILE), error = function(e) NULL)
  }

  add_recent_project <- function(project_dir) {
    recent <- load_recent_projects()
    recent <- unique(c(project_dir, recent))
    recent <- recent[1:min(5, length(recent))]
    save_recent_projects(recent)
  }

  detect_config_files <- function(project_dir) {
    if (!dir.exists(project_dir)) return(character(0))
    files <- list.files(project_dir, pattern = "\\.xlsx$", full.names = FALSE, ignore.case = TRUE)
    config_patterns <- c("confidence", "Confidence", "CI", "confidence_config")
    detected <- character(0)
    for (pattern in config_patterns) {
      matches <- grep(pattern, files, value = TRUE, ignore.case = TRUE)
      if (length(matches) > 0) detected <- c(detected, matches)
    }
    if (length(detected) == 0) detected <- files
    unique(detected)
  }

  # ==============================================================================
  # SHINY UI
  # ==============================================================================

  ui <- fluidPage(
    tags$head(
      tags$style(HTML("
        .main-header {
          background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
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
        .btn-primary {
          background: #f59e0b;
          border: none;
        }
        .btn-primary:hover {
          background: #d97706;
        }
        .btn-run {
          background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
          border: none;
          color: white;
          font-weight: 700;
          padding: 16px 40px;
          font-size: 18px;
          border-radius: 10px;
        }
        .project-display {
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
          border-color: #f59e0b;
        }
      "))
    ),

    # Header
    div(class = "main-header",
      h1("📊 TURAS>CONFIDENCE"),
      p("Statistical Confidence Intervals • Means & Proportions • Bootstrap & Bayesian Methods"),
      p(style = "font-size: 14px; opacity: 0.9;",
        "Part of Turas Analytics Toolkit")
    ),

    # Main content
    fluidRow(
      column(12,

        # Step 1: Project Selection
        div(class = "card",
          h3("1. Select Project Directory"),

          shinyDirButton("project_btn",
                        "Browse for Project Folder",
                        "Select project directory",
                        class = "btn btn-primary btn-lg",
                        icon = icon("folder-open")),

          uiOutput("project_ui"),
          uiOutput("recent_ui")
        ),

        # Step 2: Config Selection
        uiOutput("config_ui"),

        # Step 3: Run Button
        uiOutput("run_ui"),

        # Step 4: Console Output
        uiOutput("console_ui")
      )
    )
  )

  # ==============================================================================
  # SHINY SERVER
  # ==============================================================================

  server <- function(input, output, session) {

    # Reactive values
    project_data <- reactiveVal(NULL)
    console_output <- reactiveVal("")
    is_running <- reactiveVal(FALSE)

    # Directory chooser
    volumes <- c(Home = "~", Documents = "~/Documents", Desktop = "~/Desktop")
    shinyDirChoose(input, "project_btn", roots = volumes, session = session)

    # Handle directory selection
    observeEvent(input$project_btn, {
      if (!is.integer(input$project_btn)) {
        dir_path <- parseDirPath(volumes, input$project_btn)
        # Expand tilde and normalize path (fixes OneDrive/home directory paths)
        dir_path <- normalizePath(path.expand(dir_path), winslash = "/", mustWork = FALSE)
        if (length(dir_path) > 0 && dir.exists(dir_path)) {
          configs <- detect_config_files(dir_path)
          project_data(list(
            path = dir_path,
            configs = configs,
            selected_config = if(length(configs) > 0) configs[1] else NULL
          ))
          add_recent_project(dir_path)
        }
      }
    })

    # Handle recent project selection
    observeEvent(input$select_recent, {
      req(input$select_recent)
      # Expand tilde and normalize path (fixes OneDrive/home directory paths)
      dir_path <- normalizePath(path.expand(input$select_recent), winslash = "/", mustWork = FALSE)
      if (dir.exists(dir_path)) {
        configs <- detect_config_files(dir_path)
        project_data(list(
          path = dir_path,
          configs = configs,
          selected_config = if(length(configs) > 0) configs[1] else NULL
        ))
        add_recent_project(dir_path)
      }
    })

    # Handle config selection
    observeEvent(input$config_select, {
      data <- project_data()
      if (!is.null(data)) {
        data$selected_config <- input$config_select
        project_data(data)
      }
    })

    # Project display
    output$project_ui <- renderUI({
      data <- project_data()
      if (is.null(data)) {
        div(class = "status-info",
          icon("info-circle"), " No project selected. Click Browse to get started."
        )
      } else {
        div(class = "project-display",
          tags$strong(basename(data$path)),
          tags$br(),
          tags$small(data$path),
          div(class = "status-success", style = "margin-top: 10px;",
            icon("check-circle"), " ",
            tags$strong(length(data$configs)), " configuration file(s) found"
          )
        )
      }
    })

    # Recent projects
    output$recent_ui <- renderUI({
      recent <- load_recent_projects()
      if (length(recent) == 0) return(NULL)

      div(
        tags$hr(),
        h4("Recent Projects"),
        lapply(seq_along(recent), function(i) {
          tags$div(
            class = "recent-project-item",
            onclick = sprintf("Shiny.setInputValue('select_recent', '%s', {priority: 'event'})", recent[i]),
            tags$strong(basename(recent[i])),
            tags$br(),
            tags$small(style = "color: #666;", recent[i])
          )
        })
      )
    })

    # Config selection UI
    output$config_ui <- renderUI({
      data <- project_data()
      if (is.null(data) || length(data$configs) == 0) return(NULL)

      div(class = "card",
        h3("2. Select Configuration File"),
        radioButtons("config_select",
                    NULL,
                    choices = setNames(data$configs, paste("📄", data$configs)),
                    selected = data$selected_config)
      )
    })

    # Run button UI
    output$run_ui <- renderUI({
      data <- project_data()
      if (is.null(data) || is.null(data$selected_config)) return(NULL)

      div(class = "card",
        h3("3. Run Analysis"),
        div(style = "text-align: center; margin: 20px 0;",
          actionButton("run_btn",
                      "RUN ANALYSIS",
                      class = "btn-run",
                      icon = icon("play-circle"),
                      disabled = is_running())
        )
      )
    })

    # Console output UI
    output$console_ui <- renderUI({
      if (console_output() == "") return(NULL)

      div(class = "card",
        h3("4. Analysis Output"),
        div(class = "console-output",
          verbatimTextOutput("console_text")
        )
      )
    })

    # R 4.2+ compatible renderText - must return single string
    output$console_text <- renderText({
      out <- console_output()
      if (is.null(out) || length(out) == 0) {
        return("")
      }
      # Ensure single string output for R 4.2+
      paste(out, collapse = "")
    })

    # Run analysis
    observeEvent(input$run_btn, {
      data <- project_data()
      req(data, data$selected_config)

      is_running(TRUE)
      console_output("Starting confidence interval analysis...\n\n")

      # Save current working directory
      old_wd <- getwd()

      tryCatch({
        # Build paths
        confidence_dir <- file.path(TURAS_HOME, "modules", "confidence")
        config_path <- file.path(data$path, data$selected_config)

        if (!dir.exists(confidence_dir)) {
          stop("Could not find confidence module at: ", confidence_dir)
        }

        if (!file.exists(config_path)) {
          stop("Could not find config file at: ", config_path)
        }

        # Update console
        console_output(paste0(
          console_output(),
          sprintf("Project: %s\n", data$path),
          sprintf("Config: %s\n", data$selected_config),
          sprintf("\n%s\n\n", strrep("=", 80))
        ))

        # Set script directory override so module can find its files
        assign("script_dir_override", file.path(confidence_dir, "R"), envir = .GlobalEnv)

        # Source the confidence module
        source(file.path(confidence_dir, "R", "00_main.R"))

        # Capture ALL console output (cat, print, messages) including errors
        # This ensures output is displayed even if analysis fails
        captured_output <- capture.output({
          result <- tryCatch({
            run_confidence_analysis(config_path, verbose = TRUE)
            list(success = TRUE, error = NULL)
          }, error = function(e) {
            cat("\n", strrep("=", 80), "\n", sep = "")
            cat("❌ ERROR OCCURRED\n")
            cat(strrep("=", 80), "\n\n", sep = "")
            cat("Error message:\n")
            cat(e$message, "\n\n")
            cat("The analysis encountered an error. Check the configuration file and data.\n")
            cat("Common issues:\n")
            cat("  • Data file path incorrect or file not accessible\n")
            cat("  • Missing required columns in data\n")
            cat("  • Invalid question IDs in config\n")
            cat("  • Weight variable not found\n\n")
            list(success = FALSE, error = e$message)
          })
        }, type = "output")

        # Update console with all captured output
        console_output(paste0(
          console_output(),
          paste(captured_output, collapse = "\n")
        ))

        # Show completion or error message
        if (result$success) {
          console_output(paste0(
            console_output(),
            sprintf("\n\n%s\n✓ ANALYSIS COMPLETE\n%s\n", strrep("=", 80), strrep("=", 80)),
            sprintf("\nOutput files saved to project directory\n")
          ))
          showNotification("Analysis completed successfully!", type = "message", duration = 5)
        } else {
          showNotification(paste("Error:", result$error), type = "error", duration = 10)
        }

      }, error = function(e) {
        # This catches errors in the GUI setup itself (not analysis errors)
        console_output(paste0(
          console_output(),
          "\n\n", strrep("=", 80), "\n",
          "❌ FATAL ERROR\n",
          strrep("=", 80), "\n\n",
          "GUI encountered an unexpected error:\n",
          e$message, "\n\n",
          "This is likely a GUI configuration issue, not an analysis error.\n"
        ))
        showNotification(paste("Fatal error:", e$message), type = "error", duration = 10)

      }, finally = {
        # Clean up global variables
        if (exists("script_dir_override", envir = .GlobalEnv)) {
          rm("script_dir_override", envir = .GlobalEnv)
        }
        # Restore original working directory
        setwd(old_wd)
        is_running(FALSE)
      })
    })
  }

  # Launch
  cat("\nLaunching Turas>Confidence GUI...\n\n")
  shinyApp(ui = ui, server = server)
}
