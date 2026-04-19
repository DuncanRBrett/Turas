# ==============================================================================
# TURAS BRAND MODULE - SHINY GUI LAUNCHER
# ==============================================================================
# Shiny interface for running brand health analysis (funnel, mental
# availability, WOM, repertoire). Follows the shared 4-step GUI pattern.
#
# SIZE-EXCEPTION: Shiny GUIs must define UI and server in one function scope
# to share reactive values. All Turas GUI launchers follow this pattern
# (tabs: 615 lines, segment: 549 lines). Decomposing would break reactivity.
# ==============================================================================

run_brand_gui <- function() {

  # Required packages
  required_pkgs <- c("shiny", "shinyFiles", "openxlsx")
  missing_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]

  if (length(missing_pkgs) > 0) {
    msg <- paste0(
      "[REFUSE] PKG_MISSING_DEPENDENCY: Missing Required Packages\n\n",
      "Problem: The following required packages are not installed: ",
      paste(missing_pkgs, collapse = ", "), "\n\n",
      "How to fix: Run the following command in R:\n",
      "  install.packages(c(", paste(sprintf('"%s"', missing_pkgs), collapse = ", "), "))\n"
    )
    cat("\n=== BRAND ERROR ===\n")
    cat(msg)
    cat("===================\n\n")
    stop(msg, call. = FALSE)
  }

  library(shiny)
  library(shinyFiles)

  turas_root <- Sys.getenv("TURAS_ROOT", getwd())
  brand_dir  <- file.path(turas_root, "modules", "brand")

  # Shared GUI theme
  source(file.path(turas_root, "modules", "shared", "lib", "gui_theme.R"))
  theme      <- turas_gui_theme("Brand", "Brand Health Analysis")
  hide_recents <- turas_hide_recents()

  # Source brand module
  source(file.path(brand_dir, "R", "00_main.R"))

  # Source HTML report generator and Excel output
  source(file.path(brand_dir, "lib", "html_report", "99_html_report_main.R"))
  source(file.path(brand_dir, "R", "99_output.R"))

  # Recent projects
  load_recent_projects <- function() turas_load_recents("brand")
  save_recent_project  <- function(p) turas_add_recent("brand", p)

  # ===========================================================================
  # SHINY UI
  # ===========================================================================

  ui <- fluidPage(
    theme$head,
    theme$header,

    div(class = "turas-content",

      # Step 1: Select Brand_Config.xlsx
      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 1: Select Configuration File"),
        p("Choose your Brand_Config.xlsx file. The Survey_Structure.xlsx and data files ",
          "are resolved from the settings inside Brand_Config."),

        shinyFilesButton("select_config_btn", "Browse for Brand_Config.xlsx",
                         "Select Brand_Config.xlsx",
                         multiple = FALSE,
                         class = "btn btn-primary",
                         icon = icon("folder-open")),

        uiOutput("config_display"),

        if (!hide_recents) uiOutput("recent_projects_ui")
      ),

      # Step 2: Configuration Summary
      uiOutput("config_summary_ui"),

      # Step 3: Run Analysis
      uiOutput("run_button_ui"),

      # Step 4: Console Output
      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 4: Console Output"),
        div(class = "turas-console",
          verbatimTextOutput("console_text")
        )
      ),

      # Step 5: Results
      uiOutput("results_ui")
    )
  )

  # ===========================================================================
  # SHINY SERVER
  # ===========================================================================

  server <- function(input, output, session) {

    config_file    <- reactiveVal(NULL)
    analysis_result <- reactiveVal(NULL)
    console_output <- reactiveVal("")

    # Auto-load from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      if (dir.exists(pre_config)) {
        dir_path   <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
        xlsx_files <- list.files(dir_path, pattern = "Brand_Config.*\\.xlsx$",
                                 full.names = TRUE, ignore.case = TRUE)
        if (length(xlsx_files) > 0) {
          config_file(xlsx_files[1])
        } else {
          all_xlsx <- list.files(dir_path, pattern = "\\.xlsx$", full.names = TRUE)
          if (length(all_xlsx) > 0) config_file(all_xlsx[1])
        }
      } else if (file.exists(pre_config)) {
        config_file(normalizePath(pre_config, winslash = "/", mustWork = FALSE))
      }
    }

    volumes <- turas_gui_volumes()
    shinyFileChoose(input, "select_config_btn", roots = volumes,
                    filetypes = c("xlsx", "xls"))

    # Handle file selection
    observeEvent(input$select_config_btn, {
      if (!is.null(input$select_config_btn) && !is.integer(input$select_config_btn)) {
        sel <- parseFilePaths(volumes, input$select_config_btn)
        if (nrow(sel) > 0) {
          fp <- normalizePath(path.expand(as.character(sel$datapath)),
                              winslash = "/", mustWork = FALSE)
          config_file(fp)
          save_recent_project(fp)
          analysis_result(NULL)
        }
      }
    })

    # Handle recent project selection
    observeEvent(input$recent_project, {
      req(input$recent_project)
      recents <- load_recent_projects()
      if (input$recent_project <= length(recents)) {
        fp <- normalizePath(path.expand(recents[[input$recent_project]]),
                            winslash = "/", mustWork = FALSE)
        if (file.exists(fp)) {
          config_file(fp)
          save_recent_project(fp)
          analysis_result(NULL)
        } else {
          showNotification("Config file no longer exists at this location",
                           type = "error", duration = 5)
        }
      }
    })

    # Display selected file
    output$config_display <- renderUI({
      req(config_file())
      div(
        div(class = "turas-file-display",
          strong("Selected: "), basename(config_file()),
          br(),
          tags$small(dirname(config_file()))
        )
      )
    })

    # Recent projects list
    output$recent_projects_ui <- renderUI({
      recents <- load_recent_projects()
      if (length(recents) > 0) {
        div(
          hr(),
          p(strong("Recent Projects:"), style = "margin-top: 15px; margin-bottom: 10px;"),
          lapply(seq_along(recents), function(i) {
            if (file.exists(recents[[i]])) {
              tags$div(
                class = "turas-recent-item",
                onclick = paste0("Shiny.setInputValue('recent_project', ", i,
                                 ", {priority: 'event'})"),
                tags$strong(basename(recents[[i]])),
                tags$br(),
                tags$small(dirname(recents[[i]]))
              )
            }
          })
        )
      }
    })

    # Config summary (Step 2)
    output$config_summary_ui <- renderUI({
      req(config_file())

      tryCatch({
        cfg <- load_brand_config(config_file())

        cats <- cfg$categories
        n_cats <- if (!is.null(cats)) nrow(cats) else 0

        elements_on <- c(
          if (isTRUE(cfg$element_funnel))        "Funnel",
          if (isTRUE(cfg$element_mental_avail))  "Mental Availability",
          if (isTRUE(cfg$element_wom))           "WOM",
          if (isTRUE(cfg$element_repertoire))    "Repertoire",
          if (isTRUE(cfg$element_cep_turf))      "CEP TURF",
          if (isTRUE(cfg$element_dba))           "Brand Assets"
        )

        div(class = "turas-card",
          h3(class = "turas-card-title", "Step 2: Configuration Summary"),
          div(class = "turas-status-info",
            strong("Configuration Loaded Successfully"), br(),
            hr(style = "margin: 10px 0;"),
            strong("Categories: "), n_cats, br(),
            if (n_cats > 0) {
              tagList(
                strong("Category names: "),
                paste(cats$Category, collapse = ", "), br()
              )
            },
            strong("Focal brand: "), cfg$focal_brand %||% "(not set)", br(),
            strong("Elements enabled: "),
            if (length(elements_on) > 0) paste(elements_on, collapse = ", ") else "none", br(),
            strong("Output folder: "), cfg$output_dir %||% "(same as config)", br()
          )
        )
      },
      error = function(e) {
        div(class = "turas-card",
          h3(class = "turas-card-title", "Step 2: Configuration Summary"),
          div(class = "turas-status-error",
            strong("\u2717 Configuration Error"), br(),
            hr(style = "margin: 10px 0;"),
            as.character(e$message)
          )
        )
      })
    })

    # Run button (Step 3)
    output$run_button_ui <- renderUI({
      req(config_file())

      div(class = "turas-card",
        h3(class = "turas-card-title", "Step 3: Run Analysis"),
        p("Click the button below to run the full brand health analysis. ",
          "This may take a moment depending on sample size and elements enabled."),

        checkboxInput("open_on_completion",
                      "Open HTML report in browser on completion",
                      value = TRUE),

        div(style = "margin-top: 12px;",
          checkboxInput("prepare_deliverable",
                        "Prepare client deliverable (minify for delivery)",
                        value = FALSE)
        ),

        actionButton("run_analysis_btn", "Run Brand Analysis",
                     class = "turas-btn-run",
                     icon = icon("play-circle"))
      )
    })

    # Console output rendering
    output$console_text <- renderText({
      out <- console_output()
      if (is.null(out) || length(out) == 0 || nchar(out[1]) == 0) {
        "Console output will appear here when you run the analysis..."
      } else {
        if (length(out) > 1) paste(out, collapse = "\n") else out
      }
    })

    # Run analysis
    observeEvent(input$run_analysis_btn, {
      req(config_file())

      console_output("")
      analysis_result(NULL)

      progress <- Progress$new(session)
      progress$set(message = "Running brand analysis", value = 0)
      on.exit(progress$close())

      # Deliverable flag
      assign("TURAS_PREPARE_DELIVERABLE",
             isTRUE(input$prepare_deliverable), envir = .GlobalEnv)
      if (isTRUE(input$prepare_deliverable)) {
        minify_dir <- file.path(turas_root, "modules", "shared", "lib")
        if (!exists("turas_prepare_deliverable", mode = "function")) {
          source(file.path(minify_dir, "turas_minify_verify.R"), local = FALSE)
          source(file.path(minify_dir, "turas_minify_watermark.R"), local = FALSE)
          source(file.path(minify_dir, "turas_minify.R"), local = FALSE)
        }
      }

      old_wd <- getwd()
      setwd(turas_root)

      tryCatch({
        progress$set(value = 0.2, detail = "Running analysis...")

        output_capture_file <- tempfile()
        sink(output_capture_file, type = "output")

        run_result <- tryCatch({

          res <- run_brand(config_file(), verbose = TRUE)

          if (identical(res$status, "REFUSED")) {
            list(success = FALSE, error = paste(res$message, collapse = "\n"),
                 result = NULL)
          } else {
            # Derive output paths
            cfg        <- res$config
            output_dir <- cfg$output_dir_resolved %||% cfg$output_dir %||%
                          dirname(config_file())
            if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

            cfg_base <- tools::file_path_sans_ext(basename(config_file()))
            out_html  <- file.path(output_dir, paste0(cfg_base, "_report.html"))
            out_xlsx  <- file.path(output_dir, paste0(cfg_base, "_report.xlsx"))

            progress$set(value = 0.7, detail = "Generating HTML report...")
            html_result <- generate_brand_html_report(res, out_html, config = cfg)

            progress$set(value = 0.85, detail = "Generating Excel report...")
            xlsx_result <- generate_brand_excel(res, out_xlsx, config = cfg)

            list(
              success    = TRUE,
              result     = res,
              output_dir = output_dir,
              html_path  = if (identical(html_result$status, "PASS") ||
                                file.exists(out_html)) out_html else NULL,
              xlsx_path  = if (identical(xlsx_result$status, "PASS") ||
                                file.exists(out_xlsx)) out_xlsx else NULL
            )
          }

        }, error = function(e) {
          list(
            success = FALSE,
            error   = paste0(e$message, "\n\nCall: ",
                             paste(deparse(e$call), collapse = "\n"))
          )
        }, finally = {
          sink(type = "output")
        })

        progress$set(value = 0.95, detail = "Finalizing...")

        captured <- readLines(output_capture_file, warn = FALSE)
        unlink(output_capture_file)

        console_output(
          if (length(captured) > 0) paste(captured, collapse = "\n")
          else "Analysis completed but produced no console output."
        )

        if (run_result$success) {
          analysis_result(run_result)

          console_output(paste0(
            console_output(),
            sprintf("\n\n%s\n\u2713 ANALYSIS COMPLETE\n%s\n",
                    strrep("=", 80), strrep("=", 80))
          ))

          # Open HTML in browser if requested
          if (isTRUE(input$open_on_completion) && !is.null(run_result$html_path) &&
              file.exists(run_result$html_path)) {
            browseURL(run_result$html_path)
          }

          save_recent_project(config_file())
          progress$set(value = 1.0, detail = "Complete!")
          showNotification("Brand analysis completed successfully!",
                           type = "message", duration = 5)

        } else {
          analysis_result(list(error = run_result$error))

          console_output(paste0(
            console_output(),
            sprintf("\n\n%s\nERROR\n%s\n%s\n",
                    strrep("=", 80), strrep("=", 80), run_result$error)
          ))

          showNotification(paste("Error:", run_result$error),
                           type = "error", duration = 10)
        }

      }, error = function(e) {
        error_msg <- paste0(strrep("=", 80), "\nERROR: ", e$message, "\n", strrep("=", 80))
        console_output(paste0(console_output(), "\n\n", error_msg))
        showNotification(paste("Error:", e$message), type = "error", duration = 10)

      }, finally = {
        setwd(old_wd)
      })
    })

    # Results display (Step 5)
    output$results_ui <- renderUI({
      req(analysis_result())

      result <- analysis_result()

      if (!is.null(result$error)) {
        div(class = "turas-card",
          h3(class = "turas-card-title", "Step 5: Results"),
          div(class = "turas-status-error",
            strong("\u2717 Analysis Error"), br(),
            hr(style = "margin: 10px 0;"),
            p(strong("Error Details:")),
            p(style = "font-family: monospace; white-space: pre-wrap;", result$error),
            hr(style = "margin: 10px 0;"),
            p(strong("Note:"), " Check console output above for details.")
          )
        )
      } else {
        res <- result$result

        n_warnings <- length(res$warnings)
        elapsed    <- round(res$elapsed_seconds %||% 0, 1)

        div(class = "turas-card",
          h3(class = "turas-card-title", "Step 5: Results"),

          div(class = if (n_warnings > 0) "turas-status-partial" else "turas-status-success",
            strong(if (n_warnings > 0) "\u26a0 Analysis Complete (with warnings)"
                   else "\u2713 Analysis Complete!"), br(),
            hr(style = "margin: 10px 0;"),

            strong("Status: "), res$status, br(),
            strong("Elapsed: "), elapsed, " seconds", br(),
            br(),

            if (n_warnings > 0) {
              tagList(
                strong("Warnings:"), br(),
                lapply(res$warnings, function(w) tagList("  \u2022 ", w, br())),
                br()
              )
            },

            strong("Output folder: "), result$output_dir, br(),
            br(),

            if (!is.null(result$html_path)) {
              tagList(strong("HTML report: "), basename(result$html_path), br())
            },
            if (!is.null(result$xlsx_path)) {
              tagList(strong("Excel report: "), basename(result$xlsx_path), br())
            }
          ),

          br(),

          div(style = "display: flex; gap: 10px; flex-wrap: wrap;",
            actionButton("open_output_btn", "Open Output Folder",
                         class = "btn btn-primary",
                         icon = icon("folder-open")),

            if (!is.null(result$html_path) && file.exists(result$html_path)) {
              actionButton("open_html_btn", "Open HTML Report",
                           class = "btn btn-success",
                           icon = icon("globe"))
            }
          )
        )
      }
    })

    # Open output folder
    observeEvent(input$open_output_btn, {
      req(analysis_result())
      result <- analysis_result()
      out_path <- result$output_dir %||% dirname(config_file())

      if (.Platform$OS.type == "windows") {
        shell.exec(out_path)
      } else if (Sys.info()["sysname"] == "Darwin") {
        system(paste("open", shQuote(out_path)))
      } else {
        system(paste("xdg-open", shQuote(out_path)))
      }
    })

    # Open HTML report in browser
    observeEvent(input$open_html_btn, {
      req(analysis_result())
      result <- analysis_result()
      if (!is.null(result$html_path) && file.exists(result$html_path)) {
        browseURL(result$html_path)
      }
    })
  }

  shinyApp(ui = ui, server = server)
}
