# ==============================================================================
# TURAS>TABS GUI - LAUNCHER
# ==============================================================================
# Purpose: Launch beautiful crosstabs GUI (matches parser interface)
# Location: modules/tabs/run_tabs_gui.R
# Usage: source("modules/tabs/run_tabs_gui.R") then run_tabs_gui()
# ==============================================================================

# ==============================================================================
# TRS v1.0: EARLY REFUSAL FUNCTION (GUI ENTRY POINT)
# ==============================================================================
# This GUI entry point runs before tabs_refuse() is available, so we need
# a local implementation that formats TRS-compliant errors.

early_refuse <- function(code, title, problem, why_it_matters, how_to_fix) {
  # Format TRS-compliant error message
  msg <- paste0(
    "\n", strrep("=", 80), "\n",
    "  [REFUSE] ", code, ": ", title, "\n",
    strrep("=", 80), "\n\n",
    "Problem:\n",
    "  ", problem, "\n\n",
    "Why it matters:\n",
    "  ", why_it_matters, "\n\n",
    "How to fix:\n"
  )

  # Add fix steps
  for (i in seq_along(how_to_fix)) {
    msg <- paste0(msg, "  ", i, ". ", how_to_fix[i], "\n")
  }

  msg <- paste0(msg, "\n", strrep("=", 80), "\n")

  stop(msg, call. = FALSE)
}

run_tabs_gui <- function() {

  # Required packages - check availability (TRS v1.0: no auto-install)
  required_packages <- c("shiny", "shinyFiles")

  # Check for missing packages and refuse with clear instructions if any are missing
  missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  if (length(missing_packages) > 0) {
    early_refuse(
      code = "PKG_MISSING_DEPENDENCY",
      title = "Missing Required Packages",
      problem = paste0("The following required packages are not installed: ", paste(missing_packages, collapse = ", ")),
      why_it_matters = "The Tabs GUI cannot run without these packages.",
      how_to_fix = c(
        paste0("Run the following command in R: install.packages(c(", paste(sprintf('"%s"', missing_packages), collapse = ", "), "))")
      )
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
  theme <- turas_gui_theme("Tabs", "Cross-tabulation & Statistical Testing")
  hide_recents <- turas_hide_recents()
  
  # Recent projects file
  RECENT_PROJECTS_FILE <- file.path(TURAS_HOME, ".recent_tabs_projects.rds")
  
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
    theme$head,

    # Header
    theme$header,

    # Main content
    div(class = "turas-content",

      # Step 1: Project Selection
      div(class = "turas-card",
        h3(class = "turas-card-title", "1. Select Project Directory"),

        shinyDirButton("project_btn",
                      "Browse for Project Folder",
                      "Select project directory",
                      class = "btn btn-primary btn-lg",
                      icon = icon("folder-open")),

        uiOutput("project_ui"),
        if (!hide_recents) uiOutput("recent_ui")
      ),

      # Step 2: Config Selection
      uiOutput("config_ui"),

      # Step 3: Run Button
      uiOutput("run_ui"),

      # Step 4: Console Output
      uiOutput("console_ui")
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

    # Auto-load config from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      pre_config <- normalizePath(path.expand(pre_config), winslash = "/", mustWork = FALSE)

      if (dir.exists(pre_config)) {
        # Recents for Tabs are directory paths
        configs <- detect_config_files(pre_config)
        project_data(list(
          path = pre_config,
          configs = configs,
          selected_configs = if (length(configs) > 0) configs else character(0)
        ))
        add_recent_project(pre_config)
      } else if (file.exists(pre_config)) {
        # Config file path
        config_dir <- dirname(pre_config)
        config_name <- basename(pre_config)
        configs <- detect_config_files(config_dir)
        project_data(list(
          path = config_dir,
          configs = configs,
          selected_configs = config_name
        ))
        add_recent_project(config_dir)
      }
    }

    # Directory chooser
    volumes <- turas_gui_volumes()
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
            selected_configs = if(length(configs) > 0) configs else character(0)
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
          selected_configs = if(length(configs) > 0) configs else character(0)
        ))
        add_recent_project(dir_path)
      }
    })
    
    # Handle config selection (multi-select)
    observeEvent(input$config_select, {
      data <- project_data()
      if (!is.null(data)) {
        data$selected_configs <- input$config_select
        project_data(data)
      }
    }, ignoreNULL = FALSE)

    # Select All configs
    observeEvent(input$select_all_configs, {
      data <- project_data()
      if (!is.null(data) && length(data$configs) > 0) {
        updateCheckboxGroupInput(session, "config_select", selected = data$configs)
      }
    })

    # Deselect All configs
    observeEvent(input$deselect_all_configs, {
      updateCheckboxGroupInput(session, "config_select", selected = character(0))
    })
    
    # Project display
    output$project_ui <- renderUI({
      data <- project_data()
      if (is.null(data)) {
        div(class = "turas-status-info",
          icon("info-circle"), " No project selected. Click Browse to get started."
        )
      } else {
        div(class = "turas-file-display",
          tags$strong(basename(data$path)),
          tags$br(),
          tags$small(data$path),
          div(class = "turas-status-success", style = "margin-top: 10px;",
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
      
      div(class = "turas-recent-section",
        tags$hr(),
        h4("Recent Projects"),
        lapply(seq_along(recent), function(i) {
          tags$div(
            class = "turas-recent-item",
            onclick = sprintf("Shiny.setInputValue('select_recent', '%s', {priority: 'event'})", recent[i]),
            tags$strong(basename(recent[i])),
            tags$br(),
            tags$small(recent[i])
          )
        })
      )
    })
    
    # Config selection UI (multi-select)
    output$config_ui <- renderUI({
      data <- project_data()
      if (is.null(data) || length(data$configs) == 0) return(NULL)

      div(class = "turas-card",
        h3(class = "turas-card-title", "2. Select Configuration Files"),
        p(class = "turas-card-subtitle",
          "Select one or more config files to run. Each will produce a separate report."),
        div(style = "margin-bottom: 10px;",
          actionLink("select_all_configs", "Select All",
                     style = "margin-right: 15px; font-weight: 600;"),
          actionLink("deselect_all_configs", "Deselect All",
                     style = "font-weight: 600;")
        ),
        checkboxGroupInput("config_select",
                    NULL,
                    choices = setNames(data$configs, paste("\U0001F4C4", data$configs)),
                    selected = if (length(data$selected_configs) > 0) data$selected_configs else NULL)
      )
    })
    
    # Run button UI
    output$run_ui <- renderUI({
      data <- project_data()
      if (is.null(data) || length(data$selected_configs) == 0) return(NULL)

      n_selected <- length(data$selected_configs)
      btn_label <- if (n_selected == 1) {
        "RUN ANALYSIS"
      } else {
        sprintf("RUN %d ANALYSES", n_selected)
      }

      div(class = "turas-card",
        h3(class = "turas-card-title", "3. Run Analysis"),
        div(style = "text-align: center; margin: 20px 0;",
          actionButton("run_btn",
                      btn_label,
                      class = "turas-btn-run",
                      icon = icon("play-circle"),
                      disabled = is_running()),
          div(style = "margin-top: 12px;",
            checkboxInput("prepare_deliverable",
                         "Prepare client deliverable (minify for delivery)",
                         value = FALSE)
          )
        )
      )
    })
    
    # Console output UI
    output$console_ui <- renderUI({
      if (console_output() == "") return(NULL)
      
      div(class = "turas-card",
        h3(class = "turas-card-title", "4. Analysis Output"),
        div(class = "turas-console",
          verbatimTextOutput("console_text")
        )
      )
    })
    
    output$console_text <- renderText({
      console_output()
    })
    
    # Run analysis (supports multiple configs sequentially)
    observeEvent(input$run_btn, {
      data <- project_data()
      req(data, length(data$selected_configs) > 0)

      is_running(TRUE)

      selected_configs <- data$selected_configs
      n_configs <- length(selected_configs)

      console_output(sprintf("Starting analysis for %d configuration file%s...\n\n",
                             n_configs, if (n_configs > 1) "s" else ""))

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

      # Track overall results
      results_summary <- list()
      overall_start <- Sys.time()

      # --- Loop over each selected config ---
      for (config_idx in seq_along(selected_configs)) {
        current_config <- selected_configs[config_idx]

        # Header for this config run
        config_header <- if (n_configs > 1) {
          sprintf("\n%s\n  CONFIG %d of %d: %s\n%s\n",
                  strrep("=", 80), config_idx, n_configs, current_config, strrep("=", 80))
        } else {
          sprintf("\n%s\n", strrep("=", 80))
        }

        console_output(paste0(
          console_output(),
          config_header,
          sprintf("Project: %s\n", data$path),
          sprintf("Config:  %s\n\n", current_config)
        ))

        # Change to modules/tabs/lib directory where all the analysis scripts are
        setwd(tabs_lib_dir)

        # Set config_file as global variable (script expects this)
        assign("config_file", file.path(data$path, current_config), envir = .GlobalEnv)

        # Pass deliverable flag and load minification functions if needed
        assign("TURAS_PREPARE_DELIVERABLE",
               isTRUE(input$prepare_deliverable), envir = .GlobalEnv)
        if (isTRUE(input$prepare_deliverable)) {
          .client <- if (!is.null(input$client_name) && nzchar(input$client_name)) {
            input$client_name
          } else NULL
          assign("TURAS_CLIENT_NAME", .client, envir = .GlobalEnv)
          minify_dir <- file.path(TURAS_HOME, "modules", "shared", "lib")
          if (!exists("turas_prepare_deliverable", mode = "function")) {
            source(file.path(minify_dir, "turas_minify_verify.R"), local = FALSE)
            source(file.path(minify_dir, "turas_minify_watermark.R"), local = FALSE)
            source(file.path(minify_dir, "turas_minify.R"), local = FALSE)
          }
        }

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

          # Include config context in progress message for multi-config runs
          config_prefix <- if (n_configs > 1) {
            sprintf("[%d/%d] ", config_idx, n_configs)
          } else {
            ""
          }

          detail_msg <- sprintf("%sProcessing %s... (%d/%d) | ETA: %s",
                               config_prefix, item, current, total, eta_str)

          # Update Shiny progress bar
          setProgress(progress_value, detail = detail_msg)
        }

        # Set the custom progress callback as a global variable
        assign("gui_progress_callback", shiny_progress_callback, envir = .GlobalEnv)

        # Run analysis with progress bar
        progress_msg <- if (n_configs > 1) {
          sprintf("Running Analysis [%d/%d]: %s", config_idx, n_configs, current_config)
        } else {
          "Running Analysis"
        }

        withProgress(message = progress_msg, value = 0, {

          # Run analysis and capture ALL console output (including validation errors)
          output_file <- tempfile()
          sink(output_file, type = "output")

          analysis_result <- tryCatch({
            source("run_crosstabs.R", local = FALSE)
            list(success = TRUE, error = NULL)

          }, error = function(e) {
            list(success = FALSE, error = e)

          }, finally = {
            sink(type = "output")
          })
        })

        # Read captured output
        captured_output <- readLines(output_file, warn = FALSE)
        unlink(output_file)

        if (length(captured_output) > 0) {
          console_output(paste0(
            console_output(),
            paste(captured_output, collapse = "\n"),
            "\n"
          ))
        }

        # Handle result for this config
        if (analysis_result$success) {
          config_settings <- tryCatch({
            load_config_sheet(file.path(data$path, current_config))
          }, error = function(e) list())
          output_subfolder <- get_config_value(config_settings, "output_subfolder", "Crosstabs")

          console_output(paste0(
            console_output(),
            sprintf("\n%s %s\n", "\U2713", current_config),
            sprintf("  Output: %s\n", file.path(data$path, output_subfolder))
          ))

          results_summary[[current_config]] <- list(
            success = TRUE,
            output_dir = file.path(data$path, output_subfolder)
          )

        } else {
          error_msg <- analysis_result$error$message
          error_call <- if (!is.null(analysis_result$error$call)) {
            paste0("\n  Call: ", deparse(analysis_result$error$call))
          } else {
            ""
          }

          console_output(paste0(
            console_output(),
            sprintf("\n%s %s\n", "\U2717", current_config),
            sprintf("  Error: %s%s\n", error_msg, error_call)
          ))

          results_summary[[current_config]] <- list(
            success = FALSE,
            error = error_msg
          )
        }

        # Clean up global variables between runs
        if (exists("config_file", envir = .GlobalEnv)) {
          rm("config_file", envir = .GlobalEnv)
        }
        if (exists("TURAS_PREPARE_DELIVERABLE", envir = .GlobalEnv)) {
          rm("TURAS_PREPARE_DELIVERABLE", envir = .GlobalEnv)
        }
        if (exists("TURAS_CLIENT_NAME", envir = .GlobalEnv)) {
          rm("TURAS_CLIENT_NAME", envir = .GlobalEnv)
        }

        # Restore working directory between runs
        setwd(old_wd)
      }

      # --- Overall summary ---
      n_success <- sum(sapply(results_summary, function(x) x$success))
      n_failed <- n_configs - n_success
      elapsed_total <- as.numeric(difftime(Sys.time(), overall_start, units = "secs"))

      elapsed_str <- if (elapsed_total < 60) {
        sprintf("%.0f seconds", elapsed_total)
      } else {
        sprintf("%.1f minutes", elapsed_total / 60)
      }

      summary_text <- paste0(
        "\n", strrep("=", 80), "\n",
        if (n_configs > 1) {
          sprintf("  BATCH COMPLETE: %d of %d succeeded in %s\n", n_success, n_configs, elapsed_str)
        } else if (n_success == 1) {
          sprintf("  \U2713 ANALYSIS COMPLETE (%s)\n", elapsed_str)
        } else {
          sprintf("  \U2717 ANALYSIS FAILED\n")
        },
        strrep("=", 80), "\n"
      )

      # List output locations for successful runs
      if (n_success > 0) {
        summary_text <- paste0(summary_text, "\nOutput files:\n")
        for (cfg_name in names(results_summary)) {
          r <- results_summary[[cfg_name]]
          if (r$success) {
            summary_text <- paste0(summary_text, sprintf("  \U2713 %s\n    %s\n", cfg_name, r$output_dir))
          }
        }
      }

      # List failures
      if (n_failed > 0) {
        summary_text <- paste0(summary_text, "\nFailed:\n")
        for (cfg_name in names(results_summary)) {
          r <- results_summary[[cfg_name]]
          if (!r$success) {
            summary_text <- paste0(summary_text, sprintf("  \U2717 %s: %s\n", cfg_name, r$error))
          }
        }
      }

      console_output(paste0(console_output(), summary_text))

      # Notifications
      if (n_failed == 0) {
        msg <- if (n_configs > 1) {
          sprintf("All %d analyses completed successfully!", n_configs)
        } else {
          "Analysis completed successfully!"
        }
        showNotification(msg, type = "message", duration = 5)
      } else if (n_success > 0) {
        showNotification(
          sprintf("%d of %d analyses completed. %d failed.", n_success, n_configs, n_failed),
          type = "warning", duration = 10
        )
      } else {
        showNotification(
          sprintf("All %d analyses failed. Check console for details.", n_configs),
          type = "error", duration = 10
        )
      }

      # Final cleanup
      if (exists("gui_progress_callback", envir = .GlobalEnv)) {
        rm("gui_progress_callback", envir = .GlobalEnv)
      }
      setwd(old_wd)
      is_running(FALSE)
    })
  }
  
  # Launch
  cat("\nLaunching Turas>Tabs GUI...\n\n")
  shinyApp(ui = ui, server = server)
}
