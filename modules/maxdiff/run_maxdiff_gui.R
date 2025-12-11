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

  # File browser function using tcltk
  browse_for_file <- function() {
    if (requireNamespace("tcltk", quietly = TRUE)) {
      tryCatch({
        f <- tcltk::tk_choose.files(
          default = "",
          caption = "Select MaxDiff Config File",
          multi = FALSE,
          filters = matrix(c("Excel files", ".xlsx", "All files", "*"), 2, 2, byrow = TRUE)
        )
        if (length(f) > 0 && nzchar(f[1])) return(f[1])
      }, error = function(e) NULL)
    }
    # Fallback to file.choose
    tryCatch({
      f <- file.choose()
      if (!is.null(f) && nzchar(f)) return(f)
    }, error = function(e) NULL)
    return(NULL)
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
      .btn-browse { background: #6366f1; color: white; border: none; padding: 10px 20px; border-radius: 8px; margin-left: 10px; cursor: pointer; }
      .btn-browse:hover { background: #4f46e5; }
      .input-row { display: flex; align-items: center; gap: 10px; }
      .input-row .form-group { flex: 1; margin-bottom: 0; }
      .shiny-notification { background: #8b5cf6; color: white; }
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
        actionButton("run_btn", "Run MaxDiff", class = "btn-run")
      ),

      div(class = "card",
        h4("Console Output"),
        div(class = "console", verbatimTextOutput("console_text"))
      )
    )
  )

  # Server
  server <- function(input, output, session) {
    rv <- reactiveValues(mode = "ANALYSIS")
    console_out <- reactiveVal("Ready. Enter config path and click Run.")

    # Browse button - runs in session context
    observeEvent(input$browse_btn, {
      selected <- browse_for_file()
      if (!is.null(selected) && nzchar(selected)) {
        updateTextInput(session, "config_path", value = selected)
      }
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
        tags$p(class = "status-ok", "\u2713 File found")
      } else {
        tags$p(class = "status-err", "\u2717 File not found")
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

    # Run with built-in progress
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

      console_out(paste0("Starting MaxDiff ", rv$mode, "...\n", strrep("=", 60), "\n"))

      old_wd <- getwd()

      # Use Shiny's built-in progress indicator
      withProgress(message = paste("Running MaxDiff", rv$mode), value = 0, {

        tryCatch({
          incProgress(0.1, detail = "Loading module...")
          setwd(MODULE_DIR)
          source(file.path("R", "00_main.R"))

          incProgress(0.2, detail = "Reading configuration...")

          # Capture output
          tmp <- tempfile()
          sink(tmp, type = "output")

          incProgress(0.1, detail = "Processing...")

          result <- tryCatch({
            run_maxdiff(config_path = config_path, verbose = TRUE)
          }, finally = { sink(type = "output") })

          incProgress(0.4, detail = "Finalizing...")

          captured <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
          unlink(tmp)

          save_recent(config_path, rv$mode)

          incProgress(0.2, detail = "Complete!")

          out_path <- if (!is.null(result$output_path)) result$output_path else "output folder"
          console_out(paste0(captured, "\n", strrep("=", 60), "\nCOMPLETE\nOutput: ", out_path))

        }, error = function(e) {
          console_out(paste0(console_out(), "\nERROR: ", e$message))
        }, finally = {
          setwd(old_wd)
        })
      })
    })
  }

  shinyApp(ui = ui, server = server)
}
