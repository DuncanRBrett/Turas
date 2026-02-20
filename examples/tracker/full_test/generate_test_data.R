# ==============================================================================
# TurasTracker Full Test Project - Data Generator
# ==============================================================================
# Generates a comprehensive test dataset covering ALL question types:
#   - Rating (10-point satisfaction scale)
#   - NPS (0-10 recommend)
#   - Single_Response (categorical: awareness yes/no, preference A/B/C/D)
#   - Multi_Mention (multi-select: channels used)
#   - Composite (calculated from satisfaction + recommend)
#
# 4 Waves, 2 Banner segments (region), 100 respondents per wave.
# Data has a slight upward trend to make charts interesting.
#
# USAGE:
#   source("generate_test_data.R")
#   generate_full_test_project()
# ==============================================================================

library(openxlsx)

generate_full_test_project <- function(output_dir = NULL) {

  if (is.null(output_dir)) {
    output_dir <- dirname(sys.frame(1)$ofile)
  }

  set.seed(42)  # Reproducible

  cat("Generating TurasTracker Full Test Project...\n")
  cat("Output directory:", output_dir, "\n\n")

  # ==========================================================================
  # DEFINE PARAMETERS
  # ==========================================================================
  n_per_wave <- 100
  wave_ids <- c("W1", "W2", "W3", "W4")
  wave_names <- c("Jan 2024", "Apr 2024", "Jul 2024", "Oct 2024")
  regions <- c("Cape Town", "Joburg", "Durban")

  # Trend shifts per wave (cumulative from W1 baseline)
  # Slight upward trend for most metrics
  trend_shift <- c(0, 0.3, 0.5, 0.8)  # for ratings (mean shift)

  # ==========================================================================
  # GENERATE WAVE DATA FILES
  # ==========================================================================
  for (w in seq_along(wave_ids)) {
    wave_id <- wave_ids[w]
    shift <- trend_shift[w]

    cat(paste0("  Generating ", wave_id, " (", wave_names[w], ")...\n"))

    # Respondent IDs
    resp_id <- paste0("R", sprintf("%04d", ((w - 1) * n_per_wave + 1):(w * n_per_wave)))

    # Region (demographic banner variable)
    region <- sample(regions, n_per_wave, replace = TRUE,
                     prob = c(0.40, 0.35, 0.25))

    # Weights (slightly variable)
    weight <- round(runif(n_per_wave, 0.7, 1.4), 2)

    # ---- Q_SAT: Satisfaction (Rating 1-10) ----
    # Base mean ~7.0, trending up
    sat_mean <- 7.0 + shift
    satisfaction <- pmin(10, pmax(1, round(rnorm(n_per_wave, sat_mean, 1.5))))

    # ---- Q_SERVICE: Service Rating (Rating 1-10) ----
    # Base mean ~6.5, trending up slightly
    svc_mean <- 6.5 + shift * 0.8
    service <- pmin(10, pmax(1, round(rnorm(n_per_wave, svc_mean, 1.8))))

    # ---- Q_VALUE: Value for Money (Rating 1-10) ----
    # Base mean ~6.0, trending flat/slight improvement
    val_mean <- 6.0 + shift * 0.5
    value <- pmin(10, pmax(1, round(rnorm(n_per_wave, val_mean, 2.0))))

    # ---- Q_NPS: Net Promoter Score (0-10 scale) ----
    # Generate with proper NPS distribution
    nps_mean <- 7.0 + shift * 0.6
    nps <- pmin(10, pmax(0, round(rnorm(n_per_wave, nps_mean, 2.2))))

    # ---- Q_AWARE: Awareness (Single_Response: Yes/No) ----
    # Base ~65% Yes, trending up
    aware_prob <- 0.65 + shift * 0.05
    awareness <- sample(c("Yes", "No"), n_per_wave, replace = TRUE,
                        prob = c(aware_prob, 1 - aware_prob))

    # ---- Q_PREF: Brand Preference (Single_Response: A/B/C/D) ----
    # Brand A gaining share over time
    pref_probs <- c(0.30 + shift * 0.04, 0.25, 0.25 - shift * 0.02, 0.20 - shift * 0.02)
    pref_probs <- pmax(0.05, pref_probs)  # floor at 5%
    pref_probs <- pref_probs / sum(pref_probs)  # normalize
    preference <- sample(c("Brand A", "Brand B", "Brand C", "Brand D"),
                         n_per_wave, replace = TRUE, prob = pref_probs)

    # ---- Q_CHANNEL: Channels Used (Multi_Mention: multiple binary columns) ----
    # Each channel is a binary 0/1
    ch_online <- rbinom(n_per_wave, 1, 0.55 + shift * 0.05)
    ch_store  <- rbinom(n_per_wave, 1, 0.45 - shift * 0.02)
    ch_phone  <- rbinom(n_per_wave, 1, 0.20 - shift * 0.01)
    ch_app    <- rbinom(n_per_wave, 1, 0.30 + shift * 0.08)

    # ---- Q_INTENT: Purchase Intent (Rating 1-5, Likert) ----
    # Base mean ~3.2, trending up
    # Generate as TEXT responses (to test text → numeric mapping via structure)
    intent_mean <- 3.2 + shift * 0.4
    intent_numeric <- pmin(5, pmax(1, round(rnorm(n_per_wave, intent_mean, 0.9))))
    intent_labels <- c("Strongly Disagree", "Disagree", "Neutral", "Agree", "Strongly Agree")
    intent <- intent_labels[intent_numeric]

    # Add some regional variation
    region_boost <- ifelse(region == "Cape Town", 0.3,
                    ifelse(region == "Joburg", 0, -0.2))
    satisfaction <- pmin(10, pmax(1, satisfaction + round(region_boost)))
    nps <- pmin(10, pmax(0, nps + round(region_boost)))

    # Build data frame
    wave_df <- data.frame(
      respondent_id = resp_id,
      region = region,
      weight = weight,
      satisfaction = satisfaction,
      service_rating = service,
      value_rating = value,
      nps_score = nps,
      awareness = awareness,
      brand_preference = preference,
      channel_online = ch_online,
      channel_store = ch_store,
      channel_phone = ch_phone,
      channel_app = ch_app,
      purchase_intent = intent,
      stringsAsFactors = FALSE
    )

    # Write CSV
    csv_path <- file.path(output_dir, paste0("wave_", w, ".csv"))
    write.csv(wave_df, csv_path, row.names = FALSE)
    cat(paste0("    Written: wave_", w, ".csv (", n_per_wave, " records)\n"))
  }

  # ==========================================================================
  # CREATE PER-WAVE SURVEY STRUCTURE + CONFIG FILES
  # ==========================================================================
  # These enable text → numeric mapping (Q_INTENT) and box: specs.
  # Each wave gets a Survey_Structure.xlsx (Options sheet) and
  # Crosstab_Config.xlsx (Settings sheet with weighting).
  # ==========================================================================
  cat("\n  Creating per-wave structure and config files...\n")

  for (w in seq_along(wave_ids)) {
    wave_id <- wave_ids[w]

    # ---- Survey Structure (Options sheet) ----
    struct_wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(struct_wb, "Options")

    options_df <- data.frame(
      QuestionCode = c(
        # Q_SAT: 1-10 rating (numeric, no BoxCategory needed but included for completeness)
        rep("satisfaction", 10),
        # Q_INTENT: 1-5 Likert with text labels and BoxCategory
        rep("purchase_intent", 5)
      ),
      OptionText = c(
        as.character(1:10),
        "Strongly Disagree", "Disagree", "Neutral", "Agree", "Strongly Agree"
      ),
      DisplayText = c(
        paste0("Rating ", 1:10),
        "Strongly Disagree", "Disagree", "Neutral", "Agree", "Strongly Agree"
      ),
      Index_Weight = c(
        1:10,
        1, 2, 3, 4, 5
      ),
      BoxCategory = c(
        rep(NA, 10),
        "Disagree", "Disagree", "Neutral", "Agree", "Agree"
      ),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(struct_wb, "Options", options_df)

    struct_path <- file.path(output_dir, paste0("structure_w", w, ".xlsx"))
    openxlsx::saveWorkbook(struct_wb, struct_path, overwrite = TRUE)
    cat(paste0("    Written: structure_w", w, ".xlsx\n"))

    # ---- Crosstab Config (Settings sheet) ----
    cfg_wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(cfg_wb, "Settings")

    cfg_df <- data.frame(
      Setting = c("apply_weighting", "weight_variable", "alpha"),
      Value = c("TRUE", "weight", "0.05"),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(cfg_wb, "Settings", cfg_df)

    cfg_path <- file.path(output_dir, paste0("config_w", w, ".xlsx"))
    openxlsx::saveWorkbook(cfg_wb, cfg_path, overwrite = TRUE)
    cat(paste0("    Written: config_w", w, ".xlsx\n"))
  }


  # ==========================================================================
  # CREATE tracking_config.xlsx
  # ==========================================================================
  cat("\n  Creating tracking_config.xlsx...\n")
  wb <- openxlsx::createWorkbook()

  # ---- Sheet 1: Waves ----
  openxlsx::addWorksheet(wb, "Waves")
  waves_df <- data.frame(
    WaveID = wave_ids,
    WaveName = wave_names,
    DataFile = paste0("wave_", 1:4, ".csv"),
    FieldworkStart = as.Date(c("2024-01-01", "2024-04-01", "2024-07-01", "2024-10-01")),
    FieldworkEnd = as.Date(c("2024-01-31", "2024-04-30", "2024-07-31", "2024-10-31")),
    WeightVar = rep("weight", 4),
    StructureFile = paste0("structure_w", 1:4, ".xlsx"),
    ConfigFile = paste0("config_w", 1:4, ".xlsx"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Waves", waves_df)

  # ---- Sheet 2: Settings ----
  openxlsx::addWorksheet(wb, "Settings")
  settings_df <- data.frame(
    Setting = c(
      "project_name",
      "baseline_wave",
      "confidence_level",
      "decimal_places_ratings",
      "show_significance",
      "report_types",
      "html_report",
      "brand_colour",
      "accent_colour",
      "company_name",
      "client_name",
      "default_rating_specs",
      "default_nps_specs",
      "default_single_choice_specs",
      "fieldwork_dates"
    ),
    Value = c(
      "Brand Health Tracker 2024",
      "W1",
      "0.95",
      "1",
      "Y",
      "tracking_crosstab",
      "Y",
      "#323367",
      "#CC9900",
      "The Research LampPost",
      "Test Client Ltd",
      "mean,top2_box",
      "nps_score,promoters_pct",
      "category:Brand A",
      "Jan - Oct 2024"
    ),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Settings", settings_df)

  # ---- Sheet 3: Banner ----
  # NOTE: One row per break variable. The system auto-discovers unique values
  # from the data and creates a segment for each. BreakLabel is the group name.
  openxlsx::addWorksheet(wb, "Banner")
  banner_df <- data.frame(
    BreakVariable = c("Total", "region"),
    BreakLabel = c("Total", "Region"),
    W1 = c("", "region"),
    W2 = c("", "region"),
    W3 = c("", "region"),
    W4 = c("", "region"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Banner", banner_df)

  # ---- Sheet 4: TrackedQuestions ----
  openxlsx::addWorksheet(wb, "TrackedQuestions")
  tracked_df <- data.frame(
    QuestionCode = c(
      "Q_SAT",
      "Q_SERVICE",
      "Q_VALUE",
      "Q_NPS",
      "Q_AWARE",
      "Q_PREF",
      "Q_CHANNEL",
      "Q_INTENT",
      "Q_COMPOSITE"
    ),
    MetricLabel = c(
      "Overall Satisfaction",
      "Service Quality",
      "Value for Money",
      "Net Promoter Score",
      "Brand Awareness",
      "Brand Preference",
      "Channel Usage",
      "Purchase Intent",
      "Customer Experience Index"
    ),
    TrackingSpecs = c(
      "mean=Average,top2_box=Satisfied,top_box=Very Satisfied",
      "mean,top2_box",
      "mean,bottom2_box=Dissatisfied",
      "nps_score,promoters_pct,detractors_pct",
      "category:Yes=Aware",
      "category:Brand A,category:Brand B",
      "any",
      "mean=Average,box:Agree=Positive,box:Disagree=Negative",
      "mean"
    ),
    Section = c(
      "Brand Health",
      "Brand Health",
      "Brand Health",
      "Loyalty",
      "Awareness",
      "Awareness",
      "Channels",
      "Commercial",
      "Summary Metrics"
    ),
    SortOrder = c(1, 2, 3, 4, 5, 6, 7, 8, 9),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "TrackedQuestions", tracked_df)

  config_path <- file.path(output_dir, "tracking_config.xlsx")
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  cat(paste0("    Written: tracking_config.xlsx\n"))

  # ==========================================================================
  # CREATE question_mapping.xlsx
  # ==========================================================================
  cat("\n  Creating question_mapping.xlsx...\n")
  wb2 <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb2, "QuestionMap")
  qmap_df <- data.frame(
    QuestionCode = c(
      "Q_SAT",
      "Q_SERVICE",
      "Q_VALUE",
      "Q_NPS",
      "Q_AWARE",
      "Q_PREF",
      "Q_CHANNEL",
      "Q_INTENT",
      "Q_COMPOSITE"
    ),
    QuestionText = c(
      "Overall, how satisfied are you with our brand? (1-10)",
      "How would you rate the quality of our service? (1-10)",
      "How would you rate the value for money of our products? (1-10)",
      "How likely are you to recommend us to a friend or colleague? (0-10)",
      "Are you aware of our brand?",
      "Which brand do you prefer?",
      "Which channels have you used in the past 3 months?",
      "How likely are you to purchase from us in the next 6 months? (1-5)",
      "Customer Experience Index (Satisfaction + Service + Value)"
    ),
    QuestionType = c(
      "Rating",
      "Rating",
      "Rating",
      "NPS",
      "Single_Response",
      "Single_Response",
      "Multi_Mention",
      "Rating",
      "Composite"
    ),
    W1 = c(
      "satisfaction",
      "service_rating",
      "value_rating",
      "nps_score",
      "awareness",
      "brand_preference",
      "channel_online,channel_store,channel_phone,channel_app",
      "purchase_intent",
      "Q_SAT,Q_SERVICE,Q_VALUE"
    ),
    W2 = c(
      "satisfaction",
      "service_rating",
      "value_rating",
      "nps_score",
      "awareness",
      "brand_preference",
      "channel_online,channel_store,channel_phone,channel_app",
      "purchase_intent",
      "Q_SAT,Q_SERVICE,Q_VALUE"
    ),
    W3 = c(
      "satisfaction",
      "service_rating",
      "value_rating",
      "nps_score",
      "awareness",
      "brand_preference",
      "channel_online,channel_store,channel_phone,channel_app",
      "purchase_intent",
      "Q_SAT,Q_SERVICE,Q_VALUE"
    ),
    W4 = c(
      "satisfaction",
      "service_rating",
      "value_rating",
      "nps_score",
      "awareness",
      "brand_preference",
      "channel_online,channel_store,channel_phone,channel_app",
      "purchase_intent",
      "Q_SAT,Q_SERVICE,Q_VALUE"
    ),
    SourceQuestions = c(
      NA, NA, NA, NA, NA, NA, NA, NA,
      "Q_SAT,Q_SERVICE,Q_VALUE"
    ),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb2, "QuestionMap", qmap_df)

  mapping_path <- file.path(output_dir, "question_mapping.xlsx")
  openxlsx::saveWorkbook(wb2, mapping_path, overwrite = TRUE)
  cat(paste0("    Written: question_mapping.xlsx\n"))

  # ==========================================================================
  # CREATE run_test.R convenience script
  # ==========================================================================
  run_script <- '# ==============================================================================
# Run Full Tracker Test
# ==============================================================================
# This script runs the tracker on the full test dataset.
# It produces both Excel and HTML tracking crosstab reports.
# ==============================================================================

# Set paths
test_dir <- dirname(sys.frame(1)$ofile)
turas_root <- normalizePath(file.path(test_dir, "..", "..", ".."))

# Source the tracker
tracker_path <- file.path(turas_root, "modules", "tracker", "run_tracker.R")
source(tracker_path)

# Run with banners enabled
result <- run_tracker(
  tracking_config_path = file.path(test_dir, "tracking_config.xlsx"),
  question_mapping_path = file.path(test_dir, "question_mapping.xlsx"),
  data_dir = test_dir,
  use_banners = TRUE
)

cat("\\n\\nOutput files:\\n")
if (is.list(result)) {
  for (name in names(result)) {
    cat(paste0("  ", name, ": ", result[[name]], "\\n"))
  }
} else {
  cat(paste0("  ", result, "\\n"))
}
'

  run_script_path <- file.path(output_dir, "run_test.R")
  writeLines(run_script, run_script_path)
  cat(paste0("    Written: run_test.R\n"))

  # ==========================================================================
  # SUMMARY
  # ==========================================================================
  cat("\n")
  cat("================================================================================\n")
  cat("Test Project Generated Successfully!\n")
  cat("================================================================================\n")
  cat(paste0("Location: ", output_dir, "\n\n"))
  cat("Files created:\n")
  cat("  tracking_config.xlsx   - 4 sheets: Waves, Settings, Banner, TrackedQuestions\n")
  cat("  question_mapping.xlsx  - 1 sheet:  QuestionMap\n")
  cat("  wave_1..4.csv          - Wave data (100 records each)\n")
  cat("  structure_w1..4.xlsx   - Per-wave Survey_Structure (Options sheet)\n")
  cat("  config_w1..4.xlsx      - Per-wave Crosstab_Config (weighting settings)\n")
  cat("  run_test.R             - Convenience script to run the tracker\n")
  cat("\n")
  cat("Question Types Covered:\n")
  cat("  - Rating (1-10):       Q_SAT, Q_SERVICE, Q_VALUE\n")
  cat("  - Likert (text data):  Q_INTENT (Strongly Agree..Strongly Disagree with box: specs)\n")
  cat("  - NPS (0-10):          Q_NPS\n")
  cat("  - Single_Response:     Q_AWARE (Yes/No), Q_PREF (Brand A/B/C/D)\n")
  cat("  - Multi_Mention:       Q_CHANNEL (4 binary columns)\n")
  cat("  - Composite:           Q_COMPOSITE (mean of SAT, SERVICE, VALUE)\n")
  cat("\n")
  cat("New Features Tested:\n")
  cat("  - =Label syntax:       mean=Average, top2_box=Satisfied, box:Agree=Positive\n")
  cat("  - box: spec type:      box:Agree, box:Disagree (from BoxCategory in structure)\n")
  cat("  - Text data mapping:   Q_INTENT uses text options mapped via StructureFile\n")
  cat("  - Per-wave structure:  StructureFile + ConfigFile columns in Waves sheet\n")
  cat("\n")
  cat("Banners:\n")
  cat("  - Total (all respondents)\n")
  cat("  - Region: Cape Town, Joburg, Durban\n")
  cat("\n")
  cat("To run:\n")
  cat(paste0("  source('", run_script_path, "')\n"))
  cat("\n")
  cat("Or manually:\n")
  cat("  source('modules/tracker/run_tracker.R')  # from Turas root\n")
  cat("  run_tracker(\n")
  cat(paste0("    tracking_config_path = '", config_path, "',\n"))
  cat(paste0("    question_mapping_path = '", mapping_path, "',\n"))
  cat(paste0("    data_dir = '", output_dir, "',\n"))
  cat("    use_banners = TRUE\n")
  cat("  )\n")
  cat("================================================================================\n")

  invisible(list(
    config_path = config_path,
    mapping_path = mapping_path,
    output_dir = output_dir,
    wave_files = file.path(output_dir, paste0("wave_", 1:4, ".csv"))
  ))
}

# Auto-run if sourced directly
if (sys.nframe() == 0 || identical(environment(), globalenv())) {
  # When sourced interactively, run the generator
  tryCatch({
    test_dir <- dirname(sys.frame(1)$ofile)
    generate_full_test_project(test_dir)
  }, error = function(e) {
    cat("To generate test data, run:\n")
    cat("  generate_full_test_project('/path/to/output/dir')\n")
  })
}
