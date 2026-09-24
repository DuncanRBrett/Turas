# ==============================================================================
# TURAS WHAT IF MODULE - GUI LAUNCHER
# ==============================================================================
#
# The What If tile in launch_turas(). Pick the project folder, pick (or
# create) the What if config, run. The run writes {output_name}.xlsx for the
# analyst and {output_name}_whatif_island.json; point the tabs setting
# whatif_island at the .json and rebuild the tabs report to add the What if tab.
# Whether that tab is the open or the client-safe version is decided when the
# tabs report is built, by its "Who is this file for?" choice.
# ==============================================================================

#' Run the What if GUI
#'
#' @return A shinyApp object
#' @export
run_whatif_gui <- function() {
  early_refuse <- function(code, title, problem, why_it_matters, how_to_fix) {
    msg <- paste0(
      "\n================================================================================\n",
      sprintf("  [REFUSE] %s: %s\n", code, title),
      "================================================================================\n\n",
      "Problem:\n  ", problem, "\n\nWhy it matters:\n  ", why_it_matters, "\n\nHow to fix:\n",
      paste0("  ", how_to_fix, "\n", collapse = ""),
      "\n================================================================================\n")
    cat(msg)
    stop(msg, call. = FALSE)
  }
  missing_packages <- c("shiny", "shinyFiles")[!vapply(c("shiny", "shinyFiles"), requireNamespace,
                                                       logical(1), quietly = TRUE)]
  if (length(missing_packages)) {
    early_refuse("PKG_MISSING_DEPENDENCY", "Missing Required Packages",
                 sprintf("Not installed: %s", paste(missing_packages, collapse = ", ")),
                 "The What if GUI cannot run without them.",
                 sprintf("install.packages(c(%s))", paste(sprintf('"%s"', missing_packages), collapse = ", ")))
  }
  suppressPackageStartupMessages({
    library(shiny)
    library(shinyFiles)
  })

  turas_root <- Sys.getenv("TURAS_ROOT", getwd())
  if (!file.exists(file.path(turas_root, "launch_turas.R")) &&
      file.exists(file.path(dirname(turas_root), "launch_turas.R"))) {
    turas_root <- dirname(turas_root)
  }
  source(file.path(turas_root, "modules", "shared", "lib", "gui_theme.R"))
  theme <- turas_gui_theme("What If", "Where to direct effort")
  hide_recents <- turas_hide_recents()
  recent_file <- turas_recent_file("whatif")

  load_recent <- function() {
    if (file.exists(recent_file)) tryCatch(readRDS(recent_file), error = function(e) list()) else list()
  }
  add_recent <- function(dir) {
    recent <- load_recent()
    recent <- recent[!vapply(recent, function(x) identical(x$project_dir, dir), logical(1))]
    recent <- c(list(list(project_dir = dir)), recent)
    tryCatch(saveRDS(recent[seq_len(min(TURAS_MAX_RECENTS, length(recent)))], recent_file),
             error = function(e) NULL)
  }
  detect_configs <- function(dir) {
    if (!dir.exists(dir)) return(character(0))
    f <- list.files(dir, pattern = "\\.xlsx$", ignore.case = TRUE)
    f[grepl("what.?if", f, ignore.case = TRUE) & !grepl("^~\\$", f)]
  }

  ui <- fluidPage(
    theme$head,
    theme$header,
    div(class = "turas-content",
      div(class = "turas-card",
        h4(class = "turas-card-title", "Step 1: Select Project Directory"),
        fluidRow(
          column(if (!hide_recents) 8 else 12,
            shinyDirButton("project_dir_btn", "Browse for Project Folder", "Select project directory",
                           class = "btn turas-btn-primary", icon = icon("folder-open"))),
          if (!hide_recents) column(4, uiOutput("recent_ui"))
        ),
        uiOutput("project_display")
      ),
      conditionalPanel(
        condition = "output.project_selected",
        div(class = "turas-card",
          h4(class = "turas-card-title", "Step 2: Select the What if Config"),
          uiOutput("config_selector"),
          uiOutput("config_display"),
          div(class = "turas-status-info",
            tags$strong("Levers: "), "the config's Levers sheet decides which areas the model uses. ",
            "Include = Y for a lever, N to leave it out, Symptom for something that moves with the ",
            "outcome but is not a lever (it is reported, never modelled)."),
          actionButton("make_template", "Create a blank What if config in this folder",
                       class = "btn", icon = icon("file-excel"))
        )
      ),
      conditionalPanel(
        condition = "output.ready_to_run",
        div(class = "turas-card",
          actionButton("run", "Run What If", class = "btn turas-btn-run", icon = icon("play")),
          div(class = "turas-status-info", style = "margin-top: 10px;",
            "The run writes a workbook for you and a contribution file for the tabs report. ",
            "Open or client-safe is chosen later, when the tabs report is built.")
        )
      ),
      conditionalPanel(
        condition = "output.show_console",
        div(class = "turas-card",
          h4(class = "turas-card-title", "Output"),
          div(class = "turas-console", verbatimTextOutput("console_output"))
        )
      )
    )
  )

  server <- function(input, output, session) {
    files <- reactiveValues(project_dir = NULL, config_file = NULL)
    console_text <- reactiveVal("")
    is_running <- reactiveVal(FALSE)

    pre <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      if (dir.exists(pre)) {
        files$project_dir <- normalizePath(pre, winslash = "/", mustWork = FALSE)
        d <- detect_configs(files$project_dir)
        if (length(d)) files$config_file <- file.path(files$project_dir, d[1])
      } else if (file.exists(pre)) {
        files$config_file <- normalizePath(pre, winslash = "/", mustWork = FALSE)
        files$project_dir <- dirname(files$config_file)
      }
    }

    volumes <- turas_gui_volumes()
    shinyDirChoose(input, "project_dir_btn", roots = volumes, session = session)
    observeEvent(input$project_dir_btn, {
      if (!is.integer(input$project_dir_btn)) {
        dir_path <- normalizePath(path.expand(parseDirPath(volumes, input$project_dir_btn)),
                                  winslash = "/", mustWork = FALSE)
        if (length(dir_path) && dir.exists(dir_path)) {
          files$project_dir <- dir_path
          d <- detect_configs(dir_path)
          files$config_file <- if (length(d)) file.path(dir_path, d[1]) else NULL
        }
      }
    })
    output$recent_ui <- renderUI({
      recent <- load_recent()
      if (!length(recent)) return(NULL)
      div(tags$label("Recent:", style = "font-weight: 600; display: block;"),
          lapply(recent, function(p) tags$div(class = "turas-recent-item",
            onclick = sprintf("Shiny.setInputValue('select_recent', '%s', {priority: 'event'})",
                              gsub("'", "\\\\'", p$project_dir)),
            tags$strong(basename(p$project_dir)), tags$br(), tags$small(style = "color: #666;", p$project_dir))))
    })
    observeEvent(input$select_recent, {
      dir_path <- normalizePath(path.expand(input$select_recent), winslash = "/", mustWork = FALSE)
      if (dir.exists(dir_path)) {
        files$project_dir <- dir_path
        d <- detect_configs(dir_path)
        files$config_file <- if (length(d)) file.path(dir_path, d[1]) else NULL
      }
    })
    output$project_display <- renderUI({
      req(files$project_dir)
      div(class = "turas-file-display", tags$strong(basename(files$project_dir)), tags$br(),
          tags$small(files$project_dir), div(class = "status-success", "✓ Directory selected"))
    })
    output$config_selector <- renderUI({
      req(files$project_dir)
      d <- detect_configs(files$project_dir)
      if (length(d)) {
        radioButtons("config_select", "What if configs in this folder:", choices = d,
                     selected = basename(files$config_file %||% d[1]))
      } else {
        div(class = "status-error", "No What if config here yet (a file with 'WhatIf' in its name).")
      }
    })
    observeEvent(input$config_select, {
      if (!is.null(files$project_dir)) files$config_file <- file.path(files$project_dir, input$config_select)
    })
    output$config_display <- renderUI({
      req(files$config_file)
      div(class = "turas-file-display", tags$strong(basename(files$config_file)), tags$br(),
          tags$small(files$config_file),
          if (file.exists(files$config_file)) div(class = "status-success", "✓ Config found")
          else div(class = "status-error", "✗ File not found"))
    })
    observeEvent(input$make_template, {
      req(files$project_dir)
      target <- file.path(files$project_dir, "WhatIf_Config.xlsx")
      if (file.exists(target)) {
        showNotification("WhatIf_Config.xlsx already exists in this folder; it was not overwritten.",
                         type = "warning")
        return()
      }
      res <- tryCatch({
        source(file.path(turas_root, "modules", "whatif", "source_whatif.R"))
        source(file.path(turas_root, "modules", "shared", "template_styles.R"))
        source(file.path(turas_root, "modules", "whatif", "lib", "generate_config_template.R"))
        generate_whatif_config_template(target)
      }, error = function(e) list(status = "ERROR", message = conditionMessage(e)))
      if (identical(res$status, "PASS")) {
        files$config_file <- target
        showNotification("Created WhatIf_Config.xlsx. Fill in its Settings, Levers and Context sheets, then run.",
                         type = "message", duration = 8)
      } else {
        cat("\n=== TURAS ERROR ===\nWhat if template:", res$message %||% "", "\n==================\n")
        showNotification(paste("Could not create the config:", res$message %||% ""), type = "error", duration = NULL)
      }
    })

    output$project_selected <- reactive({ !is.null(files$project_dir) })
    outputOptions(output, "project_selected", suspendWhenHidden = FALSE)
    output$ready_to_run <- reactive({
      !is.null(files$config_file) && file.exists(files$config_file) && !is_running()
    })
    outputOptions(output, "ready_to_run", suspendWhenHidden = FALSE)
    output$show_console <- reactive({ nchar(console_text()) > 0 })
    outputOptions(output, "show_console", suspendWhenHidden = FALSE)
    output$console_output <- renderText(paste(console_text(), collapse = "\n"))

    observeEvent(input$run, {
      req(files$config_file)
      is_running(TRUE)
      on.exit(is_running(FALSE), add = TRUE)
      add_recent(files$project_dir)
      out <- "Loading the What if module...\n\n"
      console_text(out)
      tryCatch({
        withProgress(message = "Running What If...", value = 0.1, {
          source(file.path(turas_root, "modules", "whatif", "source_whatif.R"))
          captured <- capture_console_all({ res <- run_whatif(files$config_file) })
          out <- paste0(out, paste(captured$combined_output, collapse = "\n"))
          if (is_refusal(res) || is_error(res)) {
            out <- paste0(out, "\n\nWhat if run REFUSED: see the message above. Nothing was written.")
            showNotification("The What if run was refused. Read the console for the reason.", type = "error",
                             duration = NULL)
          } else {
            out <- paste0(out, "\n\n", if (identical(res$status, "PARTIAL")) "Finished with warnings (see the Preflight sheet)." else "Finished.",
                          "\n\nAnalyst workbook: ", res$files$excel,
                          "\nContribution file: ", res$files$island,
                          "\n\nTo add the What if tab to the tabs report, set whatif_island on the tabs config's",
                          "\nSettings sheet to the contribution file above, then rebuild the tabs report.",
                          "\nThe contribution file holds respondent rows: keep it with the project, never send it.")
            if (identical(res$status, "PARTIAL")) {
              showNotification("What if finished with warnings. Check the Preflight sheet.", type = "warning",
                               duration = NULL)
            }
          }
          incProgress(0.9)
        })
      }, error = function(e) {
        cat("\n=== TURAS ERROR ===\nMessage:", conditionMessage(e), "\n==================\n\n")
        out <<- paste0(out, "\n\nError: ", conditionMessage(e))
        showNotification(paste("Error:", conditionMessage(e)), type = "error", duration = 10)
      })
      console_text(out)
    })
  }

  shinyApp(ui = ui, server = server)
}
