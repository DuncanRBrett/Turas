# ==============================================================================
# TURAS SUITE LAUNCHER
# ==============================================================================
# Unified launcher for all Turas modules
# ==============================================================================

library(shiny)

#' Launch Turas Suite Launcher
#'
#' Opens a GUI with options to launch Parser, Tabs, or Tracker modules.
#'
#' @export
launch_turas <- function() {

  # Get Turas root directory
  turas_root <- getwd()
  if (basename(turas_root) != "Turas") {
    # Try to detect if we're in a subdirectory
    if (file.exists(file.path(dirname(turas_root), "launch_turas.R"))) {
      turas_root <- dirname(turas_root)
    } else {
      stop("Please run from Turas directory or set working directory to Turas root")
    }
  }

  ui <- fluidPage(

    # Custom CSS
    tags$head(
      tags$style(HTML("
        body {
          background-color: #f5f5f5;
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        .main-container {
          max-width: 800px;
          margin: 50px auto;
          padding: 40px;
          background-color: white;
          border-radius: 10px;
          box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .title-section {
          text-align: center;
          margin-bottom: 40px;
          padding-bottom: 20px;
          border-bottom: 2px solid #e0e0e0;
        }
        .title-section h1 {
          color: #2c3e50;
          font-size: 36px;
          margin-bottom: 10px;
        }
        .title-section p {
          color: #7f8c8d;
          font-size: 16px;
        }
        .module-section {
          margin: 30px 0;
        }
        .module-card {
          background-color: #f8f9fa;
          border: 1px solid #dee2e6;
          border-radius: 8px;
          padding: 20px;
          margin-bottom: 20px;
          transition: transform 0.2s, box-shadow 0.2s;
        }
        .module-card:hover {
          transform: translateY(-2px);
          box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        .module-title {
          font-size: 22px;
          font-weight: bold;
          color: #2c3e50;
          margin-bottom: 10px;
        }
        .module-description {
          color: #6c757d;
          font-size: 14px;
          margin-bottom: 15px;
          line-height: 1.5;
        }
        .launch-btn {
          width: 100%;
          padding: 12px;
          font-size: 16px;
          font-weight: 600;
          border: none;
          border-radius: 6px;
          cursor: pointer;
          transition: background-color 0.2s;
        }
        .btn-alchemerparser {
          background-color: #16a085;
          color: white;
        }
        .btn-alchemerparser:hover {
          background-color: #138d75;
        }
        .btn-tabs {
          background-color: #2ecc71;
          color: white;
        }
        .btn-tabs:hover {
          background-color: #27ae60;
        }
        .btn-tracker {
          background-color: #e74c3c;
          color: white;
        }
        .btn-tracker:hover {
          background-color: #c0392b;
        }
        .btn-confidence {
          background-color: #f59e0b;
          color: white;
        }
        .btn-confidence:hover {
          background-color: #d97706;
        }
        .btn-segment {
          background-color: #9b59b6;
          color: white;
        }
        .btn-segment:hover {
          background-color: #8e44ad;
        }
        .btn-conjoint {
          background-color: #06b6d4;
          color: white;
        }
        .btn-conjoint:hover {
          background-color: #0891b2;
        }
        .btn-keydriver {
          background-color: #ec4899;
          color: white;
        }
        .btn-keydriver:hover {
          background-color: #db2777;
        }
        .btn-pricing {
          background-color: #10b981;
          color: white;
        }
        .btn-pricing:hover {
          background-color: #059669;
        }
        .btn-maxdiff {
          background-color: #8b5cf6;
          color: white;
        }
        .btn-maxdiff:hover {
          background-color: #7c3aed;
        }
        .btn-catdriver {
          background-color: #6366f1;
          color: white;
        }
        .btn-catdriver:hover {
          background-color: #4f46e5;
        }
        .btn-weighting {
          background-color: #0ea5e9;
          color: white;
        }
        .btn-weighting:hover {
          background-color: #0284c7;
        }
        .status-message {
          margin-top: 20px;
          padding: 15px;
          border-radius: 6px;
          text-align: center;
          font-weight: 500;
        }
        .status-success {
          background-color: #d4edda;
          color: #155724;
          border: 1px solid #c3e6cb;
        }
        .status-info {
          background-color: #d1ecf1;
          color: #0c5460;
          border: 1px solid #bee5eb;
        }
        .footer {
          text-align: center;
          margin-top: 40px;
          padding-top: 20px;
          border-top: 1px solid #e0e0e0;
          color: #95a5a6;
          font-size: 12px;
        }
      "))
    ),

    div(class = "main-container",

      # Title
      div(class = "title-section",
        h1("TURAS SUITE"),
        p("Select a module to launch")
      ),

      # Module Cards
      div(class = "module-section",

        # AlchemerParser
        div(class = "module-card",
          div(class = "module-title", "🔄 AlchemerParser"),
          div(class = "module-description",
            "Parse Alchemer survey files and generate Tabs configuration. Converts questionnaire, data export map, and translation files into ready-to-use Tabs inputs."
          ),
          actionButton("launch_alchemerparser", "Launch AlchemerParser",
                      class = "launch-btn btn-alchemerparser")
        ),

        # Tabs
        div(class = "module-card",
          div(class = "module-title", "📈 Tabs"),
          div(class = "module-description",
            "Generate cross-tabulation reports. Create formatted Excel outputs with banner breakouts and statistical tests."
          ),
          actionButton("launch_tabs", "Launch Tabs",
                      class = "launch-btn btn-tabs")
        ),

        # Tracker
        div(class = "module-card",
          div(class = "module-title", "📉 Tracker"),
          div(class = "module-description",
            "Track metrics across survey waves. Analyze trends, calculate wave-over-wave changes, and test significance."
          ),
          actionButton("launch_tracker", "Launch Tracker",
                      class = "launch-btn btn-tracker")
        ),

        # Confidence
        div(class = "module-card",
          div(class = "module-title", "📊 Confidence"),
          div(class = "module-description",
            "Calculate statistical confidence intervals for means and proportions. Supports Bootstrap, Bayesian, and Wilson methods with design effect adjustments."
          ),
          actionButton("launch_confidence", "Launch Confidence",
                      class = "launch-btn btn-confidence")
        ),

        # Segment
        div(class = "module-card",
          div(class = "module-title", "🎯 Segment"),
          div(class = "module-description",
            "K-means clustering segmentation. Automatically select optimal variables, detect outliers, and create meaningful respondent segments."
          ),
          actionButton("launch_segment", "Launch Segment",
                      class = "launch-btn btn-segment")
        ),

        # Conjoint
        div(class = "module-card",
          div(class = "module-title", "🔄 Conjoint"),
          div(class = "module-description",
            "Choice-based conjoint analysis. Calculate part-worth utilities and attribute importance from experimental choice data."
          ),
          actionButton("launch_conjoint", "Launch Conjoint",
                      class = "launch-btn btn-conjoint")
        ),

        # Key Driver
        div(class = "module-card",
          div(class = "module-title", "🔑 Key Driver"),
          div(class = "module-description",
            "Key driver analysis using multiple regression methods. Identify which factors most influence your target outcome with derived importance scores."
          ),
          actionButton("launch_keydriver", "Launch Key Driver",
                      class = "launch-btn btn-keydriver")
        ),

        # Pricing
        div(class = "module-card",
          div(class = "module-title", "💰 Pricing"),
          div(class = "module-description",
            "Pricing research analysis using Van Westendorp PSM and Gabor-Granger methods. Determine optimal price points and acceptable price ranges."
          ),
          actionButton("launch_pricing", "Launch Pricing",
                      class = "launch-btn btn-pricing")
        ),

        # MaxDiff
        div(class = "module-card",
          div(class = "module-title", "⚖️ MaxDiff"),
          div(class = "module-description",
            "Best-Worst Scaling (MaxDiff) design and analysis. Generate optimal experimental designs and compute preference utilities using count scores, logit models, and Hierarchical Bayes estimation."
          ),
          actionButton("launch_maxdiff", "Launch MaxDiff",
                      class = "launch-btn btn-maxdiff")
        ),

        # Categorical Key Driver
        div(class = "module-card",
          div(class = "module-title", "📋 Categorical Key Driver"),
          div(class = "module-description",
            "Key driver analysis for categorical outcomes. Identify what drives binary, ordinal, or nominal outcomes using logistic regression with variable importance scores and odds ratios."
          ),
          actionButton("launch_catdriver", "Launch Categorical Key Driver",
                      class = "launch-btn btn-catdriver")
        ),

        # Weighting
        div(class = "module-card",
          div(class = "module-title", "⚖️ Weighting"),
          div(class = "module-description",
            "Calculate survey weights using design or rim weighting methods. Adjust for stratified samples or match demographic targets with iterative proportional fitting (raking)."
          ),
          actionButton("launch_weighting", "Launch Weighting",
                      class = "launch-btn btn-weighting")
        )
      ),

      # Status message
      uiOutput("status_message"),

      # Footer
      div(class = "footer",
        paste0("Turas Suite v10.0 | ", turas_root)
      )
    )
  )

  server <- function(input, output, session) {

    # Status message
    status <- reactiveVal("")

    output$status_message <- renderUI({
      if (status() != "") {
        div(class = "status-message status-info", status())
      }
    })

    # Helper function to launch modules in background
    launch_module <- function(module_name, script_path) {
      # Standard launch for all modules
      # Set TURAS_LAUNCHER_ACTIVE to prevent auto-run in GUI files
      # IMPORTANT: TURAS_SKIP_RENV must be set as env var BEFORE Rscript starts,
      # so .Rprofile sees it and skips renv activation (saves ~9 seconds)
      launch_script <- sprintf('
Sys.setenv(TURAS_ROOT = "%s")
setwd("%s")
TURAS_LAUNCHER_ACTIVE <- TRUE
source("%s")
if ("%s" != "alchemerparser") {
  app <- %s()
  shiny::runApp(app, launch.browser = TRUE)
}
',
      turas_root,
      turas_root,
      script_path,
      module_name,
      paste0("run_", module_name, "_gui"))

      # Write temporary launch script with error handling
      temp_script <- tempfile(fileext = ".R")
      log_file <- tempfile(fileext = ".log")

      # Wrap the script with error handling
      launch_script_wrapped <- paste0(
        'tryCatch({\n',
        launch_script,
        '}, error = function(e) {\n',
        '  cat("ERROR:", conditionMessage(e), "\\n", file = "', log_file, '")\n',
        '})\n'
      )

      writeLines(launch_script_wrapped, temp_script)

      # Set TURAS_SKIP_RENV before launching so .Rprofile skips renv activation
      # This is critical for fast GUI loading (~2s vs ~15s)
      old_env <- Sys.getenv("TURAS_SKIP_RENV")
      Sys.setenv(TURAS_SKIP_RENV = "1")

      # Launch in background process (inherits environment with TURAS_SKIP_RENV=1)
      system2("Rscript",
              args = c(temp_script),
              wait = FALSE,
              stdout = log_file,
              stderr = log_file)

      # Restore original env (though it doesn't matter much for parent process)
      if (old_env == "") {
        Sys.unsetenv("TURAS_SKIP_RENV")
      } else {
        Sys.setenv(TURAS_SKIP_RENV = old_env)
      }

      # Check for errors after a delay
      later::later(function() {
        if (file.exists(log_file)) {
          log_content <- readLines(log_file, warn = FALSE)
          if (length(log_content) > 0 && any(grepl("ERROR|error", log_content, ignore.case = TRUE))) {
            status(paste("Launch error:", paste(log_content, collapse = " ")))
          }
          unlink(log_file)
        }
        if (file.exists(temp_script)) unlink(temp_script)
      }, delay = 5)
    }

    # Launch AlchemerParser
    observeEvent(input$launch_alchemerparser, {
      status("Launching AlchemerParser in new tab...")

      tryCatch({
        launch_module("alchemerparser",
                     file.path(turas_root, "modules/AlchemerParser/run_alchemerparser_gui.R"))

        # Update status after short delay
        later::later(function() {
          status("AlchemerParser launched successfully!")
        }, delay = 1)

        # Clear status after a few seconds
        later::later(function() {
          status("")
        }, delay = 4)

      }, error = function(e) {
        status(paste("Error launching AlchemerParser:", e$message))
      })
    })

    # Launch Tabs
    observeEvent(input$launch_tabs, {
      status("Launching Tabs in new tab...")

      tryCatch({
        launch_module("tabs",
                     file.path(turas_root, "modules/tabs/run_tabs_gui.R"))

        later::later(function() {
          status("Tabs launched successfully!")
        }, delay = 1)

        later::later(function() {
          status("")
        }, delay = 4)

      }, error = function(e) {
        status(paste("Error launching Tabs:", e$message))
      })
    })

    # Launch Tracker
    observeEvent(input$launch_tracker, {
      status("Launching Tracker in new tab...")

      tryCatch({
        launch_module("tracker",
                     file.path(turas_root, "modules/tracker/run_tracker_gui.R"))

        later::later(function() {
          status("Tracker launched successfully!")
        }, delay = 1)

        later::later(function() {
          status("")
        }, delay = 4)

      }, error = function(e) {
        status(paste("Error launching Tracker:", e$message))
      })
    })

    # Launch Confidence
    observeEvent(input$launch_confidence, {
      status("Launching Confidence in new tab...")

      tryCatch({
        launch_module("confidence",
                     file.path(turas_root, "modules/confidence/run_confidence_gui.R"))

        later::later(function() {
          status("Confidence launched successfully!")
        }, delay = 1)

        later::later(function() {
          status("")
        }, delay = 4)

      }, error = function(e) {
        status(paste("Error launching Confidence:", e$message))
      })
    })

    # Launch Segment
    observeEvent(input$launch_segment, {
      status("Launching Segment in new tab...")

      tryCatch({
        launch_module("segment",
                     file.path(turas_root, "modules/segment/run_segment_gui.R"))

        later::later(function() {
          status("Segment launched successfully!")
        }, delay = 1)

        later::later(function() {
          status("")
        }, delay = 4)

      }, error = function(e) {
        status(paste("Error launching Segment:", e$message))
      })
    })

    # Launch Conjoint
    observeEvent(input$launch_conjoint, {
      status("Launching Conjoint in new tab...")

      tryCatch({
        launch_module("conjoint",
                     file.path(turas_root, "modules/conjoint/run_conjoint_gui.R"))

        later::later(function() {
          status("Conjoint launched successfully!")
        }, delay = 1)

        later::later(function() {
          status("")
        }, delay = 4)

      }, error = function(e) {
        status(paste("Error launching Conjoint:", e$message))
      })
    })

    # Launch Key Driver
    observeEvent(input$launch_keydriver, {
      status("Launching Key Driver in new tab...")

      tryCatch({
        launch_module("keydriver",
                     file.path(turas_root, "modules/keydriver/run_keydriver_gui.R"))

        later::later(function() {
          status("Key Driver launched successfully!")
        }, delay = 1)

        later::later(function() {
          status("")
        }, delay = 4)

      }, error = function(e) {
        status(paste("Error launching Key Driver:", e$message))
      })
    })

    # Launch Pricing
    observeEvent(input$launch_pricing, {
      status("Launching Pricing in new tab...")

      tryCatch({
        launch_module("pricing",
                     file.path(turas_root, "modules/pricing/run_pricing_gui.R"))

        later::later(function() {
          status("Pricing launched successfully!")
        }, delay = 1)

        later::later(function() {
          status("")
        }, delay = 4)

      }, error = function(e) {
        status(paste("Error launching Pricing:", e$message))
      })
    })

    # Launch MaxDiff
    observeEvent(input$launch_maxdiff, {
      status("Launching MaxDiff in new tab...")

      tryCatch({
        launch_module("maxdiff",
                     file.path(turas_root, "modules/maxdiff/run_maxdiff_gui.R"))

        later::later(function() {
          status("MaxDiff launched successfully!")
        }, delay = 1)

        later::later(function() {
          status("")
        }, delay = 4)

      }, error = function(e) {
        status(paste("Error launching MaxDiff:", e$message))
      })
    })

    # Launch Categorical Key Driver
    observeEvent(input$launch_catdriver, {
      status("Launching Categorical Key Driver in new tab...")

      tryCatch({
        launch_module("catdriver",
                     file.path(turas_root, "modules/catdriver/run_catdriver_gui.R"))

        later::later(function() {
          status("Categorical Key Driver launched successfully!")
        }, delay = 1)

        later::later(function() {
          status("")
        }, delay = 4)

      }, error = function(e) {
        status(paste("Error launching Categorical Key Driver:", e$message))
      })
    })

    # Launch Weighting
    observeEvent(input$launch_weighting, {
      status("Launching Weighting in new tab...")

      tryCatch({
        launch_module("weighting",
                     file.path(turas_root, "modules/weighting/run_weighting_gui.R"))

        later::later(function() {
          status("Weighting launched successfully!")
        }, delay = 1)

        later::later(function() {
          status("")
        }, delay = 4)

      }, error = function(e) {
        status(paste("Error launching Weighting:", e$message))
      })
    })
  }

  # Run the launcher app (stays open while modules launch in background)
  runApp(list(ui = ui, server = server),
         launch.browser = TRUE,
         quiet = TRUE)
}


# ==============================================================================
# Auto-run when sourced
# ==============================================================================
# Automatically launch the GUI when this file is sourced
launch_turas()
