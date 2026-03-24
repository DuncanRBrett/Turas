# ==============================================================================
# TURAS SUITE LAUNCHER
# ==============================================================================
# Unified launcher for all Turas modules
# Data-driven architecture with categorized grid and two-step launch flow
# ==============================================================================

library(shiny)
library(shinyjs)

#' Launch Turas Suite Launcher
#'
#' Opens a GUI with categorized module grid and per-module recent projects.
#'
#' @export
launch_turas <- function() {

  # Get Turas root directory (Docker-aware: checks TURAS_ROOT env var first)
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root) || !dir.exists(turas_root)) {
    turas_root <- getwd()
  }

  # Validate: must contain launch_turas.R (the marker file for Turas root)
  if (!file.exists(file.path(turas_root, "launch_turas.R"))) {
    # Try parent directory
    if (file.exists(file.path(dirname(turas_root), "launch_turas.R"))) {
      turas_root <- dirname(turas_root)
    } else {
      cat("\n")
      cat("================================================================================\n")
      cat("  [REFUSE] IO_TURAS_ROOT_NOT_FOUND: Cannot Locate Turas Root Directory\n")
      cat("================================================================================\n\n")
      cat("Problem:\n")
      cat("  Cannot find launch_turas.R in the current or parent directory.\n\n")
      cat("How to fix:\n")
      cat("  1. Set the TURAS_ROOT environment variable: Sys.setenv(TURAS_ROOT = '/path/to/Turas')\n")
      cat("  2. Or run from the Turas directory: setwd('/path/to/Turas')\n")
      cat("  3. For Docker: ensure TURAS_ROOT is set in the container environment\n")
      cat("================================================================================\n\n")
      return(invisible(NULL))
    }
  }

  # Cache for child modules
  Sys.setenv(TURAS_ROOT = turas_root)

  # ============================================================================
  # MODULE REGISTRY
  # ============================================================================

  categories <- list(
    list(id = "setup",    label = "Setup & Data Prep"),
    list(id = "tables",   label = "Tables & Tracking"),
    list(id = "advanced", label = "Advanced Analytics"),
    list(id = "reporting", label = "Reporting")
  )

  modules <- list(
    list(id = "callout_editor", name = "Callout Editor",
         description = "View and edit platform callout text across all report modules",
         category = "setup",
         script = "modules/shared/lib/callouts/run_callout_editor_gui.R",
         recent_file = NULL,
         recent_key = NULL),

    list(id = "alchemerparser", name = "AlchemerParser",
         description = "Parse Alchemer survey exports and generate Tabs configuration files",
         category = "setup",
         script = "modules/AlchemerParser/run_alchemerparser_gui.R",
         recent_file = "modules/AlchemerParser/.recent_alchemerparser_projects.rds",
         recent_key = NULL),

    list(id = "weighting", name = "Weighting",
         description = "Sample and rim weighting with iterative proportional fitting",
         category = "setup",
         script = "modules/weighting/run_weighting_gui.R",
         recent_file = ".turas_weighting_recent_folders.rds",
         recent_key = NULL),

    list(id = "tabs", name = "Tabs",
         description = "Cross-tabulation reports with banner breakouts and statistical tests",
         category = "tables",
         script = "modules/tabs/run_tabs_gui.R",
         recent_file = ".recent_tabs_projects.rds",
         recent_key = NULL),

    list(id = "tracker", name = "Tracker",
         description = "Longitudinal tracking, trend analysis, and wave-over-wave significance",
         category = "tables",
         script = "modules/tracker/run_tracker_gui.R",
         recent_file = ".recent_tracker_projects.rds",
         recent_key = "tracking_config"),

    list(id = "conjoint", name = "Conjoint",
         description = "Choice-based conjoint analysis with Hierarchical Bayes utilities",
         category = "advanced",
         script = "modules/conjoint/run_conjoint_gui.R",
         recent_file = ".recent_conjoint_projects.rds",
         recent_key = "project_dir"),

    list(id = "maxdiff", name = "MaxDiff",
         description = "Best-worst scaling preference analysis with Hierarchical Bayes estimation",
         category = "advanced",
         script = "modules/maxdiff/run_maxdiff_gui.R",
         recent_file = ".recent_maxdiff.rds",
         recent_key = "path"),

    list(id = "pricing", name = "Pricing",
         description = "Price sensitivity using Van Westendorp, Gabor-Granger, and monadic methods",
         category = "advanced",
         script = "modules/pricing/run_pricing_gui.R",
         recent_file = ".recent_pricing_projects.rds",
         recent_key = "project_dir"),

    list(id = "segment", name = "Segment",
         description = "K-means clustering segmentation with automatic variable selection",
         category = "advanced",
         script = "modules/segment/run_segment_gui.R",
         recent_file = ".recent_segment_projects.rds",
         recent_key = NULL),

    list(id = "keydriver", name = "Key Driver",
         description = "Key driver correlation analysis with derived importance scores",
         category = "advanced",
         script = "modules/keydriver/run_keydriver_gui.R",
         recent_file = ".recent_keydriver_projects.rds",
         recent_key = "project_dir"),

    list(id = "catdriver", name = "Categorical Driver",
         description = "Driver analysis for categorical outcomes using logistic regression and SHAP",
         category = "advanced",
         script = "modules/catdriver/run_catdriver_gui.R",
         recent_file = ".recent_catdriver_projects.rds",
         recent_key = "project_dir"),

    list(id = "confidence", name = "Confidence",
         description = "Confidence intervals for means and proportions with design effect adjustments",
         category = "advanced",
         script = "modules/confidence/run_confidence_gui.R",
         recent_file = ".recent_confidence_projects.rds",
         recent_key = NULL),

    list(id = "report_hub", name = "Report Hub",
         description = "Combine Turas HTML reports into a unified portal with cross-referencing",
         category = "reporting",
         script = "modules/report_hub/run_report_hub_gui.R",
         recent_file = ".recent_hub_configs.rds",
         recent_key = NULL),

    list(id = "hub_app", name = "Hub App",
         description = "Browse, annotate, and export across multiple Turas reports",
         category = "reporting",
         script = "modules/hub_app/run_hub_app_gui.R",
         recent_file = NULL,
         recent_key = NULL)
  )

  # ============================================================================
  # SVG ICONS
  # ============================================================================

  icons <- list(
    callout_editor = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>',

    alchemerparser = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="9" y1="15" x2="15" y2="15"/><polyline points="12 18 12 12 9 14"/></svg>',

    weighting = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="3" x2="12" y2="6"/><circle cx="12" cy="6" r="1"/><line x1="4" y1="9" x2="20" y2="9"/><path d="M4 9l-1 7h6l-1-7"/><path d="M20 9l-1 7h-6l1-7"/><line x1="2" y1="20" x2="22" y2="20"/></svg>',

    tabs = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="3" y1="15" x2="21" y2="15"/><line x1="9" y1="3" x2="9" y2="21"/><line x1="15" y1="3" x2="15" y2="21"/></svg>',

    tracker = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>',

    conjoint = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="5" r="2"/><line x1="12" y1="7" x2="12" y2="11"/><line x1="12" y1="11" x2="7" y2="16"/><line x1="12" y1="11" x2="17" y2="16"/><circle cx="7" cy="18" r="2"/><circle cx="17" cy="18" r="2"/></svg>',

    maxdiff = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="18 15 12 9 6 15"/><polyline points="18 20 12 14 6 20"/><line x1="3" y1="4" x2="21" y2="4"/></svg>',

    pricing = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>',

    segment = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="8" cy="8" r="3"/><circle cx="16" cy="16" r="3"/><circle cx="17" cy="7" r="2"/><circle cx="7" cy="17" r="2"/></svg>',

    keydriver = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/></svg>',

    catdriver = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>',

    confidence = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="4" x2="12" y2="20"/><line x1="8" y1="4" x2="16" y2="4"/><line x1="8" y1="20" x2="16" y2="20"/><circle cx="12" cy="12" r="2"/></svg>',

    report_hub = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="8" height="8" rx="1"/><rect x="14" y="3" width="8" height="8" rx="1"/><rect x="2" y="13" width="8" height="8" rx="1"/><rect x="14" y="13" width="8" height="8" rx="1"/><line x1="10" y1="7" x2="14" y2="7"/><line x1="6" y1="11" x2="6" y2="13"/><line x1="18" y1="11" x2="18" y2="13"/></svg>',

    hub_app = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="18" rx="2"/><line x1="2" y1="9" x2="22" y2="9"/><line x1="8" y1="3" x2="8" y2="9"/><line x1="14" y1="3" x2="14" y2="9"/><circle cx="12" cy="15" r="2"/><path d="M8 15h-2"/><path d="M18 15h-2"/></svg>'
  )

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  #' Read recent projects for a module, normalizing different storage formats
  read_module_recents <- function(mod) {
    tryCatch({
      if (is.null(mod$recent_file)) return(character(0))
      rds_path <- if (isTRUE(mod$recent_absolute)) {
        mod$recent_file
      } else {
        file.path(turas_root, mod$recent_file)
      }
      if (!file.exists(rds_path)) return(character(0))

      data <- readRDS(rds_path)
      if (length(data) == 0) return(character(0))

      # Normalize to character vector of paths
      paths <- if (is.character(data)) {
        data
      } else if (is.list(data) && !is.null(mod$recent_key)) {
        sapply(data, function(x) {
          val <- x[[mod$recent_key]]
          if (is.null(val)) NA_character_ else val
        })
      } else {
        character(0)
      }

      paths <- paths[!is.na(paths)]
      paths <- paths[file.exists(paths) | dir.exists(paths)]
      head(paths, 5)
    }, error = function(e) character(0))
  }

  #' Build a module card for the grid
  build_module_card <- function(mod) {
    div(
      class = "module-card",
      onclick = sprintf(
        "Shiny.setInputValue('module_card_click', '%s', {priority: 'event'})",
        mod$id
      ),
      div(class = "card-icon", HTML(icons[[mod$id]])),
      div(class = "card-content",
        div(class = "card-name", mod$name),
        div(class = "card-desc", mod$description)
      )
    )
  }

  #' Build a category section with grid of cards
  build_category_section <- function(cat, all_modules) {
    cat_modules <- Filter(function(m) m$category == cat$id, all_modules)
    if (length(cat_modules) == 0) return(NULL)

    div(class = "category-section",
      div(class = "category-label", cat$label),
      div(class = "category-grid",
        lapply(cat_modules, build_module_card)
      )
    )
  }

  # ============================================================================
  # UI
  # ============================================================================

  ui <- fluidPage(
    useShinyjs(),

    tags$head(tags$style(HTML("
      :root {
        --tl-text: #1e293b;
        --tl-text-muted: #64748b;
        --tl-text-faint: #94a3b8;
        --tl-bg: #f8f7f5;
        --tl-surface: #ffffff;
        --tl-border: #e2e8f0;
        --tl-border-hover: #94a3b8;
        --tl-accent: #1a2744;
        --tl-font: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      }
      body {
        background: var(--tl-bg);
        font-family: var(--tl-font);
        margin: 0;
        padding: 0;
      }
      .container-fluid { padding: 0; }

      /* Header */
      .launcher-header {
        background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
        padding: 16px 32px;
        color: #fff;
      }
      .launcher-header-inner {
        max-width: 1100px;
        margin: 0 auto;
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      .launcher-title {
        font-size: 20px;
        font-weight: 700;
        letter-spacing: 0.5px;
      }
      .launcher-meta {
        font-size: 12px;
        color: rgba(255,255,255,0.55);
      }
      .launcher-version { margin-right: 16px; }

      /* Content area */
      .launcher-content {
        max-width: 1100px;
        margin: 0 auto;
        padding: 32px 32px 80px 32px;
      }

      /* Category sections */
      .category-section { margin-bottom: 28px; }
      .category-label {
        font-size: 11px;
        font-weight: 600;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: var(--tl-text-faint);
        margin-bottom: 10px;
        padding-left: 2px;
      }
      .category-grid {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 10px;
      }
      @media (max-width: 900px) {
        .category-grid { grid-template-columns: repeat(2, 1fr); }
      }
      @media (max-width: 600px) {
        .category-grid { grid-template-columns: 1fr; }
      }

      /* Module cards */
      .module-card {
        background: var(--tl-surface);
        border: 1px solid var(--tl-border);
        border-radius: 8px;
        padding: 18px;
        cursor: pointer;
        transition: border-color 0.15s, box-shadow 0.15s;
        display: flex;
        align-items: flex-start;
        gap: 14px;
      }
      .module-card:hover {
        border-color: var(--tl-border-hover);
        box-shadow: 0 2px 8px rgba(0,0,0,0.06);
      }
      .module-card:active { background: #f8f9fa; }
      .card-icon {
        color: var(--tl-text-muted);
        flex-shrink: 0;
        margin-top: 2px;
      }
      .card-name {
        font-size: 15px;
        font-weight: 600;
        color: var(--tl-text);
        margin-bottom: 4px;
      }
      .card-desc {
        font-size: 12.5px;
        color: var(--tl-text-muted);
        line-height: 1.45;
      }

      /* Detail panel */
      .detail-panel {
        max-width: 600px;
        margin: 0 auto;
      }
      .detail-back {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        font-size: 13px;
        font-weight: 500;
        color: var(--tl-text-muted);
        cursor: pointer;
        padding: 6px 0;
        margin-bottom: 20px;
        border: none;
        background: none;
      }
      .detail-back:hover { color: var(--tl-text); }
      .detail-header {
        display: flex;
        align-items: flex-start;
        gap: 16px;
        margin-bottom: 24px;
      }
      .detail-header .card-icon {
        color: var(--tl-text-muted);
        flex-shrink: 0;
      }
      .detail-header .card-icon svg {
        width: 36px;
        height: 36px;
      }
      .detail-name {
        font-size: 24px;
        font-weight: 700;
        color: var(--tl-text);
        margin-bottom: 6px;
      }
      .detail-desc {
        font-size: 14px;
        color: var(--tl-text-muted);
        line-height: 1.5;
      }

      /* Recent projects list */
      .recent-section-label {
        font-size: 11px;
        font-weight: 600;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: var(--tl-text-faint);
        margin-bottom: 8px;
      }
      .recent-item {
        background: var(--tl-surface);
        border: 1px solid var(--tl-border);
        border-radius: 6px;
        padding: 12px 16px;
        margin-bottom: 6px;
        cursor: pointer;
        transition: border-color 0.15s, box-shadow 0.15s;
      }
      .recent-item:hover {
        border-color: var(--tl-border-hover);
        box-shadow: 0 1px 4px rgba(0,0,0,0.06);
      }
      .recent-item:active { background: #f8f9fa; }
      .recent-name {
        font-size: 13.5px;
        font-weight: 600;
        color: var(--tl-text);
        margin-bottom: 2px;
      }
      .recent-path {
        font-size: 11.5px;
        color: var(--tl-text-faint);
      }

      /* Divider */
      .launch-divider {
        display: flex;
        align-items: center;
        margin: 20px 0;
        color: var(--tl-text-faint);
        font-size: 12px;
      }
      .launch-divider::before, .launch-divider::after {
        content: '';
        flex: 1;
        height: 1px;
        background: var(--tl-border);
      }
      .launch-divider::before { margin-right: 12px; }
      .launch-divider::after { margin-left: 12px; }

      /* Launch button */
      .launch-new-btn {
        display: block;
        width: 100%;
        padding: 12px;
        font-size: 14px;
        font-weight: 600;
        color: var(--tl-text-muted);
        background: var(--tl-surface);
        border: 1px solid var(--tl-border);
        border-radius: 6px;
        cursor: pointer;
        text-align: center;
        transition: border-color 0.15s, color 0.15s;
      }
      .launch-new-btn:hover {
        border-color: var(--tl-border-hover);
        color: var(--tl-text);
      }

      /* Status bar */
      .status-bar {
        position: fixed;
        bottom: 0;
        left: 0;
        right: 0;
        padding: 10px 32px;
        background: var(--tl-accent);
        color: #e2e8f0;
        font-size: 13px;
        font-weight: 500;
        text-align: center;
        transform: translateY(100%);
        transition: transform 0.2s ease;
        z-index: 100;
      }
      .status-bar.visible { transform: translateY(0); }

      /* Footer */
      .launcher-footer {
        text-align: center;
        padding: 16px 0;
        color: var(--tl-text-faint);
        font-size: 11px;
      }

      /* No recents message */
      .no-recents {
        color: var(--tl-text-faint);
        font-size: 13px;
        padding: 16px 0;
      }
    "))),

    # Header
    div(class = "launcher-header",
      div(class = "launcher-header-inner",
        span(class = "launcher-title", "TURAS SUITE"),
        div(class = "launcher-meta",
          span(class = "launcher-version", "v10.0"),
          span(turas_root)
        )
      )
    ),

    # Content
    div(class = "launcher-content",

      # Grid view
      div(id = "grid_view",
        lapply(categories, build_category_section, all_modules = modules),
        div(class = "launcher-footer",
          paste0("Turas Suite v10.0")
        )
      ),

      # Detail view (hidden by default)
      hidden(div(id = "detail_view",
        uiOutput("module_detail")
      ))
    ),

    # Status bar
    div(id = "status_bar", class = "status-bar",
      textOutput("status_text", inline = TRUE)
    )
  )

  # ============================================================================
  # SERVER
  # ============================================================================

  server <- function(input, output, session) {

    rv <- reactiveValues(
      selected_module = NULL,
      status = ""
    )

    # Status bar text
    output$status_text <- renderText({ rv$status })

    show_status <- function(msg) {
      rv$status <- msg
      tryCatch(
        shinyjs::addClass(id = "status_bar", class = "visible"),
        error = function(e) NULL
      )
    }

    hide_status <- function() {
      tryCatch(
        shinyjs::removeClass(id = "status_bar", class = "visible"),
        error = function(e) NULL
      )
      rv$status <- ""
    }

    # ------------------------------------------------------------------
    # Card click -> show detail panel
    # ------------------------------------------------------------------
    observeEvent(input$module_card_click, {
      mod_id <- input$module_card_click
      mod <- Find(function(m) m$id == mod_id, modules)
      if (is.null(mod)) return()

      rv$selected_module <- mod

      shinyjs::hide("grid_view")
      shinyjs::show("detail_view")
    })

    # ------------------------------------------------------------------
    # Back button -> return to grid
    # ------------------------------------------------------------------
    observeEvent(input$detail_back, {
      shinyjs::hide("detail_view")
      shinyjs::show("grid_view")
      rv$selected_module <- NULL
    })

    # ------------------------------------------------------------------
    # Render detail panel
    # ------------------------------------------------------------------
    output$module_detail <- renderUI({
      mod <- rv$selected_module
      if (is.null(mod)) return(NULL)

      recents <- read_module_recents(mod)
      icon_svg <- icons[[mod$id]]
      # Make icon larger for detail view
      icon_large <- gsub('width="28" height="28"', 'width="36" height="36"', icon_svg)

      tagList(
        div(class = "detail-panel",

          # Back button
          tags$button(
            class = "detail-back",
            onclick = "Shiny.setInputValue('detail_back', Math.random(), {priority: 'event'})",
            HTML('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>'),
            "Back"
          ),

          # Module header
          div(class = "detail-header",
            div(class = "card-icon", HTML(icon_large)),
            div(
              div(class = "detail-name", mod$name),
              div(class = "detail-desc", mod$description)
            )
          ),

          # Recent projects
          if (length(recents) > 0) {
            tagList(
              div(class = "recent-section-label", "Recent Projects"),
              lapply(seq_along(recents), function(i) {
                config_path <- recents[i]
                div(
                  class = "recent-item",
                  onclick = sprintf(
                    "Shiny.setInputValue('launch_with_config', {mod_id: %s, config: %s}, {priority: 'event'})",
                    jsonlite::toJSON(mod$id, auto_unbox = TRUE),
                    jsonlite::toJSON(config_path, auto_unbox = TRUE)
                  ),
                  div(class = "recent-name", basename(config_path)),
                  div(class = "recent-path", dirname(config_path))
                )
              }),
              div(class = "launch-divider", "or")
            )
          } else {
            div(class = "no-recents", "No recent projects")
          },

          # Launch fresh button
          tags$button(
            class = "launch-new-btn",
            onclick = sprintf(
              "Shiny.setInputValue('launch_fresh', '%s', {priority: 'event'})",
              mod$id
            ),
            "Launch New Session"
          )
        )
      )
    })

    # ------------------------------------------------------------------
    # Launch module fresh (no config)
    # ------------------------------------------------------------------
    observeEvent(input$launch_fresh, {
      mod_id <- input$launch_fresh
      mod <- Find(function(m) m$id == mod_id, modules)
      if (is.null(mod)) return()

      script_file <- file.path(turas_root, mod$script)
      if (!file.exists(script_file)) {
        show_status(paste0("Error: Module script not found: ", mod$script))
        later::later(function() {
          tryCatch(hide_status(), error = function(e) NULL)
        }, delay = 5)
        return()
      }

      show_status(paste0("Launching ", mod$name, "..."))

      tryCatch({
        launch_module(mod$id, script_file)

        later::later(function() {
          tryCatch(show_status(paste0(mod$name, " launched")), error = function(e) NULL)
        }, delay = 1)
        later::later(function() {
          tryCatch(hide_status(), error = function(e) NULL)
        }, delay = 4)
      }, error = function(e) {
        show_status(paste("Error:", e$message))
      })
    })

    # ------------------------------------------------------------------
    # Launch module with pre-loaded config
    # ------------------------------------------------------------------
    observeEvent(input$launch_with_config, {
      data <- input$launch_with_config
      mod_id <- data$mod_id
      config_path <- data$config
      mod <- Find(function(m) m$id == mod_id, modules)
      if (is.null(mod)) return()

      if (!file.exists(config_path) && !dir.exists(config_path)) {
        show_status("Project path no longer exists")
        later::later(function() {
          tryCatch(hide_status(), error = function(e) NULL)
        }, delay = 4)
        return()
      }

      show_status(paste0("Launching ", mod$name, " with ", basename(config_path), "..."))

      tryCatch({
        # Pass config path directly into the launched script (no env var race condition)
        launch_module(mod$id,
                     file.path(turas_root, mod$script),
                     config_path = config_path)

        later::later(function() {
          tryCatch(show_status(paste0(mod$name, " launched")), error = function(e) NULL)
        }, delay = 1)
        later::later(function() {
          tryCatch(hide_status(), error = function(e) NULL)
        }, delay = 4)
      }, error = function(e) {
        show_status(paste("Error:", e$message))
      })
    })

    # ------------------------------------------------------------------
    # launch_module() — background Rscript launcher
    # ------------------------------------------------------------------
    launch_module <- function(module_name, script_path, config_path = NULL) {
      config_lines <- ""
      if (!is.null(config_path) && nzchar(config_path)) {
        config_lines <- sprintf('Sys.setenv(TURAS_MODULE_CONFIG = "%s")\n', config_path)
        if (module_name == "report_hub") {
          config_lines <- paste0(config_lines, sprintf('Sys.setenv(TURAS_HUB_CONFIG = "%s")\n', config_path))
        }
      }
      launch_script <- sprintf('
Sys.setenv(TURAS_ROOT = "%s")
Sys.setenv(TURAS_LAUNCHED_FROM_HUB = "1")
%ssetwd("%s")
TURAS_LAUNCHER_ACTIVE <- TRUE
source("%s")
if ("%s" != "alchemerparser") {
  app <- %s()
  shiny::runApp(app, launch.browser = TRUE)
}
',
      turas_root,
      config_lines,
      turas_root,
      script_path,
      module_name,
      paste0("run_", module_name, "_gui"))

      temp_script <- tempfile(fileext = ".R")
      log_file <- tempfile(fileext = ".log")

      launch_script_wrapped <- paste0(
        'tryCatch({\n',
        launch_script,
        '}, error = function(e) {\n',
        '  cat("ERROR:", conditionMessage(e), "\\n", file = "', log_file, '")\n',
        '})\n'
      )

      writeLines(launch_script_wrapped, temp_script)

      old_env <- Sys.getenv("TURAS_SKIP_RENV")
      Sys.setenv(TURAS_SKIP_RENV = "1")

      system2("Rscript",
              args = c(temp_script),
              wait = FALSE,
              stdout = log_file,
              stderr = log_file)

      if (old_env == "") {
        Sys.unsetenv("TURAS_SKIP_RENV")
      } else {
        Sys.setenv(TURAS_SKIP_RENV = old_env)
      }

      later::later(function() {
        tryCatch({
          if (file.exists(log_file)) {
            log_content <- readLines(log_file, warn = FALSE)
            if (length(log_content) > 0 && any(grepl("ERROR|error", log_content, ignore.case = TRUE))) {
              show_status(paste("Launch error:", paste(log_content, collapse = " ")))
            }
            unlink(log_file)
          }
          if (file.exists(temp_script)) unlink(temp_script)
        }, error = function(e) NULL)
      }, delay = 5)
    }
  }

  # Run the launcher
  runApp(list(ui = ui, server = server),
         launch.browser = TRUE,
         quiet = TRUE)
}


# ==============================================================================
# Auto-run when sourced
# ==============================================================================
launch_turas()
