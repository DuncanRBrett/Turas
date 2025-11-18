# ==============================================================================
# TURAS>PARSER - Shiny Application
# ==============================================================================
# Purpose: Interactive UI for questionnaire parsing
# ==============================================================================

#' Parser UI
#' 
#' @description
#' Creates the Shiny UI for the questionnaire parser.
#' 
#' @export
parser_ui <- function() {
  
  shiny::fluidPage(
    
    # Custom CSS
    shiny::tags$head(
      shiny::tags$style(shiny::HTML("
        .main-header {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 30px;
          border-radius: 10px;
          margin-bottom: 20px;
        }
        .card {
          background: white;
          border-radius: 10px;
          padding: 20px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          margin-bottom: 20px;
        }
        .needs-review {
          background-color: #fff3cd;
          border-left: 4px solid #ffc107;
        }
        .btn-primary {
          background: #667eea;
          border: none;
        }
        .btn-primary:hover {
          background: #764ba2;
        }
      "))
    ),
    
    # Header
    shiny::div(
      class = "main-header",
      shiny::h1("Turas>Parser"),
      shiny::p("Generate Survey_Structure.xlsx from Word questionnaires"),
      shiny::p(
        style = "font-size: 14px; opacity: 0.9;",
        "Part of Turas Analytics Toolkit • Version 1.0.0"
      )
    ),
    
    # Main content
    shiny::fluidRow(
      shiny::column(12,
        
        # Step 1: File selection
        shiny::div(
          class = "card",
          shiny::h3("1. Select Word Document"),
          shiny::fileInput(
            "docx_file",
            "Choose .docx file",
            accept = c(".docx"),
            buttonLabel = "Browse...",
            placeholder = "No file selected"
          ),
          
          # Configuration
          shiny::h4("Parsing Configuration"),
          shiny::fluidRow(
            shiny::column(4,
              shiny::selectInput(
                "auto_detect",
                "Auto-detect question types",
                choices = c("Yes" = "TRUE", "No" = "FALSE"),
                selected = "TRUE"
              )
            ),
            shiny::column(4,
              shiny::selectInput(
                "default_type",
                "Default question type",
                choices = names(get_question_types()),
                selected = "Single_Response"
              )
            ),
            shiny::column(4,
              shiny::selectInput(
                "combine_multiline",
                "Combine multi-line questions",
                choices = c("Yes" = "TRUE", "No" = "FALSE"),
                selected = "TRUE"
              )
            )
          ),
          
          shiny::actionButton(
            "parse_btn",
            "Parse Document",
            class = "btn btn-primary btn-lg",
            icon = shiny::icon("play")
          )
        ),
        
        # Step 2: Status
        shiny::uiOutput("status_ui"),
        
        # Step 3: Questions table
        shiny::uiOutput("questions_ui"),
        
        # Step 4: Downloads
        shiny::uiOutput("download_ui")
      )
    )
  )
}

#' Parser Server
#'
#' @description
#' Server logic for the questionnaire parser.
#'
#' @note REFACTORING NEEDED (CR-PARSER-003):
#' This function is 294 lines long and violates single responsibility principle.
#' Recommended refactoring using Shiny modules pattern:
#'
#' PHASE 1 - Extract Reactive Logic:
#' - create_parsing_module() -> handles document parsing (lines 137-184)
#' - create_status_module() -> handles status display (lines 186-213)
#' - create_questions_table_module() -> handles questions display (lines 215-290)
#' - create_download_module() -> handles Excel generation (lines 292-350)
#' - create_upload_module() -> handles edited file upload (lines 352-425)
#'
#' PHASE 2 - Shared State:
#' - Use reactiveValues() for shared state instead of multiple reactiveVal()
#' - Implement event bus pattern for cross-module communication
#'
#' PHASE 3 - UI Modules:
#' - Extract corresponding UI functions for each module
#' - Implement consistent module naming: mod_parsing_ui() / mod_parsing_server()
#'
#' BENEFITS:
#' - Each module <50 lines, easier to test
#' - Clear separation of concerns
#' - Reusable components
#' - Better error isolation
#'
#' @export
parser_server <- function(input, output, session) {
  
  # Reactive value for parsed questions
  questions_data <- shiny::reactiveVal(NULL)
  
  # Parse button clicked
  shiny::observeEvent(input$parse_btn, {
    shiny::req(input$docx_file)

    # Validate file type and size
    file_ext <- tolower(tools::file_ext(input$docx_file$name))
    if (!file_ext %in% c("docx", "doc")) {
      shiny::showNotification(
        "Invalid file type. Please upload a Word document (.docx or .doc)",
        type = "error",
        duration = 5
      )
      return(NULL)
    }

    # Check file size (max 50MB)
    max_size <- 50 * 1024 * 1024  # 50MB in bytes
    if (file.size(input$docx_file$datapath) > max_size) {
      shiny::showNotification(
        "File too large. Maximum file size is 50MB.",
        type = "error",
        duration = 5
      )
      return(NULL)
    }

    # Show loading
    parse_notif_id <- shiny::showNotification(
      "Parsing document...",
      type = "message",
      duration = NULL
    )
    
    tryCatch({
      # Build config
      config <- list(
        auto_detect = (input$auto_detect == "TRUE"),
        default_type = input$default_type,
        combine_multiline = (input$combine_multiline == "TRUE")
      )
      
      # Parse
      questions <- parse_docx_questionnaire(input$docx_file$datapath, config)
      
      # Validate
      if (is.null(questions) || nrow(questions) == 0) {
        stop("No questions were parsed from the document")
      }
      
      # Store
      questions_data(questions)
      
      # Success notification
      shiny::removeNotification(parse_notif_id)
      shiny::showNotification(
        paste("✓ Successfully parsed", nrow(questions), "questions"),
        type = "message",
        duration = 5
      )
      
    }, error = function(e) {
      shiny::removeNotification(parse_notif_id)
      shiny::showNotification(
        paste("Error:", e$message),
        type = "error",
        duration = 10
      )
      cat("\nError details:\n")
      print(e)
    })
  })
  
  # Display status summary
  output$status_ui <- shiny::renderUI({
    questions <- questions_data()
    if (is.null(questions)) return(NULL)
    
    needs_review <- sum(questions$needs_review, na.rm = TRUE)
    
    shiny::div(
      class = "card",
      shiny::h3("2. Review Parsed Questions"),
      shiny::tags$p(
        shiny::tags$strong(nrow(questions)), " questions parsed"
      ),
      if (needs_review > 0) {
        shiny::tags$p(
          style = "color: #856404;",
          shiny::icon("exclamation-triangle"),
          shiny::tags$strong(needs_review), " questions flagged for review"
        )
      } else {
        shiny::tags$p(
          style = "color: #155724;",
          shiny::icon("check-circle"),
          " All questions parsed with high confidence"
        )
      }
    )
  })
  
  # Display questions table
  output$questions_ui <- shiny::renderUI({
    questions <- questions_data()
    if (is.null(questions)) return(NULL)
    
    shiny::div(
      class = "card",
      shiny::h4("Parsed Questions"),
      shiny::p(
        style = "color: #666;",
        "Review the questions below. Edit codes and types as needed in the downloaded Excel files."
      ),
      
      # Create table
      shiny::tags$div(
        style = "overflow-x: auto;",
        shiny::tags$table(
          class = "table table-striped",
          shiny::tags$thead(
            shiny::tags$tr(
              shiny::tags$th("Code"),
              shiny::tags$th("Type"),
              shiny::tags$th("Question Text"),
              shiny::tags$th("Options"),
              shiny::tags$th("Status")
            )
          ),
          shiny::tags$tbody(
            lapply(seq_len(nrow(questions)), function(i) {
              q <- questions[i, ]
              
              # Options display
              options_display <- if (length(q$options[[1]]) > 0) {
                paste0(length(q$options[[1]]), " options")
              } else if (!is.null(q$bins[[1]]) && nrow(q$bins[[1]]) > 0) {
                paste0(nrow(q$bins[[1]]), " bins")
              } else {
                "None"
              }
              
              # Status display
              status_display <- if (isTRUE(q$needs_review)) {
                shiny::tags$span(
                  style = "color: #856404;",
                  shiny::icon("exclamation-triangle"), " Review"
                )
              } else {
                shiny::tags$span(
                  style = "color: #28a745;",
                  shiny::icon("check"), " OK"
                )
              }
              
              shiny::tags$tr(
                class = if (isTRUE(q$needs_review)) "needs-review" else "",
                shiny::tags$td(shiny::tags$strong(q$code)),
                shiny::tags$td(
                  shiny::tags$span(
                    class = "badge badge-info",
                    style = "background-color: #667eea;",
                    q$type
                  )
                ),
                shiny::tags$td(
                  style = "max-width: 400px;",
                  substr(q$text, 1, 100),
                  if (nchar(q$text) > 100) "..." else ""
                ),
                shiny::tags$td(options_display),
                shiny::tags$td(status_display)
              )
            })
          )
        )
      ),
      
      shiny::tags$hr(),
      shiny::tags$p(
        style = "color: #666; font-size: 14px;",
        shiny::icon("info-circle"),
        " Questions are ready for download. Edit manually in Excel if needed."
      )
    )
  })
  
  # Download buttons
  output$download_ui <- shiny::renderUI({
    if (is.null(questions_data())) return(NULL)
    
    shiny::div(
      class = "card",
      shiny::h3("3. Download Files"),
      shiny::p("Download the generated Excel files for use in Turas>Tabs"),
      
      shiny::fluidRow(
        shiny::column(4,
                      shiny::downloadButton(
                        "download_structure",
                        "Download Survey_Structure.xlsx",
                        class = "btn btn-primary btn-lg btn-block",
                        icon = shiny::icon("download")
                      )
        ),
        shiny::column(4,
                      shiny::downloadButton(
                        "download_selection",
                        "Download Selection_Sheet.xlsx",
                        class = "btn btn-success btn-lg btn-block",
                        icon = shiny::icon("download")
                      )
        ),
        shiny::column(4,
                      shiny::downloadButton(
                        "download_headers",
                        "Download Data_Headers.xlsx",
                        class = "btn btn-info btn-lg btn-block",
                        icon = shiny::icon("download")
                      )
        )
      ),
      
      shiny::tags$hr(),
      shiny::tags$div(
        style = "background-color: #e7f3ff; padding: 15px; border-radius: 5px;",
        shiny::tags$h5(shiny::icon("lightbulb"), " Next Steps"),
        shiny::tags$ol(
          shiny::tags$li("Download both Excel files"),
          shiny::tags$li("Review and edit if needed"),
          shiny::tags$li("Copy Selection sheet into your Crosstab_Config.xlsx"),
          shiny::tags$li("Use Survey_Structure.xlsx with Turas>Tabs")
        )
      )
    )
  })
  
  # Download handlers
  output$download_structure <- shiny::downloadHandler(
    filename = function() {
      paste0("Survey_Structure_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
    },
    content = function(file) {
      questions <- questions_data()
      
      tryCatch({
        generate_survey_structure(questions, file)
        
        shiny::showNotification(
          "✓ Survey_Structure.xlsx downloaded successfully",
          type = "message",
          duration = 3
        )
      }, error = function(e) {
        shiny::showNotification(
          paste("Error generating file:", e$message),
          type = "error",
          duration = 10
        )
      })
    }
  )
  
  output$download_selection <- shiny::downloadHandler(
    filename = function() {
      paste0("Selection_Sheet_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
    },
    content = function(file) {
      questions <- questions_data()
      
      tryCatch({
        generate_selection_sheet(questions, file)
        
        shiny::showNotification(
          "✓ Selection_Sheet.xlsx downloaded successfully",
          type = "message",
          duration = 3
        )
      }, error = function(e) {
        shiny::showNotification(
          paste("Error generating file:", e$message),
          type = "error",
          duration = 10
        )
      })
    }
  )
  
  output$download_headers <- shiny::downloadHandler(
    filename = function() {
      paste0("Data_Headers_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
    },
    content = function(file) {
      questions <- questions_data()
      
      tryCatch({
        generate_data_headers(questions, file)
        
        shiny::showNotification(
          "✓ Data_Headers.xlsx downloaded successfully",
          type = "message",
          duration = 3
        )
      }, error = function(e) {
        shiny::showNotification(
          paste("Error generating file:", e$message),
          type = "error",
          duration = 10
        )
      })
    }
  )
}  # <-- This closing brace ends the parser_server function
