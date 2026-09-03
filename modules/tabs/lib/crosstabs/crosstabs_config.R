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

    # Dual significance level toggle (optional, V10.10)
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
    # Defaults ON, unlike its siblings: the SD row has always been published on
    # numeric questions, so a report that says nothing about it must not change.
    show_numeric_sd = safe_logical(get_config_value(config, "show_numeric_sd", TRUE), default = TRUE),
    show_numeric_outliers = safe_logical(get_config_value(config, "show_numeric_outliers", TRUE), default = TRUE),
    exclude_outliers_from_stats = safe_logical(get_config_value(config, "exclude_outliers_from_stats", FALSE), default = FALSE),
    outlier_method = get_config_value(config, "outlier_method", "IQR"),

    # Stats pack (contractual deliverable, defaults to Y). Canonicalised to
    # "Y"/"N" because the consumer tests `toupper(...) == "Y"` exactly: a
    # perfectly reasonable `TRUE` in the cell read as "not Y" and switched the
    # contractual deliverable off in silence (production review 2026-08, I3).
    # An unreadable token is left as typed so validate_config_settings can
    # quote it and refuse.
    generate_stats_pack = normalise_flag_setting(
      get_config_value(config, "generate_stats_pack", "Y"), default = "Y"),

    # (html_report, the classic HTML report, is RETIRED. It is not read here
    # any more; a config that still carries the row is answered by name in
    # TABS_RETIRED_SETTINGS rather than silently ignored.)

    # V11 data-centric report (data-layer JSON for the v2 renderer).
    # Additive: when TRUE, a *_data.json island is written alongside the
    # Excel workbook. The workbook is untouched when FALSE.
    html_report_v2 = safe_logical(get_config_value(config, "html_report_v2", FALSE), default = FALSE),
    # Whether the Settings sheet EXPLICITLY set html_report_v2 (I16): an
    # explicit FALSE must beat the GUI's default-ON. A confidentiality-driven
    # opt-out was silently overridden before. Internal, not a Settings name.
    html_report_v2_explicit = !is.null(get_config_value(config, "html_report_v2", NULL)),
    # V13 confidentiality dial (ON by default = today's behaviour). FALSE omits
    # the anonymised per-respondent DATA_MICRO island from the v2 report. The
    # aggregates-only ship for insider populations (small staff surveys) where
    # coded records + banner cuts could re-identify individuals. Only an
    # explicit FALSE disables: a blank or stringified-"NA" cell keeps the island
    # (default TRUE passed to safe_logical too, so it cannot flip it). A cell
    # that is neither blank nor readable as yes/no refuses in
    # validate_config_settings rather than defaulting the island back ON (I3).
    html_report_v2_microdata = safe_logical(
      get_config_value(config, "html_report_v2_microdata", TRUE), default = TRUE),
    # V11 tabs-integrated tracker (OFF by default). When TRUE AND a waves_source
    # resolves, the v2 report gains a Tracking tab built from anonymised per-wave
    # microdata. Independent of the standalone tracker module, which is untouched.
    html_report_v2_tracking = safe_logical(get_config_value(config, "html_report_v2_tracking", FALSE), default = FALSE),
    # Exec-summary cover (OFF by default). When TRUE, a SAVED copy that carries
    # story content opens on a cover page instead of the dashboard. It changes
    # what a client sees on opening the file, so the study opts in per project
    # rather than inheriting it: a config that never mentions the setting emits
    # no cover flag at all and lands exactly where it always did.
    html_report_v2_cover = safe_logical(get_config_value(config, "html_report_v2_cover", FALSE), default = FALSE),
    # How many story pins the cover lists as leading findings. Blank/absent ->
    # NULL, and the renderer's own default of 5 stands (the island stays
    # byte-identical to one built before this setting existed). "ALL" parses to
    # 0, the no-limit sentinel: every pin is listed, however many there are.
    # A cover that quietly stopped at five was the complaint this answers.
    html_report_v2_cover_findings = {
      raw <- get_config_value(config, "html_report_v2_cover_findings", NULL)
      tok <- toupper(trimws(as.character(raw)[1]))
      if (is.null(raw) || length(tok) != 1L || is.na(tok) || !nzchar(tok)) {
        NULL
      } else if (tok == "ALL") {
        0
      } else {
        n <- suppressWarnings(as.numeric(tok))
        if (is.na(n) || n < 1) NULL else floor(n)
      }
    },
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
    # Sample design. Drives honest confidence vocabulary in the v2 report
    # (probability designs speak CI/MOE; non-probability designs speak the
    # softened SI/PE). Cautious default: Not_Specified -> SI/PE. The value is
    # normalised to its canonical token here ("stratified" -> "Stratified");
    # an unrecognised token refuses in validate_config_settings (I5): it
    # would otherwise silently flip the whole report's confidence vocabulary.
    sampling_method = normalise_sampling_method(
      get_config_value(config, "sampling_method", "Not_Specified")),
    # Total universe size for a census / full-invite design. Drives the finite
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
    # Each dial is normalised to its canonical lowercase token, then refused in
    # validate_config_settings if it is not one of them (I4). Every consumer
    # compares with identical(), so "Block" used to mean ALLOW and "Noteworthy"
    # used to mean ALL. A capital letter silently opened a confidentiality gate.
    qual_workbook = get_config_value(config, "qual_workbook", ""),
    qual_confidentiality_mode = normalise_enum_setting(
      get_config_value(config, "qual_confidentiality_mode", "hidden"),
      .TABS_QUAL_ENUMS$qual_confidentiality_mode, "hidden"),
    qual_demographic_cuts = normalise_enum_setting(
      get_config_value(config, "qual_demographic_cuts", "allow"),
      .TABS_QUAL_ENUMS$qual_demographic_cuts, "allow"),
    qual_noteworthy_default = normalise_enum_setting(
      get_config_value(config, "qual_noteworthy_default", "all"),
      .TABS_QUAL_ENUMS$qual_noteworthy_default, "all"),
    # Verbatim scope: which comments ship readable text. "all" = every comment except
    # hide-marked ones; "noteworthy" = only tier >= 1 (noteworthy/must-read/priority).
    # Withheld comments still count in the distribution, only their text is withheld.
    qual_verbatim_scope = normalise_enum_setting(
      get_config_value(config, "qual_verbatim_scope", "all"),
      .TABS_QUAL_ENUMS$qual_verbatim_scope, "all"),
    qual_join_id_column = get_config_value(config, "qual_join_id_column", ""),

    # Path to a conjoint contribution file ({output}_cj_island.json, written by
    # the conjoint module). Names it and the report gains a Conjoint tab;
    # leave it blank and nothing about the report changes. The two modules meet
    # through this one file, the way the tracker meets its prior waves.
    conjoint_island = get_config_value(config, "conjoint_island", ""),
    # Same arrangement for a MaxDiff study ({output}_md_island.json, written by
    # the maxdiff module): named, the report gains a MaxDiff tab.
    maxdiff_island = get_config_value(config, "maxdiff_island", ""),
    # Host-survey columns exposed as comment tags (Feature 2): "Col:Label, Col:Label".
    # Must be populated here. Config_obj is an explicit whitelist, not the raw settings.
    qual_tag_dimensions = get_config_value(config, "qual_tag_dimensions", ""),
    # Whitelisted alongside their siblings above (qual_*, min_reporting_base
    # already loaded below): heatmap_colour and research_house are both
    # genuine, template-documented settings that were readable downstream
    # (02_table_builder.R, stats_diagnostics.R) but never populated here,
    # so they were silent no-ops even when set.
    heatmap_colour = get_config_value(config, "heatmap_colour", ""),
    research_house = get_config_value(config, "research_house", "The Research LampPost"),

    # Disclosure control (V13). The minimum audience base below which the report
    # withholds identifying detail. The demographic tags on comments now, small
    # crosstab cells next, so a composite filter (e.g. 1st-year promoters in Cape
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
    # Save copy (V15). ON by default, which is every report built before this
    # setting existed. FALSE removes the header button, for a copy that is
    # published rather than worked in: a public demo, or a client copy that
    # must stay the one version of record. Nothing else about the report moves,
    # and the story, insight and note editors are untouched.
    show_save_copy = safe_logical(get_config_value(config, "show_save_copy", TRUE), default = TRUE),

    # Patterns-tab levers (optional). patterns_headline pins the apex KPI tiles
    # to these question codes, in order (e.g. "Q78, Q79"): otherwise the tab
    # auto-detects satisfaction/overall-titled questions, which on a study with
    # many section ratings picks the wrong ones. patterns_exclude_banners keeps
    # operational cuts (e.g. "Interviewer") out of the Patterns scan entirely,
    # a fieldwork-QC banner must never become the client-facing lead portrait.
    # Comma/semicolon-separated; parsed in the data layer.
    patterns_headline = get_config_value(config, "patterns_headline", NULL),
    patterns_exclude_banners = get_config_value(config, "patterns_exclude_banners", NULL),
    # The POSITIVE banner selection for the Group overview tab: name the banner
    # group(s) to portray (e.g. "Centre"; comma-separated for a second banner).
    # Unset -> every banner group, as before.
    patterns_banner = get_config_value(config, "patterns_banner", NULL),
    # Category names (beyond the built-in demographics/corpographics detection)
    # whose questions the Differences tab and the Patterns KeyShare scan treat
    # as cuts, not outcomes, e.g. imputed spend families a study does not want
    # leading its findings. Comma/semicolon-separated; parsed in the data layer.
    # The JS consumer and its test predate this line; the setting was consumed
    # but never written until 2026-08 (DIFFERENCES_TAB_SCOPE.md, item 0).
    insight_exclude_categories = get_config_value(config, "insight_exclude_categories", NULL),

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
    fieldwork_dates = get_config_value(config, "fieldwork_dates", NULL),

    # Dashboard gauge scales and colour breaks. Only the mean and index pairs are
    # read (data_layer_writer.R build_dl_dashboard); the net and custom pairs drove
    # the retired classic report and are retired with it, as are embed_frequencies,
    # include_summary, show_charts, dashboard_metrics, dashboard_sort_gauges, the
    # three row descriptors and priority_metric (production review 2026-08, I11).
    dashboard_scale_mean    = safe_numeric(get_config_value(config, "dashboard_scale_mean", 10), 10),
    dashboard_scale_index   = safe_numeric(get_config_value(config, "dashboard_scale_index", 10), 10),
    dashboard_green_mean    = safe_numeric(get_config_value(config, "dashboard_green_mean", 7), 7),
    dashboard_amber_mean    = safe_numeric(get_config_value(config, "dashboard_amber_mean", 5), 5),
    dashboard_green_index   = safe_numeric(get_config_value(config, "dashboard_green_index", 7), 7),
    dashboard_amber_index   = safe_numeric(get_config_value(config, "dashboard_amber_index", 5), 5),

    # V10.7.0 Closing section & qualitative content
    analyst_name = get_config_value(config, "analyst_name", NULL),
    analyst_email = get_config_value(config, "analyst_email", NULL),
    analyst_phone = get_config_value(config, "analyst_phone", NULL),
    verbatim_filename = get_config_value(config, "verbatim_filename", NULL),
    closing_notes = get_config_value(config, "closing_notes", NULL),

    # V10.9.0 AI Insights (optional, default FALSE)
    enable_ai_insights = safe_logical(get_config_value(config, "enable_ai_insights", FALSE), default = FALSE),

    # AI model selection. Friendly label ("Sonnet 4.6"/"Opus 4.8") or an exact
    # model ID. Resolved in the AI layer; blank uses the sidecar/default model.
    ai_model = get_config_value(config, "ai_model", NULL),

    # V15 Reader report. A separate narrative-summary file written beside the
    # crosstab that deep-links back into it. Opt-in; the GUI checkbox sets
    # TURAS_GENERATE_READER_REPORT, which overrides this. The report is
    # DETERMINISTIC by default (built on-device from the data layer, no AI,
    # nothing leaves the machine). reader_ai_prose sends AGGREGATES ONLY to the
    # model to draft the prose, never microdata or verbatims, and stays off
    # unless the operator explicitly turns it on.
    generate_reader_report = safe_logical(get_config_value(config, "generate_reader_report", FALSE), default = FALSE),
    reader_ai_prose = safe_logical(get_config_value(config, "reader_ai_prose", FALSE), default = FALSE),

    # Index summary (I9): these Settings were whitelisted but never carried
    # into config_obj, so their downstream get_config_value() reads always saw
    # the default. Setting create_index_summary = N did nothing, silently.
    # NULL-when-absent defers to each consumer's own default (create_index_
    # summary's default is composites-driven in create_index_summary_safe).
    # Y/N flag (create_index_summary_safe reads the flag vocabulary), so it is
    # canonicalised like generate_stats_pack; NULL when absent so the
    # composites-driven default still holds.
    create_index_summary = normalise_flag_setting(
      get_config_value(config, "create_index_summary", NULL), default = NULL),
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

    # Ranking thresholds (I9): same gap. Whitelisted, documented, never carried.
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

#' Is a raw Settings cell blank (= "use the documented default")?
#'
#' A cleared cell is dropped by the loader entirely, but a cell can still arrive
#' as "", whitespace, or the literal text "NA" (readxl keeps "NA" as a string).
#' All of those mean "not set" and must never be read as junk.
#'
#' @param raw The raw Settings value
#' @return TRUE when the cell carries no value
#' @keywords internal
is_blank_setting <- function(raw) {
  if (is.null(raw) || length(raw) == 0) return(TRUE)
  r1 <- raw[[1]]
  if (is.null(r1) || (length(r1) == 1 && is.na(r1))) return(TRUE)
  v <- trimws(as.character(r1))
  !nzchar(v) || identical(toupper(v), "NA")
}

#' Normalise a Y/N Settings cell to canonical "Y" / "N"
#'
#' Case- and whitespace-insensitive, on the module's single yes/no vocabulary
#' (\code{.TABS_FLAG_TRUE_TOKENS} / \code{.TABS_FLAG_FALSE_TOKENS} in
#' type_utils.R). A blank cell takes \code{default}; an unreadable token is
#' returned trimmed as typed so validate_config_settings() can quote and refuse
#' it, exactly as normalise_sampling_method() does.
#'
#' @param x Raw Settings-sheet value
#' @param default Value for a blank/absent cell
#' @return "Y", "N", \code{default}, or the trimmed original
#' @keywords internal
normalise_flag_setting <- function(x, default = NULL) {
  if (is_blank_setting(x)) return(default)
  v <- trimws(as.character(x[[1]]))
  u <- toupper(v)
  if (u %in% .TABS_FLAG_TRUE_TOKENS) return("Y")
  if (u %in% .TABS_FLAG_FALSE_TOKENS) return("N")
  v
}

#' Normalise an enum Settings cell to its canonical token
#'
#' Case-insensitive, and spaces/hyphens resolve to underscores ("must read" ->
#' "must_read"), like normalise_sampling_method(). An unrecognised token is
#' returned trimmed as typed; validate_config_settings() refuses on it rather
#' than letting it fall through to the permissive default.
#'
#' @param x Raw Settings-sheet value
#' @param tokens Character vector of canonical tokens
#' @param default Value for a blank/absent cell
#' @return A canonical token, \code{default}, or the trimmed original
#' @keywords internal
normalise_enum_setting <- function(x, tokens, default) {
  if (is_blank_setting(x)) return(default)
  v <- trimws(as.character(x[[1]]))
  hit <- tokens[tolower(tokens) == tolower(gsub("[ -]", "_", v))]
  if (length(hit) == 1) hit else v
}

#' Validate the statistical settings after build_config_object
#'
#' A junk cell in a statistical setting must refuse AT LOAD, naming the cell,
#' not crash mid-run inside a z-test where the orchestrator re-brands it as a
#' per-question DATA_ fault (production review 2026-08, I11). An unrecognised
#' sampling_method must refuse rather than silently soften the report's whole
#' confidence vocabulary (I5).
#'
#' The same argument covers every OTHER cell whose junk value silently became a
#' default (I2/I3/I4): a Y/N toggle warned one scrollback line and ran the
#' opposite way (`apply_weighting`, every published number wrong-by-weighting),
#' an unparseable number became the default it was meant to override
#' (`population_size` switching the FPC off on a census project,
#' `alpha_secondary` switching dual significance off), and a mis-cased
#' confidentiality dial opened the gate it was set to close
#' (`qual_demographic_cuts = "Block"` meant ALLOW).
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
  bad <- function(key, why,
                  hint = "Numbers must use '.' as the decimal separator (0.05, not 0,05)") {
    tabs_refuse(
      code = "CFG_INVALID_SETTING",
      title = "Invalid Configuration Setting",
      problem = sprintf("Setting '%s' %s%s.", key, why, quote_raw(key)),
      why_it_matters = "Statistical settings drive every test in the run; a junk value would fail mid-run or silently change what the report claims.",
      how_to_fix = c(
        sprintf("Fix the '%s' row on the config Settings sheet", key),
        hint,
        "Leave the cell blank to accept the documented default"
      )
    )
  }
  # A Y/N cell's fix is a different sentence from a number's.
  flag_hint <- sprintf("Accepted values (any case): %s",
                       paste(c(.TABS_FLAG_TRUE_TOKENS, .TABS_FLAG_FALSE_TOKENS),
                             collapse = ", "))

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
  # Every numeric setting that takes safe_numeric() with a fallback (M9, I2, I3).
  # A junk cell silently BECAME the default: a 0-5 project that typed "five" got
  # a scale maximum of 10 and every gauge read at half strength; a
  # population_size of "5,000" switched the finite population correction off on
  # a census project; an alpha_secondary of "ten percent" switched dual
  # significance off. The parsed value cannot tell junk from a real default, so
  # the test reads the raw cell; blank or absent still means "use the default".
  for (key in .TABS_NUMERIC_SETTINGS) {
    raw <- if (!is.null(raw_settings)) raw_settings[[key]] else NULL
    if (is_blank_setting(raw)) next
    if (is.na(suppressWarnings(as.numeric(raw[[1]])))) {
      bad(key, "must be a number")
    }
  }
  # Y/N toggles (I3). safe_logical() prints one scrollback line and returns the
  # default, so `apply_weighting = "Yes please"` ran the whole study unweighted
  #, every published number wrong, with all the weight preflight checks
  # skipped because they gate on the parsed FALSE.
  for (key in .TABS_LOGICAL_SETTINGS) {
    raw <- if (!is.null(raw_settings)) raw_settings[[key]] else NULL
    if (is_blank_setting(raw)) next
    if (is.logical(raw[[1]])) next
    tok <- toupper(trimws(as.character(raw[[1]])))
    if (!(tok %in% c(.TABS_FLAG_TRUE_TOKENS, .TABS_FLAG_FALSE_TOKENS))) {
      bad(key, "must be yes or no", hint = flag_hint)
    }
  }
  # The Y/N settings consumers read as STRINGS rather than through safe_logical:
  # generate_stats_pack gates a contractual deliverable on an exact `== "Y"`, so
  # a cell reading TRUE switched the stats pack off in silence.
  for (key in .TABS_FLAG_SETTINGS) {
    v <- config_obj[[key]]
    if (is.null(v) || !nzchar(as.character(v)[1])) next
    if (!(as.character(v)[1] %in% c("Y", "N"))) {
      bad(key, "must be yes or no", hint = flag_hint)
    }
  }
  # population_size (I2). Parsed, it is NULL both when absent and when junk, so
  # the range test has to read the raw cell too. The template documents "whole
  # number greater than 1, or leave blank"; anything else would silently mean
  # "no finite population correction" on precisely the census projects that
  # asked for one.
  raw_pop <- if (!is.null(raw_settings)) raw_settings[["population_size"]] else NULL
  if (!is_blank_setting(raw_pop)) {
    pop <- suppressWarnings(as.numeric(raw_pop[[1]]))
    if (!is.na(pop) && pop <= 1) {
      bad("population_size", "must be a whole number greater than 1 (leave it blank for no finite population correction)")
    }
  }
  # html_report_v2_cover_findings. Not in .TABS_NUMERIC_SETTINGS because "ALL"
  # is a legal value, so the generic number test would refuse it. Junk here would
  # silently mean "five". The very cap the operator was trying to lift.
  raw_cf <- if (!is.null(raw_settings)) raw_settings[["html_report_v2_cover_findings"]] else NULL
  if (!is_blank_setting(raw_cf)) {
    tok <- toupper(trimws(as.character(raw_cf[[1]])))
    n <- suppressWarnings(as.numeric(tok))
    if (tok != "ALL" && (is.na(n) || n < 1)) {
      bad("html_report_v2_cover_findings",
          "must be a whole number of 1 or more, or ALL (leave it blank for the default of 5)")
    }
  }
  # A scale maximum divides every gauge and heatmap cell; zero or negative makes
  # the whole dashboard meaningless rather than merely wrong.
  for (key in c("dashboard_scale_mean", "dashboard_scale_index")) {
    sc <- config_obj[[key]]
    if (!is.null(sc) && (!is.numeric(sc) || length(sc) != 1 || is.na(sc) || sc <= 0)) {
      bad(key, "must be a number greater than 0")
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

  # The qualitative confidentiality dials (I4). Every consumer compares with
  # identical(), so an unrecognised token fell through to the PERMISSIVE branch:
  # "Block" meant allow, "Noteworthy" meant show every verbatim. A dial set to
  # close a gate silently opened it, on exactly the anonymity-sensitive projects
  # that set it. Case and separators are normalised first, so only a genuinely
  # unknown word reaches this refusal.
  for (key in names(.TABS_QUAL_ENUMS)) {
    v <- config_obj[[key]]
    if (is.null(v) || length(v) == 0 || is.na(v[1]) || !nzchar(as.character(v)[1])) next
    tokens <- .TABS_QUAL_ENUMS[[key]]
    if (!(as.character(v)[1] %in% tokens)) {
      tabs_refuse(
        code = "CFG_INVALID_SETTING",
        title = sprintf("Unrecognised %s", key),
        problem = sprintf("Setting '%s' is '%s', which is not one of its allowed values.",
                          key, as.character(v)[1]),
        why_it_matters = paste0(
          "This is a confidentiality dial. An unrecognised value would fall ",
          "through to the most permissive setting - demographic tags or ",
          "verbatim text shipping in a report that was configured to withhold them."
        ),
        how_to_fix = c(
          sprintf("Set '%s' to one of: %s", key, paste(tokens, collapse = ", ")),
          "Case does not matter - the value is read case-insensitively",
          "Leave the cell blank to accept the documented default"
        ),
        expected = paste(tokens, collapse = ", "),
        observed = as.character(v)[1]
      )
    }
  }

  # "safe" k-anonymises demographic tag COMBINATIONS against min_reporting_base
  #, but the anonymiser only engages when k > 1 (qual_island_builder.R), and
  # min_reporting_base defaults to 1. So the source-safe-looking combination
  # 'safe' + default k ships every raw tag combination while reading as
  # protected. This is the operator's choice to make, so it warns rather than
  # refusing; it only fires when a comment workbook is actually configured.
  qw <- config_obj$qual_workbook
  if (identical(config_obj$qual_demographic_cuts, "safe") &&
      !is.null(qw) && length(qw) == 1 && !is.na(qw) && nzchar(as.character(qw))) {
    k <- suppressWarnings(as.numeric(config_obj$min_reporting_base))
    if (!(length(k) == 1L && !is.na(k) && k > 1)) {
      cat("\n┌─── TURAS DISCLOSURE WARNING ────────────────────┐\n")
      cat("│ qual_demographic_cuts = 'safe' but min_reporting_base = ",
          format(config_obj$min_reporting_base), "\n", sep = "")
      cat("│ 'safe' k-anonymises comment tag COMBINATIONS against that threshold,\n")
      cat("│ and a threshold of 1 anonymises nothing - every raw tag combination\n")
      cat("│ (e.g. 'Admin + <1yr + Cape Town', which may be one person) ships.\n")
      cat("│ How to fix: set min_reporting_base to your disclosure floor (e.g. 10),\n")
      cat("│   or set qual_demographic_cuts = 'block' to ship no tags at all.\n")
      cat("└────────────────────────────────────────────┘\n\n")
    }
  }
  invisible(TRUE)
}

# The dashboard settings that must parse as numbers. Every one of them is read
# through safe_numeric() with a fallback, so an unparseable cell would otherwise
# become the default in silence (M9).
# The net and custom pairs left this list when they were retired (I11): a
# setting nothing reads cannot have its value corrupted.
.TABS_DASHBOARD_NUMERIC_SETTINGS <- c(
  "dashboard_scale_mean", "dashboard_scale_index",
  "dashboard_green_mean", "dashboard_amber_mean",
  "dashboard_green_index", "dashboard_amber_index"
)

# EVERY Settings cell that must parse as a number (I2/I3). The dashboard family
# above plus the statistical, display, ranking and universe settings. Each read
# through safe_numeric()/as.numeric() with a fallback, so junk in the cell
# became the value the operator was overriding. test_config_contract.R parses
# build_config_object and fails if a numeric setting is added without joining
# this list.
.TABS_NUMERIC_SETTINGS <- c(
  .TABS_DASHBOARD_NUMERIC_SETTINGS,
  "alpha", "alpha_secondary", "significance_min_base", "min_reporting_base",
  "decimal_places_percent", "decimal_places_ratings", "decimal_places_index",
  "decimal_places_numeric", "decimal_places", "index_summary_decimal_places",
  "ranking_tie_threshold_pct", "ranking_gap_threshold_pct",
  "ranking_completeness_threshold_pct", "ranking_min_base",
  "population_size", "wave_order"
)

# EVERY Settings cell read through safe_logical() (I3). safe_logical prints a
# single scrollback line and returns the default, so an unreadable toggle ran
# the analysis the other way with nothing in the deliverable saying so.
# test_config_contract.R parses build_config_object and fails if a toggle is
# added without joining this list.
.TABS_LOGICAL_SETTINGS <- c(
  "apply_weighting", "show_unweighted_n", "show_effective_n", "show_weighted_base",
  "show_frequency", "show_percent_column", "show_percent_row",
  "boxcategory_frequency", "boxcategory_percent_column", "boxcategory_percent_row",
  "enable_significance_testing", "bonferroni_correction", "enable_checkpointing",
  "zero_division_as_blank", "show_standard_deviation", "test_net_differences",
  "create_sample_composition", "enable_chi_square", "show_net_positive",
  "show_numeric_median", "show_numeric_mode", "show_numeric_sd", "show_numeric_outliers",
  "exclude_outliers_from_stats",
  "html_report_v2", "html_report_v2_microdata", "html_report_v2_tracking",
  "html_report_v2_cover",
  "show_dashboard", "show_patterns", "show_differences", "show_tracking",
  "show_qualitative",
  "show_save_copy",
  "enable_ai_insights", "generate_reader_report", "reader_ai_prose",
  "index_summary_show_sections", "index_summary_show_base_sizes",
  "index_summary_show_composites"
)

# Y/N settings whose consumers read the STRING (an exact `== "Y"` or the flag
# vocabulary) rather than a converted logical. They are canonicalised to "Y"/"N"
# in build_config_object so every consumer agrees, and refuse on any other token.
.TABS_FLAG_SETTINGS <- c("generate_stats_pack", "create_index_summary")

# The qualitative confidentiality dials and their allowed tokens (I4). These
# MUST match QUAL_TEXT_MODES / QUAL_VERBATIM_SCOPES / QUAL_NOTEWORTHY_DEFAULTS
# in qual_island_builder.R and the template dropdowns. Test_config_contract.R
# reads both files and fails on drift.
.TABS_QUAL_ENUMS <- list(
  qual_confidentiality_mode = c("hidden", "redacted", "full"),
  qual_demographic_cuts     = c("allow", "safe", "block"),
  qual_noteworthy_default   = c("all", "noteworthy", "must_read", "priority"),
  qual_verbatim_scope       = c("all", "noteworthy")
)

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
#' returned trimmed as-is. Validate_config_settings() refuses on it.
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
#'   \code{background_text} / \code{executive_summary} /
#'   \code{report_construction} / \code{headlines} attributes), or NULL
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

    # Filter valid rows. QuestionCode is always required; Comment may be blank
    # on a row that only carries a Headline (V13.x)
    df <- df[!is.na(df$QuestionCode) & nzchar(trimws(df$QuestionCode)), , drop = FALSE]
    if (nrow(df) == 0) return(NULL)

    # Support optional Banner column for multi-banner comments
    has_banner <- "Banner" %in% names(df)

    # Extract special dashboard text entries (V10.8.0)
    # Use _BACKGROUND and _EXECUTIVE_SUMMARY as reserved QuestionCode values
    # _REPORT_CONSTRUCTION lets a study state how its numbers were actually
    # built, in place of the About card's default sentence. Turas describes
    # itself accurately, but it cannot see the stages around it - a derived
    # engine ahead of it, a preparation layer, pages that compute in the
    # browser - and a study that has them needs to say so where the reader
    # looks. Left blank, the report reads exactly as it did before.
    special_codes <- c("_BACKGROUND", "_EXECUTIVE_SUMMARY", "_REPORT_CONSTRUCTION")
    background_text <- NULL
    executive_summary <- NULL
    report_construction <- NULL

    for (i in seq_len(nrow(df))) {
      if (!has_comment(df$Comment[i])) next
      q_code <- trimws(toupper(df$QuestionCode[i]))
      if (q_code == "_BACKGROUND") {
        background_text <- trimws(df$Comment[i])
      } else if (q_code == "_EXECUTIVE_SUMMARY") {
        executive_summary <- trimws(df$Comment[i])
      } else if (q_code == "_REPORT_CONSTRUCTION") {
        report_construction <- trimws(df$Comment[i])
      }
    }

    # Filter out special rows from question comments
    df <- df[!trimws(toupper(df$QuestionCode)) %in% special_codes, , drop = FALSE]

    # Optional per-question analyst headline (reader experience plan §E): the
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
        is.null(background_text) && is.null(executive_summary) &&
        is.null(report_construction)) {
      return(NULL)
    }

    n_total <- if (length(comments) > 0) sum(vapply(comments, length, integer(1))) else 0L
    cat(sprintf("  [INFO] Loaded %d comments for %d questions from Comments sheet\n",
                n_total, length(comments)))

    if (!is.null(background_text)) cat(sprintf("  [INFO] Background text loaded from Comments sheet\n"))
    if (!is.null(executive_summary)) cat(sprintf("  [INFO] Executive summary loaded from Comments sheet\n"))
    if (!is.null(report_construction)) cat(sprintf("  [INFO] Report construction note loaded from Comments sheet\n"))
    if (length(headlines) > 0) {
      cat(sprintf("  [INFO] Loaded %d question headline(s) from Comments sheet\n",
                  length(headlines)))
    }

    # Attach dashboard text (and headlines) as attributes
    attr(comments, "background_text") <- background_text
    attr(comments, "executive_summary") <- executive_summary
    attr(comments, "report_construction") <- report_construction
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
#' Largest image an AddedSlides row may embed, in bytes
#'
#' Matches the in-browser import limit so the two routes refuse the same files.
#' The config route embeds at BUILD time and had no limit at all: a 12 MB slide
#' export went straight into the report and nobody found out until the file
#' would not send.
#' @keywords internal
TABS_SLIDE_IMAGE_MAX_BYTES <- 1.5 * 1024 * 1024

#' Intrinsic Pixel Size of an Image, From Its Header
#'
#' Reads width/height out of the file's own header for the formats whose header
#' is fixed and trivially parsed. Pure base R. No image package is added for
#' this. The dimensions travel to the report so a slide exported to PowerPoint
#' keeps its aspect ratio; without them the deck writer stretches the picture to
#' fill the slide.
#'
#' @param raw Raw vector, the whole file
#' @param ext Character, lower-case file extension
#' @return List with \code{w} and \code{h} (integers), or NULL when the format
#'   carries no header this can read (SVG, WebP) or the file is truncated
#' @keywords internal
.slide_image_pixel_size <- function(raw, ext) {
  n <- length(raw)
  be <- function(i) sum(as.integer(raw[i:(i + 3)]) * c(16777216L, 65536L, 256L, 1L))
  le2 <- function(i) as.integer(raw[i]) + 256L * as.integer(raw[i + 1])
  be2 <- function(i) 256L * as.integer(raw[i]) + as.integer(raw[i + 1])
  if (ext == "png" && n >= 24 &&
      identical(as.integer(raw[1:4]), c(137L, 80L, 78L, 71L))) {
    return(list(w = be(17), h = be(21)))
  }
  if (ext == "gif" && n >= 10 && identical(as.integer(raw[1:3]), c(71L, 73L, 70L))) {
    return(list(w = le2(7), h = le2(9)))
  }
  if (ext %in% c("jpg", "jpeg") && n >= 4 &&
      identical(as.integer(raw[1:2]), c(255L, 216L))) {
    # Walk the marker segments to the first frame header (SOF0/1/2/…), whose
    # payload carries the real dimensions. SOF4 (0xC4), SOF8 (0xC8) and SOFC
    # (0xCC) are NOT frame headers. They are Huffman/JPEG-LS tables.
    i <- 3L
    sof <- c(0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
             0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF)
    while (i + 8L <= n) {
      if (as.integer(raw[i]) != 255L) return(NULL)   # not a marker -> give up
      marker <- as.integer(raw[i + 1])
      if (marker %in% sof) return(list(w = be2(i + 7), h = be2(i + 5)))
      seg <- be2(i + 2)
      if (seg < 2L) return(NULL)
      i <- i + 2L + seg
    }
  }
  NULL
}

#' Load Optional ReportText Sheet from Config Excel
#'
#' Per-project overrides for the v2 report's authored text. The platform wording
#' lives in the shared callout registry (module "tabs") and is edited in the
#' Callout Editor; this sheet lets ONE study say something different without
#' changing what every other study says.
#'
#' The sheet ships empty on purpose. A key with no row, or a row with a blank
#' Text cell, uses the platform wording, so an override only exists where an
#' analyst deliberately typed one, and a stale copy of the platform text can
#' never sit in an old config quietly overriding an improvement made since.
#'
#' Unknown keys are NOT silently ignored: they are returned and the report build
#' refuses, naming them, because a typed key that matches nothing looks exactly
#' like an override that is working.
#'
#' @param config_file Path to the config workbook
#' @return Named list of key -> text, or NULL when the sheet is absent or empty
load_report_text_sheet <- function(config_file) {
  tryCatch({
    sheets <- openxlsx::getSheetNames(config_file)
    if (!"ReportText" %in% sheets) return(NULL)

    # A sheet that EXISTS but cannot be read is an authoring fault, not an
    # absence: the study's own wording silently reverts to platform wording and
    # the client report ships in the wrong voice. The authored-text system
    # refuses the build for an unknown KEY, so an unreadable SHEET must not be
    # quieter than that (review 2026-08-21, I-28). A missing sheet is still a
    # clean no-op. That is the normal case for most projects.
    read_err <- NULL
    df <- tryCatch(.read_table_sheet(config_file, "ReportText", c("Key", "Text")),
                   error = function(e) { read_err <<- conditionMessage(e); NULL })
    if (!is.null(read_err)) {
      tabs_refuse(
        code = "CFG_REPORT_TEXT_UNREADABLE",
        title = "ReportText Sheet Could Not Be Read",
        problem = paste0("The config has a ReportText sheet, but reading it failed: ", read_err),
        why_it_matters = paste0(
          "The sheet exists, so this study intends to override some report wording. ",
          "Continuing would silently publish the platform's default wording instead ",
          "of the study's own. A difference nobody would notice until a client did."),
        how_to_fix = c(
          "Open the config's ReportText sheet and check it has 'Key' and 'Text' header columns",
          "Check the sheet is not corrupt (re-save the workbook from Excel)",
          "Delete the ReportText sheet entirely if this study does not override any wording"
        )
      )
    }
    if (is.null(df) || nrow(df) == 0) return(NULL)
    if (!all(c("Key", "Text") %in% names(df))) {
      tabs_refuse(
        code = "CFG_REPORT_TEXT_INVALID_COLUMNS",
        title = "ReportText Sheet Is Missing Key/Text Columns",
        problem = paste0(
          "The ReportText sheet has columns [", paste(names(df), collapse = ", "),
          "] but needs 'Key' and 'Text'."),
        why_it_matters = paste0(
          "Every override on the sheet is ignored without them, so the report would ",
          "ship with platform wording while the config says otherwise."),
        how_to_fix = c(
          "Name the first two header cells 'Key' and 'Text'",
          "Regenerate the config template to get the sheet in its expected shape",
          "Delete the ReportText sheet if this study does not override any wording"
        )
      )
    }

    keys <- trimws(as.character(df$Key))
    txt  <- ifelse(is.na(df$Text), "", as.character(df$Text))
    keep <- !is.na(keys) & nzchar(keys) & nzchar(trimws(txt))
    if (!any(keep)) return(NULL)

    out <- as.list(txt[keep])
    names(out) <- keys[keep]
    cat(sprintf("  Report text: %d per-project override(s) from the ReportText sheet.\n",
                length(out)))
    out
  }, error = function(e) {
    # A TRS refusal raised above must travel, not be downgraded to a warning by
    # the very handler this fix exists to bypass (I-28).
    if (inherits(e, "turas_refusal")) stop(e)
    cat(sprintf("  [WARNING] Could not read ReportText sheet: %s\n", e$message))
    NULL
  })
}


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
        # Strip wrapping quotes before anything else. Every normal way of
        # getting a path onto the clipboard on macOS or Windows can bring
        # quotes with it (dragging a file into a terminal, "Copy as path"),
        # and a cell reading '/Users/…/RatingsMap.png' resolves to nothing.
        # The operator sees a correct-looking path and a missing picture.
        img_path <- gsub("^['\"]+|['\"]+$", "", trimws(df$image_path[i]))
        # Resolve relative paths against config directory
        if (!file.exists(img_path)) {
          img_path <- file.path(config_dir, img_path)
        }
        if (!file.exists(img_path)) {
          # Boxed, not a one-liner: Turas runs behind a Shiny app and this
          # warning used to scroll past in a long console, leaving a slide that
          # looked deliberately text-only.
          cat("\n┌─── TURAS: SLIDE IMAGE NOT FOUND ──────────────────────┐\n")
          cat(sprintf("│ Slide:  %s\n", slide$title))
          cat(sprintf("│ Looked: %s\n", img_path))
          cat("│ Fix:    Check the image_path cell in the AddedSlides sheet.\n")
          cat("│         A relative path is resolved against the config file's\n")
          cat("│         own folder. The slide's text still shows; only the\n")
          cat("│         picture was left out.\n")
          cat("└───────────────────────────────────────────────────────┘\n\n")
          return(slide)
        }
        if (!requireNamespace("base64enc", quietly = TRUE)) {
          # Its own message: this branch used to fall into "file not found",
          # which sent the operator hunting a path that was perfectly correct.
          cat("\n┌─── TURAS: SLIDE IMAGE NOT EMBEDDED ───────────────────┐\n")
          cat(sprintf("│ Slide:  %s\n", slide$title))
          cat("│ Cause:  The 'base64enc' package is not installed, so images\n")
          cat("│         cannot be embedded in the report.\n")
          cat("│ Fix:    install.packages(\"base64enc\"), then re-run.\n")
          cat("└───────────────────────────────────────────────────────┘\n\n")
          return(slide)
        }
        tryCatch({
            img_size <- file.info(img_path)$size
            # Refuse the image, keep the slide. The whole run must not fail over
            # an oversized picture, but the operator has to be told plainly,
            # a silently dropped exhibit is exactly the kind of thing nobody
            # notices until the client asks where it went.
            if (!is.na(img_size) && img_size > TABS_SLIDE_IMAGE_MAX_BYTES) {
              cat("\n┌─── TURAS: SLIDE IMAGE TOO LARGE ──────────────────────┐\n")
              cat(sprintf("│ Slide:  %s\n", slide$title))
              cat(sprintf("│ File:   %s\n", basename(img_path)))
              cat(sprintf("│ Size:   %.1f MB (limit %.1f MB)\n",
                img_size / 1024 / 1024, TABS_SLIDE_IMAGE_MAX_BYTES / 1024 / 1024))
              cat("│ Fix:    Export the slide at a smaller size, or save it as\n")
              cat("│         a JPEG, then re-run. The slide's text still shows;\n")
              cat("│         only the picture was left out.\n")
              cat("└───────────────────────────────────────────────────────┘\n\n")
              return(slide)
            }
            raw <- readBin(img_path, "raw", img_size)
            ext <- tolower(tools::file_ext(img_path))
            mime <- switch(ext,
              png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg",
              gif = "image/gif", webp = "image/webp", svg = "image/svg+xml",
              "image/png"  # fallback
            )
            slide$image_data <- sprintf("data:%s;base64,%s",
              mime, base64enc::base64encode(raw))
            # Intrinsic size, so the PowerPoint export keeps the aspect ratio.
            # Absent for formats with no readable header. The report still
            # shows the image; only the deck falls back to fitting the slide.
            px <- .slide_image_pixel_size(raw, ext)
            if (!is.null(px) && px$w > 0 && px$h > 0) {
              slide$image_w <- px$w
              slide$image_h <- px$h
            }
            cat(sprintf("  [INFO] Embedded image for slide '%s' (%s, %dKB%s)\n",
              slide$title, basename(img_path), round(length(raw) / 1024),
              if (is.null(px)) "" else sprintf(", %dx%d", px$w, px$h)))
          }, error = function(e) {
            cat(sprintf("  [WARNING] Could not embed image '%s': %s\n", img_path, e$message))
          })
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
#' auto-detected in `waves_source`, the project root, or the config directory,
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
#' when its column-A text is a KNOWN setting name. Headers never are.
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
    # Sheet order, not the arbitrary order the merges are stored in. The
    # operator is going to walk down the sheet fixing them.
    found[order(vapply(found, function(h) h$row, integer(1)))]
  }, error = function(e) list())

  if (!length(hits)) return(invisible(character(0)))
  cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
  cat(sprintf("│ Context: config '%s' sheet\n", sheet_name))
  cat("│ These setting rows are merged across columns, so they have\n")
  cat("│ no Value cell and are being IGNORED. Whatever you meant to\n")
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
#' that says `Research_House` never answers a request for `research_house`. The
#' run silently takes the default. The typo check above cannot see this: it
#' lower-cases before comparing, so a case variant looks perfectly valid.
#'
#' When the canonical spelling is ALSO present the variant is merely redundant,
#' and that is said explicitly. Renaming it would produce two identically named
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
  cat("│ Context: config 'Settings' sheet. Case mismatch\n")
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
    cat("│ Rows marked [duplicate] already have a correctly named twin, \n")
    cat("│ DELETE those rows rather than renaming them, or the sheet will\n")
    cat("│ hold the same setting twice and the run will refuse.\n")
  }
  cat("└───────────────────────────────────────────────────────┘\n\n")
  invisible(labels[off])
}


# Settings that no longer do anything. Either because the feature they drove was
# retired, or because they were never read in the first place. A name here is NOT
# a typo, so it must not be reported as one: the operator wrote it deliberately
# and is entitled to know that the run ignored it, and why. Each entry is the
# sentence the loader prints (see announce_retired_settings).
#
# Retirement runs for one release: the name is answered here by name, then the
# entry is deleted and the name falls through to the ordinary "unrecognised
# setting" warning. Retired 2026-08 (remove after the next release).
#
# A dead name must NOT stay on TABS_KNOWN_SETTINGS. While it does, it silently
# blesses itself and defeats the typo warning for its whole neighbourhood. An
# operator who wrote `output_folder` meaning `output_subfolder` was told nothing
# and found the workbook in the default folder (production review 2026-08, I11).
TABS_RETIRED_SETTINGS <- c(
  html_report = paste(
    "the classic HTML report is retired. The interactive report",
    "(html_report_v2) is the deliverable. No HTML file is written for this",
    "setting. Delete the row from the Settings sheet."
  ),

  # --- drove the classic HTML report, retired 2026-08 with it ----------------
  embed_frequencies = paste(
    "drove the classic HTML report, which is retired. The interactive report",
    "shows frequencies from show_frequency. Delete the row."
  ),
  include_summary = paste(
    "drove the classic HTML report's summary page, which is retired. Use",
    "show_dashboard for the interactive report's dashboard. Delete the row."
  ),
  show_charts = paste(
    "drove the classic HTML report, which is retired. The interactive report",
    "always draws its charts. Delete the row."
  ),
  dashboard_metrics = paste(
    "drove the classic HTML report's dashboard, which is retired. The",
    "interactive report picks its dashboard metrics from the questions",
    "themselves. Delete the row."
  ),
  dashboard_sort_gauges = paste(
    "drove the classic HTML report's dashboard, which is retired. Delete the row."
  ),
  dashboard_green_net = paste(
    "was a classic-report dashboard threshold and is read by nothing. The",
    "interactive report's gauges use dashboard_green_mean / dashboard_green_index",
    "(and their amber pairs). Delete the row."
  ),
  dashboard_amber_net = paste(
    "was a classic-report dashboard threshold and is read by nothing. See",
    "dashboard_amber_mean / dashboard_amber_index. Delete the row."
  ),
  dashboard_green_custom = paste(
    "was a classic-report dashboard threshold and is read by nothing. See",
    "dashboard_green_mean / dashboard_green_index. Delete the row."
  ),
  dashboard_amber_custom = paste(
    "was a classic-report dashboard threshold and is read by nothing. See",
    "dashboard_amber_mean / dashboard_amber_index. Delete the row."
  ),
  index_descriptor = paste(
    "labelled a scale in the classic HTML report, which is retired. Delete the row."
  ),
  mean_descriptor = paste(
    "labelled a scale in the classic HTML report, which is retired. Delete the row."
  ),
  nps_descriptor = paste(
    "labelled a scale in the classic HTML report, which is retired. Delete the row."
  ),
  priority_metric = paste(
    "marked a metric for the classic HTML report's charts, which is retired.",
    "Delete the row."
  ),

  # --- never read by anything, at any point ---------------------------------
  output_folder = paste(
    "is not read by Tabs and never has been. The output location is",
    "output_subfolder (a folder inside the project). Delete the row and set",
    "output_subfolder instead."
  ),
  output_file = paste(
    "is not read by Tabs and never has been. The workbook name is",
    "output_filename. Delete the row and set output_filename instead."
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
  # Module contributions
  "conjoint_island", "maxdiff_island",
  # Weighting
  "apply_weighting", "weight_variable", "show_unweighted_n", "show_effective_n",
  "show_weighted_base", "weight_label",
  # Display. Frequencies and percentages
  "decimal_separator", "show_frequency", "show_percent_column", "show_percent_row",
  "boxcategory_frequency", "boxcategory_percent_column", "boxcategory_percent_row",
  "decimal_places", "decimal_places_percent", "decimal_places_ratings",
  "decimal_places_index", "decimal_places_numeric",
  # Statistics
  "show_standard_deviation", "show_net_positive", "show_numeric_median",
  "show_numeric_mode", "show_numeric_sd", "show_numeric_outliers",
  "exclude_outliers_from_stats", "outlier_method",
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
  "show_qualitative", "show_save_copy", "patterns_headline", "patterns_exclude_banners",
  "patterns_banner", "sampling_note", "insight_exclude_categories",
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
  # HTML report (html_report itself is retired, see TABS_RETIRED_SETTINGS)
  "html_report_v2", "html_report_v2_tracking",
  "html_report_v2_microdata", "html_report_v2_cover",
  "html_report_v2_cover_findings",
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
  "fieldwork_dates", # Dashboard
  "dashboard_scale_mean", "dashboard_scale_index",
  "dashboard_green_mean", "dashboard_amber_mean",
  "dashboard_green_index", "dashboard_amber_index",
  # Descriptors
  # Analyst / report metadata
  "analyst_name", "analyst_email", "analyst_phone", "verbatim_filename", "closing_notes",
  # Ranking
  "ranking_completeness_threshold_pct", "ranking_gap_threshold_pct", "ranking_tie_threshold_pct",
  "ranking_min_base",
  # AI Insights
  "enable_ai_insights", "ai_model",
  # File path settings (loaded separately but may appear in Settings sheet)
  "data_file", "structure_file", "output_filename",
  "output_format", "output_subfolder"
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

  # A setting that used to work and no longer does gets named, not ignored,
  # live configs (CCPB among them) still carry html_report = True.
  announce_retired_settings(settings$config)

  # Check for unrecognised settings. Typos are silently ignored otherwise.
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

  # A setting that never arrives is invisible to the check above. It isn't an
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
    config_obj$report_construction <- attr(config_obj$comments, "report_construction")
  }

  # Load optional AddedSlides sheet (V10.8.0, renamed from Qualitative)
  config_obj$qualitative_slides <- load_qualitative_sheet(config_file)

  # Load optional ReportText sheet. Per-project overrides for the v2 report's
  # authored text (the platform wording lives in the callout registry).
  config_obj$report_text_overrides <- load_report_text_sheet(config_file)

  # Load optional Population sheet (finite population correction): per-subgroup
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
  # relative to the project root / config dir), else auto-detected. A
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
