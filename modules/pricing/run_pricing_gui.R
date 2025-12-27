# ==============================================================================
# TURAS PRICING MODULE - SHINY GUI LAUNCHER
# ==============================================================================
#
# Purpose: Provide graphical interface for pricing analysis
# Version: 1.0.0
# Date: 2025-11-18
#
# ==============================================================================

#' Run Pricing GUI
#'
#' Launch the Shiny GUI for pricing analysis.
#'
#' @return A shinyApp object
#' @export
run_pricing_gui <- function() {

  # Early refuse function for errors before guard layer loads
  early_refuse <- function(code, title, problem, why_it_matters, how_to_fix) {
    msg <- paste0(
      "\n", strrep("=", 80), "\n",
      "  [REFUSE] ", code, ": ", title, "\n",
      strrep("=", 80), "\n\n",
      "Problem:\n  ", problem, "\n\n",
      "Why it matters:\n  ", why_it_matters, "\n\n",
      "How to fix:\n  ", how_to_fix, "\n",
      "\n", strrep("=", 80), "\n"
    )
    stop(msg, call. = FALSE)
  }

  # Source module files
  # Try multiple methods to find script location
  get_script_dir <- function() {
    # Method 1: Check if running via source() - look through call stack
    for (i in seq_len(sys.nframe())) {
      file <- sys.frame(i)$ofile
      if (!is.null(file) && grepl("run_pricing_gui", file)) {
        return(dirname(normalizePath(file)))
      }
    }

    # Method 2: Check commandArgs for --file
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("--file=", args, value = TRUE)
    if (length(file_arg) > 0) {
      file_path <- sub("--file=", "", file_arg)
      if (grepl("run_pricing_gui", file_path)) {
        return(dirname(normalizePath(file_path)))
      }
    }

    # Method 3: Fallback - assume we're in Turas root
    return(file.path(getwd(), "modules", "pricing"))
  }

  module_dir <- get_script_dir()
  r_dir <- file.path(module_dir, "R")

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

  # Check for required packages
  required_packages <- c("shiny", "readxl", "openxlsx", "shinyFiles", "shinyjs")
  missing <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  if (length(missing) > 0) {
    early_refuse(
      code = "PKG_MISSING_DEPENDENCY",
      title = "Missing Required Packages",
      problem = sprintf("The following packages are not installed: %s", paste(missing, collapse = ", ")),
      why_it_matters = "The Pricing GUI requires these packages for interactive analysis",
      how_to_fix = sprintf("Install missing packages with: install.packages(c('%s'))", paste(missing, collapse = "', '"))
    )
  }

  library(shiny)
  library(shinyFiles)
  library(shinyjs)

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
  useShinyjs(),  # Enable shinyjs
  titlePanel("Turas Pricing Research Analysis"),

  sidebarLayout(
    sidebarPanel(
      width = 4,

      h4("Configuration"),

      # File browser button
      shinyFilesButton("config_file_button", "Browse for Config File",
                      "Select configuration file", multiple = FALSE,
                      icon = icon("folder-open")),

      # Display selected path
      verbatimTextOutput("config_path_display", placeholder = TRUE),

      # Or paste path manually
      textInput("config_path_text", "Or Paste Full Path",
                placeholder = "/full/path/to/config.xlsx"),

      # Or select recent (populated dynamically in server)
      selectInput("recent_projects", "Or Select Recent",
                  choices = c(""),
                  selected = ""),

      hr(),

      h4("Optional Overrides"),

      # Data file override
      fileInput("data_file", "Override Data File (optional)",
                accept = c(".csv", ".xlsx", ".xls", ".sav", ".dta", ".rds")),
      actionButton("clear_data_file", "Clear Data File",
                   class = "btn-sm btn-warning"),
      br(),

      # Output file
      textInput("output_file", "Output File Name",
                value = "pricing_results.xlsx"),

      hr(),

      h4("Phase 1: Advanced Features"),

      # Weight variable
      textInput("weight_var", "Weight Variable (optional)",
                placeholder = "e.g., survey_weight"),

      # DK codes
      textInput("dk_codes", "Don't Know Codes (optional)",
                placeholder = "e.g., 98,99"),

      # Monotonicity behaviors
      selectInput("vw_monotonicity", "VW Monotonicity Behavior",
                  choices = c("Flag Only" = "flag_only",
                             "Drop" = "drop",
                             "Fix" = "fix"),
                  selected = "flag_only"),

      selectInput("gg_monotonicity", "GG Monotonicity Behavior",
                  choices = c("Smooth" = "smooth",
                             "Flag Only" = "flag_only",
                             "None" = "none"),
                  selected = "smooth"),

      # Segment variables
      textInput("segment_vars", "Segment Variables (optional)",
                placeholder = "e.g., age_group,region"),

      hr(),

      h4("Phase 2: Profit Optimization"),

      # Unit cost
      numericInput("unit_cost", "Unit Cost (for profit)",
                   value = NA, min = 0, step = 0.01),

      hr(),

      # Run button
      actionButton("run_analysis", "Run Analysis",
                   class = "btn-primary btn-lg btn-block"),

      hr(),

      # Create template
      h4("Create Config Template"),
      selectInput("template_method", "Analysis Method",
                  choices = c("van_westendorp", "gabor_granger", "both")),
      shinyDirButton("template_dir_button", "Choose Save Folder",
                    "Select folder to save template",
                    icon = icon("folder-open")),
      verbatimTextOutput("template_dir_display", placeholder = TRUE),
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
                   tableOutput("results_table"),
                   conditionalPanel(
                     condition = "output.has_profit_results",
                     hr(),
                     h4("Profit Optimization"),
                     tableOutput("profit_table")
                   )
                 )
        ),

        tabPanel("Main Plot",
                 br(),
                 plotOutput("main_plot", height = "500px")
        ),

        tabPanel("Additional Plots",
                 br(),
                 conditionalPanel(
                   condition = "output.has_additional_plots",
                   selectInput("plot_selector", "Select Plot",
                              choices = c("Revenue Curve", "Profit Curve", "Revenue vs Profit")),
                   plotOutput("additional_plot", height = "500px")
                 )
        ),

        tabPanel("Diagnostics",
                 br(),
                 h4("Validation Summary"),
                 tableOutput("validation_table"),
                 conditionalPanel(
                   condition = "output.has_weight_summary",
                   hr(),
                   h4("Weight Statistics"),
                   tableOutput("weight_table")
                 ),
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
    config_path = NULL,
    template_dir = NULL
  )

  # Set up file/folder choosers - allow browsing from root and home
  volumes <- c(Home = path.expand("~"), Root = "/")
  shinyFileChoose(input, "config_file_button", roots = volumes,
                  filetypes = c("xlsx", "xls"))
  shinyDirChoose(input, "template_dir_button", roots = volumes)

  # Populate recent projects dropdown on startup
  observe({
    recent <- load_recent_projects()
    if (length(recent) > 0) {
      # Show just filename as label, full path as value
      choices <- c("", setNames(recent, basename(recent)))
    } else {
      choices <- c("")
    }
    updateSelectInput(session, "recent_projects", choices = choices)
  })

  # Handle file browser selection
  observeEvent(input$config_file_button, {
    if (!is.null(input$config_file_button) && !is.integer(input$config_file_button)) {
      file_selected <- parseFilePaths(volumes, input$config_file_button)
      if (nrow(file_selected) > 0) {
        # Expand tilde and normalize path (fixes OneDrive/home directory paths)
        file_path_expanded <- normalizePath(path.expand(as.character(file_selected$datapath)),
                                            winslash = "/", mustWork = FALSE)
        rv$config_path <- file_path_expanded
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

  # Handle recent project selection
  observeEvent(input$recent_projects, {
    if (input$recent_projects != "") {
      # Expand tilde and normalize path (fixes OneDrive/home directory paths)
      config_path_expanded <- normalizePath(path.expand(input$recent_projects),
                                            winslash = "/", mustWork = FALSE)
      rv$config_path <- config_path_expanded
    }
  })

  # Handle template folder selection
  observeEvent(input$template_dir_button, {
    if (!is.null(input$template_dir_button) && !is.integer(input$template_dir_button)) {
      dir_selected <- parseDirPath(volumes, input$template_dir_button)
      # Expand tilde and normalize path (fixes OneDrive/home directory paths)
      dir_selected <- normalizePath(path.expand(dir_selected), winslash = "/", mustWork = FALSE)
      if (length(dir_selected) > 0) {
        rv$template_dir <- as.character(dir_selected)
      }
    }
  })

  # Display selected template directory
  output$template_dir_display <- renderText({
    if (!is.null(rv$template_dir) && rv$template_dir != "") {
      paste("Save to:", rv$template_dir)
    } else {
      paste("Save to:", getwd())
    }
  })

  # Clear data file override
  observeEvent(input$clear_data_file, {
    # Reset the file input by updating its value
    shinyjs::reset("data_file")
    showNotification("Data file override cleared", type = "message")
  })

  # Run analysis
  observeEvent(input$run_analysis, {

    # Get config path - prioritize text input, then recent, then upload
    config_path <- NULL

    if (!is.null(input$config_path_text) && input$config_path_text != "") {
      config_path <- input$config_path_text
    } else {
      config_path <- rv$config_path
    }

    # Validate config path is not empty
    if (is.null(config_path) || length(config_path) == 0 || !nzchar(config_path)) {
      showNotification("Please specify a configuration file path", type = "error")
      return()
    }

    # Validate config file exists
    if (!file.exists(config_path)) {
      showNotification(sprintf("Config file not found: %s", config_path), type = "error")
      return()
    }

    # Get data file override
    data_file <- NULL
    if (!is.null(input$data_file)) {
      data_file <- input$data_file$datapath
    }

    # Get output file
    output_file <- input$output_file
    if (is.null(output_file) || output_file == "") {
      output_file <- "pricing_results.xlsx"
    }

    # Build config overrides for Phase 1-3 features
    config_overrides <- list()

    # Phase 1: Weighting and data quality
    if (!is.null(input$weight_var) && input$weight_var != "") {
      config_overrides$weight_var <- input$weight_var
    }

    if (!is.null(input$dk_codes) && input$dk_codes != "") {
      dk_vals <- trimws(strsplit(input$dk_codes, ",")[[1]])
      config_overrides$dk_codes <- as.numeric(dk_vals)
    }

    if (!is.null(input$vw_monotonicity)) {
      config_overrides$vw_monotonicity_behavior <- input$vw_monotonicity
    }

    if (!is.null(input$gg_monotonicity)) {
      config_overrides$gg_monotonicity_behavior <- input$gg_monotonicity
    }

    if (!is.null(input$segment_vars) && input$segment_vars != "") {
      seg_vals <- trimws(strsplit(input$segment_vars, ",")[[1]])
      config_overrides$segment_vars <- seg_vals
    }

    # Phase 2: Profit optimization
    if (!is.null(input$unit_cost) && !is.na(input$unit_cost) && input$unit_cost > 0) {
      config_overrides$unit_cost <- input$unit_cost
    }

    # Capture console output
    rv$console <- ""

    tryCatch({
      # Load config
      config <- load_pricing_config(config_path)

      # Apply overrides
      if (length(config_overrides) > 0) {
        for (key in names(config_overrides)) {
          config[[key]] <- config_overrides[[key]]
        }
      }

      # Override data file if specified
      if (!is.null(data_file)) {
        config$data_file <- data_file
      }

      # Override output file - resolve to project directory if relative
      if (!is.null(output_file) && length(output_file) > 0 && nzchar(output_file)) {
        # If just a filename, put it in project directory
        if (!grepl("/", output_file) && !grepl("\\\\", output_file)) {
          output_file <- file.path(config$project_root, output_file)
        }
        config$output$directory <- dirname(output_file)
        config$output$filename_prefix <- tools::file_path_sans_ext(basename(output_file))
      }

      # Run analysis with console capture
      output_capture <- capture.output({
        rv$results <- run_pricing_analysis_from_config(config)
      })

      rv$console <- paste(output_capture, collapse = "\n")

      # Save to recent projects (use actual config path, not temp file)
      if (!is.null(config_path) && config_path != "" && file.exists(config_path)) {
        # Don't save temp paths
        if (!grepl("^/private/var/folders/|^/tmp/|Rtmp", config_path)) {
          save_recent_project(config_path)
        }
      }

      showNotification("Analysis completed successfully!", type = "message")

    }, error = function(e) {
      # Print full error to R console for debugging
      cat("\n=== ERROR IN PRICING ANALYSIS ===\n")
      cat("Message:", e$message, "\n")
      cat("Call:", deparse(e$call), "\n")
      print(traceback())
      cat("=================================\n\n")

      rv$console <- paste("ERROR:", e$message)
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Console output (R 4.2+ compatible)
  output$console_output <- renderPrint({
    cat(rv$console)
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
          Metric = c("Revenue-Maximizing Price", "Purchase Intent", "Revenue Index"),
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
        Metric = c("VW Acceptable Range", "VW Optimal Range", "GG Revenue-Max Price"),
        Value = c(
          sprintf("$%.2f - $%.2f", vw$PMC, vw$PME),
          sprintf("$%.2f - $%.2f", vw$OPP, vw$IDP),
          sprintf("$%.2f", gg$price)
        )
      )
    }
  })

  # Profit results table (Phase 2)
  output$profit_table <- renderTable({
    req(rv$results)
    method <- rv$results$method

    # Extract GG results
    gg_results <- if (method == "gabor_granger") {
      rv$results$results
    } else if (method == "both") {
      rv$results$results$gabor_granger
    } else {
      NULL
    }

    req(gg_results)
    opt_profit <- gg_results$optimal_price_profit
    req(opt_profit)

    data.frame(
      Metric = c("Profit-Maximizing Price", "Purchase Intent", "Profit Index", "Margin"),
      Value = c(
        sprintf("$%.2f", opt_profit$price),
        sprintf("%.1f%%", opt_profit$purchase_intent * 100),
        sprintf("%.2f", opt_profit$profit_index),
        sprintf("$%.2f", opt_profit$margin)
      )
    )
  })

  # Weight statistics table (Phase 1)
  output$weight_table <- renderTable({
    req(rv$results)
    ws <- rv$results$diagnostics$weight_summary
    req(ws)

    data.frame(
      Metric = c("Valid Weights", "Effective N", "Range", "Mean", "SD"),
      Value = c(
        sprintf("%d", ws$n_valid),
        sprintf("%.1f", ws$n_valid),
        sprintf("%.2f - %.2f", ws$min, ws$max),
        sprintf("%.2f", ws$mean),
        sprintf("%.2f", ws$sd)
      )
    )
  })

  # Main plot
  output$main_plot <- renderPlot({
    req(rv$results)
    req(length(rv$results$plots) > 0)

    # Return first plot
    rv$results$plots[[1]]
  })

  # Additional plot handler (Phase 2 profit plots)
  output$additional_plot <- renderPlot({
    req(rv$results)
    req(length(rv$results$plots) > 1)
    req(input$plot_selector)

    # Map selection to plot name
    plot_name <- switch(input$plot_selector,
      "Revenue Curve" = "revenue_curve",
      "Profit Curve" = "profit_curve",
      "Revenue vs Profit" = "revenue_vs_profit",
      NULL
    )

    req(plot_name)
    req(!is.null(rv$results$plots[[plot_name]]))

    rv$results$plots[[plot_name]]
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

  # Reactive flags for conditional panels
  output$has_profit_results <- reactive({
    if (is.null(rv$results)) return(FALSE)
    method <- rv$results$method

    gg_results <- if (method == "gabor_granger") {
      rv$results$results
    } else if (method == "both") {
      rv$results$results$gabor_granger
    } else {
      NULL
    }

    !is.null(gg_results) && !is.null(gg_results$optimal_price_profit)
  })
  outputOptions(output, "has_profit_results", suspendWhenHidden = FALSE)

  output$has_weight_summary <- reactive({
    !is.null(rv$results) && !is.null(rv$results$diagnostics$weight_summary)
  })
  outputOptions(output, "has_weight_summary", suspendWhenHidden = FALSE)

  output$has_additional_plots <- reactive({
    !is.null(rv$results) && length(rv$results$plots) > 1
  })
  outputOptions(output, "has_additional_plots", suspendWhenHidden = FALSE)

  # Create template
  observeEvent(input$create_template, {

    template_name <- input$template_name
    if (template_name == "") {
      template_name <- "pricing_config.xlsx"
    }

    # Determine save directory
    save_dir <- if (!is.null(rv$template_dir) && rv$template_dir != "") {
      rv$template_dir
    } else {
      getwd()
    }

    # Construct full path
    output_path <- file.path(save_dir, template_name)

    tryCatch({
      create_pricing_config(
        output_file = output_path,
        method = input$template_method,
        overwrite = TRUE
      )
      showNotification(
        sprintf("Template created: %s", output_path),
        type = "message"
      )
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })
}

# ==============================================================================
# RETURN APP
# ==============================================================================
  shinyApp(ui = ui, server = server)
}
