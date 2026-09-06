# ==============================================================================
# CHART BRANDS: a per-chart deviation from the header's comparison set
# ==============================================================================
# Stage 2 put one brand control in the category header and hid every per-panel
# focal select and brand filter, because the two sets duplicated each other.
# That removed a capability an analyst used: the per-panel filter carried a
# "Sync table and chart" toggle, and with it off a brand could be hidden from
# the chart while it stayed in the table.
#
# This widget brings that back as a control of its own rather than as a side
# effect of a duplicated dropdown. Two rules make it a deviation and not a
# second selection:
#
#   1. It can only narrow. The popover lists the brands the header currently
#      shows, so a brand the header excluded can never reappear in a chart.
#   2. Any change in the header resets it. BrandSelector.applyRemoteHiddenSet
#      already sets hiddenChart from hiddenTable on every published set, so
#      the reset is the substrate's own behaviour, not a rule bolted on top.
#
# Two elements per chart, emitted separately on purpose.
#
#   .br-cf       the control mount. JavaScript builds the trigger and the
#                popover into it. It carries no numbers of its own and is
#                stripped from every pin and PNG capture.
#   .br-cf-note  the deviation note. Plain text, no control, so it survives
#                brStripInteractive and is cloned by capturePortableHtml when
#                a panel captures its chart area. This is what stops a reader
#                exporting a chart and a table that disagree with nothing on
#                the face of either to say why.
#
# Pairs with js/brand_chart_focus.js (window.BrandChartFocus).
# ==============================================================================


#' Build the chart-brands control mount and its deviation note
#'
#' Emitted next to a chart that has both a table beside it and a chart-only
#' visibility map behind it. The mount is empty: the popover has to list the
#' brands the header shows right now, which is a runtime fact, so JavaScript
#' fills it. The note is empty and hidden until a deviation exists.
#'
#' @param scope Character. The chart's own scope key within its panel, for
#'   example \code{"funnel"}, \code{"attributes"}, \code{"loyalty"}. Used by
#'   the tests and by the JavaScript for logging; the control itself works
#'   through the panel's own BrandSelector handle, not through this value.
#'
#' @return Character. One HTML fragment holding the mount and the note.
#'
#' @keywords internal
build_chart_focus_control <- function(scope) {
  if (!is.character(scope) || length(scope) != 1L || !nzchar(scope)) {
    stop("build_chart_focus_control: scope must be a non-empty string")
  }
  esc <- gsub('"', "&quot;", scope, fixed = TRUE)
  paste0(
    '<div class="br-cf" data-chartfocus="', esc, '"></div>',
    '<div class="br-cf-note" data-chartfocus-note="', esc, '" hidden></div>'
  )
}


#' Styles for the chart-brands control and its note
#'
#' Every selector here names its own class with no ancestor. A rule scoped
#' under a panel class would look right on screen and vanish from a pin,
#' because TurasPins re-parents the captured node and its style inliner skips
#' values that look like defaults. Colours are literal rather than CSS
#' variables for the same reason: a panel-scoped variable resolves to nothing
#' once the captured HTML sits in a body-level container.
#'
#' @return Character. A CSS block, no style tag.
#'
#' @keywords internal
build_chart_focus_styles <- function() {
  paste(
    ".br-cf { position: relative; display: block; margin: 0 0 6px; }",
    ".br-cf-trigger {",
    "  display: inline-flex; align-items: center; gap: 6px;",
    "  font-size: 11px; padding: 4px 9px; border-radius: 6px;",
    "  border: 1px solid #cbd5e1; background: #fff; color: #475569;",
    "  cursor: pointer;",
    "}",
    ".br-cf-trigger:hover { border-color: #94a3b8; }",
    ".br-cf-trigger[aria-expanded=\"true\"] { border-color: #64748b; }",
    ".br-cf-trigger.br-cf-on {",
    "  border-color: #b45309; background: #fffbeb; color: #92400e;",
    "  font-weight: 600;",
    "}",
    ".br-cf-pop {",
    "  position: absolute; z-index: 900; top: 100%; left: 0; margin-top: 4px;",
    "  min-width: 240px; max-height: 320px; overflow-y: auto;",
    "  background: #fff; border: 1px solid #cbd5e1; border-radius: 8px;",
    "  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.14); padding: 10px 12px;",
    "}",
    ".br-cf-pop[hidden] { display: none; }",
    ".br-cf-head { font-size: 11px; color: #64748b; margin-bottom: 8px; }",
    ".br-cf-item {",
    "  display: flex; align-items: center; gap: 7px; font-size: 12px;",
    "  padding: 3px 0; cursor: pointer;",
    "}",
    ".br-cf-item input[disabled] + span { color: #94a3b8; }",
    ".br-cf-reset {",
    "  margin-top: 8px; font-size: 11px; padding: 4px 9px; border-radius: 6px;",
    "  border: 1px solid #cbd5e1; background: #f8fafc; color: #475569;",
    "  cursor: pointer;",
    "}",
    ".br-cf-reset:hover { border-color: #94a3b8; }",
    # The note is the half that survives a capture, so it carries its own
    # colour, weight and rail rather than inheriting any of them.
    ".br-cf-note {",
    "  font-size: 11px; font-weight: 600; color: #92400e;",
    "  background: #fffbeb; border-left: 3px solid #b45309;",
    "  padding: 6px 10px; margin: 0 0 8px; border-radius: 0 4px 4px 0;",
    "}",
    ".br-cf-note[hidden] { display: none; }",
    sep = "\n"
  )
}
