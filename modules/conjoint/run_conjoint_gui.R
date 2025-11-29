# ==============================================================================
# TURAS CONJOINT MODULE - GUI LAUNCHER
# ==============================================================================

library(shiny)
library(shinyFiles)

#' Run Conjoint Analysis GUI
#'
#' Launches a Shiny GUI for running conjoint analysis.
#'
#' @return A shinyApp object
#' @export
run_conjoint_gui <- function() {

  # Get Turas root directory
  turas_root <- getwd()
  if (basename(turas_root) != "Turas") {
    if (file.exists(file.path(dirname(turas_root), "launch_turas.R"))) {
      turas_root <- dirname(turas_root)
    }
  }

  # Recent projects file
  RECENT_PROJECTS_FILE <- file.path(turas_root, ".recent_conjoint_projects.rds")

  # Load recent projects
  load_recent_projects <- function() {
    if (file.exists(RECENT_PROJECTS_FILE)) {
      tryCatch(readRDS(RECENT_PROJECTS_FILE), error = function(e) list())
    } else {
      list()
    }
  }

  # Save recent projects
  save_recent_projects <- function(projects) {
    tryCatch(saveRDS(projects, RECENT_PROJECTS_FILE), error = function(e) NULL)
  }

  # Add to recent projects
  add_recent_project <- function(project_info) {
    recent <- load_recent_projects()
    # Remove duplicates
    recent <- recent[!sapply(recent, function(x) x$project_dir == project_info$project_dir)]
    # Add new at front
    recent <- c(list(project_info), recent)
    # Keep only last 5
    recent <- recent[1:min(5, length(recent))]
    save_recent_projects(recent)
  }

  # Detect config files in directory
  detect_config_files <- function(dir) {
    if (!dir.exists(dir)) return(character(0))
    files <- list.files(dir, pattern = "\\.xlsx$", full.names = FALSE, ignore.case = TRUE)
    config_patterns <- c("conjoint.*config", "config.*conjoint", "cbc.*config", "config")
    detected <- character(0)
    for (pattern in config_patterns) {
      matches <- grep(pattern, files, value = TRUE, ignore.case = TRUE)
      if (length(matches) > 0) detected <- c(detected, matches)
    }
    unique(detected)
  }

  ui <- fluidPage(

    tags$head(
      tags$style(HTML("
        body {
          background-color: #f5f5f5;
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
          border-bottom: 3px solid #06b6d4;
        }
        .header h1 {
          color: #06b6d4;
          margin-bottom: 5px;
        }
        .header p {
          color: #6c757d;
        }
        .step-card {
          background-color: #f8f9fa;
          border: 1px solid #dee2e6;
          border-radius: 8px;
          padding: 20px;
          margin-bottom: 20px;
        }
        .step-title {
          font-size: 18px;
          font-weight: bold;
          color: #2c3e50;
          margin-bottom: 15px;
        }
        .file-display {
          background-color: #e9ecef;
          padding: 10px 15px;
          border-radius: 5px;
          margin-top: 10px;
          word-break: break-all;
        }
        .file-display .filename {
          font-weight: bold;
          color: #2c3e50;
        }
        .file-display .filepath {
          font-size: 12px;
          color: #6c757d;
        }
        .status-success {
          color: #28a745;
          font-weight: bold;
        }
        .status-error {
          color: #dc3545;
          font-weight: bold;
        }
        .btn-conjoint {
          background-color: #06b6d4;
          color: white;
          border: none;
        }
        .btn-conjoint:hover {
          background-color: #0891b2;
          color: white;
        }
        .run-btn {
          width: 100%;
          padding: 15px;
          font-size: 18px;
          font-weight: bold;
        }
        .console-output {
          background-color: #1e1e1e;
          color: #d4d4d4;
          font-family: 'Consolas', 'Monaco', monospace;
          padding: 15px;
          border-radius: 5px;
          max-height: 400px;
          overflow-y: auto;
          white-space: pre-wrap;
          font-size: 13px;
        }
        .info-box {
          background-color: #d1ecf1;
          border: 1px solid #bee5eb;
          color: #0c5460;
          padding: 10px 15px;
          border-radius: 5px;
          margin-top: 10px;
          font-size: 13px;
        }
      "))
    ),

    div(class = "main-container",

      # Header
      div(class = "header",
        h1("🔄 TURAS Conjoint Analysis"),
        p("Choice-based conjoint analysis with part-worth utilities")
      ),

      # Step 1: Project Directory
      div(class = "step-card",
        div(class = "step-title", "Step 1: Select Project Directory"),

        fluidRow(
          column(8,
            shinyDirButton("project_dir_btn",
                          "Browse for Project Folder",
                          "Select project directory",
                          class = "btn btn-conjoint",
                          icon = icon("folder-open"))
          ),
          column(4,
            uiOutput("recent_projects_ui")
          )
        ),

        uiOutput("project_display")
      ),

      # Step 2: Config File
      conditionalPanel(
        condition = "output.project_selected",
        div(class = "step-card",
          div(class = "step-title", "Step 2: Select Configuration File"),
          uiOutput("config_selector"),
          uiOutput("config_display"),
          div(class = "info-box",
            tags$strong("Note: "), "The config file's Settings sheet should specify ",
            tags$code("data_file"), " and ", tags$code("output_file"), " paths."
          )
        )
      ),

      # Run Button
      conditionalPanel(
        condition = "output.ready_to_run",
        div(class = "step-card",
          actionButton("run_analysis", "Run Conjoint Analysis",
                      class = "btn btn-conjoint run-btn",
                      icon = icon("play"))
        )
      ),

      # Console Output
      conditionalPanel(
        condition = "output.show_console",
        div(class = "step-card",
          div(class = "step-title", "Analysis Output"),
          div(class = "console-output",
            verbatimTextOutput("console_output")
          )
        )
      )
    )
  )

  server <- function(input, output, session) {

    # Reactive values
    files <- reactiveValues(
      project_dir = NULL,
      config_file = NULL
    )

    console_text <- reactiveVal("")
    is_running <- reactiveVal(FALSE)

    # Set up directory browser
    volumes <- c(Home = path.expand("~"),
                Documents = file.path(path.expand("~"), "Documents"),
                Desktop = file.path(path.expand("~"), "Desktop"))

    shinyDirChoose(input, "project_dir_btn", roots = volumes, session = session)

    # Handle project directory selection
    observeEvent(input$project_dir_btn, {
      if (!is.integer(input$project_dir_btn)) {
        dir_path <- parseDirPath(volumes, input$project_dir_btn)
        if (length(dir_path) > 0 && dir.exists(dir_path)) {
          files$project_dir <- dir_path
          files$config_file <- NULL
        }
      }
    })

    # Recent projects dropdown
    output$recent_projects_ui <- renderUI({
      recent <- load_recent_projects()
      if (length(recent) > 0) {
        choices <- setNames(
          sapply(recent, function(x) x$project_dir),
          sapply(recent, function(x) basename(x$project_dir))
        )
        selectInput("recent_project", "Recent:",
                   choices = c("Select recent..." = "", choices),
                   width = "100%")
      }
    })

    # Handle recent project selection
    observeEvent(input$recent_project, {
      if (!is.null(input$recent_project) && input$recent_project != "") {
        if (dir.exists(input$recent_project)) {
          files$project_dir <- input$recent_project
          files$config_file <- NULL
        }
      }
    })

    # Project display
    output$project_display <- renderUI({
      if (!is.null(files$project_dir)) {
        div(class = "file-display",
          div(class = "filename", basename(files$project_dir)),
          div(class = "filepath", files$project_dir),
          div(class = "status-success", "✓ Directory selected")
        )
      }
    })

    # Config file selector
    output$config_selector <- renderUI({
      req(files$project_dir)
      configs <- detect_config_files(files$project_dir)

      if (length(configs) > 0) {
        radioButtons("config_select", "Detected config files:",
                    choices = configs,
                    selected = configs[1])
      } else {
        # Manual file selection
        shinyFilesButton("config_btn", "Browse for Config File",
                        "Select configuration file",
                        class = "btn btn-conjoint",
                        multiple = FALSE)
      }
    })

    # Handle config selection
    observeEvent(input$config_select, {
      if (!is.null(input$config_select) && !is.null(files$project_dir)) {
        files$config_file <- file.path(files$project_dir, input$config_select)
      }
    })

    # Config display
    output$config_display <- renderUI({
      if (!is.null(files$config_file)) {
        div(class = "file-display",
          div(class = "filename", basename(files$config_file)),
          div(class = "filepath", files$config_file),
          if (file.exists(files$config_file)) {
            div(class = "status-success", "✓ Config file found")
          } else {
            div(class = "status-error", "✗ File not found")
          }
        )
      }
    })

    # Conditional panel outputs
    output$project_selected <- reactive({ !is.null(files$project_dir) })
    outputOptions(output, "project_selected", suspendWhenHidden = FALSE)

    output$ready_to_run <- reactive({
      !is.null(files$project_dir) &&
      !is.null(files$config_file) &&
      file.exists(files$config_file) &&
      !is_running()
    })
    outputOptions(output, "ready_to_run", suspendWhenHidden = FALSE)

    output$show_console <- reactive({ nchar(console_text()) > 0 })
    outputOptions(output, "show_console", suspendWhenHidden = FALSE)

    # Console output
    output$console_output <- renderText({ console_text() })

    # Run analysis
    observeEvent(input$run_analysis, {

      req(files$project_dir, files$config_file)

      is_running(TRUE)
      console_text("")

      # Save to recent projects
      add_recent_project(list(project_dir = files$project_dir))

      # Capture output
      output_text <- ""

      tryCatch({
        # Get Turas root
        turas_root <- getwd()
        if (basename(turas_root) != "Turas") {
          turas_root <- dirname(turas_root)
        }

        # Source module files (00_main.R loads all components)
        output_text <- paste0(output_text, "Loading Conjoint module...\n\n")
        console_text(output_text)

        source(file.path(turas_root, "modules/conjoint/R/00_main.R"))

        # Capture analysis output
        # Paths are read from config file Settings sheet
        capture <- capture.output({
          results <- run_conjoint_analysis(
            config_file = files$config_file
          )
        }, type = "output")

        output_text <- paste0(output_text, paste(capture, collapse = "\n"))
        output_text <- paste0(output_text, "\n\n✓ Analysis complete!")

      }, error = function(e) {
        output_text <<- paste0(output_text, "\n\n✗ Error: ", e$message)
      })

      console_text(output_text)
      is_running(FALSE)
    })
  }

  shinyApp(ui = ui, server = server)
}
