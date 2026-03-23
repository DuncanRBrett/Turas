# ==============================================================================
# TURAS SEGMENTATION MODULE - SHINY GUI LAUNCHER
# ==============================================================================
# Shiny interface for running segmentation analysis
# Part of Turas Analytics Platform
# ==============================================================================

run_segment_gui <- function() {

  # Required packages - check availability (TRS v1.0: no auto-install)
  required_pkgs <- c("shiny", "shinyFiles", "readxl", "writexl")
  missing_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]

  if (length(missing_pkgs) > 0) {
    stop(paste0(
      "[REFUSE] PKG_MISSING_DEPENDENCY: Missing Required Packages\n\n",
      "Problem: The following required packages are not installed: ", paste(missing_pkgs, collapse = ", "), "\n\n",
      "Why it matters: The Segment GUI cannot run without these packages.\n\n",
      "How to fix: Run the following command in R:\n",
      "  install.packages(c(", paste(sprintf('"%s"', missing_pkgs), collapse = ", "), "))\n"
    ), call. = FALSE)
  }

  # Load required libraries
  library(shiny)
  library(shinyFiles)

  # Get module directories
  turas_root <- Sys.getenv("TURAS_ROOT", getwd())
  segment_dir <- file.path(turas_root, "modules/segment")

  # Load shared GUI theme
  source(file.path(turas_root, "modules", "shared", "lib", "gui_theme.R"))
  theme <- turas_gui_theme("Segment", "Clustering & Segmentation Analysis")
  hide_recents <- turas_hide_recents()

  # Source the segmentation module
  source(file.path(segment_dir, "run_segment.R"))

  # Recent projects file
  recent_file <- file.path(turas_root, ".recent_segment_projects.rds")

  # Helper function to load recent projects
  load_recent_projects <- function() {
    if (file.exists(recent_file)) {
      readRDS(recent_file)
    } else {
      list()
    }
  }

  # Helper function to save recent project
  save_recent_project <- function(config_path) {
    recent <- load_recent_projects()

    # Add new project (avoid duplicates)
    recent <- c(config_path, recent[recent != config_path])

    # Keep only last 5
    recent <- head(recent, 5)

    saveRDS(recent, recent_file)
  }

  # ===========================================================================
  # SHINY UI
  # ===========================================================================

  ui <- fluidPage(
    theme$head,

    # Header
    theme$header,

    div(class = "turas-content",

      # Step 1: Select Configuration File
      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 1: Select Configuration File"),
        p("Choose your segmentation configuration Excel file (must contain a 'Config' sheet)."),

        shinyFilesButton("select_config_btn", "Browse for Config File",
                         "Please select a config file",
                         multiple = FALSE,
                         class = "btn btn-primary",
                         icon = icon("folder-open")),

        uiOutput("config_display"),

        # Recent projects (hidden when launched from hub)
        if (!hide_recents) uiOutput("recent_projects_ui")
      ),

      # Step 2: Configuration Summary
      uiOutput("config_summary_ui"),

      # Step 3: Run Analysis
      uiOutput("run_button_ui"),

      # Step 4: Console Output (static UI - always visible, like tracker)
      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 4: Console Output"),
        div(class = "turas-console",
          verbatimTextOutput("console_text")
        )
      ),

      # Step 5: Results
      uiOutput("results_ui")
    )
  )

  # ===========================================================================
  # SHINY SERVER
  # ===========================================================================

  server <- function(input, output, session) {

    # Reactive values
    config_file <- reactiveVal(NULL)
    analysis_result <- reactiveVal(NULL)
    console_output <- reactiveVal("")  # Store console output

    # Auto-load config from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      if (dir.exists(pre_config)) {
        # Directory passed — look for a segment config xlsx inside
        dir_path <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
        xlsx_files <- list.files(dir_path, pattern = "\\.(xlsx|xls)$", full.names = TRUE, ignore.case = TRUE)
        seg_files <- grep("segment", xlsx_files, value = TRUE, ignore.case = TRUE)
        if (length(seg_files) > 0) {
          config_file(seg_files[1])
        } else if (length(xlsx_files) > 0) {
          config_file(xlsx_files[1])
        }
      } else if (file.exists(pre_config)) {
        config_file(normalizePath(pre_config, winslash = "/", mustWork = FALSE))
      }
    }

    # Setup file browser
    volumes <- turas_gui_volumes()

    shinyFileChoose(input, "select_config_btn", roots = volumes,
                   filetypes = c("xlsx", "xls"))

    # Handle config file selection
    observeEvent(input$select_config_btn, {
      if (!is.null(input$select_config_btn) && !is.integer(input$select_config_btn)) {
        file_selected <- parseFilePaths(volumes, input$select_config_btn)
        if (nrow(file_selected) > 0) {
          # Expand tilde and normalize path (fixes OneDrive/home directory paths)
          file_path_expanded <- normalizePath(path.expand(as.character(file_selected$datapath)),
                                              winslash = "/", mustWork = FALSE)
          config_file(file_path_expanded)
          save_recent_project(file_path_expanded)
          analysis_result(NULL)  # Reset results when new file selected
        }
      }
    })

    # Handle recent project selection
    observeEvent(input$recent_project, {
      req(input$recent_project)

      recent_projects <- load_recent_projects()
      if (input$recent_project <= length(recent_projects)) {
        selected_path <- recent_projects[[input$recent_project]]
        # Expand tilde and normalize path (fixes OneDrive/home directory paths)
        selected_path_expanded <- normalizePath(path.expand(selected_path),
                                                winslash = "/", mustWork = FALSE)
        if (file.exists(selected_path_expanded)) {
          config_file(selected_path_expanded)
          analysis_result(NULL)
        } else {
          showNotification("Config file no longer exists at this location",
                          type = "error", duration = 5)
        }
      }
    })

    # Display selected config file
    output$config_display <- renderUI({
      req(config_file())

      div(
        div(class = "turas-file-display",
          strong("Selected: "), basename(config_file()),
          br(),
          tags$small(dirname(config_file()))
        )
      )
    })

    # Display recent projects
    output$recent_projects_ui <- renderUI({
      recent_projects <- load_recent_projects()

      if (length(recent_projects) > 0) {
        div(
          hr(),
          p(strong("Recent Projects:"), style = "margin-top: 15px; margin-bottom: 10px;"),
          lapply(seq_along(recent_projects), function(i) {
            if (file.exists(recent_projects[[i]])) {
              actionButton(
                paste0("recent_project"),
                label = basename(recent_projects[[i]]),
                class = "turas-recent-item",
                style = "width: 100%; text-align: left;",
                onclick = paste0("Shiny.setInputValue('recent_project', ", i,
                               ", {priority: 'event'})")
              )
            }
          })
        )
      }
    })

    # Display configuration summary
    output$config_summary_ui <- renderUI({
      req(config_file())

      # Try to read and validate config
      tryCatch({
        config_raw <- read_segment_config(config_file())
        config <- validate_segment_config(config_raw)

        div(class = "turas-card",
          h3(class = "turas-card-title", "Step 2: Configuration Summary"),

          div(class = "turas-status-info",
            strong("Configuration Loaded Successfully"), br(),
            hr(style = "margin: 10px 0;"),

            strong("Mode: "), config$mode, br(),
            strong("Method: "), switch(config$method,
              kmeans = "K-Means",
              hclust = paste0("Hierarchical (", config$linkage_method %||% "ward.D2", ")"),
              gmm = paste0("Gaussian Mixture Model (", config$gmm_model_type %||% "VVV", ")"),
              toupper(config$method)
            ), br(),
            strong("Clustering Variables: "), length(config$clustering_vars), br(),

            if (config$mode == "exploration") {
              tagList(
                strong("K Range: "), paste0(config$k_min, " to ", config$k_max), br()
              )
            } else {
              tagList(
                strong("Fixed K: "), config$k_fixed, br()
              )
            },

            if (config$variable_selection) {
              tagList(
                strong("Variable Selection: "), "Enabled (", config$variable_selection_method,
                ", target: ", config$max_clustering_vars, ")", br()
              )
            },

            if (config$outlier_detection) {
              tagList(
                strong("Outlier Detection: "), "Enabled (", config$outlier_method,
                ", handling: ", config$outlier_handling, ")", br()
              )
            },

            if (isTRUE(config$html_report)) {
              tagList(
                strong("HTML Report: "), "Enabled", br()
              )
            },

            strong("Output Folder: "), config$output_folder
          )
        )
      },
      error = function(e) {
        div(class = "turas-card",
          h3(class = "turas-card-title", "Step 2: Configuration Summary"),
          div(class = "turas-status-error",
            strong("✗ Configuration Error"), br(),
            hr(style = "margin: 10px 0;"),
            as.character(e$message)
          )
        )
      })
    })

    # Display run button
    output$run_button_ui <- renderUI({
      req(config_file())

      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 3: Run Analysis"),
        p("Click the button below to start the segmentation analysis. This may take a few moments."),

        checkboxInput("generate_stats_pack",
                      "Generate stats pack (diagnostic workbook for advanced review)",
                      value = FALSE),

        actionButton("run_analysis_btn", "Run Segmentation Analysis",
                    class = "turas-btn-run",
                    icon = icon("play-circle"))
      )
    })

    # Render console output (R 4.2+ compatible - EXACT same fix as tracker)
    output$console_text <- renderText({
      current_output <- console_output()

      # Ensure single string for R 4.2+ compatibility
      # If vector, collapse it; if empty/NULL, return placeholder
      if (is.null(current_output) || length(current_output) == 0 || nchar(current_output[1]) == 0) {
        "Console output will appear here when you run the analysis..."
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
    observeEvent(input$run_analysis_btn, {
      req(config_file())

      # Clear previous console output
      console_output("")

      # Create progress indicator (like tracker - NOT withProgress!)
      progress <- Progress$new(session)
      progress$set(message = "Running segmentation analysis", value = 0)
      on.exit(progress$close())

      # Change working directory to Turas root
      old_wd <- getwd()
      setwd(turas_root)

      tryCatch({
        progress$set(value = 0.3, detail = "Running analysis...")

        # Capture console output using sink (stdout only like tracker)
        output_capture_file <- tempfile()
        sink(output_capture_file, type = "output")

        # Propagate stats pack flag
        options(turas.generate_stats_pack = isTRUE(input$generate_stats_pack))

        analysis_result_data <- tryCatch({
          # Run segmentation
          result <- turas_segment_from_config(config_file(), verbose = TRUE)
          list(success = TRUE, result = result)

        }, error = function(e) {
          # Capture detailed error information
          error_msg <- paste0(
            e$message,
            "\n\nError Type: ", class(e)[1],
            "\n\nCall Stack:\n",
            paste(deparse(e$call), collapse = "\n")
          )
          list(success = FALSE, error = error_msg)

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
          console_output("Analysis completed but produced no console output.")
        }

        # Handle success or error
        if (analysis_result_data$success) {
          # Store successful result
          analysis_result(analysis_result_data$result)

          # Append completion message to console
          console_output(paste0(
            console_output(),
            sprintf("\n\n%s\n✓ ANALYSIS COMPLETE\n%s\n", strrep("=", 80), strrep("=", 80))
          ))

          progress$set(value = 1.0, detail = "Complete!")
          showNotification("Segmentation analysis completed successfully!",
                          type = "message", duration = 5)

        } else {
          # Store error result
          analysis_result(list(error = analysis_result_data$error))

          # Append error to console
          console_output(paste0(
            console_output(),
            sprintf("\n\n%s\nERROR\n%s\n%s\n",
                   strrep("=", 80), strrep("=", 80), analysis_result_data$error)
          ))

          showNotification(paste("Error:", analysis_result_data$error),
                          type = "error", duration = 10)
        }

      }, error = function(e) {
        # Top-level error handler
        error_msg <- paste0(strrep("=", 80), "\nERROR: ", e$message, "\n", strrep("=", 80))
        console_output(paste0(console_output(), "\n\n", error_msg))
        showNotification(paste("Error:", e$message), type = "error", duration = 10)

      }, finally = {
        # Restore original working directory
        setwd(old_wd)
      })
    })

    # Display results
    output$results_ui <- renderUI({
      req(analysis_result())

      result <- analysis_result()

      if (!is.null(result$error)) {
        # Error occurred
        div(class = "turas-card",
          h3(class = "turas-card-title", "Step 5: Results"),
          div(class = "turas-status-error",
            strong("✗ Analysis Error"), br(),
            hr(style = "margin: 10px 0;"),
            p(strong("Error Details:")),
            p(style = "font-family: monospace; white-space: pre-wrap;", result$error),
            hr(style = "margin: 10px 0;"),
            p(strong("Note:"), " Check console output above for details. Output files may still have been generated - check your output folder.")
          )
        )
      } else {
        # Success
        div(class = "turas-card",
          h3(class = "turas-card-title", "Step 5: Results"),

          div(class = "turas-status-success",
            strong("✓ Analysis Complete!"), br(),
            hr(style = "margin: 10px 0;"),

            if (result$mode == "exploration") {
              tagList(
                strong("Recommended K: "), result$recommendation$recommended_k, br(),
                strong("Silhouette Score: "),
                if (!is.null(result$recommendation$recommended_silhouette) && is.numeric(result$recommendation$recommended_silhouette)) {
                  round(result$recommendation$recommended_silhouette, 3)
                } else {
                  "N/A"
                }, br(),
                br(),
                strong("Output Files:"), br(),
                "- K Selection Report: ",
                basename(result$output_files$report), br(),
                if (!is.null(result$output_files$html)) {
                  tagList("- HTML Report: ", basename(result$output_files$html), br())
                },
                br(),
                strong("Next Steps:"), br(),
                "1. Review the k selection report", br(),
                "2. Update config file: set k_fixed = ",
                result$recommendation$recommended_k, br(),
                "3. Re-run this analysis for final segmentation"
              )
            } else {
              tagList(
                strong("Number of Segments: "), result$k, br(),
                strong("Method: "), toupper(result$method %||% "kmeans"), br(),
                strong("Silhouette Score: "),
                if (!is.null(result$validation$avg_silhouette) && is.numeric(result$validation$avg_silhouette)) {
                  round(result$validation$avg_silhouette, 3)
                } else {
                  "N/A"
                }, br(),
                br(),
                strong("Output Files:"), br(),
                "- Segment Assignments: ",
                basename(result$output_files$assignments), br(),
                "- Full Report: ",
                basename(result$output_files$report), br(),
                if (!is.null(result$output_files$model)) {
                  tagList("- Model Object: ", basename(result$output_files$model), br())
                },
                if (!is.null(result$output_files$html)) {
                  tagList("- HTML Report: ", basename(result$output_files$html), br())
                }
              )
            }
          ),

          br(),
          actionButton("open_output_btn", "Open Output Folder",
                      class = "btn btn-primary",
                      icon = icon("folder-open"))
        )
      }
    })

    # Open output folder
    observeEvent(input$open_output_btn, {
      req(analysis_result())

      result <- analysis_result()

      # Get output folder from result
      if (result$mode == "exploration") {
        output_path <- dirname(result$output_files$report)
      } else {
        output_path <- dirname(result$output_files$assignments)
      }

      # Open folder based on OS
      if (.Platform$OS.type == "windows") {
        shell.exec(output_path)
      } else if (Sys.info()["sysname"] == "Darwin") {
        system(paste("open", shQuote(output_path)))
      } else {
        system(paste("xdg-open", shQuote(output_path)))
      }
    })
  }

  # Return Shiny app
  shinyApp(ui = ui, server = server)
}
