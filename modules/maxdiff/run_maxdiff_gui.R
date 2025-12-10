# ==============================================================================
# TURAS>MAXDIFF GUI - LAUNCHER (Debug version)
# ==============================================================================

run_maxdiff_gui <- function() {

  cat("Step 1: Loading shiny...\n")
  library(shiny)
  cat("Step 1: Done\n")

  cat("Step 2: Setting paths...\n")
  TURAS_HOME <- getwd()
  MODULE_DIR <- file.path(TURAS_HOME, "modules", "maxdiff")
  cat("Step 2: Done - TURAS_HOME =", TURAS_HOME, "\n")

  cat("Step 3: Creating UI...\n")
  ui <- fluidPage(
    h1("TURAS MaxDiff"),
    textInput("config_path", "Config file path:", value = ""),
    actionButton("run_btn", "Run MaxDiff"),
    verbatimTextOutput("console_text")
  )
  cat("Step 3: Done\n")

  cat("Step 4: Creating server...\n")
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

      old_wd <- getwd()

      tryCatch({
        setwd(MODULE_DIR)
        source(file.path("R", "00_main.R"))

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
  cat("Step 4: Done\n")

  cat("Step 5: Creating shinyApp...\n")
  app <- shinyApp(ui = ui, server = server)
  cat("Step 5: Done\n")

  cat("Step 6: Returning app\n")
  return(app)
}
