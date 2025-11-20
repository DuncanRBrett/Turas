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
        )
      ),

      # Status message
      uiOutput("status_message"),

      # Footer
      div(class = "footer",
        paste0("Turas Suite v1.0 | ", turas_root)
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

    # Store selected module
    selected_module <- reactiveVal(NULL)

    # Launch AlchemerParser
    observeEvent(input$launch_alchemerparser, {
      showModal(modalDialog(
        title = "Launching AlchemerParser",
        "Closing launcher and starting AlchemerParser...",
        footer = NULL
      ))

      # Small delay to show message
      Sys.sleep(0.5)
      stopApp(returnValue = "alchemerparser")
    })

    # Launch Tabs
    observeEvent(input$launch_tabs, {
      showModal(modalDialog(
        title = "Launching Tabs",
        "Closing launcher and starting Tabs...",
        footer = NULL
      ))

      # Small delay to show message
      Sys.sleep(0.5)
      stopApp(returnValue = "tabs")
    })

    # Launch Tracker
    observeEvent(input$launch_tracker, {
      showModal(modalDialog(
        title = "Launching Tracker",
        "Closing launcher and starting Tracker...",
        footer = NULL
      ))

      # Small delay to show message
      Sys.sleep(0.5)
      stopApp(returnValue = "tracker")
    })

    # Launch Confidence
    observeEvent(input$launch_confidence, {
      showModal(modalDialog(
        title = "Launching Confidence",
        "Closing launcher and starting Confidence...",
        footer = NULL
      ))

      # Small delay to show message
      Sys.sleep(0.5)
      stopApp(returnValue = "confidence")
    })

    # Launch Segment
    observeEvent(input$launch_segment, {
      showModal(modalDialog(
        title = "Launching Segment",
        "Closing launcher and starting Segment...",
        footer = NULL
      ))

      # Small delay to show message
      Sys.sleep(0.5)
      stopApp(returnValue = "segment")
    })

    # Launch Conjoint
    observeEvent(input$launch_conjoint, {
      showModal(modalDialog(
        title = "Launching Conjoint",
        "Closing launcher and starting Conjoint...",
        footer = NULL
      ))

      # Small delay to show message
      Sys.sleep(0.5)
      stopApp(returnValue = "conjoint")
    })

    # Launch Key Driver
    observeEvent(input$launch_keydriver, {
      showModal(modalDialog(
        title = "Launching Key Driver",
        "Closing launcher and starting Key Driver...",
        footer = NULL
      ))

      # Small delay to show message
      Sys.sleep(0.5)
      stopApp(returnValue = "keydriver")
    })

    # Launch Pricing
    observeEvent(input$launch_pricing, {
      showModal(modalDialog(
        title = "Launching Pricing",
        "Closing launcher and starting Pricing...",
        footer = NULL
      ))

      # Small delay to show message
      Sys.sleep(0.5)
      stopApp(returnValue = "pricing")
    })
  }

  # Run the app and get selection
  selected <- runApp(list(ui = ui, server = server),
                     launch.browser = TRUE,
                     quiet = TRUE)

  # Launch the selected module
  if (!is.null(selected)) {
    cat("\n")
    cat("==============================================================================\n")
    cat("  LAUNCHING", toupper(selected), "\n")
    cat("==============================================================================\n\n")

    # Ensure we're in the Turas root directory
    setwd(turas_root)

    # Give browser time to close previous app
    Sys.sleep(0.5)

    if (selected == "alchemerparser") {
      cat("Loading AlchemerParser module...\n\n")
      source(file.path(turas_root, "modules/AlchemerParser/run_alchemerparser_gui.R"))

      # run_alchemerparser_gui() returns a shinyApp object, we need to run it
      tryCatch({
        app <- run_alchemerparser_gui()
        runApp(app, launch.browser = TRUE)
      }, error = function(e) {
        cat("\nError launching AlchemerParser:\n")
        cat(e$message, "\n")
      })

    } else if (selected == "tabs") {
      cat("Loading Tabs module...\n\n")
      source(file.path(turas_root, "modules/tabs/run_tabs_gui.R"))

      # run_tabs_gui() returns a shinyApp object, we need to run it
      tryCatch({
        app <- run_tabs_gui()
        runApp(app, launch.browser = TRUE)
      }, error = function(e) {
        cat("\nError launching Tabs:\n")
        cat(e$message, "\n")
      })

    } else if (selected == "tracker") {
      cat("Loading Tracker module...\n\n")
      source(file.path(turas_root, "modules/tracker/run_tracker_gui.R"))

      # run_tracker_gui() returns a shinyApp object, we need to run it
      tryCatch({
        app <- run_tracker_gui()
        runApp(app, launch.browser = TRUE)
      }, error = function(e) {
        cat("\nError launching Tracker:\n")
        cat(e$message, "\n")
      })

    } else if (selected == "confidence") {
      cat("Loading Confidence module...\n\n")
      source(file.path(turas_root, "modules/confidence/run_confidence_gui.R"))

      # run_confidence_gui() returns a shinyApp object, we need to run it
      tryCatch({
        app <- run_confidence_gui()
        runApp(app, launch.browser = TRUE)
      }, error = function(e) {
        cat("\nError launching Confidence:\n")
        cat(e$message, "\n")
      })

    } else if (selected == "segment") {
      cat("Loading Segment module...\n\n")
      source(file.path(turas_root, "modules/segment/run_segment_gui.R"))

      # run_segment_gui() returns a shinyApp object, we need to run it
      tryCatch({
        app <- run_segment_gui()
        runApp(app, launch.browser = TRUE)
      }, error = function(e) {
        cat("\nError launching Segment:\n")
        cat(e$message, "\n")
      })

    } else if (selected == "conjoint") {
      cat("Loading Conjoint module...\n\n")
      source(file.path(turas_root, "modules/conjoint/run_conjoint_gui.R"))

      # run_conjoint_gui() returns a shinyApp object, we need to run it
      tryCatch({
        app <- run_conjoint_gui()
        runApp(app, launch.browser = TRUE)
      }, error = function(e) {
        cat("\nError launching Conjoint:\n")
        cat(e$message, "\n")
      })

    } else if (selected == "keydriver") {
      cat("Loading Key Driver module...\n\n")
      source(file.path(turas_root, "modules/keydriver/run_keydriver_gui.R"))

      # run_keydriver_gui() returns a shinyApp object, we need to run it
      tryCatch({
        app <- run_keydriver_gui()
        runApp(app, launch.browser = TRUE)
      }, error = function(e) {
        cat("\nError launching Key Driver:\n")
        cat(e$message, "\n")
      })

    } else if (selected == "pricing") {
      cat("Loading Pricing module...\n\n")
      source(file.path(turas_root, "modules/pricing/run_pricing_gui.R"))

      # run_pricing_gui() returns a shinyApp object, we need to run it
      tryCatch({
        app <- run_pricing_gui()
        runApp(app, launch.browser = TRUE)
      }, error = function(e) {
        cat("\nError launching Pricing:\n")
        cat(e$message, "\n")
      })
    }
  } else {
    cat("\nLauncher closed without selection.\n")
  }

  # Return invisibly
  invisible(NULL)
}


# ==============================================================================
# Auto-run when sourced
# ==============================================================================
# Automatically launch the GUI when this file is sourced
launch_turas()
