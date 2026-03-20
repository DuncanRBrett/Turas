# ==============================================================================
# TURAS PRICING MODULE - SHINY GUI LAUNCHER
# ==============================================================================
#
# Purpose: Minimal interface — select config file, run analysis, view console
# Version: 12.0
# Date: 2026-03-20
#
# Everything is driven by the Excel configuration template.
# This GUI provides: config file selection, run button, and console log.
#
# ==============================================================================

#' Run Pricing GUI
#'
#' Launch the Shiny GUI for pricing analysis.
#'
#' @return A shinyApp object
#' @export
run_pricing_gui <- function() {

  # Locate module directory
  get_script_dir <- function() {
    for (i in seq_len(sys.nframe())) {
      file <- sys.frame(i)$ofile
      if (!is.null(file) && grepl("run_pricing_gui", file)) {
        return(dirname(normalizePath(file)))
      }
    }
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("--file=", args, value = TRUE)
    if (length(file_arg) > 0) {
      file_path <- sub("--file=", "", file_arg)
      if (grepl("run_pricing_gui", file_path)) {
        return(dirname(normalizePath(file_path)))
      }
    }
    return(file.path(getwd(), "modules", "pricing"))
  }

  module_dir <- get_script_dir()
  r_dir <- file.path(module_dir, "R")

  # Set script_dir_override so 00_main.R can find 00_guard.R and TRS infra
  assign("script_dir_override", r_dir, envir = globalenv())

  # Source ALL module files (guard must come before main)
  source(file.path(r_dir, "00_guard.R"))
  source(file.path(r_dir, "00_main.R"))
  source(file.path(r_dir, "01_config.R"))
  source(file.path(r_dir, "02_validation.R"))
  source(file.path(r_dir, "03_van_westendorp.R"))
  source(file.path(r_dir, "04_gabor_granger.R"))
  source(file.path(r_dir, "05_visualization.R"))
  source(file.path(r_dir, "06_output.R"))
  source(file.path(r_dir, "07_wtp_distribution.R"))
  source(file.path(r_dir, "08_competitive_scenarios.R"))
  source(file.path(r_dir, "09_price_volume_optimisation.R"))
  source(file.path(r_dir, "10_segmentation.R"))
  source(file.path(r_dir, "11_price_ladder.R"))
  source(file.path(r_dir, "12_recommendation_synthesis.R"))
  source(file.path(r_dir, "13_monadic.R"))

  # Check for required packages
  required_packages <- c("shiny", "shinyFiles")
  missing <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  if (length(missing) > 0) {
    stop(sprintf("Missing required packages: %s\nInstall with: install.packages(c('%s'))",
                 paste(missing, collapse = ", "),
                 paste(missing, collapse = "', '")),
         call. = FALSE)
  }

  library(shiny)
  library(shinyFiles)

  # Load shared GUI theme
  TURAS_HOME <- getwd()
  source(file.path(TURAS_HOME, "modules", "shared", "lib", "gui_theme.R"))
  theme <- turas_gui_theme("Pricing", "Price Sensitivity & Optimization")

  # ============================================================================
  # UI
  # ============================================================================
  ui <- fluidPage(
    theme$head,
    theme$header,

    div(class = "turas-sidebar",
      sidebarLayout(
        sidebarPanel(
          width = 4,

          h4("Configuration File"),

          shinyFilesButton("config_file_button", "Browse",
                          "Select configuration file (.xlsx)",
                          multiple = FALSE,
                          icon = icon("folder-open")),

          verbatimTextOutput("config_path_display", placeholder = TRUE),

          textInput("config_path_text", "Or paste full path",
                    placeholder = "/path/to/pricing_config.xlsx"),

          hr(),

          actionButton("run_analysis", "Run Analysis",
                       class = "turas-btn-run btn-block",
                       icon = icon("play"))
        ),

        mainPanel(
          width = 8,

          div(class = "turas-card",
            h4("Console Output"),
            div(class = "turas-console",
                style = "max-height: 600px; overflow-y: auto;",
                verbatimTextOutput("console_output")),

            conditionalPanel(
              condition = "output.has_results",
              hr(),
              h4("Summary"),
              tableOutput("results_table"),
              hr(),
              tags$p(
                "Full results written to Excel and HTML report.",
                "Open the HTML file for the interactive report with simulator.",
                class = "turas-help-text"
              )
            )
          )
        )
      )
    )
  )

  # ============================================================================
  # SERVER
  # ============================================================================
  server <- function(input, output, session) {

    rv <- reactiveValues(
      results = NULL,
      console = "",
      config_path = NULL
    )

    # Auto-load config from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config) && file.exists(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      rv$config_path <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
    }

    # File chooser
    volumes <- c(Home = path.expand("~"), Root = "/")
    shinyFileChoose(input, "config_file_button", roots = volumes,
                    filetypes = c("xlsx", "xls"))

    # Handle file browser selection
    observeEvent(input$config_file_button, {
      if (!is.null(input$config_file_button) && !is.integer(input$config_file_button)) {
        file_selected <- parseFilePaths(volumes, input$config_file_button)
        if (nrow(file_selected) > 0) {
          rv$config_path <- normalizePath(
            path.expand(as.character(file_selected$datapath)),
            winslash = "/", mustWork = FALSE
          )
        }
      }
    })

    # Display selected config path
    output$config_path_display <- renderText({
      if (!is.null(rv$config_path) && rv$config_path != "") {
        paste("Selected:", rv$config_path)
      } else {
        "No file selected"
      }
    })

    # Handle text path input
    observeEvent(input$config_path_text, {
      if (!is.null(input$config_path_text) && input$config_path_text != "") {
        rv$config_path <- input$config_path_text
      }
    })

    # ------------------------------------------------------------------
    # Run analysis
    # ------------------------------------------------------------------
    observeEvent(input$run_analysis, {

      config_path <- if (!is.null(input$config_path_text) && input$config_path_text != "") {
        input$config_path_text
      } else {
        rv$config_path
      }

      if (is.null(config_path) || !nzchar(config_path)) {
        showNotification("Please select a configuration file", type = "error")
        return()
      }

      if (!file.exists(config_path)) {
        showNotification(sprintf("Config file not found: %s", config_path), type = "error")
        return()
      }

      rv$console <- ""
      rv$results <- NULL

      tryCatch({
        output_capture <- capture.output({
          rv$results <- run_pricing_analysis(config_path)
        })
        rv$console <- paste(output_capture, collapse = "\n")
        showNotification("Analysis complete", type = "message")
      }, error = function(e) {
        cat("\n=== ERROR IN PRICING ANALYSIS ===\n")
        cat("Message:", e$message, "\n")
        cat("=================================\n\n")
        rv$console <- paste("ERROR:", e$message)
        showNotification(paste("Error:", e$message), type = "error")
      })
    })

    # Console output
    output$console_output <- renderPrint({
      cat(rv$console)
    })

    # Has results flag
    output$has_results <- reactive({ !is.null(rv$results) })
    outputOptions(output, "has_results", suspendWhenHidden = FALSE)

    # Summary results table
    output$results_table <- renderTable({
      req(rv$results)
      method <- rv$results$method

      if (method == "van_westendorp") {
        pp <- rv$results$results$price_points
        data.frame(
          `Price Point` = c("PMC", "OPP", "IDP", "PME"),
          `Description` = c(
            "Point of Marginal Cheapness",
            "Optimal Price Point",
            "Indifference Price Point",
            "Point of Marginal Expensiveness"
          ),
          `Price` = sprintf("$%.2f", c(pp$PMC, pp$OPP, pp$IDP, pp$PME)),
          check.names = FALSE
        )
      } else if (method == "gabor_granger") {
        opt <- rv$results$results$optimal_price
        rows <- data.frame(
          Metric = c("Revenue-Maximizing Price", "Purchase Intent", "Revenue Index"),
          Value = c(
            sprintf("$%.2f", opt$price),
            sprintf("%.1f%%", opt$purchase_intent * 100),
            sprintf("%.2f", opt$revenue_index)
          ),
          stringsAsFactors = FALSE
        )
        opt_profit <- rv$results$results$optimal_price_profit
        if (!is.null(opt_profit)) {
          rows <- rbind(rows, data.frame(
            Metric = c("Profit-Maximizing Price", "Profit Index"),
            Value = c(
              sprintf("$%.2f", opt_profit$price),
              sprintf("%.2f", opt_profit$profit_index)
            ),
            stringsAsFactors = FALSE
          ))
        }
        rows
      } else if (method == "monadic") {
        opt <- rv$results$results$optimal_price
        if (!is.null(opt)) {
          data.frame(
            Metric = c("Revenue-Maximizing Price", "Predicted Intent"),
            Value = c(
              sprintf("$%.2f", opt$price),
              sprintf("%.1f%%", opt$predicted_intent * 100)
            ),
            stringsAsFactors = FALSE
          )
        }
      } else if (method == "both") {
        vw <- rv$results$results$van_westendorp$price_points
        gg <- rv$results$results$gabor_granger$optimal_price
        data.frame(
          Metric = c("VW Acceptable Range", "VW Optimal Range", "GG Revenue-Max Price"),
          Value = c(
            sprintf("$%.2f - $%.2f", vw$PMC, vw$PME),
            sprintf("$%.2f - $%.2f", vw$OPP, vw$IDP),
            sprintf("$%.2f", gg$price)
          ),
          stringsAsFactors = FALSE
        )
      }
    })
  }

  # ============================================================================
  # RETURN APP
  # ============================================================================
  shinyApp(ui = ui, server = server)
}
