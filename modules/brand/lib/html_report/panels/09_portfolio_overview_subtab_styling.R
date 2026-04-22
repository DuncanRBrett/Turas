# ==============================================================================
# BRAND MODULE - PORTFOLIO OVERVIEW SUBTAB CSS
# ==============================================================================
# Scoped to .pfo-* prefix. Appended to the portfolio panel styles bundle by
# 99_html_report_main.R.
# ==============================================================================

#' Build portfolio overview (subtab) CSS bundle
#'
#' @param focal_colour Character. Hex colour for the focal brand.
#' @return Character. CSS string.
#' @keywords internal
build_portfolio_overview_subtab_styles <- function(focal_colour = "#1A5276") {
  sprintf("
/* ---- Portfolio Overview subtab (.pfo-*) ---- */
.pfo-picker {
  align-items: center;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin-bottom: 20px;
  padding: 12px 16px;
}
.pfo-picker-label {
  color: #475569;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.pfo-picker-select {
  appearance: none;
  -webkit-appearance: none;
  background: #fff url(\"data:image/svg+xml;charset=UTF-8,%%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' viewBox='0 0 12 8'%%3E%%3Cpath fill='%%23475569' d='M6 8L0 0h12z'/%%3E%%3C/svg%%3E\") no-repeat right 12px center;
  background-size: 10px 7px;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  color: #1e293b;
  cursor: pointer;
  font-size: 13px;
  font-weight: 500;
  min-width: 220px;
  padding: 8px 36px 8px 14px;
  transition: border-color 0.15s, box-shadow 0.15s;
}
.pfo-picker-select:hover {
  border-color: #94a3b8;
}
.pfo-picker-select:focus-visible {
  border-color: %s;
  box-shadow: 0 0 0 3px rgba(26, 82, 118, 0.15);
  outline: none;
}

.pfo-grid {
  display: grid;
  gap: 24px;
}
.pfo-section-title {
  color: #1e293b;
  font-size: 14px;
  font-weight: 600;
  margin: 0 0 12px;
}

/* Ranked bars */
.pfo-bars {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.pfo-bar-row {
  align-items: center;
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(180px, 220px) 1fr 60px;
}
.pfo-bar-label {
  align-items: center;
  color: #1e293b;
  display: flex;
  font-size: 12px;
  gap: 6px;
}
.pfo-bar-track {
  background: #f1f5f9;
  border-radius: 999px;
  height: 14px;
  overflow: hidden;
  position: relative;
}
.pfo-bar-fill {
  border-radius: 999px;
  height: 100%%;
  transition: width 0.25s ease;
}
.pfo-bar-value {
  color: #475569;
  font-size: 12px;
  font-weight: 600;
  text-align: right;
}
.pfo-depth-badge {
  border-radius: 4px;
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 0.03em;
  padding: 2px 6px;
  text-transform: uppercase;
}
.pfo-depth-full  { background: #ecfdf5; color: #047857; }
.pfo-depth-aware { background: #f1f5f9; color: #64748b; }

/* Summary table */
.pfo-table-scroll { overflow-x: auto; }
.pfo-table {
  border-collapse: collapse;
  font-size: 12px;
  width: 100%%;
}
.pfo-table thead th {
  background: #f8fafc;
  border-bottom: 1px solid #e2e8f0;
  color: #475569;
  font-weight: 600;
  padding: 10px 12px;
  text-align: right;
}
.pfo-table thead th.pfo-th-cat,
.pfo-table thead th.pfo-th-depth {
  text-align: left;
}
.pfo-table tbody tr:nth-child(odd)  { background: #fcfdfe; }
.pfo-table tbody tr:hover           { background: #f1f5f9; }
.pfo-table td {
  border-bottom: 1px solid #f1f5f9;
  color: #1e293b;
  padding: 10px 12px;
  vertical-align: middle;
}
.pfo-td-cat  { font-weight: 500; text-align: left; }
.pfo-td-num  { text-align: right; white-space: nowrap; }
.pfo-td-na   { color: #cbd5e1; }
.pfo-td-focal { color: %s; font-weight: 600; }
.pfo-pill {
  border-radius: 4px;
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 0.03em;
  padding: 2px 6px;
  text-transform: uppercase;
}
.pfo-pill-deep  { background: #ecfdf5; color: #047857; }
.pfo-pill-aware { background: #f1f5f9; color: #64748b; }
.pfo-gap-leader {
  background: #fef3c7;
  border-radius: 4px;
  color: #92400e;
  font-size: 10px;
  font-weight: 600;
  padding: 2px 6px;
}
.pfo-table-note {
  color: #94a3b8;
  font-size: 11px;
  margin: 8px 0 0;
}

/* Deep-dive competitive cards */
.pfo-deep-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
}
.pfo-deep-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: 14px 16px;
}
.pfo-deep-card-head {
  align-items: baseline;
  display: flex;
  justify-content: space-between;
  margin-bottom: 10px;
}
.pfo-deep-card-title {
  color: #1e293b;
  font-size: 13px;
  font-weight: 600;
}
.pfo-deep-card-rank {
  color: %s;
  font-size: 11px;
  font-weight: 600;
}
.pfo-deep-card-kpis {
  border-bottom: 1px solid #f1f5f9;
  display: flex;
  gap: 16px;
  margin-bottom: 10px;
  padding-bottom: 10px;
}
.pfo-deep-card-kpis > div { display: flex; flex-direction: column; }
.pfo-kpi-mini-v {
  color: #1e293b;
  font-size: 16px;
  font-weight: 700;
  line-height: 1;
}
.pfo-kpi-mini-l {
  color: #94a3b8;
  font-size: 10px;
  margin-top: 2px;
  text-transform: uppercase;
}
.pfo-deep-rank { width: 100%%; }
.pfo-deep-rank td {
  border: 0;
  color: #475569;
  font-size: 11px;
  padding: 4px 0;
}
.pfo-deep-focal td {
  color: %s;
  font-weight: 600;
}
", focal_colour, focal_colour, focal_colour, focal_colour)
}
