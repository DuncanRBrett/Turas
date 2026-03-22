# ==============================================================================
# TURAS DESIGN SYSTEM - DESIGN TOKENS
# ==============================================================================
# Centralised design tokens for all Turas HTML reports.
# Provides consistent typography, spacing, colours, and CSS custom properties
# across all modules. Each module calls turas_design_tokens() to get values
# and turas_css_variables() to generate the :root CSS block.
#
# VERSION: 1.0.0
# ==============================================================================


#' Get Turas Design Tokens
#'
#' Returns a named list of all design tokens used across the platform.
#' Modules should use these values rather than hardcoding strings.
#'
#' @param brand_colour Character. Module brand hex colour (default "#323367")
#' @param accent_colour Character. Accent hex colour (default "#CC9900")
#' @return Named list of token categories (typography, spacing, colours, etc.)
#' @export
turas_design_tokens <- function(brand_colour = "#323367",
                                accent_colour = "#CC9900") {
  list(
    # --- Typography ---
    font_family      = "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
    font_family_mono = "ui-monospace, 'SF Mono', Consolas, 'Liberation Mono', monospace",

    # Type scale (modular, based on 1rem = 14px base)
    font_size_xs     = "10px",
    font_size_sm     = "11px",
    font_size_base   = "13px",
    font_size_md     = "14px",
    font_size_lg     = "16px",
    font_size_xl     = "18px",
    font_size_2xl    = "22px",
    font_size_3xl    = "26px",

    font_weight_normal  = "400",
    font_weight_medium  = "500",
    font_weight_semi    = "600",
    font_weight_bold    = "700",

    line_height_tight   = "1.25",
    line_height_normal  = "1.5",
    line_height_relaxed = "1.65",

    letter_spacing_tight  = "-0.3px",
    letter_spacing_normal = "0",
    letter_spacing_wide   = "0.5px",
    letter_spacing_caps   = "1.2px",

    # --- Spacing scale (4px base) ---
    space_1  = "4px",
    space_2  = "8px",
    space_3  = "12px",
    space_4  = "16px",
    space_5  = "20px",
    space_6  = "24px",
    space_7  = "28px",
    space_8  = "32px",
    space_10 = "40px",
    space_12 = "48px",

    # --- Colours ---
    brand         = brand_colour,
    accent        = accent_colour,

    # Text
    text_primary   = "#1e293b",
    text_secondary = "#64748b",
    text_tertiary  = "#94a3b8",
    text_inverse   = "#ffffff",

    # Backgrounds
    bg_page        = "#f8f7f5",
    bg_surface     = "#ffffff",
    bg_muted       = "#f8f9fa",
    bg_subtle      = "#f0f4f8",
    bg_header_from = "#1a2744",
    bg_header_to   = "#2a3f5f",

    # Borders
    border_default  = "#e2e8f0",
    border_strong   = "#cbd5e1",
    border_subtle   = "#f0f0f0",

    # Status
    status_success  = "#059669",
    status_success_bg = "rgba(5,150,105,0.08)",
    status_warning  = "#c9a96e",
    status_error    = "#b85450",
    low_base_colour = "#e8614d",

    # --- Borders & Radii ---
    radius_sm  = "4px",
    radius_md  = "6px",
    radius_lg  = "8px",
    radius_xl  = "12px",
    radius_full = "9999px",

    # --- Shadows ---
    shadow_sm   = "0 1px 2px rgba(0,0,0,0.04)",
    shadow_md   = "0 2px 8px rgba(0,0,0,0.06)",
    shadow_lg   = "0 4px 16px rgba(0,0,0,0.08)",
    shadow_card = "0 1px 3px rgba(0,0,0,0.04), 0 1px 2px rgba(0,0,0,0.02)",

    # --- Transitions ---
    transition_fast   = "0.15s ease",
    transition_normal = "0.2s ease",
    transition_slow   = "0.3s ease",

    # --- Layout ---
    max_width_content = "1400px",
    max_width_hub     = "1600px",
    sidebar_width     = "280px",

    # --- Chart tokens ---
    chart_grid_colour    = "#e2e8f0",
    chart_axis_colour    = "#94a3b8",
    chart_label_colour   = "#64748b",
    chart_value_colour   = "#1e293b",
    chart_bar_radius     = "4",
    chart_label_size     = "11",
    chart_axis_size      = "10",
    chart_title_size     = "13",
    chart_value_weight   = "500",

    # --- Table tokens ---
    table_header_bg      = "#f8f9fa",
    table_header_border  = "2px solid #e2e8f0",
    table_cell_border    = "1px solid #f0f0f0",
    table_row_hover      = "#f8f9fb",
    table_base_row_bg    = "#fafbfc",
    table_net_row_bg     = "#f5f3ef",
    table_mean_row_bg    = "#faf8f4",
    table_separator      = "2px solid #cbd5e1"
  )
}


#' Generate CSS Custom Properties Block
#'
#' Generates the :root { ... } CSS block with all design tokens as custom
#' properties. Modules include this at the top of their stylesheet.
#'
#' @param brand_colour Character. Module brand colour
#' @param accent_colour Character. Module accent colour
#' @param prefix Character. CSS variable prefix (e.g., "ct" for crosstabs,
#'   "kd" for keydriver). Default "t" for turas.
#' @return Character string of CSS
#' @export
turas_css_variables <- function(brand_colour = "#323367",
                                accent_colour = "#CC9900",
                                prefix = "t") {
  tk <- turas_design_tokens(brand_colour, accent_colour)
  p <- prefix

  sprintf('
    :root {
      /* Brand */
      --%s-brand: %s;
      --%s-accent: %s;

      /* Typography */
      --%s-font: %s;
      --%s-font-mono: %s;

      /* Text */
      --%s-text-primary: %s;
      --%s-text-secondary: %s;
      --%s-text-tertiary: %s;

      /* Backgrounds */
      --%s-bg-page: %s;
      --%s-bg-surface: %s;
      --%s-bg-muted: %s;

      /* Borders */
      --%s-border: %s;
      --%s-border-strong: %s;

      /* Status */
      --%s-success: %s;
      --%s-warning: %s;
      --%s-error: %s;

      /* Radii */
      --%s-radius-sm: %s;
      --%s-radius-md: %s;
      --%s-radius-lg: %s;

      /* Shadows */
      --%s-shadow-sm: %s;
      --%s-shadow-md: %s;
      --%s-shadow-card: %s;

      /* Transitions */
      --%s-transition-fast: %s;
      --%s-transition-normal: %s;

      /* Legacy aliases (backward compat during migration) */
      --brand-colour: %s;
      --ct-brand: %s;
      --ct-accent: %s;
      --ct-text-primary: %s;
      --ct-text-secondary: %s;
      --ct-bg-surface: %s;
      --ct-bg-muted: %s;
      --ct-border: %s;
    }',
    p, tk$brand,
    p, tk$accent,
    p, tk$font_family,
    p, tk$font_family_mono,
    p, tk$text_primary,
    p, tk$text_secondary,
    p, tk$text_tertiary,
    p, tk$bg_page,
    p, tk$bg_surface,
    p, tk$bg_muted,
    p, tk$border_default,
    p, tk$border_strong,
    p, tk$status_success,
    p, tk$status_warning,
    p, tk$status_error,
    p, tk$radius_sm,
    p, tk$radius_md,
    p, tk$radius_lg,
    p, tk$shadow_sm,
    p, tk$shadow_md,
    p, tk$shadow_card,
    p, tk$transition_fast,
    p, tk$transition_normal,
    # Legacy aliases
    tk$brand,
    tk$brand,
    tk$accent,
    tk$text_primary,
    tk$text_secondary,
    tk$bg_surface,
    tk$bg_muted,
    tk$border_default
  )
}
