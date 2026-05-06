# ==============================================================================
# BRAND MODULE - DBA PANEL CSS
# ==============================================================================
# Self-contained CSS for the DBA panel. Function name follows the
# convention used by every other brand panel (build_X_panel_styles)
# so the html_report main loader auto-includes it via its existence
# check.
#
# Classes are namespaced to .dba-* to avoid collisions with the legacy
# DBA chart+table path (still wired in commit 1; removed in commit 2).
#
# Colours respect the brand_colour_cfg argument (focal_colour) when
# supplied; otherwise fall back to the cool-navy default used by other
# brand panels.
#
# VERSION: 1.0
# ==============================================================================

BRAND_DBA_PANEL_STYLES_VERSION <- "1.0"


#' Build the DBA panel CSS bundle
#'
#' @param brand_colour_cfg List with optional \code{focal_colour} hex
#'   string. When omitted, defaults to the brand-module navy.
#' @return Character. CSS string, no surrounding \code{<style>} tags.
#' @export
build_dba_panel_styles <- function(brand_colour_cfg = NULL) {
  focal <- brand_colour_cfg$focal_colour %||% "#1A5276"
  sprintf(
'/* === DBA panel === */
.dba-panel{
  --dba-brand: %s;
  background:#ffffff;border:1px solid #e6e3da;border-radius:10px;
  padding:24px 28px;margin:24px 0;
}
.dba-panel-body{display:block;}

/* Sub-nav (mirrors .ma-sub-tabs visual contract) */
.dba-subnav{
  display:flex;gap:4px;margin-bottom:18px;
  border-bottom:1px solid #e6e3da;
}
.dba-subtab-btn{
  appearance:none;border:0;background:transparent;
  padding:10px 16px;font-size:14px;font-weight:600;
  color:#5e574a;cursor:pointer;
  border-bottom:2px solid transparent;
  transition:color 120ms ease, border-color 120ms ease;
}
.dba-subtab-btn:hover{color:#1f2933;}
.dba-subtab-btn.active{
  color:var(--dba-brand);border-bottom-color:var(--dba-brand);
}
.dba-subtab-btn:focus-visible{
  outline:2px solid var(--dba-brand);outline-offset:2px;border-radius:2px;
}

.dba-subtab[hidden]{display:none;}

/* === Quadrant view === */
.dba-quadrant-wrap{display:flex;flex-direction:column;gap:14px;}
.dba-quadrant-chart{
  width:100%%;max-width:780px;margin:0 auto;
  background:#ffffff;border:1px solid #e6e3da;border-radius:8px;
  padding:8px 12px;
}
.dba-quadrant-svg{width:100%%;height:auto;display:block;}
.dba-quadrant-legend{
  display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));
  gap:8px 24px;margin:0;
  font-size:13px;color:#3b424c;
}
.dba-quadrant-legend dt{font-weight:600;display:inline;color:#1f2933;}
.dba-quadrant-legend dd{display:inline;margin:0 0 0 6px;}
.dba-quadrant-legend > div{display:block;}

/* Hidden (visually) screen-reader fallback table */
.dba-quadrant-sr-only{
  position:absolute;width:1px;height:1px;padding:0;margin:-1px;
  overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0;
}

/* === Asset detail grid === */
.dba-detail-grid{
  display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));
  gap:18px;margin-top:6px;
}
.dba-detail-card{
  background:#fbfaf6;border:1px solid #e6e3da;border-radius:10px;
  padding:18px 20px;display:flex;flex-direction:column;gap:14px;
}
.dba-detail-header{
  display:flex;justify-content:space-between;align-items:baseline;gap:12px;
}
.dba-detail-title{
  margin:0;font-size:16px;font-weight:600;color:#1f2933;
}
.dba-detail-code{
  font-size:11px;color:#7d756a;letter-spacing:0.6px;text-transform:uppercase;
  font-weight:600;
}
.dba-detail-image-wrap{
  width:100%%;max-height:160px;display:flex;align-items:center;
  justify-content:center;background:#ffffff;border:1px solid #efece4;
  border-radius:6px;padding:10px;
}
.dba-detail-image{max-width:100%%;max-height:140px;object-fit:contain;}
.dba-detail-image-placeholder{
  flex-direction:column;gap:6px;color:#9c9587;
  background:#f5f2ea;
}
.dba-detail-image-placeholder svg{width:80px;height:60px;display:block;}
.dba-detail-image-placeholder-label{
  font-size:11px;letter-spacing:0.6px;text-transform:uppercase;
  font-weight:600;color:#9c9587;
}

.dba-detail-quadrant{display:flex;flex-direction:column;gap:4px;}
.dba-detail-quadrant-badge{
  align-self:flex-start;
  display:inline-block;padding:4px 10px;border-radius:999px;
  background:#efece4;color:#5e574a;
  font-size:11px;font-weight:700;letter-spacing:0.5px;text-transform:uppercase;
}
.dba-detail-quadrant[data-quadrant="Use or Lose"] .dba-detail-quadrant-badge{
  background:#dceae0;color:#256048;
}
.dba-detail-quadrant[data-quadrant="Avoid Alone"] .dba-detail-quadrant-badge{
  background:#f5e0d6;color:#7a3a1a;
}
.dba-detail-quadrant[data-quadrant="Invest to Build"] .dba-detail-quadrant-badge{
  background:#e0e8f3;color:#274d7a;
}
.dba-detail-quadrant[data-quadrant="Ignore or Test"] .dba-detail-quadrant-badge{
  background:#ece8df;color:#5e574a;
}
.dba-detail-action{margin:0;font-size:13px;color:#3b424c;line-height:1.5;}

.dba-detail-metric{display:flex;flex-direction:column;gap:6px;}
.dba-detail-metric-label{
  font-size:12px;color:#7d756a;font-weight:600;
  letter-spacing:0.4px;text-transform:uppercase;
}
.dba-detail-metric-row{display:grid;grid-template-columns:64px 1fr;align-items:center;gap:12px;}
.dba-detail-metric-value{font-size:22px;font-weight:700;line-height:1.1;}
.dba-detail-metric-empty{font-size:13px;color:#9c9587;font-style:italic;}
.dba-detail-metric-bar{display:flex;flex-direction:column;gap:4px;}
.dba-detail-metric-bar-track{
  position:relative;height:14px;background:#efece4;border-radius:7px;
}
.dba-detail-metric-bar-band{
  position:absolute;top:2px;height:10px;border-radius:5px;
}
.dba-detail-metric-bar-point{
  position:absolute;top:0;width:3px;height:14px;border-radius:1.5px;
}
.dba-detail-metric-ci{font-size:11px;color:#7d756a;}
.dba-detail-metric-helper{font-size:12px;color:#7d756a;line-height:1.4;}
.dba-detail-footer{
  font-size:11px;color:#9c9587;border-top:1px solid #efece4;padding-top:8px;
}

/* === Insight box (mirrors .ma-insight-box visual) === */
.dba-insight-box{
  margin-top:24px;padding:16px 20px;
  background:#fbfaf6;border:1px solid #e6e3da;border-radius:8px;
}
.dba-insight-title{
  margin:0 0 8px 0;font-size:13px;font-weight:700;
  color:#7d756a;letter-spacing:0.5px;text-transform:uppercase;
}
.dba-insight-list{margin:0;padding-left:18px;list-style:none;}
.dba-insight-item{
  position:relative;padding-left:8px;margin:6px 0;
  font-size:14px;line-height:1.5;color:#1f2933;
}
.dba-insight-verb{
  display:inline-block;min-width:64px;padding:2px 8px;margin-right:10px;
  border-radius:4px;background:#efece4;color:#5e574a;
  font-size:11px;font-weight:700;letter-spacing:0.4px;text-transform:uppercase;
  text-align:center;vertical-align:1px;
}
.dba-insight-text{display:inline;}

/* === Empty / refused states === */
.dba-panel-empty{
  padding:24px 28px;background:#fbfaf6;border:1px solid #e6e3da;
  border-radius:8px;color:#5e574a;font-size:14px;
}
.dba-quadrant-empty,
.dba-detail-empty{
  padding:18px;color:#7d756a;font-size:13px;text-align:center;
}

/* === Theme-dark overrides (host page sets .theme-dark on body) === */
.theme-dark .dba-panel{
  background:#1e2733;border-color:#2c3a4a;
}
.theme-dark .dba-subnav{border-bottom-color:#2c3a4a;}
.theme-dark .dba-subtab-btn{color:#bcc4cd;}
.theme-dark .dba-subtab-btn.active{color:var(--dba-brand);}
.theme-dark .dba-detail-card{background:#16202b;border-color:#2c3a4a;}
.theme-dark .dba-detail-title{color:#e6ebf1;}
.theme-dark .dba-detail-action{color:#bcc4cd;}
.theme-dark .dba-detail-metric-helper,
.theme-dark .dba-detail-metric-ci,
.theme-dark .dba-detail-footer{color:#9aa3ad;}
.theme-dark .dba-insight-box{background:#16202b;border-color:#2c3a4a;}
.theme-dark .dba-insight-item{color:#e6ebf1;}

/* === Print: keep layout intact for PDF/PNG capture === */
@media print{
  .dba-panel{break-inside:avoid;}
  .dba-detail-card{break-inside:avoid;}
}
',
    focal)
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand DBA panel styles loaded (v%s)",
                  BRAND_DBA_PANEL_STYLES_VERSION))
}
