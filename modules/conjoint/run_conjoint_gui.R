# ==============================================================================
# TURAS CONJOINT MODULE - GUI LAUNCHER
# ==============================================================================

#' Run Conjoint Analysis GUI
#'
#' Launches a Shiny GUI for running conjoint analysis.
#'
#' @return A shinyApp object
#' @export
run_conjoint_gui <- function() {

  # Required packages - check availability (TRS v1.0: no auto-install)
  required_packages <- c("shiny", "shinyFiles")

  # Early refuse function for GUI entry point (before guard is loaded)
  early_refuse <- function(code, title, problem, why_it_matters, how_to_fix) {
    msg <- paste0(
      "\n", strrep("=", 80), "\n",
      sprintf("  [REFUSE] %s: %s\n", code, title),
      strrep("=", 80), "\n\n",
      "Problem:\n  ", problem, "\n\n",
      "Why it matters:\n  ", why_it_matters, "\n\n",
      "How to fix:\n  ", paste(how_to_fix, collapse = "\n  "), "\n\n",
      strrep("=", 80), "\n"
    )
    stop(msg, call. = FALSE)
  }

  # Check for missing packages and refuse with clear instructions if any are missing
  missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  if (length(missing_packages) > 0) {
    early_refuse(
      code = "PKG_MISSING_DEPENDENCY",
      title = "Missing Required Packages",
      problem = sprintf("The following required packages are not installed: %s",
                       paste(missing_packages, collapse = ", ")),
      why_it_matters = "The Conjoint GUI cannot run without these packages.",
      how_to_fix = sprintf("Run the following command in R:\n    install.packages(c(%s))",
                          paste(sprintf('"%s"', missing_packages), collapse = ", "))
    )
  }

  # Load packages
  suppressPackageStartupMessages({
    library(shiny)
    library(shinyFiles)
  })

  # Get Turas root directory
  turas_root <- getwd()
  if (basename(turas_root) != "Turas") {
    if (file.exists(file.path(dirname(turas_root), "launch_turas.R"))) {
      turas_root <- dirname(turas_root)
    }
  }

  # Load shared GUI theme
  source(file.path(turas_root, "modules", "shared", "lib", "gui_theme.R"))
  theme <- turas_gui_theme("Conjoint", "Choice-Based Conjoint Analysis")
  hide_recents <- turas_hide_recents()

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

    theme$head,

    theme$header,

    div(class = "turas-content",

      # Step 1: Project Directory
      div(class = "turas-card",
        h4(class = "turas-card-title", "Step 1: Select Project Directory"),

        fluidRow(
          column(if (!hide_recents) 8 else 12,
            shinyDirButton("project_dir_btn",
                          "Browse for Project Folder",
                          "Select project directory",
                          class = "btn turas-btn-primary",
                          icon = icon("folder-open"))
          ),
          if (!hide_recents) {
            column(4,
              uiOutput("recent_projects_ui")
            )
          }
        ),

        uiOutput("project_display")
      ),

      # Step 2: Config File
      conditionalPanel(
        condition = "output.project_selected",
        div(class = "turas-card",
          h4(class = "turas-card-title", "Step 2: Select Configuration File"),
          uiOutput("config_selector"),
          uiOutput("config_display"),
          div(class = "turas-status-info",
            tags$strong("Note: "), "The config file's Settings sheet should specify ",
            tags$code("data_file"), " and ", tags$code("output_file"), " paths."
          )
        )
      ),

      # Run Button
      conditionalPanel(
        condition = "output.ready_to_run",
        div(class = "turas-card",
          actionButton("run_analysis", "Run Conjoint Analysis",
                      class = "btn turas-btn-run",
                      icon = icon("play"))
        )
      ),

      # Console Output
      conditionalPanel(
        condition = "output.show_console",
        div(class = "turas-card",
          h4(class = "turas-card-title", "Analysis Output"),
          div(class = "turas-console",
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

    # Auto-load config from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config) && file.exists(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      files$config_file <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
      files$project_dir <- dirname(pre_config)
    }

    # Set up directory browser
    volumes <- c(Home = path.expand("~"),
                Documents = file.path(path.expand("~"), "Documents"),
                Desktop = file.path(path.expand("~"), "Desktop"))

    shinyDirChoose(input, "project_dir_btn", roots = volumes, session = session)

    # Handle project directory selection
    observeEvent(input$project_dir_btn, {
      if (!is.integer(input$project_dir_btn)) {
        dir_path <- parseDirPath(volumes, input$project_dir_btn)
        # Expand tilde and normalize path (fixes OneDrive/home directory paths)
        dir_path <- normalizePath(path.expand(dir_path), winslash = "/", mustWork = FALSE)
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
        div(class = "turas-file-display",
          tags$strong(basename(files$project_dir)),
          tags$br(),
          tags$small(files$project_dir),
          div(class = "status-success", "\u2713 Directory selected")
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
                        class = "btn turas-btn-primary",
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
        div(class = "turas-file-display",
          tags$strong(basename(files$config_file)),
          tags$br(),
          tags$small(files$config_file),
          if (file.exists(files$config_file)) {
            div(class = "status-success", "\u2713 Config file found")
          } else {
            div(class = "status-error", "\u2717 File not found")
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

        # Set working directory to Turas root for module loading
        old_wd <- getwd()
        setwd(turas_root)

        # Source main module file
        source(file.path(turas_root, "modules/conjoint/R/00_main.R"))

        # Restore working directory
        setwd(old_wd)

        # Verify config file exists
        if (!file.exists(files$config_file)) {
          early_refuse(
            code = "IO_CONFIG_FILE_NOT_FOUND",
            title = "Configuration File Not Found",
            problem = sprintf("Config file not found: %s", files$config_file),
            why_it_matters = "The configuration file defines the conjoint study design and analysis settings.",
            how_to_fix = c(
              "Verify the file path is correct",
              "Check that the file exists at the specified location"
            )
          )
        }

        # Capture analysis output
        # Paths are read from config file Settings sheet
        output_text <- paste0(output_text, "Config file: ", basename(files$config_file), "\n\n")
        console_text(output_text)

        capture <- capture.output({
          results <- run_conjoint_analysis(
            config_file = files$config_file
          )
        }, type = "output")

        output_text <- paste0(output_text, paste(capture, collapse = "\n"))
        output_text <- paste0(output_text, "\n\n✓ Analysis complete!")

      }, error = function(e) {
        output_text <<- paste0(output_text, "\n\n✗ Error: ", e$message)
        output_text <<- paste0(output_text, "\n\nDebug info:")
        output_text <<- paste0(output_text, "\n  - Turas root: ", turas_root)
        output_text <<- paste0(output_text, "\n  - Config file: ", files$config_file)
        output_text <<- paste0(output_text, "\n  - Config exists: ", file.exists(files$config_file))
        if (exists("e")) {
          output_text <<- paste0(output_text, "\n  - Error class: ", class(e)[1])
          output_text <<- paste0(output_text, "\n  - Call stack: ", paste(head(sys.calls(), 5), collapse = " -> "))
        }
      })

      console_text(output_text)
      is_running(FALSE)
    })
  }

  shinyApp(ui = ui, server = server)
}
