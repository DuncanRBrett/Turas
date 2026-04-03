# ==============================================================================
# AI RENDERING — HTML Rendering for AI Insights
# ==============================================================================
# SIZE-EXCEPTION: CSS string constants inflate line count beyond 300.
#   Actual logic functions are individually under 50 lines.
#
# All HTML generation for AI-related content in tabs reports:
#   - Per-question AI callout panels (distinct from researcher commentary)
#   - Researcher commentary panels (standard styling)
#   - Executive summary (reviewed and unreviewed variants)
#   - Methodology note with model attribution
#   - CSS for all AI components
#   - Toggle control for showing/hiding AI callouts
#
# Dependencies:
#   htmltools — HTML generation (already in Turas)
#
# Usage:
#   source("modules/tabs/lib/ai/ai_rendering.R")
#   html <- build_ai_callout_panel(callout, "Q001")
#
# ==============================================================================


#' Build an AI callout panel for a single question
#'
#' Renders the distinctive AI-styled panel with sparkle icon, "AI-assisted
#' insight" label, pin button, narrative text, and optional data caveat.
#'
#' @param callout List. AI callout with has_insight, narrative, confidence,
#'   data_limitations, pinned fields.
#' @param q_code Character. Question code (for data attributes).
#'
#' @return Character. HTML string, or empty string if no insight.
build_ai_callout_panel <- function(callout, q_code) {

  if (is.null(callout) || !isTRUE(callout$has_insight)) return("")
  if (is.null(callout$narrative) || !nzchar(callout$narrative)) return("")

  confidence  <- callout$confidence %||% "high"
  narrative   <- escape_html(callout$narrative)
  limitations <- callout$data_limitations %||% ""

  caveat_html <- ""
  if (confidence %in% c("medium", "low") && nzchar(limitations)) {
    caveat_html <- sprintf(
      '<div class="ai-callout-caveat">%s</div>',
      escape_html(limitations)
    )
  }

  sprintf(
    '<div class="turas-ai-callout" data-q-code="%s" data-confidence="%s">
  <div class="ai-callout-header">
    <span class="ai-callout-icon" title="AI-assisted insight">&#10022;</span>
    <span class="ai-callout-label">AI-assisted insight</span>
    <button class="ai-callout-dismiss" onclick="dismissAiCallout(this)" title="Dismiss this insight">
      &times;
    </button>
  </div>
  <div class="ai-callout-body">%s</div>%s
</div>',
    escape_html(q_code), confidence,
    narrative, caveat_html
  )
}


#' Build a researcher commentary panel for a single question
#'
#' Renders the standard-styled commentary panel (brand-colour border, no AI
#' labelling). This is the "here's what it means" layer written by the
#' researcher in the Comments sheet.
#'
#' @param commentary Character. The researcher's commentary text.
#' @param q_code Character. Question code.
#'
#' @return Character. HTML string, or empty string if no commentary.
build_researcher_commentary_panel <- function(commentary, q_code) {

  if (is.null(commentary) || !nzchar(commentary)) return("")

  sprintf(
    '<div class="turas-commentary" data-q-code="%s">
  <div class="commentary-body">%s</div>
</div>',
    escape_html(q_code), escape_html(commentary)
  )
}


#' Build the executive summary panel
#'
#' Renders the executive summary with styling dependent on whether a
#' researcher has reviewed it (standard styling) or not (AI callout styling).
#'
#' @param exec_summary List. Executive summary with narrative, confidence,
#'   data_limitations fields.
#' @param ai_config List. AI config with exec_summary_reviewed flag.
#'
#' @return Character. HTML string, or empty string if no summary.
build_ai_exec_summary <- function(exec_summary, ai_config) {

  if (is.null(exec_summary)) return("")
  narrative <- exec_summary$narrative %||% ""
  if (!nzchar(narrative)) return("")

  # Convert double newlines to paragraph breaks
  body_html <- narrative_to_paragraphs(escape_html(narrative))

  sprintf(
    '<div class="turas-ai-callout turas-ai-exec" id="ai-exec-summary">
  <div class="ai-callout-header">
    <span class="ai-callout-icon" title="AI-assisted key findings">&#10022;</span>
    <span class="ai-callout-label">AI-assisted key findings</span>
    <button class="ai-callout-dismiss" onclick="dismissAiCallout(this)" title="Dismiss this summary">&times;</button>
  </div>
  <div class="ai-callout-body">%s</div>
</div>',
    body_html
  )
}


#' Build the methodology note
#'
#' Renders the AI transparency disclosure including the model name.
#' Text varies by delivery context (reviewed vs unreviewed).
#'
#' @param ai_config List. AI configuration.
#' @param model_display_name Character. Human-readable model name.
#'
#' @return Character. HTML string.
build_ai_methodology_note <- function(ai_config, model_display_name) {

  model_name <- model_display_name %||% "AI model"

  if (isTRUE(ai_config$exec_summary_reviewed)) {
    note_text <- sprintf(
      "AI-assisted insight callouts in this report are generated using %s and reviewed by the research team. They are clearly labelled in the report. AI callouts analyse data across all banner groups simultaneously and may reference subgroups not visible in the currently selected banner view. Strategic commentary and the executive summary are written by the research team.",
      model_name
    )
  } else {
    note_text <- sprintf(
      "AI-assisted insights in this report &mdash; including the key findings summary and per-question callouts &mdash; are generated using %s. They are clearly labelled in the report. AI callouts analyse data across all banner groups simultaneously and may reference subgroups not visible in the currently selected banner view.",
      model_name
    )
  }

  sprintf(
    '<div class="turas-ai-methodology-note">
  <div class="methodology-label">AI methodology</div>
  <div class="methodology-body">%s</div>
</div>',
    note_text
  )
}


#' Build the AI toggle control
#'
#' Renders a checkbox toggle that shows/hides all AI callout panels.
#' Does not affect the executive summary or researcher commentary.
#'
#' @return Character. HTML string.
build_ai_toggle_control <- function() {
  '<label class="ai-toggle">
  <input type="checkbox" checked onchange="toggleAllCallouts(this.checked)">
  <span>Show AI-assisted insights</span>
</label>'
}


#' Build CSS for all AI insight components
#'
#' Returns the complete CSS block for AI callouts, researcher commentary,
#' executive summary panels, methodology note, toggle, and print rules.
#'
#' @return Character. CSS string (without <style> tags).
build_ai_callout_css <- function() {
  '
/* === Researcher commentary (standard report styling) === */
.turas-commentary {
  background: var(--ct-bg-surface, #fafbfc);
  border-left: 3px solid var(--ct-brand, #323367);
  border-radius: var(--ct-radius-md, 6px);
  padding: 16px 20px;
  margin: 12px 0 16px 0;
  font-size: 13.5px;
  line-height: 1.7;
  color: var(--ct-text-primary, #1a1a2e);
}

/* === Executive summary (researcher-reviewed) === */
.turas-insight-exec {
  background: var(--ct-bg-surface, #fafbfc);
  border-left: 3px solid var(--ct-brand, #323367);
  border-radius: var(--ct-radius-md, 6px);
  padding: 20px 24px;
  margin: 0 0 24px 0;
  font-size: 13.5px;
  line-height: 1.7;
  color: var(--ct-text-primary, #1a1a2e);
}
.turas-insight-exec .insight-label {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 1.2px;
  text-transform: uppercase;
  color: var(--ct-brand, #323367);
  margin-bottom: 12px;
}
.turas-insight-exec .insight-body p { margin-bottom: 12px; }
.turas-insight-exec .insight-body p:last-child { margin-bottom: 0; }
.turas-insight-exec .insight-meta {
  font-size: 11px;
  color: var(--ct-text-tertiary, #8a8a9a);
  margin-top: 14px;
  padding-top: 10px;
  border-top: 1px solid var(--ct-border, #e2e4e8);
}

/* === AI callout (distinct visual treatment — pale gold) === */
.turas-ai-callout {
  background: #fdf8ed;
  border-left: 3px solid #c9a84c;
  border-radius: var(--ct-radius-md, 6px);
  padding: 16px 20px;
  margin: 12px 0 16px 0;
  font-size: 13.5px;
  line-height: 1.7;
  color: var(--ct-text-primary, #1a1a2e);
  box-sizing: border-box;
  width: 100%;
}
/* Match researcher commentary width */
.turas-commentary {
  box-sizing: border-box;
  width: 100%;
}
.turas-ai-callout.turas-ai-exec {
  padding: 20px 24px;
  margin: 0 0 24px 0;
}
.turas-ai-callout.turas-ai-exec .ai-callout-body p { margin-bottom: 12px; }
.turas-ai-callout.turas-ai-exec .ai-callout-body p:last-child { margin-bottom: 0; }
.turas-ai-callout .ai-callout-header {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 8px;
}
.turas-ai-callout .ai-callout-icon {
  font-size: 12px;
  color: #c9a84c;
}
.turas-ai-callout .ai-callout-label {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 1px;
  text-transform: uppercase;
  color: #c9a84c;
  flex: 1;
}
.turas-ai-callout .ai-callout-dismiss {
  background: none;
  border: 1px solid var(--ct-border, #e2e4e8);
  border-radius: var(--ct-radius-sm, 4px);
  padding: 2px 8px;
  font-size: 14px;
  cursor: pointer;
  opacity: 0.3;
  color: var(--ct-text-tertiary, #8a8a9a);
  transition: opacity 0.15s ease;
  line-height: 1;
}
.turas-ai-callout .ai-callout-dismiss:hover { opacity: 0.8; color: #e74c3c; }
.turas-ai-callout .ai-callout-body {
  font-size: 13.5px;
  line-height: 1.7;
}
.turas-ai-callout .ai-callout-meta {
  font-size: 11px;
  color: #a08840;
  margin-top: 12px;
  padding-top: 8px;
  border-top: 1px solid #e8dfc0;
}
.turas-ai-callout .ai-callout-caveat {
  font-size: 12px;
  color: var(--ct-text-tertiary, #8a8a9a);
  font-style: italic;
  margin-top: 6px;
}
.turas-ai-callout[data-confidence="medium"] {
  border-left-color: #d4a017;
  background: #fdf6e3;
}
.turas-ai-callout[data-confidence="low"] {
  border-left-color: var(--ct-text-tertiary, #8a8a9a);
  background: #f5f3ee;
  opacity: 0.85;
}

/* === Methodology note === */
.turas-ai-methodology-note {
  background: var(--ct-bg-surface, #fafbfc);
  border: 1px solid var(--ct-border, #e2e4e8);
  border-radius: var(--ct-radius-md, 6px);
  padding: 14px 18px;
  margin: 24px 0 12px 0;
  font-size: 12px;
  line-height: 1.6;
  color: var(--ct-text-secondary, #555566);
}
.turas-ai-methodology-note .methodology-label {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 1px;
  text-transform: uppercase;
  color: var(--ct-text-tertiary, #8a8a9a);
  margin-bottom: 6px;
}

/* === AI toggle control === */
.ai-toggle {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: var(--ct-text-secondary, #555566);
  cursor: pointer;
  margin-left: 12px;
}

/* === Print: AI callouts only print if pinned === */
@media print {
  .turas-ai-callout { display: none; }
  .turas-ai-callout[data-pinned="true"] {
    display: block;
    break-inside: avoid;
  }
  .turas-ai-callout .ai-callout-pin { display: none; }
  .ai-toggle { display: none; }
  .turas-insight-exec,
  .turas-commentary { break-inside: avoid; }
  .turas-ai-methodology-note { break-inside: avoid; }
}
'
}


#' Build JavaScript for AI insight interactivity
#'
#' Returns JS for toggle, dismiss, and dashboard exec summary injection.
#'
#' @param exec_summary_html Character or NULL. Pre-rendered exec summary HTML
#'   to inject into the dashboard after text boxes.
#'
#' @return Character. JavaScript string (without <script> tags).
build_ai_insights_js <- function(exec_summary_html = NULL) {
  # Inject AI exec summary into dashboard on page load
  exec_inject_js <- ""
  if (!is.null(exec_summary_html) && nzchar(exec_summary_html)) {
    # Escape for JS string embedding
    escaped <- gsub("\\\\", "\\\\\\\\", exec_summary_html)
    escaped <- gsub("'", "\\\\'", escaped)
    escaped <- gsub("\n", "\\\\n", escaped)
    exec_inject_js <- sprintf('
/* === Inject AI Executive Summary into Dashboard === */
(function() {
  var html = \'%s\';
  var boxes = document.querySelectorAll(".dash-text-box");
  var target = boxes.length > 0 ? boxes[boxes.length - 1] : null;
  if (target) {
    var wrapper = document.createElement("div");
    wrapper.innerHTML = html;
    target.parentNode.insertBefore(wrapper.firstElementChild || wrapper, target.nextSibling);
  }
})();
', escaped)
  }

  paste0(exec_inject_js, '
/* === AI Insights Toggle === */
function toggleAllCallouts(show) {
  document.querySelectorAll(".turas-ai-callout:not(.turas-ai-exec)")
    .forEach(function(el) { el.style.display = show ? "" : "none"; });
}

/* === AI Callout Pin Toggle === */
function toggleCalloutPin(btn) {
  var callout = btn.closest(".turas-ai-callout");
  if (!callout) return;
  var pinned = callout.getAttribute("data-pinned") === "true";
  callout.setAttribute("data-pinned", pinned ? "false" : "true");
}

/* === AI Callout Dismiss === */
function dismissAiCallout(btn) {
  var callout = btn.closest(".turas-ai-callout, .turas-insight-exec");
  if (!callout) return;
  callout.style.display = "none";
}
')
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

#' Escape HTML special characters
#' @keywords internal
escape_html <- function(text) {
  if (is.null(text) || !nzchar(text)) return("")
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  text <- gsub(">", "&gt;", text, fixed = TRUE)
  text <- gsub('"', "&quot;", text, fixed = TRUE)
  text
}


#' Convert narrative text with double newlines to HTML paragraphs
#' @keywords internal
narrative_to_paragraphs <- function(text) {
  if (!nzchar(text)) return("")
  paragraphs <- strsplit(text, "\n\n", fixed = TRUE)[[1]]
  paragraphs <- trimws(paragraphs)
  paragraphs <- paragraphs[nzchar(paragraphs)]
  if (length(paragraphs) == 0) return("")
  paste0("<p>", paragraphs, "</p>", collapse = "\n")
}
