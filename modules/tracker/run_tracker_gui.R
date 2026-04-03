# ==============================================================================
# TURAS>TRACKER GUI - LAUNCHER
# ==============================================================================
# Purpose: Launch beautiful tracking analysis GUI
# Location: modules/tracker/run_tracker_gui.R
# Usage: source("modules/tracker/run_tracker_gui.R") then run_tracker_gui()
# ==============================================================================

run_tracker_gui <- function() {

  # ==============================================================================
  # TRS v1.0: Load shared refusal infrastructure for proper error handling
  # ==============================================================================
  TURAS_HOME <- Sys.getenv("TURAS_ROOT", getwd())
  trs_refusal_path <- file.path(TURAS_HOME, "modules", "shared", "lib", "trs_refusal.R")

  # Define local refusal function (used if shared infrastructure unavailable)
  # This ensures TRS-compliant error messages even before full infrastructure loads.
  # Uses stop() as the ultimate mechanism since this is the pre-TRS fallback.
  # Throws a turas_refusal condition so handlers can catch it consistently.
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

    # Throw as a turas_refusal condition so handlers can catch it consistently
    cond <- structure(
      class = c("turas_refusal", "error", "condition"),
      list(message = msg, code = code, title = title, problem = problem,
           why_it_matters = why_it_matters, how_to_fix = how_to_fix)
    )
    stop(cond)
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
  TURAS_HOME <- Sys.getenv("TURAS_ROOT", getwd())

  # Load shared GUI theme
  source(file.path(TURAS_HOME, "modules", "shared", "lib", "gui_theme.R"))
  theme <- turas_gui_theme("Tracker", "Multi-Wave Trend Calculation & Testing")
  hide_recents <- turas_hide_recents()

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
    theme$head,

    # Header
    theme$header,

    # Main content
    div(class = "turas-content",

        # Step 1: File Selection
        div(class = "turas-card",
          h3(class = "turas-card-title", "1. Select Tracking Configuration"),
          p(style = "color: #666; font-size: 14px;",
            "Question mapping from config setting, or auto-detected in same directory"),

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

          if (!hide_recents) uiOutput("recent_ui")
        ),

        # Step 2: Additional Options
        uiOutput("options_ui"),

        # Step 3: Run Button
        uiOutput("run_ui"),

        # Step 4: Console Output (static UI - always visible)
        div(class = "turas-card",
          h3(class = "turas-card-title", "4. Analysis Output"),
          div(class = "turas-console",
            verbatimTextOutput("console_text")
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
      mapping_source = NULL     # "config" or "auto-detected"
    )

    console_output <- reactiveVal("")
    is_running <- reactiveVal(FALSE)

    # Auto-load config from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      # Handle directory paths — look for tracking config xlsx inside
      if (dir.exists(pre_config) && !file.exists(pre_config)) {
        dir_path <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
        xlsx_files <- list.files(dir_path, pattern = "\\.(xlsx|xls)$", full.names = TRUE, ignore.case = TRUE)
        tk_files <- grep("track", xlsx_files, value = TRUE, ignore.case = TRUE)
        if (length(tk_files) > 0) {
          pre_config <- tk_files[1]
        } else if (length(xlsx_files) > 0) {
          pre_config <- xlsx_files[1]
        } else {
          pre_config <- ""
        }
      }
    }
    if (nzchar(pre_config) && file.exists(pre_config)) {
      tracking_path <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
      files$tracking_config <- tracking_path

      # Resolve question mapping (same logic as file browse handler)
      config_dir <- dirname(tracking_path)
      question_map_path <- NULL
      mapping_source <- NULL

      # Try reading question_mapping_file from config Settings sheet
      tryCatch({
        raw_df <- openxlsx::read.xlsx(tracking_path, sheet = "Settings",
                                      colNames = FALSE, skipEmptyRows = FALSE)
        header_row <- which(raw_df[[1]] == "Setting" | raw_df[[1]] == "SettingName")[1]
        if (!is.na(header_row)) {
          settings_df <- openxlsx::read.xlsx(tracking_path, sheet = "Settings",
                                             startRow = header_row)
        } else {
          settings_df <- openxlsx::read.xlsx(tracking_path, sheet = "Settings")
        }
        setting_col <- if ("Setting" %in% names(settings_df)) "Setting" else "SettingName"
        if (setting_col %in% names(settings_df) && "Value" %in% names(settings_df)) {
          idx <- which(settings_df[[setting_col]] == "question_mapping_file")
          if (length(idx) > 0) {
            val <- trimws(settings_df$Value[idx[1]])
            if (!is.na(val) && nzchar(val)) {
              val <- path.expand(val)
              val <- gsub("^\\./", "", val)
              if (!grepl("^/|^[A-Za-z]:", val)) val <- file.path(config_dir, val)
              val <- normalizePath(val, winslash = "/", mustWork = FALSE)
              if (file.exists(val)) {
                question_map_path <- val
                mapping_source <- "config"
              }
            }
          }
        }
      }, error = function(e) NULL)

      # Fall back to auto-detection
      if (is.null(question_map_path)) {
        possible_names <- c(
          "question_mapping.xlsx", "Question_Mapping.xlsx", "QuestionMapping.xlsx",
          paste0(gsub("_tracking_config\\.xlsx$|_config\\.xlsx$", "", basename(tracking_path)), "_question_mapping.xlsx")
        )
        for (name in possible_names) {
          test_path <- file.path(config_dir, name)
          if (file.exists(test_path)) {
            question_map_path <- test_path
            mapping_source <- "auto-detected"
            break
          }
        }
        if (is.null(question_map_path)) {
          xlsx_files <- list.files(config_dir, pattern = "mapping.*\\.xlsx$", ignore.case = TRUE, full.names = TRUE)
          if (length(xlsx_files) > 0) {
            question_map_path <- xlsx_files[1]
            mapping_source <- "auto-detected"
          }
        }
      }

      files$question_mapping <- question_map_path
      files$mapping_source <- mapping_source
    }

    # File choosers
    volumes <- turas_gui_volumes()

    shinyFileChoose(input, "tracking_config_btn", roots = volumes, session = session,
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

            # Resolve question mapping: config setting first, then auto-detect
            config_dir <- dirname(tracking_path)
            question_map_path <- NULL
            mapping_source <- NULL

            # Try reading question_mapping_file from config Settings sheet
            tryCatch({
              # Read raw to find header row (styled templates have title rows above)
              raw_df <- openxlsx::read.xlsx(tracking_path, sheet = "Settings",
                                            colNames = FALSE, skipEmptyRows = FALSE)
              header_row <- which(raw_df[[1]] == "Setting" | raw_df[[1]] == "SettingName")[1]
              if (!is.na(header_row)) {
                settings_df <- openxlsx::read.xlsx(tracking_path, sheet = "Settings",
                                                   startRow = header_row)
              } else {
                settings_df <- openxlsx::read.xlsx(tracking_path, sheet = "Settings")
              }
              setting_col <- if ("Setting" %in% names(settings_df)) "Setting" else "SettingName"
              if (setting_col %in% names(settings_df) && "Value" %in% names(settings_df)) {
                idx <- which(settings_df[[setting_col]] == "question_mapping_file")
                if (length(idx) > 0) {
                  val <- trimws(settings_df$Value[idx[1]])
                  if (!is.na(val) && nzchar(val)) {
                    val <- path.expand(val)
                    val <- gsub("^\\./", "", val)
                    if (!grepl("^/|^[A-Za-z]:", val)) {
                      val <- file.path(config_dir, val)
                    }
                    val <- normalizePath(val, winslash = "/", mustWork = FALSE)
                    if (file.exists(val)) {
                      question_map_path <- val
                      mapping_source <- "config"
                    }
                  }
                }
              }
            }, error = function(e) {
              # Silently continue to auto-detection if config read fails
            })

            # Fall back to auto-detection if not found in config
            if (is.null(question_map_path)) {
              possible_names <- c(
                "question_mapping.xlsx",
                "Question_Mapping.xlsx",
                "QuestionMapping.xlsx",
                paste0(gsub("_tracking_config\\.xlsx$|_config\\.xlsx$", "", basename(tracking_path)), "_question_mapping.xlsx")
              )

              for (name in possible_names) {
                test_path <- file.path(config_dir, name)
                if (file.exists(test_path)) {
                  question_map_path <- test_path
                  mapping_source <- "auto-detected"
                  break
                }
              }

              # Last resort: search for any mapping*.xlsx
              if (is.null(question_map_path)) {
                xlsx_files <- list.files(config_dir, pattern = "mapping.*\\.xlsx$", ignore.case = TRUE, full.names = TRUE)
                if (length(xlsx_files) > 0) {
                  question_map_path <- xlsx_files[1]
                  mapping_source <- "auto-detected"
                }
              }
            }

            files$question_mapping <- question_map_path
            files$mapping_source <- mapping_source

            if (is.null(question_map_path)) {
              showNotification("Question mapping file not found. Set 'question_mapping_file' in config Settings or place it in the same directory.",
                             type = "warning", duration = 5)
            }
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
        files$mapping_source <- proj$mapping_source
        if (!is.null(proj$use_banners)) {
          updateCheckboxInput(session, "use_banners", value = proj$use_banners)
        }
        if (!is.null(proj$enable_html)) {
          updateCheckboxInput(session, "enable_html", value = proj$enable_html)
        }
      }
    })

    # Display tracking config
    output$tracking_config_display <- renderUI({
      if (is.null(files$tracking_config)) {
        div(class = "turas-status-info",
          icon("info-circle"), " No file selected"
        )
      } else {
        div(class = "turas-file-display",
          tags$strong(basename(files$tracking_config)),
          tags$br(),
          tags$small(files$tracking_config),
          if (file.exists(files$tracking_config)) {
            div(class = "turas-status-success", style = "margin-top: 10px;",
              icon("check-circle"), " File found"
            )
          } else {
            div(class = "turas-status-warning", style = "margin-top: 10px;",
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
          div(class = "file-label", style = "margin-top: 15px;",
            paste0("Question Mapping (",
                   if (!is.null(files$mapping_source)) files$mapping_source else "auto-detected",
                   "):")),
          div(class = "turas-file-display",
            tags$strong(basename(files$question_mapping)),
            tags$br(),
            tags$small(files$question_mapping),
            if (file.exists(files$question_mapping)) {
              div(class = "turas-status-success", style = "margin-top: 10px;",
                icon("check-circle"), " File found"
              )
            } else {
              div(class = "turas-status-warning", style = "margin-top: 10px;",
                icon("exclamation-triangle"), " File not found"
              )
            }
          )
        )
      }
    })

    # Recent projects
    output$recent_ui <- renderUI({
      if (hide_recents) return(NULL)
      recent <- load_recent_projects()
      if (length(recent) == 0) return(NULL)

      div(class = "turas-recent-section",
        tags$hr(),
        h4("Recent Projects"),
        lapply(seq_along(recent), function(i) {
          proj <- recent[[i]]
          tags$div(
            class = "turas-recent-item",
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

      div(class = "turas-card",
        h3(class = "turas-card-title", "2. Additional Options (Optional)"),

        checkboxInput("use_banners",
                     "Calculate trends with banner breakouts (Phase 3)",
                     value = TRUE),
        p(style = "font-size: 13px; color: #666;",
          "When enabled, calculates trends for Total and banner segments defined in config"),

        tags$hr(),

        checkboxInput("enable_html",
                     "Generate interactive HTML report",
                     value = TRUE),
        p(style = "font-size: 13px; color: #666;",
          "Creates a self-contained HTML report with charts, filtering, and export features alongside the Excel output"),

        tags$hr(),

        checkboxInput("generate_stats_pack",
                      "Generate stats pack (diagnostic workbook for advanced review)",
                      value = FALSE),
        p(style = "font-size: 13px; color: #666;",
          "Produces a standalone Excel workbook recording all assumptions, wave parameters, and TRS events for review")
      )
    })

    # Run button UI
    output$run_ui <- renderUI({
      if (is.null(files$tracking_config) || is.null(files$question_mapping)) return(NULL)

      can_run <- !is.null(files$tracking_config) &&
                 !is.null(files$question_mapping) &&
                 file.exists(files$tracking_config) &&
                 file.exists(files$question_mapping)

      div(class = "turas-card",
        h3(class = "turas-card-title", "3. Run Tracking Analysis"),
        if (!can_run) {
          div(class = "turas-status-warning",
            icon("exclamation-triangle"), " Please select valid configuration files to continue"
          )
        },
        div(style = "text-align: center; margin: 20px 0;",
          actionButton("run_btn",
                      "RUN TRACKING ANALYSIS",
                      class = "turas-btn-run",
                      icon = icon("play-circle"),
                      disabled = !can_run || is_running()),
          div(style = "margin-top: 12px;",
            checkboxInput("prepare_deliverable",
                         "Prepare client deliverable (minify for delivery)",
                         value = FALSE)
          )
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

        # Let run_tracker() resolve output path from config settings
        # Priority in run_tracker(): 1) output_dir/output_file from config, 2) config directory
        config_dir <- dirname(tracking_config)
        data_dir <- config_dir

        # Build paths
        tracker_dir <- file.path(TURAS_HOME, "modules", "tracker")
        run_script <- file.path(tracker_dir, "run_tracker.R")

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
        setwd(tracker_dir)

        # Pass deliverable flag and load minification functions if needed
        assign("TURAS_PREPARE_DELIVERABLE",
               isTRUE(input$prepare_deliverable), envir = .GlobalEnv)
        if (isTRUE(input$prepare_deliverable)) {
          .minify_dir <- file.path(TURAS_HOME, "modules", "shared", "lib")
          if (!exists("turas_prepare_deliverable", mode = "function")) {
            source(file.path(.minify_dir, "turas_minify_verify.R"), local = FALSE)
            source(file.path(.minify_dir, "turas_minify.R"), local = FALSE)
          }
        }

        # Source run_tracker.R
        progress$set(value = 0.2, detail = "Loading tracker modules...")
        source("run_tracker.R")

        # Set stats pack option before calling run_tracker
        options(turas.generate_stats_pack = isTRUE(input$generate_stats_pack))

        # Run analysis and capture ALL console output
        progress$set(value = 0.3, detail = "Running tracker analysis...")

        output_capture_file <- tempfile()
        sink(output_capture_file, type = "output")

        analysis_result <- tryCatch({
          output_file <- run_tracker(
            tracking_config_path = tracking_config,
            question_mapping_path = question_mapping,
            data_dir = data_dir,
            output_path = NULL,
            use_banners = input$use_banners,
            enable_html = input$enable_html
          )
          list(success = TRUE, output_file = output_file, error = NULL)

        }, error = function(e) {
          list(success = FALSE, output_file = NULL, error = e)

        }, finally = {
          # Always restore console output
          sink(type = "output")
        })

        progress$set(value = 0.9, detail = "Finalizing...")

        # Read captured output (available even if error occurred)
        captured_output <- readLines(output_capture_file, warn = FALSE)
        unlink(output_capture_file)

        # Display captured output in console
        if (length(captured_output) > 0) {
          console_output(paste(captured_output, collapse = "\n"))
        } else {
          console_output("Tracker completed but produced no console output.")
        }

        # Extract output_file and show completion message
        if (analysis_result$success) {
          output_file <- analysis_result$output_file

          # Save to recent projects
          add_recent_project(list(
            tracking_config = tracking_config,
            question_mapping = question_mapping,
            mapping_source = files$mapping_source,
            use_banners = input$use_banners,
            enable_html = input$enable_html
          ))

          # Update console with completion message
          completion_msg <- sprintf("\n%s\n✓ ANALYSIS COMPLETE\n%s\n", strrep("=", 80), strrep("=", 80))
          if (is.list(output_file)) {
            # Multiple output files
            completion_msg <- paste0(completion_msg, "\nOutput files saved to:\n")
            for (report_type in names(output_file)) {
              completion_msg <- paste0(completion_msg, sprintf("  %s: %s\n", report_type, output_file[[report_type]]))
            }
          } else {
            # Single output file
            completion_msg <- paste0(completion_msg, sprintf("\nOutput file saved to:\n%s\n", output_file))
          }
          console_output(paste0(console_output(), completion_msg))
        } else {
          # Analysis failed
          error_msg <- sprintf("\n%s\n✗ ANALYSIS FAILED\n%s\n", strrep("=", 80), strrep("=", 80))
          if (!is.null(analysis_result$error)) {
            error_msg <- paste0(error_msg, sprintf("\nError: %s\n", analysis_result$error$message))
          }
          console_output(paste0(console_output(), error_msg))
        }

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
