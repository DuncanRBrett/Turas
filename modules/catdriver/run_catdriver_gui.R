# ==============================================================================
# TURAS CATEGORICAL KEY DRIVER MODULE - GUI LAUNCHER
# ==============================================================================
# Supports single-config and multi-config (unified report) workflows.
# Multi-config: select 2+ config files → run sequentially → unified report.
# ==============================================================================

#' Run Categorical Key Driver Analysis GUI
#'
#' Launches a Shiny GUI for running categorical key driver analysis.
#' Supports selecting multiple config files for unified report generation.
#'
#' @return A shinyApp object
#' @export
run_catdriver_gui <- function() {

  # Required packages - check availability (TRS v1.0: no auto-install)
  required_packages <- c("shiny", "shinyFiles")

  # Check for missing packages and refuse with clear instructions if any are missing
  missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  if (length(missing_packages) > 0) {
    stop(
      "\n================================================================================\n",
      "  [REFUSE] PKG_MISSING_DEPENDENCY: Missing Required Packages\n",
      "================================================================================\n\n",
      "Problem:\n",
      "  The following required packages are not installed: ", paste(missing_packages, collapse = ", "), "\n\n",
      "Why it matters:\n",
      "  The CatDriver GUI cannot run without these packages.\n\n",
      "How to fix:\n",
      "  Run the following command in R:\n",
      "    install.packages(c(", paste(sprintf('"%s"', missing_packages), collapse = ", "), "))\n\n",
      "================================================================================\n",
      call. = FALSE
    )
  }

  # Load packages
  suppressPackageStartupMessages({
    library(shiny)
    library(shinyFiles)
  })

  # Get Turas root directory
  turas_root <- Sys.getenv("TURAS_ROOT", getwd())
  if (basename(turas_root) != "Turas") {
    if (file.exists(file.path(dirname(turas_root), "launch_turas.R"))) {
      turas_root <- dirname(turas_root)
    }
  }

  # Load shared GUI theme
  source(file.path(turas_root, "modules", "shared", "lib", "gui_theme.R"))
  theme <- turas_gui_theme("Categorical Driver", "Categorical Key Driver Analysis")
  hide_recents <- turas_hide_recents()

  # Recent projects file
  RECENT_PROJECTS_FILE <- file.path(turas_root, ".recent_catdriver_projects.rds")

  # Load recent projects
  load_recent_projects <- function() {
    if (file.exists(RECENT_PROJECTS_FILE)) {
      tryCatch(readRDS(RECENT_PROJECTS_FILE), error = function(e) list())
    } else {
      list()
    }
  }

  # Save recent projects
  save_recent_projects <- function(projects) {
    tryCatch(saveRDS(projects, RECENT_PROJECTS_FILE), error = function(e) NULL)
  }

  # Add to recent projects
  add_recent_project <- function(project_info) {
    recent <- load_recent_projects()
    # Remove duplicates
    recent <- recent[!sapply(recent, function(x) x$project_dir == project_info$project_dir)]
    # Add new at front
    recent <- c(list(project_info), recent)
    # Keep only last 5
    recent <- recent[1:min(5, length(recent))]
    save_recent_projects(recent)
  }

  # Detect config files in directory
  detect_config_files <- function(dir) {
    if (!dir.exists(dir)) return(character(0))
    files <- list.files(dir, pattern = "\\.xlsx$", full.names = FALSE, ignore.case = TRUE)
    config_patterns <- c("catdriver.*config", "cat.*driver.*config", "categorical.*config",
                        "keydriver.*config", "config")
    detected <- character(0)
    for (pattern in config_patterns) {
      matches <- grep(pattern, files, value = TRUE, ignore.case = TRUE)
      if (length(matches) > 0) detected <- c(detected, matches)
    }
    unique(detected)
  }

  # Hex colour validator
  is_valid_hex <- function(x) {
    !is.null(x) && nzchar(x) && grepl("^#[0-9A-Fa-f]{6}$", x)
  }

  ui <- fluidPage(

    theme$head,

    # Module-specific CSS for catdriver-unique elements
    tags$style(HTML("
      .toggle-link {
        font-size: 13px;
        cursor: pointer;
        margin-bottom: 8px;
        display: inline-block;
      }
      .config-list-item {
        display: flex;
        align-items: center;
        gap: 6px;
        margin-bottom: 4px;
        font-size: 13px;
      }
      .colour-swatch {
        display: inline-block;
        width: 24px;
        height: 24px;
        border-radius: 4px;
        border: 1px solid #ccc;
        vertical-align: middle;
      }
    ")),

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

      # Step 2: Config Files (multi-select)
      conditionalPanel(
        condition = "output.project_selected",
        div(class = "turas-card",
          h4(class = "turas-card-title", "Step 2: Select Configuration Files"),
          uiOutput("config_selector"),
          uiOutput("config_display"),
          div(class = "turas-status-info",
            tags$strong("Note: "), "Each config file needs ",
            tags$code("Settings"), ", ", tags$code("Variables"), ", and ",
            tags$code("Driver_Settings"), " sheets. ",
            "Select multiple configs to generate a unified report."
          ),

          # Subgroup comparison option (collapsible advanced)
          tags$hr(),
          actionLink("toggle_advanced", "Advanced Options",
                     class = "toggle-link", icon = icon("cog")),
          conditionalPanel(
            condition = "input.toggle_advanced % 2 == 1",
            div(style = "margin-top: 10px;",
              fluidRow(
                column(6,
                  textInput("subgroup_var", "Subgroup Variable (optional)",
                            value = "",
                            placeholder = "e.g., age_group, region, segment")
                ),
                column(6,
                  div(style = "margin-top: 30px; font-size: 12px; color: #6c757d;",
                    "Enter a column name from your data to split the analysis ",
                    "by subgroup. Leave blank for standard analysis. ",
                    "The variable must NOT be the outcome or a driver."
                  )
                )
              )
            )
          )
        )
      ),

      # Step 3: Report Settings (always visible when configs selected)
      conditionalPanel(
        condition = "output.ready_to_run",
        div(class = "turas-card",
          h4(class = "turas-card-title", "Step 3: Report Settings"),

          fluidRow(
            column(6,
              textInput("report_title", "Report Title",
                        value = "Categorical Key Driver Analysis",
                        placeholder = "e.g., Q4 2024 Brand Health Drivers")
            ),
            column(6,
              textInput("client_name", "Client Name (optional)",
                        value = "",
                        placeholder = "e.g., Acme Corp")
            )
          ),

          fluidRow(
            column(6,
              textInput("researcher_name", "Researcher Name (optional)",
                        value = "",
                        placeholder = "e.g., Jane Smith")
            ),
            column(6,
              div(style = "margin-top: 30px; font-size: 12px; color: #6c757d;",
                "Appears in the report header alongside company name."
              )
            )
          ),

          fluidRow(
            column(3,
              textInput("brand_colour", "Brand Colour",
                        value = "#323367",
                        placeholder = "#323367")
            ),
            column(3,
              textInput("accent_colour", "Accent Colour",
                        value = "#CC9900",
                        placeholder = "#CC9900")
            ),
            column(3,
              fileInput("researcher_logo", "Researcher Logo",
                        accept = c("image/png", "image/jpeg", "image/svg+xml"))
            ),
            column(3,
              fileInput("client_logo", "Client Logo",
                        accept = c("image/png", "image/jpeg", "image/svg+xml"))
            )
          ),

          uiOutput("colour_preview"),

          div(class = "turas-status-info",
            tags$strong("Note: "), "These settings are applied to the generated HTML report. ",
            "They override any brand/colour settings in individual config files."
          ),

          checkboxInput("generate_stats_pack",
                        "Generate stats pack (diagnostic workbook for advanced review)",
                        value = FALSE)
        )
      ),

      # Run Button (dynamic label)
      conditionalPanel(
        condition = "output.ready_to_run",
        div(class = "turas-card",
          uiOutput("run_button_ui")
        )
      ),

      # Console Output
      conditionalPanel(
        condition = "output.show_console",
        div(class = "turas-card",
          h4(class = "turas-card-title", "Analysis Output"),
          div(class = "turas-console",
            verbatimTextOutput("console_output")
          )
        )
      )
    )
  )

  server <- function(input, output, session) {

    # Reactive values
    files <- reactiveValues(
      project_dir = NULL,
      config_files = character(0)  # Vector of full paths
    )

    console_text <- reactiveVal("")
    is_running <- reactiveVal(FALSE)

    # Auto-load config from launcher
    pre_config <- Sys.getenv("TURAS_MODULE_CONFIG", unset = "")
    if (nzchar(pre_config)) {
      Sys.unsetenv("TURAS_MODULE_CONFIG")
      if (dir.exists(pre_config)) {
        # Hub passed a project directory (from recent_key = "project_dir")
        files$project_dir <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
        # Auto-detect config file in the directory
        detected <- detect_config_files(files$project_dir)
        if (length(detected) > 0) {
          files$config_files <- file.path(files$project_dir, detected[1])
        }
      } else if (file.exists(pre_config)) {
        # Hub passed an actual config file path
        files$config_files <- normalizePath(pre_config, winslash = "/", mustWork = FALSE)
        files$project_dir <- dirname(files$config_files)
      }
    }

    # Set up directory browser
    volumes <- turas_gui_volumes()

    shinyDirChoose(input, "project_dir_btn", roots = volumes, session = session)

    # Handle project directory selection
    observeEvent(input$project_dir_btn, {
      if (!is.integer(input$project_dir_btn)) {
        dir_path <- parseDirPath(volumes, input$project_dir_btn)
        # Expand tilde and normalize path (fixes OneDrive/home directory paths)
        dir_path <- normalizePath(path.expand(dir_path), winslash = "/", mustWork = FALSE)
        if (length(dir_path) > 0 && dir.exists(dir_path)) {
          files$project_dir <- dir_path
          files$config_files <- character(0)
        }
      }
    })

    # Recent projects dropdown
    output$recent_projects_ui <- renderUI({
      recent <- load_recent_projects()
      if (length(recent) > 0) {
        choices <- setNames(
          sapply(recent, function(x) x$project_dir),
          sapply(recent, function(x) basename(x$project_dir))
        )
        selectInput("recent_project", "Recent:",
                   choices = c("Select recent..." = "", choices),
                   width = "100%")
      }
    })

    # Handle recent project selection
    observeEvent(input$recent_project, {
      if (!is.null(input$recent_project) && input$recent_project != "") {
        if (dir.exists(input$recent_project)) {
          files$project_dir <- input$recent_project
          files$config_files <- character(0)
        }
      }
    })

    # Project display
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

    # =========================================================================
    # CONFIG FILE SELECTOR (checkboxes + select all toggle)
    # =========================================================================

    output$config_selector <- renderUI({
      req(files$project_dir)
      configs <- detect_config_files(files$project_dir)

      if (length(configs) > 0) {
        tagList(
          actionLink("toggle_all_configs", "Select All / Deselect All",
                     class = "toggle-link"),
          checkboxGroupInput("config_select", "Detected config files:",
                            choices = configs,
                            selected = configs[1])
        )
      } else {
        # Manual file selection fallback
        shinyFilesButton("config_btn", "Browse for Config File",
                        "Select configuration file",
                        class = "btn turas-btn-primary",
                        multiple = FALSE)
      }
    })

    # Select All / Deselect All toggle
    observeEvent(input$toggle_all_configs, {
      configs <- detect_config_files(files$project_dir)
      current <- input$config_select
      if (length(current) == length(configs)) {
        updateCheckboxGroupInput(session, "config_select", selected = character(0))
      } else {
        updateCheckboxGroupInput(session, "config_select", selected = configs)
      }
    })

    # Handle config selection → build full path vector
    observeEvent(input$config_select, {
      if (!is.null(input$config_select) && length(input$config_select) > 0 &&
          !is.null(files$project_dir)) {
        files$config_files <- file.path(files$project_dir, input$config_select)
      } else {
        files$config_files <- character(0)
      }
    }, ignoreNULL = FALSE)

    # Config display — bullet list of selected files
    output$config_display <- renderUI({
      if (length(files$config_files) > 0) {
        file_items <- lapply(files$config_files, function(f) {
          exists <- file.exists(f)
          div(class = "config-list-item",
            tags$span(
              class = if (exists) "status-success" else "status-error",
              if (exists) "\u2713" else "\u2717"
            ),
            tags$span(basename(f))
          )
        })
        div(class = "turas-file-display",
          tags$strong(
            sprintf("%d config%s selected",
                    length(files$config_files),
                    if (length(files$config_files) != 1) "s" else "")),
          file_items
        )
      }
    })

    # =========================================================================
    # COLOUR PREVIEW
    # =========================================================================

    output$colour_preview <- renderUI({
      brand <- input$brand_colour
      accent <- input$accent_colour
      items <- list()
      if (is_valid_hex(brand)) {
        items <- c(items, list(
          tags$span(class = "colour-swatch", style = sprintf("background:%s;", brand)),
          tags$span(style = "font-size:12px;color:#6c757d;margin-right:16px;", "Brand")
        ))
      }
      if (is_valid_hex(accent)) {
        items <- c(items, list(
          tags$span(class = "colour-swatch", style = sprintf("background:%s;", accent)),
          tags$span(style = "font-size:12px;color:#6c757d;", "Accent")
        ))
      }
      if (length(items) > 0) {
        div(style = "display:flex;align-items:center;gap:8px;margin-top:8px;", items)
      }
    })

    # =========================================================================
    # DYNAMIC RUN BUTTON
    # =========================================================================

    output$run_button_ui <- renderUI({
      n <- length(files$config_files)
      label <- if (n <= 1) {
        "Run Categorical Key Driver Analysis"
      } else {
        sprintf("Run %d Analyses + Generate Unified Report", n)
      }
      actionButton("run_analysis", label,
                    class = "btn turas-btn-run",
                    icon = icon("play"))
    })

    # =========================================================================
    # CONDITIONAL PANEL FLAGS
    # =========================================================================

    output$project_selected <- reactive({ !is.null(files$project_dir) })
    outputOptions(output, "project_selected", suspendWhenHidden = FALSE)

    output$ready_to_run <- reactive({
      !is.null(files$project_dir) &&
      length(files$config_files) > 0 &&
      all(file.exists(files$config_files)) &&
      !is_running()
    })
    outputOptions(output, "ready_to_run", suspendWhenHidden = FALSE)

    output$show_console <- reactive({ nchar(console_text()) > 0 })
    outputOptions(output, "show_console", suspendWhenHidden = FALSE)

    # Console output - R 4.2+ compatibility (ensure single string)
    output$console_output <- renderText({
      current_output <- console_text()

      # Ensure single string for R 4.2+ compatibility
      if (is.null(current_output) || length(current_output) == 0 || nchar(current_output[1]) == 0) {
        "Console output will appear here when you run the analysis..."
      } else {
        # Ensure it's a single string
        paste(current_output, collapse = "\n")
      }
    })

    # =========================================================================
    # RUN ANALYSIS — Multi-config orchestration
    # =========================================================================

    observeEvent(input$run_analysis, {

      req(files$project_dir, length(files$config_files) > 0)

      is_running(TRUE)
      console_text("")

      # Save to recent projects
      add_recent_project(list(project_dir = files$project_dir))

      # Capture output
      output_text <- ""
      n_configs <- length(files$config_files)
      is_multi <- n_configs >= 2

      # Use withProgress for visual progress bar
      withProgress(message = "Running Key Driver Analysis", value = 0, {

        tryCatch({
          # Get Turas root
          turas_root <- Sys.getenv("TURAS_ROOT", getwd())
          if (basename(turas_root) != "Turas") {
            turas_root <- dirname(turas_root)
          }

          # =================================================================
          # PHASE 1: Source module files
          # =================================================================
          output_text <- paste0(output_text, "Loading Categorical Key Driver module...\n\n")
          console_text(output_text)
          setProgress(value = 0.02, detail = "Loading modules...")

          # 1. Source shared TRS infrastructure first (required by guard files)
          source(file.path(turas_root, "modules/shared/lib/import_all.R"))

          # 2. Source CatDriver modules in dependency order
          source(file.path(turas_root, "modules/catdriver/R/07_utilities.R"))
          source(file.path(turas_root, "modules/catdriver/R/08_guard.R"))
          source(file.path(turas_root, "modules/catdriver/R/08a_guards_hard.R"))
          source(file.path(turas_root, "modules/catdriver/R/08b_guards_soft.R"))
          source(file.path(turas_root, "modules/catdriver/R/01_config.R"))
          source(file.path(turas_root, "modules/catdriver/R/02_validation.R"))
          source(file.path(turas_root, "modules/catdriver/R/03_preprocessing.R"))
          source(file.path(turas_root, "modules/catdriver/R/09_mapper.R"))
          source(file.path(turas_root, "modules/catdriver/R/10_missing.R"))
          source(file.path(turas_root, "modules/catdriver/R/04_analysis.R"))
          source(file.path(turas_root, "modules/catdriver/R/04a_ordinal.R"))
          source(file.path(turas_root, "modules/catdriver/R/04b_multinomial.R"))
          source(file.path(turas_root, "modules/catdriver/R/05_importance.R"))
          source(file.path(turas_root, "modules/catdriver/R/06a_sheets_summary.R"))
          source(file.path(turas_root, "modules/catdriver/R/06b_sheets_detail.R"))
          source(file.path(turas_root, "modules/catdriver/R/06_output.R"))
          source(file.path(turas_root, "modules/catdriver/R/06c_sheets_subgroup.R"))
          source(file.path(turas_root, "modules/catdriver/R/11_subgroup_comparison.R"))
          source(file.path(turas_root, "modules/catdriver/R/00_main.R"))

          # 3. Set lib dir for HTML report auto-discovery + source pipeline if multi-config
          assign(".catdriver_lib_dir",
                 file.path(turas_root, "modules", "catdriver", "lib"),
                 envir = globalenv())
          if (is_multi) {
            source(file.path(turas_root, "modules/catdriver/lib/html_report/99_html_report_main.R"))
          }

          setProgress(value = 0.05, detail = "Modules loaded")

          # =================================================================
          # PHASE 2: Run each config sequentially
          # =================================================================
          analyses <- list()        # Named list for unified report
          failed_configs <- list()  # Track failures

          for (i in seq_along(files$config_files)) {
            config_path <- files$config_files[i]
            config_name <- tools::file_path_sans_ext(basename(config_path))

            # Progress: each config gets a proportional slice within 5%-85%
            base_progress <- 0.05 + (i - 1) * (0.80 / n_configs)
            slice_size <- 0.80 / n_configs

            output_text <- paste0(output_text,
              sprintf("\n%s\n", paste(rep("=", 50), collapse = "")),
              sprintf("  Config %d/%d: %s\n", i, n_configs, basename(config_path)),
              sprintf("%s\n", paste(rep("=", 50), collapse = "")))
            console_text(output_text)

            setProgress(
              value = base_progress,
              detail = sprintf("Config %d/%d: %s", i, n_configs, config_name)
            )

            # Scoped progress callback for this config
            config_progress <- function(value, message) {
              scaled <- base_progress + (value * slice_size)
              setProgress(value = scaled,
                          detail = sprintf("[%d/%d] %s", i, n_configs, message))
            }

            # Build config overrides from all GUI inputs
            gui_overrides <- list()

            # Subgroup variable
            subgroup_input <- input$subgroup_var
            if (!is.null(subgroup_input) && nzchar(trimws(subgroup_input))) {
              gui_overrides$subgroup_var <- trimws(subgroup_input)
            }

            # Report branding settings
            if (is_valid_hex(input$brand_colour)) {
              gui_overrides$brand_colour <- input$brand_colour
            }
            if (is_valid_hex(input$accent_colour)) {
              gui_overrides$accent_colour <- input$accent_colour
            }
            if (!is.null(input$report_title) && nzchar(input$report_title)) {
              gui_overrides$report_title <- input$report_title
            }
            if (!is.null(input$client_name) && nzchar(input$client_name)) {
              gui_overrides$client_name <- input$client_name
            }
            if (!is.null(input$researcher_name) && nzchar(input$researcher_name)) {
              gui_overrides$researcher_name <- input$researcher_name
            }
            gui_overrides$company_name <- "The Research Lamppost"

            # Logo file paths from fileInput uploads
            if (!is.null(input$researcher_logo)) {
              gui_overrides$researcher_logo_path <- input$researcher_logo$datapath
            }
            if (!is.null(input$client_logo)) {
              gui_overrides$client_logo_path <- input$client_logo$datapath
            }

            # If no overrides were added beyond company_name, keep minimal
            if (length(gui_overrides) == 1 && "company_name" %in% names(gui_overrides)) {
              gui_overrides <- NULL
            }

            # Run with full output capture
            options(turas.generate_stats_pack = isTRUE(input$generate_stats_pack))
            captured <- capture_console_all({
              run_categorical_keydriver(
                config_file = config_path,
                progress_callback = config_progress,
                config_overrides = gui_overrides
              )
            })

            output_text <- paste0(output_text,
                                   paste(captured$combined_output, collapse = "\n"))

            if (captured$has_error) {
              output_text <- paste0(output_text,
                sprintf("\n\u2717 Config '%s' FAILED\n", config_name))
              failed_configs[[config_name]] <- "error"

            } else {
              result <- captured$result

              # Check for TRS refusal
              is_refused <- isTRUE(result$status == "REFUSED") ||
                            isTRUE(result$run_status == "REFUSED")

              if (is_refused) {
                output_text <- paste0(output_text,
                  sprintf("\n\u2717 Config '%s' REFUSED: %s\n", config_name,
                          result$message %||% result$code %||% "Unknown"))
                failed_configs[[config_name]] <- result

              } else {
                output_text <- paste0(output_text,
                  sprintf("\n\u2713 Config '%s' complete (status: %s)\n",
                          config_name, result$run_status %||% "PASS"))

                analyses[[config_name]] <- list(
                  results = result,
                  config = result$config,
                  label = result$config$outcome_label %||%
                          result$config$analysis_name %||% config_name
                )
              }
            }

            console_text(output_text)
          }  # end config loop

          # =================================================================
          # PHASE 3: Generate unified report (if multi-config, 2+ succeeded)
          # =================================================================
          n_success <- length(analyses)
          n_failed <- length(failed_configs)

          if (is_multi && n_success >= 2) {
            setProgress(value = 0.88, detail = "Generating unified report...")

            output_text <- paste0(output_text,
              sprintf("\n%s\n", paste(rep("=", 50), collapse = "")),
              "  GENERATING UNIFIED REPORT\n",
              sprintf("  %d successful analyses, %d failed\n", n_success, n_failed),
              sprintf("%s\n", paste(rep("=", 50), collapse = "")))
            console_text(output_text)

            # Output path: same directory as first config
            first_dir <- dirname(files$config_files[1])
            unified_filename <- sprintf("CatDriver_Unified_%s.html",
                                         format(Sys.Date(), "%Y%m%d"))
            unified_path <- file.path(first_dir, unified_filename)

            # Get GUI branding settings (with safe defaults)
            gui_brand <- if (is_valid_hex(input$brand_colour)) {
              input$brand_colour
            } else "#323367"
            gui_accent <- if (is_valid_hex(input$accent_colour)) {
              input$accent_colour
            } else "#CC9900"
            gui_title <- if (!is.null(input$report_title) && nzchar(input$report_title)) {
              input$report_title
            } else "Categorical Key Driver Analysis"
            gui_client <- if (!is.null(input$client_name) && nzchar(input$client_name)) {
              input$client_name
            } else NULL
            gui_researcher <- if (!is.null(input$researcher_name) && nzchar(input$researcher_name)) {
              input$researcher_name
            } else NULL

            # Resolve logo file paths from fileInput uploads
            researcher_logo <- NULL
            if (!is.null(input$researcher_logo)) {
              researcher_logo <- input$researcher_logo$datapath
            }
            client_logo <- NULL
            if (!is.null(input$client_logo)) {
              client_logo <- input$client_logo$datapath
            }

            # Generate unified report
            unified_captured <- capture_console_all({
              generate_catdriver_unified_report(
                analyses = analyses,
                output_path = unified_path,
                report_title = gui_title,
                brand_colour = gui_brand,
                accent_colour = gui_accent,
                researcher_logo_path = researcher_logo,
                client_logo_path = client_logo,
                client_name = gui_client,
                company_name = "The Research Lamppost",
                researcher_name = gui_researcher
              )
            })

            output_text <- paste0(output_text,
                                   paste(unified_captured$combined_output, collapse = "\n"))

            if (!unified_captured$has_error) {
              output_text <- paste0(output_text,
                sprintf("\n\n\u2713 Unified report saved: %s\n", unified_filename))
            } else {
              output_text <- paste0(output_text,
                "\n\n\u2717 Unified report generation failed\n")
            }

          } else if (is_multi && n_success < 2) {
            output_text <- paste0(output_text,
              "\n\u26a0 Fewer than 2 analyses succeeded \u2014 unified report skipped\n")
          }

          # =================================================================
          # PHASE 4: Summary
          # =================================================================
          setProgress(value = 0.98, detail = "Finalizing...")

          if (n_failed > 0) {
            output_text <- paste0(output_text, sprintf(
              "\n\n\u26a0 %d/%d config%s completed, %d failed",
              n_success, n_configs,
              if (n_configs != 1) "s" else "", n_failed))
          } else if (n_configs == 1) {
            if (captured$has_error) {
              output_text <- paste0(output_text,
                "\n\n\u2717 Analysis failed - see error above")
            } else if (captured$has_warnings) {
              output_text <- paste0(output_text,
                "\n\n\u26a0 Analysis complete with warnings - review above")
            } else {
              output_text <- paste0(output_text,
                "\n\n\u2713 Analysis complete!")
            }
          } else {
            output_text <- paste0(output_text, sprintf(
              "\n\n\u2713 All %d configs completed successfully!", n_configs))
          }

          setProgress(value = 1, detail = "Done!")

        }, error = function(e) {
          output_text <<- paste0(output_text, "\n\n\u2717 Error: ", e$message)
        })

      })  # End withProgress

      console_text(output_text)
      is_running(FALSE)
    })
  }

  shinyApp(ui = ui, server = server)
}
