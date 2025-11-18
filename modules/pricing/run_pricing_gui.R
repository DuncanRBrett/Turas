# ==============================================================================
# TURAS PRICING MODULE - SHINY GUI LAUNCHER
# ==============================================================================
#
# Purpose: Provide graphical interface for pricing analysis
# Version: 1.0.0
# Date: 2025-11-18
#
# ==============================================================================

# Source module files
# Try to get script location, fallback to working directory
script_path <- tryCatch({
  if (!is.null(sys.frame(1)$ofile)) {
    normalizePath(sys.frame(1)$ofile)
  } else {
    NULL
  }
}, error = function(e) NULL)

if (is.null(script_path)) {
  # Fallback: assume we're in Turas root
  module_dir <- file.path(getwd(), "modules", "pricing")
} else {
  module_dir <- dirname(script_path)
}

r_dir <- file.path(module_dir, "R")

source(file.path(r_dir, "00_main.R"))
source(file.path(r_dir, "01_config.R"))
source(file.path(r_dir, "02_validation.R"))
source(file.path(r_dir, "03_van_westendorp.R"))
source(file.path(r_dir, "04_gabor_granger.R"))
source(file.path(r_dir, "05_visualization.R"))
source(file.path(r_dir, "06_output.R"))

# Check for required packages
required_packages <- c("shiny", "readxl", "openxlsx")
missing <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
  stop(sprintf("Missing required packages: %s\nInstall with: install.packages(c('%s'))",
               paste(missing, collapse = ", "),
               paste(missing, collapse = "', '")),
       call. = FALSE)
}

library(shiny)

# Recent projects file
recent_projects_file <- file.path(module_dir, ".recent_pricing_projects.rds")

#' Load Recent Projects
load_recent_projects <- function() {
  if (file.exists(recent_projects_file)) {
    tryCatch({
      readRDS(recent_projects_file)
    }, error = function(e) {
      character(0)
    })
  } else {
    character(0)
  }
}

#' Save Recent Project
save_recent_project <- function(path) {
  recent <- load_recent_projects()
  recent <- unique(c(path, recent))
  recent <- recent[file.exists(recent)]
  recent <- head(recent, 10)  # Keep only 10 most recent
  saveRDS(recent, recent_projects_file)
}

# ==============================================================================
# UI
# ==============================================================================
ui <- fluidPage(
  titlePanel("Turas Pricing Research Analysis"),

  sidebarLayout(
    sidebarPanel(
      width = 4,

      h4("Configuration"),

      # Config file selection
      fileInput("config_file", "Select Configuration File",
                accept = c(".xlsx", ".xls")),

      # Or select recent
      selectInput("recent_projects", "Or Select Recent Project",
                  choices = c("", load_recent_projects()),
                  selected = ""),

      hr(),

      h4("Optional Overrides"),

      # Data file override
      fileInput("data_file", "Override Data File (optional)",
                accept = c(".csv", ".xlsx", ".xls", ".sav", ".dta", ".rds")),

      # Output file
      textInput("output_file", "Output File Name",
                value = "pricing_results.xlsx"),

      hr(),

      # Run button
      actionButton("run_analysis", "Run Analysis",
                   class = "btn-primary btn-lg btn-block"),

      hr(),

      # Create template
      h4("Create Config Template"),
      selectInput("template_method", "Analysis Method",
                  choices = c("van_westendorp", "gabor_granger", "both")),
      textInput("template_name", "Template File Name",
                value = "pricing_config.xlsx"),
      actionButton("create_template", "Create Template",
                   class = "btn-success btn-block")
    ),

    mainPanel(
      width = 8,

      tabsetPanel(
        id = "main_tabs",

        tabPanel("Results",
                 br(),
                 verbatimTextOutput("console_output"),
                 hr(),
                 conditionalPanel(
                   condition = "output.has_results",
                   h4("Key Results"),
                   tableOutput("results_table")
                 )
        ),

        tabPanel("Plots",
                 br(),
                 plotOutput("main_plot", height = "500px")
        ),

        tabPanel("Diagnostics",
                 br(),
                 h4("Validation Summary"),
                 tableOutput("validation_table"),
                 hr(),
                 h4("Warnings"),
                 verbatimTextOutput("warnings_output")
        ),

        tabPanel("Help",
                 br(),
                 includeMarkdown(file.path(module_dir, "QUICK_START.md"))
        )
      )
    )
  )
)

# ==============================================================================
# SERVER
# ==============================================================================
server <- function(input, output, session) {

  # Reactive values
  rv <- reactiveValues(
    results = NULL,
    console = "",
    config_path = NULL
  )

  # Handle recent project selection
  observeEvent(input$recent_projects, {
    if (input$recent_projects != "") {
      rv$config_path <- input$recent_projects
    }
  })

  # Handle file upload
  observeEvent(input$config_file, {
    if (!is.null(input$config_file)) {
      rv$config_path <- input$config_file$datapath
    }
  })

  # Run analysis
  observeEvent(input$run_analysis, {

    # Get config path
    config_path <- rv$config_path

    if (is.null(config_path) || config_path == "") {
      showNotification("Please select a configuration file", type = "error")
      return()
    }

    # Get data file override
    data_file <- NULL
    if (!is.null(input$data_file)) {
      data_file <- input$data_file$datapath
    }

    # Get output file
    output_file <- input$output_file
    if (output_file == "") {
      output_file <- "pricing_results.xlsx"
    }

    # Capture console output
    rv$console <- ""

    tryCatch({
      # Run analysis with console capture
      output_capture <- capture.output({
        rv$results <- run_pricing_analysis(
          config_file = config_path,
          data_file = data_file,
          output_file = output_file
        )
      })

      rv$console <- paste(output_capture, collapse = "\n")

      # Save to recent projects
      if (!is.null(input$config_file)) {
        save_recent_project(input$config_file$datapath)
      }

      showNotification("Analysis completed successfully!", type = "message")

    }, error = function(e) {
      rv$console <- paste("ERROR:", e$message)
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Console output
  output$console_output <- renderText({
    rv$console
  })

  # Has results flag
  output$has_results <- reactive({
    !is.null(rv$results)
  })
  outputOptions(output, "has_results", suspendWhenHidden = FALSE)

  # Results table
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
      if (!is.null(opt)) {
        data.frame(
          Metric = c("Optimal Price", "Purchase Intent", "Revenue Index"),
          Value = c(
            sprintf("$%.2f", opt$price),
            sprintf("%.1f%%", opt$purchase_intent * 100),
            sprintf("%.2f", opt$revenue_index)
          )
        )
      }
    } else if (method == "both") {
      vw <- rv$results$results$van_westendorp$price_points
      gg <- rv$results$results$gabor_granger$optimal_price
      data.frame(
        Metric = c("VW Acceptable Range", "VW Optimal Range", "GG Optimal Price"),
        Value = c(
          sprintf("$%.2f - $%.2f", vw$PMC, vw$PME),
          sprintf("$%.2f - $%.2f", vw$OPP, vw$IDP),
          sprintf("$%.2f", gg$price)
        )
      )
    }
  })

  # Main plot
  output$main_plot <- renderPlot({
    req(rv$results)
    req(length(rv$results$plots) > 0)

    # Return first plot
    rv$results$plots[[1]]
  })

  # Validation table
  output$validation_table <- renderTable({
    req(rv$results)

    diag <- rv$results$diagnostics
    data.frame(
      Metric = c("Total Respondents", "Valid Respondents", "Excluded", "Warnings"),
      Value = c(diag$n_total, diag$n_valid, diag$n_excluded, diag$n_warnings)
    )
  })

  # Warnings output
  output$warnings_output <- renderText({
    req(rv$results)

    warnings <- rv$results$diagnostics$warnings
    if (length(warnings) == 0) {
      "No warnings"
    } else {
      paste(seq_along(warnings), ". ", warnings, collapse = "\n")
    }
  })

  # Create template
  observeEvent(input$create_template, {

    template_name <- input$template_name
    if (template_name == "") {
      template_name <- "pricing_config.xlsx"
    }

    tryCatch({
      create_pricing_config(
        output_file = template_name,
        method = input$template_method,
        overwrite = TRUE
      )
      showNotification(
        sprintf("Template created: %s", template_name),
        type = "message"
      )
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })
}

# ==============================================================================
# RUN APP
# ==============================================================================
shinyApp(ui = ui, server = server)
