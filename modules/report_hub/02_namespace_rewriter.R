#' Namespace Rewriter
#'
#' Prefixes DOM IDs, rewrites JS references, wraps JS in IIFEs,
#' and removes/redirects hub-managed features (save, print, pinned).
#' This prevents conflicts when multiple reports share one page.

#' Rewrite a Parsed Report for Hub Integration
#'
#' @param parsed Parsed report from parse_html_report()
#' @param report_label Human-readable label for source identification in pins
#' @return Modified parsed report with namespaced IDs and JS
rewrite_for_hub <- function(parsed, report_label = NULL) {
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

  # --- Rewrite help overlay ---
  if (!is.null(parsed$help_overlay) && nzchar(parsed$help_overlay)) {
    parsed$help_overlay <- rewrite_html_ids(parsed$help_overlay, prefix)
    parsed$help_overlay <- rewrite_html_onclick_conflicts(parsed$help_overlay, key)
  }

  # --- Rewrite CSS ---
  for (i in seq_along(parsed$css_blocks)) {
    parsed$css_blocks[[i]]$content <- rewrite_css_ids(
      parsed$css_blocks[[i]]$content, prefix
    )
  }

  # --- Collect data script ID mappings (before modifying HTML) ---
  data_id_map <- list()
  for (i in seq_along(parsed$data_scripts)) {
    if (!is.null(parsed$data_scripts[[i]]$id)) {
      old_id <- parsed$data_scripts[[i]]$id
      data_id_map[[old_id]] <- paste0(prefix, old_id)
    }
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
    # Rewrite data script ID string literals so each report finds its own data
    for (old_id in names(data_id_map)) {
      new_id <- data_id_map[[old_id]]
      parsed$js_blocks[[i]]$content <- gsub(
        sprintf('"%s"', old_id), sprintf('"%s"', new_id),
        parsed$js_blocks[[i]]$content, fixed = TRUE
      )
      parsed$js_blocks[[i]]$content <- gsub(
        sprintf("'%s'", old_id), sprintf("'%s'", new_id),
        parsed$js_blocks[[i]]$content, fixed = TRUE
      )
    }
  }

  # --- Wrap all JS in an IIFE namespace ---
  parsed$wrapped_js <- wrap_js_in_iife(parsed$js_blocks, key, parsed$report_type, report_label)

  # --- Rewrite data scripts (HTML elements) ---
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
  # Prefix standalone id= attributes (not data-*-id= etc.)
  # Require whitespace before "id=" to avoid matching substrings like data-metric-id=
  html <- gsub(
    '(\\s)id="([^"]+)"',
    sprintf('\\1id="%s\\2"', prefix),
    html
  )

  # Also rewrite href="#id" links
  html <- gsub(
    '(\\s)href="#([^"]+)"',
    sprintf('\\1href="#%s\\2"', prefix),
    html
  )

  # Rewrite for="id" on labels (avoid matching data-*-for= etc.)
  html <- gsub(
    '(\\s)for="([^"]+)"',
    sprintf('\\1for="%s\\2"', prefix),
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
  # Strategy: only match identifiers containing at least one hyphen or underscore.
  # All Turas IDs have hyphens/underscores (tab-summary, mv-metric_1, etc.)
  # while hex colours (#e2e8f0, #ccc, #fff) never do.
  gsub(
    "#([a-zA-Z][a-zA-Z0-9_-]*[-_][a-zA-Z0-9_-]*)",
    paste0("#", prefix, "\\1"),
    css
  )
}


#' Rewrite JS References for Hub Integration
#'
#' Redirects tab-switching calls to the hub's navigation controller.
#' DOM ID resolution is handled at runtime by hub_id_resolver.js,
#' so we do NOT rewrite getElementById/querySelector patterns here.
#'
#' @param js JavaScript string
#' @param prefix Prefix string (e.g., "tracker--")
#' @param report_key Report key (e.g., "tracker")
#' @return Modified JavaScript
rewrite_js_ids <- function(js, prefix, report_key = NULL) {
  if (is.null(report_key)) report_key <- sub("--$", "", prefix)

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
  # Skip function declarations (function updatePinBadge) and method calls (.updatePinBadge)
  js <- gsub(
    "(?<!function )(?<![.a-zA-Z])updatePinBadge\\(",
    "ReportHub.updatePinBadge(",
    js,
    perl = TRUE
  )

  # savePinnedData() -> ReportHub.savePinnedData()
  js <- gsub(
    "(?<!function )(?<![.a-zA-Z])savePinnedData\\(",
    "ReportHub.savePinnedData(",
    js,
    perl = TRUE
  )

  # Fix tabs captureCurrentView: only capture chart SVG if chart-wrapper is visible
  # (toggleChart sets display:none on .chart-wrapper when charts are hidden)
  js <- gsub(
    'var chartSvg = wrapper ? wrapper.querySelector("svg") : null;',
    'var chartSvg = (wrapper && wrapper.style.display !== "none") ? wrapper.querySelector("svg") : null;',
    js, fixed = TRUE
  )

  return(js)
}


#' Redirect Save/Print Functions
#'
#' @param js JavaScript string
#' @return Modified JavaScript
redirect_save_functions <- function(js) {
  # saveReportHTML() -> ReportHub.saveReportHTML()
  # Skip function declarations (function saveReportHTML) and method calls
  js <- gsub(
    "(?<!function )(?<![.a-zA-Z])saveReportHTML\\(",
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

  # Functions that appear in inline HTML handlers (onclick, onchange, oninput, ondblclick).
  # Must be prefixed in both JS definitions AND HTML attributes.
  conflict_fns <- c(
    # --- Pin/export functions ---
    "togglePin",
    "updatePinButton",
    "renderPinnedCards",
    "removePinned",
    "movePinned",
    "addSection",
    "updateSectionTitle",
    "exportSlidePNG",
    "printReport",
    "toggleHelpOverlay",
    "exportChartPNG",
    "exportCSV",
    "exportExcel",
    "exportAllPinsPNG",
    "printAllPins",
    "saveReportHTML",
    "hydratePinnedViews",
    # V10.7.0 sig findings toggle/pin + qualitative slides
    "toggleSigCard",
    "pinSigCard",
    "pinVisibleSigFindings",
    "saveSigCardStates",
    "hydrateSigCardStates",
    "renderMarkdown",
    "addQualSlide",
    "removeQualSlide",
    "moveQualSlide",
    "pinQualSlide",
    "toggleQualEdit",
    "renderAllQualSlides",
    "triggerQualImage",
    "handleQualImage",
    "removeQualImage",
    # --- Insight editing (onclick/ondblclick/oninput in insight-area HTML) ---
    "toggleInsight",
    "toggleInsightEdit",
    "dismissInsight",
    "syncInsight",
    # --- Navigation/display (called from onchange/oninput/onclick in HTML) ---
    "selectQuestion",
    "switchBannerGroup",
    "filterQuestions",
    "toggleCategoryGroup",
    "toggleChart",
    "toggleHeatmap",
    "toggleFrequency",
    "toggleColumn",
    "toggleRowExclusion",
    "toggleAllRows",
    "toggleGaugeExclude",
    "toggleDashEdit",
    "pinDashboardText",
    "pinGaugeSection",
    "pinSigFindings",
    "exportHeatmapExcel",
    "exportSigFindingsSlide",
    "exportAllPinnedSlides",
    "printPinnedViews",
    "exportPinnedCardPNG",
    "toggleSlideMenu",
    # --- Segment filter (tabs summary page) ---
    "filterSigBySegment",
    # --- Conjoint-specific ---
    "switchChartType",
    "addSlide",
    "switchSlide",
    "switchSimMode",
    # --- Pricing-specific ---
    "exportTableExcel",
    "addPrSlide",
    "movePrSlide",
    "removePrSlide",
    "pinView",
    "exportAllPinned",
    "switchTab",
    # --- Segment-specific ---
    "segToggleHelp",
    "segSaveReportHTML",
    "segAddSlide",
    "segAddSection",
    "segPinComponent",
    "segDismissInsight",
    "segMovePinned",
    "segRemovePinned",
    "segClearAllPinned",
    "segExportAllPinnedPNG",
    "segExportAllSlidesPNG",
    "segExportPinnedCardPNG"
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
    # Cover all event handler attributes: onclick, oninput, onchange, ondblclick
    for (attr in c("onclick", "oninput", "onchange", "ondblclick")) {
      html <- gsub(
        sprintf('%s="%s\\(', attr, fn),
        sprintf('%s="%s%s(', attr, prefix, fn),
        html,
        fixed = FALSE
      )
      html <- gsub(
        sprintf("%s='%s\\(", attr, fn),
        sprintf("%s='%s%s(", attr, prefix, fn),
        html,
        fixed = FALSE
      )
    }
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


#' Get List of Conflicting JS Function/Variable Names
#'
#' Returns the canonical list of JS function and variable names that must
#' be prefixed when combining multiple reports. These are global names that
#' would collide when two reports of the same or different types share a page.
#'
#' @return Character vector of function/variable names
#' @keywords internal
.get_conflicting_js_names <- function() {
  c(
    # --- Global state variables (collide when multiple tabs reports combined) ---
    "bannerGroups",
    "currentGroup",
    "heatmapEnabled",
    "hiddenColumns",
    "sortState",
    "originalRowOrder",
    "excludedRows",
    # --- Pin/export functions (shared between tracker and tabs) ---
    "togglePin",
    "updatePinButton",
    "renderPinnedCards",
    "movePinned",
    "removePinned",
    "hydratePinnedViews",
    "addSection",
    "updateSectionTitle",
    "exportSlidePNG",
    "printReport",
    "toggleHelpOverlay",
    "escapeHtml",
    "downloadBlob",
    "exportChartPNG",
    "exportCSV",
    "exportExcel",
    "pinnedViews",
    "switchReportTab",
    "printAllPins",
    "exportAllPinsPNG",
    "saveReportHTML",
    # V10.7.0 sig findings toggle/pin + qualitative slides
    "toggleSigCard",
    "pinSigCard",
    "pinVisibleSigFindings",
    "saveSigCardStates",
    "hydrateSigCardStates",
    "renderMarkdown",
    "addQualSlide",
    "removeQualSlide",
    "moveQualSlide",
    "pinQualSlide",
    "toggleQualEdit",
    "renderAllQualSlides",
    "triggerQualImage",
    "handleQualImage",
    "removeQualImage",
    # --- Core navigation (conflict when multiple tabs reports combined) ---
    "selectQuestion",
    "switchBannerGroup",
    "filterQuestions",
    "toggleCategoryGroup",
    "captureCurrentView",
    # --- Display toggles ---
    "toggleChart",
    "toggleHeatmap",
    "toggleFrequency",
    "toggleColumn",
    "toggleRowExclusion",
    "toggleAllRows",
    "toggleGaugeExclude",
    "buildColumnChips",
    "sortByColumn",
    "sortChartBars",
    "initSortHeaders",
    # --- Dashboard text / insight editing ---
    "toggleDashEdit",
    "toggleInsight",
    "toggleInsightEdit",
    "dismissInsight",
    "syncInsight",
    "syncAllInsights",
    "hydrateInsights",
    "updateInsightsForBanner",
    "pinDashboardText",
    "pinGaugeSection",
    "pinSigFindings",
    # --- Chart picker ---
    "initChartColumnPickers",
    "buildChartPickersForGroup",
    "toggleChartColumn",
    "rebuildChartSVG",
    "rebuildChartWithExclusions",
    # --- Utility functions used by navigation ---
    "getActiveBannerName",
    "getLabelText",
    "getInsightStore",
    "setInsightStore",
    "extractTableData",
    "escapeXml",
    # --- Additional export functions ---
    "exportHeatmapExcel",
    "exportSigFindingsSlide",
    "exportAllPinnedSlides",
    "printPinnedViews",
    "exportPinnedCardPNG",
    "toggleSlideMenu",
    "exportInsightsHTML",
    # --- Segment filter (tabs summary page) ---
    "filterSigBySegment",
    # --- Conjoint-specific ---
    "switchChartType",
    "addSlide",
    "switchSlide",
    "switchSimMode",
    # --- Pricing-specific ---
    "exportTableExcel",
    "addPrSlide",
    "movePrSlide",
    "removePrSlide",
    "pinView",
    "exportAllPinned",
    "switchTab",
    # --- Segment-specific ---
    "segToggleHelp",
    "segSaveReportHTML",
    "segAddSlide",
    "segAddSection",
    "segPinComponent",
    "segDismissInsight",
    "segMovePinned",
    "segRemovePinned",
    "segClearAllPinned",
    "segExportAllPinnedPNG",
    "segExportAllSlidesPNG",
    "segExportPinnedCardPNG"
  )
}


#' Prefix JS Function Definitions, Declarations, and References
#'
#' Applies report-key prefixing to all conflicting function/variable names
#' in a combined JS string. Handles function definitions, var/let/const
#' declarations, window.* assignments, and standalone references.
#'
#' @param js Combined JS string
#' @param prefix Prefix to apply (e.g., "tracker_")
#' @param fn_names Character vector of function/variable names to prefix
#' @return Modified JS string
#' @keywords internal
.prefix_js_functions <- function(js, prefix, fn_names) {
  for (fn in fn_names) {
    # Prefix function definitions: function fnName( -> function prefix_fnName(
    js <- gsub(
      sprintf("function %s\\(", fn),
      sprintf("function %s%s(", prefix, fn),
      js
    )
    # Prefix var/let/const declarations: var fnName = -> var prefix_fnName =
    js <- gsub(
      sprintf("(var|let|const)\\s+%s\\b", fn),
      sprintf("\\1 %s%s", prefix, fn),
      js
    )
    # Prefix window.fnName assignments: window.fnName -> window.prefix_fnName
    # CRITICAL: Must keep "window." prefix! Without it, strict-mode IIFEs
    # throw ReferenceError on bare assignments (e.g., tracker_fn = function(){})
    # and non-strict IIFEs lose global exposure (variable stays IIFE-local).
    js <- gsub(
      sprintf("window\\.%s\\b", fn),
      sprintf("window.%s%s", prefix, fn),
      js
    )
    # Prefix standalone references: fnName -> prefix_fnName
    # Match when NOT preceded by . or identifier char (prevents matching
    # inside obj.fnName or longerFnName) and NOT followed by identifier char
    # (prevents matching fnNameExtra).
    js <- gsub(
      sprintf("(?<![.a-zA-Z_])%s(?![a-zA-Z0-9_])", fn),
      sprintf("%s%s", prefix, fn),
      js,
      perl = TRUE
    )
  }
  js
}


#' Build Scoped DOM Helper Functions for a Report
#'
#' Generates JavaScript helper functions that scope DOM queries
#' (getElementById, querySelector, querySelectorAll) to a specific
#' report panel within the hub. Also rewrites bare document.* calls
#' in the JS string to use these helpers.
#'
#' @param js Combined JS string (already function-prefixed)
#' @param report_key Report key (e.g., "tracker")
#' @return Modified JS string with helpers prepended and DOM calls rewritten
#' @keywords internal
.build_dom_helpers <- function(js, report_key) {
  id_prefix <- paste0(report_key, "--")
  helper_id <- paste0("_", report_key, "_id")
  helper_qs <- paste0("_", report_key, "_qs")
  helper_qsa <- paste0("_", report_key, "_qsa")

  # IMPORTANT: Replace querySelectorAll BEFORE querySelector to avoid substring collision
  js <- gsub("document.querySelectorAll(", paste0(helper_qsa, "("), js, fixed = TRUE)
  js <- gsub("document.getElementById(", paste0(helper_id, "("), js, fixed = TRUE)
  js <- gsub("document.querySelector(", paste0(helper_qs, "("), js, fixed = TRUE)

  # Prepend scoped helper functions
  # _qs and _qsa search within the report's hub panel FIRST to prevent
  # cross-report collisions
  helpers_js <- sprintf(
    'var %1$s = function(id) { return document.getElementById(id) || document.getElementById("%2$s" + id); };
var _%7$s_panel = function() { return document.querySelector(\'[data-hub-panel="%7$s"]\'); };
var %3$s = function(sel) { var p = _%7$s_panel(); if (p) { var el = p.querySelector(sel); if (el) return el; } var el = document.querySelector(sel); if (el) return el; if (sel.indexOf("#") === -1) return null; var pSel = sel.replace(/#([a-zA-Z][\\w-]*)/g, "#%4$s$1"); if (p) { var el2 = p.querySelector(pSel); if (el2) return el2; } return document.querySelector(pSel); };
var %5$s = function(sel) { var p = _%7$s_panel(); if (p) { var els = p.querySelectorAll(sel); if (els.length > 0) return els; } var els = document.querySelectorAll(sel); if (els.length > 0 || sel.indexOf("#") === -1) return els; var pSel = sel.replace(/#([a-zA-Z][\\w-]*)/g, "#%6$s$1"); if (p) { var els2 = p.querySelectorAll(pSel); if (els2.length > 0) return els2; } return document.querySelectorAll(pSel); };
',
    helper_id, id_prefix, helper_qs, id_prefix, helper_qsa, id_prefix, report_key
  )

  paste0(helpers_js, "\n", js)
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
#' @param report_label Human-readable label for source identification in pins
#' @return Single JS string with prefixed conflicts
wrap_js_in_iife <- function(js_blocks, report_key, report_type, report_label = NULL) {
  # Combine all JS content
  all_js <- paste(
    sapply(js_blocks, function(b) b$content),
    collapse = "\n\n"
  )

  # Step 1: Prefix conflicting function/variable names
  prefix <- paste0(report_key, "_")
  all_js <- .prefix_js_functions(all_js, prefix, .get_conflicting_js_names())

  # Step 2: Rewrite DOM queries and prepend scoped helpers
  all_js <- .build_dom_helpers(all_js, report_key)

  # Step 3: Build namespace API object
  namespace_name <- switch(report_type,
    tracker = "TrackerReport",
    tabs = "TabsReport",
    maxdiff = "MaxDiffReport",
    conjoint = "ConjointReport",
    pricing = "PricingReport",
    segment = "SegmentReport",
    catdriver = "CatDriverReport",
    keydriver = "KeyDriverReport",
    confidence = "ConfidenceReport",
    weighting = "WeightingReport",
    "TabsReport"  # fallback
  )
  api_js <- build_namespace_api(namespace_name, report_key, report_type)

  # Step 4: Build pin bridge
  bridge_js <- build_pin_bridge(report_key, report_type, report_label)

  return(paste0(all_js, "\n\n", api_js, "\n\n", bridge_js))
}


#' Build Pin Bridge for Hub Integration
#'
#' Generates JavaScript that overrides per-report pin functions to route
#' pins through the hub's unified store (ReportHub.pinnedItems) instead
#' of the local per-report arrays. Dispatches to type-specific builders.
#'
#' @param report_key "tracker" or "tabs"
#' @param report_type "tracker" or "tabs"
#' @param report_label Human-readable label for source identification in pins
#' @return JavaScript string with bridge functions
build_pin_bridge <- function(report_key, report_type, report_label = NULL) {
  prefix <- paste0(report_key, "_")
  id_helper <- paste0("_", report_key, "_id")
  qs_helper <- paste0("_", report_key, "_qs")
  # Escape label for safe JS string embedding
  label_js <- if (!is.null(report_label)) gsub("'", "\\\\'", report_label) else report_key

  if (report_type == "tracker") {
    .build_tracker_pin_bridge(prefix, id_helper, qs_helper, label_js, report_key)
  } else if (report_type == "tabs") {
    .build_tabs_pin_bridge(prefix, id_helper, qs_helper, label_js, report_key)
  } else {
    .build_generic_pin_bridge(prefix, id_helper, qs_helper, label_js, report_key)
  }
}


#' Build Tracker Pin Bridge JavaScript
#'
#' Generates tracker-specific pin bridge functions that override per-report
#' pin functions (pinMetricView, pinSummarySection, pinOverviewView, etc.)
#' to route through the hub's unified store.
#'
#' @param prefix Report prefix (e.g., "tracker_")
#' @param id_helper Name of the getElementById helper (e.g., "_tracker_id")
#' @param qs_helper Name of the querySelector helper (e.g., "_tracker_qs")
#' @param label_js Escaped report label for JS embedding
#' @param report_key Report key (e.g., "tracker")
#' @return JavaScript string
#' @keywords internal
.build_tracker_pin_bridge <- function(prefix, id_helper, qs_helper, label_js, report_key) {
  sprintf('
// ===== Hub Pin Bridge \u2014 Tracker =====
// Override per-report pin functions to route through hub store
// Use report-specific variable name to prevent global collision
var _hubSrcLbl_%5$s = \'%4$s\';
pinMetricView = function(metricId) {
  // Always add a new pin (multi-pin support).
  // Each pin captures the current view state (visible segments, chart, table).
  var pinObj = captureMetricView(metricId);
  if (!pinObj) return;
  pinObj.title = pinObj.metricTitle || metricId;
  pinObj.insight = pinObj.insightText || "";
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
};
pinSummarySection = function(sectionType) {
  var editorId = sectionType === "background" ? "summary-background-editor" : "summary-findings-editor";
  var editor = %2$s(editorId);
  if (!editor || !editor.innerHTML.trim()) { alert("Add content before pinning."); return; }
  var title = sectionType === "background" ? "Background & Method" : "Summary";
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    metricId: "summary-" + sectionType,
    title: title, insight: editor.innerHTML,
    tableHtml: "", chartSvg: "", timestamp: Date.now()
  };
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
};
pinSummaryTable = function() {
  var table = %2$s("summary-metrics-table");
  if (!table) return;
  var clone = table.cloneNode(true);
  clone.querySelectorAll("tr").forEach(function(tr) { if (tr.style.display === "none") tr.parentNode.removeChild(tr); });
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    metricId: "summary-metrics-table",
    title: "Summary Metrics Overview", insight: "",
    tableHtml: \'<div class="tk-table-wrapper">\' + clone.outerHTML + \'</div>\',
    chartSvg: "", timestamp: Date.now()
  };
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
};
pinOverviewView = function() {
  var tablePanel = %3$s("#tab-overview .tk-table-panel");
  var chartPanel = %2$s("tk-chart-panel");
  var insightEditor = %2$s("overview-insight-editor");
  var cleanHtml = "";
  if (tablePanel && tablePanel.style.display !== "none") {
    var clone = tablePanel.cloneNode(true);
    clone.querySelectorAll(".segment-hidden").forEach(function(el) { el.parentNode.removeChild(el); });
    clone.querySelectorAll(".row-hidden-user").forEach(function(el) { el.parentNode.removeChild(el); });
    clone.querySelectorAll(".row-filtered").forEach(function(el) { el.parentNode.removeChild(el); });
    clone.querySelectorAll(".section-hidden").forEach(function(el) { el.parentNode.removeChild(el); });
    clone.querySelectorAll(".tk-change-row").forEach(function(el) {
      if (!el.classList.contains("visible")) el.parentNode.removeChild(el);
    });
    clone.querySelectorAll(".tk-section-row.section-collapsed").forEach(function(el) {
      el.parentNode.removeChild(el);
    });
    clone.querySelectorAll(".tk-row-hide-btn, .tk-add-chart-btn, .tk-sortable").forEach(function(el) {
      el.removeAttribute("onclick");
    });
    cleanHtml = clone.innerHTML;
  }
  var chartSvg = "";
  var chartVisible = false;
  if (chartPanel && chartPanel.style.display !== "none") {
    chartVisible = true;
    chartSvg = chartPanel.innerHTML;
  }
  var seg = typeof getCurrentSegment === "function" ? getCurrentSegment() : "Total";
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    metricId: "overview-" + seg,
    metricTitle: "Segment Overview: " + seg,
    title: "Segment Overview: " + seg,
    tableHtml: cleanHtml, chartSvg: chartSvg, chartVisible: chartVisible,
    insight: insightEditor ? insightEditor.innerHTML : "",
    timestamp: Date.now()
  };
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
  if (typeof window.captureOverviewPng === "function") {
    window.captureOverviewPng(pinObj);
  }
};
pinSelectedCharts = function() {
  var selected = typeof getChartSelection === "function" ? getChartSelection() : [];
  if (selected.length === 0) return;
  var chartContainer = %2$s("tk-combined-chart");
  var chartSvg = chartContainer ? chartContainer.innerHTML : "";
  var insightEditor = %2$s("overview-insight-editor");
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    metricId: "overview-charts-" + selected.join("-"),
    title: "Overview: " + selected.length + " metrics (" + (typeof getCurrentSegment === "function" ? getCurrentSegment() : "Total") + ")",
    tableHtml: "", chartSvg: chartSvg, chartVisible: true,
    insight: insightEditor ? insightEditor.innerHTML : "",
    timestamp: Date.now()
  };
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
};
pinSigChanges = function() { %1$spinVisibleSigFindings(); };
%1$spinSigCard = function(sigId) {
  var card = %3$s(\'.dash-sig-card[data-sig-id="\' + sigId + \'"]\');
  if (!card || card.classList.contains("sig-hidden")) return;
  var clone = card.cloneNode(true);
  var actions = clone.querySelector(".sig-card-actions");
  if (actions) actions.remove();
  var textEl = clone.querySelector(".dash-sig-text");
  var title = textEl ? textEl.textContent.substring(0, 80) : "Sig Change";
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    metricId: "summary-sig-change-" + sigId,
    metricTitle: "Sig Change: " + title,
    title: "Sig Change: " + title,
    visibleSegments: [],
    tableHtml: clone.outerHTML, chartSvg: "", chartVisible: false,
    insightText: "", insight: "",
    timestamp: Date.now()
  };
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
};
%1$spinVisibleSigFindings = function() {
  var section = %2$s("summary-section-sig-changes");
  if (!section) return;
  var visible = section.querySelectorAll(".dash-sig-card:not(.sig-hidden)");
  if (visible.length === 0) return;
  var wrapper = document.createElement("div");
  wrapper.className = "dash-sig-grid";
  visible.forEach(function(card) {
    var clone = card.cloneNode(true);
    var actions = clone.querySelector(".sig-card-actions");
    if (actions) actions.remove();
    wrapper.appendChild(clone);
  });
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    metricId: "summary-sig-changes",
    metricTitle: "Significant Changes",
    title: "Significant Changes",
    visibleSegments: [],
    tableHtml: wrapper.outerHTML, chartSvg: "", chartVisible: false,
    insightText: "", insight: "",
    timestamp: Date.now()
  };
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
};
%1$shydratePinnedViews = function() {};
%1$srenderPinnedCards = function() { ReportHub.renderPinnedCards(); };
// ===== End Hub Pin Bridge =====
', prefix, id_helper, qs_helper, label_js, report_key)
}


#' Build Tabs Pin Bridge JavaScript
#'
#' Generates tabs-specific pin bridge functions that override per-report
#' pin functions (togglePin, pinDashboardText, pinGaugeSection, etc.)
#' to route through the hub's unified store.
#'
#' @param prefix Report prefix (e.g., "tabs_")
#' @param id_helper Name of the getElementById helper (e.g., "_tabs_id")
#' @param qs_helper Name of the querySelector helper (e.g., "_tabs_qs")
#' @param label_js Escaped report label for JS embedding
#' @param report_key Report key (e.g., "tabs")
#' @return JavaScript string
#' @keywords internal
.build_tabs_pin_bridge <- function(prefix, id_helper, qs_helper, label_js, report_key) {
  sprintf('
// ===== Hub Pin Bridge \u2014 Tabs =====
// Override per-report pin functions to route through hub store
var _hubSrcLbl_%5$s = \'%4$s\';
%1$stogglePin = function(qCode) {
  // Show pin-mode popover (same UX as standalone tabs)
  var existing = document.querySelector(".pin-mode-popover");
  if (existing) existing.remove();
  var btn = %3$s(".pin-btn[data-q-code=\\"" + qCode + "\\"]");
  if (!btn) return;
  var popover = document.createElement("div");
  popover.className = "pin-mode-popover";
  var options = [
    { label: "Table + Chart + Insight", mode: "all" },
    { label: "Chart + Insight", mode: "chart_insight" },
    { label: "Table + Insight", mode: "table_insight" }
  ];
  options.forEach(function(opt) {
    var row = document.createElement("button");
    row.className = "pin-mode-option";
    row.textContent = opt.label;
    row.onclick = function(e) {
      e.stopPropagation();
      popover.remove();
      var pinObj = %1$scaptureCurrentView(qCode);
      if (!pinObj) return;
      pinObj.title = pinObj.qCode || "";
      pinObj.subtitle = pinObj.qTitle || "";
      pinObj.insight = pinObj.insightText || "";
      pinObj.pinMode = opt.mode;
      pinObj.sourceLabel = _hubSrcLbl_%5$s;
      ReportHub.addPin("%5$s", pinObj);
      %1$supdatePinButton(qCode, true);
    };
    popover.appendChild(row);
  });
  btn.style.position = "relative";
  popover.style.position = "absolute";
  popover.style.top = "100%%";
  popover.style.right = "0";
  popover.style.zIndex = "1000";
  btn.appendChild(popover);
  function closePopover(e) {
    if (!popover.contains(e.target) && e.target !== btn) {
      popover.remove();
      document.removeEventListener("click", closePopover, true);
    }
  }
  setTimeout(function() { document.addEventListener("click", closePopover, true); }, 0);
};
%1$spinDashboardText = function(boxId) {
  var editor = %2$s("dash-text-" + boxId);
  var text = editor ? editor.innerText.trim() : "";
  if (!text) { alert("Please enter text before pinning."); return; }
  var title = boxId === "background" ? "Background & Method" : "Executive Summary";
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    pinType: "text_box", qCode: null, title: title,
    insight: text, tableHtml: null, chartSvg: null, timestamp: Date.now()
  };
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
};
%1$spinGaugeSection = function(sectionId) {
  var section = %2$s("dash-sec-" + sectionId);
  if (!section) return;
  var gauges = section.querySelectorAll(".dash-gauge-card:not(.dash-gauge-excluded)");
  if (gauges.length === 0) return;
  var titleEl = section.querySelector(".dash-section-title");
  var sectionTitle = titleEl ? titleEl.childNodes[0].textContent.trim() : sectionId;
  var clone = section.cloneNode(true);
  clone.querySelectorAll(".dash-export-btn, .dash-sort-btn, .dash-slide-export-btn").forEach(function(btn) { btn.remove(); });
  clone.querySelectorAll(".dash-tier-pill").forEach(function(pill) { pill.remove(); });
  clone.querySelectorAll(".dash-gauge-excluded").forEach(function(g) { g.remove(); });
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    pinType: "dashboard_section", qCode: null, title: sectionTitle, subtitle: "",
    insight: null, tableHtml: clone.innerHTML, chartSvg: null,
    baseText: null, timestamp: Date.now()
  };
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
};
%1$spinSigFindings = function() { %1$spinVisibleSigFindings(); };
%1$spinSigCard = function(sigId) {
  var card = %3$s(\'.dash-sig-card[data-sig-id="\' + sigId + \'"]\');
  if (!card || card.classList.contains("sig-hidden")) return;
  var clone = card.cloneNode(true);
  var actions = clone.querySelector(".sig-card-actions");
  if (actions) actions.remove();
  var textEl = clone.querySelector(".dash-sig-text");
  var title = textEl ? textEl.textContent.substring(0, 80) : "Sig Finding";
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    pinType: "dashboard_section", qCode: null,
    title: "Sig Finding: " + title, subtitle: "",
    insight: null, tableHtml: clone.outerHTML, chartSvg: null,
    baseText: null, timestamp: Date.now()
  };
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
};
%1$spinVisibleSigFindings = function() {
  var section = %2$s("dash-sec-sig-findings");
  if (!section) return;
  var visible = section.querySelectorAll(".dash-sig-card:not(.sig-hidden)");
  if (visible.length === 0) return;
  var wrapper = document.createElement("div");
  wrapper.className = "dash-sig-grid";
  visible.forEach(function(card) {
    var clone = card.cloneNode(true);
    var actions = clone.querySelector(".sig-card-actions");
    if (actions) actions.remove();
    wrapper.appendChild(clone);
  });
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    pinType: "dashboard_section", qCode: null,
    title: "Significant Findings", subtitle: "",
    insight: null, tableHtml: wrapper.outerHTML, chartSvg: null,
    baseText: null, timestamp: Date.now()
  };
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
};
%1$spinQualSlide = function(slideId) {
  var card = %3$s(\'.qual-slide-card[data-slide-id="\' + slideId + \'"]\');
  if (!card) return;
  var titleEl = card.querySelector(".qual-slide-title");
  var rendered = card.querySelector(".qual-md-rendered");
  var editor = card.querySelector(".qual-md-editor");
  if (rendered && editor) rendered.innerHTML = %1$srenderMarkdown(editor.value);
  var imgStore = card.querySelector(".qual-img-store");
  var imageData = (imgStore && imgStore.value) ? imgStore.value : null;
  var imageWidth = imgStore ? parseInt(imgStore.getAttribute("data-img-w")) || 0 : 0;
  var imageHeight = imgStore ? parseInt(imgStore.getAttribute("data-img-h")) || 0 : 0;
  if (!imageData) {
    var thumb = card.querySelector(".qual-img-thumb");
    if (thumb && thumb.src && thumb.src.indexOf("data:") === 0) {
      imageData = thumb.src;
      imageWidth = thumb.naturalWidth || 0;
      imageHeight = thumb.naturalHeight || 0;
    }
  }
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    pinType: "text_box", qCode: null,
    title: titleEl ? titleEl.textContent.trim() : "Qualitative Slide",
    subtitle: "",
    insight: rendered ? rendered.innerHTML : "",
    imageData: imageData,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    tableHtml: null, chartSvg: null,
    baseText: null, timestamp: Date.now()
  };
  pinObj.sourceLabel = _hubSrcLbl_%5$s;
  ReportHub.addPin("%5$s", pinObj);
};
%1$shydratePinnedViews = function() {};
%1$srenderPinnedCards = function() { ReportHub.renderPinnedCards(); };
// ===== End Hub Pin Bridge =====
', prefix, id_helper, qs_helper, label_js, report_key)
}


#' Build Generic Pin Bridge JavaScript
#'
#' Generates a generic pin bridge for report types other than tracker and tabs
#' (maxdiff, conjoint, pricing, segment, catdriver, keydriver, confidence, weighting).
#' These reports use a common pin pattern: capture the current panel's visible content
#' and route through the hub's unified store.
#'
#' @param prefix Report prefix (e.g., "maxdiff_")
#' @param id_helper Name of the getElementById helper
#' @param qs_helper Name of the querySelector helper
#' @param label_js Escaped report label for JS embedding
#' @param report_key Report key (e.g., "maxdiff")
#' @return JavaScript string
#' @keywords internal
.build_generic_pin_bridge <- function(prefix, id_helper, qs_helper, label_js, report_key) {
  sprintf('
// ===== Hub Pin Bridge — Generic (%5$s) =====
var _hubSrcLbl_%5$s = \'%4$s\';
// Override togglePin if it exists
if (typeof %1$stogglePin === "function") {
  var _orig_%1$stogglePin = %1$stogglePin;
  %1$stogglePin = function(pinId) {
    var pinObj;
    if (typeof %1$scaptureCurrentView === "function") {
      pinObj = %1$scaptureCurrentView(pinId);
    } else if (typeof _orig_%1$stogglePin === "function") {
      pinObj = _orig_%1$stogglePin(pinId);
    }
    if (!pinObj) {
      pinObj = {
        id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
        title: pinId || "Pinned View",
        tableHtml: "", chartSvg: "", insight: "",
        timestamp: Date.now()
      };
    }
    pinObj.sourceLabel = _hubSrcLbl_%5$s;
    ReportHub.addPin("%5$s", pinObj);
  };
}
%1$shydratePinnedViews = function() {};
%1$srenderPinnedCards = function() { ReportHub.renderPinnedCards(); };
// ===== End Hub Pin Bridge =====
', prefix, id_helper, qs_helper, label_js, report_key)
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
  updatePinButton: typeof %supdatePinButton === "function" ? %supdatePinButton : function() {},
  toggleHelpOverlay: typeof %stoggleHelpOverlay === "function" ? %stoggleHelpOverlay : function() {}
};
', namespace_name, prefix, prefix, prefix, prefix, prefix, prefix)
  } else if (report_type == "tabs") {
    sprintf('
var %s = {
  selectQuestion: typeof selectQuestion === "function" ? selectQuestion : function() {},
  togglePin: typeof %stogglePin === "function" ? %stogglePin : function() {},
  updatePinButton: typeof %supdatePinButton === "function" ? %supdatePinButton : function() {},
  toggleHelpOverlay: typeof %stoggleHelpOverlay === "function" ? %stoggleHelpOverlay : function() {}
};
', namespace_name, prefix, prefix, prefix, prefix, prefix, prefix)
  } else {
    # Generic namespace API for maxdiff, conjoint, pricing, segment, etc.
    sprintf('
var %s = {
  init: function() {},
  togglePin: typeof %stogglePin === "function" ? %stogglePin : function() {},
  updatePinButton: typeof %supdatePinButton === "function" ? %supdatePinButton : function() {},
  toggleHelpOverlay: typeof %stoggleHelpOverlay === "function" ? %stoggleHelpOverlay : function() {}
};
', namespace_name, prefix, prefix, prefix, prefix, prefix, prefix)
  }
}
