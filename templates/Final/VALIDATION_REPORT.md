# Template Validation Report
## Final Annotated Templates vs Module Code

**Date:** 2025-12-03
**Purpose:** Validate 9 Final annotated templates against their corresponding module code to identify conflicts and ensure single source of truth

---

## 1. CONFIDENCE MODULE

**Template:** `Confidence_Config_Template_Annotated_Final.xlsx`
**Code:** `/home/user/Turas/modules/confidence/R/01_load_config.R`

### File_Paths Sheet

#### ✅ Parameters that MATCH
- `Data_File` - Required in code (line 163-164)
- `Output_File` - Required in code (line 164-165)

#### ⚠️ Parameters in Template but NOT Required by Code
- `Weight_Variable` - Template includes this but code does NOT require it in File_Paths sheet
  - **Issue:** Template shows this in File_Paths, but code doesn't validate or require it there
  - **Recommendation:** Remove from File_Paths sheet OR add validation in code

#### 📝 Code Notes
- Code makes File_Paths sheet OPTIONAL (lines 137-141)
- Template should clarify this sheet is optional

### Study_Settings Sheet

#### ✅ Parameters that MATCH
- `Calculate_Effective_N` - Required, Y/N validation (lines 209, 395-399)
- `Multiple_Comparison_Adjustment` - Required, Y/N validation (lines 210, 401-405)
- `Multiple_Comparison_Method` - Required, validated if adjustment=Y (lines 211, 407-413)
- `Bootstrap_Iterations` - Required, numeric 1000-10000 (lines 212, 415-421)
- `Confidence_Level` - Required, must be 0.90/0.95/0.99 (lines 213, 423-429)
- `Decimal_Separator` - Required, must be '.' or ',' (lines 214, 431-435)

#### ❌ Parameters in CODE but NOT in Template
- **MISSING IN TEMPLATE:** `random_seed` - Code checks for this optional parameter (lines 437-446)
  - **Impact:** Users cannot set random seed for reproducibility
  - **Recommendation:** ADD to template as optional parameter

### Question_Analysis Sheet

**Sheet Structure:** Template has 14 columns, code validates 5+ required columns

#### ✅ Required Columns that MATCH
- `Question_ID` - Required (line 249)
- `Statistic_Type` - Required, validates proportion/mean/nps (lines 250, 472-478)
- `Run_MOE` - Required (line 251)
- `Run_Bootstrap` - Required (line 252)
- `Run_Credible` - Required (line 253)

#### ✅ Optional Columns Validated by Code
- `Categories` - Required when Statistic_Type='proportion' (lines 481-488)
- `Promoter_Codes` - Required when Statistic_Type='nps' (line 492-494)
- `Detractor_Codes` - Required when Statistic_Type='nps' (line 495-497)
- `Use_Wilson` - Optional Y/N (lines 513-520)
- `Prior_Mean` - Optional numeric (lines 523-560)
- `Prior_SD` - Required when Prior_Mean specified for mean/nps (lines 541-558)

#### 🔄 Potential Issues
- Template has 14 columns but only ~10 are validated by code
- Need to verify template column names exactly match code expectations

### Population_Margins Sheet (Optional)

#### ❌ MISSING ENTIRELY FROM TEMPLATE
- Code loads optional "Population_Margins" sheet (lines 567-695)
- **Required columns:** Variable, Category_Label, Target_Prop
- **Optional columns:** Category_Code, Include
- **Impact:** Users cannot specify population targets for representativeness checking
- **Recommendation:** ADD as optional sheet to template

---

## 2. CONJOINT MODULE

**Template:** `Conjoint_Config_Template_Annotated_Final.xlsx`
**Code:** `/home/user/Turas/modules/conjoint/R/01_config.R`

### Settings Sheet

#### ✅ Parameters that MATCH
- `analysis_type` - Default 'choice', validates choice/rating (lines 169, 307-313)
- `choice_set_column` - Default 'choice_set_id' (line 177)
- `chosen_column` - Default 'chosen' (line 178)
- `respondent_id_column` - Default 'resp_id' (line 176)
- `data_file` - Required (lines 127-130, 364-366)
- `output_file` - Optional (lines 131-141)
- `confidence_level` - Default 0.95, validates 0.80-0.99 (lines 172, 336-342)
- `baseline_handling` - Default 'first_level_zero' (lines 171, 327-333)
- `choice_type` - Default 'single', validates single/single_with_none/best_worst/continuous_sum (lines 173, 345-353)
- `estimation_method` - Default 'auto', validates auto/mlogit/clogit/hb (lines 170, 316-324)
- `generate_market_simulator` - Default TRUE (lines 183-186)

#### ❌ Parameters in CODE but NOT in Template
- `alternative_id_column` - Default 'alternative_id' (line 179)
  - **Impact:** Users cannot customize alternative ID column name
  - **Recommendation:** ADD to template
- `rating_variable` - Default 'rating' (line 180)
  - **Impact:** For rating-based conjoint, users cannot specify rating column
  - **Recommendation:** ADD to template (especially important for analysis_type='rating')
- `include_diagnostics` - Default TRUE (lines 187-190)
  - **Recommendation:** ADD to template
- `bootstrap_iterations` - Default 1000 (line 193)
  - **Recommendation:** ADD to template
- `min_responses_per_level` - Default 10 (line 194)
  - **Recommendation:** ADD to template
- `none_as_baseline` - Default FALSE (line 197)
  - **Impact:** For choice_type='single_with_none', cannot configure none handling
  - **Recommendation:** ADD to template (critical for none option handling)
- `none_label` - Default 'None' (line 198)
  - **Recommendation:** ADD to template

#### ⚠️ Parameters in Template but Ambiguous in Code
- Template includes "Setting" as a parameter (row 7) - this appears to be a formatting error in template

### Attributes Sheet

#### ✅ Structure MATCHES
- `AttributeName` - Required, validated (lines 242-250)
- `NumLevels` - Required, validated must be ≥2 (lines 253-267)
- `LevelNames` - Required, parsed as comma-separated list (line 103, 277-284)

#### 🔄 Validation Differences
- Code validates max 6 attributes (warning only, line 234)
- Code validates max 6 levels per attribute (warning only, lines 270-275)
- Template should document these soft limits

---

## 3. CROSSTAB MODULE

**Template:** `Crosstab_Config_Template_Annotated_Final.xlsx`
**Code:** `/home/user/Turas/modules/tabs/lib/config_loader.R`

### Settings Sheet

#### ✅ Parameters that MATCH (Display Settings)
- `apply_weighting` - Default FALSE (line 231)
- `weight_variable` - Default NULL (line 232)
- `show_unweighted_n` - Default TRUE (line 233)
- `show_effective_n` - Default TRUE (line 234)
- `weight_label` - Default 'Weighted' (line 235)
- `decimal_separator` - Default '.' (line 238)
- `show_frequency` - Default TRUE (line 239)
- `show_percent_column` - Default TRUE (line 240)
- `show_percent_row` - Default FALSE (line 241)
- `decimal_places_percent` - Default 0 (line 249)
- `decimal_places_ratings` - Default 1 (line 250)
- `decimal_places_index` - Default 1 (line 251)
- `decimal_places_numeric` - Default 1 (line 252)

#### ✅ Parameters that MATCH (BoxCategory)
- `boxcategory_frequency` - Default FALSE (line 244)
- `boxcategory_percent_column` - Default TRUE (line 245)
- `boxcategory_percent_row` - Default FALSE (line 246)

#### ✅ Parameters that MATCH (Significance)
- `enable_significance_testing` - Default TRUE (line 255)
- `alpha` - Default 0.05 (line 256)
- `significance_min_base` - Default 30 (line 257)
- `bonferroni_correction` - Default TRUE (line 258)
- `enable_chi_square` - Default FALSE (line 259)

#### ✅ Parameters that MATCH (Advanced)
- `show_standard_deviation` - Default FALSE (line 262)
- `test_net_differences` - Default FALSE (line 263)
- `create_sample_composition` - Default FALSE (line 264)
- `show_net_positive` - Default FALSE (line 265)
- `show_numeric_median` - Default FALSE (line 268)
- `show_numeric_mode` - Default FALSE (line 269)
- `show_numeric_outliers` - Default TRUE (line 270)
- `exclude_outliers_from_stats` - Default FALSE (line 271)
- `outlier_method` - Default 'IQR' (line 272)

#### ✅ Parameters that MATCH (System)
- `enable_checkpointing` - Default TRUE (line 275)
- `zero_division_as_blank` - Default TRUE (line 276)

#### ✅ Parameters that MATCH (Output)
- `output_subfolder` - Default 'Crosstabs' (line 279)
- `output_filename` - Default 'Crosstabs.xlsx' (line 280)
- `structure_file` - Required for path resolution (line 313)

#### ⚠️ Parameters in TEMPLATE but NOT Validated in Code
- `output_format` - Template lists this but code doesn't use it
  - **Recommendation:** Remove from template OR add to code
- `weight_na_threshold` - Template lists but not in code
  - **Recommendation:** Remove from template OR add to code
- `weight_zero_threshold` - Template lists but not in code
  - **Recommendation:** Remove from template OR add to code
- `weight_deff_warning` - Template lists but not in code
  - **Recommendation:** Remove from template OR add to code

#### ⚠️ Parameters in TEMPLATE (Ranking) - Not Validated in Code
- `ranking_tie_threshold_pct`
- `ranking_gap_threshold_pct`
- `ranking_completeness_threshold_pct`
- `ranking_min_base`
  - **Issue:** These are in template but config_loader.R doesn't validate them
  - **Recommendation:** Either add validation OR remove from template

#### ⚠️ Parameters in TEMPLATE (Index Summary) - Not Validated in Code
- `create_index_summary`
- `index_summary_show_sections`
- `index_summary_show_base_sizes`
- `index_summary_show_composites`
- `index_summary_decimal_places`
  - **Issue:** These are in template but config_loader.R doesn't validate them
  - **Recommendation:** Either add validation OR remove from template

### Selection Sheet

#### ✅ Structure MATCHES
- `QuestionCode` - Required (line 401)
- `Include` - Default 'N' (lines 412-413, 435)
- `UseBanner` - Default 'N' (lines 415-416, 432)
- `BannerBoxCategory` - Default 'N' (lines 418-419)
- `CreateIndex` - Default 'N' (lines 421-422)

#### 🔄 Template Has Additional Columns (Not Validated)
- `Column`, `BannerLabel`, `DisplayOrder`, `BaseFilter`, `QuestionText`
  - These columns in template are not explicitly validated by config_loader.R
  - They may be used by downstream processing

### Base Filters Sheet

#### ⚠️ Sheet Exists in Template but NOT Loaded by Code
- Template includes "Base Filters" sheet with filter syntax examples
- Code does NOT load or validate this sheet
- **Recommendation:** Clarify this is documentation/examples only

---

## 4. KEYDRIVER MODULE

**Template:** `KeyDriver_Config_Template_Annotated_Final.xlsx`
**Code:** `/home/user/Turas/modules/keydriver/R/01_config.R`

### Settings Sheet

#### ✅ Parameters that MATCH
- `data_file` - Required (lines 29-39)
- `output_file` - Required (lines 30, 41-47)
- `analysis_name` - Template includes (not explicitly validated but extracted as part of settings_list)

#### ❌ Parameters in CODE but NOT in Template
- Code extracts ALL settings from Settings sheet into `settings_list` (lines 25-26)
- Template only shows 3 settings, but code doesn't enforce specific settings
- **Issue:** Template is incomplete - no guidance on other possible settings
- **Recommendation:** Clarify what settings are available/optional

### Variables Sheet

#### ✅ Required Columns that MATCH
- `VariableName` - Required (line 53)
- `Type` - Required, validates Outcome/Driver/Weight (lines 53, 61-87)
- `Label` - Required (line 53)

#### 🔄 Validation Logic
- Code requires exactly 1 Outcome variable (lines 64-72)
- Code requires at least 1 Driver variable (lines 74-77)
- Code allows 0-1 Weight variable (lines 80-88)
- Template should document these requirements

---

## 5. PRICING MODULE

**Template:** `Pricing_Config_Template_Annotated_Final.xlsx`
**Code:** `/home/user/Turas/modules/pricing/R/01_config.R`

### Settings Sheet

#### ✅ Parameters that MATCH
- `project_name` - Default 'Pricing Analysis' (line 380)
- `analysis_method` - Required, validates van_westendorp/gabor_granger/both (lines 82-85, 149-154)
- `currency_symbol` - Default '$' (line 381)
- `data_file` - Required (lines 59-72, 364-366)
- `id_var` - Default NA (lines 432-435)
- `weight_var` - Default NA (lines 385-388)
- `dk_codes` - Comma-separated list (lines 423-429)
- `unit_cost` - Optional numeric (lines 399-403)
- `vw_monotonicity_behavior` - Default 'flag_only', validates drop/fix/flag_only (lines 406-412)
- `gg_monotonicity_behavior` - Default 'smooth', validates diagnostic_only/smooth (lines 414-420)
- `segment_vars` - Comma-separated list (lines 391-396)

#### ❌ Parameters in CODE but NOT in Template
- `output_file` - Code resolves this (lines 74-80)
  - **Recommendation:** ADD to Settings template
- `verbose` - Default TRUE (line 382)
  - **Recommendation:** ADD to Settings template

### VanWestendorp Sheet

#### ✅ Parameters that MATCH
- `col_too_cheap` - Required for VW (line 250)
- `col_cheap` - Required for VW (line 251)
- `col_expensive` - Required for VW (line 252)
- `col_too_expensive` - Required for VW (line 253)
- `validate_monotonicity` - Default TRUE (line 256)
- `violation_threshold` - Default 0.1 (line 258)
- `interpolation_method` - Default 'linear' (line 259)
- `calculate_confidence` - Default FALSE (line 260)
- `confidence_level` - Default 0.95 (line 261)
- `bootstrap_iterations` - Default 1000 (line 262)

#### ❌ Parameters in CODE but NOT in Template
- `exclude_violations` - Default FALSE (line 257)
  - **Recommendation:** ADD to template
- `price_decimals` - Default 2 (line 263)
  - **Recommendation:** ADD to template

### GaborGranger Sheet

#### ✅ Parameters that MATCH
- `data_format` - Default 'wide' (line 278)
- `price_sequence` - Semicolon-separated for wide format (lines 211-212, 281-283)
- `response_columns` - Semicolon-separated for wide format (lines 215-217, 284-286)
- `price_column` - For long format (line 289)
- `response_column` - For long format (line 290)
- `respondent_column` - For long format (line 291)
- `scale_threshold` - Default 3 (line 295)
- `check_monotonicity` - Default TRUE (line 298)
- `calculate_elasticity` - Default TRUE (line 299)
- `revenue_optimization` - Default TRUE (line 300)
- `confidence_intervals` - Default FALSE (line 301)
- `bootstrap_iterations` - Default 1000 (line 302)
- `confidence_level` - Default 0.95 (line 303)

#### ❌ Parameters in CODE but NOT in Template
- `response_type` - Default 'binary', code expects this (line 294)
  - **Recommendation:** ADD to template (important for scale-based responses)
- `run_simulation` - Default FALSE (line 306)
  - **Recommendation:** ADD to template
- `market_size` - Default 10000 (line 307)
  - **Recommendation:** ADD to template
- `unit_cost` - Code checks for this in GG config (line 308)
  - Note: Also in main Settings, may be redundant

#### 🔄 Template Has "response_coding" but Code Uses "response_type"
- Template: `response_coding`
- Code: `response_type` (line 294)
- **Issue:** NAME MISMATCH
- **Recommendation:** Change template to use `response_type`

### Bootstrap Sheet

#### ⚠️ Sheet Exists in Template but NOT Loaded Separately
- Code doesn't have a separate "Bootstrap" sheet loader
- Bootstrap settings are in VW and GG sheets
- **Issue:** Template has redundant Bootstrap sheet
- **Recommendation:** Remove Bootstrap sheet OR integrate into code

### Validation Sheet

#### ⚠️ Sheet Exists in Template but Loaded Differently
- Code has `load_validation_config()` function (lines 319-322)
- Default values in code: min_completeness=0.8, price_min=0, price_max=10000, etc. (lines 341-348)
- Template parameters mostly match defaults
- **Recommendation:** Verify all Validation parameters in template match code expectations

#### ✅ Likely MATCHES (based on defaults)
- `min_completeness` - Default 0.8
- `check_ranges` - Implied by price_min/max
- `min_price` - Default 0 (as price_min in code)
- `max_price` - Default 10000 (as price_max in code)
- `flag_outliers` - Default TRUE
- `outlier_method` - Default 'iqr'
- `outlier_threshold` - Default 3

### Output Sheet

#### ⚠️ Sheet Exists in Template but NOT Loaded Separately
- Code doesn't have a separate "Output" sheet loader
- Output settings are in main Settings
- **Issue:** Template has separate Output sheet
- **Recommendation:** Remove Output sheet OR add loader to code

---

## 6. SEGMENT MODULE

**Template:** `Segment_Config_Template_Annotated_Final.xlsx`
**Code:** `/home/user/Turas/modules/segment/lib/segment_config.R`

### Config Sheet

#### ✅ Parameters that MATCH (Data Source)
- `data_file` - Required (line 156)
- `data_sheet` - Default 'Data' (line 184)
- `id_variable` - Required (line 157)

#### ✅ Parameters that MATCH (Variables)
- `clustering_vars` - Required, comma/semicolon-separated, min 2, max 20 (lines 160-177)
- `profile_vars` - Optional, comma/semicolon-separated (lines 187-198)

#### ✅ Parameters that MATCH (Model)
- `method` - Default 'kmeans', validates only kmeans currently (lines 201-202)
- `k_fixed` - Optional, if set must be ≥2 (lines 204-231)
- `k_min` - Default 3, range 2-10 (line 211)
- `k_max` - Default 6, range 2-15 (line 212)
- `nstart` - Default 50, range 1-200 (line 213)
- `seed` - Default 123, min 1 (line 214)

#### ✅ Parameters that MATCH (Data Handling)
- `missing_data` - Default 'listwise_deletion', validates listwise_deletion/mean_imputation/median_imputation/refuse (lines 234-239)
- `missing_threshold` - Default 15, range 0-100 (lines 241-242)
- `standardize` - Default TRUE (line 244)
- `min_segment_size_pct` - Default 10, range 0-50 (lines 246-247)

#### ✅ Parameters that MATCH (Outlier Detection)
- `outlier_detection` - Default FALSE (lines 250-251)
- `outlier_method` - Default 'zscore', validates zscore/mahalanobis (lines 253-255)
- `outlier_threshold` - Default 3.0, range 1.0-5.0 (lines 257-258)
- `outlier_min_vars` - Default 1, min 1 (lines 260-261)
- `outlier_handling` - Default 'flag', validates none/flag/remove (lines 263-265)
- `outlier_alpha` - Default 0.001, range 0.0001-0.1 (lines 267-268)

#### ✅ Parameters that MATCH (Variable Selection)
- `variable_selection` - Default FALSE (lines 279-280)
- `variable_selection_method` - Default 'variance_correlation', validates variance_correlation/factor_analysis/both (lines 282-286)
- `max_clustering_vars` - Default 10, range 2-20 (lines 288-289)
- `varsel_min_variance` - Default 0.1, range 0.01-1.0 (lines 291-292)
- `varsel_max_correlation` - Default 0.8, range 0.5-0.95 (lines 294-295)

#### ✅ Parameters that MATCH (Validation)
- `k_selection_metrics` - Default 'silhouette,elbow', validates silhouette/elbow/gap (lines 308-319)

#### ✅ Parameters that MATCH (Output)
- `output_folder` - Default 'output/' (line 322)
- `output_prefix` - Default 'seg_' (line 323)
- `create_dated_folder` - Default TRUE (lines 324-325)
- `segment_names` - Default 'auto' or comma-separated list (lines 327-343)
- `save_model` - Default TRUE (line 345)

#### ✅ Parameters that MATCH (Metadata)
- `project_name` - Default 'Segmentation Analysis' (lines 348-349)
- `analyst_name` - Default 'Analyst' (lines 350-351)
- `description` - Default '' (lines 352-353)
- `question_labels_file` - Optional, loads labels for variables (lines 355-363)

#### 🎯 PERFECT ALIGNMENT
- Segment module shows **EXCELLENT alignment** between template and code
- All 36 parameters in template match code expectations
- Comprehensive validation with clear error messages

---

## 7. SURVEY_STRUCTURE MODULE

**Template:** `Survey_Structure_Template_Annotated_Final.xlsx`
**Code:** `/home/user/Turas/modules/tabs/lib/config_loader.R` (same as Crosstab)

### Project Sheet

#### ✅ Parameters that MATCH
- `project_name` - Used by system (line 322 references structure file)
- `data_file` - Required, loaded from Survey_Structure Project sheet (lines 322-329)
- `output_folder` - Implied by output path resolution

#### ⚠️ Parameters in TEMPLATE but NOT Validated
- `project_code`, `client_name`, `study_type`, `study_date` - These are in template but code doesn't validate them
- `total_sample`, `contact_person`, `notes` - Not validated
- `weight_column_exists`, `weight_columns`, `default_weight`, `weight_description` - Not validated
  - **Issue:** Code only loads data_file from Project sheet
  - **Recommendation:** Either validate these OR clarify they're metadata only

### Questions Sheet

#### ✅ Required Columns (Assumed to Match)
- `QuestionCode`, `QuestionText`, `Variable_Type`, `Columns`
  - Code loads Questions sheet for survey structure
  - Validation happens in downstream processing, not in config_loader.R

#### 🔄 Template Has Additional Columns
- `Ranking_Format`, `Ranking_Positions`, `Ranking_Direction`
- `Category`, `Notes`, `Min_Value`, `Max_Value`
  - These may be used by tabs processing, not config loader

### Options Sheet

#### 🔄 Structure Not Validated in Config Loader
- Options sheet is referenced but not validated in config_loader.R
- Validation likely happens in tabs processing
- Template columns seem reasonable for options configuration

### Composite_Metrics Sheet

#### ⚠️ Sheet in Template but NOT Referenced in Config Loader
- Template includes Composite_Metrics sheet
- config_loader.R doesn't reference this sheet
- **Recommendation:** Verify if this sheet is used elsewhere OR remove from template

---

## 8. TRACKER MODULE

**Template:** `Tracker_Config_Template_Annotated_Final.xlsx`
**Code:** `/home/user/Turas/modules/tracker/tracker_config_loader.R`

### Waves Sheet

#### ✅ Required Columns that MATCH
- `WaveID` - Required, must be unique (lines 57-61, 250-252)
- `WaveName` - Required (line 57)
- `DataFile` - Required (line 57)
- `FieldworkStart` - Required (line 57)
- `FieldworkEnd` - Required (line 57)

#### 🔄 Validation Notes
- Code validates FieldworkEnd ≥ FieldworkStart (lines 264-269)
- Code validates data files exist (lines 255-261)
- Template structure matches requirements

### Settings Sheet

#### ✅ Settings Parsed as Named List
- Code converts Settings sheet to named list (lines 63-74)
- Code expects "Setting" and "Value" columns (lines 196-206)
- Template structure matches

#### ⚠️ Settings Validated by Other Functions
- `project_name`, `decimal_places_ratings`, `show_significance` - Referenced as required (lines 286-293)
- **Issue:** Template doesn't show which settings are required vs optional
- **Recommendation:** Document required settings in template

### TrackedQuestions Sheet

#### ✅ Required Column that MATCHES
- `QuestionCode` - Required (line 98-100)

#### 🔄 Template Has Additional Columns
- `QuestionText`, `Tracking detail` - In template but not validated
- These are likely for user reference/documentation

### Banner Sheet

#### ✅ Required Columns that MATCH
- `BreakVariable` - Required (line 84)
- `BreakLabel` - Required (line 84)

#### 🔄 Validation Notes
- Code checks for "Total" in banner (lines 301-304)
- Code requires at least 1 banner row (lines 296-298)

---

## 9. TRACKER_MAPPING MODULE

**Template:** `Tracker_Question_Mapping_Template_Annotated_Final.xlsx`
**Code:** `/home/user/Turas/modules/tracker/tracker_config_loader.R` (load_question_mapping function)

### QuestionMap Sheet

#### ✅ Required Columns that MATCH
- `QuestionCode` - Required (line 149)
- `QuestionText` - Required (line 149)
- `QuestionType` - Required (line 149)

#### ✅ Dynamic Wave Columns
- Code dynamically detects wave columns (e.g., W1, W2, W3 or Wave1, Wave2, Wave3) (lines 156-173)
- Template includes: `Wave 1`, `Wave 2`
- **Validation:** Code filters columns by non-emptiness, template structure allows flexibility

#### 🔄 Additional Columns in Template
- `Column`, `TrackingSpecs`, `SourceQuestions` - In template but not in required validation
- Code excludes these from wave detection (line 158)
- These appear to be metadata/reference columns

---

## SUMMARY OF CRITICAL ISSUES

### 🔴 HIGH PRIORITY - Missing Required Parameters

1. **Confidence:**
   - Missing optional "Population_Margins" sheet entirely
   - Missing optional "random_seed" parameter in Study_Settings

2. **Conjoint:**
   - Missing 7 important parameters in Settings: alternative_id_column, rating_variable, include_diagnostics, bootstrap_iterations, min_responses_per_level, none_as_baseline, none_label

3. **Pricing:**
   - NAME MISMATCH: Template has "response_coding" but code expects "response_type"
   - Missing "response_type" in GaborGranger sheet
   - Missing "exclude_violations", "price_decimals" in VanWestendorp sheet
   - Bootstrap and Output sheets in template but not loaded by code

4. **Crosstab:**
   - Template has 11 parameters that code doesn't validate (weight thresholds, ranking parameters, index summary parameters)

### 🟡 MEDIUM PRIORITY - Documentation Issues

1. **KeyDriver:**
   - Template only shows 3 settings, unclear what other settings are supported

2. **Survey_Structure:**
   - Many Project sheet parameters not validated
   - Composite_Metrics sheet not referenced in code

3. **Tracker:**
   - Template doesn't clarify which settings are required vs optional

### 🟢 EXCELLENT ALIGNMENT

1. **Segment:** Perfect alignment - all 36 parameters match
2. **Tracker Core Sheets:** Good structural match
3. **Tracker_Mapping:** Good structural match

---

## RECOMMENDATIONS

### Immediate Actions:

1. **Confidence Template:**
   - ADD Population_Margins sheet as optional
   - ADD random_seed to Study_Settings

2. **Conjoint Template:**
   - ADD 7 missing parameters to Settings sheet

3. **Pricing Template:**
   - RENAME "response_coding" to "response_type" in GaborGranger
   - ADD missing VanWestendorp parameters
   - REMOVE Bootstrap sheet OR implement loader
   - REMOVE Output sheet OR implement loader

4. **Crosstab Template:**
   - REMOVE parameters not validated by code OR
   - ADD validation for ranking and index summary parameters

### Process Improvements:

1. Add template version numbers to track changes
2. Create automated validation tests for template-code alignment
3. Document which sheets/parameters are optional vs required
4. Add default values to all templates for clarity

---

**Report Generated:** 2025-12-03
**Total Modules Validated:** 9
**Overall Assessment:** Significant misalignments found in 4 of 9 modules requiring immediate attention
