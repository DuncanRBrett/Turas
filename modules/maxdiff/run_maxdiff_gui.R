# ==============================================================================
# MAXDIFF MODULE - SHINY GUI LAUNCHER - TURAS V10.0
# ==============================================================================
# Graphical user interface for MaxDiff module
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# USAGE:
# source("run_maxdiff_gui.R")
# run_maxdiff_gui()
#
# Or from Turas launcher
# ==============================================================================

#' Launch MaxDiff GUI
#'
#' Opens a Shiny interface for running MaxDiff design and analysis.
#'
#' @export
run_maxdiff_gui <- function() {

  # ===========================================================================
  # SETUP
  # ===========================================================================

  # Check and load required packages
  required_packages <- c("shiny", "shinyFiles")
  missing <- required_packages[!required_packages %in% installed.packages()[, "Package"]]

  if (length(missing) > 0) {
    message("Installing required packages: ", paste(missing, collapse = ", "))
    install.packages(missing)
  }

  suppressPackageStartupMessages({
    library(shiny)
    library(shinyFiles)
  })

  # Determine paths
  TURAS_HOME <- Sys.getenv("TURAS_ROOT")
  if (!nzchar(TURAS_HOME)) {
    TURAS_HOME <- getwd()
    # Try to find Turas root
    if (!file.exists(file.path(TURAS_HOME, "launch_turas.R"))) {
      if (file.exists(file.path(dirname(TURAS_HOME), "launch_turas.R"))) {
        TURAS_HOME <- dirname(TURAS_HOME)
      } else if (file.exists(file.path(dirname(dirname(TURAS_HOME)), "launch_turas.R"))) {
        TURAS_HOME <- dirname(dirname(TURAS_HOME))
      }
    }
  }

  MODULE_DIR <- file.path(TURAS_HOME, "modules", "maxdiff")
  RECENT_PROJECTS_FILE <- file.path(TURAS_HOME, ".maxdiff_recent_projects.rds")

  # ===========================================================================
  # HELPER FUNCTIONS
  # ===========================================================================

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

  add_recent_project <- function(path) {
    projects <- load_recent_projects()
    projects <- unique(c(path, projects))
    if (length(projects) > 10) projects <- projects[1:10]
    save_recent_projects(projects)
  }

  detect_config_files <- function(dir_path) {
    if (!dir.exists(dir_path)) return(character(0))

    files <- list.files(dir_path, pattern = "\\.xlsx$", ignore.case = TRUE)

    # Prioritize files with maxdiff or config in name
    patterns <- c("maxdiff", "MaxDiff", "config", "Config")
    detected <- character(0)

    for (pattern in patterns) {
      matches <- grep(pattern, files, value = TRUE, ignore.case = TRUE)
      if (length(matches) > 0) detected <- c(detected, matches)
    }

    if (length(detected) == 0) detected <- files
    unique(detected)
  }

  # ===========================================================================
  # UI
  # ===========================================================================

  ui <- fluidPage(

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
          border-bottom: 2px solid #8b5cf6;
        }
        .header h1 {
          color: #2c3e50;
          font-size: 28px;
          margin-bottom: 5px;
        }
        .header p {
          color: #6c757d;
          font-size: 14px;
        }
        .card {
          background-color: #f8f9fa;
          border: 1px solid #dee2e6;
          border-radius: 8px;
          padding: 20px;
          margin-bottom: 20px;
        }
        .card h4 {
          color: #2c3e50;
          margin-bottom: 15px;
          font-size: 16px;
        }
        .btn-maxdiff {
          background-color: #8b5cf6;
          color: white;
          border: none;
          padding: 12px 24px;
          font-size: 16px;
          border-radius: 6px;
          cursor: pointer;
          width: 100%;
          margin-top: 10px;
        }
        .btn-maxdiff:hover {
          background-color: #7c3aed;
        }
        .btn-maxdiff:disabled {
          background-color: #c4b5fd;
          cursor: not-allowed;
        }
        .console-output {
          background-color: #1e293b;
          color: #e2e8f0;
          font-family: 'Consolas', 'Monaco', monospace;
          font-size: 12px;
          padding: 15px;
          border-radius: 6px;
          max-height: 400px;
          overflow-y: auto;
          white-space: pre-wrap;
          word-wrap: break-word;
        }
        .mode-selector {
          display: flex;
          gap: 10px;
          margin-bottom: 15px;
        }
        .mode-btn {
          flex: 1;
          padding: 15px;
          border: 2px solid #dee2e6;
          border-radius: 8px;
          background: white;
          cursor: pointer;
          text-align: center;
          transition: all 0.2s;
        }
        .mode-btn:hover {
          border-color: #8b5cf6;
        }
        .mode-btn.active {
          border-color: #8b5cf6;
          background-color: #f3e8ff;
        }
        .mode-btn h5 {
          margin: 0 0 5px 0;
          color: #2c3e50;
        }
        .mode-btn p {
          margin: 0;
          font-size: 12px;
          color: #6c757d;
        }
        .status-success {
          color: #059669;
          font-weight: bold;
        }
        .status-error {
          color: #dc2626;
          font-weight: bold;
        }
        .recent-projects {
          margin-top: 10px;
        }
        .recent-item {
          padding: 8px 12px;
          background: white;
          border: 1px solid #e5e7eb;
          border-radius: 4px;
          margin-bottom: 5px;
          cursor: pointer;
          font-size: 13px;
        }
        .recent-item:hover {
          background: #f3f4f6;
          border-color: #8b5cf6;
        }
      "))
    ),

    div(class = "main-container",

      # Header
      div(class = "header",
        h1("MaxDiff Module"),
        p("Best-Worst Scaling Design & Analysis")
      ),

      # Mode Selection
      div(class = "card",
        h4("1. Select Mode"),
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

      # Project Selection
      div(class = "card",
        h4("2. Select Configuration File"),
        fluidRow(
          column(8,
            shinyFilesButton("config_file", "Browse...",
                            title = "Select MaxDiff Config File",
                            multiple = FALSE,
                            buttonType = "default",
                            class = "btn-secondary")
          ),
          column(4,
            textOutput("selected_file_display")
          )
        ),
        uiOutput("recent_projects_ui")
      ),

      # Config Preview
      uiOutput("config_preview_ui"),

      # Run Button
      div(class = "card",
        h4("3. Run MaxDiff"),
        actionButton("run_btn", "Run MaxDiff Analysis",
                    class = "btn-maxdiff",
                    disabled = TRUE),
        br(), br(),
        uiOutput("status_ui")
      ),

      # Console Output
      div(class = "card",
        h4("Console Output"),
        div(class = "console-output",
          verbatimTextOutput("console_text")
        )
      ),

      # Footer
      div(style = "text-align: center; color: #9ca3af; font-size: 12px; margin-top: 20px;",
        sprintf("Turas MaxDiff Module v10.0 | %s", TURAS_HOME)
      )
    )
  )

  # ===========================================================================
  # SERVER
  # ===========================================================================

  server <- function(input, output, session) {

    # Reactive values
    rv <- reactiveValues(
      mode = "ANALYSIS",
      config_path = NULL,
      config = NULL,
      is_running = FALSE,
      console_output = "Ready to run MaxDiff analysis...\n"
    )

    # Volume roots for file browser
    volumes <- c(
      Home = path.expand("~"),
      Documents = file.path(path.expand("~"), "Documents"),
      Desktop = file.path(path.expand("~"), "Desktop"),
      Turas = TURAS_HOME
    )

    shinyFileChoose(input, "config_file", roots = volumes, session = session,
                   filetypes = c("xlsx", "xls"))

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

    # File selection
    observeEvent(input$config_file, {
      if (!is.integer(input$config_file)) {
        file_info <- parseFilePaths(volumes, input$config_file)
        if (nrow(file_info) > 0) {
          rv$config_path <- as.character(file_info$datapath)
          add_recent_project(rv$config_path)

          # Try to load config preview
          rv$console_output <- paste0(rv$console_output,
                                      sprintf("\nSelected: %s\n", rv$config_path))

          tryCatch({
            # Quick validation only
            rv$config <- list(path = rv$config_path, valid = TRUE)
            updateActionButton(session, "run_btn", disabled = FALSE)
          }, error = function(e) {
            rv$config <- list(path = rv$config_path, valid = FALSE, error = e$message)
            rv$console_output <- paste0(rv$console_output,
                                        sprintf("Warning: %s\n", e$message))
          })
        }
      }
    })

    output$selected_file_display <- renderText({
      if (!is.null(rv$config_path)) {
        basename(rv$config_path)
      } else {
        "No file selected"
      }
    })

    # Recent projects
    output$recent_projects_ui <- renderUI({
      recent <- load_recent_projects()
      if (length(recent) > 0) {
        div(class = "recent-projects",
          tags$small("Recent:"),
          lapply(recent[1:min(3, length(recent))], function(path) {
            actionLink(
              inputId = paste0("recent_", digest::digest(path)),
              label = basename(path),
              class = "recent-item",
              onclick = sprintf('Shiny.setInputValue("select_recent", "%s", {priority: "event"})', path)
            )
          })
        )
      }
    })

    observeEvent(input$select_recent, {
      if (!is.null(input$select_recent) && file.exists(input$select_recent)) {
        rv$config_path <- input$select_recent
        rv$console_output <- paste0(rv$console_output,
                                    sprintf("\nSelected: %s\n", rv$config_path))
        updateActionButton(session, "run_btn", disabled = FALSE)
      }
    })

    # Config preview
    output$config_preview_ui <- renderUI({
      if (!is.null(rv$config_path) && file.exists(rv$config_path)) {
        div(class = "card",
          h4("Configuration Preview"),
          tags$p(tags$strong("File: "), basename(rv$config_path)),
          tags$p(tags$strong("Mode: "), rv$mode)
        )
      }
    })

    # Run button
    observeEvent(input$run_btn, {
      req(rv$config_path)
      req(!rv$is_running)

      rv$is_running <- TRUE
      updateActionButton(session, "run_btn", disabled = TRUE, label = "Running...")

      rv$console_output <- sprintf(
        "================================================================================\n%s\nStarting MaxDiff %s mode...\n================================================================================\n",
        format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        rv$mode
      )

      # Source module
      tryCatch({
        old_wd <- getwd()

        # Source main module
        main_script <- file.path(MODULE_DIR, "R", "00_main.R")
        if (!file.exists(main_script)) {
          stop("Module files not found. Please check installation.")
        }

        # Create a temporary script to capture output
        withCallingHandlers({
          source(main_script, local = TRUE)

          result <- run_maxdiff(
            config_path = rv$config_path,
            verbose = TRUE
          )

          rv$console_output <- paste0(rv$console_output,
                                      "\n================================================================================\n",
                                      "COMPLETE\n",
                                      "================================================================================\n")

          if (!is.null(result$output_path)) {
            rv$console_output <- paste0(rv$console_output,
                                        sprintf("\nOutput saved to:\n%s\n", result$output_path))
          }

        }, message = function(m) {
          rv$console_output <- paste0(rv$console_output, m$message)
        }, warning = function(w) {
          rv$console_output <- paste0(rv$console_output, "Warning: ", w$message, "\n")
          invokeRestart("muffleWarning")
        })

        setwd(old_wd)

      }, error = function(e) {
        rv$console_output <- paste0(rv$console_output,
                                    sprintf("\nERROR: %s\n", e$message))
      }, finally = {
        rv$is_running <- FALSE
        updateActionButton(session, "run_btn", disabled = FALSE, label = "Run MaxDiff Analysis")
      })
    })

    # Status output
    output$status_ui <- renderUI({
      if (rv$is_running) {
        div(style = "color: #8b5cf6;", "Running analysis...")
      } else if (!is.null(rv$config_path)) {
        div(class = "status-success", "Ready to run")
      } else {
        div(style = "color: #6c757d;", "Select a configuration file to begin")
      }
    })

    # Console output
    output$console_text <- renderText({
      rv$console_output
    })
  }

  # ===========================================================================
  # RUN APP
  # ===========================================================================

  shinyApp(ui = ui, server = server)
}


# ==============================================================================
# AUTO-RUN
# ==============================================================================

# When sourced directly, launch the GUI
if (!interactive() || !exists("TURAS_LAUNCHER_ACTIVE")) {
  run_maxdiff_gui()
}
