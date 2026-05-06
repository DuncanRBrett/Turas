# ==============================================================================
# BRAND MODULE - BRAND SELECTOR DROPDOWN STYLING
# Shared CSS for the BrandSelector trigger button, popover, and below-chart
# colour-legend strip. All classes namespaced .bs-* to avoid collisions with
# .tp-* (TurasPins), .fn-* (funnel), .ma-* (mental availability), etc.
# ==============================================================================


#' Return the <style> block for the brand-selector dropdown component
#'
#' Used by every brand panel that has migrated from chip-strip to dropdown
#' brand selection. The trigger element is a button with class
#' \code{.bs-trigger}; the popover is dynamically inserted with class
#' \code{.bs-popover} and removed on close. The static legend strip below
#' charts uses class \code{.bs-legend}.
#'
#' @return Character. A single \code{<style>...</style>} string.
#' @export
build_brand_selector_styles <- function() {
  paste0('<style class="bs-styles">', .bs_css_body(), '</style>')
}


#' Raw CSS body for the brand-selector component.
#' Plain string — no R interpolation needed.
#' @keywords internal
.bs_css_body <- function() {
"
/* Trigger button — sits inside a panel toolbar */
.bs-trigger {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border: 1px solid #cbd5e1;
  border-radius: 999px;
  background: #ffffff;
  color: #0f172a;
  font: 500 13px/1 system-ui, -apple-system, 'Segoe UI', sans-serif;
  cursor: pointer;
  transition: background 0.12s, border-color 0.12s;
}
.bs-trigger:hover {
  background: #f1f5f9;
  border-color: #94a3b8;
}
.bs-trigger:focus-visible {
  outline: 2px solid #1A5276;
  outline-offset: 2px;
}
.bs-trigger[aria-expanded='true'] {
  background: #e2e8f0;
  border-color: #475569;
}
.bs-trigger-icon {
  font-size: 14px;
  line-height: 1;
}
.bs-trigger-count {
  color: #475569;
  font-weight: 400;
  font-size: 12px;
}
.bs-trigger-caret {
  font-size: 10px;
  color: #64748b;
  margin-left: 2px;
}

/* Popover — dynamically inserted, anchored under trigger */
.bs-popover {
  min-width: 300px;
  max-width: 420px;
  max-height: 480px;
  background: #ffffff;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.18);
  font: 13px/1.4 system-ui, -apple-system, 'Segoe UI', sans-serif;
  color: #0f172a;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
/* Split-mode (Table+Chart) needs wider min so the two label columns fit */
.bs-popover[data-bs-panel] .bs-popover-body-split {
  min-width: 360px;
}
.bs-popover-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  border-bottom: 1px solid #e2e8f0;
  background: #f8fafc;
}
.bs-popover-title {
  font-weight: 600;
  color: #0f172a;
}
.bs-popover-header-actions {
  display: inline-flex;
  gap: 6px;
}
.bs-popover-action {
  padding: 3px 8px;
  border: 1px solid #cbd5e1;
  border-radius: 4px;
  background: #ffffff;
  color: #1A5276;
  font: 500 12px/1 system-ui, -apple-system, 'Segoe UI', sans-serif;
  cursor: pointer;
}
.bs-popover-action:hover {
  background: #1A5276;
  color: #ffffff;
  border-color: #1A5276;
}
.bs-popover-body {
  flex: 1 1 auto;
  overflow-y: auto;
  padding: 4px 0;
}
.bs-popover-col-header {
  display: grid;
  grid-template-columns: 50px 50px 16px 1fr auto;
  gap: 8px;
  padding: 6px 12px;
  font-size: 10px;
  font-weight: 700;
  color: #475569;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  border-bottom: 1px solid #e2e8f0;
  margin-bottom: 4px;
  background: #f8fafc;
}
.bs-popover-col-table { grid-column: 1; text-align: center; }
.bs-popover-col-chart { grid-column: 2; text-align: center; }
.bs-popover-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 12px;
  cursor: pointer;
  user-select: none;
}
.bs-popover-row:hover { background: #f1f5f9; }
.bs-popover-body-split .bs-popover-row {
  display: grid;
  grid-template-columns: 50px 50px 16px 1fr auto;
  gap: 8px;
  align-items: center;
}
.bs-popover-body-split .bs-popover-checkbox-table { justify-self: center; }
.bs-popover-body-split .bs-popover-checkbox-chart { justify-self: center; }
.bs-popover-row-focal {
  background: rgba(26, 82, 118, 0.06);
  font-weight: 600;
}
.bs-popover-checkbox {
  margin: 0;
  cursor: pointer;
  accent-color: #1A5276;
}
.bs-popover-swatch {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  flex-shrink: 0;
  border: 1px solid rgba(15, 23, 42, 0.12);
}
.bs-popover-label {
  flex: 1 1 auto;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  color: #0f172a;
}
.bs-popover-focal-pill {
  font: 600 9px/1 system-ui, -apple-system, sans-serif;
  letter-spacing: 0.06em;
  padding: 2px 5px;
  border-radius: 3px;
  background: #1A5276;
  color: #ffffff;
}
.bs-popover-sync {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 12px;
  border-bottom: 1px solid #e2e8f0;
  background: #f8fafc;
  font-size: 12px;
  font-weight: 500;
  color: #475569;
  cursor: pointer;
  user-select: none;
}
.bs-popover-sync-cb { accent-color: #1A5276; }

/* Container — used by R helpers to wrap trigger + adjacent quick-action chips */
.bs-toolbar-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin: 6px 0;
}
.bs-toolbar-row > .bs-toolbar-label {
  font: 600 11px/1 system-ui, -apple-system, sans-serif;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: #475569;
}
"
}
