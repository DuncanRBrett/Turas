# ==============================================================================
# ALCHEMER PARSER - SHINY GUI
# ==============================================================================
# Interactive GUI for AlchemerParser module
# ==============================================================================

# Fast package check - only install if needed, don't load yet
if (!requireNamespace("shiny", quietly = TRUE)) {
  message("Installing required package: shiny")
  install.packages("shiny")
}

# Load shiny with suppressed messages
suppressPackageStartupMessages(library(shiny))

# Get script directory
get_script_dir <- function() {
  # Method 1: Check call stack for ofile
  for (i in seq_len(sys.nframe())) {
    file <- sys.frame(i)$ofile
    if (!is.null(file) && grepl("run_alchemerparser_gui", file)) {
      return(dirname(normalizePath(file)))
    }
  }

  # Method 2: Check commandArgs
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("--file=", "", file_arg))))
  }

  # Fallback
  return(file.path(getwd(), "modules", "AlchemerParser"))
}

# Source all R functions
script_dir <- get_script_dir()
r_files <- list.files(file.path(script_dir, "R"), pattern = "\\.R$",
                     full.names = TRUE)
for (f in r_files) {
  source(f, local = FALSE)
}

# Check required packages
check_dependencies <- function() {
  required_packages <- c("readxl", "openxlsx", "officer", "shiny", "shinyFiles", "fs")
  missing_packages <- character(0)

  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing_packages <- c(missing_packages, pkg)
    }
  }

  if (length(missing_packages) > 0) {
    stop(sprintf("Missing required packages: %s\nInstall with: install.packages(c(%s))",
                paste(missing_packages, collapse = ", "),
                paste0("'", missing_packages, "'", collapse = ", ")),
         call. = FALSE)
  }
}

check_dependencies()

# Recent projects file
recent_projects_file <- file.path(script_dir, ".recent_alchemerparser_projects.rds")

#' Run AlchemerParser GUI
#'
#' @description
#' Launches interactive Shiny GUI for AlchemerParser.
#'
#' @export
run_alchemerparser_gui <- function() {

  ui <- fluidPage(
    # Custom CSS
    tags$head(
      tags$style(HTML("
        body {
          background-color: #f5f5f5;
        }
        .main-header {
          background-color: #3498db;
          color: white;
          padding: 20px;
          margin-bottom: 20px;
          border-radius: 5px;
        }
        .main-header h2 {
          margin: 0;
        }
        .section-box {
          background-color: white;
          padding: 20px;
          margin-bottom: 20px;
          border-radius: 5px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-title {
          font-size: 18px;
          font-weight: bold;
          color: #2c3e50;
          margin-bottom: 15px;
          border-bottom: 2px solid #3498db;
          padding-bottom: 5px;
        }
        .status-box {
          padding: 15px;
          border-radius: 5px;
          margin-top: 10px;
        }
        .status-success {
          background-color: #d4edda;
          border: 1px solid #c3e6cb;
          color: #155724;
        }
        .status-error {
          background-color: #f8d7da;
          border: 1px solid #f5c6cb;
          color: #721c24;
        }
        .status-warning {
          background-color: #fff3cd;
          border: 1px solid #ffeaa7;
          color: #856404;
        }
        .status-info {
          background-color: #d1ecf1;
          border: 1px solid #bee5eb;
          color: #0c5460;
        }
        .file-info {
          font-family: monospace;
          font-size: 12px;
          background-color: #f8f9fa;
          padding: 10px;
          border-radius: 3px;
          margin-top: 10px;
        }
      "))
    ),

    # Header
    div(class = "main-header",
      h2("AlchemerParser"),
      p("Parse Alchemer survey files and generate Tabs configuration")
    ),

    # Main content
    div(style = "max-width: 1200px; margin: auto;",

      # Step 1: Select Project Directory
      div(class = "section-box",
        div(class = "section-title", "Step 1: Select Project Directory"),

        fluidRow(
          column(8,
            textInput("project_dir", "Project Directory:",
                     value = "", width = "100%",
                     placeholder = "/path/to/alchemer/files")
          ),
          column(4,
            br(),
            shinyFiles::shinyDirButton("browse_dir", "Browse...",
                                       title = "Select Project Directory",
                                       buttonType = "default", class = NULL)
          )
        ),

        # Recent projects
        selectInput("recent_project", "Or select a recent project:",
                   choices = c("Select..." = ""), width = "100%"),

        uiOutput("file_status")
      ),

      # Step 2: Review and Parse
      div(class = "section-box",
        div(class = "section-title", "Step 2: Parse Files"),

        fluidRow(
          column(6,
            textInput("project_name", "Project Name (optional):",
                     value = "", width = "100%",
                     placeholder = "Auto-detected from filenames")
          ),
          column(6,
            textInput("output_dir", "Output Directory (optional):",
                     value = "", width = "100%",
                     placeholder = "Defaults to project directory")
          )
        ),

        actionButton("run_parser", "Parse Files", width = "200px",
                    class = "btn-primary btn-lg"),

        uiOutput("parse_status")
      ),

      # Step 3: Review Results
      div(class = "section-box",
        div(class = "section-title", "Step 3: Review Results"),

        uiOutput("results_summary"),

        conditionalPanel(
          condition = "output.show_results",
          hr(),
          h4("Question Preview"),
          DT::dataTableOutput("questions_preview"),

          conditionalPanel(
            condition = "output.has_flags",
            hr(),
            h4("Validation Flags"),
            DT::dataTableOutput("flags_table")
          )
        )
      ),

      # Step 4: Download Outputs
      div(class = "section-box",
        div(class = "section-title", "Step 4: Download Output Files"),

        p("Output files are saved to the output directory. You can also download them here:"),

        fluidRow(
          column(4,
            downloadButton("download_crosstab", "Download Crosstab_Config",
                          width = "100%")
          ),
          column(4,
            downloadButton("download_survey", "Download Survey_Structure",
                          width = "100%")
          ),
          column(4,
            downloadButton("download_headers", "Download Data_Headers",
                          width = "100%")
          )
        )
      )
    )
  )

  server <- function(input, output, session) {

    # Reactive values
    rv <- reactiveValues(
      files_found = FALSE,
      parse_complete = FALSE,
      results = NULL,
      output_files = NULL
    )

    # Load recent projects on startup
    observe({
      if (file.exists(recent_projects_file)) {
        recent <- tryCatch(readRDS(recent_projects_file), error = function(e) NULL)
        if (!is.null(recent) && length(recent) > 0) {
          # recent is a named vector: names = project names, values = paths
          # Display format: "ProjectName (path/to/folder)"
          display_names <- sapply(names(recent), function(proj_name) {
            path <- recent[[proj_name]]
            # Show last 2 parts of path for context
            path_parts <- strsplit(path, "/")[[1]]
            short_path <- paste(tail(path_parts, 2), collapse = "/")
            sprintf("%s (%s)", proj_name, short_path)
          })
          choices <- c("Select..." = "", setNames(recent, display_names))
          updateSelectInput(session, "recent_project", choices = choices)
        }
      }
    })

    # Handle recent project selection
    observeEvent(input$recent_project, {
      if (input$recent_project != "") {
        updateTextInput(session, "project_dir", value = input$recent_project)
      }
    })

    # Set up directory chooser
    volumes <- c(Home = fs::path_home(), shinyFiles::getVolumes()())
    shinyFiles::shinyDirChoose(input, "browse_dir", roots = volumes, session = session)

    # Handle directory selection
    observeEvent(input$browse_dir, {
      if (!is.integer(input$browse_dir)) {
        dir_path <- shinyFiles::parseDirPath(volumes, input$browse_dir)
        # Expand tilde and normalize path (fixes OneDrive/home directory paths)
        dir_path <- normalizePath(path.expand(dir_path), winslash = "/", mustWork = FALSE)
        if (length(dir_path) > 0) {
          updateTextInput(session, "project_dir", value = as.character(dir_path))
        }
      }
    })

    # Check files when directory changes
    observeEvent(input$project_dir, {
      req(input$project_dir)

      if (dir.exists(input$project_dir)) {
        # Check for required files
        files <- tryCatch({
          locate_input_files(input$project_dir, verbose = FALSE)
        }, error = function(e) {
          return(NULL)
        })

        if (!is.null(files)) {
          rv$files_found <- TRUE
          rv$project_name <- files$project_name

          # Auto-fill project name
          if (input$project_name == "") {
            updateTextInput(session, "project_name", value = files$project_name)
          }
        } else {
          rv$files_found <- FALSE
        }
      } else {
        rv$files_found <- FALSE
      }
    })

    # File status
    output$file_status <- renderUI({
      req(input$project_dir)

      if (!dir.exists(input$project_dir)) {
        div(class = "status-box status-error",
          strong("Directory not found"),
          br(),
          "Please enter a valid directory path."
        )
      } else if (!rv$files_found) {
        div(class = "status-box status-warning",
          strong("Required files not found"),
          br(),
          "Looking for:",
          tags$ul(
            tags$li("*_questionnaire.docx"),
            tags$li("*_data_export_map.xlsx"),
            tags$li("*_translation-export.xlsx")
          )
        )
      } else {
        div(class = "status-box status-success",
          strong("✓ All required files found"),
          br(),
          sprintf("Project: %s", rv$project_name)
        )
      }
    })

    # Run parser
    observeEvent(input$run_parser, {
      req(rv$files_found)

      output$parse_status <- renderUI({
        div(class = "status-box status-info",
          strong("Parsing in progress..."),
          br(),
          "This may take a few moments."
        )
      })

      # Save to recent projects
      tryCatch({
        # Load existing recent projects (named vector: project_name = path)
        recent <- if (file.exists(recent_projects_file)) {
          readRDS(recent_projects_file)
        } else {
          setNames(character(0), character(0))
        }

        # Get project name (either user input or detected)
        proj_name <- if (input$project_name != "") {
          input$project_name
        } else if (!is.null(rv$project_name)) {
          rv$project_name
        } else {
          basename(input$project_dir)
        }

        # Add current project (will overwrite if name exists)
        new_entry <- setNames(input$project_dir, proj_name)
        recent <- c(new_entry, recent[names(recent) != proj_name])
        recent <- head(recent, 10)  # Keep only 10 most recent

        saveRDS(recent, recent_projects_file)
      }, error = function(e) {
        # Ignore errors saving recent projects
      })

      # Run parser
      results <- tryCatch({
        run_alchemerparser(
          project_dir = input$project_dir,
          project_name = if (input$project_name != "") input$project_name else NULL,
          output_dir = if (input$output_dir != "") input$output_dir else NULL,
          verbose = TRUE
        )
      }, error = function(e) {
        output$parse_status <- renderUI({
          div(class = "status-box status-error",
            strong("Error during parsing:"),
            br(),
            as.character(e$message)
          )
        })
        return(NULL)
      })

      if (!is.null(results)) {
        rv$results <- results
        rv$parse_complete <- TRUE
        rv$output_files <- results$outputs

        output$parse_status <- renderUI({
          div(class = "status-box status-success",
            strong("✓ Parsing complete!"),
            br(),
            sprintf("Processed %d questions with %d data columns",
                   results$summary$n_questions,
                   results$summary$n_columns),
            br(),
            if (results$summary$n_flags > 0) {
              sprintf("⚠ %d items flagged for review", results$summary$n_flags)
            } else {
              "No validation issues found"
            }
          )
        })
      }
    })

    # Show results flag
    output$show_results <- reactive({
      rv$parse_complete
    })
    outputOptions(output, "show_results", suspendWhenHidden = FALSE)

    # Has flags
    output$has_flags <- reactive({
      rv$parse_complete && length(rv$results$validation_flags) > 0
    })
    outputOptions(output, "has_flags", suspendWhenHidden = FALSE)

    # Results summary
    output$results_summary <- renderUI({
      req(rv$parse_complete)

      type_dist <- rv$results$summary$type_distribution
      type_text <- paste(
        sapply(names(type_dist), function(t) {
          sprintf("%s: %d", t, type_dist[t])
        }),
        collapse = ", "
      )

      div(
        p(strong("Question Type Distribution:")),
        p(type_text)
      )
    })

    # Questions preview table
    output$questions_preview <- DT::renderDataTable({
      req(rv$parse_complete)

      # Build preview data frame
      rows <- list()

      for (q_num in names(rv$results$questions)) {
        q <- rv$results$questions[[q_num]]

        if (q$is_grid) {
          for (suffix in names(q$sub_questions)) {
            sub_q <- q$sub_questions[[suffix]]
            rows[[length(rows) + 1]] <- data.frame(
              QCode = sub_q$q_code,
              QText = substr(sub_q$question_text, 1, 50),
              Type = sub_q$variable_type,
              Columns = sub_q$n_columns,
              stringsAsFactors = FALSE
            )
          }
        } else {
          rows[[length(rows) + 1]] <- data.frame(
            QCode = q$q_code,
            QText = substr(q$question_text, 1, 50),
            Type = q$variable_type,
            Columns = q$n_columns,
            stringsAsFactors = FALSE
          )
        }
      }

      preview_df <- do.call(rbind, rows)

      DT::datatable(preview_df,
                   options = list(pageLength = 10, scrollX = TRUE),
                   rownames = FALSE)
    })

    # Flags table
    output$flags_table <- DT::renderDataTable({
      req(rv$parse_complete)
      req(length(rv$results$validation_flags) > 0)

      flags_df <- do.call(rbind, lapply(rv$results$validation_flags, function(f) {
        data.frame(
          QCode = f$q_code,
          Severity = f$severity,
          Issue = f$issue,
          Details = f$details,
          stringsAsFactors = FALSE
        )
      }))

      DT::datatable(flags_df,
                   options = list(pageLength = 10, scrollX = TRUE),
                   rownames = FALSE)
    })

    # Download handlers
    output$download_crosstab <- downloadHandler(
      filename = function() {
        basename(rv$output_files$crosstab_config)
      },
      content = function(file) {
        file.copy(rv$output_files$crosstab_config, file)
      }
    )

    output$download_survey <- downloadHandler(
      filename = function() {
        basename(rv$output_files$survey_structure)
      },
      content = function(file) {
        file.copy(rv$output_files$survey_structure, file)
      }
    )

    output$download_headers <- downloadHandler(
      filename = function() {
        basename(rv$output_files$data_headers)
      },
      content = function(file) {
        file.copy(rv$output_files$data_headers, file)
      }
    )
  }

  # Return shinyApp object
  shinyApp(ui = ui, server = server)
}

# Auto-launch GUI when script is sourced
if (!interactive()) {
  app <- run_alchemerparser_gui()
  runApp(app, launch.browser = TRUE)
} else {
  cat("AlchemerParser GUI loaded.\n")
  cat("Run with: run_alchemerparser_gui()\n")
}
