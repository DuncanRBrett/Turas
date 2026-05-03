# ==============================================================================
# TURAS CALLOUT EDITOR GUI
# ==============================================================================
# Purpose: View, edit, and preview callout text for all Turas report modules
# Location: modules/shared/lib/callouts/run_callout_editor_gui.R
# Usage: source(...) then run_callout_editor_gui()
#
# The callout registry (callouts.json) stores educational callout text that
# appears across all Turas HTML reports. This editor provides a GUI for
# viewing and editing that text without touching JSON directly.
# ==============================================================================

run_callout_editor_gui <- function() {

  # --- Package check ---
  required_packages <- c("shiny", "jsonlite")
  missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  if (length(missing_packages) > 0) {
    stop(sprintf(
      "\n[REFUSE] PKG_MISSING_DEPENDENCY: Missing packages: %s\nInstall with: install.packages(c(%s))\n",
      paste(missing_packages, collapse = ", "),
      paste(sprintf('"%s"', missing_packages), collapse = ", ")
    ), call. = FALSE)
  }

  library(shiny)

  # --- Locate callouts.json ---
  TURAS_HOME <- Sys.getenv("TURAS_ROOT", getwd())
  json_path <- file.path(TURAS_HOME, "modules", "shared", "lib", "callouts", "callouts.json")
  if (!file.exists(json_path)) {
    # Fallback: relative to this script
    json_path <- file.path(dirname(sys.frame(1)$ofile %||% "."), "callouts.json")
  }

  # --- Read registry ---
  read_registry <- function() {
    if (!file.exists(json_path)) return(list())
    jsonlite::fromJSON(json_path, simplifyVector = FALSE)
  }

  # --- Write registry ---
  write_registry <- function(data) {
    jsonlite::write_json(data, json_path, pretty = TRUE, auto_unbox = TRUE)
  }

  # --- Build flat table from nested JSON ---
  flatten_registry <- function(reg) {
    rows <- list()
    for (mod in names(reg)) {
      if (mod == "_meta") next
      entries <- reg[[mod]]
      mod_keys <- names(entries)
      for (idx in seq_along(mod_keys)) {
        key <- mod_keys[idx]
        entry <- entries[[key]]
        rows[[length(rows) + 1]] <- data.frame(
          module = mod,
          key = key,
          index = idx,
          total_in_module = length(mod_keys),
          title = entry$title %||% "",
          text = entry$text %||% "",
          context = entry$context %||% "",
          page = entry$page %||% "",
          stringsAsFactors = FALSE
        )
      }
    }
    if (length(rows) == 0) {
      return(data.frame(module = character(), key = character(),
                        index = integer(), total_in_module = integer(),
                        title = character(), text = character(),
                        context = character(), page = character(),
                        stringsAsFactors = FALSE))
    }
    do.call(rbind, rows)
  }

  `%||%` <- function(a, b) if (is.null(a)) b else a

  # --- Page choices for a module ----------------------------------------
  # Returns the union of:
  #   (a) the canonical seed list at reg$_meta$pages[[module]]
  #   (b) any pages that show up in existing callout entries for this
  #       module (so user-added values from the past stay discoverable
  #       even if not yet promoted into _meta.pages)
  # Sorted, deduped, NA/empty stripped. Used for both the Add Callout
  # modal and the Edit panel page picker.
  pages_for_module <- function(reg, module) {
    seed <- reg[["_meta"]]$pages[[module]] %||% list()
    seed_v <- vapply(seed, function(x) as.character(x %||% ""), character(1))
    df <- flatten_registry(reg)
    used <- if (nrow(df) > 0) {
      df$page[df$module == module]
    } else character(0)
    pages <- unique(c(seed_v, used))
    pages <- pages[nzchar(pages)]
    sort(pages)
  }

  # Append a new page to reg$_meta$pages[[module]] when an editor types
  # one that isn't already there. Returns the (possibly mutated) reg.
  remember_page <- function(reg, module, page) {
    page <- trimws(page %||% "")
    if (!nzchar(page) || !nzchar(module)) return(reg)
    if (is.null(reg[["_meta"]])) reg[["_meta"]] <- list()
    if (is.null(reg[["_meta"]]$pages)) reg[["_meta"]]$pages <- list()
    cur <- reg[["_meta"]]$pages[[module]] %||% list()
    cur_v <- vapply(cur, function(x) as.character(x %||% ""), character(1))
    if (page %in% cur_v) return(reg)
    reg[["_meta"]]$pages[[module]] <- as.list(c(cur_v, page))
    reg
  }

  # ============================================================================
  # UI
  # ============================================================================
  ui <- fluidPage(
    tags$head(tags$style(HTML(callout_editor_css()))),
    div(class = "ce-header",
      div(class = "ce-header-inner",
        div(class = "ce-header-title", "Callout Editor"),
        div(class = "ce-header-subtitle", "View and edit platform callout text across all report modules")
      )
    ),

    div(class = "ce-content",
      # Top controls
      div(class = "ce-controls",
        div(class = "ce-filter-row",
          div(class = "ce-filter-group",
            tags$label("Module", `for` = "filter_module", class = "ce-label"),
            selectInput("filter_module", NULL,
                        choices = c("All modules" = "all"),
                        width = "200px")
          ),
          div(class = "ce-filter-group",
            tags$label("Page", `for` = "filter_page", class = "ce-label"),
            selectInput("filter_page", NULL,
                        choices = c("All pages" = "all"),
                        width = "180px")
          ),
          div(class = "ce-filter-group",
            tags$label("Search", `for` = "search_text", class = "ce-label"),
            textInput("search_text", NULL, placeholder = "Search titles or text...",
                      width = "300px")
          ),
          div(class = "ce-spacer"),
          div(class = "ce-count", textOutput("callout_count", inline = TRUE)),
          actionButton("add_btn", "Add Callout",
                        class = "ce-btn ce-btn-primary",
                        icon = icon("plus")),
          div(class = "ce-save-status", textOutput("save_status", inline = TRUE))
        )
      ),

      # Split layout: list left, editor right
      div(class = "ce-split",
        # Left: Callout list
        div(class = "ce-list-panel",
          uiOutput("callout_cards")
        ),

        # Right: Edit panel (always visible area)
        div(class = "ce-edit-area",
          uiOutput("edit_panel")
        )
      )
    )
  )

  # ============================================================================
  # SERVER
  # ============================================================================
  server <- function(input, output, session) {
    # Reactive registry data
    registry <- reactiveVal(read_registry())
    selected <- reactiveVal(NULL)  # list(module, key)
    save_msg <- reactiveVal("")

    # Update module filter choices
    observe({
      reg <- registry()
      mods <- setdiff(names(reg), "_meta")
      choices <- c("All modules" = "all", setNames(mods, tools::toTitleCase(mods)))
      updateSelectInput(session, "filter_module", choices = choices)
    })

    # Update page filter choices based on selected module
    observe({
      reg <- registry()
      df <- flatten_registry(reg)
      if (nrow(df) == 0) return()

      # Filter to selected module first
      if (!is.null(input$filter_module) && input$filter_module != "all") {
        df <- df[df$module == input$filter_module, , drop = FALSE]
      }

      pages <- unique(df$page[nzchar(df$page)])
      page_choices <- c("All pages" = "all")
      if (length(pages) > 0) {
        page_choices <- c(page_choices, setNames(pages, pages))
      }
      updateSelectInput(session, "filter_page", choices = page_choices)
    })

    # Filtered data
    filtered_data <- reactive({
      reg <- registry()
      df <- flatten_registry(reg)
      if (nrow(df) == 0) return(df)

      # Module filter
      if (!is.null(input$filter_module) && input$filter_module != "all") {
        df <- df[df$module == input$filter_module, , drop = FALSE]
      }

      # Page filter
      if (!is.null(input$filter_page) && input$filter_page != "all") {
        df <- df[df$page == input$filter_page, , drop = FALSE]
      }

      # Search filter
      search <- trimws(input$search_text %||% "")
      if (nzchar(search)) {
        pattern <- tolower(search)
        match <- grepl(pattern, tolower(df$title), fixed = TRUE) |
                 grepl(pattern, tolower(df$text), fixed = TRUE) |
                 grepl(pattern, tolower(df$key), fixed = TRUE)
        df <- df[match, , drop = FALSE]
      }

      df
    })

    # Callout count
    output$callout_count <- renderText({
      df <- filtered_data()
      reg <- registry()
      total <- nrow(flatten_registry(reg))
      if (nrow(df) == total) {
        sprintf("%d callouts", total)
      } else {
        sprintf("%d of %d callouts", nrow(df), total)
      }
    })

    # Render callout cards
    output$callout_cards <- renderUI({
      df <- filtered_data()
      if (nrow(df) == 0) {
        return(div(class = "ce-empty", "No callouts found. Use 'Add Callout' to create one."))
      }

      sel <- selected()
      cards <- lapply(seq_len(nrow(df)), function(i) {
        row <- df[i, ]
        is_selected <- !is.null(sel) && sel$module == row$module && sel$key == row$key
        card_class <- paste("ce-card", if (is_selected) "ce-card-selected" else "")

        # Truncate text for preview
        preview <- row$text
        if (nchar(preview) > 120) preview <- paste0(substr(preview, 1, 117), "...")
        # Strip HTML tags for preview
        preview <- gsub("<[^>]+>", "", preview)

        # Position label: "Callout 3 of 5"
        position_label <- sprintf("%d of %d", row$index, row$total_in_module)

        # Page + context labels
        page_label <- if (nzchar(row$page)) row$page else ""
        context_label <- if (nzchar(row$context)) row$context else "No location set"

        div(class = card_class,
          onclick = sprintf(
            "Shiny.setInputValue('select_callout', {module:'%s', key:'%s'}, {priority:'event'})",
            row$module, row$key
          ),
          div(class = "ce-card-header",
            span(class = "ce-card-module", row$module),
            span(class = "ce-card-number", position_label),
            if (nzchar(page_label)) span(class = "ce-card-page-tab", page_label) else NULL,
            span(class = "ce-card-page", HTML(paste0(
              '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align:-1px;margin-right:3px;"><rect x="2" y="3" width="20" height="18" rx="2"/><line x1="2" y1="9" x2="22" y2="9"/></svg>',
              context_label
            )))
          ),
          div(class = "ce-card-title", row$title),
          div(class = "ce-card-key", paste0(row$module, " / ", row$key)),
          div(class = "ce-card-preview", preview)
        )
      })

      tagList(cards)
    })

    # Handle card selection
    observeEvent(input$select_callout, {
      sel <- input$select_callout
      selected(list(module = sel$module, key = sel$key))
    })

    # Render edit panel
    output$edit_panel <- renderUI({
      sel <- selected()
      if (is.null(sel)) {
        return(div(class = "ce-edit-placeholder",
          div(class = "ce-edit-placeholder-icon",
            HTML('<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#cbd5e1" stroke-width="1.5"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>')
          ),
          div(class = "ce-edit-placeholder-text", "Click a callout to edit"),
          div(class = "ce-edit-placeholder-hint", "Select any callout from the list to view and edit its title, text, and location")
        ))
      }

      reg <- registry()
      entry <- reg[[sel$module]][[sel$key]]
      if (is.null(entry)) {
        selected(NULL)
        return(NULL)
      }

      div(class = "ce-edit-panel",
        div(class = "ce-edit-header",
          div(class = "ce-edit-title",
            span(class = "ce-card-module", sel$module),
            span(style = "margin: 0 8px; color: #94a3b8;", "/"),
            span(sel$key)
          ),
          div(class = "ce-edit-actions",
            actionButton("save_callout", "Save", class = "ce-btn ce-btn-primary"),
            actionButton("delete_callout", "Delete", class = "ce-btn ce-btn-danger")
          )
        ),

        div(class = "ce-edit-body",
          div(class = "ce-field",
            tags$label("Title", class = "ce-label"),
            textInput("edit_title", NULL, value = entry$title, width = "100%")
          ),
          div(class = "ce-field-row",
            div(class = "ce-field", style = "flex: 1;",
              tags$label("Page / Tab", class = "ce-label"),
              # Selectize so the canonical seed pages for this module
              # (_meta.pages[module]) plus any other pages already used
              # in the registry surface as a dropdown. create=TRUE lets
              # the user type a brand-new page name (or sub-page using
              # "parent / child"); confirm_save will remember it via
              # remember_page() so it appears in future dropdowns.
              selectizeInput("edit_page", NULL,
                             choices = {
                               existing <- pages_for_module(reg, sel$module)
                               cur <- entry$page %||% ""
                               vals <- c("", union(existing,
                                                    if (nzchar(cur)) cur))
                               vals
                             },
                             selected = entry$page %||% "",
                             multiple = FALSE,
                             width = "100%",
                             options = list(
                               create = TRUE,
                               placeholder = "Pick an existing page or type a new one",
                               allowEmptyOption = TRUE
                             ))
            ),
            div(class = "ce-field", style = "flex: 2;",
              tags$label("Context", class = "ce-label"),
              textInput("edit_context", NULL, value = entry$context %||% "",
                        width = "100%",
                        placeholder = "Where on the page? (e.g. 'Results overview card')")
            )
          ),
          div(class = "ce-field ce-field-text",
            tags$label("Text (supports basic HTML: <strong>, <ul>, <li>, <p>)", class = "ce-label"),
            textAreaInput("edit_text", NULL,
                          value = entry$text,
                          width = "100%",
                          rows = 8,
                          resize = "vertical")
          ),

          # Live preview
          div(class = "ce-preview",
            div(class = "ce-preview-label", "Preview"),
            div(class = "ce-preview-callout",
              div(class = "ce-preview-header",
                span(class = "ce-preview-icon", "i"),
                span(class = "ce-preview-title", textOutput("preview_title", inline = TRUE)),
                span(class = "ce-preview-chevron", HTML("&#x25BC;"))
              ),
              div(class = "ce-preview-body",
                uiOutput("preview_body")
              )
            )
          )
        )
      )
    })

    # Live preview
    output$preview_title <- renderText({
      input$edit_title %||% ""
    })

    output$preview_body <- renderUI({
      txt <- input$edit_text %||% ""
      HTML(txt)
    })

    # Save callout
    observeEvent(input$save_callout, {
      sel <- selected()
      if (is.null(sel)) return()

      reg <- registry()
      page <- trimws(input$edit_page %||% "")
      reg[[sel$module]][[sel$key]] <- list(
        title = input$edit_title %||% "",
        text = input$edit_text %||% "",
        context = input$edit_context %||% "",
        page = page
      )
      # Remember any newly-typed page so it appears in the dropdown next
      # time someone opens this module.
      reg <- remember_page(reg, sel$module, page)

      write_registry(reg)
      registry(reg)
      save_msg(paste("Saved", sel$module, "/", sel$key, "at", format(Sys.time(), "%H:%M:%S")))
    })

    output$save_status <- renderText({ save_msg() })

    # Delete callout
    observeEvent(input$delete_callout, {
      sel <- selected()
      if (is.null(sel)) return()

      showModal(modalDialog(
        title = "Confirm Delete",
        sprintf("Delete callout '%s / %s'? This cannot be undone.", sel$module, sel$key),
        footer = tagList(
          modalButton("Cancel"),
          actionButton("confirm_delete", "Delete", class = "ce-btn ce-btn-danger")
        )
      ))
    })

    observeEvent(input$confirm_delete, {
      removeModal()
      sel <- selected()
      if (is.null(sel)) return()

      reg <- registry()
      reg[[sel$module]][[sel$key]] <- NULL
      # Remove empty module
      if (length(reg[[sel$module]]) == 0) reg[[sel$module]] <- NULL

      write_registry(reg)
      registry(reg)
      selected(NULL)
      save_msg(paste("Deleted", sel$module, "/", sel$key))
    })

    # Add callout
    observeEvent(input$add_btn, {
      reg <- registry()
      mods <- setdiff(names(reg), "_meta")
      if (length(mods) == 0) mods <- c("general")

      # Default to whatever module is currently filtered; otherwise the
      # first module. Using "all" — fall through to the first.
      default_mod <- if (!is.null(input$filter_module) &&
                         input$filter_module != "all" &&
                         input$filter_module %in% mods) {
        input$filter_module
      } else {
        mods[1]
      }

      # Pre-compute the page list for the default module so the Page
      # picker has options on first paint. The picker also updates
      # reactively in observeEvent(input$new_module) below.
      page_choices <- pages_for_module(reg, default_mod)

      showModal(modalDialog(
        title = "Add New Callout",
        div(class = "ce-add-form",
          selectInput("new_module", "Module",
                      choices = c(mods, "-- New module --" = "__new__"),
                      selected = default_mod,
                      width = "100%"),
          conditionalPanel(
            condition = "input.new_module == '__new__'",
            textInput("new_module_name", "New module name", width = "100%",
                      placeholder = "e.g. pricing")
          ),
          # Page picker — selectize with create=TRUE so the user can
          # either pick an existing page for this module or type a new
          # one. Choices come from _meta.pages[module] plus any pages
          # already in use, so the analyst doesn't have to guess names.
          selectizeInput("new_page", "Page / Tab",
                         choices = page_choices,
                         selected = NULL,
                         multiple = FALSE,
                         width = "100%",
                         options = list(
                           create = TRUE,
                           placeholder = "Pick a page from the list, or type a new one",
                           allowEmptyOption = TRUE
                         )),
          tags$p(class = "ce-add-hint",
                 tags$strong("Page"), " = which top-level tab the callout sits on (",
                 tags$code("funnel"), ", ", tags$code("mental_availability"),
                 ", ", tags$code("executive_summary"), "...). ",
                 "Use ", tags$code("parent / child"),
                 " for a sub-tab. ",
                 tags$strong("Context"),
                 " describes where on the page (e.g. ",
                 tags$code("Brand attitude card"), "). ",
                 "Typing a new page name here adds it to the dropdown for next time."),
          textInput("new_context", "Context",
                    width = "100%",
                    placeholder = "Where on the page? (e.g. 'Brand attitude card')"),
          textInput("new_key", "Callout key", width = "100%",
                    placeholder = "e.g. method_explanation (snake_case)"),
          textInput("new_title", "Title", width = "100%",
                    placeholder = "Heading shown in the callout")
        ),
        footer = tagList(
          modalButton("Cancel"),
          actionButton("confirm_add", "Create", class = "ce-btn ce-btn-primary")
        )
      ))
    })

    # Refresh the Page dropdown when the user changes Module inside the
    # Add Callout modal — pages are scoped to a module. Uses the shared
    # pages_for_module() helper so the seed list in _meta.pages and any
    # previously-typed pages both surface.
    observeEvent(input$new_module, {
      reg <- registry()
      mod <- input$new_module
      if (is.null(mod)) return()
      page_choices <- if (mod == "__new__") character(0) else pages_for_module(reg, mod)
      updateSelectizeInput(session, "new_page",
                           choices = page_choices,
                           selected = "",
                           options = list(
                             create = TRUE,
                             placeholder = "Pick an existing page or type a new one",
                             allowEmptyOption = TRUE
                           ))
    }, ignoreInit = TRUE)

    observeEvent(input$confirm_add, {
      removeModal()

      mod_name <- if (input$new_module == "__new__") {
        trimws(input$new_module_name %||% "")
      } else {
        input$new_module
      }
      key <- trimws(input$new_key %||% "")
      title <- trimws(input$new_title %||% "")
      page <- trimws(input$new_page %||% "")
      context <- trimws(input$new_context %||% "")

      if (!nzchar(mod_name) || !nzchar(key)) {
        save_msg("Error: Module and key are required")
        return()
      }

      reg <- registry()
      if (is.null(reg[[mod_name]])) reg[[mod_name]] <- list()
      if (!is.null(reg[[mod_name]][[key]])) {
        save_msg(sprintf("Error: %s/%s already exists", mod_name, key))
        return()
      }

      reg[[mod_name]][[key]] <- list(
        title = if (nzchar(title)) title else key,
        text = "Enter callout text here.",
        context = context,
        page = page
      )
      # Persist any newly-typed page into _meta.pages so future Add
      # Callout dialogs surface it in the dropdown.
      reg <- remember_page(reg, mod_name, page)

      write_registry(reg)
      registry(reg)
      selected(list(module = mod_name, key = key))
      save_msg(paste("Created", mod_name, "/", key))
    })
  }

  # ============================================================================
  # LAUNCH
  # ============================================================================
  cat("\n=== Launching Turas Callout Editor ===\n")
  cat(sprintf("Registry: %s\n\n", json_path))

  app <- shinyApp(ui = ui, server = server)
  shiny::runApp(app, launch.browser = TRUE)
}


# ==============================================================================
# CSS
# ==============================================================================

callout_editor_css <- function() {
  '
  @import url("https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap");

  body {
    font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: #f8f7f5;
    color: #1e293b;
    margin: 0;
    -webkit-font-smoothing: antialiased;
  }

  .ce-header {
    background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 60%, #1e3a5f 100%);
    border-bottom: 3px solid #1e3a5f;
    padding: 20px 32px;
  }
  .ce-header-inner { max-width: 1200px; margin: 0 auto; }
  .ce-header-title { color: #fff; font-size: 20px; font-weight: 700; letter-spacing: -0.3px; }
  .ce-header-subtitle {
    color: rgba(255,255,255,0.5); font-size: 11px; font-weight: 500;
    text-transform: uppercase; letter-spacing: 0.5px; margin-top: 2px;
  }

  .ce-content { max-width: 1300px; margin: 0 auto; padding: 24px; }

  .ce-controls {
    background: #fff; border: 1px solid #e2e8f0; border-radius: 10px;
    padding: 16px 20px; margin-bottom: 20px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.04);
  }
  .ce-filter-row {
    display: flex; align-items: flex-end; gap: 16px; flex-wrap: wrap;
  }
  .ce-filter-group { display: flex; flex-direction: column; gap: 4px; }
  .ce-spacer { flex: 1; }
  .ce-label { font-size: 11px; font-weight: 600; color: #64748b; text-transform: uppercase; letter-spacing: 0.5px; }

  .ce-btn {
    border: none; border-radius: 6px; padding: 8px 16px; font-size: 13px;
    font-weight: 600; cursor: pointer; font-family: inherit;
    transition: all 0.2s ease;
  }
  .ce-btn-primary { background: #1e3a5f; color: #fff; }
  .ce-btn-primary:hover { background: #2a4f7f; }
  .ce-btn-danger { background: #fee2e2; color: #dc2626; }
  .ce-btn-danger:hover { background: #fecaca; }

  .ce-save-status {
    font-size: 12px; color: #059669; font-weight: 500;
    padding: 8px 0; min-width: 200px;
  }

  .ce-count { font-size: 12px; color: #64748b; font-weight: 500; padding: 8px 0; }

  .ce-empty {
    text-align: center; padding: 60px 20px; color: #94a3b8;
    font-size: 14px;
  }

  /* Split layout */
  .ce-split {
    display: grid;
    grid-template-columns: 380px 1fr;
    gap: 20px;
    align-items: start;
  }
  @media (max-width: 900px) {
    .ce-split { grid-template-columns: 1fr; }
  }

  /* Card list */
  .ce-list-panel {
    max-height: calc(100vh - 200px);
    overflow-y: auto;
    padding-right: 4px;
  }
  .ce-card {
    background: #fff; border: 1px solid #e2e8f0; border-radius: 8px;
    padding: 12px 14px; margin-bottom: 6px; cursor: pointer;
    transition: all 0.15s ease;
  }
  .ce-card:hover { border-color: #cbd5e1; box-shadow: 0 2px 8px rgba(0,0,0,0.04); }
  .ce-card-selected { border-color: #1e3a5f; border-left: 3px solid #1e3a5f; background: #f8fafc; }

  .ce-card-header {
    display: flex; align-items: center; gap: 6px; margin-bottom: 4px;
    flex-wrap: wrap;
  }
  .ce-card-module {
    background: #eef2ff; color: #4338ca; font-size: 10px; font-weight: 700;
    padding: 2px 8px; border-radius: 4px; text-transform: uppercase; letter-spacing: 0.5px;
  }
  .ce-card-number {
    font-size: 10px; color: #94a3b8; font-weight: 600;
    background: #f1f5f9; padding: 1px 6px; border-radius: 3px;
  }
  .ce-card-page-tab {
    font-size: 10px; color: #1e6f50; font-weight: 600;
    background: #ecfdf5; border: 1px solid #bbf7d0; border-radius: 4px;
    padding: 1px 7px; letter-spacing: 0.3px;
  }
  .ce-card-page {
    font-size: 10px; color: #64748b; margin-left: auto;
    display: flex; align-items: center;
    background: #fef9f0; border: 1px solid #fde8c8; border-radius: 4px;
    padding: 1px 7px; font-weight: 500;
  }

  .ce-card-title { font-size: 13px; font-weight: 600; color: #1e293b; margin-bottom: 1px; }
  .ce-card-key {
    font-size: 10px; color: #b0b8c4; font-weight: 500;
    font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
    background: #f1f5f9; display: inline-block; padding: 1px 6px; border-radius: 3px;
    margin-bottom: 3px;
  }
  .ce-card-preview {
    font-size: 11px; color: #94a3b8; line-height: 1.4;
    display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
    overflow: hidden;
  }

  /* Edit area */
  .ce-edit-area { position: sticky; top: 20px; }

  .ce-edit-placeholder {
    background: #fff; border: 2px dashed #e2e8f0; border-radius: 10px;
    padding: 60px 20px; text-align: center;
  }
  .ce-edit-placeholder-icon { margin-bottom: 12px; }
  .ce-edit-placeholder-text { font-size: 16px; font-weight: 600; color: #94a3b8; margin-bottom: 4px; }
  .ce-edit-placeholder-hint { font-size: 13px; color: #cbd5e1; max-width: 300px; margin: 0 auto; }

  /* Edit panel */
  .ce-edit-panel {
    background: #fff; border: 1px solid #e2e8f0; border-radius: 10px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.04);
    overflow: hidden;
  }
  .ce-edit-header {
    display: flex; align-items: center; justify-content: space-between;
    padding: 14px 20px;
    background: #f8f9fb; border-bottom: 1px solid #e2e8f0;
  }
  .ce-edit-title { font-size: 14px; font-weight: 600; display: flex; align-items: center; }
  .ce-edit-actions { display: flex; gap: 8px; }

  .ce-edit-body { padding: 20px; }
  .ce-field { margin-bottom: 16px; }
  .ce-field .form-group { margin-bottom: 0; }
  .ce-field-row { display: flex; gap: 12px; margin-bottom: 16px; }
  .ce-field-row .ce-field { margin-bottom: 0; }

  .ce-field-text textarea.form-control {
    font-size: 13px; font-family: inherit; line-height: 1.6;
    color: #1e293b; padding: 10px 14px;
  }
  .ce-field-text .form-group { margin-bottom: 0; }

  /* Preview */
  .ce-preview {
    margin-top: 20px; padding-top: 16px; border-top: 1px solid #f1f5f9;
  }
  .ce-preview-label {
    font-size: 10px; font-weight: 700; text-transform: uppercase;
    letter-spacing: 0.5px; color: #94a3b8; margin-bottom: 10px;
  }
  .ce-preview-callout {
    background: #f8fafa; border-left: 3px solid #94a3b8;
    border-radius: 0 6px 6px 0; padding: 14px 16px;
  }
  .ce-preview-header { display: flex; align-items: center; gap: 8px; }
  .ce-preview-icon {
    width: 18px; height: 18px; border-radius: 50%; background: #94a3b8;
    color: #fff; font-size: 10px; font-weight: 700; display: flex;
    align-items: center; justify-content: center; flex-shrink: 0;
  }
  .ce-preview-title { font-size: 12px; font-weight: 600; color: #64748b; }
  .ce-preview-chevron { font-size: 8px; color: #94a3b8; margin-left: auto; }
  .ce-preview-body {
    margin-top: 8px; font-size: 13px; line-height: 1.65; color: #475569;
  }
  .ce-preview-body strong { font-weight: 600; }
  .ce-preview-body ul { margin: 6px 0; padding-left: 20px; }
  .ce-preview-body li { margin-bottom: 4px; }

  /* Add form */
  .ce-add-form .form-group { margin-bottom: 12px; }
  .ce-add-hint {
    font-size: 11px; color: #94a3b8; line-height: 1.4;
    margin: -4px 0 12px; font-style: italic;
  }
  .ce-add-hint code {
    background: #f1f5f9; padding: 1px 5px; border-radius: 3px;
    font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
    font-style: normal; color: #475569; font-size: 10.5px;
  }

  /* Override Shiny defaults */
  .form-control {
    border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px;
    font-family: inherit; color: #1e293b;
  }
  .form-control:focus { border-color: #1e3a5f; box-shadow: 0 0 0 2px rgba(30,58,95,0.1); }
  .selectize-input { border: 1px solid #e2e8f0 !important; border-radius: 6px !important; font-size: 13px !important; }
  .btn-default { border: 1px solid #e2e8f0; border-radius: 6px; font-family: inherit; }
  .modal-content { border-radius: 12px; }
  .modal-header { border-bottom: 1px solid #f1f5f9; }
  .modal-title { font-size: 16px; font-weight: 600; }
  '
}
