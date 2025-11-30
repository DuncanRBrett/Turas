# ==============================================================================
# TURAS SEGMENTATION MODULE - SHINY GUI LAUNCHER
# ==============================================================================
# Shiny interface for running segmentation analysis
# Part of Turas Analytics Platform
# ==============================================================================

run_segment_gui <- function() {

  # Check required packages
  required_pkgs <- c("shiny", "shinyFiles", "readxl", "writexl")
  missing_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]

  if (length(missing_pkgs) > 0) {
    message("Installing required packages: ", paste(missing_pkgs, collapse = ", "))
    install.packages(missing_pkgs)
  }

  # Load required libraries
  library(shiny)
  library(shinyFiles)

  # Get module directories
  turas_root <- Sys.getenv("TURAS_ROOT", getwd())
  segment_dir <- file.path(turas_root, "modules/segment")

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

    # Keep only last 10
    recent <- head(recent, 10)

    saveRDS(recent, recent_file)
  }

  # ===========================================================================
  # SHINY UI
  # ===========================================================================

  ui <- fluidPage(
    tags$head(
      tags$style(HTML("
        body {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          min-height: 100vh;
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }

        .main-container {
          max-width: 900px;
          margin: 40px auto;
          padding: 30px;
          background: white;
          border-radius: 15px;
          box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }

        .module-title {
          font-size: 32px;
          font-weight: 700;
          color: #667eea;
          margin-bottom: 10px;
          text-align: center;
        }

        .module-subtitle {
          font-size: 16px;
          color: #666;
          text-align: center;
          margin-bottom: 30px;
        }

        .step-card {
          background: #f8f9fa;
          border-left: 4px solid #667eea;
          border-radius: 8px;
          padding: 20px;
          margin-bottom: 20px;
        }

        .step-title {
          font-size: 18px;
          font-weight: 600;
          color: #333;
          margin-bottom: 15px;
        }

        .btn-primary {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          border: none;
          padding: 12px 30px;
          font-size: 16px;
          font-weight: 600;
          border-radius: 8px;
          transition: all 0.3s;
        }

        .btn-primary:hover {
          transform: translateY(-2px);
          box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }

        .btn-success {
          background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
          border: none;
          padding: 15px 40px;
          font-size: 18px;
          font-weight: 700;
          border-radius: 8px;
          margin-top: 20px;
        }

        .btn-success:hover {
          transform: translateY(-2px);
          box-shadow: 0 5px 15px rgba(56, 239, 125, 0.4);
        }

        .file-display {
          background: white;
          border: 2px solid #e0e0e0;
          border-radius: 6px;
          padding: 12px;
          margin-top: 10px;
          font-family: 'Courier New', monospace;
          color: #333;
        }

        .status-box {
          background: #e3f2fd;
          border-left: 4px solid #2196f3;
          border-radius: 6px;
          padding: 15px;
          margin-top: 20px;
        }

        .success-box {
          background: #e8f5e9;
          border-left: 4px solid #4caf50;
          border-radius: 6px;
          padding: 15px;
          margin-top: 20px;
        }

        .error-box {
          background: #ffebee;
          border-left: 4px solid #f44336;
          border-radius: 6px;
          padding: 15px;
          margin-top: 20px;
        }

        .recent-project {
          background: white;
          border: 1px solid #e0e0e0;
          border-radius: 6px;
          padding: 10px 15px;
          margin-bottom: 8px;
          cursor: pointer;
          transition: all 0.2s;
        }

        .recent-project:hover {
          background: #f5f5f5;
          border-color: #667eea;
        }

        .console-output {
          background: #1e1e1e;
          color: #d4d4d4;
          padding: 20px;
          border-radius: 8px;
          font-family: 'Courier New', Consolas, monospace;
          font-size: 12px;
          line-height: 1.5;
          max-height: 500px;
          overflow-y: auto;
          margin-top: 15px;
          white-space: pre-wrap;
          word-wrap: break-word;
        }
      "))
    ),

    div(class = "main-container",
      div(class = "module-title", "Segmentation Analysis"),
      div(class = "module-subtitle", "K-means clustering with variable selection and outlier detection"),

      hr(),

      # Step 1: Select Configuration File
      div(class = "step-card",
        div(class = "step-title", "Step 1: Select Configuration File"),
        p("Choose your segmentation configuration Excel file (must contain a 'Config' sheet)."),

        shinyFilesButton("select_config_btn", "Browse for Config File", 
                         "Please select a config file",
                         multiple = FALSE,
                         class = "btn btn-primary",
                         icon = icon("folder-open")),

        uiOutput("config_display"),

        # Recent projects
        uiOutput("recent_projects_ui")
      ),

      # Step 2: Configuration Summary
      uiOutput("config_summary_ui"),

      # Step 3: Run Analysis
      uiOutput("run_button_ui"),

      # Step 4: Results
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

    # Setup file browser
    volumes <- c(Home = normalizePath("~"),
                getVolumes()())

    shinyFileChoose(input, "select_config_btn", roots = volumes,
                   filetypes = c("xlsx", "xls"))

    # Handle config file selection
    observeEvent(input$select_config_btn, {
      if (!is.null(input$select_config_btn) && !is.integer(input$select_config_btn)) {
        file_selected <- parseFilePaths(volumes, input$select_config_btn)
        if (nrow(file_selected) > 0) {
          config_file(as.character(file_selected$datapath))
          save_recent_project(as.character(file_selected$datapath))
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
        if (file.exists(selected_path)) {
          config_file(selected_path)
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
        div(class = "file-display",
          strong("Selected: "), basename(config_file()),
          br(),
          span(style = "color: #888; font-size: 12px;",
               dirname(config_file()))
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
                class = "recent-project",
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

        div(class = "step-card",
          div(class = "step-title", "Step 2: Configuration Summary"),

          div(class = "status-box",
            strong("✓ Configuration Loaded Successfully"), br(),
            hr(style = "margin: 10px 0;"),

            strong("Mode: "), config$mode, br(),
            strong("Clustering Variables: "), length(config$clustering_vars), br(),
            strong("Method: "), config$method, br(),

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

            strong("Output Folder: "), config$output_folder
          )
        )
      },
      error = function(e) {
        div(class = "step-card",
          div(class = "step-title", "Step 2: Configuration Summary"),
          div(class = "error-box",
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

      div(class = "step-card",
        div(class = "step-title", "Step 3: Run Analysis"),
        p("Click the button below to start the segmentation analysis. This may take a few moments."),

        actionButton("run_analysis_btn", "Run Segmentation Analysis",
                    class = "btn btn-success btn-lg btn-block",
                    icon = icon("play-circle"))
      )
    })

    # Render console output (R 4.2+ compatible)
    output$console_text <- renderText({
      current_output <- console_output()

      # R 4.2+ requires single TRUE/FALSE in if conditions
      # Check length first to avoid "condition has length > 1" error
      if (length(current_output) == 0 || is.null(current_output)) {
        return("")
      }

      # Return the output
      as.character(current_output)
    })

    # Run analysis
    observeEvent(input$run_analysis_btn, {
      req(config_file())

      # Clear previous console output
      console_output("")

      # Show progress
      withProgress(message = 'Running segmentation analysis...', value = 0, {

        incProgress(0.1, detail = "Loading configuration")

        # Capture console output using sink
        output_file <- tempfile()
        sink(output_file, type = "output")

        analysis_result_data <- tryCatch({
          # Change working directory to Turas root
          setwd(turas_root)

          incProgress(0.2, detail = "Preparing data")

          # Run segmentation
          result <- turas_segment_from_config(config_file(), verbose = TRUE)

          incProgress(0.9, detail = "Finalizing")

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

        # Read captured output
        captured_output <- readLines(output_file, warn = FALSE)
        unlink(output_file)

        # Update console display
        if (length(captured_output) > 0) {
          console_output(paste(captured_output, collapse = "\n"))
        }

        incProgress(1.0, detail = "Complete!")

        # Handle success or error
        if (analysis_result_data$success) {
          # Store successful result
          analysis_result(analysis_result_data$result)

          # Append completion message to console
          console_output(paste0(
            console_output(),
            sprintf("\n\n%s\n✓ ANALYSIS COMPLETE\n%s\n", strrep("=", 80), strrep("=", 80))
          ))

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
      })
    })

    # Display results
    output$results_ui <- renderUI({
      req(analysis_result())

      result <- analysis_result()

      # Always show console output section if there is output (R 4.2+ compatible)
      current_console <- console_output()
      has_output <- length(current_console) > 0 &&
                    !is.null(current_console) &&
                    nchar(current_console[1]) > 0

      console_section <- if (has_output) {
        div(
          h4("Console Output:", style = "margin-top: 20px;"),
          div(class = "console-output",
            verbatimTextOutput("console_text")
          )
        )
      } else {
        NULL
      }

      if (!is.null(result$error)) {
        # Error occurred
        div(class = "step-card",
          div(class = "step-title", "Step 4: Results"),
          div(class = "error-box",
            strong("✗ Analysis Error"), br(),
            hr(style = "margin: 10px 0;"),
            p(strong("Error Details:")),
            p(style = "font-family: monospace; white-space: pre-wrap;", result$error),
            hr(style = "margin: 10px 0;"),
            p(strong("Note:"), " Check console output below for details. Output files may still have been generated - check your output folder.")
          ),
          # Always show console output for errors
          console_section
        )
      } else {
        # Success
        div(class = "step-card",
          div(class = "step-title", "Step 4: Results"),

          div(class = "success-box",
            strong("✓ Analysis Complete!"), br(),
            hr(style = "margin: 10px 0;"),

            if (result$mode == "exploration") {
              tagList(
                strong("Recommended K: "), result$recommendation$recommended_k, br(),
                strong("Silhouette Score: "),
                round(result$recommendation$recommended_silhouette, 3), br(),
                br(),
                strong("Output Files:"), br(),
                "• K Selection Report: ",
                basename(result$output_files$report), br(),
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
                strong("Silhouette Score: "),
                round(result$validation$avg_silhouette, 3), br(),
                strong("Observations: "), nrow(result$profiles$segment_sizes), br(),
                br(),
                strong("Output Files:"), br(),
                "• Segment Assignments: ",
                basename(result$output_files$assignments), br(),
                "• Full Report: ",
                basename(result$output_files$report), br(),
                if (!is.null(result$output_files$model)) {
                  tagList("• Model Object: ", basename(result$output_files$model), br())
                }
              )
            }
          ),

          br(),
          actionButton("open_output_btn", "Open Output Folder",
                      class = "btn btn-primary",
                      icon = icon("folder-open")),

          # Show console output (using shared section)
          console_section
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
