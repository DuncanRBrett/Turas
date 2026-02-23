#' Namespace Rewriter
#'
#' Prefixes DOM IDs, rewrites JS references, wraps JS in IIFEs,
#' and removes/redirects hub-managed features (save, print, pinned).
#' This prevents conflicts when multiple reports share one page.

#' Rewrite a Parsed Report for Hub Integration
#'
#' @param parsed Parsed report from parse_html_report()
#' @return Modified parsed report with namespaced IDs and JS
rewrite_for_hub <- function(parsed) {
  key <- parsed$report_key
  prefix <- paste0(key, "--")

  # --- Rewrite content panel HTML ---
  panels <- parsed$content_panels
  for (name in names(panels)) {
    panels[[name]] <- rewrite_html_ids(panels[[name]], prefix)
    panels[[name]] <- rewrite_html_onclick_conflicts(panels[[name]], key)
    panels[[name]] <- remove_save_print_buttons(panels[[name]])
  }
  parsed$content_panels <- panels

  # --- Rewrite report tab navigation ---
  if (!is.null(parsed$report_tabs$html) && nzchar(parsed$report_tabs$html)) {
    parsed$report_tabs$html <- rewrite_html_ids(parsed$report_tabs$html, prefix)
    # Rewrite switchReportTab calls to use namespaced version
    parsed$report_tabs$html <- gsub(
      "switchReportTab\\(",
      sprintf("ReportHub.switchSubTab('%s',", key),
      parsed$report_tabs$html
    )
  }

  # --- Rewrite header ---
  if (nzchar(parsed$header)) {
    parsed$header <- rewrite_html_ids(parsed$header, prefix)
  }

  # --- Rewrite footer ---
  if (nzchar(parsed$footer)) {
    parsed$footer <- rewrite_html_ids(parsed$footer, prefix)
  }

  # --- Rewrite CSS ---
  for (i in seq_along(parsed$css_blocks)) {
    parsed$css_blocks[[i]]$content <- rewrite_css_ids(
      parsed$css_blocks[[i]]$content, prefix
    )
  }

  # --- Rewrite JS blocks ---
  for (i in seq_along(parsed$js_blocks)) {
    parsed$js_blocks[[i]]$content <- rewrite_js_ids(
      parsed$js_blocks[[i]]$content, prefix
    )
    parsed$js_blocks[[i]]$content <- redirect_pin_functions(
      parsed$js_blocks[[i]]$content, key
    )
    parsed$js_blocks[[i]]$content <- redirect_save_functions(
      parsed$js_blocks[[i]]$content
    )
  }

  # --- Wrap all JS in an IIFE namespace ---
  parsed$wrapped_js <- wrap_js_in_iife(parsed$js_blocks, key, parsed$report_type)

  # --- Rewrite data scripts ---
  for (i in seq_along(parsed$data_scripts)) {
    if (!is.null(parsed$data_scripts[[i]]$id)) {
      old_id <- parsed$data_scripts[[i]]$id
      new_id <- paste0(prefix, old_id)
      parsed$data_scripts[[i]]$id <- new_id
      parsed$data_scripts[[i]]$open_tag <- gsub(
        sprintf('id="%s"', old_id),
        sprintf('id="%s"', new_id),
        parsed$data_scripts[[i]]$open_tag
      )
    }
  }

  return(parsed)
}


#' Rewrite HTML id Attributes with Prefix
#'
#' @param html HTML string
#' @param prefix Prefix to add (e.g., "tracker--")
#' @return Modified HTML
rewrite_html_ids <- function(html, prefix) {
  # Known IDs that need prefixing (from conflict analysis)
  # We prefix ALL ids to be safe, not just the conflicting ones
  html <- gsub(
    'id="([^"]+)"',
    sprintf('id="%s\\1"', prefix),
    html
  )

  # Also rewrite href="#id" links
  html <- gsub(
    'href="#([^"]+)"',
    sprintf('href="#%s\\1"', prefix),
    html
  )

  # Rewrite for="id" on labels
  html <- gsub(
    'for="([^"]+)"',
    sprintf('for="%s\\1"', prefix),
    html
  )

  return(html)
}


#' Rewrite CSS ID Selectors with Prefix
#'
#' @param css CSS string
#' @param prefix Prefix to add
#' @return Modified CSS
rewrite_css_ids <- function(css, prefix) {
  # Rewrite #id selectors — match #word-chars but not hex colours
  # CSS ID selectors: #name { ... } or #name.class or #name:pseudo
  # Hex colours: #fff, #abcdef — always 3, 4, 6, or 8 hex digits
  # Strategy: replace #id patterns that are followed by a selector character

  # Split CSS into lines for safer processing
  lines <- strsplit(css, "\n")[[1]]
  result <- character(length(lines))

  for (i in seq_along(lines)) {
    line <- lines[i]

    # Skip lines that are inside property values (contain : before #)
    # These are likely colour values
    if (grepl(":\\s*#", line) && !grepl("^\\s*#", line)) {
      result[i] <- line
      next
    }

    # Replace #id patterns in selector context
    # Match #identifier where identifier starts with a letter or hyphen
    result[i] <- gsub(
      "#([a-zA-Z][a-zA-Z0-9_-]*)",
      paste0("#", prefix, "\\1"),
      line
    )
  }

  return(paste(result, collapse = "\n"))
}


#' Rewrite JS String References to DOM IDs
#'
#' @param js JavaScript string
#' @param prefix Prefix to add
#' @return Modified JavaScript
rewrite_js_ids <- function(js, prefix, report_key = NULL) {
  if (is.null(report_key)) report_key <- sub("--$", "", prefix)
  # getElementById('id') and getElementById("id")
  js <- gsub(
    "getElementById\\(['\"]([^'\"]+)['\"]\\)",
    sprintf("getElementById('%s\\1')", prefix),
    js
  )

  # querySelector('#id') and querySelector("#id")
  js <- gsub(
    "querySelector\\(['\"]#([^'\"]+)['\"]\\)",
    sprintf("querySelector('#%s\\1')", prefix),
    js
  )

  # querySelectorAll with ID selectors (less common but possible)
  js <- gsub(
    "querySelectorAll\\(['\"]#([^'\"]+)['\"]\\)",
    sprintf("querySelectorAll('#%s\\1')", prefix),
    js
  )

  # Rewrite switchReportTab CALLS within JS (not the function definition)
  # Match calls: switchReportTab( but NOT: function switchReportTab(
  js <- gsub(
    "(?<!function )switchReportTab\\(",
    sprintf("ReportHub.switchSubTab('%s',", report_key),
    js,
    perl = TRUE
  )

  return(js)
}


#' Redirect Pin-Related Functions to ReportHub
#'
#' @param js JavaScript string
#' @param report_key Report key
#' @return Modified JavaScript
redirect_pin_functions <- function(js, report_key) {
  # These functions should call through to ReportHub instead of operating locally

  # updatePinBadge() -> ReportHub.updatePinBadge()
  js <- gsub(
    "(?<![.a-zA-Z])updatePinBadge\\(",
    "ReportHub.updatePinBadge(",
    js,
    perl = TRUE
  )

  # savePinnedData() -> ReportHub.savePinnedData()
  js <- gsub(
    "(?<![.a-zA-Z])savePinnedData\\(",
    "ReportHub.savePinnedData(",
    js,
    perl = TRUE
  )

  return(js)
}


#' Redirect Save/Print Functions
#'
#' @param js JavaScript string
#' @return Modified JavaScript
redirect_save_functions <- function(js) {
  # saveReportHTML() -> ReportHub.saveReportHTML()
  js <- gsub(
    "(?<![.a-zA-Z])saveReportHTML\\(",
    "ReportHub.saveReportHTML(",
    js,
    perl = TRUE
  )

  return(js)
}


#' Rewrite Inline onclick Handlers for Conflicting Functions
#'
#' Prefixes conflicting function names in onclick/onchange/onblur attributes
#' so they call the report-specific version.
#'
#' @param html HTML string
#' @param report_key Report key for prefixing
#' @return Modified HTML
rewrite_html_onclick_conflicts <- function(html, report_key) {
  prefix <- paste0(report_key, "_")

  # Functions that conflict and appear in onclick handlers
  conflict_fns <- c(
    "togglePin",
    "updatePinButton",
    "renderPinnedCards",
    "removePinned",
    "movePinned",
    "exportSlidePNG",
    "printReport",
    "toggleHelpOverlay",
    "exportChartPNG",
    "exportCSV",
    "exportExcel",
    "exportAllPinsPNG",
    "printAllPins",
    "saveReportHTML",
    "hydratePinnedViews"
  )

  for (fn in conflict_fns) {
    # Match function calls within attribute values (onclick="...", onchange="...", etc.)
    # Pattern: the function name followed by ( but not preceded by a letter/dot
    html <- gsub(
      sprintf('(?<=["\';, ])%s\\(', fn),
      sprintf('%s%s(', prefix, fn),
      html,
      perl = TRUE
    )
    # Also handle case where function is at the start of the attribute value
    html <- gsub(
      sprintf('onclick="%s\\(', fn),
      sprintf('onclick="%s%s(', prefix, fn),
      html,
      fixed = FALSE
    )
    html <- gsub(
      sprintf("onclick='%s\\(", fn),
      sprintf("onclick='%s%s(", prefix, fn),
      html,
      fixed = FALSE
    )
  }

  return(html)
}


#' Remove Save and Print Buttons from HTML
#'
#' @param html HTML string
#' @return Modified HTML with save/print buttons removed
remove_save_print_buttons <- function(html) {
  # Remove buttons that call saveReportHTML
  html <- gsub(
    '<button[^>]*onclick="[^"]*saveReportHTML[^"]*"[^>]*>[^<]*</button>',
    '',
    html
  )

  # Remove buttons that call printReport
  html <- gsub(
    '<button[^>]*onclick="[^"]*printReport[^"]*"[^>]*>[^<]*</button>',
    '',
    html
  )

  # Remove buttons that call printAllPins or printPinnedViews
  html <- gsub(
    '<button[^>]*onclick="[^"]*print(AllPins|PinnedViews)[^"]*"[^>]*>[^<]*</button>',
    '',
    html
  )

  return(html)
}


#' Prefix Conflicting JS Functions and Variables
#'
#' Instead of IIFE wrapping (which breaks inline onclick handlers),
#' we prefix only the functions/variables that actually collide between
#' tracker and tabs. Non-conflicting functions remain global.
#'
#' @param js_blocks List of JS block objects from parser
#' @param report_key Report key (e.g., "tracker")
#' @param report_type "tracker" or "tabs"
#' @return Single JS string with prefixed conflicts
wrap_js_in_iife <- function(js_blocks, report_key, report_type) {
  # Combine all JS content
  all_js <- paste(
    sapply(js_blocks, function(b) b$content),
    collapse = "\n\n"
  )

  # Prefix conflicting global function definitions and their calls
  # These are functions that exist in BOTH tracker and tabs with different implementations
  conflicting_fns <- c(
    "togglePin",
    "updatePinButton",
    "renderPinnedCards",
    "movePinned",
    "removePinned",
    "hydratePinnedViews",
    "exportSlidePNG",
    "printReport",
    "toggleHelpOverlay",
    "escapeHtml",
    "downloadBlob",
    "exportChartPNG",
    "exportCSV",
    "exportExcel",
    "pinnedViews"
  )

  prefix <- paste0(report_key, "_")

  for (fn in conflicting_fns) {
    # Prefix function definitions: function fnName( -> function prefix_fnName(
    all_js <- gsub(
      sprintf("function %s\\(", fn),
      sprintf("function %s%s(", prefix, fn),
      all_js
    )
    # Prefix var/let/const declarations: var fnName = -> var prefix_fnName =
    all_js <- gsub(
      sprintf("(var|let|const)\\s+%s\\b", fn),
      sprintf("\\1 %s%s", prefix, fn),
      all_js
    )
    # Prefix standalone calls: fnName( -> prefix_fnName(
    # But NOT when preceded by . (method call) or another letter (substring)
    all_js <- gsub(
      sprintf("(?<![.a-zA-Z_])%s(?=\\(|\\s*=|\\[|\\.|\\s*;|\\s*\\))", fn),
      sprintf("%s%s", prefix, fn),
      all_js,
      perl = TRUE
    )
  }

  # Also create a namespace object for the public API
  namespace_name <- if (report_type == "tracker") "TrackerReport" else "TabsReport"

  api_js <- build_namespace_api(namespace_name, report_key, report_type)

  return(paste0(all_js, "\n\n", api_js))
}


#' Build Namespace API Object
#'
#' Creates a convenience object that other code can use to call
#' report-specific functions without knowing the prefix.
#'
#' @param namespace_name "TrackerReport" or "TabsReport"
#' @param report_key "tracker" or "tabs"
#' @param report_type "tracker" or "tabs"
#' @return JavaScript string defining the namespace object
build_namespace_api <- function(namespace_name, report_key, report_type) {
  prefix <- paste0(report_key, "_")

  if (report_type == "tracker") {
    sprintf('
var %s = {
  selectMetric: typeof selectTrackerMetric === "function" ? selectTrackerMetric : function() {},
  togglePin: typeof %stogglePin === "function" ? %stogglePin : function() {},
  toggleHelpOverlay: typeof %stoggleHelpOverlay === "function" ? %stoggleHelpOverlay : function() {}
};
', namespace_name, prefix, prefix, prefix, prefix)
  } else {
    sprintf('
var %s = {
  selectQuestion: typeof selectQuestion === "function" ? selectQuestion : function() {},
  togglePin: typeof %stogglePin === "function" ? %stogglePin : function() {},
  toggleHelpOverlay: typeof %stoggleHelpOverlay === "function" ? %stoggleHelpOverlay : function() {}
};
', namespace_name, prefix, prefix, prefix, prefix)
  }
}
