# ==============================================================================
# ALCHEMER PARSER - SHINY GUI
# ==============================================================================
# Interactive GUI for AlchemerParser module
# ==============================================================================

# Early refuse function for use before TRS guard is loaded
early_refuse <- function(code, title, problem, why_it_matters, how_to_fix) {
  message <- paste0(
    "\n================================================================================\n",
    "  [REFUSE] ", code, ": ", title, "\n",
    "================================================================================\n\n",
    "Problem:\n",
    "  ", problem, "\n\n",
    "Why it matters:\n",
    "  ", why_it_matters, "\n\n",
    "How to fix:\n"
  )

  for (step in how_to_fix) {
    message <- paste0(message, "  - ", step, "\n")
  }

  message <- paste0(message, "\n================================================================================\n")
  cat(message)
  stop(message, call. = FALSE)
}

# Required package check (TRS v1.0: no auto-install)
if (!requireNamespace("shiny", quietly = TRUE)) {
  early_refuse(
    code = "PKG_MISSING_DEPENDENCY",
    title = "Missing Required Package",
    problem = "The required package 'shiny' is not installed.",
    why_it_matters = "The AlchemerParser GUI cannot run without this package.",
    how_to_fix = "Run: install.packages('shiny')"
  )
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
  # DT package added for interactive data table displays
  required_packages <- c("readxl", "openxlsx", "officer", "shiny", "shinyFiles", "fs", "DT")
  missing_packages <- character(0)

  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing_packages <- c(missing_packages, pkg)
    }
  }

  if (length(missing_packages) > 0) {
    early_refuse(
      code = "PKG_MISSING_DEPENDENCIES",
      title = "Missing Required Packages",
      problem = paste0("The following packages are required but not installed: ",
                      paste(missing_packages, collapse = ", ")),
      why_it_matters = "AlchemerParser GUI cannot run without these dependencies.",
      how_to_fix = c(
        sprintf("Run: install.packages(c(%s))",
                paste0("'", missing_packages, "'", collapse = ", ")),
        "Then restart R and try again"
      )
    )
  }
}

check_dependencies()

#' Run AlchemerParser GUI
#'
#' @description
#' Launches interactive Shiny GUI for AlchemerParser.
#'
#' @export
run_alchemerparser_gui <- function() {

  # Derive turas root from script_dir (modules/AlchemerParser -> ../../)
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root) || !dir.exists(file.path(turas_root, "modules"))) {
    turas_root <- dirname(dirname(script_dir))
  }

  # Load shared GUI theme
  source(file.path(turas_root, "modules", "shared", "lib", "gui_theme.R"))
  theme <- turas_gui_theme("AlchemerParser", "Parse Alchemer Surveys & Generate Configs")
  hide_recents <- turas_hide_recents()

  # Recent projects file — persistent storage in TURAS_PROJECTS_ROOT/.turas/
  # Defined here (after gui_theme.R is sourced) so turas_recent_file() is available.
  recent_projects_file <- turas_recent_file("alchemerparser")

  ui <- fluidPage(
    theme$head,

    # Header
    theme$header,

    # Main content
    div(class = "turas-content-wide",

      # Step 1: Select Project Directory
      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 1: Select Project Directory"),

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

        # Recent projects (hidden when launched from hub)
        if (!hide_recents) {
          selectInput("recent_project", "Or select a recent project:",
                     choices = c("Select..." = ""), width = "100%")
        },

        uiOutput("file_status")
      ),

      # Step 2: Review and Parse
      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 2: Parse Files"),

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
                    class = "turas-btn-run"),

        uiOutput("parse_status")
      ),

      # Step 3: Review Results
      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 3: Review Results"),

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
      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 4: Download Output Files"),

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

    # Auto-load project directory from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      if (dir.exists(pre_config)) {
        updateTextInput(session, "project_dir",
                        value = normalizePath(pre_config, winslash = "/", mustWork = FALSE))
      } else if (file.exists(pre_config)) {
        # If a file was passed, use its parent directory
        updateTextInput(session, "project_dir",
                        value = normalizePath(dirname(pre_config), winslash = "/", mustWork = FALSE))
      }
    }

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
    volumes <- turas_gui_volumes()
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
        div(class = "turas-status-error",
          strong("Directory not found"),
          br(),
          "Please enter a valid directory path."
        )
      } else if (!rv$files_found) {
        div(class = "turas-status-warning",
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
        div(class = "turas-status-success",
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
        div(class = "turas-status-info",
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
        recent <- head(recent, TURAS_MAX_RECENTS)

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
          div(class = "turas-status-error",
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
          div(class = "turas-status-success",
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
