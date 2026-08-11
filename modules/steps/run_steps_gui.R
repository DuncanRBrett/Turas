# ==============================================================================
# TURAS > PROJECT STEPS GUI - LAUNCHER
# ==============================================================================
# Purpose: Run the project steps that live outside the analytical modules -
#          the scripts a deliverable depends on - from inside Turas, with their
#          output visible and their failures reported as TRS refusals.
# Location: modules/steps/run_steps_gui.R
# Usage: source("modules/steps/run_steps_gui.R"); app <- run_steps_gui()
# ==============================================================================

run_steps_gui <- function() {

  # === EARLY REFUSE (before the module libraries are loaded) ===================
  early_refuse <- function(code, title, problem, why_it_matters, how_to_fix) {
    msg <- paste0(
      "\n", strrep("=", 80), "\n",
      "  [REFUSE] ", code, ": ", title, "\n",
      strrep("=", 80), "\n\n",
      "Problem:\n  ", problem, "\n\n",
      "Why it matters:\n  ", why_it_matters, "\n\n",
      "How to fix:\n"
    )
    if (is.character(how_to_fix) && length(how_to_fix) > 1) {
      for (fix in how_to_fix) msg <- paste0(msg, "  - ", fix, "\n")
    } else {
      msg <- paste0(msg, "  ", how_to_fix, "\n")
    }
    msg <- paste0(msg, "\n", strrep("=", 80), "\n")
    cat(msg)   # console visibility in Shiny
    stop(msg, call. = FALSE)
  }

  required_packages <- c("shiny", "shinyFiles", "processx")
  missing_packages <- required_packages[
    !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing_packages) > 0) {
    early_refuse(
      code = "PKG_MISSING_DEPENDENCY",
      title = "Missing Required Packages",
      problem = sprintf("These packages are not installed: %s",
                        paste(missing_packages, collapse = ", ")),
      why_it_matters = "The Project Steps GUI cannot run a tool without them.",
      how_to_fix = c(
        "Run renv::restore() - all three are already in renv.lock",
        sprintf("Or install directly: install.packages(c(%s))",
                paste(sprintf('"%s"', missing_packages), collapse = ", "))
      )
    )
  }

  suppressPackageStartupMessages({
    library(shiny)
    library(shinyFiles)
  })

  # === CONFIGURATION ==========================================================

  TURAS_HOME <- Sys.getenv("TURAS_ROOT", getwd())
  MODULE_DIR <- file.path(TURAS_HOME, "modules", "steps")

  source(file.path(TURAS_HOME, "modules", "shared", "lib", "gui_theme.R"))
  source(file.path(MODULE_DIR, "lib", "registry.R"))
  source(file.path(MODULE_DIR, "lib", "run_tool.R"))
  source(file.path(MODULE_DIR, "lib", "runbook.R"))

  theme <- turas_gui_theme("Project Steps",
                           "Run the project's external tools from inside Turas")

  reg <- steps_registry()
  if (reg$status == "REFUSED") {
    steps_print_refusal(reg, context = "Project Steps: tool registry")
    early_refuse(
      code = reg$code,
      title = "Tool Registry Is Not Valid",
      problem = reg$message,
      why_it_matters = "No tool can be listed or run until the registry is well-formed.",
      how_to_fix = reg$how_to_fix
    )
  }
  TOOLS <- reg$result

  tool_group <- function(m) if (is.null(m$group)) STEPS_DEFAULT_GROUP else m$group

  # Browse-button ids are derived from the manifest, so they are known before
  # the app starts and can be registered up front.
  browse_id <- function(tool_id, arg_id) paste0("browse__", tool_id, "__", arg_id)

  path_args <- do.call(rbind, lapply(TOOLS, function(m) {
    args <- m$args
    if (is.null(args)) return(NULL)
    keep <- Filter(function(a) a$type %in% c("file", "dir"), args)
    if (length(keep) == 0) return(NULL)
    do.call(rbind, lapply(keep, function(a) {
      data.frame(tool = m$id, arg = a$id, type = a$type, stringsAsFactors = FALSE)
    }))
  }))

  input_id <- function(tool_id, arg_id) paste0("arg__", tool_id, "__", arg_id)

  if (!exists("%||%")) {
    `%||%` <- function(a, b) if (is.null(a)) b else a
  }

  # ============================================================================
  # UI
  # ============================================================================

  ui <- fluidPage(
    theme$head,
    theme$header,

    div(class = "turas-content",

      div(class = "turas-card",
        h3(class = "turas-card-title", "Project runbook"),
        p(class = "turas-help-text",
          "A runbook is the ordered record of how one project's deliverable is ",
          "produced - every step, including the ones no button can run. Open one ",
          "to work through it as a checklist, or create a blank one for a new project."),
        fluidRow(
          column(9, textInput("runbook_path", NULL, value = "", width = "100%",
                              placeholder = "…/<Project> Runbook.xlsx")),
          column(3, shinyFiles::shinyFilesButton("browse_runbook", "Browse...",
                                                 "Select a runbook workbook",
                                                 multiple = FALSE, buttonType = "default"))
        ),
        actionButton("load_runbook", "Open runbook", class = "btn btn-primary"),
        tags$span(style = "display:inline-block; width:10px;"),
        actionButton("new_runbook_toggle", "New runbook...", class = "btn btn-default"),
        uiOutput("new_runbook_ui"),
        uiOutput("runbook_status")
      ),

      uiOutput("checklist_card"),

      div(class = "turas-card",
        h3(class = "turas-card-title", "All tools"),
        p(class = "turas-help-text",
          "Every registered tool, runnable on its own without a runbook."),
        uiOutput("tool_list")
      ),

      uiOutput("tool_form"),
      uiOutput("run_card"),
      uiOutput("output_card")
    )
  )

  # ============================================================================
  # SERVER
  # ============================================================================

  server <- function(input, output, session) {

    rv <- reactiveValues(
      tool_id      = NULL,
      proc         = NULL,
      display      = "",
      lines        = character(0),
      result       = NULL,
      running      = FALSE,
      prefill      = list(),      # arg values loaded from a runbook step
      runbook      = NULL,        # parsed runbook
      runbook_path = NULL,
      runbook_msg  = NULL,        # refusal to show on the runbook card
      state        = list(),      # sidecar last-run state
      step_key     = NULL,        # the runbook step the next run belongs to
      last_values  = list(),      # arguments the current run was started with
      show_new     = FALSE
    )

    current_tool <- reactive({
      if (is.null(rv$tool_id)) return(NULL)
      steps_find_tool(rv$tool_id, TOOLS)
    })

    # ---- Runbook -------------------------------------------------------------

    volumes <- turas_gui_volumes()
    shinyFiles::shinyFileChoose(input, "browse_runbook", roots = volumes,
                                session = session, filetypes = "xlsx")

    observeEvent(input$browse_runbook, {
      if (!is.integer(input$browse_runbook)) {
        info <- shinyFiles::parseFilePaths(volumes, input$browse_runbook)
        if (nrow(info) > 0) {
          updateTextInput(session, "runbook_path",
            value = normalizePath(as.character(info$datapath[1]),
                                  winslash = "/", mustWork = FALSE))
        }
      }
    })

    observeEvent(input$load_runbook, {
      path <- trimws(input$runbook_path %||% "")
      res <- steps_runbook_read(path, TOOLS)

      if (res$status == "REFUSED") {
        steps_print_refusal(res, context = "Project Steps: runbook")
        rv$runbook <- NULL
        rv$runbook_path <- NULL
        rv$runbook_msg <- res
        showNotification(paste0(res$code, ": ", res$message),
                         type = "error", duration = NULL)
        return()
      }

      rv$runbook      <- res$result
      rv$runbook_path <- res$result$path
      rv$runbook_msg  <- NULL
      rv$state        <- steps_runbook_state_read(res$result$path)
      cat("\nRunbook loaded:", res$result$path, "-",
          length(res$result$steps), "steps\n\n")
    })

    observeEvent(input$new_runbook_toggle, {
      rv$show_new <- !isTRUE(rv$show_new)
    })

    shinyFiles::shinyDirChoose(input, "browse_new_dir", roots = volumes,
                               session = session)

    observeEvent(input$browse_new_dir, {
      if (!is.integer(input$browse_new_dir)) {
        d <- shinyFiles::parseDirPath(volumes, input$browse_new_dir)
        if (length(d) > 0) {
          updateTextInput(session, "new_runbook_dir",
            value = normalizePath(path.expand(as.character(d)),
                                  winslash = "/", mustWork = FALSE))
        }
      }
    })

    output$new_runbook_ui <- renderUI({
      if (!isTRUE(rv$show_new)) return(NULL)
      div(style = "margin-top:16px; padding-top:12px; border-top:1px solid #e2e8f0;",
        p(class = "turas-help-text",
          "Writes a blank runbook - the Steps sheet with its columns, a Provenance ",
          "block, and a Guide sheet explaining both. It never overwrites an ",
          "existing runbook."),
        fluidRow(
          column(6, textInput("new_runbook_name", "Project name", value = "",
                              placeholder = "ASSA", width = "100%")),
          column(6, textInput("new_runbook_dir", "Folder", value = "",
                              placeholder = "the project folder", width = "100%"))
        ),
        shinyFiles::shinyDirButton("browse_new_dir", "Browse for folder...",
                                   "Select the project folder", buttonType = "default"),
        tags$span(style = "display:inline-block; width:10px;"),
        actionButton("create_runbook", "Create runbook", class = "btn btn-primary")
      )
    })

    observeEvent(input$create_runbook, {
      name <- trimws(input$new_runbook_name %||% "")
      dir  <- trimws(input$new_runbook_dir %||% "")

      if (!nzchar(name) || !nzchar(dir)) {
        showNotification("Give the project a name and choose a folder.",
                         type = "warning", duration = 6)
        return()
      }

      target <- file.path(dir, sprintf("%s Runbook.xlsx", name))
      res <- steps_runbook_write_template(target, project_name = name)

      if (res$status == "REFUSED") {
        steps_print_refusal(res, context = "Project Steps: new runbook")
        rv$runbook_msg <- res
        showNotification(paste0(res$code, ": ", res$message),
                         type = "error", duration = NULL)
        return()
      }

      cat("\nRunbook created:", res$path, "\n\n")
      updateTextInput(session, "runbook_path", value = res$path)
      rv$show_new <- FALSE
      showNotification(paste0(res$message,
                              " Fill in the steps in Excel, then open it here."),
                       type = "message", duration = 10)
    })

    output$runbook_status <- renderUI({
      if (!is.null(rv$runbook_msg)) {
        m <- rv$runbook_msg
        return(div(class = "turas-status-error", style = "margin-top:12px;",
                   tags$strong(paste0(m$code, ": ")), m$message,
                   tags$br(),
                   tags$small(paste(m$how_to_fix, collapse = "  |  "))))
      }
      if (is.null(rv$runbook)) return(NULL)
      div(class = "turas-status-success", style = "margin-top:12px;",
          sprintf("%s - %d steps.", basename(rv$runbook$path),
                  length(rv$runbook$steps)))
    })

    # ---- Checklist -----------------------------------------------------------

    type_badge <- function(type) {
      colours <- list(
        module        = c("#1a2744", "#e2e8f0"),
        tool          = c("#065f46", "#d1fae5"),
        `ai-assisted` = c("#92400e", "#fef3c7"),
        manual        = c("#475569", "#f1f5f9")
      )
      col <- colours[[type]]
      if (is.null(col)) col <- c("#475569", "#f1f5f9")
      tags$span(
        style = sprintf(paste0("display:inline-block; padding:1px 8px; border-radius:10px;",
                               " font-size:11px; font-weight:600; color:%s; background:%s;"),
                        col[1], col[2]),
        type
      )
    }

    last_run_line <- function(key) {
      st <- rv$state[[key]]
      if (is.null(st)) return(NULL)
      tags$small(style = "color:#64748b;",
        sprintf("Last %s: %s",
                if (identical(st$last_status, "PASS")) "run" else "attempt",
                format(st$last_run, "%d %b %Y %H:%M")))
    }

    output$checklist_card <- renderUI({
      rb <- rv$runbook
      if (is.null(rb)) return(NULL)

      prov <- rb$provenance
      prov_rows <- Filter(function(k) nzchar(prov[[k]] %||% ""), names(prov))

      div(class = "turas-card",
        h3(class = "turas-card-title", "Steps in this project"),
        p(class = "turas-help-text",
          "In order. 'Open' fills the form below with this step's arguments - ",
          "you still press RUN STEP to start it. Nothing here sequences itself ",
          "and there is no run-all: the work between steps is the point."),

        lapply(seq_along(rb$steps), function(i) {
          s <- rb$steps[[i]]
          key <- steps_runbook_key(s)
          runnable <- identical(s$type, "tool")

          div(style = paste0("display:flex; gap:12px; align-items:flex-start; ",
                             "padding:10px 0; border-bottom:1px solid #f1f5f9;"),
            div(style = "width:28px; color:#94a3b8; font-weight:600; flex-shrink:0;",
                s$order),
            div(style = "flex:1;",
              div(tags$strong(s$step), " ", type_badge(s$type)),
              if (nzchar(s$notes)) div(class = "turas-help-text", s$notes),
              if (nzchar(s$tool) && !runnable) {
                tags$small(style = "color:#94a3b8;", s$tool)
              },
              last_run_line(key)
            ),
            div(style = "flex-shrink:0;",
              if (runnable) {
                tags$button(class = "btn btn-default btn-sm",
                  onclick = sprintf(
                    "Shiny.setInputValue('open_runbook_step', %d, {priority: 'event'})", i),
                  "Open")
              } else {
                tags$button(class = "btn btn-default btn-sm",
                  onclick = sprintf(
                    "Shiny.setInputValue('mark_runbook_step', %d, {priority: 'event'})", i),
                  "Mark done")
              }
            )
          )
        }),

        if (length(prov_rows) > 0) {
          div(style = "margin-top:18px; padding-top:12px; border-top:1px solid #e2e8f0;",
            div(class = "recent-section-label",
                style = "font-size:11px; font-weight:600; letter-spacing:0.08em; text-transform:uppercase; color:#94a3b8;",
                "Provenance"),
            tags$ul(style = "margin:8px 0 0 0; padding-left:18px;",
              lapply(prov_rows, function(k) {
                tags$li(tags$small(sprintf("%s: %s", k, prov[[k]])))
              })
            )
          )
        }
      )
    })

    observeEvent(input$open_runbook_step, {
      rb <- rv$runbook
      req(rb)
      if (isTRUE(rv$running)) {
        showNotification("A step is still running - wait for it to finish.",
                         type = "warning", duration = 5)
        return()
      }
      s <- rb$steps[[as.integer(input$open_runbook_step)]]
      if (is.null(s)) return()

      # Last-used arguments win over the runbook's, so a corrected path sticks.
      st <- rv$state[[steps_runbook_key(s)]]
      args <- s$args
      if (!is.null(st) && length(st$last_args) > 0) {
        for (nm in names(st$last_args)) args[[nm]] <- st$last_args[[nm]]
      }

      rv$tool_id  <- s$tool
      rv$prefill  <- args
      rv$step_key <- steps_runbook_key(s)
      rv$lines    <- character(0)
      rv$result   <- NULL
      rv$display  <- ""
    })

    observeEvent(input$mark_runbook_step, {
      rb <- rv$runbook
      req(rb, rv$runbook_path)
      s <- rb$steps[[as.integer(input$mark_runbook_step)]]
      if (is.null(s)) return()
      key <- steps_runbook_key(s)
      steps_runbook_state_write(rv$runbook_path, key, "PASS")
      rv$state <- steps_runbook_state_read(rv$runbook_path)
      showNotification(sprintf("Marked done: %s", s$step),
                       type = "message", duration = 5)
    })

    # ---- Tool list -----------------------------------------------------------

    output$tool_list <- renderUI({
      groups <- unique(vapply(TOOLS, tool_group, character(1)))
      tagList(lapply(groups, function(g) {
        in_group <- Filter(function(m) identical(tool_group(m), g), TOOLS)
        div(class = "turas-recent-section",
          h4(g),
          lapply(in_group, function(m) {
            selected <- identical(rv$tool_id, m$id)
            div(
              class = "turas-recent-item",
              style = if (selected) "border-color:#1a2744; background:#f1f5f9;" else NULL,
              onclick = sprintf(
                "Shiny.setInputValue('select_tool', '%s', {priority: 'event'})", m$id
              ),
              tags$strong(m$name),
              tags$br(),
              tags$small(m$description)
            )
          })
        )
      }))
    })

    observeEvent(input$select_tool, {
      if (isTRUE(rv$running)) {
        showNotification("A step is still running - wait for it to finish.",
                         type = "warning", duration = 5)
        return()
      }
      rv$tool_id  <- input$select_tool
      rv$lines    <- character(0)
      rv$result   <- NULL
      rv$display  <- ""
      # Chosen directly, so it belongs to no runbook step and starts blank.
      rv$prefill  <- list()
      rv$step_key <- NULL
    })

    # ---- Form ----------------------------------------------------------------

    # Prefill values come from the runbook step (and its last-used arguments).
    # They are baked into the inputs at render time rather than pushed with
    # updateTextInput, which would race the form being built.
    prefill_value <- function(arg_id) {
      v <- rv$prefill[[arg_id]]
      if (is.null(v)) "" else as.character(v)[1]
    }

    render_arg <- function(m, a) {
      iid <- input_id(m$id, a$id)
      help <- if (!is.null(a$help)) div(class = "turas-help-text", a$help) else NULL
      required_mark <- if (isTRUE(a$required)) " *" else ""
      pre <- prefill_value(a$id)

      if (identical(a$type, "flag")) {
        return(div(style = "margin-bottom:14px;",
                   checkboxInput(iid, paste0(a$label, required_mark),
                                 value = .steps_value_flag(pre)),
                   help))
      }

      if (identical(a$type, "choice")) {
        return(div(style = "margin-bottom:14px;",
                   selectInput(iid, paste0(a$label, required_mark),
                               choices = c("", a$choices),
                               selected = if (pre %in% a$choices) pre else ""),
                   help))
      }

      if (a$type %in% c("file", "dir")) {
        btn <- browse_id(m$id, a$id)
        return(div(style = "margin-bottom:14px;",
          fluidRow(
            column(9, textInput(iid, paste0(a$label, required_mark),
                                value = pre, width = "100%")),
            column(3, br(),
              if (identical(a$type, "file")) {
                shinyFiles::shinyFilesButton(btn, "Browse...", "Select a file",
                                             multiple = FALSE, buttonType = "default")
              } else {
                shinyFiles::shinyDirButton(btn, "Browse...", "Select a folder",
                                           buttonType = "default")
              }
            )
          ),
          help
        ))
      }

      # text and flag_value both take a free-text value
      div(style = "margin-bottom:14px;",
          textInput(iid, paste0(a$label, required_mark), value = pre, width = "100%"),
          help)
    }

    output$tool_form <- renderUI({
      m <- current_tool()
      if (is.null(m)) return(NULL)

      env <- steps_check_env(m)
      env_banner <- if (env$status == "REFUSED") {
        div(class = "turas-status-error",
            tags$strong(paste0(env$code, ": ")), env$message,
            tags$br(),
            tags$small(paste(env$how_to_fix, collapse = "  |  ")))
      } else {
        div(class = "turas-status-success",
            sprintf("%s found at %s", m$runtime, env$runtime_path))
      }

      docs_line <- if (!is.null(m$docs)) {
        div(class = "turas-help-text",
            "Documentation: ", tags$code(m$docs))
      } else NULL

      args <- m$args
      if (is.null(args)) args <- list()

      div(class = "turas-card",
        h3(class = "turas-card-title", m$name),
        p(class = "turas-help-text", m$description),
        div(class = "turas-help-text",
            "Runs: ", tags$code(paste(m$runtime, m$entry))),
        docs_line,
        env_banner,
        tags$hr(),
        lapply(args, function(a) render_arg(m, a)),
        div(class = "turas-help-text", "* required")
      )
    })

    # ---- Browse buttons (per tool argument; `volumes` set above) -------------

    if (!is.null(path_args)) {
      for (i in seq_len(nrow(path_args))) {
        local({
          row <- path_args[i, ]
          btn <- browse_id(row$tool, row$arg)
          target <- input_id(row$tool, row$arg)

          if (identical(row$type, "file")) {
            shinyFiles::shinyFileChoose(input, btn, roots = volumes, session = session)
            observeEvent(input[[btn]], {
              if (!is.integer(input[[btn]])) {
                info <- shinyFiles::parseFilePaths(volumes, input[[btn]])
                if (nrow(info) > 0) {
                  updateTextInput(session, target,
                    value = normalizePath(as.character(info$datapath[1]),
                                          winslash = "/", mustWork = FALSE))
                }
              }
            })
          } else {
            shinyFiles::shinyDirChoose(input, btn, roots = volumes, session = session)
            observeEvent(input[[btn]], {
              if (!is.integer(input[[btn]])) {
                d <- shinyFiles::parseDirPath(volumes, input[[btn]])
                if (length(d) > 0) {
                  updateTextInput(session, target,
                    value = normalizePath(path.expand(as.character(d)),
                                          winslash = "/", mustWork = FALSE))
                }
              }
            })
          }
        })
      }
    }

    # ---- Run -----------------------------------------------------------------

    output$run_card <- renderUI({
      m <- current_tool()
      if (is.null(m)) return(NULL)
      step_note <- if (!is.null(rv$step_key) && !is.null(rv$runbook)) {
        div(class = "turas-help-text",
            "Runs as runbook step ", tags$code(rv$step_key),
            " - the outcome is recorded against it.")
      } else NULL

      div(class = "turas-card",
        h3(class = "turas-card-title", "Run"),
        step_note,
        actionButton("run_step", "RUN STEP", class = "turas-btn-run",
                     width = "220px"),
        if (isTRUE(rv$running)) {
          div(class = "turas-status-info", style = "margin-top:12px;",
              "Running - output appears below as the tool produces it.")
        }
      )
    })

    collect_values <- function(m) {
      args <- m$args
      if (is.null(args)) return(list())
      vals <- list()
      for (a in args) vals[[a$id]] <- input[[input_id(m$id, a$id)]]
      vals
    }

    #' Record a run against the runbook step it came from, if any
    #'
    #' Only ever writes the sidecar - the analyst's workbook is never touched.
    record_runbook_outcome <- function(status, values) {
      key <- isolate(rv$step_key)
      path <- isolate(rv$runbook_path)
      if (is.null(key) || is.null(path)) return(invisible(NULL))
      # Flags are stored as they were set, so reopening the step restores them.
      keep <- Filter(function(v) !is.null(v) && length(v) > 0 && nzchar(as.character(v)[1]),
                     lapply(values, function(v) if (is.logical(v)) tolower(as.character(v)) else v))
      steps_runbook_state_write(path, key, status, args = keep)
      rv$state <- steps_runbook_state_read(path)
      invisible(NULL)
    }

    observeEvent(input$run_step, {
      m <- current_tool()
      req(m)
      if (isTRUE(rv$running)) return()

      rv$lines  <- character(0)
      rv$result <- NULL

      values <- collect_values(m)
      rv$last_values <- values

      started <- steps_start_tool(m, values, turas_root = TURAS_HOME)

      if (started$status == "REFUSED") {
        steps_print_refusal(started, context = sprintf("Project Steps: %s", m$name))
        rv$result <- started
        record_runbook_outcome("REFUSED", values)
        showNotification(paste0(started$code, ": ", started$message),
                         type = "error", duration = NULL)
        return()
      }

      cat("\n> ", started$display, "\n\n", sep = "")
      rv$display <- started$display
      rv$lines   <- c(paste0("> ", started$display), "")
      rv$proc    <- started$process
      rv$running <- TRUE
    })

    # Poll the running tool. This must live outside the run observer: the UI
    # cannot flush while an observer is still executing.
    observe({
      p <- rv$proc
      if (is.null(p)) return()
      invalidateLater(300, session)

      # rv$lines is read with isolate(): appending to it must not invalidate this
      # observer, or a chatty tool would spin it instead of waiting the 300ms.
      new_lines <- steps_drain(p, timeout_ms = 0L)
      if (length(new_lines) > 0) {
        cat(new_lines, sep = "\n"); cat("\n")
        rv$lines <- c(isolate(rv$lines), new_lines)
      }

      if (!p$is_alive()) {
        last <- steps_drain(p, timeout_ms = 0L)
        if (length(last) > 0) {
          cat(last, sep = "\n"); cat("\n")
          rv$lines <- c(isolate(rv$lines), last)
        }
        result <- steps_finish_tool(current_tool(), p,
                                    output = isolate(rv$lines),
                                    display = rv$display)
        rv$proc    <- NULL
        rv$running <- FALSE
        rv$result  <- result
        record_runbook_outcome(result$status, isolate(rv$last_values) %||% list())

        if (result$status == "REFUSED") {
          steps_print_refusal(result, context = sprintf("Project Steps: %s",
                                                        current_tool()$name))
          showNotification(paste0(result$code, ": ", result$message),
                           type = "error", duration = NULL)
        } else {
          cat("\n", result$message, "\n\n", sep = "")
          showNotification(result$message, type = "message", duration = 8)
        }
      }
    })

    # ---- Output --------------------------------------------------------------

    output$console_text <- renderText({
      paste(rv$lines, collapse = "\n")
    })

    output$output_card <- renderUI({
      if (length(rv$lines) == 0 && is.null(rv$result)) return(NULL)

      banner <- NULL
      res <- rv$result
      if (!is.null(res)) {
        banner <- if (res$status == "REFUSED") {
          div(class = "turas-status-error",
              tags$strong(paste0(res$code, ": ")), res$message,
              tags$br(),
              tags$small(paste(res$how_to_fix, collapse = "  |  ")))
        } else {
          div(class = "turas-status-success", res$message)
        }
      }

      div(class = "turas-card",
        h3(class = "turas-card-title", "Output"),
        banner,
        div(class = "turas-console", verbatimTextOutput("console_text"))
      )
    })
  }

  cat("\nLaunching Turas > Project Steps GUI...\n\n")
  shinyApp(ui = ui, server = server)
}
