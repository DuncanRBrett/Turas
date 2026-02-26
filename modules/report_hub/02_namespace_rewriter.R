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
  parsed$wrapped_js <- wrap_js_in_iife(parsed$js_blocks, key, parsed$report_type)

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

  # Functions that conflict and appear in onclick handlers
  conflict_fns <- c(
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
    "saveReportHTML"
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
    # Prefix window.fnName assignments: window.fnName -> window.prefix_fnName
    # (tracker defines many functions as window.fnName = function(...))
    # CRITICAL: Must keep "window." prefix! Without it, strict-mode IIFEs
    # throw ReferenceError on bare assignments (e.g., tracker_fn = function(){})
    # and non-strict IIFEs lose global exposure (variable stays IIFE-local).
    all_js <- gsub(
      sprintf("window\\.%s\\b", fn),
      sprintf("window.%s%s", prefix, fn),
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

  # --- Rewrite DOM queries to use report-specific scoped helpers ---
  # Each report gets uniquely-named helpers to prevent global variable collision
  # (both scripts share global scope, so _$id would be overwritten by the second report)
  id_prefix <- paste0(report_key, "--")
  helper_id <- paste0("_", report_key, "_id")
  helper_qs <- paste0("_", report_key, "_qs")
  helper_qsa <- paste0("_", report_key, "_qsa")

  # IMPORTANT: Replace querySelectorAll BEFORE querySelector to avoid substring collision
  # "document.querySelectorAll(" contains "document.querySelector(" as a prefix,
  # but the trailing "All(" vs "(" disambiguates them with fixed matching.
  all_js <- gsub("document.querySelectorAll(", paste0(helper_qsa, "("), all_js, fixed = TRUE)
  all_js <- gsub("document.getElementById(", paste0(helper_id, "("), all_js, fixed = TRUE)
  all_js <- gsub("document.querySelector(", paste0(helper_qs, "("), all_js, fixed = TRUE)

  # Prepend scoped helper functions
  helpers_js <- sprintf(
    'var %s = function(id) { return document.getElementById(id) || document.getElementById("%s" + id); };
var %s = function(sel) { var el = document.querySelector(sel); if (el) return el; if (sel.indexOf("#") === -1) return null; return document.querySelector(sel.replace(/#([a-zA-Z][\\w-]*)/g, "#%s$1")); };
var %s = function(sel) { var els = document.querySelectorAll(sel); if (els.length > 0 || sel.indexOf("#") === -1) return els; return document.querySelectorAll(sel.replace(/#([a-zA-Z][\\w-]*)/g, "#%s$1")); };
',
    helper_id, id_prefix, helper_qs, id_prefix, helper_qsa, id_prefix
  )
  all_js <- paste0(helpers_js, "\n", all_js)

  # Also create a namespace object for the public API
  namespace_name <- if (report_type == "tracker") "TrackerReport" else "TabsReport"

  api_js <- build_namespace_api(namespace_name, report_key, report_type)

  bridge_js <- build_pin_bridge(report_key, report_type)

  return(paste0(all_js, "\n\n", api_js, "\n\n", bridge_js))
}


#' Build Pin Bridge for Hub Integration
#'
#' Generates JavaScript that overrides per-report pin functions to route
#' pins through the hub's unified store (ReportHub.pinnedItems) instead
#' of the local per-report arrays. Appended at the end of each report's
#' JS block so it overwrites the original function definitions.
#'
#' @param report_key "tracker" or "tabs"
#' @param report_type "tracker" or "tabs"
#' @return JavaScript string with bridge functions
build_pin_bridge <- function(report_key, report_type) {
  prefix <- paste0(report_key, "_")
  id_helper <- paste0("_", report_key, "_id")
  qs_helper <- paste0("_", report_key, "_qs")

  if (report_type == "tracker") {
    sprintf('
// ===== Hub Pin Bridge \u2014 Tracker =====
// Override per-report pin functions to route through hub store
pinMetricView = function(metricId) {
  // Always add a new pin (multi-pin support).
  // Each pin captures the current view state (visible segments, chart, table).
  var pinObj = captureMetricView(metricId);
  if (!pinObj) return;
  pinObj.title = pinObj.metricTitle || metricId;
  pinObj.insight = pinObj.insightText || "";
  ReportHub.addPin("tracker", pinObj);
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
  ReportHub.addPin("tracker", pinObj);
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
  ReportHub.addPin("tracker", pinObj);
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
  ReportHub.addPin("tracker", pinObj);
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
  ReportHub.addPin("tracker", pinObj);
};
%1$shydratePinnedViews = function() {};
%1$srenderPinnedCards = function() { ReportHub.renderPinnedCards(); };
// ===== End Hub Pin Bridge =====
', prefix, id_helper, qs_helper)
  } else {
    sprintf('
// ===== Hub Pin Bridge \u2014 Tabs =====
// Override per-report pin functions to route through hub store
%stogglePin = function(qCode) {
  // Always add a new pin (multi-pin support).
  // Each pin captures the current view state (banner, chart, table).
  var pinObj = captureCurrentView(qCode);
  if (!pinObj) return;
  pinObj.title = pinObj.qCode || "";
  pinObj.subtitle = pinObj.qTitle || "";
  pinObj.insight = pinObj.insightText || "";
  ReportHub.addPin("tabs", pinObj);
  %supdatePinButton(qCode, true);
};
pinDashboardText = function(boxId) {
  var editor = %s("dash-text-" + boxId);
  var text = editor ? editor.innerText.trim() : "";
  if (!text) { alert("Please enter text before pinning."); return; }
  var title = boxId === "background" ? "Background & Method" : "Executive Summary";
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2,5),
    pinType: "text_box", qCode: null, title: title,
    insight: text, tableHtml: null, chartSvg: null, timestamp: Date.now()
  };
  ReportHub.addPin("tabs", pinObj);
};
%shydratePinnedViews = function() {};
%srenderPinnedCards = function() { ReportHub.renderPinnedCards(); };
// ===== End Hub Pin Bridge =====
', prefix, prefix, prefix, id_helper, prefix, prefix)
  }
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
  } else {
    sprintf('
var %s = {
  selectQuestion: typeof selectQuestion === "function" ? selectQuestion : function() {},
  togglePin: typeof %stogglePin === "function" ? %stogglePin : function() {},
  updatePinButton: typeof %supdatePinButton === "function" ? %supdatePinButton : function() {},
  toggleHelpOverlay: typeof %stoggleHelpOverlay === "function" ? %stoggleHelpOverlay : function() {}
};
', namespace_name, prefix, prefix, prefix, prefix, prefix, prefix)
  }
}
