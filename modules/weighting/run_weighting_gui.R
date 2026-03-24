# ==============================================================================
# TURAS WEIGHTING MODULE - SHINY GUI
# ==============================================================================
#
# Version: 3.0
# Date: 2026-03-06
#
# DESCRIPTION:
# Graphical user interface for the weighting module.
# Provides point-and-click access to weight calculation.
#
# USAGE:
#   source("modules/weighting/run_weighting_gui.R")
#   run_weighting_gui()
#
# ==============================================================================

# Check required GUI packages
if (!requireNamespace("shiny", quietly = TRUE)) {
  stop(paste0(
    "[REFUSE] PKG_SHINY_MISSING: Shiny Package Required\n\n",
    "Problem: Package 'shiny' is not installed.\n",
    "How to fix: Install with: install.packages('shiny')"
  ), call. = FALSE)
}
if (!requireNamespace("shinyFiles", quietly = TRUE)) {
  stop(paste0(
    "[REFUSE] PKG_SHINYFILES_MISSING: shinyFiles Package Required\n\n",
    "Problem: Package 'shinyFiles' is not installed.\n",
    "How to fix: Install with: install.packages('shinyFiles')"
  ), call. = FALSE)
}

#' Run Weighting Module GUI
#'
#' Launches the Shiny interface for weight calculation.
#'
#' @param launch_browser Logical, open in browser (default: TRUE)
#' @export
run_weighting_gui <- function(launch_browser = TRUE) {

  # Load Shiny packages into function scope (requireNamespace check already done above)
  library(shiny)
  library(shinyFiles)

  # Get module directory
  module_dir <- tryCatch({
    if (!is.null(sys.frame(1)$ofile)) {
      dirname(sys.frame(1)$ofile)
    } else {
      # Fallback methods
      if (file.exists("run_weighting_gui.R")) {
        getwd()
      } else if (file.exists("modules/weighting/run_weighting_gui.R")) {
        file.path(getwd(), "modules/weighting")
      } else {
        getwd()
      }
    }
  }, error = function(e) getwd())

  # Find TURAS root for shared utilities
  turas_root <- tryCatch({
    root <- Sys.getenv("TURAS_ROOT", "")
    if (nzchar(root) && dir.exists(file.path(root, "modules"))) {
      root
    } else {
      # Try to find from module directory
      check <- dirname(dirname(module_dir))
      if (dir.exists(file.path(check, "modules", "shared"))) {
        check
      } else {
        NULL
      }
    }
  }, error = function(e) NULL)

  # Load shared GUI theme
  if (!is.null(turas_root)) {
    source(file.path(turas_root, "modules", "shared", "lib", "gui_theme.R"))
    theme <- turas_gui_theme("Weighting", "Sample Weighting & Rim Weighting")
    hide_recents <- turas_hide_recents()
  }

  # Source shared library for TRS compliance (includes atomic save, console capture, etc.)
  shared_loaded <- FALSE
  if (!is.null(turas_root)) {
    shared_import <- file.path(turas_root, "modules", "shared", "lib", "import_all.R")
    if (file.exists(shared_import)) {
      tryCatch({
        source(shared_import, local = FALSE)
        shared_loaded <- TRUE
      }, error = function(e) {
        warning(paste("Failed to load shared library:", e$message), call. = FALSE)
      })
    }

    # Fallback to just console capture if full import failed
    if (!shared_loaded) {
      console_capture_file <- file.path(turas_root, "modules", "shared", "lib", "console_capture.R")
      if (file.exists(console_capture_file)) {
        source(console_capture_file, local = FALSE)
      }
    }
  }

  # Warn if shared library not loaded
  if (!shared_loaded) {
    warning(
      "Shared library not loaded. Some features may not work correctly.\n",
      "  Expected location: ", if (!is.null(turas_root)) file.path(turas_root, "modules/shared/lib/import_all.R") else "[TURAS root not found]",
      call. = FALSE
    )
  }

  # Source module libraries
  lib_dir <- file.path(module_dir, "lib")
  if (dir.exists(lib_dir)) {
    lib_files <- c("00_guard.R", "validation.R", "config_loader.R",
                   "design_weights.R", "rim_weights.R", "cell_weights.R",
                   "trimming.R", "diagnostics.R", "output.R")
    for (f in lib_files) {
      lib_path <- file.path(lib_dir, f)
      if (file.exists(lib_path)) {
        source(lib_path, local = FALSE)
      }
    }
  }

  # Source main run file
  main_file <- file.path(module_dir, "run_weighting.R")
  if (file.exists(main_file)) {
    source(main_file, local = FALSE)
  }

  # ===========================================================================
  # HELPER FUNCTIONS
  # ===========================================================================

  # Detect weight config files in directory
  detect_config_files <- function(dir) {
    if (!dir.exists(dir)) return(character(0))
    files <- list.files(dir, pattern = "\\.xlsx$", full.names = FALSE, ignore.case = TRUE)
    config_patterns <- c("weight.*config", "config.*weight", "weighting.*config", "config")
    detected <- character(0)
    for (pattern in config_patterns) {
      matches <- grep(pattern, files, ignore.case = TRUE, value = TRUE)
      detected <- c(detected, matches)
    }
    unique(detected)
  }

  # ===========================================================================
  # UI DEFINITION
  # ===========================================================================
  ui <- fluidPage(

    theme$head,

    # Module-specific CSS (metric indicators, notification positioning)
    tags$style(HTML("
      .metric-good { color: #28a745; }
      .metric-acceptable { color: #ffc107; }
      .metric-poor { color: #dc3545; }
      .shiny-notification {
        position: fixed;
        top: calc(50% - 100px);
        left: calc(50% - 200px);
        width: 400px;
      }
      .progress {
        height: 25px;
        border-radius: 6px;
        margin-bottom: 10px;
      }
      .progress-bar {
        font-size: 14px;
        line-height: 25px;
        font-weight: 600;
      }
      .shiny-progress .progress-text {
        font-size: 14px;
        font-weight: 500;
      }
    ")),

    # Header
    theme$header,

    div(class = "turas-content",

      # Folder Selection
      div(class = "turas-card",
        h3(class = "turas-card-title", "1. Select Project Folder"),

        # Recent folders dropdown (hidden when launched from hub)
        if (!hide_recents) {
          tagList(
            conditionalPanel(
              condition = "output.has_recent_folders",
              selectInput("recent_folder", "Recent Folders",
                          choices = NULL,
                          width = "100%"),
              div(class = "turas-help-text", style = "margin-top: -10px; margin-bottom: 15px;",
                  "Select from recently used folders or browse/enter path below")
            )
          )
        },

      # Folder path with browse button
      fluidRow(
        column(9,
          textInput("project_folder", "Project Folder Path",
                    placeholder = "e.g., path/to/your/weighting/project/folder",
                    width = "100%")
        ),
        column(3,
          div(style = "margin-top: 25px;",
            shinyDirButton("folder_browse", "Browse...",
                         title = "Select project folder",
                         class = "btn btn-default")
          )
        )
      ),
      div(class = "turas-help-text",
          "Select or enter the folder path containing your Weight_Config.xlsx and data file"),

      # Config file selector (shows when folder is selected)
      conditionalPanel(
        condition = "output.folder_selected",
        div(style = "margin-top: 20px;",
          uiOutput("config_selector"),
          div(class = "turas-help-text",
              "Select a config file from the detected files in the folder above, or enter a custom filename")
        )
      )
      ),

      # Options Section
      div(class = "turas-card",
        h3(class = "turas-card-title", "2. Options"),

        fluidRow(
          column(4,
            shiny::checkboxInput("save_output", "Save weighted data to file", value = TRUE)
          ),
          column(4,
            shiny::checkboxInput("save_diagnostics", "Save diagnostic report", value = TRUE)
          ),
          column(4,
            shiny::checkboxInput("generate_html", "Generate HTML report", value = FALSE)
          )
        ),

        fluidRow(
          column(12,
            checkboxInput("generate_stats_pack",
                          "Generate stats pack (diagnostic workbook for advanced review)",
                          value = FALSE)
          )
        ),

        # Run Button
        div(style = "text-align: center; margin-top: 20px;",
          actionButton("run_weighting", "Calculate Weights",
                      class = "turas-btn-run",
                      icon = icon("calculator"))
        )
      ),

      # Progress Section
      div(class = "turas-card",
        h3(class = "turas-card-title", "3. Progress"),
        div(class = "turas-console",
          verbatimTextOutput("progress_log")
        )
      ),

      # Results Section
      conditionalPanel(
        condition = "output.has_results",
        div(class = "turas-card",
          h3(class = "turas-card-title", "4. Results"),
          uiOutput("results_summary")
        ),

        div(class = "turas-card",
          h3(class = "turas-card-title", "Weight Diagnostics"),
          tableOutput("diagnostics_table")
        ),

        div(class = "turas-card",
          h3(class = "turas-card-title", "Output Files"),
          uiOutput("output_files")
        )
      )
    )
  )

  # ===========================================================================
  # SERVER LOGIC
  # ===========================================================================
  server <- function(input, output, session) {

    # Reactive values
    rv <- reactiveValues(
      result = NULL,
      log = "",
      running = FALSE,
      recent_folders = character(0),
      selected_config = NULL
    )

    # Auto-load config from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      if (dir.exists(pre_config)) {
        # Directory passed — look for a weighting config xlsx inside
        dir_path <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
        xlsx_files <- list.files(dir_path, pattern = "\\.(xlsx|xls)$", full.names = TRUE, ignore.case = TRUE)
        wt_files <- grep("weight", xlsx_files, value = TRUE, ignore.case = TRUE)
        if (length(wt_files) > 0) {
          rv$selected_config <- wt_files[1]
        } else if (length(xlsx_files) > 0) {
          rv$selected_config <- xlsx_files[1]
        }
      } else if (file.exists(pre_config)) {
        rv$selected_config <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
      }
    }

    # Recent folders file location (persistent across sessions)
    # Use Turas root directory for consistency with other modules
    recent_folders_file <- file.path(turas_root, ".turas_weighting_recent_folders.rds")

    # Load recent folders on startup
    observe({
      if (file.exists(recent_folders_file)) {
        rv$recent_folders <- tryCatch(
          readRDS(recent_folders_file),
          error = function(e) character(0)
        )
      }
    })

    # Update recent folders dropdown
    observe({
      if (length(rv$recent_folders) > 0) {
        # Create named list for dropdown (display basename, value is full path)
        choices <- setNames(rv$recent_folders, basename(rv$recent_folders))
        updateSelectInput(session, "recent_folder",
                         choices = c("-- Select recent folder --" = "", choices))
      }
    })

    # Flag for whether recent folders exist
    output$has_recent_folders <- reactive({
      length(rv$recent_folders) > 0
    })
    outputOptions(output, "has_recent_folders", suspendWhenHidden = FALSE)

    # When recent folder selected, update text input
    observeEvent(input$recent_folder, {
      if (!is.null(input$recent_folder) && input$recent_folder != "") {
        updateTextInput(session, "project_folder", value = input$recent_folder)
      }
    })

    # Folder browser setup
    volumes <- turas_gui_volumes()
    shinyDirChoose(input, "folder_browse", roots = volumes, session = session)

    # Update text input when folder is selected via browser
    observeEvent(input$folder_browse, {
      if (!is.null(input$folder_browse)) {
        # Get selected path
        selected_path <- parseDirPath(volumes, input$folder_browse)
        if (length(selected_path) > 0) {
          updateTextInput(session, "project_folder", value = selected_path)
        }
      }
    })

    # Function to add folder to recent list
    add_to_recent_folders <- function(folder_path) {
      if (!is.null(folder_path) && nzchar(folder_path) && dir.exists(folder_path)) {
        # Normalize path
        folder_path <- normalizePath(folder_path, winslash = "/")

        # Remove if already exists (will re-add at top)
        rv$recent_folders <- setdiff(rv$recent_folders, folder_path)

        # Add to front, limit to 5 most recent
        rv$recent_folders <- c(folder_path, rv$recent_folders)
        if (length(rv$recent_folders) > 5) {
          rv$recent_folders <- rv$recent_folders[1:5]
        }

        # Save to file
        tryCatch({
          saveRDS(rv$recent_folders, recent_folders_file)
        }, error = function(e) {
          # Silently fail if can't save
        })
      }
    }

    # Folder selected flag
    output$folder_selected <- reactive({
      !is.null(input$project_folder) &&
      nzchar(input$project_folder) &&
      dir.exists(input$project_folder)
    })
    outputOptions(output, "folder_selected", suspendWhenHidden = FALSE)

    # Config file selector UI
    output$config_selector <- renderUI({
      req(input$project_folder)
      if (!dir.exists(input$project_folder)) {
        return(NULL)
      }

      configs <- detect_config_files(input$project_folder)

      if (length(configs) > 0) {
        # Show detected config files as radio buttons
        tagList(
          radioButtons("config_select",
                      label = "Detected config files:",
                      choices = configs,
                      selected = if (!is.null(rv$selected_config) && rv$selected_config %in% configs) {
                        rv$selected_config
                      } else {
                        configs[1]
                      }),
          # Option for custom filename
          checkboxInput("use_custom_config", "Use custom filename", value = FALSE),
          conditionalPanel(
            condition = "input.use_custom_config == true",
            textInput("custom_config_name", "Custom config filename:",
                     value = "Weight_Config.xlsx",
                     placeholder = "e.g., My_Weight_Config.xlsx")
          )
        )
      } else {
        # No configs detected, show text input
        tagList(
          div(style = "color: #ffc107; margin-bottom: 10px;",
              icon("exclamation-triangle"), " No config files detected in folder"),
          textInput("custom_config_name", "Config filename:",
                   value = "Weight_Config.xlsx",
                   placeholder = "e.g., Weight_Config.xlsx")
        )
      }
    })

    # Handle config selection
    observeEvent(input$config_select, {
      if (!is.null(input$config_select)) {
        rv$selected_config <- input$config_select
      }
    })

    # Handle custom config toggle
    observeEvent(input$use_custom_config, {
      if (input$use_custom_config && !is.null(input$custom_config_name)) {
        rv$selected_config <- input$custom_config_name
      } else if (!input$use_custom_config && !is.null(input$config_select)) {
        rv$selected_config <- input$config_select
      }
    })

    # Handle custom config name input
    observeEvent(input$custom_config_name, {
      if (input$use_custom_config || is.null(input$config_select)) {
        rv$selected_config <- input$custom_config_name
      }
    })

    # Log capture function
    add_log <- function(msg) {
      rv$log <- paste0(rv$log, msg, "\n")
    }

    # Progress log output (R 4.2+ compatible - use renderPrint with cat)
    output$progress_log <- renderPrint({
      cat(rv$log)
    })

    # Has results flag
    output$has_results <- reactive({
      !is.null(rv$result)
    })
    outputOptions(output, "has_results", suspendWhenHidden = FALSE)

    # Run weighting analysis
    observeEvent(input$run_weighting, {

      # Reset state
      rv$result <- NULL
      rv$log <- ""
      rv$running <- TRUE

      add_log("Starting weighting analysis...")

      # Use withProgress for visual progress bar
      withProgress(message = "Calculating Weights", value = 0, {

        tryCatch({
          # Validate inputs
          req(input$project_folder)
          req(rv$selected_config)

          project_folder <- input$project_folder
          config_filename <- rv$selected_config

          # Validate folder exists
          if (!dir.exists(project_folder)) {
            msg <- paste0(
              "[REFUSE] IO_PROJECT_DIR_NOT_FOUND: Project Folder Not Found\n\n",
              "Problem: Project folder not found: ", project_folder, "\n\n",
              "How to fix: Select a valid project folder using the Browse button."
            )
            cat("\n", msg, "\n\n")
            stop(msg, call. = FALSE)
          }

          config_path <- file.path(project_folder, config_filename)

          # Validate config file exists
          if (!file.exists(config_path)) {
            msg <- paste0(
              "[REFUSE] IO_CONFIG_FILE_NOT_FOUND: Config File Not Found\n\n",
              "Problem: Config file not found: ", config_path, "\n\n",
              "How to fix: Ensure the Weight_Config.xlsx file exists in the project folder."
            )
            cat("\n", msg, "\n\n")
            stop(msg, call. = FALSE)
          }

          # Add to recent folders
          add_to_recent_folders(project_folder)

          add_log(paste("Project folder:", project_folder))
          add_log(paste("Config file:", config_filename))
          add_log(strrep("-", 50))

          # Don't override data_file - let config resolve it
          data_path <- NULL

          # Create progress callback for run_weighting
          progress_callback <- function(value, message) {
            setProgress(value = value, detail = message)
          }

          # Run weighting with progress updates
          add_log("Loading configuration...")

          # Set stats pack option before calling run_weighting
          options(turas.generate_stats_pack = isTRUE(input$generate_stats_pack))

          # Use capture.output for TRS compliance - all console output visible in GUI
          output_capture <- capture.output({
            result <- withCallingHandlers({
              if (exists("with_refusal_handler", mode = "function")) {
                with_refusal_handler({
                  run_weighting(
                    config_file = config_path,
                    data_file = data_path,
                    verbose = TRUE,
                    progress_callback = progress_callback,
                    html_report = input$generate_html
                  )
                }, module = "WEIGHTING")
              } else {
                run_weighting(
                  config_file = config_path,
                  data_file = data_path,
                  verbose = TRUE,
                  progress_callback = progress_callback,
                  html_report = input$generate_html
                )
              }
            }, message = function(m) {
              cat(conditionMessage(m), "\n")
              invokeRestart("muffleMessage")
            }, warning = function(w) {
              cat("WARNING:", conditionMessage(w), "\n")
              invokeRestart("muffleWarning")
            })
          }, type = "output")

          # Add captured output to log
          if (length(output_capture) > 0) {
            add_log(paste(output_capture, collapse = "\n"))
          }

          rv$result <- result

          add_log(strrep("-", 50))
          add_log("Weighting completed successfully!")
          add_log(paste("Weights created:", paste(result$weight_names, collapse = ", ")))

        }, error = function(e) {
          add_log(strrep("=", 50))
          add_log("ERROR:")
          add_log(conditionMessage(e))
          add_log(strrep("=", 50))
        })

      })  # End withProgress

      rv$running <- FALSE
    })

    # Results summary
    output$results_summary <- renderUI({
      req(rv$result)
      result <- rv$result

      n_weights <- length(result$weight_names)
      n_rows <- nrow(result$data)

      div(
        h4(style = "color: var(--turas-success); font-weight: 600;", icon("check-circle"), " Analysis Complete"),
        p(sprintf("Project: %s", result$config$general$project_name)),
        p(sprintf("Records processed: %s", format(n_rows, big.mark = ","))),
        p(sprintf("Weight columns created: %d", n_weights)),
        tags$ul(
          lapply(result$weight_names, function(w) {
            tags$li(w)
          })
        )
      )
    })

    # Diagnostics table
    output$diagnostics_table <- renderTable({
      req(rv$result)

      summary_df <- create_weight_summary_df(rv$result)

      if (nrow(summary_df) > 0) {
        # Format for display
        summary_df$efficiency <- paste0(round(summary_df$efficiency, 1), "%")
        summary_df$design_effect <- round(summary_df$design_effect, 2)
        summary_df$cv <- round(summary_df$cv, 3)
        summary_df$min <- round(summary_df$min, 3)
        summary_df$max <- round(summary_df$max, 2)

        # Select display columns
        summary_df[, c("weight_name", "method", "n_valid", "effective_n",
                      "design_effect", "efficiency", "quality_status")]
      }
    }, striped = TRUE, hover = TRUE, width = "100%")

    # Output files info
    output$output_files <- renderUI({
      req(rv$result)

      files <- list()

      if (!is.null(rv$result$output_file)) {
        files <- c(files, list(
          p(icon("file-excel"), " Weighted data: ", code(basename(rv$result$output_file)))
        ))
      }

      if (!is.null(rv$result$diagnostics_file)) {
        files <- c(files, list(
          shiny::p(shiny::icon("file-alt"), " Diagnostics: ", shiny::code(basename(rv$result$diagnostics_file)))
        ))
      }

      if (!is.null(rv$result$html_report_file)) {
        files <- c(files, list(
          shiny::p(shiny::icon("globe"), " HTML Report: ", shiny::code(basename(rv$result$html_report_file)))
        ))
      }

      if (length(files) > 0) {
        div(files)
      } else {
        p("No output files saved (configure in Weight_Config.xlsx)")
      }
    })
  }

  # ===========================================================================
  # LAUNCH APP
  # ===========================================================================
  shinyApp(ui = ui, server = server)
}

# ==============================================================================
# AUTO-RUN
# ==============================================================================

# Don't auto-run if being sourced by launcher
if (!exists("TURAS_LAUNCHER_ACTIVE") || !TURAS_LAUNCHER_ACTIVE) {
  if (interactive()) {
    run_weighting_gui()
  }
}
