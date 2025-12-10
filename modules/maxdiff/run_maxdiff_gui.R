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
  required_packages <- c("shiny")
  missing <- required_packages[!required_packages %in% installed.packages()[, "Package"]]

  if (length(missing) > 0) {
    message("Installing required packages: ", paste(missing, collapse = ", "))
    install.packages(missing)
  }

  suppressPackageStartupMessages({
    library(shiny)
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
          display: block;
          text-decoration: none;
          color: inherit;
        }
        .recent-item:hover {
          background: #f3f4f6;
          border-color: #8b5cf6;
        }
        .file-input-container {
          display: flex;
          gap: 10px;
          align-items: center;
        }
        .file-input-container .form-control {
          flex: 1;
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

      # Project Selection - use text input instead of shinyFiles
      div(class = "card",
        h4("2. Select Configuration File"),
        div(class = "file-input-container",
          textInput("config_path", NULL,
                    placeholder = "Enter path to config file or use file upload below",
                    width = "100%"),
          actionButton("browse_btn", "Browse...", class = "btn-secondary")
        ),
        fileInput("config_upload", "Or upload config file:",
                  accept = c(".xlsx", ".xls")),
        uiOutput("recent_projects_ui"),
        textOutput("file_status")
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
      is_running = FALSE,
      console_output = "Ready to run MaxDiff analysis...\n"
    )

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

    # Handle text input path
    observeEvent(input$config_path, {
      path <- trimws(input$config_path)
      if (nzchar(path) && file.exists(path)) {
        rv$config_path <- normalizePath(path)
        add_recent_project(rv$config_path)
        updateActionButton(session, "run_btn", disabled = FALSE)
      } else if (nzchar(path)) {
        rv$config_path <- NULL
        updateActionButton(session, "run_btn", disabled = TRUE)
      }
    }, ignoreInit = TRUE)

    # Handle file upload
    observeEvent(input$config_upload, {
      req(input$config_upload)
      # Copy uploaded file to a permanent location
      upload_path <- input$config_upload$datapath
      file_name <- input$config_upload$name

      # Save to module examples directory
      dest_dir <- file.path(MODULE_DIR, "uploads")
      if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE)

      dest_path <- file.path(dest_dir, file_name)
      file.copy(upload_path, dest_path, overwrite = TRUE)

      rv$config_path <- dest_path
      updateTextInput(session, "config_path", value = dest_path)
      add_recent_project(dest_path)
      updateActionButton(session, "run_btn", disabled = FALSE)

      rv$console_output <- paste0(rv$console_output,
                                  sprintf("\nUploaded: %s\n", file_name))
    })

    # Browse button - show file dialog hint
    observeEvent(input$browse_btn, {
      showModal(modalDialog(
        title = "Select Configuration File",
        p("Enter the full path to your MaxDiff configuration file (.xlsx):"),
        textInput("modal_path", NULL,
                  value = file.path(MODULE_DIR, "examples", "basic"),
                  width = "100%"),
        p(tags$small("Example: ", code(file.path(MODULE_DIR, "examples", "basic", "example_maxdiff_config.xlsx")))),
        footer = tagList(
          modalButton("Cancel"),
          actionButton("modal_ok", "OK", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$modal_ok, {
      path <- trimws(input$modal_path)
      if (nzchar(path)) {
        updateTextInput(session, "config_path", value = path)
        removeModal()
      }
    })

    output$file_status <- renderText({
      if (!is.null(rv$config_path) && file.exists(rv$config_path)) {
        paste("Selected:", basename(rv$config_path))
      } else if (!is.null(input$config_path) && nzchar(input$config_path)) {
        "File not found"
      } else {
        ""
      }
    })

    # Recent projects
    output$recent_projects_ui <- renderUI({
      recent <- load_recent_projects()
      recent <- recent[file.exists(recent)]  # Filter existing files

      if (length(recent) > 0) {
        div(class = "recent-projects",
          tags$small(tags$strong("Recent projects:")),
          lapply(recent[1:min(3, length(recent))], function(path) {
            tags$a(
              href = "#",
              class = "recent-item",
              onclick = sprintf('Shiny.setInputValue("select_recent", "%s", {priority: "event"}); return false;',
                               gsub("\\\\", "\\\\\\\\", path)),
              basename(path)
            )
          })
        )
      }
    })

    observeEvent(input$select_recent, {
      path <- input$select_recent
      if (!is.null(path) && file.exists(path)) {
        rv$config_path <- path
        updateTextInput(session, "config_path", value = path)
        updateActionButton(session, "run_btn", disabled = FALSE)
      }
    })

    # Config preview
    output$config_preview_ui <- renderUI({
      if (!is.null(rv$config_path) && file.exists(rv$config_path)) {
        div(class = "card",
          h4("Configuration Preview"),
          tags$p(tags$strong("File: "), basename(rv$config_path)),
          tags$p(tags$strong("Path: "), tags$small(rv$config_path)),
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

      # Source module and run
      tryCatch({
        old_wd <- getwd()

        # Source main module
        main_script <- file.path(MODULE_DIR, "R", "00_main.R")
        if (!file.exists(main_script)) {
          stop("Module files not found. Please check installation.")
        }

        # Capture output
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
      } else if (!is.null(rv$config_path) && file.exists(rv$config_path)) {
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
  app <- run_maxdiff_gui()
  shiny::runApp(app, launch.browser = TRUE)
}
