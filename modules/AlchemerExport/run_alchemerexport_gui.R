# ==============================================================================
# ALCHEMER EXPORT - SHINY GUI
# ==============================================================================
# Fetches survey structure from the Alchemer v5 API and generates populated
# Turas config templates (Survey_Structure, Crosstab_Config, Data_Headers).
# ==============================================================================

early_refuse <- function(code, title, problem, how_to_fix) {
  msg <- paste0(
    "\n================================================================================\n",
    "  [REFUSE] ", code, ": ", title, "\n",
    "================================================================================\n\n",
    "Problem:\n  ", problem, "\n\nHow to fix:\n"
  )
  for (step in how_to_fix) msg <- paste0(msg, "  - ", step, "\n")
  msg <- paste0(msg, "\n================================================================================\n")
  cat(msg)
  stop(msg, call. = FALSE)
}

required_pkgs <- c("shiny", "shinyFiles", "openxlsx", "data.table", "httr", "DT")
missing_pkgs  <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1L), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  early_refuse(
    code       = "PKG_MISSING_DEPENDENCIES",
    title      = "Missing Required Packages",
    problem    = paste("Not installed:", paste(missing_pkgs, collapse = ", ")),
    how_to_fix = sprintf("Run: install.packages(c(%s))",
                         paste0("'", missing_pkgs, "'", collapse = ", "))
  )
}

suppressPackageStartupMessages({
  library(shiny)
  library(shinyFiles)
})

get_script_dir <- function() {
  for (i in seq_len(sys.nframe())) {
    file <- sys.frame(i)$ofile
    if (!is.null(file) && grepl("run_alchemerexport_gui", file))
      return(dirname(normalizePath(file)))
  }
  args     <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0)
    return(dirname(normalizePath(sub("--file=", "", file_arg))))
  file.path(getwd(), "modules", "AlchemerExport")
}

script_dir <- get_script_dir()

#' Run Alchemer Export GUI
#'
#' @description
#' Launches interactive Shiny GUI for Alchemer Export.
#' Fetches survey structure via the Alchemer v5 API and writes populated
#' Survey_Structure, Crosstab_Config and (optionally) Data_Headers workbooks.
#'
#' @export
run_alchemerexport_gui <- function() {

  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root) || !dir.exists(file.path(turas_root, "modules")))
    turas_root <- dirname(dirname(script_dir))

  source(file.path(turas_root, "modules", "shared", "lib", "gui_theme.R"))
  theme       <- turas_gui_theme("Alchemer Export", "Fetch survey structure & generate Turas config templates")
  hide_recents <- turas_hide_recents()

  recent_projects_file <- turas_recent_file("alchemerexport")

  # Source the core export function (TURAS_ROOT already set, so path resolves)
  Sys.setenv(TURAS_ROOT = turas_root)
  source(file.path(turas_root, "scripts", "alchemer_to_turas.R"))

  # ---- UI --------------------------------------------------------------------

  ui <- fluidPage(
    theme$head,
    theme$header,

    div(class = "turas-content",

      # ---- Step 1: Survey ID --------------------------------------------------
      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 1: Alchemer Survey"),

        fluidRow(
          column(4,
            textInput("survey_id", "Build ID:",
                      placeholder = "e.g. 8822527", width = "100%")
          ),
          column(4,
            checkboxGroupInput(
              "targets", "Generate configs for:",
              choices  = c("Tabs (Survey_Structure + Crosstab_Config)" = "tabs",
                           "Brand (Survey_Structure_Brand + Brand_Config)"  = "brand"),
              selected = "tabs"
            )
          )
        ),

        if (!hide_recents) uiOutput("recent_ui"),

        uiOutput("cred_status")
      ),

      # ---- Step 2: Files ------------------------------------------------------
      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 2: Files"),

        p(class = "turas-help-text",
          "Provide the Alchemer data export so Data_Headers can produce one ",
          "cell per export column, each holding the Survey_Structure code that ",
          "owns that column (colon-format options translated via the API, ",
          "metadata cells passed through with tidy names). Without an export, ",
          "Data_Headers falls back to a structure-only row."),

        fluidRow(
          column(8,
            textInput("data_export", "Data Export File (CSV or XLSX):",
                      placeholder = "/path/to/data_export.xlsx",
                      width = "100%")
          ),
          column(4,
            br(),
            shinyFiles::shinyFilesButton("browse_export", "Browse...",
                                         title    = "Select Alchemer Data Export",
                                         multiple = FALSE,
                                         buttonType = "default")
          )
        ),

        fluidRow(
          column(8,
            textInput("output_dir", "Output Directory:",
                      placeholder = "/path/to/output/folder", width = "100%")
          ),
          column(4,
            br(),
            shinyFiles::shinyDirButton("browse_output", "Browse...",
                                       title      = "Select Output Directory",
                                       buttonType = "default")
          )
        )
      ),

      # ---- Step 3: Generate ---------------------------------------------------
      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 3: Generate Config Files"),

        actionButton("run_export", "Generate Config Files",
                     class = "turas-btn-run", width = "220px"),

        br(), br(),

        uiOutput("run_status"),

        conditionalPanel(
          condition = "output.show_log",
          verbatimTextOutput("run_log")
        )
      ),

      # ---- Step 4: Downloads (shown after successful run) ---------------------
      uiOutput("downloads_card")
    )
  )

  # ---- Server ----------------------------------------------------------------

  server <- function(input, output, session) {

    rv <- reactiveValues(
      complete = FALSE,
      result   = NULL,
      log      = NULL
    )

    # Pre-load from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      updateTextInput(session, "survey_id", value = pre_config)
    }

    # Recent surveys — tile list (matches tabs/keydriver/etc. pattern)
    recent_trigger <- reactiveVal(0L)
    load_recents <- function() {
      if (!file.exists(recent_projects_file)) return(list())
      val <- tryCatch(readRDS(recent_projects_file), error = function(e) NULL)
      if (is.null(val)) list() else val
    }

    output$recent_ui <- renderUI({
      recent_trigger()
      if (hide_recents) return(NULL)
      recent <- load_recents()
      if (length(recent) == 0L) return(NULL)

      div(class = "turas-recent-section",
        tags$hr(),
        h4("Recent Surveys"),
        lapply(seq_along(recent), function(i) {
          entry <- recent[[i]]
          key   <- names(recent)[[i]]
          subtitle <- entry$output_dir %||% ""
          tags$div(
            class = "turas-recent-item",
            onclick = sprintf(
              "Shiny.setInputValue('select_recent', '%s', {priority: 'event'})",
              gsub("'", "\\\\'", key, fixed = TRUE)
            ),
            tags$strong(sprintf("Survey %s", entry$survey_id %||% key)),
            tags$br(),
            tags$small(subtitle)
          )
        })
      )
    })

    observeEvent(input$select_recent, {
      req(nzchar(input$select_recent))
      recent <- load_recents()
      entry  <- recent[[input$select_recent]]
      if (is.null(entry)) return()
      updateTextInput(session, "survey_id",   value = entry$survey_id %||% "")
      updateTextInput(session, "output_dir",  value = entry$output_dir %||% "")
      updateTextInput(session, "data_export", value = entry$data_export %||% "")
      if (!is.null(entry$targets))
        updateCheckboxGroupInput(session, "targets", selected = entry$targets)
    })

    # API credential status
    output$cred_status <- renderUI({
      token  <- nzchar(Sys.getenv("ALCHEMER_API_TOKEN",  ""))
      secret <- nzchar(Sys.getenv("ALCHEMER_API_SECRET", ""))
      if (token && secret) {
        div(class = "turas-status-success",
            "API credentials found in environment")
      } else {
        div(class = "turas-status-warning",
            strong("API credentials not set."),
            br(),
            "Add ALCHEMER_API_TOKEN and ALCHEMER_API_SECRET to ~/.Renviron and restart R.")
      }
    })

    # File / dir browsers
    volumes <- turas_gui_volumes()
    shinyFiles::shinyFileChoose(input, "browse_export", roots = volumes, session = session,
                                filetypes = c("xlsx", "csv"))
    shinyFiles::shinyDirChoose(input, "browse_output", roots = volumes, session = session)

    observeEvent(input$browse_export, {
      if (!is.integer(input$browse_export)) {
        info <- shinyFiles::parseFilePaths(volumes, input$browse_export)
        if (nrow(info) > 0) {
          path <- normalizePath(as.character(info$datapath[1]),
                                winslash = "/", mustWork = FALSE)
          updateTextInput(session, "data_export", value = path)
        }
      }
    })

    observeEvent(input$browse_output, {
      if (!is.integer(input$browse_output)) {
        dir_path <- shinyFiles::parseDirPath(volumes, input$browse_output)
        if (length(dir_path) > 0) {
          path <- normalizePath(path.expand(as.character(dir_path)), winslash = "/", mustWork = FALSE)
          updateTextInput(session, "output_dir", value = path)
        }
      }
    })

    # Run export
    observeEvent(input$run_export, {
      req(nzchar(trimws(input$survey_id)))
      req(nzchar(trimws(input$output_dir)))

      rv$complete <- FALSE
      rv$result   <- NULL
      rv$log      <- NULL

      output$run_status <- renderUI({
        div(class = "turas-status-info",
            strong("Fetching from Alchemer API and generating files..."),
            br(),
            "This takes 15–30 seconds. Check the R console for live progress.")
      })

      # Strip whitespace plus any wrapping quotes (users sometimes paste
      # shell-style 'quoted paths', which R won't strip on its own).
      clean_path <- function(x) {
        x <- trimws(x %||% "")
        x <- sub("^['\"]+", "", x)
        x <- sub("['\"]+$", "", x)
        trimws(x)
      }
      survey_id   <- clean_path(input$survey_id)
      output_dir  <- clean_path(input$output_dir)
      data_export <- clean_path(input$data_export %||% "")
      if (!nzchar(data_export)) data_export <- NULL
      targets     <- if (length(input$targets) > 0L) input$targets else "tabs"

      if (!dir.exists(output_dir)) {
        rv$complete <- FALSE
        rv$log <- sprintf("ERROR: output directory does not exist: '%s'", output_dir)
        output$run_status <- renderUI({
          div(class = "turas-status-error",
              strong("Output directory not found."),
              br(),
              "Use the Browse button or paste a path without surrounding quotes.")
        })
        return(invisible(NULL))
      }

      log_lines <- capture.output({
        result <- tryCatch(
          alchemer_to_turas(
            survey_id        = survey_id,
            output_dir       = output_dir,
            targets          = targets,
            data_export_path = data_export
          ),
          error = function(e) {
            cat("ERROR:", conditionMessage(e), "\n")
            NULL
          }
        )
      })

      rv$log      <- log_lines
      rv$result   <- result
      rv$complete <- !is.null(result)

      # Save to recent — newest first, deduped by survey ID, capped at TURAS_MAX_RECENTS
      if (rv$complete) {
        tryCatch({
          recent <- load_recents()
          entry_name <- paste0("Survey ", survey_id)
          entry <- list(
            survey_id   = survey_id,
            output_dir  = output_dir,
            data_export = data_export %||% "",
            targets     = targets
          )
          recent <- c(setNames(list(entry), entry_name),
                      recent[names(recent) != entry_name])
          recent <- recent[seq_len(min(TURAS_MAX_RECENTS, length(recent)))]
          saveRDS(recent, recent_projects_file)
          recent_trigger(recent_trigger() + 1L)
        }, error = function(e) invisible(NULL))

        output$run_status <- renderUI({
          div(class = "turas-status-success",
              strong("Config files generated."),
              br(),
              sprintf("Saved to: %s", output_dir))
        })
      } else {
        output$run_status <- renderUI({
          div(class = "turas-status-error",
              strong("Generation failed."),
              br(),
              "See the log below and the R console for details.")
        })
      }
    })

    # Log visibility
    output$show_log <- reactive({ !is.null(rv$log) && length(rv$log) > 0 })
    outputOptions(output, "show_log", suspendWhenHidden = FALSE)

    output$run_log <- renderText({
      req(rv$log)
      paste(rv$log, collapse = "\n")
    })

    # Downloads card
    output$downloads_card <- renderUI({
      req(rv$complete)
      res <- rv$result

      ss_path <- res$survey_structure %||% res$survey_structure_brand
      n_q <- tryCatch({
        nrow(openxlsx::read.xlsx(ss_path, sheet = "Questions", startRow = 5L, colNames = FALSE))
      }, error = function(e) NA_integer_)
      n_opts <- tryCatch({
        nrow(openxlsx::read.xlsx(ss_path, sheet = "Options", startRow = 5L, colNames = FALSE))
      }, error = function(e) NA_integer_)

      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 4: Output Files"),

        if (!is.na(n_q)) p(sprintf("%d questions | %d option rows", n_q, n_opts)),

        if (!is.null(res$survey_structure) || !is.null(res$crosstab_config)) {
          tagList(
            p(strong("Tabs")),
            fluidRow(
              column(6,
                if (!is.null(res$survey_structure))
                  downloadButton("dl_survey", "Survey_Structure.xlsx", width = "100%")
              ),
              column(6,
                if (!is.null(res$crosstab_config))
                  downloadButton("dl_config", "Crosstab_Config.xlsx", width = "100%")
              )
            )
          )
        },

        if (!is.null(res$survey_structure_brand) || !is.null(res$brand_config)) {
          tagList(
            p(strong("Brand")),
            fluidRow(
              column(6,
                if (!is.null(res$survey_structure_brand))
                  downloadButton("dl_survey_brand", "Survey_Structure_Brand.xlsx", width = "100%")
              ),
              column(6,
                if (!is.null(res$brand_config))
                  downloadButton("dl_brand_config", "Brand_Config.xlsx", width = "100%")
              )
            )
          )
        },

        if (!is.null(res$data_headers) || !is.null(res$data_file)) {
          tagList(
            p(strong("Shared")),
            fluidRow(
              column(6,
                if (!is.null(res$data_headers))
                  downloadButton("dl_headers", "Data_Headers.xlsx", width = "100%")
              ),
              column(6,
                if (!is.null(res$data_file))
                  downloadButton("dl_data", "Turas-ready data.xlsx", width = "100%")
              )
            )
          )
        }
      )
    })

    output$dl_survey <- downloadHandler(
      filename = function() basename(rv$result$survey_structure),
      content  = function(f) file.copy(rv$result$survey_structure, f)
    )
    output$dl_config <- downloadHandler(
      filename = function() basename(rv$result$crosstab_config),
      content  = function(f) file.copy(rv$result$crosstab_config, f)
    )
    output$dl_survey_brand <- downloadHandler(
      filename = function() basename(rv$result$survey_structure_brand),
      content  = function(f) file.copy(rv$result$survey_structure_brand, f)
    )
    output$dl_brand_config <- downloadHandler(
      filename = function() basename(rv$result$brand_config),
      content  = function(f) file.copy(rv$result$brand_config, f)
    )
    output$dl_headers <- downloadHandler(
      filename = function() basename(rv$result$data_headers),
      content  = function(f) file.copy(rv$result$data_headers, f)
    )
    output$dl_data <- downloadHandler(
      filename = function() basename(rv$result$data_file),
      content  = function(f) file.copy(rv$result$data_file, f)
    )
  }

  shinyApp(ui = ui, server = server)
}

# Auto-launch when run as a script
if (!interactive()) {
  app <- run_alchemerexport_gui()
  shiny::runApp(app, launch.browser = TRUE)
} else {
  cat("Alchemer Export GUI loaded.\n")
  cat("Run with: run_alchemerexport_gui()\n")
}
