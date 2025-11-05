# ============================================================================
# TURAS CROSSTABS - INTERACTIVE GUI LAUNCHER (SHINY VERSION)
# ============================================================================
# Modern web-based GUI for running Turas crosstabs analysis
# 
# FEATURES:
#   - Browse to select project directory
#   - Auto-detect available config files  
#   - Live progress monitoring
#   - Recent projects with search
#   - Modern responsive interface
#
# REQUIREMENTS:
#   - shiny package: install.packages("shiny")
#   - shinyFiles package: install.packages("shinyFiles")
#
# USAGE:
#   source("turas_launcher_shiny.R")
# ============================================================================

# Check for required packages
required_packages <- c("shiny", "shinyFiles")
missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

if (length(missing_packages) > 0) {
  cat("\n")
  cat("Missing required packages:", paste(missing_packages, collapse = ", "), "\n")
  cat("Install with: install.packages(c('", paste(missing_packages, collapse = "', '"), "'))\n\n")
  
  response <- readline("Install missing packages now? (y/n): ")
  if (tolower(response) == "y") {
    install.packages(missing_packages)
  } else {
    stop("Required packages not installed. Exiting.")
  }
}

library(shiny)
library(shinyFiles)

# === CONFIGURATION ===
TURAS_HOME <- "/Users/duncan/Documents/Turas"
RECENT_PROJECTS_FILE <- file.path(TURAS_HOME, ".recent_projects.rds")
MAX_RECENT_PROJECTS <- 10

# === HELPER FUNCTIONS ===

#' Load recent projects from file
load_recent_projects <- function() {
  if (file.exists(RECENT_PROJECTS_FILE)) {
    tryCatch({
      readRDS(RECENT_PROJECTS_FILE)
    }, error = function(e) {
      character(0)
    })
  } else {
    character(0)
  }
}

#' Save recent projects to file
save_recent_projects <- function(recent_projects) {
  tryCatch({
    saveRDS(recent_projects, RECENT_PROJECTS_FILE)
  }, error = function(e) {
    warning("Could not save recent projects: ", e$message)
  })
}

#' Add project to recent list
add_to_recent <- function(project_dir, recent_projects) {
  recent_projects <- recent_projects[recent_projects != project_dir]
  recent_projects <- c(project_dir, recent_projects)
  
  if (length(recent_projects) > MAX_RECENT_PROJECTS) {
    recent_projects <- recent_projects[1:MAX_RECENT_PROJECTS]
  }
  
  recent_projects
}

#' Detect available config files in project directory
detect_config_files <- function(project_dir) {
  if (is.null(project_dir) || !dir.exists(project_dir)) {
    return(character(0))
  }
  
  config_files <- c()
  
  # Check for standard config files
  if (file.exists(file.path(project_dir, "Crosstab_Config.xlsx"))) {
    config_files <- c(config_files, "Crosstab_Config.xlsx")
  }
  
  if (file.exists(file.path(project_dir, "Survey_Structure.xlsx"))) {
    config_files <- c(config_files, "Survey_Structure.xlsx")
  }
  
  # Also check for any other xlsx files
  all_xlsx <- list.files(project_dir, pattern = "\\.xlsx$", full.names = FALSE)
  other_configs <- setdiff(all_xlsx, config_files)
  
  if (length(other_configs) > 0) {
    config_files <- c(config_files, other_configs)
  }
  
  config_files
}

# === SHINY UI ===

ui <- fluidPage(
  
  # Custom CSS
  tags$head(
    tags$style(HTML("
      body {
        background-color: #f5f5f5;
      }
      .main-header {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 20px;
        border-radius: 8px;
        margin-bottom: 20px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
      }
      .main-header h2 {
        margin: 0;
        font-weight: 600;
      }
      .main-header p {
        margin: 5px 0 0 0;
        opacity: 0.9;
      }
      .section-box {
        background: white;
        padding: 20px;
        border-radius: 8px;
        margin-bottom: 20px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
      .section-title {
        font-size: 16px;
        font-weight: 600;
        color: #333;
        margin-bottom: 15px;
        padding-bottom: 10px;
        border-bottom: 2px solid #667eea;
      }
      .btn-run {
        background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
        border: none;
        color: white;
        padding: 15px 40px;
        font-size: 18px;
        font-weight: 600;
        border-radius: 8px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        transition: transform 0.2s;
      }
      .btn-run:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 8px rgba(0,0,0,0.15);
      }
      .btn-browse {
        background-color: #667eea;
        border: none;
        color: white;
        padding: 8px 20px;
        border-radius: 5px;
      }
      .btn-browse:hover {
        background-color: #5568d3;
      }
      .project-path {
        background-color: #f8f9fa;
        padding: 10px;
        border-radius: 5px;
        border-left: 3px solid #667eea;
        font-family: monospace;
        font-size: 12px;
        margin-top: 10px;
        word-wrap: break-word;
      }
      .recent-project {
        background-color: #f8f9fa;
        padding: 8px 12px;
        margin: 5px 0;
        border-radius: 5px;
        cursor: pointer;
        transition: background-color 0.2s;
      }
      .recent-project:hover {
        background-color: #e9ecef;
      }
      .status-message {
        padding: 10px;
        border-radius: 5px;
        margin-top: 10px;
      }
      .status-success {
        background-color: #d4edda;
        border-left: 3px solid #28a745;
        color: #155724;
      }
      .status-error {
        background-color: #f8d7da;
        border-left: 3px solid #dc3545;
        color: #721c24;
      }
      .status-info {
        background-color: #d1ecf1;
        border-left: 3px solid #17a2b8;
        color: #0c5460;
      }
      .config-badge {
        display: inline-block;
        background-color: #667eea;
        color: white;
        padding: 3px 10px;
        border-radius: 12px;
        font-size: 12px;
        margin-left: 10px;
      }
      .footer {
        text-align: center;
        color: #6c757d;
        font-size: 12px;
        padding: 20px;
        margin-top: 20px;
      }
      #console_output {
        background-color: #1e1e1e;
        color: #d4d4d4;
        font-family: 'Courier New', monospace;
        font-size: 12px;
        padding: 15px;
        border-radius: 5px;
        max-height: 400px;
        overflow-y: auto;
        white-space: pre-wrap;
        word-wrap: break-word;
      }
    "))
  ),
  
  # Main container
  div(style = "max-width: 900px; margin: 0 auto; padding: 20px;",
    
    # Header
    div(class = "main-header",
      h2("🔬 TURAS CROSSTABS"),
      p("Interactive Analysis Launcher")
    ),
    
    # Project Selection
    div(class = "section-box",
      div(class = "section-title", "1️⃣ Select Project Directory"),
      
      fluidRow(
        column(12,
          shinyDirButton("browse_btn", "📁 Browse for Project", 
                        "Select project directory", class = "btn-browse"),
          uiOutput("project_path_display")
        )
      ),
      
      conditionalPanel(
        condition = "output.has_recent_projects",
        hr(),
        div(style = "margin-top: 15px;",
          strong("Recent Projects:"),
          uiOutput("recent_projects_ui")
        )
      )
    ),
    
    # Config Selection
    div(class = "section-box",
      div(class = "section-title", "2️⃣ Select Configuration File"),
      
      uiOutput("config_selection_ui")
    ),
    
    # Run Button
    div(style = "text-align: center; margin: 30px 0;",
      actionButton("run_btn", "▶ RUN ANALYSIS", 
                  class = "btn-run")
    ),
    
    # Console Output
    conditionalPanel(
      condition = "output.show_console",
      div(class = "section-box",
        div(class = "section-title", "📊 Analysis Output"),
        verbatimTextOutput("console_output", placeholder = TRUE)
      )
    ),
    
    # Footer
    div(class = "footer",
      paste("Turas Home:", TURAS_HOME)
    )
  )
)

# === SHINY SERVER ===

server <- function(input, output, session) {
  
  # Reactive values
  rv <- reactiveValues(
    project_dir = NULL,
    available_configs = character(0),
    recent_projects = load_recent_projects(),
    console_text = "",
    show_console = FALSE
  )
  
  # Directory chooser - initialize with multiple root options for better Mac compatibility
  volumes <- c(
    Home = path.expand("~"),
    Documents = path.expand("~/Documents"),
    Desktop = path.expand("~/Desktop"),
    Root = "/"
  )
  
  shinyDirChoose(input, "browse_btn", roots = volumes, session = session)
  
  observeEvent(input$browse_btn, {
    cat("Browse button clicked\n")
    cat("Input value type:", class(input$browse_btn), "\n")
    
    if (!is.integer(input$browse_btn)) {
      cat("Processing directory selection...\n")
      # Parse directory path with the volumes we defined
      dir_path <- parseDirPath(volumes, input$browse_btn)
      cat("Parsed path:", dir_path, "\n")
      
      if (length(dir_path) > 0) {
        if (dir.exists(dir_path)) {
          cat("Directory exists, updating...\n")
          rv$project_dir <- dir_path
          rv$available_configs <- detect_config_files(dir_path)
          cat("Found", length(rv$available_configs), "config files\n")
        } else {
          cat("Directory does not exist:", dir_path, "\n")
        }
      } else {
        cat("No directory path parsed\n")
      }
    } else {
      cat("Button value is integer (initial state)\n")
    }
  })
  
  # Display project path
  output$project_path_display <- renderUI({
    if (!is.null(rv$project_dir)) {
      div(class = "project-path",
        strong("Selected: "), basename(rv$project_dir),
        br(),
        tags$small(rv$project_dir)
      )
    } else {
      div(class = "status-message status-info",
        "No project selected. Click Browse to select a project directory."
      )
    }
  })
  
  # Recent projects
  output$has_recent_projects <- reactive({
    length(rv$recent_projects) > 0
  })
  outputOptions(output, "has_recent_projects", suspendWhenHidden = FALSE)
  
  output$recent_projects_ui <- renderUI({
    if (length(rv$recent_projects) == 0) return(NULL)
    
    lapply(seq_along(rv$recent_projects), function(i) {
      proj <- rv$recent_projects[i]
      div(class = "recent-project",
        onclick = sprintf("Shiny.setInputValue('select_recent', %d, {priority: 'event'})", i),
        tags$strong(basename(proj)),
        br(),
        tags$small(style = "color: #6c757d;", proj)
      )
    })
  })
  
  observeEvent(input$select_recent, {
    if (input$select_recent > 0 && input$select_recent <= length(rv$recent_projects)) {
      rv$project_dir <- rv$recent_projects[input$select_recent]
      rv$available_configs <- detect_config_files(rv$project_dir)
    }
  })
  
  # Config selection
  output$config_selection_ui <- renderUI({
    if (is.null(rv$project_dir)) {
      div(class = "status-message status-info",
        "Please select a project directory first."
      )
    } else if (length(rv$available_configs) == 0) {
      div(class = "status-message status-error",
        "⚠️ No configuration files found in selected directory.",
        br(),
        "Expected: Crosstab_Config.xlsx or Survey_Structure.xlsx"
      )
    } else {
      tagList(
        div(class = "status-message status-success",
          sprintf("✓ Found %d configuration file(s)", length(rv$available_configs))
        ),
        br(),
        radioButtons("config_file", "Select configuration:",
                    choices = setNames(rv$available_configs, 
                                      paste(rv$available_configs, 
                                           ifelse(rv$available_configs %in% 
                                                 c("Crosstab_Config.xlsx", "Survey_Structure.xlsx"),
                                                 "(Standard)", ""))),
                    selected = rv$available_configs[1])
      )
    }
  })
  
  # Console output
  output$show_console <- reactive({
    rv$show_console
  })
  outputOptions(output, "show_console", suspendWhenHidden = FALSE)
  
  output$console_output <- renderText({
    rv$console_text
  })
  
  # Run analysis
  observeEvent(input$run_btn, {
    
    # Validation
    if (is.null(rv$project_dir)) {
      showModal(modalDialog(
        title = "Error",
        "Please select a project directory.",
        easyClose = TRUE,
        footer = modalButton("OK")
      ))
      return()
    }
    
    if (length(rv$available_configs) == 0 || is.null(input$config_file)) {
      showModal(modalDialog(
        title = "Error",
        "No configuration file selected.",
        easyClose = TRUE,
        footer = modalButton("OK")
      ))
      return()
    }
    
    # Add to recent projects
    rv$recent_projects <- add_to_recent(rv$project_dir, rv$recent_projects)
    save_recent_projects(rv$recent_projects)
    
    # Prepare for analysis
    rv$show_console <- TRUE
    
    project_dir <- rv$project_dir
    config_filename <- input$config_file
    
    # Capture output and run analysis
    output_text <- capture.output({
      cat(strrep("=", 80), "\n")
      cat("TURAS CROSSTABS ANALYSIS\n")
      cat(strrep("=", 80), "\n\n")
      cat("Project:", basename(project_dir), "\n")
      cat("Config:", config_filename, "\n")
      cat("Path:", project_dir, "\n\n")
      
      # Set working directory
      old_wd <- getwd()
      setwd(project_dir)
      
      # CRITICAL: Set config_file in global env for run_crosstabs.R
      assign("config_file", config_filename, envir = .GlobalEnv)
      
      # Point to Turas installation
      toolkit_path <- file.path(TURAS_HOME, "modules/tabs/lib/run_crosstabs.R")
      
      if (!file.exists(toolkit_path)) {
        stop("Turas toolkit not found at: ", toolkit_path)
      }
      
      cat("Starting analysis...\n")
      cat(strrep("=", 80), "\n")
      
      # CRITICAL: Assign toolkit_path to global env so run_crosstabs.R can find its dependencies
      assign("toolkit_path", toolkit_path, envir = .GlobalEnv)
      
      # Source the toolkit
      tryCatch({
        source(toolkit_path, local = FALSE)  # Source in global env
        cat("\n")
        cat(strrep("=", 80), "\n")
        cat("✓ ANALYSIS COMPLETE\n")
        cat(strrep("=", 80), "\n")
      }, error = function(e) {
        cat("\n")
        cat(strrep("=", 80), "\n")
        cat("✗ ERROR:\n")
        cat(e$message, "\n")
        cat(strrep("=", 80), "\n")
      }, finally = {
        # Clean up
        if (exists("toolkit_path", envir = .GlobalEnv)) {
          rm(toolkit_path, envir = .GlobalEnv)
        }
        if (exists("config_file", envir = .GlobalEnv)) {
          rm(config_file, envir = .GlobalEnv)
        }
      })
      
      # Restore working directory
      setwd(old_wd)
    })
    
    rv$console_text <- paste(output_text, collapse = "\n")
  })
}

# === LAUNCH APP ===

#' Launch the Turas Crosstabs Shiny App
launch_turas_shiny <- function(port = NULL) {
  
  cat("\n")
  cat(strrep("=", 80), "\n")
  cat("LAUNCHING TURAS CROSSTABS GUI (SHINY)...\n")
  cat(strrep("=", 80), "\n\n")
  
  if (is.null(port)) {
    port <- as.integer(Sys.getenv("SHINY_PORT", "3838"))
  }
  
  # Build URL
  app_url <- sprintf("http://localhost:%d", port)
  
  cat("Starting Shiny server on:", app_url, "\n")
  cat("Opening browser...\n")
  cat("(If browser doesn't open, manually go to:", app_url, ")\n\n")
  
  # Create the app object
  app <- shinyApp(
    ui = ui, 
    server = server
  )
  
  # Use runApp for better source() compatibility
  runApp(app, port = port, launch.browser = TRUE)
}

# Auto-launch if sourced interactively
if (interactive()) {
  # Check if required packages are available
  if (all(sapply(required_packages, requireNamespace, quietly = TRUE))) {
    # Just call the function - it will handle everything
    launch_turas_shiny()
  }
}
