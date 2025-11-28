# ==============================================================================
# TURAS>TRACKER GUI - LAUNCHER
# ==============================================================================
# Purpose: Launch beautiful tracking analysis GUI
# Location: modules/tracker/run_tracker_gui.R
# Usage: source("modules/tracker/run_tracker_gui.R") then run_tracker_gui()
# ==============================================================================

run_tracker_gui <- function() {

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
  RECENT_PROJECTS_FILE <- file.path(TURAS_HOME, ".recent_tracker_projects.rds")

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
    # Add to front, remove duplicates based on tracking_config path
    recent <- c(list(project_info), recent)
    recent <- recent[!duplicated(sapply(recent, function(x) x$tracking_config))]
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
          background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
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
          background: #f093fb;
          border: none;
        }
        .btn-primary:hover {
          background: #f5576c;
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
        .file-display {
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
          border-color: #f093fb;
        }
        .file-label {
          font-weight: 600;
          color: #2d3748;
          margin-top: 10px;
        }
      "))
    ),

    # Header
    div(class = "main-header",
      h1("📊 TURAS>TRACKER"),
      p("Survey Tracking Analysis • Multi-Wave Trend Calculation & Testing"),
      p(style = "font-size: 14px; opacity: 0.9;",
        "Part of Turas Analytics Toolkit")
    ),

    # Main content
    fluidRow(
      column(12,

        # Step 1: File Selection
        div(class = "card",
          h3("1. Select Tracking Configuration"),
          p(style = "color: #666; font-size: 14px;",
            "Question mapping will be auto-detected in the same directory"),

          div(class = "file-label", "Tracking Configuration:"),
          div(style = "display: inline-block; margin-right: 10px;",
            shinyFilesButton("tracking_config_btn",
                          "Browse for tracking_config.xlsx",
                          "Select tracking config file",
                          class = "btn btn-primary",
                          icon = icon("file-excel"),
                          multiple = FALSE)
          ),
          uiOutput("tracking_config_display"),
          uiOutput("question_mapping_display"),

          uiOutput("recent_ui")
        ),

        # Step 2: Additional Options
        uiOutput("options_ui"),

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
    files <- reactiveValues(
      tracking_config = NULL,
      question_mapping = NULL,
      data_dir = NULL,
      output_path = NULL
    )

    console_output <- reactiveVal("")
    is_running <- reactiveVal(FALSE)

    # File choosers
    volumes <- c(Home = "~", Documents = "~/Documents", Desktop = "~/Desktop")

    shinyFileChoose(input, "tracking_config_btn", roots = volumes, session = session,
                   filetypes = c("", "xlsx"))
    shinyDirChoose(input, "data_dir_btn", roots = volumes, session = session)
    shinyFileChoose(input, "output_path_btn", roots = volumes, session = session,
                   filetypes = c("", "xlsx"))

    # Handle tracking config selection
    observeEvent(input$tracking_config_btn, {
      tryCatch({
        if (!is.integer(input$tracking_config_btn)) {
          file_path <- parseFilePaths(volumes, input$tracking_config_btn)
          if (nrow(file_path) > 0) {
            tracking_path <- as.character(file_path$datapath[1])
            files$tracking_config <- tracking_path

            # Auto-detect question mapping in same directory
            config_dir <- dirname(tracking_path)

            # Look for question_mapping file
            possible_names <- c(
              "question_mapping.xlsx",
              "Question_Mapping.xlsx",
              "QuestionMapping.xlsx",
              paste0(gsub("_tracking_config\\.xlsx$|_config\\.xlsx$", "", basename(tracking_path)), "_question_mapping.xlsx")
            )

            question_map_path <- NULL
            for (name in possible_names) {
              test_path <- file.path(config_dir, name)
              if (file.exists(test_path)) {
                question_map_path <- test_path
                break
              }
            }

            # If not found, list all xlsx files in directory
            if (is.null(question_map_path)) {
              xlsx_files <- list.files(config_dir, pattern = "mapping.*\\.xlsx$", ignore.case = TRUE, full.names = TRUE)
              if (length(xlsx_files) > 0) {
                question_map_path <- xlsx_files[1]
              }
            }

            files$question_mapping <- question_map_path

            if (is.null(question_map_path)) {
              showNotification("Question mapping file not found in same directory. Please ensure it exists.",
                             type = "warning", duration = 5)
            }
          }
        }
      }, error = function(e) {
        showNotification(paste("Error selecting file:", e$message), type = "error")
      })
    })

    # Handle data dir selection
    observeEvent(input$data_dir_btn, {
      tryCatch({
        if (!is.integer(input$data_dir_btn)) {
          dir_path <- parseDirPath(volumes, input$data_dir_btn)
          if (length(dir_path) > 0 && nchar(dir_path[1]) > 0) {
            files$data_dir <- as.character(dir_path[1])
          }
        }
      }, error = function(e) {
        showNotification(paste("Error selecting directory:", e$message), type = "error")
      })
    })

    # Handle output path selection
    observeEvent(input$output_path_btn, {
      tryCatch({
        if (!is.integer(input$output_path_btn)) {
          file_path <- parseFilePaths(volumes, input$output_path_btn)
          if (nrow(file_path) > 0) {
            files$output_path <- as.character(file_path$datapath[1])
          }
        }
      }, error = function(e) {
        showNotification(paste("Error selecting file:", e$message), type = "error")
      })
    })

    # Handle recent project selection
    observeEvent(input$select_recent, {
      req(input$select_recent)
      recent <- load_recent_projects()
      if (input$select_recent <= length(recent)) {
        proj <- recent[[input$select_recent]]
        files$tracking_config <- proj$tracking_config
        files$question_mapping <- proj$question_mapping
        if (!is.null(proj$data_dir)) files$data_dir <- proj$data_dir
        if (!is.null(proj$output_path)) files$output_path <- proj$output_path
        if (!is.null(proj$use_banners)) {
          updateCheckboxInput(session, "use_banners", value = proj$use_banners)
        }
      }
    })

    # Display tracking config
    output$tracking_config_display <- renderUI({
      if (is.null(files$tracking_config)) {
        div(class = "status-info",
          icon("info-circle"), " No file selected"
        )
      } else {
        div(class = "file-display",
          tags$strong(basename(files$tracking_config)),
          tags$br(),
          tags$small(files$tracking_config),
          if (file.exists(files$tracking_config)) {
            div(class = "status-success", style = "margin-top: 10px;",
              icon("check-circle"), " File found"
            )
          } else {
            div(class = "status-warning", style = "margin-top: 10px;",
              icon("exclamation-triangle"), " File not found"
            )
          }
        )
      }
    })

    # Display question mapping
    output$question_mapping_display <- renderUI({
      if (is.null(files$question_mapping)) {
        return(NULL)
      } else {
        div(
          div(class = "file-label", style = "margin-top: 15px;", "Question Mapping (auto-detected):"),
          div(class = "file-display",
            tags$strong(basename(files$question_mapping)),
            tags$br(),
            tags$small(files$question_mapping),
            if (file.exists(files$question_mapping)) {
              div(class = "status-success", style = "margin-top: 10px;",
                icon("check-circle"), " File found"
              )
            } else {
              div(class = "status-warning", style = "margin-top: 10px;",
                icon("exclamation-triangle"), " File not found"
              )
            }
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
          proj <- recent[[i]]
          tags$div(
            class = "recent-project-item",
            onclick = sprintf("Shiny.setInputValue('select_recent', %d, {priority: 'event'})", i),
            tags$strong(basename(proj$tracking_config)),
            tags$br(),
            tags$small(style = "color: #666;", dirname(proj$tracking_config))
          )
        })
      )
    })

    # Options UI
    output$options_ui <- renderUI({
      if (is.null(files$tracking_config) || is.null(files$question_mapping)) return(NULL)

      div(class = "card",
        h3("2. Additional Options (Optional)"),

        div(class = "file-label", "Data Directory (optional):"),
        p(style = "font-size: 13px; color: #666;",
          "Default: Same directory as config files. Only change if wave data files are elsewhere."),
        div(style = "display: inline-block; margin-right: 10px;",
          shinyDirButton("data_dir_btn",
                        "Browse for Data Directory",
                        "Select data directory",
                        class = "btn btn-primary",
                        icon = icon("folder"))
        ),
        if (!is.null(files$data_dir)) {
          div(class = "file-display",
            tags$strong("Data Directory:"),
            tags$br(),
            tags$small(files$data_dir),
            actionLink("clear_data_dir", "Clear", style = "float: right; color: #e53e3e;")
          )
        },

        tags$hr(),

        div(class = "file-label", "Output Path (optional):"),
        p(style = "font-size: 13px; color: #666;",
          "Default: Auto-generated in same directory as config (e.g., 'CCS_tracking_output.xlsx')"),
        div(style = "display: inline-block; margin-right: 10px;",
          shinyFilesButton("output_path_btn",
                        "Browse for Output Path",
                        "Select output file location",
                        class = "btn btn-primary",
                        icon = icon("file-excel"),
                        multiple = FALSE)
        ),
        if (!is.null(files$output_path)) {
          div(class = "file-display",
            tags$strong("Output Path:"),
            tags$br(),
            tags$small(files$output_path),
            actionLink("clear_output", "Clear", style = "float: right; color: #e53e3e;")
          )
        },

        tags$hr(),

        checkboxInput("use_banners",
                     "Calculate trends with banner breakouts (Phase 3)",
                     value = TRUE),
        p(style = "font-size: 13px; color: #666;",
          "When enabled, calculates trends for Total and banner segments defined in config")
      )
    })

    # Clear handlers
    observeEvent(input$clear_data_dir, {
      files$data_dir <- NULL
    })

    observeEvent(input$clear_output, {
      files$output_path <- NULL
    })

    # Run button UI
    output$run_ui <- renderUI({
      if (is.null(files$tracking_config) || is.null(files$question_mapping)) return(NULL)

      can_run <- !is.null(files$tracking_config) &&
                 !is.null(files$question_mapping) &&
                 file.exists(files$tracking_config) &&
                 file.exists(files$question_mapping)

      div(class = "card",
        h3("3. Run Tracking Analysis"),
        if (!can_run) {
          div(class = "status-warning",
            icon("exclamation-triangle"), " Please select valid configuration files to continue"
          )
        },
        div(style = "text-align: center; margin: 20px 0;",
          actionButton("run_btn",
                      "RUN TRACKING ANALYSIS",
                      class = "btn-run",
                      icon = icon("play-circle"),
                      disabled = !can_run || is_running())
        )
      )
    })

    # Console output UI - always visible
    output$console_ui <- renderUI({
      div(class = "card",
        h3("4. Analysis Output"),
        div(class = "console-output",
          if (nchar(console_output()) == 0) {
            p(style = "color: #666; font-style: italic;",
              "Console output will appear here when you run the tracker...")
          } else {
            verbatimTextOutput("console_text")
          }
        )
      )
    })

    output$console_text <- renderText({
      console_output()
    })

    # Run analysis
    observeEvent(input$run_btn, {
      req(files$tracking_config, files$question_mapping)

      is_running(TRUE)
      session$userData$has_run <- TRUE
      console_output("Starting tracking analysis...\n\n")

      # Save current working directory
      old_wd <- getwd()

      # Capture all warnings
      all_warnings <- character(0)
      warning_handler <- function(w) {
        all_warnings <<- c(all_warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }

      tryCatch(withCallingHandlers({
        # Validate and ensure all paths are character strings
        tracking_config <- files$tracking_config
        question_mapping <- files$question_mapping

        # Expand paths (resolve ~ and relative paths)
        tracking_config <- normalizePath(tracking_config, mustWork = FALSE)
        question_mapping <- normalizePath(question_mapping, mustWork = FALSE)

        # Debug info
        console_output(paste0(
          console_output(),
          "Validating inputs...\n",
          sprintf("  tracking_config: %s\n", tracking_config),
          sprintf("  question_mapping: %s\n", question_mapping)
        ))

        # Ensure character
        if (!is.character(tracking_config) || length(tracking_config) != 1) {
          stop("Invalid tracking config path: not a single character string")
        }
        if (!is.character(question_mapping) || length(question_mapping) != 1) {
          stop("Invalid question mapping path: not a single character string")
        }

        # Validate files exist
        if (!file.exists(tracking_config)) {
          stop("Tracking config file not found: ", tracking_config)
        }
        if (!file.exists(question_mapping)) {
          stop("Question mapping file not found: ", question_mapping)
        }

        # Auto-set data_dir to same directory as config files if not specified
        config_dir <- dirname(tracking_config)
        data_dir <- if (!is.null(files$data_dir)) {
          normalizePath(files$data_dir, mustWork = FALSE)
        } else {
          config_dir  # Use same directory as config
        }

        # Auto-generate output path in same directory as config
        output_path <- if (!is.null(files$output_path)) {
          normalizePath(files$output_path, mustWork = FALSE)
        } else {
          # Generate filename based on tracking config name
          config_basename <- gsub("_tracking_config\\.xlsx$|_config\\.xlsx$", "", basename(tracking_config))
          output_filename <- paste0(config_basename, "_tracking_output.xlsx")
          file.path(config_dir, output_filename)
        }

        # Build paths
        tracker_dir <- file.path(TURAS_HOME, "modules", "tracker")
        run_script <- file.path(tracker_dir, "run_tracker.R")

        if (!file.exists(run_script)) {
          stop("Could not find run_tracker.R at: ", run_script)
        }

        # Update console
        console_output(paste0(
          console_output(),
          "\nStarting analysis with:\n",
          sprintf("  Tracking Config: %s\n", tracking_config),
          sprintf("  Question Mapping: %s\n", question_mapping),
          sprintf("  Data Directory: %s\n", data_dir),
          sprintf("  Output Path: %s\n", output_path),
          sprintf("  Use Banners: %s\n", ifelse(input$use_banners, "Yes", "No")),
          sprintf("\n%s\n\n", strrep("=", 80))
        ))

        # Change to tracker directory
        setwd(tracker_dir)

        # Source run_tracker.R
        source("run_tracker.R")

        # Run analysis and capture all console output
        # Use sink() to capture messages to a temporary file
        temp_log <- tempfile(fileext = ".log")
        log_con <- file(temp_log, open = "wt")

        tryCatch({
          # Redirect output and messages to file connection
          sink(log_con, type = "output", split = FALSE)
          sink(log_con, type = "message", split = FALSE)

          output_file <- run_tracker(
            tracking_config_path = tracking_config,
            question_mapping_path = question_mapping,
            data_dir = data_dir,
            output_path = output_path,
            use_banners = input$use_banners
          )

          # Stop redirecting
          sink(type = "message")
          sink(type = "output")
          close(log_con)

          # Read captured output and append to console
          if (file.exists(temp_log)) {
            captured_output <- paste(readLines(temp_log, warn = FALSE), collapse = "\n")
            console_output(paste0(console_output(), captured_output, "\n"))
            unlink(temp_log)
          }
        }, error = function(e) {
          # Make sure sinks are closed even on error
          tryCatch({
            sink(type = "message")
            sink(type = "output")
            close(log_con)
          }, error = function(e2) {})
          stop(e)
        })

        # Save to recent projects
        add_recent_project(list(
          tracking_config = tracking_config,
          question_mapping = question_mapping,
          data_dir = data_dir,
          output_path = output_path,
          use_banners = input$use_banners
        ))

        # Update console with completion message
        console_output(paste0(
          console_output(),
          sprintf("\n%s\n✓ ANALYSIS COMPLETE\n%s\n", strrep("=", 80), strrep("=", 80)),
          sprintf("\nOutput file saved to:\n%s\n", output_file)
        ))

        # Display any warnings that occurred
        if (length(all_warnings) > 0) {
          warning_msg <- paste0("\n\nWarnings encountered:\n", paste(all_warnings, collapse = "\n"))
          console_output(paste0(console_output(), warning_msg))
        }

        showNotification("Tracking analysis completed successfully!", type = "message", duration = 5)

      }, warning = warning_handler), error = function(e) {
        error_msg <- paste0("\n\n", strrep("=", 80), "\nERROR: ", e$message, "\n", strrep("=", 80), "\n\n")
        error_msg <- paste0(error_msg, "Full error:\n", paste(capture.output(print(e)), collapse = "\n"))
        console_output(paste0(console_output(), error_msg))
        showNotification(paste("Error:", e$message), type = "error", duration = 10)

      }, finally = {
        # Restore original working directory
        setwd(old_wd)
        is_running(FALSE)
      })
    })
  }

  # Launch
  cat("\nLaunching Turas>Tracker GUI...\n\n")

  # Set error logging
  options(shiny.error = function() {
    log_file <- file.path(tempdir(), "tracker_gui_error.log")
    tryCatch({
      cat("TRACKER GUI ERROR\n", file = log_file)
      cat("================================================================================\n", file = log_file, append = TRUE)
      cat("Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", file = log_file, append = TRUE)
      cat("Error:", geterrmessage(), "\n\n", file = log_file, append = TRUE)
      cat("Traceback:\n", file = log_file, append = TRUE)
      cat(paste(capture.output(traceback()), collapse = "\n"), file = log_file, append = TRUE)
      cat("\n================================================================================\n", file = log_file, append = TRUE)
      cat("\n\nError log written to:", log_file, "\n")
    }, error = function(e) {})
  })

  shinyApp(ui = ui, server = server)
}
