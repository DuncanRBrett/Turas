# ==============================================================================
# CROSSTABS_CONFIG.R - TURAS V10.2 (Phase 4 Refactoring)
# ==============================================================================
# Extracted from run_crosstabs.R for better modularity
#
# PURPOSE: Configuration loading and config object building
#
# FUNCTIONS:
#   - validate_config_file() - Validate config file exists
#   - load_crosstabs_settings() - Load settings from config file
#   - build_config_object() - Build the config_obj with all settings
#   - load_output_settings() - Load output path settings
#
# DEPENDENCIES:
#   - config_utils.R (for load_config_sheet, get_config_value)
#   - type_utils.R (for safe_logical, safe_numeric)
#   - path_utils.R (for resolve_path, get_project_root)
#   - 00_guard.R (for tabs_refuse)
#   - logging_utils.R (for log_message)
#
# ==============================================================================

# Default constants (should match run_crosstabs.R)
.DEFAULT_ALPHA <- 0.05
.DEFAULT_MIN_BASE <- 30

# Valid values for alpha_default setting
.VALID_ALPHA_DEFAULTS <- c("primary", "secondary")

# ==============================================================================
# VALIDATION
# ==============================================================================

#' Convert Alpha to Confidence Level Label
#'
#' Converts a significance level (alpha) to a human-readable row label
#' for use in Excel output and HTML report display when dual significance
#' levels are configured.
#'
#' @param alpha Numeric, significance level (e.g. 0.05)
#' @return Character, label such as "Sig. (95%)"
#'
#' @examples
#' alpha_to_confidence_label(0.05)  # "Sig. (95%)"
#' alpha_to_confidence_label(0.10)  # "Sig. (90%)"
#'
#' @keywords internal
alpha_to_confidence_label <- function(alpha) {
  pct <- round((1 - alpha) * 100)
  sprintf("Sig. (%d%%)", pct)
}


#' Validate Config File Exists
#'
#' Checks that the config_file variable is defined and the file exists.
#'
#' @param config_file Character, path to config file (or NULL if undefined)
#' @return Invisible TRUE if valid
#' @export
validate_config_file <- function(config_file = NULL) {
  # Check if config_file is defined
  if (is.null(config_file) || !exists("config_file", envir = parent.frame())) {
    tabs_refuse(
      code = "CFG_NO_CONFIG_FILE",
      title = "Configuration File Not Defined",
      problem = "The config_file variable is not defined.",
      why_it_matters = "Analysis requires a configuration file to specify data sources and settings.",
      how_to_fix = c(
        "Run this script from the Jupyter notebook entry point",
        "Or set config_file variable before sourcing this script"
      )
    )
  }

  invisible(TRUE)
}


#' Validate Structure File Exists
#'
#' Checks that the survey structure file exists at the specified path.
#'
#' @param structure_file_path Character, path to structure file
#' @return Invisible TRUE if valid
validate_structure_file <- function(structure_file_path) {
  if (!file.exists(structure_file_path)) {
    tabs_refuse(
      code = "IO_STRUCTURE_FILE_NOT_FOUND",
      title = "Survey Structure File Not Found",
      problem = paste0("Cannot find survey structure file: ", basename(structure_file_path)),
      why_it_matters = "The survey structure defines questions and options needed for crosstabs.",
      how_to_fix = c(
        "Check that the structure_file path in Settings is correct",
        "Verify Survey_Structure.xlsx exists in your project folder"
      ),
      details = paste0("Expected path: ", structure_file_path)
    )
  }

  invisible(TRUE)
}


# ==============================================================================
# CONFIG LOADING
# ==============================================================================

#' Load Crosstabs Settings from Config File
#'
#' Loads the Settings sheet from the config file and extracts key paths.
#'
#' @param config_file Character, path to config file
#' @param project_root Character, project root directory
#' @return List with config data frame and paths
#' @export
load_crosstabs_settings <- function(config_file, project_root) {
  log_message("Loading configuration...", "INFO")

  # Load settings sheet
  config <- load_config_sheet(config_file, "Settings")

  # Get structure file path
  structure_file <- get_config_value(config, "structure_file", required = TRUE)
  structure_file <- normalize_path_separators(structure_file)
  structure_file_path <- resolve_path(project_root, structure_file)

  # Validate structure file exists
  validate_structure_file(structure_file_path)

  # Get output settings
  output_subfolder <- get_config_value(config, "output_subfolder", "Crosstabs")
  output_filename <- get_config_value(config, "output_filename", "Crosstabs.xlsx")

  log_message("Configuration loaded", "INFO")

  list(
    config = config,
    structure_file_path = structure_file_path,
    output_subfolder = output_subfolder,
    output_filename = output_filename
  )
}


#' Build Configuration Object
#'
#' Builds the config_obj list with all analysis settings.
#' Uses safe_logical and safe_numeric for type conversion.
#'
#' @param config Data frame, loaded settings
#' @param default_alpha Numeric, default alpha value (default: 0.05)
#' @param default_min_base Integer, default minimum base (default: 30)
#' @return List, configuration object
#' @export
build_config_object <- function(config, default_alpha = .DEFAULT_ALPHA,
                                 default_min_base = .DEFAULT_MIN_BASE) {
  list(
    # Weighting settings
    apply_weighting = safe_logical(get_config_value(config, "apply_weighting", FALSE), default = FALSE),
    weight_variable = get_config_value(config, "weight_variable", NULL),
    show_unweighted_n = safe_logical(get_config_value(config, "show_unweighted_n", TRUE), default = TRUE),
    show_effective_n = safe_logical(get_config_value(config, "show_effective_n", TRUE), default = TRUE),
    show_weighted_base = safe_logical(get_config_value(config, "show_weighted_base", TRUE), default = TRUE),
    weight_label = get_config_value(config, "weight_label", "Weighted"),

    # Display settings
    decimal_separator = get_config_value(config, "decimal_separator", "."),
    show_frequency = safe_logical(get_config_value(config, "show_frequency", TRUE), default = TRUE),
    show_percent_column = safe_logical(get_config_value(config, "show_percent_column", TRUE), default = TRUE),
    show_percent_row = safe_logical(get_config_value(config, "show_percent_row", FALSE), default = FALSE),

    # Box category settings
    boxcategory_frequency = safe_logical(get_config_value(config, "boxcategory_frequency", FALSE), default = FALSE),
    boxcategory_percent_column = safe_logical(get_config_value(config, "boxcategory_percent_column", TRUE), default = TRUE),
    boxcategory_percent_row = safe_logical(get_config_value(config, "boxcategory_percent_row", FALSE), default = FALSE),

    # Decimal places
    decimal_places_percent = safe_numeric(get_config_value(config, "decimal_places_percent", 0)),
    decimal_places_ratings = safe_numeric(get_config_value(config, "decimal_places_ratings", 1)),
    decimal_places_index = safe_numeric(get_config_value(config, "decimal_places_index", 1)),
    decimal_places_numeric = safe_numeric(get_config_value(config, "decimal_places_numeric", 1)),

    # Significance testing
    enable_significance_testing = safe_logical(get_config_value(config, "enable_significance_testing", TRUE), default = TRUE),
    alpha = safe_numeric(get_config_value(config, "alpha", default_alpha)),
    significance_min_base = safe_numeric(get_config_value(config, "significance_min_base", default_min_base)),
    bonferroni_correction = safe_logical(get_config_value(config, "bonferroni_correction", TRUE), default = TRUE),

    # Dual significance level toggle (optional — V10.10)
    # Set alpha_secondary to enable a second significance level in HTML reports.
    # Leave blank/absent to disable the feature (zero impact on existing reports).
    alpha_secondary = {
      raw <- get_config_value(config, "alpha_secondary", NULL)
      if (is.null(raw) || is.na(suppressWarnings(as.numeric(raw)))) NULL else safe_numeric(raw)
    },
    alpha_default = get_config_value(config, "alpha_default", "primary"),

    # Checkpointing
    enable_checkpointing = safe_logical(get_config_value(config, "enable_checkpointing", TRUE), default = TRUE),

    # Output formatting
    zero_division_as_blank = safe_logical(get_config_value(config, "zero_division_as_blank", TRUE), default = TRUE),

    # V9.9.5 features
    show_standard_deviation = safe_logical(get_config_value(config, "show_standard_deviation", FALSE), default = FALSE),
    test_net_differences = safe_logical(get_config_value(config, "test_net_differences", FALSE), default = FALSE),
    create_sample_composition = safe_logical(get_config_value(config, "create_sample_composition", FALSE), default = FALSE),
    enable_chi_square = safe_logical(get_config_value(config, "enable_chi_square", FALSE), default = FALSE),
    show_net_positive = safe_logical(get_config_value(config, "show_net_positive", FALSE), default = FALSE),

    # V10.0.0 numeric question settings
    show_numeric_median = safe_logical(get_config_value(config, "show_numeric_median", FALSE), default = FALSE),
    show_numeric_mode = safe_logical(get_config_value(config, "show_numeric_mode", FALSE), default = FALSE),
    show_numeric_outliers = safe_logical(get_config_value(config, "show_numeric_outliers", TRUE), default = TRUE),
    exclude_outliers_from_stats = safe_logical(get_config_value(config, "exclude_outliers_from_stats", FALSE), default = FALSE),
    outlier_method = get_config_value(config, "outlier_method", "IQR"),

    # Stats pack (contractual deliverable — defaults to Y)
    generate_stats_pack = get_config_value(config, "generate_stats_pack", "Y"),

    # (html_report — the classic HTML report — is RETIRED. It is not read here
    # any more; a config that still carries the row is answered by name in
    # TABS_RETIRED_SETTINGS rather than silently ignored.)

    # V11 data-centric report (data-layer JSON for the v2 renderer).
    # Additive: when TRUE, a *_data.json island is written alongside the
    # Excel workbook. The workbook is untouched when FALSE.
    html_report_v2 = safe_logical(get_config_value(config, "html_report_v2", FALSE), default = FALSE),
    # Whether the Settings sheet EXPLICITLY set html_report_v2 (I16): an
    # explicit FALSE must beat the GUI's default-ON — a confidentiality-driven
    # opt-out was silently overridden before. Internal, not a Settings name.
    html_report_v2_explicit = !is.null(get_config_value(config, "html_report_v2", NULL)),
    # V13 confidentiality dial (ON by default = today's behaviour). FALSE omits
    # the anonymised per-respondent DATA_MICRO island from the v2 report — the
    # aggregates-only ship for insider populations (small staff surveys) where
    # coded records + banner cuts could re-identify individuals. Only an
    # explicit FALSE disables: blank/junk cells keep the island (default TRUE
    # passed to safe_logical too, so a stringified-"NA" cell cannot flip it).
    html_report_v2_microdata = safe_logical(
      get_config_value(config, "html_report_v2_microdata", TRUE), default = TRUE),
    # V11 tabs-integrated tracker (OFF by default). When TRUE AND a waves_source
    # resolves, the v2 report gains a Tracking tab built from anonymised per-wave
    # microdata. Independent of the standalone tracker module, which is untouched.
    html_report_v2_tracking = safe_logical(get_config_value(config, "html_report_v2_tracking", FALSE), default = FALSE),
    # Folder holding prior waves' *_wave.json tracking contributions (emitted by
    # each wave's own tabs run). Empty -> no history, Tracking tab stays hidden.
    waves_source = get_config_value(config, "waves_source", ""),
    # Optional classic-tracker Question_Mapping workbook: links waves by a
    # canonical key (robust to renames) + curates which metrics track. Empty ->
    # the tabs-tracker falls back to matching metrics by question title.
    question_mapping = get_config_value(config, "question_mapping", ""),
    # Numeric x-axis order key for this wave (e.g. 2025 or 2025.5 for twice-yearly
    # so two same-year waves never collide). Blank -> derived from the wave label.
    wave_order = get_config_value(config, "wave_order", ""),
    # Sample design — drives honest confidence vocabulary in the v2 report
    # (probability designs speak CI/MOE; non-probability designs speak the
    # softened SI/PE). Cautious default: Not_Specified -> SI/PE. The value is
    # normalised to its canonical token here ("stratified" -> "Stratified");
    # an unrecognised token refuses in validate_config_settings (I5) — it
    # would otherwise silently flip the whole report's confidence vocabulary.
    sampling_method = normalise_sampling_method(
      get_config_value(config, "sampling_method", "Not_Specified")),
    # Total universe size for a census / full-invite design — drives the finite
    # population correction (FPC) on the Total column and the report's overall
    # response/coverage rate. Per-subgroup populations live in the optional
    # Population sheet. Blank/absent -> no correction (byte-identical to today).
    population_size = {
      raw <- get_config_value(config, "population_size", NULL)
      n <- suppressWarnings(as.numeric(raw))
      if (is.null(raw) || length(n) != 1L || is.na(n) || n <= 1) NULL else n
    },
    # Optional wave label shown in the v2 report header (e.g. "Annual 2025").
    wave = get_config_value(config, "wave", ""),

    # Qualitative tab (V12). qual_workbook (a coded-comment .xlsx path) -> the
    # comments are JOINED into the main report by ResponseID (Phase 2); if that join
    # cannot resolve, a self-contained *_qual_report.html is emitted as a fallback.
    # The three confidentiality dials: text level (hidden default / redacted / full),
    # demographic association (allow / block), and the noteworthy-tier default view.
    # qual_join_id_column overrides the auto-detected host response-id column.
    qual_workbook = get_config_value(config, "qual_workbook", ""),
    qual_confidentiality_mode = get_config_value(config, "qual_confidentiality_mode", "hidden"),
    qual_demographic_cuts = get_config_value(config, "qual_demographic_cuts", "allow"),
    qual_noteworthy_default = get_config_value(config, "qual_noteworthy_default", "all"),
    # Verbatim scope: which comments ship readable text. "all" = every comment except
    # hide-marked ones; "noteworthy" = only tier >= 1 (noteworthy/must-read/priority).
    # Withheld comments still count in the distribution — only their text is withheld.
    qual_verbatim_scope = get_config_value(config, "qual_verbatim_scope", "all"),
    qual_join_id_column = get_config_value(config, "qual_join_id_column", ""),
    # Host-survey columns exposed as comment tags (Feature 2): "Col:Label, Col:Label".
    # Must be populated here — config_obj is an explicit whitelist, not the raw settings.
    qual_tag_dimensions = get_config_value(config, "qual_tag_dimensions", ""),
    # Whitelisted alongside their siblings above (qual_*, min_reporting_base
    # already loaded below): heatmap_colour and research_house are both
    # genuine, template-documented settings that were readable downstream
    # (02_table_builder.R, stats_diagnostics.R) but never populated here,
    # so they were silent no-ops even when set.
    heatmap_colour = get_config_value(config, "heatmap_colour", ""),
    research_house = get_config_value(config, "research_house", "The Research LampPost"),

    # Disclosure control (V13). The minimum audience base below which the report
    # withholds identifying detail — the demographic tags on comments now, small
    # crosstab cells next — so a composite filter (e.g. 1st-year promoters in Cape
    # Town) cannot be narrowed onto a handful of identifiable people. Default 1 = off
    # (existing reports unchanged). For a small / sensitive sample such as a 200-person
    # staff climate survey, set it to 10; set it to the full sample size to forbid
    # sub-group identification entirely (only the full-sample view shows detail).
    min_reporting_base = safe_numeric(get_config_value(config, "min_reporting_base", 1)),

    # Tab-visibility flags (V12, generic). Crosstabs is always on; each other tab
    # is includable per report. The flags ride into the data layer; tabList()
    # filters against them (a tab also self-hides when its island is absent).
    show_dashboard = safe_logical(get_config_value(config, "show_dashboard", TRUE), default = TRUE),
    show_patterns = safe_logical(get_config_value(config, "show_patterns", TRUE), default = TRUE),
    show_differences = safe_logical(get_config_value(config, "show_differences", TRUE), default = TRUE),
    show_tracking = safe_logical(get_config_value(config, "show_tracking", TRUE), default = TRUE),
    show_qualitative = safe_logical(get_config_value(config, "show_qualitative", TRUE), default = TRUE),

    # Patterns-tab levers (optional). patterns_headline pins the apex KPI tiles
    # to these question codes, in order (e.g. "Q78, Q79") — otherwise the tab
    # auto-detects satisfaction/overall-titled questions, which on a study with
    # many section ratings picks the wrong ones. patterns_exclude_banners keeps
    # operational cuts (e.g. "Interviewer") out of the Patterns scan entirely —
    # a fieldwork-QC banner must never become the client-facing lead portrait.
    # Comma/semicolon-separated; parsed in the data layer.
    patterns_headline = get_config_value(config, "patterns_headline", NULL),
    patterns_exclude_banners = get_config_value(config, "patterns_exclude_banners", NULL),
    # The POSITIVE banner selection for the Group overview tab: name the banner
    # group(s) to portray (e.g. "Centre"; comma-separated for a second banner).
    # Unset -> every banner group, as before.
    patterns_banner = get_config_value(config, "patterns_banner", NULL),

    # Free-text fieldwork caveat appended to the "how sure" design sentence in
    # the v2 report (e.g. substitution rules, replaced clusters, low response).
    # The generated design wording covers the textbook design; this carries the
    # honest asterisk where fieldwork reality deviated from it.
    sampling_note = get_config_value(config, "sampling_note", NULL),

    brand_colour = get_config_value(config, "brand_colour", "#323367"),
    accent_colour = get_config_value(config, "accent_colour", "#CC9900"),
    project_title = get_config_value(config, "project_title", NULL),
    company_name = get_config_value(config, "company_name", "The Research LampPost"),
    client_name = get_config_value(config, "client_name", NULL),
    researcher_logo_path = get_config_value(config, "researcher_logo_path", NULL),
    client_logo_path = get_config_value(config, "client_logo_path", NULL),
    logo_path = get_config_value(config, "logo_path", NULL),
    chart_bar_colour = get_config_value(config, "chart_bar_colour", NULL),
    chart_palette_preset = get_config_value(config, "chart_palette_preset", "warm"),
    chart_series_colour_1 = get_config_value(config, "chart_series_colour_1", NULL),
    chart_series_colour_2 = get_config_value(config, "chart_series_colour_2", NULL),
    chart_series_colour_3 = get_config_value(config, "chart_series_colour_3", NULL),
    chart_series_colour_4 = get_config_value(config, "chart_series_colour_4", NULL),
    chart_series_colour_5 = get_config_value(config, "chart_series_colour_5", NULL),
    chart_series_colour_6 = get_config_value(config, "chart_series_colour_6", NULL),
    chart_series_colour_7 = get_config_value(config, "chart_series_colour_7", NULL),
    chart_series_colour_8 = get_config_value(config, "chart_series_colour_8", NULL),
    embed_frequencies = safe_logical(get_config_value(config, "embed_frequencies", TRUE), default = TRUE),

    # V10.4 Summary Dashboard settings
    include_summary = safe_logical(get_config_value(config, "include_summary", TRUE), default = TRUE),
    fieldwork_dates = get_config_value(config, "fieldwork_dates", NULL),
    dashboard_metrics = get_config_value(config, "dashboard_metrics", "NET POSITIVE"),

    # V10.4.2 Dashboard colour breaks & scales (all optional, sensible defaults)
    dashboard_scale_mean    = safe_numeric(get_config_value(config, "dashboard_scale_mean", 10), 10),
    dashboard_scale_index   = safe_numeric(get_config_value(config, "dashboard_scale_index", 10), 10),
    dashboard_green_net     = safe_numeric(get_config_value(config, "dashboard_green_net", 30), 30),
    dashboard_amber_net     = safe_numeric(get_config_value(config, "dashboard_amber_net", 0), 0),
    dashboard_green_mean    = safe_numeric(get_config_value(config, "dashboard_green_mean", 7), 7),
    dashboard_amber_mean    = safe_numeric(get_config_value(config, "dashboard_amber_mean", 5), 5),
    dashboard_green_index   = safe_numeric(get_config_value(config, "dashboard_green_index", 7), 7),
    dashboard_amber_index   = safe_numeric(get_config_value(config, "dashboard_amber_index", 5), 5),
    dashboard_green_custom  = safe_numeric(get_config_value(config, "dashboard_green_custom", 60), 60),
    dashboard_amber_custom  = safe_numeric(get_config_value(config, "dashboard_amber_custom", 40), 40),
    dashboard_sort_gauges   = get_config_value(config, "dashboard_sort_gauges", "desc"),

    # V10.4.3 Row descriptors (shown below summary stat rows in HTML crosstabs)
    index_descriptor = get_config_value(config, "index_descriptor", NULL),
    mean_descriptor = get_config_value(config, "mean_descriptor", NULL),
    nps_descriptor = get_config_value(config, "nps_descriptor", NULL),

    # V10.5.0 Inline SVG charts
    show_charts = safe_logical(get_config_value(config, "show_charts", FALSE), default = FALSE),

    # V10.6.0 Report enhancements
    priority_metric = get_config_value(config, "priority_metric", NULL),

    # V10.7.0 Closing section & qualitative content
    analyst_name = get_config_value(config, "analyst_name", NULL),
    analyst_email = get_config_value(config, "analyst_email", NULL),
    analyst_phone = get_config_value(config, "analyst_phone", NULL),
    verbatim_filename = get_config_value(config, "verbatim_filename", NULL),
    closing_notes = get_config_value(config, "closing_notes", NULL),

    # V10.9.0 AI Insights (optional, default FALSE)
    enable_ai_insights = safe_logical(get_config_value(config, "enable_ai_insights", FALSE), default = FALSE),

    # AI model selection — friendly label ("Sonnet 4.6"/"Opus 4.8") or an exact
    # model ID. Resolved in the AI layer; blank uses the sidecar/default model.
    ai_model = get_config_value(config, "ai_model", NULL),

    # V15 Reader report — a separate narrative-summary file written beside the
    # crosstab that deep-links back into it. Opt-in; the GUI checkbox sets
    # TURAS_GENERATE_READER_REPORT, which overrides this. The report is
    # DETERMINISTIC by default (built on-device from the data layer, no AI,
    # nothing leaves the machine). reader_ai_prose sends AGGREGATES ONLY to the
    # model to draft the prose — never microdata or verbatims — and stays off
    # unless the operator explicitly turns it on.
    generate_reader_report = safe_logical(get_config_value(config, "generate_reader_report", FALSE), default = FALSE),
    reader_ai_prose = safe_logical(get_config_value(config, "reader_ai_prose", FALSE), default = FALSE),

    # Index summary (I9): these Settings were whitelisted but never carried
    # into config_obj, so their downstream get_config_value() reads always saw
    # the default — setting create_index_summary = N did nothing, silently.
    # NULL-when-absent defers to each consumer's own default (create_index_
    # summary's default is composites-driven in create_index_summary_safe).
    create_index_summary = get_config_value(config, "create_index_summary", NULL),
    index_summary_show_sections = {
      raw <- get_config_value(config, "index_summary_show_sections", NULL)
      if (is.null(raw)) NULL else safe_logical(raw, default = TRUE)
    },
    index_summary_show_base_sizes = {
      raw <- get_config_value(config, "index_summary_show_base_sizes", NULL)
      if (is.null(raw)) NULL else safe_logical(raw, default = TRUE)
    },
    index_summary_show_composites = {
      raw <- get_config_value(config, "index_summary_show_composites", NULL)
      if (is.null(raw)) NULL else safe_logical(raw, default = TRUE)
    },
    index_summary_decimal_places = {
      raw <- get_config_value(config, "index_summary_decimal_places", NULL)
      if (is.null(raw)) NULL else safe_numeric(raw, 1)
    },

    # Ranking thresholds (I9): same gap — whitelisted, documented, never carried.
    ranking_tie_threshold_pct = {
      raw <- get_config_value(config, "ranking_tie_threshold_pct", NULL)
      if (is.null(raw)) NULL else safe_numeric(raw, 5)
    },
    ranking_gap_threshold_pct = {
      raw <- get_config_value(config, "ranking_gap_threshold_pct", NULL)
      if (is.null(raw)) NULL else safe_numeric(raw, 5)
    },
    ranking_completeness_threshold_pct = {
      raw <- get_config_value(config, "ranking_completeness_threshold_pct", NULL)
      if (is.null(raw)) NULL else safe_numeric(raw, 80)
    },
    ranking_min_base = {
      raw <- get_config_value(config, "ranking_min_base", NULL)
      if (is.null(raw)) NULL else safe_numeric(raw, 30)
    },

    # General decimal-places fallback (I9): read by the workbook builder as the
    # default for cells with no type-specific setting; was never carried.
    decimal_places = {
      raw <- get_config_value(config, "decimal_places", NULL)
      if (is.null(raw)) NULL else safe_numeric(raw, 1)
    },

    # Study identification (I4/I9): the stats pack Declaration and the v2/qual
    # report headers read these from config_obj; they were never carried.
    project_name = get_config_value(config, "project_name", NULL),
    data_file = get_config_value(config, "data_file", NULL),
    structure_file = get_config_value(config, "structure_file", NULL)
  )
}

#' Validate the statistical settings after build_config_object
#'
#' A junk cell in a statistical setting must refuse AT LOAD, naming the cell —
#' not crash mid-run inside a z-test where the orchestrator re-brands it as a
#' per-question DATA_ fault (production review 2026-08, I11). An unrecognised
#' sampling_method must refuse rather than silently soften the report's whole
#' confidence vocabulary (I5).
#'
#' @param config_obj The built config object
#' @param raw_settings The raw settings list (to quote the offending cell)
#' @return Invisible TRUE, or a TRS refusal
#' @keywords internal
validate_config_settings <- function(config_obj, raw_settings = NULL) {
  quote_raw <- function(key) {
    raw <- if (!is.null(raw_settings)) raw_settings[[key]] else NULL
    if (is.null(raw)) "" else sprintf(" (Settings sheet value: '%s')", as.character(raw)[1])
  }
  bad <- function(key, why) {
    tabs_refuse(
      code = "CFG_INVALID_SETTING",
      title = "Invalid Configuration Setting",
      problem = sprintf("Setting '%s' %s%s.", key, why, quote_raw(key)),
      why_it_matters = "Statistical settings drive every test in the run; a junk value would fail mid-run or silently change what the report claims.",
      how_to_fix = c(
        sprintf("Fix the '%s' row on the config Settings sheet", key),
        "Numbers must use '.' as the decimal separator (0.05, not 0,05)"
      )
    )
  }

  a <- config_obj$alpha
  if (!is.numeric(a) || length(a) != 1 || is.na(a) || a <= 0 || a >= 1) {
    bad("alpha", "must be a number strictly between 0 and 1")
  }
  mb <- config_obj$significance_min_base
  if (!is.numeric(mb) || length(mb) != 1 || is.na(mb) || mb < 1) {
    bad("significance_min_base", "must be a number >= 1")
  }
  krb <- config_obj$min_reporting_base
  if (!is.numeric(krb) || length(krb) != 1 || is.na(krb) || krb < 1) {
    bad("min_reporting_base", "must be a number >= 1 (1 = disclosure control off)")
  }
  for (key in c("decimal_places_percent", "decimal_places_ratings",
                "decimal_places_index", "decimal_places_numeric")) {
    d <- config_obj[[key]]
    if (!is.numeric(d) || length(d) != 1 || is.na(d) || d < 0 || d > 6) {
      bad(key, "must be a whole number between 0 and 6")
    }
  }
  sm <- config_obj$sampling_method
  if (!is.null(sm) && nzchar(sm) && !(sm %in% .TABS_SAMPLING_TOKENS)) {
    tabs_refuse(
      code = "CFG_INVALID_SETTING",
      title = "Unrecognised sampling_method",
      problem = sprintf("sampling_method '%s' is not a recognised design token.", sm),
      why_it_matters = "An unrecognised design would silently become 'Not specified' and flip the whole report from confidence-interval to stability-interval vocabulary.",
      how_to_fix = c(
        sprintf("Use one of: %s", paste(.TABS_SAMPLING_TOKENS, collapse = ", ")),
        "Case does not matter - 'stratified' resolves to 'Stratified'"
      )
    )
  }
  invisible(TRUE)
}

# Canonical sampling-method tokens (must match the v2 renderer's METHOD_KEYS in
# 21c_confidence.js and the template dropdown). Self_Selected is the JS synonym
# for Convenience.
.TABS_SAMPLING_TOKENS <- c("Not_Specified", "Random", "Stratified", "Cluster",
                           "Census", "Quota", "Online_Panel", "Convenience",
                           "Self_Selected")

#' Normalise a sampling_method value to its canonical token
#'
#' Case/whitespace-insensitive: "stratified" and " STRATIFIED " both resolve to
#' "Stratified", so a casing slip cannot silently soften the report's whole
#' confidence vocabulary to "Not specified". A token with no canonical match is
#' returned trimmed as-is — validate_config_settings() refuses on it.
#'
#' @param x Raw Settings-sheet value
#' @return Canonical token, or the trimmed original when unrecognised
#' @keywords internal
normalise_sampling_method <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return("Not_Specified")
  v <- trimws(as.character(x[1]))
  if (!nzchar(v)) return("Not_Specified")
  hit <- .TABS_SAMPLING_TOKENS[tolower(.TABS_SAMPLING_TOKENS) == tolower(gsub("[ -]", "_", v))]
  if (length(hit) == 1) hit else v
}


#' Get Output Path
#'
#' Constructs the full output file path.
#'
#' @param project_root Character, project root directory
#' @param output_subfolder Character, output subfolder name
#' @param output_filename Character, output file name
#' @return Character, full output path
#' @export
get_output_path <- function(project_root, output_subfolder, output_filename) {
  resolve_path(project_root, file.path(output_subfolder, output_filename))
}


# ==============================================================================
# COMMENTS SHEET LOADER (V10.6.0)
# ==============================================================================

#' Load Optional Comments Sheet from Config Excel
#'
#' Reads a "Comments" sheet from the config workbook if it exists.
#' Expected columns: QuestionCode, Comment. An optional \code{Headline} column
#' carries a one-line analyst insight headline per question (reader experience
#' plan, section E); a row may carry a Headline with a blank Comment. The first
#' non-blank headline per question wins; headlines are attached as the
#' \code{"headlines"} attribute (named list keyed by QuestionCode).
#' Returns a named list (keyed by question code) or NULL if sheet is absent.
#'
#' @param config_file Character, path to config Excel file
#' @return Named list of comments keyed by QuestionCode (with optional
#'   \code{background_text} / \code{executive_summary} / \code{headlines}
#'   attributes), or NULL
#' @keywords internal
load_comments_sheet <- function(config_file) {
  tryCatch({
    sheets <- openxlsx::getSheetNames(config_file)
    if (!"Comments" %in% sheets) return(NULL)

    # Use .read_table_sheet to auto-detect header row (template format support)
    required_cols <- c("QuestionCode", "Comment")
    df <- tryCatch(
      .read_table_sheet(config_file, "Comments", required_cols),
      error = function(e) NULL
    )
    if (is.null(df) || nrow(df) == 0) return(NULL)

    # Require QuestionCode and Comment columns
    if (!all(required_cols %in% names(df))) {
      cat("  [INFO] Comments sheet found but missing QuestionCode/Comment columns - skipped\n")
      return(NULL)
    }

    # A usable Comment cell (same test the historical row filter applied)
    has_comment <- function(x) !is.na(x) && nzchar(trimws(x))

    # Filter valid rows — QuestionCode is always required; Comment may be blank
    # on a row that only carries a Headline (V13.x)
    df <- df[!is.na(df$QuestionCode) & nzchar(trimws(df$QuestionCode)), , drop = FALSE]
    if (nrow(df) == 0) return(NULL)

    # Support optional Banner column for multi-banner comments
    has_banner <- "Banner" %in% names(df)

    # Extract special dashboard text entries (V10.8.0)
    # Use _BACKGROUND and _EXECUTIVE_SUMMARY as reserved QuestionCode values
    special_codes <- c("_BACKGROUND", "_EXECUTIVE_SUMMARY")
    background_text <- NULL
    executive_summary <- NULL

    for (i in seq_len(nrow(df))) {
      if (!has_comment(df$Comment[i])) next
      q_code <- trimws(toupper(df$QuestionCode[i]))
      if (q_code == "_BACKGROUND") {
        background_text <- trimws(df$Comment[i])
      } else if (q_code == "_EXECUTIVE_SUMMARY") {
        executive_summary <- trimws(df$Comment[i])
      }
    }

    # Filter out special rows from question comments
    df <- df[!trimws(toupper(df$QuestionCode)) %in% special_codes, , drop = FALSE]

    # Optional per-question analyst headline (reader experience plan §E) — the
    # first non-blank Headline per question wins. The loader can surface an
    # empty cell as the literal string "NA"; treat that as blank.
    headlines <- list()
    if ("Headline" %in% names(df)) {
      for (i in seq_len(nrow(df))) {
        h <- df$Headline[i]
        if (is.na(h)) next
        h <- trimws(h)
        if (!nzchar(h) || identical(h, "NA")) next
        q_code <- trimws(df$QuestionCode[i])
        if (is.null(headlines[[q_code]])) headlines[[q_code]] <- h
      }
    }

    # Build structure: comments[[q_code]] = list of list(banner, text)
    comments <- list()
    for (i in seq_len(nrow(df))) {
      if (!has_comment(df$Comment[i])) next
      q_code <- trimws(df$QuestionCode[i])
      banner <- if (has_banner && !is.na(df$Banner[i]) && nzchar(trimws(df$Banner[i]))) {
        trimws(df$Banner[i])
      } else {
        NA_character_  # Serializes as JSON null (not {} like R NULL)
      }
      entry <- list(banner = banner, text = trimws(df$Comment[i]))
      if (is.null(comments[[q_code]])) {
        comments[[q_code]] <- list(entry)
      } else {
        comments[[q_code]] <- c(comments[[q_code]], list(entry))
      }
    }

    # Nothing usable at all -> NULL, exactly as a sheet with no valid rows
    # behaved before the Headline column existed
    if (length(comments) == 0 && length(headlines) == 0 &&
        is.null(background_text) && is.null(executive_summary)) {
      return(NULL)
    }

    n_total <- if (length(comments) > 0) sum(vapply(comments, length, integer(1))) else 0L
    cat(sprintf("  [INFO] Loaded %d comments for %d questions from Comments sheet\n",
                n_total, length(comments)))

    if (!is.null(background_text)) cat(sprintf("  [INFO] Background text loaded from Comments sheet\n"))
    if (!is.null(executive_summary)) cat(sprintf("  [INFO] Executive summary loaded from Comments sheet\n"))
    if (length(headlines) > 0) {
      cat(sprintf("  [INFO] Loaded %d question headline(s) from Comments sheet\n",
                  length(headlines)))
    }

    # Attach dashboard text (and headlines) as attributes
    attr(comments, "background_text") <- background_text
    attr(comments, "executive_summary") <- executive_summary
    if (length(headlines) > 0) attr(comments, "headlines") <- headlines

    comments
  }, error = function(e) {
    cat(sprintf("  [WARNING] Could not read Comments sheet: %s\n", e$message))
    NULL
  })
}


# ==============================================================================
# POPULATION SHEET LOADER (finite population correction)
# ==============================================================================

#' Load Optional Population Sheet from Config Excel
#'
#' Reads a "Population" sheet from the config workbook if it exists. Each row
#' gives the known universe size for one banner subgroup, enabling the finite
#' population correction (FPC) per column in the v2 report.
#'
#' Expected columns: \code{Group} (the subgroup/column label as shown in the
#' report) and \code{Population} (integer N). An optional \code{Banner} column
#' scopes the row to one banner question (blank = match the \code{Group} label
#' across any banner). Absent sheet / blank values -> no correction.
#'
#' @param config_file Character, path to config Excel file
#' @return Data frame with columns banner (chr, NA when unscoped), group (chr),
#'   population (numeric); or NULL when the sheet is absent or has no valid rows.
#' @keywords internal
load_population_sheet <- function(config_file) {
  tryCatch({
    sheets <- openxlsx::getSheetNames(config_file)
    if (!"Population" %in% sheets) return(NULL)

    required_cols <- c("Group", "Population")
    df <- tryCatch(
      .read_table_sheet(config_file, "Population", required_cols),
      error = function(e) NULL
    )
    if (is.null(df) || nrow(df) == 0) return(NULL)

    if (!all(required_cols %in% names(df))) {
      cat("  [INFO] Population sheet found but missing Group/Population columns - skipped\n")
      return(NULL)
    }

    has_banner <- "Banner" %in% names(df)
    pop_num <- suppressWarnings(as.numeric(df$Population))

    # Keep only rows with a non-blank Group and a usable population (> 1).
    keep <- !is.na(df$Group) & nzchar(trimws(df$Group)) &
            !is.na(pop_num) & pop_num > 1
    df <- df[keep, , drop = FALSE]
    pop_num <- pop_num[keep]
    if (nrow(df) == 0) return(NULL)

    banner <- if (has_banner) {
      b <- trimws(as.character(df$Banner))
      b[is.na(df$Banner) | !nzchar(b)] <- NA_character_
      b
    } else {
      rep(NA_character_, nrow(df))
    }

    frame <- data.frame(
      banner     = banner,
      group      = trimws(as.character(df$Group)),
      population = pop_num,
      stringsAsFactors = FALSE
    )
    cat(sprintf("  [INFO] Loaded %d subgroup population(s) from Population sheet\n",
                nrow(frame)))
    frame
  }, error = function(e) {
    # A malformed Population sheet is a STATISTICS-affecting failure: FPC
    # silently switching off changes every interval and sig letter on a census
    # project. Loud box, not a one-line warning (review 2026-08, I12).
    cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
    cat("│ Context: Config loader - Population sheet\n")
    cat("│ Code: CFG_POPULATION_SHEET_UNREADABLE\n")
    cat(sprintf("│ Message: Population sheet exists but could not be read: %s\n", e$message))
    cat("│ Consequence: FINITE POPULATION CORRECTION IS OFF for this run -\n")
    cat("│   intervals and significance will NOT be census-corrected.\n")
    cat("│ How to fix: repair the Population sheet (Group + Population columns),\n")
    cat("│   or delete the sheet to declare no subgroup universes.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    NULL
  })
}


# ==============================================================================
# ADDED SLIDES SHEET LOADER (V10.8.0, renamed from Qualitative)
# ==============================================================================

#' Load Optional AddedSlides Sheet from Config Excel
#'
#' Reads an "AddedSlides" sheet from the config workbook if it exists.
#' Also checks for legacy "Qualitative" sheet name for backward compatibility.
#' Expected columns: slide_title, content (markdown), display_order (optional).
#' Returns a list of slide objects or NULL if sheet is absent.
#'
#' @param config_file Character, path to config Excel file
#' @return List of slide objects, or NULL
#' @keywords internal
load_qualitative_sheet <- function(config_file) {
  tryCatch({
    sheets <- openxlsx::getSheetNames(config_file)

    # V10.8.0: Check for "AddedSlides" first, fall back to legacy "Qualitative"
    sheet_name <- if ("AddedSlides" %in% sheets) "AddedSlides"
                  else if ("Qualitative" %in% sheets) "Qualitative"
                  else return(NULL)

    # Use .read_table_sheet to auto-detect header row (template format support)
    required_cols <- c("slide_title", "content")
    df <- tryCatch(
      .read_table_sheet(config_file, sheet_name, required_cols),
      error = function(e) NULL
    )
    if (is.null(df) || nrow(df) == 0) return(NULL)

    if (!"slide_title" %in% names(df) || !"content" %in% names(df)) {
      cat(sprintf("  [INFO] %s sheet found but missing slide_title/content columns - skipped\n", sheet_name))
      return(NULL)
    }

    # Filter valid rows
    df <- df[!is.na(df$slide_title) & nzchar(trimws(df$slide_title)), , drop = FALSE]
    if (nrow(df) == 0) return(NULL)

    # Add display_order if not present
    if (!"display_order" %in% names(df)) {
      df$display_order <- seq_len(nrow(df))
    }
    df <- df[order(df$display_order), , drop = FALSE]

    # V10.8.0: Resolve image_path relative to config file directory
    config_dir <- dirname(normalizePath(config_file, mustWork = FALSE))
    has_image_col <- "image_path" %in% names(df)

    slides <- lapply(seq_len(nrow(df)), function(i) {
      slide <- list(
        id = sprintf("qual-slide-%d", i),
        title = trimws(df$slide_title[i]),
        content = trimws(df$content[i] %||% ""),
        order = i,
        image_data = NULL
      )

      # Embed image as base64 if image_path is provided
      if (has_image_col && !is.na(df$image_path[i]) && nzchar(trimws(df$image_path[i]))) {
        img_path <- trimws(df$image_path[i])
        # Resolve relative paths against config directory
        if (!file.exists(img_path)) {
          img_path <- file.path(config_dir, img_path)
        }
        if (file.exists(img_path) && requireNamespace("base64enc", quietly = TRUE)) {
          tryCatch({
            raw <- readBin(img_path, "raw", file.info(img_path)$size)
            ext <- tolower(tools::file_ext(img_path))
            mime <- switch(ext,
              png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg",
              gif = "image/gif", webp = "image/webp", svg = "image/svg+xml",
              "image/png"  # fallback
            )
            slide$image_data <- sprintf("data:%s;base64,%s",
              mime, base64enc::base64encode(raw))
            cat(sprintf("  [INFO] Embedded image for slide '%s' (%s, %dKB)\n",
              slide$title, basename(img_path), round(length(raw) / 1024)))
          }, error = function(e) {
            cat(sprintf("  [WARNING] Could not embed image '%s': %s\n", img_path, e$message))
          })
        } else {
          cat(sprintf("  [WARNING] Image file not found for slide '%s': %s\n",
            slide$title, img_path))
        }
      }

      slide
    })

    cat(sprintf("  [INFO] Loaded %d added slides from %s sheet\n", length(slides), sheet_name))
    slides
  }, error = function(e) {
    cat(sprintf("  [WARNING] Could not read AddedSlides/Qualitative sheet: %s\n", e$message))
    NULL
  })
}


# ==============================================================================
# FULL CONFIGURATION LOADER
# ==============================================================================

#' Load Complete Crosstabs Configuration
#' Resolve the tabs-tracker Question_Mapping path (explicit or auto-detected)
#'
#' An explicit `question_mapping` is tried as-is, then relative to the project
#' root and the config directory. When blank, a `*Question_Mapping*.xlsx` is
#' auto-detected in `waves_source`, the project root, or the config directory —
#' so pointing `waves_source` at a tracker's Crosswave folder is enough.
#'
#' @param raw_path The configured question_mapping value (may be blank)
#' @param waves_source The configured waves_source folder (may be blank)
#' @param project_root Project root directory
#' @param config_file The config file path (its directory is searched too)
#' @return An absolute path to a readable mapping workbook, or "" if none
#' @keywords internal
resolve_question_mapping <- function(raw_path, waves_source, project_root, config_file) {
  raw_path <- as.character(raw_path %||% "")
  if (nzchar(raw_path)) {
    rp <- normalize_path_separators(raw_path)
    for (cand in c(rp, file.path(project_root, rp), file.path(dirname(config_file), rp))) {
      if (file.exists(cand)) return(normalizePath(cand))
    }
    cat(sprintf("  [WARNING] question_mapping not found (tracking falls back to title match): %s\n",
                raw_path))
    return("")
  }
  dirs <- c(as.character(waves_source %||% ""), project_root, dirname(config_file))
  for (d in dirs) {
    if (!nzchar(d) || !dir.exists(d)) next
    hit <- list.files(d, pattern = "Question_Mapping.*\\.xlsx$",
                      full.names = TRUE, ignore.case = TRUE)
    if (length(hit) > 0) {
      cat(sprintf("  Question mapping auto-detected: %s\n", basename(hit[1])))
      return(normalizePath(hit[1]))
    }
  }
  ""
}


#' Spreadsheet column letters to a column number ("A" -> 1, "AB" -> 28)
#'
#' @param letters_ref Column letters from a cell reference
#' @return Integer column number
#' @keywords internal
excel_col_number <- function(letters_ref) {
  chars <- strsplit(toupper(letters_ref), "")[[1]]
  Reduce(function(acc, ch) acc * 26L + match(ch, LETTERS), chars, 0L)
}


#' Warn about setting rows whose Value cell was swallowed by a merged range
#'
#' The Settings sheet formats its SECTION HEADERS ("WEIGHTING", "DISPLAY
#' OPTIONS") as a row merged across A:E. When a real setting row picks up that
#' formatting by accident there is no longer a Value cell to read: readxl returns
#' NA, `load_config_sheet()` drops the setting entirely, and the run falls back to
#' the default without a word. That is how CCPB W2026 lost `question_mapping` and
#' shipped a Tracking tab with 14 prior waves loaded and nothing paired to them.
#'
#' Section headers are merged exactly the same way, so a merge is only reported
#' when its column-A text is a KNOWN setting name — headers never are.
#'
#' Diagnostic only: it reads the file again and never alters the config or throws.
#'
#' @param config_file Path to the config workbook
#' @param sheet_name Sheet to inspect (default "Settings")
#' @param known Setting names to match against (default TABS_KNOWN_SETTINGS)
#' @return Character vector of affected setting names, invisibly
#' @keywords internal
warn_merged_setting_rows <- function(config_file, sheet_name = "Settings",
                                     known = TABS_KNOWN_SETTINGS) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) return(invisible(character(0)))
  hits <- tryCatch({
    wb <- openxlsx::loadWorkbook(config_file)
    idx <- which(names(wb) == sheet_name)
    if (!length(idx)) return(invisible(character(0)))
    merges <- wb$worksheets[[idx]]$mergeCells
    refs <- regmatches(merges, regexpr("[A-Z]+[0-9]+:[A-Z]+[0-9]+", merges))
    refs <- refs[!is.na(refs) & nzchar(refs)]
    if (!length(refs)) return(invisible(character(0)))

    raw <- openxlsx::read.xlsx(config_file, sheet = sheet_name, colNames = FALSE,
                               skipEmptyRows = FALSE)
    labels <- as.character(raw[[1]])
    found <- list()
    for (ref in refs) {
      parts <- regmatches(ref, regexec("^([A-Z]+)([0-9]+):([A-Z]+)([0-9]+)$", ref))[[1]]
      if (length(parts) != 5) next
      # Only a merge that starts in the Setting column AND swallows the Value
      # column hides a value; A:A or B:E leave column B readable.
      if (excel_col_number(parts[2]) != 1L || excel_col_number(parts[4]) < 2L) next
      row <- as.integer(parts[3])
      if (is.na(row) || row > length(labels)) next
      name <- tolower(trimws(labels[row]))
      if (is.na(name) || !nzchar(name) || !(name %in% known)) next
      found[[length(found) + 1]] <- list(name = name, row = row, ref = ref)
    }
    # Sheet order, not the arbitrary order the merges are stored in — the
    # operator is going to walk down the sheet fixing them.
    found[order(vapply(found, function(h) h$row, integer(1)))]
  }, error = function(e) list())

  if (!length(hits)) return(invisible(character(0)))
  cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
  cat(sprintf("│ Context: config '%s' sheet\n", sheet_name))
  cat("│ These setting rows are merged across columns, so they have\n")
  cat("│ no Value cell and are being IGNORED — whatever you meant to\n")
  cat("│ set there is not reaching the run:\n")
  for (h in hits) {
    cat(sprintf("│   %-28s (row %d, merged %s)\n", h$name, h$row, h$ref))
  }
  cat("│ How to fix: unmerge each row in Excel, then type the value\n")
  cat("│ into column B the way the other setting rows do.\n")
  cat("└───────────────────────────────────────────────────────┘\n\n")
  invisible(vapply(hits, function(h) h$name, character(1)))
}


#' Warn about setting names that differ from the canonical one only by case
#'
#' `get_config_value()` looks settings up with an exact `[[name]]`, so a sheet
#' that says `Research_House` never answers a request for `research_house` — the
#' run silently takes the default. The typo check above cannot see this: it
#' lower-cases before comparing, so a case variant looks perfectly valid.
#'
#' When the canonical spelling is ALSO present the variant is merely redundant,
#' and that is said explicitly — renaming it would produce two identically named
#' rows, which `load_config_sheet()` refuses outright.
#'
#' @param config The loaded settings list (names are the sheet's labels)
#' @param known Canonical setting names (default TABS_KNOWN_SETTINGS)
#' @return Character vector of affected sheet labels, invisibly
#' @keywords internal
warn_case_mismatched_settings <- function(config, known = TABS_KNOWN_SETTINGS) {
  labels <- names(config)
  if (!length(labels)) return(invisible(character(0)))
  canonical <- tolower(trimws(labels))
  off <- which(!(labels %in% known) & canonical %in% known)
  if (!length(off)) return(invisible(character(0)))

  cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
  cat("│ Context: config 'Settings' sheet — case mismatch\n")
  cat("│ These settings are spelled differently from the name the\n")
  cat("│ loader looks up, so their values are being IGNORED and the\n")
  cat("│ defaults are used instead:\n")
  for (i in off) {
    twin <- canonical[i] %in% labels
    cat(sprintf("│   %-22s should be %-22s%s\n", labels[i], canonical[i],
                if (twin) " [duplicate]" else ""))
  }
  cat("│ How to fix: rename the Setting cell to the lower-case name.\n")
  if (any(canonical[off] %in% labels)) {
    cat("│ Rows marked [duplicate] already have a correctly named twin —\n")
    cat("│ DELETE those rows rather than renaming them, or the sheet will\n")
    cat("│ hold the same setting twice and the run will refuse.\n")
  }
  cat("└───────────────────────────────────────────────────────┘\n\n")
  invisible(labels[off])
}


# Settings that used to do something and no longer do. A retired name is NOT a
# typo, so it must not be reported as one — the operator wrote it deliberately
# and is entitled to know that the run ignored it, and why. Each entry is the
# sentence the loader prints (see announce_retired_settings).
#
# Retirement runs for one release: the name is answered here by name, then the
# entry is deleted and the name falls through to the ordinary "unrecognised
# setting" warning. Retired 2026-08 (remove after the next release):
TABS_RETIRED_SETTINGS <- c(
  html_report = paste(
    "the classic HTML report is retired — the interactive report",
    "(html_report_v2) is the deliverable. No HTML file is written for this",
    "setting. Delete the row from the Settings sheet."
  )
)


#' Announce any retired settings the config still carries
#'
#' Prints a boxed console notice naming each retired setting found, so a run
#' that used to produce an extra deliverable cannot quietly stop producing it.
#' Console output is mandatory here: tabs runs inside the Shiny app, where a
#' silent behaviour change is invisible to the operator.
#'
#' @param config Named list of raw Settings values (as loaded from the sheet)
#' @param retired Named character vector of retirement messages
#'
#' @return Invisibly, the retired setting names that were present
#' @export
announce_retired_settings <- function(config, retired = TABS_RETIRED_SETTINGS) {
  if (length(config) == 0 || length(retired) == 0) return(invisible(character(0)))
  present <- intersect(tolower(trimws(names(config))), names(retired))
  if (length(present) == 0) return(invisible(character(0)))

  cat("\n┌─── SETTING RETIRED ───────────────────────────────────┐\n")
  for (nm in present) {
    cat(sprintf("│ %s: %s\n", nm, retired[[nm]]))
  }
  cat("│ The run continues; this setting had no effect.\n")
  cat("└───────────────────────────────────────────────────────┘\n\n")
  invisible(present)
}


# Every setting name the tabs config recognises. Used to flag typos, and to
# tell a mis-formatted setting row apart from a section header (see
# warn_merged_setting_rows).
TABS_KNOWN_SETTINGS <- c(
  # Weighting
  "apply_weighting", "weight_variable", "show_unweighted_n", "show_effective_n",
  "show_weighted_base", "weight_label",
  # Display — frequencies and percentages
  "decimal_separator", "show_frequency", "show_percent_column", "show_percent_row",
  "boxcategory_frequency", "boxcategory_percent_column", "boxcategory_percent_row",
  "decimal_places", "decimal_places_percent", "decimal_places_ratings",
  "decimal_places_index", "decimal_places_numeric",
  # Statistics
  "show_standard_deviation", "show_net_positive", "show_numeric_median",
  "show_numeric_mode", "show_numeric_outliers", "exclude_outliers_from_stats", "outlier_method",
  "test_net_differences", "zero_division_as_blank",
  # Significance testing
  "enable_significance_testing", "alpha",
  "significance_min_base", "bonferroni_correction", "enable_chi_square",
  "alpha_secondary", "alpha_default",
  # v2 tab visibility + Patterns levers + fieldwork caveat (I7: these were read
  # by build_config_object but missing here, so a fresh template config was
  # warned at for settings that work, and the merged-row/case diagnostics were
  # blind to them)
  "show_dashboard", "show_patterns", "show_differences", "show_tracking",
  "show_qualitative", "patterns_headline", "patterns_exclude_banners",
  "patterns_banner", "sampling_note",
  # Checkpointing
  "enable_checkpointing",
  # Qualitative confidentiality & disclosure control
  "qual_workbook", "qual_confidentiality_mode", "qual_demographic_cuts", "qual_noteworthy_default",
  "qual_verbatim_scope", "qual_join_id_column", "min_reporting_base", "qual_tag_dimensions",
  # Sample composition & index summary
  "create_sample_composition", "create_index_summary",
  "index_summary_show_sections", "index_summary_show_base_sizes",
  "index_summary_show_composites", "index_summary_decimal_places",
  # Stats pack
  "generate_stats_pack",
  # HTML report (html_report itself is retired — see TABS_RETIRED_SETTINGS)
  "html_report_v2", "html_report_v2_tracking",
  "html_report_v2_microdata",
  "waves_source", "question_mapping", "wave_order", "sampling_method",
  "population_size", "wave",
  # Reader report (narrative summary, rides on html_report_v2)
  "generate_reader_report", "reader_ai_prose",
  "brand_colour", "accent_colour", "project_title", "project_name",
  "company_name", "client_name", "research_house",
  "researcher_logo_path", "client_logo_path", "logo_path",
  "chart_bar_colour", "chart_palette_preset", "heatmap_colour",
  "chart_series_colour_1", "chart_series_colour_2", "chart_series_colour_3",
  "chart_series_colour_4", "chart_series_colour_5", "chart_series_colour_6",
  "chart_series_colour_7", "chart_series_colour_8",
  "embed_frequencies",
  "include_summary", "fieldwork_dates", "show_charts",
  # Dashboard
  "dashboard_metrics", "dashboard_scale_mean", "dashboard_scale_index",
  "dashboard_green_net", "dashboard_amber_net",
  "dashboard_green_mean", "dashboard_amber_mean",
  "dashboard_green_index", "dashboard_amber_index",
  "dashboard_green_custom", "dashboard_amber_custom", "dashboard_sort_gauges",
  "priority_metric",
  # Descriptors
  "index_descriptor", "mean_descriptor", "nps_descriptor",
  # Analyst / report metadata
  "analyst_name", "analyst_email", "analyst_phone", "verbatim_filename", "closing_notes",
  # Ranking
  "ranking_completeness_threshold_pct", "ranking_gap_threshold_pct", "ranking_tie_threshold_pct",
  "ranking_min_base",
  # AI Insights
  "enable_ai_insights", "ai_model",
  # File path settings (loaded separately but may appear in Settings sheet)
  "data_file", "structure_file", "output_file", "output_filename",
  "output_format", "output_folder", "output_subfolder"
)


#'
#' Main entry point for loading all configuration.
#' Loads settings, builds config object, and returns all needed paths.
#'
#' @param config_file Character, path to config file
#' @return List with all configuration components
#' @export
load_crosstabs_config <- function(config_file) {
  # Get project root

  project_root <- get_project_root(config_file)
  log_message(sprintf("Project root: %s", project_root), "INFO")

  # Load settings
  settings <- load_crosstabs_settings(config_file, project_root)

  # Build config object
  config_obj <- build_config_object(settings$config)

  # Validate dual significance level config (if alpha_secondary is set)
  validate_dual_significance_config(config_obj)

  # Validate the statistical settings (I11/I5): junk in alpha or the bases used
  # to crash deep inside a z-test re-branded as a per-question DATA_ fault; an
  # unrecognised sampling_method silently flipped the report's whole confidence
  # vocabulary to "Not specified".
  validate_config_settings(config_obj, settings$config)

  # A setting that used to work and no longer does gets named, not ignored —
  # live configs (CCPB among them) still carry html_report = True.
  announce_retired_settings(settings$config)

  # Check for unrecognised settings — typos are silently ignored otherwise.
  # Retired names are deliberate, not typos, so they are excluded here; they
  # rejoin this list when their retirement entry is removed.
  .KNOWN_SETTINGS <- TABS_KNOWN_SETTINGS
  user_settings <- names(settings$config)
  unknown_settings <- setdiff(tolower(trimws(user_settings)),
                              c(.KNOWN_SETTINGS, names(TABS_RETIRED_SETTINGS)))
  if (length(unknown_settings) > 0) {
    cat("\n  WARNING: Unrecognised settings in config (may be typos):\n")
    for (us in unknown_settings) {
      cat("    -", us, "\n")
    }
    cat("  These settings will be ignored. Check spelling against the template.\n\n")
  }

  # A setting that never arrives is invisible to the check above — it isn't an
  # unknown name, it simply isn't in the list. The commonest cause is a row
  # merged into section-header shape, which leaves no Value cell to read.
  warn_merged_setting_rows(config_file)
  # And one that arrives under the wrong spelling is invisible too: the check
  # above lower-cases before comparing, but the lookup does not.
  warn_case_mismatched_settings(settings$config)

  # Load optional Comments sheet (V10.6.0)
  config_obj$comments <- load_comments_sheet(config_file)

  # Extract dashboard text from Comments sheet (V10.8.0)
  if (!is.null(config_obj$comments)) {
    config_obj$background_text <- attr(config_obj$comments, "background_text")
    config_obj$executive_summary <- attr(config_obj$comments, "executive_summary")
  }

  # Load optional AddedSlides sheet (V10.8.0, renamed from Qualitative)
  config_obj$qualitative_slides <- load_qualitative_sheet(config_file)

  # Load optional Population sheet (finite population correction) — per-subgroup
  # universe sizes; the study total lives in the population_size setting.
  config_obj$population_frame <- load_population_sheet(config_file)

  # Resolve logo paths against project root so HTML report gets absolute paths
  # Helper: resolve a single logo path, trying multiple candidate locations
  resolve_logo_path <- function(raw_path, label) {
    if (is.null(raw_path) || !nzchar(raw_path)) return(NULL)
    if (file.exists(raw_path)) {
      resolved <- normalizePath(raw_path)
      cat(sprintf("  %s: %s\n", label, basename(resolved)))
      return(resolved)
    }
    candidates <- c(
      file.path(project_root, raw_path),
      file.path(dirname(config_file), raw_path),
      file.path(project_root, basename(raw_path)),
      file.path(dirname(config_file), basename(raw_path))
    )
    for (cand in candidates) {
      if (file.exists(cand)) {
        resolved <- normalizePath(cand)
        cat(sprintf("  %s: resolved to %s\n", label, resolved))
        return(resolved)
      }
    }
    cat(sprintf("  [WARNING] %s not found: %s\n", label, raw_path))
    cat(sprintf("  Searched in: %s, %s\n", project_root, dirname(config_file)))
    return(raw_path)
  }

  config_obj$researcher_logo_path <- resolve_logo_path(
    config_obj$researcher_logo_path, "Researcher logo")
  config_obj$client_logo_path <- resolve_logo_path(
    config_obj$client_logo_path, "Client logo")
  # Legacy single logo_path: used as researcher logo fallback
  config_obj$logo_path <- resolve_logo_path(
    config_obj$logo_path, "Logo")

  # Resolve the tabs-tracker question mapping: an explicit path (absolute, or
  # relative to the project root / config dir), else auto-detected — a
  # *Question_Mapping*.xlsx in waves_source, the project root, or the config dir.
  config_obj$question_mapping <- resolve_question_mapping(
    config_obj$question_mapping, config_obj$waves_source, project_root, config_file)

  # Build output path
  output_path <- get_output_path(
    project_root,
    settings$output_subfolder,
    settings$output_filename
  )

  list(
    project_root = project_root,
    config_file = config_file,
    config_obj = config_obj,
    structure_file_path = settings$structure_file_path,
    output_subfolder = settings$output_subfolder,
    output_filename = settings$output_filename,
    output_path = output_path
  )
}
