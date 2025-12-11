# ==============================================================================
# TURAS>MAXDIFF GUI - LAUNCHER
# ==============================================================================
# Purpose: Launch MaxDiff design and analysis GUI
# Location: modules/maxdiff/run_maxdiff_gui.R
# Usage: source("modules/maxdiff/run_maxdiff_gui.R") then run_maxdiff_gui()
# ==============================================================================

run_maxdiff_gui <- function() {

  library(shiny)

  # Paths

  TURAS_HOME <- getwd()
  MODULE_DIR <- file.path(TURAS_HOME, "modules", "maxdiff")
  RECENT_FILE <- file.path(TURAS_HOME, ".recent_maxdiff.rds")

  # Helper functions
  load_recent <- function() {
    if (file.exists(RECENT_FILE)) {
      tryCatch(readRDS(RECENT_FILE), error = function(e) list())
    } else {
      list()
    }
  }

  save_recent <- function(path, mode) {
    recent <- load_recent()
    recent <- c(list(list(path = path, mode = mode)), recent)
    recent <- recent[!duplicated(sapply(recent, `[[`, "path"))]
    if (length(recent) > 5) recent <- recent[1:5]
    tryCatch(saveRDS(recent, RECENT_FILE), error = function(e) NULL)
  }

  # UI
  ui <- fluidPage(
    tags$head(tags$style(HTML("
      body { background: #f5f5f5; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
      .container { max-width: 900px; margin: 20px auto; }
      .header { background: linear-gradient(135deg, #8b5cf6, #6d28d9); color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; }
      .card { background: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
      .btn-run { background: #8b5cf6; color: white; border: none; padding: 15px 30px; font-size: 16px; border-radius: 8px; width: 100%; }
      .btn-run:hover { background: #7c3aed; }
      .console { background: #1e293b; color: #e2e8f0; padding: 15px; border-radius: 8px; font-family: monospace; font-size: 12px; max-height: 400px; overflow-y: auto; white-space: pre-wrap; }
      .mode-btn { padding: 15px; border: 2px solid #e5e7eb; border-radius: 8px; background: white; margin: 5px; cursor: pointer; }
      .mode-btn.active { border-color: #8b5cf6; background: #f3e8ff; }
      .recent-item { padding: 10px; background: #f9fafb; border-radius: 5px; margin: 5px 0; cursor: pointer; border: 1px solid #e5e7eb; }
      .recent-item:hover { border-color: #8b5cf6; }
      .status-ok { color: #059669; }
      .status-err { color: #dc2626; }
      .btn-browse { background: #6366f1; color: white; border: none; padding: 10px 20px; border-radius: 8px; margin-left: 10px; }
      .btn-browse:hover { background: #4f46e5; }
      .input-row { display: flex; align-items: center; }
      .input-row .form-group { flex: 1; margin-bottom: 0; }
      .progress-container { margin: 15px 0; }
      .progress-bar-custom { height: 20px; background: #e5e7eb; border-radius: 10px; overflow: hidden; }
      .progress-bar-fill { height: 100%; background: linear-gradient(90deg, #8b5cf6, #6d28d9); transition: width 0.3s ease; }
      .progress-text { text-align: center; margin-top: 5px; font-size: 14px; color: #6b7280; }
    "))),

    div(class = "container",
      div(class = "header",
        h2("TURAS MaxDiff"),
        p("Best-Worst Scaling Design & Analysis")
      ),

      div(class = "card",
        h4("1. Select Mode"),
        fluidRow(
          column(6, actionButton("mode_design", "DESIGN\nGenerate experimental design", class = "mode-btn", style = "width:100%")),
          column(6, actionButton("mode_analysis", "ANALYSIS\nAnalyze survey responses", class = "mode-btn active", style = "width:100%"))
        )
      ),

      div(class = "card",
        h4("2. Configuration File"),
        div(class = "input-row",
          textInput("config_path", NULL, placeholder = "Enter full path to config.xlsx", width = "100%"),
          actionButton("browse_btn", "Browse...", class = "btn-browse")
        ),
        tags$small("Example: ", tags$code(file.path(MODULE_DIR, "examples/basic/example_maxdiff_config.xlsx"))),
        uiOutput("file_status"),
        uiOutput("recent_ui")
      ),

      div(class = "card",
        h4("3. Run"),
        actionButton("run_btn", "Run MaxDiff", class = "btn-run"),
        uiOutput("progress_ui")
      ),

      div(class = "card",
        h4("Console Output"),
        div(class = "console", verbatimTextOutput("console_text"))
      )
    )
  )

  # Server
  server <- function(input, output, session) {
    rv <- reactiveValues(mode = "ANALYSIS", progress = 0, progress_text = "", show_progress = FALSE)
    console_out <- reactiveVal("Ready. Enter config path and click Run.")

    # Browse button
    observeEvent(input$browse_btn, {
      tryCatch({
        selected <- file.choose()
        if (!is.null(selected) && nzchar(selected)) {
          updateTextInput(session, "config_path", value = selected)
        }
      }, error = function(e) {
        # User cancelled file selection
      })
    })

    # Progress bar UI
    output$progress_ui <- renderUI({
      if (!rv$show_progress) return(NULL)
      div(class = "progress-container",
        div(class = "progress-bar-custom",
          div(class = "progress-bar-fill", style = sprintf("width: %d%%;", rv$progress))
        ),
        div(class = "progress-text", rv$progress_text)
      )
    })

    # Mode buttons
    observeEvent(input$mode_design, {
      rv$mode <- "DESIGN"
      updateActionButton(session, "mode_design", class = "mode-btn active")
      updateActionButton(session, "mode_analysis", class = "mode-btn")
    })
    observeEvent(input$mode_analysis, {
      rv$mode <- "ANALYSIS"
      updateActionButton(session, "mode_design", class = "mode-btn")
      updateActionButton(session, "mode_analysis", class = "mode-btn active")
    })

    # File status
    output$file_status <- renderUI({
      p <- trimws(input$config_path)
      if (!nzchar(p)) return(NULL)
      if (file.exists(p)) {
        tags$p(class = "status-ok", "✓ File found")
      } else {
        tags$p(class = "status-err", "✗ File not found")
      }
    })

    # Recent projects
    output$recent_ui <- renderUI({
      recent <- load_recent()
      recent <- Filter(function(x) file.exists(x$path), recent)
      if (length(recent) == 0) return(NULL)
      tagList(
        tags$hr(),
        tags$strong("Recent:"),
        lapply(seq_along(recent), function(i) {
          div(class = "recent-item",
              onclick = sprintf("Shiny.setInputValue('load_recent', %d, {priority:'event'})", i),
              tags$strong(basename(recent[[i]]$path)),
              tags$span(style = "float:right; color:#8b5cf6;", recent[[i]]$mode))
        })
      )
    })

    observeEvent(input$load_recent, {
      recent <- Filter(function(x) file.exists(x$path), load_recent())
      if (input$load_recent <= length(recent)) {
        r <- recent[[input$load_recent]]
        updateTextInput(session, "config_path", value = r$path)
        rv$mode <- r$mode
        if (r$mode == "DESIGN") {
          updateActionButton(session, "mode_design", class = "mode-btn active")
          updateActionButton(session, "mode_analysis", class = "mode-btn")
        } else {
          updateActionButton(session, "mode_design", class = "mode-btn")
          updateActionButton(session, "mode_analysis", class = "mode-btn active")
        }
      }
    })

    # Console
    output$console_text <- renderText({ console_out() })

    # Helper to update progress
    update_progress <- function(pct, text) {
      rv$progress <- pct
      rv$progress_text <- text
    }

    # Run
    observeEvent(input$run_btn, {
      config_path <- trimws(input$config_path)
      if (!nzchar(config_path)) {
        console_out("Error: Please enter a config file path")
        return()
      }
      if (!file.exists(config_path)) {
        console_out(paste("Error: File not found:", config_path))
        return()
      }

      # Show progress bar
      rv$show_progress <- TRUE
      update_progress(5, "Initializing...")

      console_out(paste0("Starting MaxDiff ", rv$mode, "...\n", strrep("=", 60), "\n"))

      old_wd <- getwd()
      tryCatch({
        update_progress(10, "Loading MaxDiff module...")
        setwd(MODULE_DIR)
        source(file.path("R", "00_main.R"))

        update_progress(20, "Reading configuration...")

        # Capture output
        tmp <- tempfile()
        sink(tmp, type = "output")

        update_progress(30, "Processing...")

        result <- tryCatch({
          run_maxdiff(config_path = config_path, verbose = TRUE)
        }, finally = { sink(type = "output") })

        update_progress(80, "Finalizing output...")

        captured <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
        unlink(tmp)

        save_recent(config_path, rv$mode)

        update_progress(100, "Complete!")

        out_path <- if (!is.null(result$output_path)) result$output_path else "output folder"
        console_out(paste0(captured, "\n", strrep("=", 60), "\nCOMPLETE\nOutput: ", out_path))

        # Hide progress bar after delay
        invalidateLater(2000, session)
        rv$show_progress <- FALSE

      }, error = function(e) {
        update_progress(0, "Error occurred")
        console_out(paste0(console_out(), "\nERROR: ", e$message))
        rv$show_progress <- FALSE
      }, finally = {
        setwd(old_wd)
      })
    })
  }

  shinyApp(ui = ui, server = server)
}
