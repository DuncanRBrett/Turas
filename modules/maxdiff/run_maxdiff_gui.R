# ==============================================================================
# TURAS>MAXDIFF GUI - LAUNCHER (Minimal version)
# ==============================================================================

run_maxdiff_gui <- function() {

  library(shiny)

  # Simple paths
  TURAS_HOME <- getwd()
  MODULE_DIR <- file.path(TURAS_HOME, "modules", "maxdiff")

  # Minimal UI
  ui <- fluidPage(
    h1("TURAS MaxDiff"),
    textInput("config_path", "Config file path:", value = ""),
    actionButton("run_btn", "Run MaxDiff"),
    verbatimTextOutput("console_text")
  )

  # Minimal server
  server <- function(input, output, session) {

    console_output <- reactiveVal("Ready...")

    output$console_text <- renderText({
      console_output()
    })

    observeEvent(input$run_btn, {
      config_path <- trimws(input$config_path)

      if (!nzchar(config_path)) {
        console_output("Please enter a config path")
        return()
      }

      if (!file.exists(config_path)) {
        console_output(paste("File not found:", config_path))
        return()
      }

      console_output("Running MaxDiff...")

      # Save working directory
      old_wd <- getwd()

      tryCatch({
        setwd(MODULE_DIR)
        source(file.path("R", "00_main.R"))

        # Capture output
        output_file <- tempfile()
        sink(output_file, type = "output")

        result <- tryCatch({
          run_maxdiff(config_path = config_path, verbose = TRUE)
        }, finally = {
          sink(type = "output")
        })

        captured <- readLines(output_file, warn = FALSE)
        unlink(output_file)

        console_output(paste(c(captured, "", "=== COMPLETE ==="), collapse = "\n"))

      }, error = function(e) {
        console_output(paste("ERROR:", e$message))
      }, finally = {
        setwd(old_wd)
      })
    })
  }

  cat("\nLaunching MaxDiff GUI...\n")
  shinyApp(ui = ui, server = server)
}
