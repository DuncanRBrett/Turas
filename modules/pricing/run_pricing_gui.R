# ==============================================================================
# TURAS PRICING MODULE - SHINY GUI LAUNCHER
# ==============================================================================
#
# Purpose: Select project directory, detect config files, run analysis
# Version: 13.0
# Date: 2026-03-20
#
# Follows the standard Turas module GUI pattern:
#   Step 1: Select project directory (browse or recent)
#   Step 2: Select config file (auto-detected or browse)
#   Step 3: Run analysis
#   Step 4: View console output + summary
#
# ==============================================================================

#' Run Pricing GUI
#'
#' Launch the Shiny GUI for pricing analysis.
#'
#' @return A shinyApp object
#' @export
run_pricing_gui <- function() {

  # Early refuse function (TRS v1.0 — before full infra is loaded)
  early_refuse <- function(code, title, problem, why_it_matters, how_to_fix) {
    msg <- paste0(
      "\n================================================================================\n",
      sprintf("  [REFUSE] %s: %s\n", code, title),
      "================================================================================\n\n",
      "Problem:\n",
      "  ", problem, "\n\n",
      "Why it matters:\n",
      "  ", why_it_matters, "\n\n",
      "How to fix:\n"
    )
    for (step in how_to_fix) {
      msg <- paste0(msg, "  ", step, "\n")
    }
    msg <- paste0(msg, "\n================================================================================\n")
    stop(msg, call. = FALSE)
  }

  # Required packages
  required_packages <- c("shiny", "shinyFiles")
  missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  if (length(missing_packages) > 0) {
    early_refuse(
      code = "PKG_MISSING_DEPENDENCY",
      title = "Missing Required Packages",
      problem = sprintf("The following required packages are not installed: %s",
                        paste(missing_packages, collapse = ", ")),
      why_it_matters = "The Pricing GUI cannot run without these packages.",
      how_to_fix = c(
        "Run the following command in R:",
        sprintf("  install.packages(c(%s))",
                paste(sprintf('"%s"', missing_packages), collapse = ", "))
      )
    )
  }

  suppressPackageStartupMessages({
    library(shiny)
    library(shinyFiles)
  })

  # Locate Turas root
  turas_root <- Sys.getenv("TURAS_ROOT", getwd())
  if (basename(turas_root) != "Turas") {
    if (file.exists(file.path(dirname(turas_root), "launch_turas.R"))) {
      turas_root <- dirname(turas_root)
    }
  }

  # Locate module directory
  module_dir <- file.path(turas_root, "modules", "pricing")
  r_dir <- file.path(module_dir, "R")

  # Load shared GUI theme
  source(file.path(turas_root, "modules", "shared", "lib", "gui_theme.R"))
  theme <- turas_gui_theme("Pricing", "Price Sensitivity & Optimization")
  hide_recents <- turas_hide_recents()

  # ============================================================================
  # Recent Projects
  # ============================================================================
  RECENT_PROJECTS_FILE <- file.path(turas_root, ".recent_pricing_projects.rds")

  load_recent_projects <- function() {
    if (file.exists(RECENT_PROJECTS_FILE)) {
      tryCatch(readRDS(RECENT_PROJECTS_FILE), error = function(e) list())
    } else {
      list()
    }
  }

  save_recent_projects <- function(projects) {
    tryCatch(saveRDS(projects, RECENT_PROJECTS_FILE), error = function(e) NULL)
  }

  add_recent_project <- function(project_info) {
    recent <- load_recent_projects()
    recent <- recent[!sapply(recent, function(x) x$project_dir == project_info$project_dir)]
    recent <- c(list(project_info), recent)
    recent <- recent[1:min(5, length(recent))]
    save_recent_projects(recent)
  }

  # ============================================================================
  # Config File Detection
  # ============================================================================
  detect_config_files <- function(dir) {
    if (!dir.exists(dir)) return(character(0))
    files <- list.files(dir, pattern = "\\.xlsx$", full.names = FALSE, ignore.case = TRUE)
    config_patterns <- c("pricing.*config", "price.*config", "psm.*config",
                         "van.*westendorp", "gabor.*granger", "config")
    detected <- character(0)
    for (pattern in config_patterns) {
      matches <- grep(pattern, files, value = TRUE, ignore.case = TRUE)
      if (length(matches) > 0) detected <- c(detected, matches)
    }
    unique(detected)
  }

  # ============================================================================
  # Source module files (ordered by dependency)
  # ============================================================================
  pricing_source_files <- c(
    "00_guard.R", "00_main.R", "01_config.R", "02_validation.R",
    "03_van_westendorp.R", "04_gabor_granger.R", "05_visualization.R",
    "06_output.R", "07_wtp_distribution.R", "08_competitive_scenarios.R",
    "09_price_volume_optimisation.R", "10_segmentation.R",
    "11_price_ladder.R", "12_recommendation_synthesis.R", "13_monadic.R"
  )

  # ============================================================================
  # UI
  # ============================================================================
  ui <- fluidPage(

    theme$head,
    theme$header,

    div(class = "turas-content",

      # Step 1: Project Directory
      div(class = "turas-card",
        h4(class = "turas-card-title", "Step 1: Select Project Directory"),

        fluidRow(
          column(if (!hide_recents) 8 else 12,
            shinyDirButton("project_dir_btn",
                           "Browse for Project Folder",
                           "Select project directory",
                           class = "btn turas-btn-primary",
                           icon = icon("folder-open"))
          ),
          if (!hide_recents) {
            column(4,
              uiOutput("recent_projects_ui")
            )
          }
        ),

        uiOutput("project_display")
      ),

      # Step 2: Config File
      conditionalPanel(
        condition = "output.project_selected",
        div(class = "turas-card",
          h4(class = "turas-card-title", "Step 2: Select Configuration File"),
          uiOutput("config_selector"),
          uiOutput("config_display"),
          div(class = "turas-status-info",
            tags$strong("Note: "), "The config file's Settings sheet should specify ",
            tags$code("data_file"), " and ", tags$code("output_file"), " paths."
          )
        )
      ),

      # Step 3: Run Button
      conditionalPanel(
        condition = "output.ready_to_run",
        div(class = "turas-card",
          checkboxInput("generate_stats_pack",
                        "Generate stats pack (diagnostic workbook for advanced review)",
                        value = FALSE),
          actionButton("run_analysis", "Run Pricing Analysis",
                       class = "btn turas-btn-run",
                       icon = icon("play")),
          div(style = "margin-top: 12px;",
            checkboxInput("prepare_deliverable",
                         "Prepare client deliverable (minify for delivery)",
                         value = FALSE)
          )
        )
      ),

      # Step 4: Console Output
      conditionalPanel(
        condition = "output.show_console",
        div(class = "turas-card",
          h4(class = "turas-card-title", "Analysis Output"),
          div(class = "turas-console",
            verbatimTextOutput("console_output")
          ),

          conditionalPanel(
            condition = "output.has_results",
            hr(),
            h4("Summary"),
            tableOutput("results_table"),
            hr(),
            tags$p(
              "Full results written to Excel. Open the HTML file for the interactive report.",
              class = "turas-help-text"
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

    # Reactive values
    files <- reactiveValues(
      project_dir = NULL,
      config_file = NULL
    )

    rv <- reactiveValues(
      results = NULL
    )

    console_text <- reactiveVal("")
    is_running <- reactiveVal(FALSE)

    # Auto-load config from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      if (dir.exists(pre_config)) {
        dir_path <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
        files$project_dir <- dir_path
        detected <- detect_config_files(dir_path)
        if (length(detected) > 0) {
          files$config_file <- file.path(dir_path, detected[1])
        }
      } else if (file.exists(pre_config)) {
        cfg_path <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
        files$config_file <- cfg_path
        files$project_dir <- dirname(cfg_path)
      }
    }

    # Set up directory browser
    volumes <- turas_gui_volumes()

    shinyDirChoose(input, "project_dir_btn", roots = volumes, session = session)

    # ------------------------------------------------------------------
    # Handle project directory selection
    # ------------------------------------------------------------------
    observeEvent(input$project_dir_btn, {
      if (!is.integer(input$project_dir_btn)) {
        dir_path <- parseDirPath(volumes, input$project_dir_btn)
        dir_path <- normalizePath(path.expand(dir_path), winslash = "/", mustWork = FALSE)
        if (length(dir_path) > 0 && dir.exists(dir_path)) {
          files$project_dir <- dir_path
          files$config_file <- NULL
        }
      }
    })

    # ------------------------------------------------------------------
    # Recent projects list
    # ------------------------------------------------------------------
    output$recent_projects_ui <- renderUI({
      recent <- load_recent_projects()
      if (length(recent) == 0) return(NULL)
      div(
        tags$label("Recent:", style = "font-weight: 600; margin-bottom: 5px; display: block;"),
        lapply(seq_along(recent), function(i) {
          proj <- recent[[i]]
          dir_path <- proj$project_dir
          tags$div(
            class = "turas-recent-item",
            onclick = sprintf("Shiny.setInputValue('select_recent', '%s', {priority: 'event'})",
                            gsub("'", "\\\\'", dir_path)),
            tags$strong(basename(dir_path)),
            tags$br(),
            tags$small(style = "color: #666;", dir_path)
          )
        })
      )
    })

    # Handle recent project selection
    observeEvent(input$select_recent, {
      req(input$select_recent)
      dir_path <- normalizePath(path.expand(input$select_recent), winslash = "/", mustWork = FALSE)
      if (dir.exists(dir_path)) {
        files$project_dir <- dir_path
        files$config_file <- NULL
        detected <- detect_config_files(dir_path)
        if (length(detected) > 0) {
          files$config_file <- file.path(dir_path, detected[1])
        }
      }
    })

    # ------------------------------------------------------------------
    # Project display
    # ------------------------------------------------------------------
    output$project_display <- renderUI({
      if (!is.null(files$project_dir)) {
        div(class = "turas-file-display",
          tags$strong(basename(files$project_dir)),
          tags$br(),
          tags$small(files$project_dir),
          div(class = "status-success", "\u2713 Directory selected")
        )
      }
    })

    # ------------------------------------------------------------------
    # Config file selector (auto-detect or browse)
    # ------------------------------------------------------------------
    output$config_selector <- renderUI({
      req(files$project_dir)
      configs <- detect_config_files(files$project_dir)

      if (length(configs) > 0) {
        radioButtons("config_select", "Detected config files:",
                     choices = configs,
                     selected = configs[1])
      } else {
        tagList(
          div(class = "turas-status-warning",
            "No pricing config files detected in this directory. ",
            "Browse to select manually or check the directory."
          ),
          shinyFilesButton("config_btn", "Browse for Config File",
                           "Select configuration file",
                           class = "btn turas-btn-primary",
                           multiple = FALSE)
        )
      }
    })

    # Handle config selection from radio buttons
    observeEvent(input$config_select, {
      if (!is.null(input$config_select) && !is.null(files$project_dir)) {
        files$config_file <- file.path(files$project_dir, input$config_select)
      }
    })

    # Handle config selection from file browser fallback
    shinyFileChoose(input, "config_btn", roots = volumes,
                    filetypes = c("xlsx", "xls"))
    observeEvent(input$config_btn, {
      if (!is.null(input$config_btn) && !is.integer(input$config_btn)) {
        file_selected <- parseFilePaths(volumes, input$config_btn)
        if (nrow(file_selected) > 0) {
          files$config_file <- normalizePath(
            path.expand(as.character(file_selected$datapath)),
            winslash = "/", mustWork = FALSE
          )
        }
      }
    })

    # Config display
    output$config_display <- renderUI({
      if (!is.null(files$config_file)) {
        div(class = "turas-file-display",
          tags$strong(basename(files$config_file)),
          tags$br(),
          tags$small(files$config_file),
          if (file.exists(files$config_file)) {
            div(class = "status-success", "\u2713 Config file found")
          } else {
            div(class = "status-error", "\u2717 File not found")
          }
        )
      }
    })

    # ------------------------------------------------------------------
    # Conditional panel outputs
    # ------------------------------------------------------------------
    output$project_selected <- reactive({ !is.null(files$project_dir) })
    outputOptions(output, "project_selected", suspendWhenHidden = FALSE)

    output$ready_to_run <- reactive({
      !is.null(files$project_dir) &&
      !is.null(files$config_file) &&
      file.exists(files$config_file) &&
      !is_running()
    })
    outputOptions(output, "ready_to_run", suspendWhenHidden = FALSE)

    output$show_console <- reactive({ nchar(console_text()) > 0 })
    outputOptions(output, "show_console", suspendWhenHidden = FALSE)

    output$has_results <- reactive({ !is.null(rv$results) })
    outputOptions(output, "has_results", suspendWhenHidden = FALSE)

    # Console output
    output$console_output <- renderText({
      current_output <- console_text()
      if (is.null(current_output) || length(current_output) == 0 || nchar(current_output[1]) == 0) {
        "Console output will appear here when you run the analysis..."
      } else {
        paste(current_output, collapse = "\n")
      }
    })

    # ------------------------------------------------------------------
    # Run analysis
    # ------------------------------------------------------------------
    observeEvent(input$run_analysis, {

      req(files$project_dir, files$config_file)

      is_running(TRUE)
      on.exit(is_running(FALSE), add = TRUE)
      console_text("")
      rv$results <- NULL

      # Save to recent projects
      add_recent_project(list(project_dir = files$project_dir))

      output_text <- ""

      tryCatch({
        withProgress(message = "Running Pricing Analysis...", value = 0, {

          # Source module files
          incProgress(0.05, detail = "Loading module files...")
          output_text <- paste0(output_text, "Loading Pricing module...\n\n")
          console_text(output_text)

          # Pass deliverable flag and load minification functions if needed
          assign("TURAS_PREPARE_DELIVERABLE",
                 isTRUE(input$prepare_deliverable), envir = .GlobalEnv)
          if (isTRUE(input$prepare_deliverable)) {
            .minify_dir <- file.path(turas_root, "modules", "shared", "lib")
            if (!exists("turas_prepare_deliverable", mode = "function")) {
              source(file.path(.minify_dir, "turas_minify_verify.R"), local = FALSE)
              source(file.path(.minify_dir, "turas_minify.R"), local = FALSE)
            }
          }

          # Set script_dir_override so 00_main.R can find 00_guard.R
          assign("script_dir_override", r_dir, envir = globalenv())

          for (src_file in pricing_source_files) {
            src_path <- file.path(r_dir, src_file)
            tryCatch({
              source(src_path)
            }, error = function(e) {
              cat(sprintf("   [WARN] Failed to source %s: %s\n", src_file, e$message))
            })
          }

          incProgress(0.10, detail = "Starting analysis...")

          # Propagate stats pack flag
          options(turas.generate_stats_pack = isTRUE(input$generate_stats_pack))

          # Capture analysis output
          captured <- capture.output({
            rv$results <- run_pricing_analysis(files$config_file)
          })

          incProgress(0.80, detail = "Finalising results...")

          output_text <- paste0(output_text, paste(captured, collapse = "\n"))
          output_text <- paste0(output_text, "\n\nAnalysis complete!")

          incProgress(0.05, detail = "Done!")

        })  # End withProgress
      }, error = function(e) {
        cat("\n=== TURAS ERROR ===\n")
        cat("Message:", conditionMessage(e), "\n")
        cat("==================\n\n")
        output_text <<- paste0(output_text, "\n\nError: ", e$message)
        showNotification(paste("Error:", conditionMessage(e)), type = "error", duration = 10)
      })

      console_text(output_text)
    })

    # ------------------------------------------------------------------
    # Summary results table
    # ------------------------------------------------------------------
    output$results_table <- renderTable({
      req(rv$results)
      method <- rv$results$method
      cs <- rv$results$config$currency_symbol %||% "$"

      if (method == "van_westendorp") {
        pp <- rv$results$results$price_points
        data.frame(
          `Price Point` = c("PMC", "OPP", "IDP", "PME"),
          Description = c(
            "Point of Marginal Cheapness",
            "Optimal Price Point",
            "Indifference Price Point",
            "Point of Marginal Expensiveness"
          ),
          Price = sprintf("%s%.2f", cs, c(pp$PMC, pp$OPP, pp$IDP, pp$PME)),
          check.names = FALSE
        )
      } else if (method == "gabor_granger") {
        opt <- rv$results$results$optimal_price
        rows <- data.frame(
          Metric = c("Revenue-Maximizing Price", "Purchase Intent", "Revenue Index"),
          Value = c(
            sprintf("%s%.2f", cs, opt$price),
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
              sprintf("%s%.2f", cs, opt_profit$price),
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
              sprintf("%s%.2f", cs, opt$price),
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
            sprintf("%s%.2f - %s%.2f", cs, vw$PMC, cs, vw$PME),
            sprintf("%s%.2f - %s%.2f", cs, vw$OPP, cs, vw$IDP),
            sprintf("%s%.2f", cs, gg$price)
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
