# ==============================================================================
# BRAND MODULE - CATEGORY BUYING PANEL CSS
# ==============================================================================
# Returns a <style> block for the Category Buying (Dirichlet) panel.
# Follows the same inline-CSS pattern as 03_funnel_panel_styling.R.
#
# VERSION: 1.0
# ==============================================================================

BRAND_CB_STYLING_VERSION <- "1.0"


#' Return the CSS bundle for the Category Buying panel
#'
#' @return Character. A \code{<style>} HTML tag containing panel CSS.
#' @keywords internal
cb_panel_css <- function() {
'<style>
/* === Category Buying Panel === */
.cb-panel { font-family: system-ui, -apple-system, sans-serif; }
.cb-kpi-strip {
  display: flex; gap: 12px; flex-wrap: wrap; margin: 0 0 20px;
}
.cb-kpi-chip {
  background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 8px;
  padding: 10px 18px; min-width: 130px;
}
.cb-kpi-chip.green  { background: #f0fdf4; border-color: #bbf7d0; }
.cb-kpi-chip.amber  { background: #fffbeb; border-color: #fde68a; }
.cb-kpi-chip.muted  { background: #f8fafc; border-color: #e2e8f0; }
.cb-kpi-val  { font-size: 22px; font-weight: 700; color: #1A5276; }
.cb-kpi-val.green   { color: #166534; }
.cb-kpi-val.amber   { color: #92400e; }
.cb-kpi-label { font-size: 11px; color: #64748b; margin-top: 2px; }
.cb-section-title {
  font-size: 14px; font-weight: 600; color: #334155; margin: 20px 0 8px;
}
.cb-subtitle {
  font-size: 11px; color: #94a3b8; margin: -4px 0 12px; font-style: italic;
}
.cb-toggle-bar {
  display: flex; gap: 6px; margin-bottom: 10px; flex-wrap: wrap;
}
.cb-toggle-btn {
  background: #f1f5f9; border: 1px solid #e2e8f0; border-radius: 6px;
  padding: 4px 12px; font-size: 12px; cursor: pointer; color: #334155;
  transition: all 0.15s;
}
.cb-toggle-btn.active {
  background: #1A5276; color: #fff; border-color: #1A5276;
}
/* DJ Scatter */
.cb-dj-container { width: 100%; min-height: 360px; position: relative; }
.cb-dj-svg { width: 100%; }
/* Norms table */
.cb-norms-wrap { overflow-x: auto; margin: 8px 0 20px; }
.cb-norms-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.cb-norms-table th {
  background: #323367; color: #fff; padding: 6px 8px;
  text-align: center; font-weight: 600; white-space: nowrap;
}
.cb-norms-table td {
  padding: 5px 8px; border-bottom: 1px solid #f1f5f9;
  text-align: right; font-size: 12px;
}
.cb-norms-table td.brand-col { text-align: left; font-weight: 500; }
.cb-norms-table tr.focal-row { background: #eff6ff; font-weight: 600; }
.cb-dev-pos { color: #166534; }
.cb-dev-neg { color: #991b1b; }
.cb-dev-large-pos { background: #dcfce7; color: #166534; font-weight: 600; }
.cb-dev-large-neg { background: #fee2e2; color: #991b1b; font-weight: 600; }
/* Two-column row */
.cb-two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin: 16px 0; }
@media (max-width: 680px) { .cb-two-col { grid-template-columns: 1fr; } }
/* Heatmap */
.cb-heatmap-wrap { overflow-x: auto; margin: 8px 0 20px; }
.cb-heatmap-table { border-collapse: collapse; font-size: 11px; }
.cb-heatmap-table th, .cb-heatmap-table td {
  padding: 4px 8px; border: 1px solid #e2e8f0;
}
.cb-heatmap-table th { background: #f8fafc; font-weight: 600; text-align: center; }
/* Collapsible descriptive detail */
.cb-details-toggle {
  font-size: 12px; color: #64748b; cursor: pointer; text-decoration: underline;
  border: none; background: none; padding: 0; margin: 16px 0 8px; display: block;
}
.cb-details-content { display: none; }
.cb-details-content.open { display: block; }
/* Refusal block */
.cb-refused {
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px;
  padding: 12px 16px; margin: 8px 0 16px; font-size: 12px; color: #991b1b;
}
/* Focal brand picker */
.cb-brand-picker {
  display: flex; gap: 6px; flex-wrap: wrap; margin: 0 0 14px;
}
.cb-focal-chip {
  background: #f1f5f9; border: 1px solid #e2e8f0; border-radius: 20px;
  padding: 4px 14px; font-size: 12px; cursor: pointer; color: #334155;
  transition: all 0.15s;
}
.cb-focal-chip.active {
  background: var(--cb-focal-colour, #1A5276); color: #fff;
  border-color: var(--cb-focal-colour, #1A5276);
}
/* Category Context tables */
.cb-context-tables {
  display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin: 16px 0;
}
@media (max-width: 560px) { .cb-context-tables { grid-template-columns: 1fr; } }
.cb-ctx-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.cb-ctx-table th {
  background: #f1f5f9; color: #334155; padding: 5px 8px;
  text-align: left; font-weight: 600; border-bottom: 2px solid #e2e8f0;
}
.cb-ctx-table td {
  padding: 4px 8px; border-bottom: 1px solid #f1f5f9; font-size: 12px;
}
</style>'
}
