# ==============================================================================
# TURAS>TRACKER GUI - LAUNCHER
# ==============================================================================
# Purpose: Launch beautiful tracking analysis GUI
# Location: modules/tracker/run_tracker_gui.R
# Usage: source("modules/tracker/run_tracker_gui.R") then run_tracker_gui()
# ==============================================================================

run_tracker_gui <- function() {

  # Version marker for debugging
  cat("[Tracker GUI] Version 2.0 - Starting...\n")
  cat("[Tracker GUI] Working directory:", getwd(), "\n")

  # ==============================================================================
  # TRS v1.0: Load shared refusal infrastructure for proper error handling
  # ==============================================================================
  TURAS_HOME <- getwd()
  trs_refusal_path <- file.path(TURAS_HOME, "modules", "shared", "lib", "trs_refusal.R")

  # Define local refusal function (used if shared infrastructure unavailable)
  # This ensures TRS-compliant error messages even before full infrastructure loads
  gui_refuse <- function(code, title, problem, why_it_matters, how_to_fix, details = NULL) {
    # Ensure code has valid TRS prefix
    if (!grepl("^(CFG_|DATA_|IO_|MODEL_|MAPPER_|PKG_|FEATURE_|BUG_)", code)) {
      code <- paste0("CFG_", code)
    }

    msg <- paste0(
      "\n", strrep("=", 80), "\n",
      "  [REFUSE] ", code, ": ", title, "\n",
      strrep("=", 80), "\n\n",
      "Problem:\n  ", problem, "\n\n",
      "Why it matters:\n  ", why_it_matters, "\n\n",
      "How to fix:\n  ", how_to_fix, "\n"
    )
    if (!is.null(details)) {
      msg <- paste0(msg, "\nDetails:\n  ", details, "\n")
    }
    msg <- paste0(msg, "\n", strrep("=", 80), "\n")
    stop(msg, call. = FALSE)
  }

  # Try to load TRS infrastructure for turas_refuse
  if (file.exists(trs_refusal_path)) {
    tryCatch({
      source(trs_refusal_path, local = FALSE)
      # If turas_refuse is now available, use it instead of gui_refuse
      if (exists("turas_refuse", mode = "function")) {
        gui_refuse <- function(code, title, problem, why_it_matters, how_to_fix, details = NULL) {
          turas_refuse(
            code = code,
            title = title,
            problem = problem,
            why_it_matters = why_it_matters,
            how_to_fix = how_to_fix,
            details = details,
            module = "TRACKER"
          )
        }
      }
    }, error = function(e) {
      # Silently continue with local gui_refuse if TRS load fails
    })
  }

  # Required packages - check availability (TRS v1.0: no auto-install)
  required_packages <- c("shiny", "shinyFiles")

  # Check for missing packages and refuse with clear instructions if any are missing
  missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  if (length(missing_packages) > 0) {
    gui_refuse(
      code = "PKG_MISSING_DEPENDENCY",
      title = "Missing Required Packages",
      problem = paste0("The following required packages are not installed: ",
                       paste(missing_packages, collapse = ", ")),
      why_it_matters = "The Tracker GUI cannot run without these packages.",
      how_to_fix = paste0("Run the following command in R:\n    install.packages(c(",
                          paste(sprintf('"%s"', missing_packages), collapse = ", "), "))")
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

        # Step 4: Console Output (static UI - always visible)
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
            # Expand tilde and normalize path (fixes OneDrive/home directory paths)
            tracking_path <- normalizePath(path.expand(as.character(file_path$datapath[1])),
                                          winslash = "/", mustWork = FALSE)
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
          # Expand tilde and normalize path (fixes OneDrive/home directory paths)
          dir_path <- normalizePath(path.expand(dir_path), winslash = "/", mustWork = FALSE)
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
            # Expand tilde and normalize path (fixes OneDrive/home directory paths)
            files$output_path <- normalizePath(path.expand(as.character(file_path$datapath[1])),
                                              winslash = "/", mustWork = FALSE)
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
        # Expand tilde and normalize paths (fixes OneDrive/home directory paths)
        files$tracking_config <- normalizePath(path.expand(proj$tracking_config),
                                              winslash = "/", mustWork = FALSE)
        files$question_mapping <- normalizePath(path.expand(proj$question_mapping),
                                               winslash = "/", mustWork = FALSE)
        if (!is.null(proj$data_dir)) {
          files$data_dir <- normalizePath(path.expand(proj$data_dir),
                                         winslash = "/", mustWork = FALSE)
        }
        if (!is.null(proj$output_path)) {
          files$output_path <- normalizePath(path.expand(proj$output_path),
                                            winslash = "/", mustWork = FALSE)
        }
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

    # Console output - static UI, always present
    output$console_text <- renderText({
      current_output <- console_output()

      # Ensure single string for R 4.2+ compatibility
      # If vector, collapse it; if empty/NULL, return placeholder
      if (is.null(current_output) || length(current_output) == 0 || nchar(current_output[1]) == 0) {
        "Console output will appear here when you run the tracker..."
      } else {
        # Ensure it's a single string
        if (length(current_output) > 1) {
          paste(current_output, collapse = "\n")
        } else {
          current_output
        }
      }
    })

    # Run analysis
    observeEvent(input$run_btn, {
      req(files$tracking_config, files$question_mapping)

      is_running(TRUE)
      session$userData$has_run <- TRUE

      # Clear previous console output
      console_output("")

      # Create progress indicator
      progress <- Progress$new(session)
      progress$set(message = "Running Tracker Analysis", value = 0)
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
        # Validate and ensure all paths are character strings
        tracking_config <- files$tracking_config
        question_mapping <- files$question_mapping

        # Expand paths (resolve ~ and relative paths)
        tracking_config <- normalizePath(tracking_config, mustWork = FALSE)
        question_mapping <- normalizePath(question_mapping, mustWork = FALSE)

        # Validate inputs
        progress$set(value = 0.1, detail = "Validating inputs...")

        # Ensure character
        if (!is.character(tracking_config) || length(tracking_config) != 1) {
          gui_refuse(
            code = "CFG_INVALID_PATH",
            title = "Invalid Tracking Config Path",
            problem = "Tracking config path is not a single character string.",
            why_it_matters = "The tracker requires a valid file path to locate the configuration.",
            how_to_fix = "Select a valid tracking_config.xlsx file using the file browser."
          )
        }
        if (!is.character(question_mapping) || length(question_mapping) != 1) {
          gui_refuse(
            code = "CFG_INVALID_PATH",
            title = "Invalid Question Mapping Path",
            problem = "Question mapping path is not a single character string.",
            why_it_matters = "The tracker requires a valid file path to locate the question mapping.",
            how_to_fix = "Ensure a question_mapping.xlsx file exists in the same directory as the config."
          )
        }

        # Validate files exist
        if (!file.exists(tracking_config)) {
          gui_refuse(
            code = "IO_FILE_NOT_FOUND",
            title = "Tracking Config File Not Found",
            problem = paste0("Tracking config file not found: ", tracking_config),
            why_it_matters = "The tracker cannot run without a valid configuration file.",
            how_to_fix = "Verify the file exists at the specified path or select a different file."
          )
        }
        if (!file.exists(question_mapping)) {
          gui_refuse(
            code = "IO_FILE_NOT_FOUND",
            title = "Question Mapping File Not Found",
            problem = paste0("Question mapping file not found: ", question_mapping),
            why_it_matters = "The tracker cannot map survey questions without the mapping file.",
            how_to_fix = "Ensure question_mapping.xlsx exists in the same directory as tracking_config.xlsx."
          )
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

        cat("[Tracker GUI] TURAS_HOME:", TURAS_HOME, "\n")
        cat("[Tracker GUI] tracker_dir:", tracker_dir, "\n")
        cat("[Tracker GUI] run_script:", run_script, "\n")
        cat("[Tracker GUI] run_script exists:", file.exists(run_script), "\n")

        if (!file.exists(run_script)) {
          gui_refuse(
            code = "IO_SCRIPT_NOT_FOUND",
            title = "Tracker Module Not Found",
            problem = paste0("Could not find run_tracker.R at: ", run_script),
            why_it_matters = "The tracker analysis script is required to run the analysis.",
            how_to_fix = "Ensure the Turas installation is complete and run_tracker.R exists in modules/tracker/."
          )
        }

        # Change to tracker directory
        cat("[Tracker GUI] tracker_dir =", tracker_dir, "\n")
        cat("[Tracker GUI] tracker_dir exists:", dir.exists(tracker_dir), "\n")
        setwd(tracker_dir)
        cat("[Tracker GUI] After setwd, getwd() =", getwd(), "\n")

        # Source run_tracker.R
        progress$set(value = 0.2, detail = "Loading tracker modules...")
        cat("[Tracker GUI] run_script =", run_script, "\n")
        cat("[Tracker GUI] file.exists(run_script) =", file.exists(run_script), "\n")
        cat("[Tracker GUI] file.access(run_script, mode=4) =", file.access(run_script, mode = 4), "\n")
        cat("[Tracker GUI] file.info(run_script)$size =", file.info(run_script)$size, "\n")

        # Try reading first line to test file access
        test_read <- tryCatch({
          first_line <- readLines(run_script, n = 1, warn = FALSE)
          paste0("OK: '", substr(first_line, 1, 50), "...'")
        }, error = function(e) {
          paste0("FAILED: ", e$message)
        })
        cat("[Tracker GUI] Test read first line:", test_read, "\n")

        tryCatch({
          # Use full path (run_script) that was already verified to exist
          cat("[Tracker GUI] About to call source()...\n")
          source(run_script)
          cat("[Tracker GUI] run_tracker.R loaded successfully\n")
        }, error = function(e) {
          gui_refuse(
            code = "IO_SOURCE_FAILED",
            title = "Failed to Load Tracker Module",
            problem = paste0("Could not source run_tracker.R: ", e$message),
            why_it_matters = "The tracker module must be loaded before analysis can run.",
            how_to_fix = c(
              "Check that all tracker module files exist in modules/tracker/",
              "Verify no syntax errors in the R files",
              paste0("Current directory: ", getwd()),
              paste0("run_script path: ", run_script)
            )
          )
        })

        # Run analysis and capture ALL console output
        progress$set(value = 0.3, detail = "Running tracker analysis...")

        # Create temp file explicitly (tempfile() only returns path, doesn't create file)
        output_capture_file <- tempfile(fileext = ".txt")
        file.create(output_capture_file)

        # Try to capture output, but don't fail if sink doesn't work
        sink_active <- tryCatch({
          sink(output_capture_file, type = "output")
          TRUE
        }, error = function(e) {
          FALSE
        })

        analysis_result <- tryCatch({
          output_file <- run_tracker(
            tracking_config_path = tracking_config,
            question_mapping_path = question_mapping,
            data_dir = data_dir,
            output_path = output_path,
            use_banners = input$use_banners
          )
          list(success = TRUE, output_file = output_file, error = NULL)

        }, error = function(e) {
          list(success = FALSE, output_file = NULL, error = e)

        }, finally = {
          # Always restore console output if sink was active
          if (sink_active) {
            tryCatch(sink(type = "output"), error = function(e) NULL)
          }
        })

        progress$set(value = 0.9, detail = "Finalizing...")

        # Read captured output (available even if error occurred)
        captured_output <- tryCatch({
          if (file.exists(output_capture_file)) {
            readLines(output_capture_file, warn = FALSE)
          } else {
            character(0)
          }
        }, error = function(e) {
          character(0)
        })
        tryCatch(unlink(output_capture_file), error = function(e) NULL)

        # Display captured output in console
        if (length(captured_output) > 0) {
          console_output(paste(captured_output, collapse = "\n"))
        } else {
          console_output("Tracker completed but produced no console output.")
        }

        # Extract output_file
        if (analysis_result$success) {
          output_file <- analysis_result$output_file
        }

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
          console_output(paste0(console_output(), "\n", warning_msg))
        }

        progress$set(value = 1.0, detail = "Complete!")
        showNotification("Tracking analysis completed successfully!", type = "message", duration = 5)

      }, warning = warning_handler), error = function(e) {
        error_msg <- paste0(strrep("=", 80), "\nERROR: ", e$message, "\n", strrep("=", 80), "\n\n")
        error_msg <- paste0(error_msg, "Full error:\n", paste(capture.output(print(e)), collapse = "\n"), "\n\n")
        error_msg <- paste0(error_msg, "Traceback:\n", paste(capture.output(traceback()), collapse = "\n"))
        console_output(paste0(console_output(), "\n\n", error_msg))
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
