# ==============================================================================
# TURAS>REPORT HUB GUI - LAUNCHER
# ==============================================================================
# Purpose: Launch Report Hub GUI for combining multiple Turas HTML reports
# Location: modules/report_hub/run_report_hub_gui.R
# Usage: source("modules/report_hub/run_report_hub_gui.R") then run_report_hub_gui()
# ==============================================================================

# ==============================================================================
# TRS v1.0: EARLY REFUSAL FUNCTION (GUI ENTRY POINT)
# ==============================================================================

early_refuse <- function(code, title, problem, why_it_matters, how_to_fix) {
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

  for (i in seq_along(how_to_fix)) {
    msg <- paste0(msg, "  ", i, ". ", how_to_fix[i], "\n")
  }

  msg <- paste0(msg, "\n", strrep("=", 80), "\n")
  stop(msg, call. = FALSE)
}

run_report_hub_gui <- function() {

  # Required packages - check availability (TRS v1.0: no auto-install)
  required_packages <- c("shiny", "shinyFiles", "openxlsx")

  missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  if (length(missing_packages) > 0) {
    early_refuse(
      code = "PKG_MISSING_DEPENDENCY",
      title = "Missing Required Packages",
      problem = paste0("The following required packages are not installed: ",
                       paste(missing_packages, collapse = ", ")),
      why_it_matters = "The Report Hub GUI cannot run without these packages.",
      how_to_fix = c(
        paste0("Run the following command in R: install.packages(c(",
               paste(sprintf('"%s"', missing_packages), collapse = ", "), "))")
      )
    )
  }

  # Load packages
  suppressPackageStartupMessages({
    library(shiny)
    library(shinyFiles)
  })

  # === CONFIGURATION ===

  TURAS_HOME <- getwd()

  # ==============================================================================
  # SHINY UI
  # ==============================================================================

  ui <- fluidPage(
    tags$head(
      tags$style(HTML("
        .main-header {
          background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
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
          background-color: #fffbeb;
          border-left: 4px solid #f59e0b;
          padding: 15px;
          margin: 10px 0;
        }
        .status-error {
          background-color: #fef2f2;
          border-left: 4px solid #ef4444;
          padding: 15px;
          margin: 10px 0;
        }
        .btn-primary {
          background: #3b82f6;
          border: none;
        }
        .btn-primary:hover {
          background: #1d4ed8;
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
        .config-display {
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
        .report-list {
          list-style: none;
          padding: 0;
          margin: 10px 0;
        }
        .report-list li {
          padding: 8px 12px;
          margin: 4px 0;
          background: #f7fafc;
          border-radius: 6px;
          border: 1px solid #e2e8f0;
          font-size: 14px;
        }
        .report-found {
          border-left: 3px solid #48bb78;
        }
        .report-missing {
          border-left: 3px solid #ef4444;
        }
        .success-info {
          background: #f0fff4;
          border: 1px solid #c6f6d5;
          border-radius: 8px;
          padding: 15px;
          margin-top: 15px;
        }
        .btn-open {
          background: #3b82f6;
          border: none;
          color: white;
          font-weight: 600;
          padding: 10px 24px;
          font-size: 14px;
          border-radius: 6px;
          margin-top: 10px;
        }
        .btn-open:hover {
          background: #1d4ed8;
          color: white;
        }
      "))
    ),

    # Header
    div(class = "main-header",
      h1("\U0001F4CA TURAS>REPORT HUB"),
      p("Combine multiple Turas HTML reports into a unified portal"),
      p(style = "font-size: 14px; opacity: 0.9;",
        "Part of Turas Analytics Toolkit")
    ),

    # Main content
    fluidRow(
      column(12,

        # Step 1: Config file selection
        div(class = "card",
          h3("1. Select Config File"),
          p(style = "color: #6c757d; margin-bottom: 15px;",
            "Select the Report Hub config Excel file (.xlsx) containing Settings and Reports sheets."
          ),
          shinyFilesButton("config_btn",
                          "Browse for Config Excel",
                          "Select config file",
                          class = "btn btn-primary btn-lg",
                          multiple = FALSE),
          uiOutput("config_display")
        ),

        # Step 2: Config preview (conditional)
        uiOutput("preview_ui"),

        # Step 3: Run button (conditional)
        uiOutput("run_ui"),

        # Step 4: Console output (conditional)
        uiOutput("console_ui")
      )
    )
  )

  # ==============================================================================
  # SHINY SERVER
  # ==============================================================================

  server <- function(input, output, session) {

    # Reactive values
    config_path <- reactiveVal(NULL)
    config_info <- reactiveVal(NULL)
    console_text <- reactiveVal("")
    result_info <- reactiveVal(NULL)
    is_running <- reactiveVal(FALSE)

    # File chooser
    volumes <- c(Home = "~", Documents = "~/Documents", Desktop = "~/Desktop")
    shinyFileChoose(input, "config_btn", roots = volumes, session = session,
                   filetypes = c("xlsx"))

    # Handle file selection
    observeEvent(input$config_btn, {
      if (!is.integer(input$config_btn)) {
        fp <- parseFilePaths(volumes, input$config_btn)
        if (nrow(fp) > 0) {
          path <- normalizePath(path.expand(as.character(fp$datapath[1])),
                               winslash = "/", mustWork = FALSE)
          config_path(path)
          # Quick-read config for preview
          config_info(read_config_preview(path))
          # Reset previous run state
          console_text("")
          result_info(NULL)
        }
      }
    })

    # Config file display
    output$config_display <- renderUI({
      path <- config_path()
      if (is.null(path)) {
        div(class = "status-info",
          "\U0001F4C1 No config file selected. Click Browse to get started."
        )
      } else {
        div(class = "config-display",
          tags$strong(basename(path)),
          tags$br(),
          tags$small(style = "color: #666;", dirname(path))
        )
      }
    })

    # Config preview
    output$preview_ui <- renderUI({
      info <- config_info()
      if (is.null(info)) return(NULL)

      # Handle read errors
      if (!is.null(info$error)) {
        return(div(class = "card",
          h3("2. Config Preview"),
          div(class = "status-error",
            tags$strong("Error reading config: "), info$error
          )
        ))
      }

      # Build report list items
      report_items <- lapply(info$reports, function(r) {
        cls <- if (r$exists) "report-found" else "report-missing"
        icon <- if (r$exists) "\u2705" else "\u274C"
        tags$li(class = cls,
          paste(icon, r$label, "\u2014", basename(r$path))
        )
      })

      all_found <- all(sapply(info$reports, function(r) r$exists))
      missing_count <- sum(!sapply(info$reports, function(r) r$exists))

      # Build output path display
      output_display <- NULL
      if (!is.null(info$output_file) || !is.null(info$output_dir)) {
        out_parts <- character(0)
        if (!is.null(info$output_dir)) out_parts <- c(out_parts, info$output_dir)
        if (!is.null(info$output_file)) {
          out_parts <- c(out_parts, info$output_file)
        } else {
          out_parts <- c(out_parts, "(auto-generated filename)")
        }
        output_display <- tags$p(tags$strong("Output: "),
          tags$code(paste(out_parts, collapse = "/")))
      }

      div(class = "card",
        h3("2. Config Preview"),
        tags$p(tags$strong("Project: "), info$title),
        tags$p(tags$strong("Reports: "), info$n_reports),
        output_display,
        tags$ul(class = "report-list", report_items),
        if (all_found) {
          div(class = "status-success",
            "\u2705 All report files found. Ready to combine."
          )
        } else {
          div(class = "status-warning",
            sprintf("\u26A0\uFE0F %d report file(s) not found. Check paths in your config.",
                    missing_count)
          )
        }
      )
    })

    # Run button
    output$run_ui <- renderUI({
      info <- config_info()
      if (is.null(info) || !is.null(info$error)) return(NULL)

      div(class = "card",
        h3("3. Combine Reports"),
        div(style = "text-align: center; margin: 20px 0;",
          actionButton("run_btn",
                      "COMBINE REPORTS",
                      class = "btn-run",
                      icon = icon("play-circle"),
                      disabled = is_running()),
          div(style = "margin-top: 12px;",
            checkboxInput("auto_open", "Open result in browser when done",
                         value = TRUE)
          )
        )
      )
    })

    # Run handler
    observeEvent(input$run_btn, {
      req(config_path())

      is_running(TRUE)
      console_text("Starting Report Hub...\n\n")
      result_info(NULL)

      # Save current working directory
      old_wd <- getwd()

      withProgress(message = "Combining reports...", value = 0.1, {

        # Source the module
        hub_dir <- file.path(TURAS_HOME, "modules", "report_hub")
        main_file <- file.path(hub_dir, "00_main.R")

        if (!file.exists(main_file)) {
          console_text(paste0(
            console_text(),
            "\nERROR: Could not find 00_main.R at: ", main_file, "\n"
          ))
          is_running(FALSE)
          return()
        }

        # Source the report hub module
        setwd(TURAS_HOME)
        source(main_file, local = TRUE)

        setProgress(0.3, detail = "Parsing and combining reports...")

        # Capture console output
        capture_file <- tempfile()
        sink(capture_file, type = "output")

        result <- tryCatch({
          combine_reports(config_path())
        }, error = function(e) {
          list(status = "REFUSED", message = e$message)
        }, finally = {
          sink(type = "output")
        })

        setProgress(0.9, detail = "Finishing up...")

        # Read captured output
        captured <- readLines(capture_file, warn = FALSE)
        unlink(capture_file)

        console_text(paste0(
          console_text(),
          paste(captured, collapse = "\n"),
          "\n"
        ))

        result_info(result)

        if (result$status %in% c("PASS", "PARTIAL")) {
          showNotification("Reports combined successfully!",
                          type = "message", duration = 5)
          if (isTRUE(input$auto_open)) {
            browseURL(result$result$output_path)
          }
        } else {
          # Console output for debugging (Shiny error pattern)
          cat("\n=== TURAS ERROR ===\n")
          cat("Status:", result$status, "\n")
          cat("Message:", result$message, "\n")
          if (!is.null(result$how_to_fix)) {
            cat("Fix:", result$how_to_fix, "\n")
          }
          cat("==================\n\n")

          showNotification(
            paste("Failed:", result$message),
            type = "error", duration = NULL
          )
        }
      })

      # Restore working directory
      setwd(old_wd)
      is_running(FALSE)
    })

    # Console output
    output$console_ui <- renderUI({
      if (console_text() == "") return(NULL)

      result <- result_info()

      div(class = "card",
        h3("4. Output"),
        pre(class = "console-output", console_text()),
        if (!is.null(result) && result$status %in% c("PASS", "PARTIAL")) {
          div(class = "success-info",
            tags$p(
              tags$strong("\u2705 Success: "),
              result$message
            ),
            tags$p(
              tags$strong("Output: "),
              tags$code(result$result$output_path)
            ),
            if (result$status == "PARTIAL" && length(result$warnings) > 0) {
              div(class = "status-warning", style = "margin-top: 10px;",
                tags$strong("Warnings:"),
                tags$ul(lapply(result$warnings, tags$li))
              )
            },
            actionButton("open_result", "Open in Browser",
                        class = "btn-open",
                        icon = icon("external-link-alt"))
          )
        }
      )
    })

    # Open result button
    observeEvent(input$open_result, {
      req(result_info())
      browseURL(result_info()$result$output_path)
    })
  }

  # Launch
  cat("\nLaunching Turas>Report Hub GUI...\n\n")
  shinyApp(ui = ui, server = server)
}


#' Quick-Read Config for Preview
#'
#' Reads the config file just enough to display a preview
#' without running full validation.
#'
#' @param config_path Path to the config Excel file
#' @return List with title, n_reports, reports, and optional error
read_config_preview <- function(config_path) {
  tryCatch({
    # Check sheets exist
    sheets <- openxlsx::getSheetNames(config_path)
    if (!"Settings" %in% sheets || !"Reports" %in% sheets) {
      return(list(
        title = "Invalid config",
        n_reports = 0,
        reports = list(),
        error = "Config file must have 'Settings' and 'Reports' sheets."
      ))
    }

    # Read Settings
    settings_raw <- openxlsx::read.xlsx(config_path, sheet = "Settings")

    # Parse settings (handle key-value or single-row format)
    col_lower <- tolower(names(settings_raw))
    if ("field" %in% col_lower && "value" %in% col_lower) {
      field_col <- which(col_lower == "field")[1]
      value_col <- which(col_lower == "value")[1]
      settings <- setNames(
        as.character(settings_raw[[value_col]]),
        tolower(trimws(as.character(settings_raw[[field_col]])))
      )
      title <- settings[["project_title"]]
    } else {
      title <- settings_raw$project_title[1]
    }

    if (is.null(title) || is.na(title)) title <- "(No title found)"

    # Read Reports
    reports_df <- openxlsx::read.xlsx(config_path, sheet = "Reports")

    if (!"report_path" %in% names(reports_df) ||
        !"report_label" %in% names(reports_df)) {
      return(list(
        title = title,
        n_reports = 0,
        reports = list(),
        error = "Reports sheet missing required columns (report_path, report_label)."
      ))
    }

    config_dir <- dirname(config_path)

    report_list <- lapply(seq_len(nrow(reports_df)), function(i) {
      rpath <- as.character(reports_df$report_path[i])
      rlabel <- as.character(reports_df$report_label[i])
      if (is.na(rpath)) rpath <- ""
      if (is.na(rlabel)) rlabel <- paste("Report", i)

      # Check if path exists (absolute or relative to config)
      found <- file.exists(rpath) || file.exists(file.path(config_dir, rpath))
      list(label = rlabel, path = rpath, exists = found)
    })

    # Extract output settings
    output_file <- NULL
    output_dir <- NULL
    if ("field" %in% col_lower && "value" %in% col_lower) {
      field_col <- which(col_lower == "field")[1]
      value_col <- which(col_lower == "value")[1]
      fields_lower <- tolower(trimws(as.character(settings_raw[[field_col]])))
      values <- as.character(settings_raw[[value_col]])
      if ("output_file" %in% fields_lower) {
        output_file <- values[which(fields_lower == "output_file")[1]]
        if (is.na(output_file) || !nzchar(trimws(output_file))) output_file <- NULL
      }
      if ("output_dir" %in% fields_lower) {
        output_dir <- values[which(fields_lower == "output_dir")[1]]
        if (is.na(output_dir) || !nzchar(trimws(output_dir))) output_dir <- NULL
      }
    } else {
      if ("output_file" %in% names(settings_raw)) {
        output_file <- settings_raw$output_file[1]
        if (is.na(output_file) || !nzchar(trimws(output_file))) output_file <- NULL
      }
      if ("output_dir" %in% names(settings_raw)) {
        output_dir <- settings_raw$output_dir[1]
        if (is.na(output_dir) || !nzchar(trimws(output_dir))) output_dir <- NULL
      }
    }

    list(title = title, n_reports = nrow(reports_df), reports = report_list,
         output_file = output_file, output_dir = output_dir)

  }, error = function(e) {
    list(
      title = "Error reading config",
      n_reports = 0,
      reports = list(),
      error = e$message
    )
  })
}
