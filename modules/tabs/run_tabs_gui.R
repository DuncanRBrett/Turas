# ==============================================================================
# TURAS>TABS GUI - LAUNCHER
# ==============================================================================
# Purpose: Launch beautiful crosstabs GUI (matches parser interface)
# Location: modules/tabs/run_tabs_gui.R
# Usage: source("modules/tabs/run_tabs_gui.R") then run_tabs_gui()
# ==============================================================================

run_tabs_gui <- function() {
  
  # Required packages
  required_packages <- c("shiny", "shinyFiles")
  
  # Install missing packages
  missing_packages <- required_packages[!required_packages %in% installed.packages()[,"Package"]]
  if (length(missing_packages) > 0) {
    message("Installing required packages: ", paste(missing_packages, collapse = ", "))
    install.packages(missing_packages)
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
    config_patterns <- c("Crosstab_Config", "Survey_Structure", "Config")
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
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
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
          background: #667eea;
          border: none;
        }
        .btn-primary:hover {
          background: #764ba2;
        }
        .btn-run {
          background: linear-gradient(135deg, #48bb78 0%, #38a169 100%);
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
          border-color: #667eea;
        }
      "))
    ),
    
    # Header
    div(class = "main-header",
      h1("🔬 TURAS>TABS"),
      p("Professional Survey Analysis • Cross-tabulation & Statistical Testing"),
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
    
    output$console_text <- renderText({
      console_output()
    })
    
    # Run analysis
    observeEvent(input$run_btn, {
      data <- project_data()
      req(data, data$selected_config)

      is_running(TRUE)
      console_output("Starting analysis...\n\n")

      # Save current working directory
      old_wd <- getwd()

      # Build paths
      tabs_lib_dir <- file.path(TURAS_HOME, "modules", "tabs", "lib")
      run_script <- file.path(tabs_lib_dir, "run_crosstabs.R")

      if (!file.exists(run_script)) {
        console_output(paste0(console_output(), "\n\nERROR: Could not find run_crosstabs.R at: ", run_script))
        is_running(FALSE)
        return()
      }

      # Update console
      console_output(paste0(
        console_output(),
        sprintf("Project: %s\n", data$path),
        sprintf("Config: %s\n", data$selected_config),
        sprintf("\n%s\n\n", strrep("=", 80))
      ))

      # Change to modules/tabs/lib directory where all the analysis scripts are
      setwd(tabs_lib_dir)

      # Set config_file as global variable (script expects this)
      assign("config_file", file.path(data$path, data$selected_config), envir = .GlobalEnv)

      # Create Shiny progress bar updater (replaces log_progress)
      # This function will be called by process_all_questions()
      shiny_progress_callback <- function(current, total, item, start_time) {
        # Calculate progress percentage
        progress_value <- current / total

        # Build detail message
        elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
        rate <- elapsed / current
        remaining <- (total - current) * rate

        eta_str <- if (remaining < 60) {
          sprintf("%.0fs", remaining)
        } else if (remaining < 3600) {
          sprintf("%.1fm", remaining / 60)
        } else {
          sprintf("%.1fh", remaining / 3600)
        }

        detail_msg <- sprintf("Processing %s... (%d/%d) | ETA: %s",
                             item, current, total, eta_str)

        # Update Shiny progress bar
        setProgress(progress_value, detail = detail_msg)
      }

      # Set the custom progress callback as a global variable
      # (run_crosstabs.R will use this if it exists)
      assign("gui_progress_callback", shiny_progress_callback, envir = .GlobalEnv)

      # Run analysis with progress bar
      withProgress(message = 'Running Analysis', value = 0, {

        # Run analysis and capture ALL console output (including validation errors)
        # Use sink() to capture output even when errors occur
        output_file <- tempfile()
        sink(output_file, type = "output")

        analysis_result <- tryCatch({
          source("run_crosstabs.R", local = FALSE)  # local = FALSE so it uses global config_file
          list(success = TRUE, error = NULL)

        }, error = function(e) {
          list(success = FALSE, error = e)

        }, finally = {
          # Always restore console output
          sink(type = "output")
        })
      })

      # Read captured output (available even if error occurred)
      captured_output <- readLines(output_file, warn = FALSE)
      unlink(output_file)

      # Append captured output to console (works for both success and error cases)
      if (length(captured_output) > 0) {
        console_output(paste0(
          console_output(),
          paste(captured_output, collapse = "\n"),
          "\n"
        ))
      }

      # Handle success or error
      if (analysis_result$success) {
        # Get actual output path from config
        config_settings <- tryCatch({
          load_config_settings(file.path(data$path, data$selected_config))
        }, error = function(e) list())
        output_subfolder <- get_config_value(config_settings, "output_subfolder", "Crosstabs")

        # Update console with completion message
        console_output(paste0(
          console_output(),
          sprintf("\n%s\n✓ ANALYSIS COMPLETE\n%s\n", strrep("=", 80), strrep("=", 80)),
          sprintf("\nOutput files saved to:\n%s\n", file.path(data$path, output_subfolder))
        ))

        showNotification("Analysis completed successfully!", type = "message", duration = 5)

      } else {
        # Display error
        error_output <- paste0(
          console_output(),
          "\n\n",
          strrep("=", 80), "\n",
          "ERROR\n",
          strrep("=", 80), "\n",
          analysis_result$error$message, "\n"
        )
        console_output(error_output)
        showNotification(paste("Error:", analysis_result$error$message), type = "error", duration = 10)
      }

      # Clean up global variables
      if (exists("config_file", envir = .GlobalEnv)) {
        rm("config_file", envir = .GlobalEnv)
      }
      if (exists("gui_progress_callback", envir = .GlobalEnv)) {
        rm("gui_progress_callback", envir = .GlobalEnv)
      }
      # Restore original working directory
      setwd(old_wd)
      is_running(FALSE)
    })
  }
  
  # Launch
  cat("\nLaunching Turas>Tabs GUI...\n\n")
  shinyApp(ui = ui, server = server)
}
