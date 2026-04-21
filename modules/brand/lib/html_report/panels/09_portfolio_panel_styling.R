# ==============================================================================
# BRAND MODULE - PORTFOLIO PANEL CSS
# ==============================================================================
# Scoped to .pf-* prefix to avoid collisions with funnel (.fn-*) and MA (.ma-*).
# Injected once per report by 99_html_report_main.R.
# ==============================================================================

#' Build portfolio panel CSS bundle
#'
#' @param focal_colour Character. Hex colour for the focal brand.
#' @return Character. CSS string.
#' @keywords internal
build_portfolio_panel_styles <- function(focal_colour = "#1A5276") {
  sprintf("
/* ---- Portfolio Panel ---- */
.pf-panel { width:100%%; }
.pf-sub-nav {
  display: flex;
  gap: 4px;
  padding: 0 0 16px 0;
  border-bottom: 1px solid #e2e8f0;
  margin-bottom: 20px;
  flex-wrap: wrap;
}
.pf-sub-btn {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  color: #64748b;
  cursor: pointer;
  font-size: 12px;
  font-weight: 500;
  padding: 6px 14px;
  transition: all 0.15s;
}
.pf-sub-btn:hover { background: #f1f5f9; color: #1e293b; }
.pf-sub-btn.active {
  background: %s;
  border-color: %s;
  color: #fff;
  font-weight: 600;
}
.pf-subtab { display: none; }
.pf-subtab.active { display: block; }
.pf-hero-strip {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  margin-bottom: 24px;
}
.pf-kpi-card {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  flex: 1;
  min-width: 160px;
  padding: 14px 16px;
  text-align: center;
}
.pf-kpi-value {
  color: %s;
  font-size: 28px;
  font-weight: 700;
  line-height: 1.1;
}
.pf-kpi-label {
  color: #64748b;
  font-size: 11px;
  margin-top: 4px;
}
.pf-about-drawer {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  color: #64748b;
  font-size: 11px;
  line-height: 1.6;
  margin-top: 16px;
  padding: 12px 16px;
}
.pf-suppression-note {
  background: #fefce8;
  border: 1px solid #fde68a;
  border-radius: 6px;
  color: #92400e;
  font-size: 11px;
  margin-top: 12px;
  padding: 8px 12px;
}
.pf-coming-soon {
  align-items: center;
  color: #94a3b8;
  display: flex;
  font-size: 13px;
  justify-content: center;
  min-height: 200px;
}
", focal_colour, focal_colour, focal_colour)
}
