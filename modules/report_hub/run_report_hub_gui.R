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
  cat("\n", strrep("=", 80), "\n", sep = "")
  cat("  [REFUSE] ", code, ": ", title, "\n", sep = "")
  cat(strrep("=", 80), "\n\n", sep = "")
  cat("Problem:\n")
  cat("  ", problem, "\n\n", sep = "")
  cat("Why it matters:\n")
  cat("  ", why_it_matters, "\n\n", sep = "")
  cat("How to fix:\n")
  for (i in seq_along(how_to_fix)) {
    cat("  ", i, ". ", how_to_fix[i], "\n", sep = "")
  }
  cat("\n", strrep("=", 80), "\n\n", sep = "")

  # Build a TRS-style condition and signal it (preserves class for upstream handlers)
  cond <- structure(
    class = c("turas_refusal", "error", "condition"),
    list(
      message = paste0("[", code, "] ", title, ": ", problem),
      code = code,
      title = title,
      problem = problem,
      why_it_matters = why_it_matters,
      how_to_fix = how_to_fix,
      call = NULL
    )
  )
  stop(cond)
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

  TURAS_HOME <- Sys.getenv("TURAS_ROOT", getwd())

  # Load shared GUI theme
  source(file.path(TURAS_HOME, "modules", "shared", "lib", "gui_theme.R"))
  theme <- turas_gui_theme("Report Hub", "Unified Report Portal")
  hide_recents <- turas_hide_recents()

  # Recent configs file (last 5 configs, same approach as tabs module)
  RECENT_CONFIGS_FILE <- file.path(TURAS_HOME, ".recent_hub_configs.rds")

  load_recent_configs <- function() {
    if (file.exists(RECENT_CONFIGS_FILE)) {
      tryCatch(readRDS(RECENT_CONFIGS_FILE), error = function(e) character(0))
    } else {
      character(0)
    }
  }

  save_recent_configs <- function(configs) {
    tryCatch(saveRDS(configs, RECENT_CONFIGS_FILE), error = function(e) NULL)
  }

  add_recent_config <- function(config_path) {
    recent <- load_recent_configs()
    recent <- unique(c(config_path, recent))
    recent <- recent[1:min(5, length(recent))]
    save_recent_configs(recent)
  }

  # ==============================================================================
  # SHINY UI
  # ==============================================================================

  ui <- fluidPage(
    theme$head,

    # Module-specific styles (report list indicators)
    tags$head(tags$style(HTML("
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
        border: 1px solid var(--turas-border, #e2e8f0);
        font-size: 14px;
      }
      .report-found {
        border-left: 3px solid var(--turas-success, #16a34a);
      }
      .report-missing {
        border-left: 3px solid var(--turas-error, #dc2626);
      }
      .btn-open {
        background: var(--turas-accent, #1a2744);
        border: none;
        color: white;
        font-weight: 600;
        padding: 10px 24px;
        font-size: 14px;
        border-radius: var(--turas-radius-sm, 6px);
        margin-top: 10px;
      }
      .btn-open:hover {
        background: var(--turas-accent-light, #2a3f5f);
        color: white;
      }
    "))),

    # Header
    theme$header,

    # Main content
    div(class = "turas-content",

        # Step 1: Config file selection
        div(class = "turas-card",
          h3(class = "turas-card-title", "1. Select Config File"),
          p(class = "turas-card-subtitle",
            "Select the Report Hub config Excel file (.xlsx) containing Settings and Reports sheets."
          ),
          shinyFilesButton("config_btn",
                          "Browse for Config Excel",
                          "Select config file",
                          class = "btn btn-primary btn-lg",
                          multiple = FALSE),
          uiOutput("config_display"),
          if (!hide_recents) uiOutput("recent_configs_ui")
        ),

        # Step 2: Config preview (conditional)
        uiOutput("preview_ui"),

        # Step 3: Run button (conditional)
        uiOutput("run_ui"),

        # Step 4: Console output (conditional)
        uiOutput("console_ui")
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

    # Auto-load config from launcher (env var set by launch_turas.R)
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (!nzchar(pre_config)) pre_config <- Sys.getenv("TURAS_HUB_CONFIG", unset = "")
    Sys.unsetenv("TURAS_MODULE_CONFIG")
    if (nzchar(pre_config) && file.exists(pre_config)) {
      Sys.unsetenv("TURAS_HUB_CONFIG")
      config_path(normalizePath(pre_config, winslash = "/", mustWork = FALSE))
      add_recent_config(normalizePath(pre_config, winslash = "/", mustWork = FALSE))
      config_info(read_config_preview(pre_config))
    }

    # File chooser
    volumes <- turas_gui_volumes()
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
          add_recent_config(path)
          # Quick-read config for preview
          config_info(read_config_preview(path))
          # Reset previous run state
          console_text("")
          result_info(NULL)
        }
      }
    })

    # Handle recent config selection
    observeEvent(input$select_recent_config, {
      req(input$select_recent_config)
      path <- normalizePath(path.expand(input$select_recent_config),
                           winslash = "/", mustWork = FALSE)
      if (file.exists(path)) {
        config_path(path)
        add_recent_config(path)
        config_info(read_config_preview(path))
        console_text("")
        result_info(NULL)
      }
    })

    # Config file display
    output$config_display <- renderUI({
      path <- config_path()
      if (is.null(path)) {
        div(class = "turas-status-info",
          icon("info-circle"), " No config file selected. Click Browse to get started."
        )
      } else {
        div(class = "turas-file-display",
          tags$strong(basename(path)),
          tags$br(),
          tags$small(dirname(path))
        )
      }
    })

    # Recent configs list
    output$recent_configs_ui <- renderUI({
      recent <- load_recent_configs()
      if (length(recent) == 0) return(NULL)

      # Only show configs that still exist
      recent <- recent[file.exists(recent)]
      if (length(recent) == 0) return(NULL)

      div(class = "turas-recent-section",
        tags$hr(),
        h4("Recent Configs"),
        lapply(seq_along(recent), function(i) {
          tags$div(
            class = "turas-recent-item",
            onclick = sprintf("Shiny.setInputValue('select_recent_config', '%s', {priority: 'event'})",
                             gsub("'", "\\\\'", recent[i])),
            tags$strong(basename(recent[i])),
            tags$br(),
            tags$small(dirname(recent[i]))
          )
        })
      )
    })

    # Config preview
    output$preview_ui <- renderUI({
      info <- config_info()
      if (is.null(info)) return(NULL)

      # Handle read errors
      if (!is.null(info$error)) {
        return(div(class = "turas-card",
          h3(class = "turas-card-title", "2. Config Preview"),
          div(class = "turas-status-error",
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

      div(class = "turas-card",
        h3(class = "turas-card-title", "2. Config Preview"),
        tags$p(tags$strong("Project: "), info$title),
        tags$p(tags$strong("Reports: "), info$n_reports),
        output_display,
        tags$ul(class = "report-list", report_items),
        if (all_found) {
          div(class = "turas-status-success",
            "\u2705 All report files found. Ready to combine."
          )
        } else {
          div(class = "turas-status-warning",
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

      div(class = "turas-card",
        h3(class = "turas-card-title", "3. Combine Reports"),
        div(style = "text-align: center; margin: 20px 0;",
          actionButton("run_btn",
                      "COMBINE REPORTS",
                      class = "turas-btn-run",
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
        }, turas_refusal = function(e) {
          list(
            status = "REFUSED",
            code = e$code %||% "UNKNOWN",
            message = conditionMessage(e),
            how_to_fix = e$how_to_fix %||% "Check the console output above for details"
          )
        }, error = function(e) {
          list(
            status = "REFUSED",
            code = "CALC_UNEXPECTED_ERROR",
            message = e$message,
            how_to_fix = "Check the console output for details and report this as a bug if it persists"
          )
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

      div(class = "turas-card",
        h3(class = "turas-card-title", "4. Output"),
        pre(class = "turas-console", console_text()),
        if (!is.null(result) && result$status %in% c("PASS", "PARTIAL")) {
          div(class = "turas-status-success",
            tags$p(
              tags$strong("\u2705 Success: "),
              result$message
            ),
            tags$p(
              tags$strong("Output: "),
              tags$code(result$result$output_path)
            ),
            if (result$status == "PARTIAL" && length(result$warnings) > 0) {
              div(class = "turas-status-warning", style = "margin-top: 10px;",
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


# ==============================================================================
# HELPERS: Auto-detect header row (same approach as tabs module)
# ==============================================================================

#' Read a table-format Excel sheet with auto-detection of header row
#' @keywords internal
.read_table_preview <- function(file_path, sheet_name, required_cols) {
  df <- openxlsx::read.xlsx(file_path, sheet = sheet_name)

  if (all(required_cols %in% names(df))) {
    # Filter out help/description rows
    if (nrow(df) > 0 && any(grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                                   as.character(df[[1]]), ignore.case = TRUE))) {
      df <- df[!grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                       as.character(df[[1]]), ignore.case = TRUE), , drop = FALSE]
    }
    if (nrow(df) > 0) {
      all_na <- apply(df, 1, function(row) all(is.na(row) | trimws(as.character(row)) == ""))
      df <- df[!all_na, , drop = FALSE]
    }
    return(df)
  }

  # Auto-detect: scan first 10 rows for the header
  raw <- openxlsx::read.xlsx(file_path, sheet = sheet_name,
                              colNames = FALSE, rows = 1:10)
  header_row <- NULL
  for (r in seq_len(nrow(raw))) {
    row_vals <- as.character(unlist(raw[r, ]))
    if (all(required_cols %in% row_vals)) {
      header_row <- r
      break
    }
  }

  if (!is.null(header_row)) {
    df <- openxlsx::read.xlsx(file_path, sheet = sheet_name, startRow = header_row)
    if (nrow(df) > 0 && any(grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                                   as.character(df[[1]]), ignore.case = TRUE))) {
      df <- df[!grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                       as.character(df[[1]]), ignore.case = TRUE), , drop = FALSE]
    }
    if (nrow(df) > 0) {
      all_na <- apply(df, 1, function(row) all(is.na(row) | trimws(as.character(row)) == ""))
      df <- df[!all_na, , drop = FALSE]
    }
    return(df)
  }

  return(df)
}


#' Read a Settings-format Excel sheet with auto-detection of header row
#' @keywords internal
.read_settings_preview <- function(file_path, sheet_name) {
  df <- openxlsx::read.xlsx(file_path, sheet = sheet_name)
  col_lower <- tolower(names(df))

  has_kv <- ("setting" %in% col_lower && "value" %in% col_lower) ||
            ("field" %in% col_lower && "value" %in% col_lower)

  if (has_kv) {
    key_col <- if ("setting" %in% col_lower) which(col_lower == "setting")[1]
               else which(col_lower == "field")[1]
    value_col <- which(col_lower == "value")[1]
    keys <- as.character(df[[key_col]])
    values <- as.character(df[[value_col]])
    valid <- !is.na(keys) & nzchar(trimws(keys)) &
             !grepl("^\\[", keys) &
             !grepl("^(PROJECT|BRANDING|OUTPUT|SECTION)$", keys, ignore.case = TRUE)
    return(as.list(setNames(values[valid], tolower(trimws(keys[valid])))))
  }

  # Auto-detect: scan first 10 rows for Setting/Value or Field/Value header
  raw <- openxlsx::read.xlsx(file_path, sheet = sheet_name,
                              colNames = FALSE, rows = 1:10)
  for (r in seq_len(nrow(raw))) {
    row_vals <- tolower(as.character(unlist(raw[r, ])))
    if (("setting" %in% row_vals && "value" %in% row_vals) ||
        ("field" %in% row_vals && "value" %in% row_vals)) {
      df <- openxlsx::read.xlsx(file_path, sheet = sheet_name, startRow = r)
      col_lower <- tolower(names(df))
      key_col <- if ("setting" %in% col_lower) which(col_lower == "setting")[1]
                 else which(col_lower == "field")[1]
      value_col <- which(col_lower == "value")[1]
      keys <- as.character(df[[key_col]])
      values <- as.character(df[[value_col]])
      valid <- !is.na(keys) & nzchar(trimws(keys)) &
               !grepl("^\\[", keys) &
               !grepl("^(PROJECT|BRANDING|OUTPUT|SECTION)$", keys, ignore.case = TRUE)
      return(as.list(setNames(values[valid], tolower(trimws(keys[valid])))))
    }
  }

  # Fallback: single-row format
  settings <- as.list(df[1, ])
  names(settings) <- tolower(trimws(names(settings)))
  return(settings)
}


#' Quick-Read Config for Preview
#'
#' Reads the config file just enough to display a preview
#' without running full validation. Auto-detects header rows to support
#' both legacy and template formats.
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

    # Read Settings (auto-detect header row)
    settings <- .read_settings_preview(config_path, "Settings")
    title <- settings[["project_title"]]
    if (is.null(title) || is.na(title)) title <- "(No title found)"

    # Read Reports (auto-detect header row)
    reports_df <- .read_table_preview(config_path, "Reports",
                                       c("report_path", "report_label"))

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
    output_file <- settings[["output_file"]]
    if (!is.null(output_file) && (is.na(output_file) || !nzchar(trimws(output_file)))) output_file <- NULL
    output_dir <- settings[["output_dir"]]
    if (!is.null(output_dir) && (is.na(output_dir) || !nzchar(trimws(output_dir)))) output_dir <- NULL

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
