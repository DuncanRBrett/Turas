# Parameter-by-Parameter Comparison
## Template vs Code Parameter Mapping

---

## 1. CONFIDENCE MODULE

### File_Paths Sheet

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| Data_File | ✅ | ✅ Yes | - | 163-164 | ✅ | Required parameter |
| Output_File | ✅ | ✅ Yes | - | 164-165 | ✅ | Required parameter |
| Weight_Variable | ✅ | ❌ No | - | - | ⚠️ | In template but not required by code |

**Sheet Status:** Optional (code allows NULL)

### Study_Settings Sheet

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| Calculate_Effective_N | ✅ | ✅ Yes | - | 209, 395-399 | ✅ | Must be Y/N |
| Multiple_Comparison_Adjustment | ✅ | ✅ Yes | - | 210, 401-405 | ✅ | Must be Y/N |
| Multiple_Comparison_Method | ✅ | ✅ Yes | - | 211, 407-413 | ✅ | Bonferroni/Holm/FDR |
| Bootstrap_Iterations | ✅ | ✅ Yes | - | 212, 415-421 | ✅ | 1000-10000 |
| Confidence_Level | ✅ | ✅ Yes | - | 213, 423-429 | ✅ | 0.90/0.95/0.99 |
| Decimal_Separator | ✅ | ✅ Yes | - | 214, 431-435 | ✅ | Must be '.' or ',' |
| random_seed | ❌ | ❌ Optional | - | 437-446 | ❌ | MISSING in template |

### Question_Analysis Sheet

| Column | Template | Code Required | Code Default | Code Line | Match | Notes |
|--------|----------|---------------|--------------|-----------|-------|-------|
| Question_ID | ✅ | ✅ Yes | - | 249 | ✅ | Primary identifier |
| Statistic_Type | ✅ | ✅ Yes | - | 250, 472-478 | ✅ | proportion/mean/nps |
| Run_MOE | ✅ | ✅ Yes | - | 251 | ✅ | Must be Y/N |
| Run_Bootstrap | ✅ | ✅ Yes | - | 252 | ✅ | Must be Y/N |
| Run_Credible | ✅ | ✅ Yes | - | 253 | ✅ | Must be Y/N |
| Categories | ✅ | ⚠️ Conditional | - | 481-488 | ✅ | Required if Statistic_Type=proportion |
| Promoter_Codes | ✅ | ⚠️ Conditional | - | 492-494 | ✅ | Required if Statistic_Type=nps |
| Detractor_Codes | ✅ | ⚠️ Conditional | - | 495-497 | ✅ | Required if Statistic_Type=nps |
| Use_Wilson | ✅ | ❌ Optional | - | 513-520 | ✅ | Y/N |
| Prior_Mean | ✅ | ❌ Optional | - | 523-560 | ✅ | Numeric |
| Prior_SD | ✅ | ⚠️ Conditional | - | 541-558 | ✅ | Required if Prior_Mean set for mean/nps |

### Population_Margins Sheet (MISSING)

| Column | Template | Code Required | Code Default | Code Line | Match | Notes |
|--------|----------|---------------|--------------|-----------|-------|-------|
| Variable | ❌ | ❌ Optional | - | 614 | ❌ | MISSING SHEET |
| Category_Label | ❌ | ❌ Optional | - | 614 | ❌ | MISSING SHEET |
| Target_Prop | ❌ | ❌ Optional | - | 614 | ❌ | MISSING SHEET |
| Category_Code | ❌ | ❌ Optional | - | 627-629 | ❌ | MISSING SHEET |
| Include | ❌ | ❌ Optional | Y | 631-633 | ❌ | MISSING SHEET |

---

## 2. CONJOINT MODULE

### Settings Sheet

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| analysis_type | ✅ | ❌ Optional | choice | 169, 307-313 | ✅ | choice/rating |
| choice_set_column | ✅ | ❌ Optional | choice_set_id | 177 | ✅ | Column name |
| chosen_column | ✅ | ❌ Optional | chosen | 178 | ✅ | Column name |
| respondent_id_column | ✅ | ❌ Optional | resp_id | 176 | ✅ | Column name |
| data_file | ✅ | ✅ Yes | - | 127-130 | ✅ | File path |
| output_file | ✅ | ❌ Optional | auto | 131-141 | ✅ | File path |
| confidence_level | ✅ | ❌ Optional | 0.95 | 172, 336-342 | ✅ | 0.80-0.99 |
| baseline_handling | ✅ | ❌ Optional | first_level_zero | 171, 327-333 | ✅ | first_level_zero/all_levels_explicit |
| choice_type | ✅ | ❌ Optional | single | 173, 345-353 | ✅ | single/single_with_none/best_worst/continuous_sum |
| estimation_method | ✅ | ❌ Optional | auto | 170, 316-324 | ✅ | auto/mlogit/clogit/hb |
| generate_market_simulator | ✅ | ❌ Optional | TRUE | 183-186 | ✅ | Logical |
| alternative_id_column | ❌ | ❌ Optional | alternative_id | 179 | ❌ | MISSING in template |
| rating_variable | ❌ | ❌ Optional | rating | 180 | ❌ | MISSING in template |
| include_diagnostics | ❌ | ❌ Optional | TRUE | 187-190 | ❌ | MISSING in template |
| bootstrap_iterations | ❌ | ❌ Optional | 1000 | 193 | ❌ | MISSING in template |
| min_responses_per_level | ❌ | ❌ Optional | 10 | 194 | ❌ | MISSING in template |
| none_as_baseline | ❌ | ❌ Optional | FALSE | 197 | ❌ | MISSING in template - CRITICAL for none handling |
| none_label | ❌ | ❌ Optional | None | 198 | ❌ | MISSING in template |

### Attributes Sheet

| Column | Template | Code Required | Code Default | Code Line | Match | Notes |
|--------|----------|---------------|--------------|-----------|-------|-------|
| AttributeName | ✅ | ✅ Yes | - | 242-250 | ✅ | Unique name required |
| NumLevels | ✅ | ✅ Yes | - | 253-267 | ✅ | Must be ≥2 |
| LevelNames | ✅ | ✅ Yes | - | 103, 277-284 | ✅ | Comma-separated list |

---

## 3. CROSSTAB MODULE

### Settings Sheet - File Paths

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| structure_file | ✅ | ✅ Yes | - | 313 | ✅ | Survey structure file |
| output_subfolder | ✅ | ❌ Optional | Crosstabs | 279 | ✅ | Output directory |
| output_filename | ✅ | ❌ Optional | Crosstabs.xlsx | 280 | ✅ | Output file |
| output_format | ✅ | ❌ | - | - | ⚠️ | In template but NOT used by code |

### Settings Sheet - Weighting

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| apply_weighting | ✅ | ❌ Optional | FALSE | 231 | ✅ | Logical |
| weight_variable | ✅ | ❌ Optional | NULL | 232 | ✅ | Variable name |
| show_unweighted_n | ✅ | ❌ Optional | TRUE | 233 | ✅ | Logical |
| show_effective_n | ✅ | ❌ Optional | TRUE | 234 | ✅ | Logical |
| weight_label | ✅ | ❌ Optional | Weighted | 235 | ✅ | Label text |
| weight_na_threshold | ✅ | ❌ | - | - | ⚠️ | In template but NOT used by code |
| weight_zero_threshold | ✅ | ❌ | - | - | ⚠️ | In template but NOT used by code |
| weight_deff_warning | ✅ | ❌ | - | - | ⚠️ | In template but NOT used by code |

### Settings Sheet - Display

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| show_frequency | ✅ | ❌ Optional | TRUE | 239 | ✅ | Logical |
| show_percent_column | ✅ | ❌ Optional | TRUE | 240 | ✅ | Logical |
| show_percent_row | ✅ | ❌ Optional | FALSE | 241 | ✅ | Logical |
| decimal_separator | ✅ | ❌ Optional | . | 238 | ✅ | Character |
| decimal_places_percent | ✅ | ❌ Optional | 0 | 249 | ✅ | Numeric |
| decimal_places_ratings | ✅ | ❌ Optional | 1 | 250 | ✅ | Numeric |
| decimal_places_index | ✅ | ❌ Optional | 1 | 251 | ✅ | Numeric |
| decimal_places_numeric | ✅ | ❌ Optional | 1 | 252 | ✅ | Numeric |
| zero_division_as_blank | ✅ | ❌ Optional | TRUE | 276 | ✅ | Logical |

### Settings Sheet - BoxCategory

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| boxcategory_frequency | ✅ | ❌ Optional | FALSE | 244 | ✅ | Logical |
| boxcategory_percent_column | ✅ | ❌ Optional | TRUE | 245 | ✅ | Logical |
| boxcategory_percent_row | ✅ | ❌ Optional | FALSE | 246 | ✅ | Logical |

### Settings Sheet - Significance

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| enable_significance_testing | ✅ | ❌ Optional | TRUE | 255 | ✅ | Logical |
| alpha | ✅ | ❌ Optional | 0.05 | 256 | ✅ | 0-1 |
| significance_min_base | ✅ | ❌ Optional | 30 | 257 | ✅ | Numeric |
| bonferroni_correction | ✅ | ❌ Optional | TRUE | 258 | ✅ | Logical |
| enable_chi_square | ✅ | ❌ Optional | FALSE | 259 | ✅ | Logical |

### Settings Sheet - Ranking (NOT VALIDATED)

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| ranking_tie_threshold_pct | ✅ | ❌ | - | - | ⚠️ | In template but NOT validated by code |
| ranking_gap_threshold_pct | ✅ | ❌ | - | - | ⚠️ | In template but NOT validated by code |
| ranking_completeness_threshold_pct | ✅ | ❌ | - | - | ⚠️ | In template but NOT validated by code |
| ranking_min_base | ✅ | ❌ | - | - | ⚠️ | In template but NOT validated by code |

### Settings Sheet - Advanced

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| show_standard_deviation | ✅ | ❌ Optional | FALSE | 262 | ✅ | Logical |
| test_net_differences | ✅ | ❌ Optional | FALSE | 263 | ✅ | Logical |
| create_sample_composition | ✅ | ❌ Optional | FALSE | 264 | ✅ | Logical |
| show_net_positive | ✅ | ❌ Optional | FALSE | 265 | ✅ | Logical |
| show_numeric_median | ✅ | ❌ Optional | FALSE | 268 | ✅ | Logical |
| show_numeric_mode | ✅ | ❌ Optional | FALSE | 269 | ✅ | Logical |
| show_numeric_outliers | ✅ | ❌ Optional | TRUE | 270 | ✅ | Logical |
| exclude_outliers_from_stats | ✅ | ❌ Optional | FALSE | 271 | ✅ | Logical |
| outlier_method | ✅ | ❌ Optional | IQR | 272 | ✅ | IQR/zscore |

### Settings Sheet - Index Summary (NOT VALIDATED)

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| create_index_summary | ✅ | ❌ | - | - | ⚠️ | In template but NOT validated by code |
| index_summary_show_sections | ✅ | ❌ | - | - | ⚠️ | In template but NOT validated by code |
| index_summary_show_base_sizes | ✅ | ❌ | - | - | ⚠️ | In template but NOT validated by code |
| index_summary_show_composites | ✅ | ❌ | - | - | ⚠️ | In template but NOT validated by code |
| index_summary_decimal_places | ✅ | ❌ | - | - | ⚠️ | In template but NOT validated by code |

### Settings Sheet - System

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| enable_checkpointing | ✅ | ❌ Optional | TRUE | 275 | ✅ | Logical |

### Selection Sheet

| Column | Template | Code Required | Code Default | Code Line | Match | Notes |
|--------|----------|---------------|--------------|-----------|-------|-------|
| QuestionCode | ✅ | ✅ Yes | - | 401 | ✅ | Required |
| Include | ✅ | ❌ Optional | N | 412-413 | ✅ | Y/N |
| UseBanner | ✅ | ❌ Optional | N | 415-416 | ✅ | Y/N |
| BannerBoxCategory | ✅ | ❌ Optional | N | 418-419 | ✅ | Y/N |
| CreateIndex | ✅ | ❌ Optional | N | 421-422 | ✅ | Y/N |

---

## 4. KEYDRIVER MODULE

### Settings Sheet

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| analysis_name | ✅ | ❌ Optional | - | 25-26 | ✅ | Name |
| data_file | ✅ | ✅ Yes | - | 29-39 | ✅ | Required |
| output_file | ✅ | ✅ Yes | - | 30, 41-47 | ✅ | Required |

### Variables Sheet

| Column | Template | Code Required | Code Default | Code Line | Match | Notes |
|--------|----------|---------------|--------------|-----------|-------|-------|
| VariableName | ✅ | ✅ Yes | - | 53 | ✅ | Required |
| Type | ✅ | ✅ Yes | - | 53, 61-87 | ✅ | Outcome/Driver/Weight |
| Label | ✅ | ✅ Yes | - | 53 | ✅ | Required |

**Type Requirements:**
- Exactly 1 Outcome variable required (lines 64-72)
- At least 1 Driver variable required (lines 74-77)
- 0-1 Weight variable optional (lines 80-88)

---

## 5. PRICING MODULE

### Settings Sheet

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| project_name | ✅ | ❌ Optional | Pricing Analysis | 380 | ✅ | Project name |
| analysis_method | ✅ | ✅ Yes | - | 82-85, 149-154 | ✅ | van_westendorp/gabor_granger/both |
| currency_symbol | ✅ | ❌ Optional | $ | 381 | ✅ | Symbol |
| data_file | ✅ | ✅ Yes | - | 59-72 | ✅ | Required |
| id_var | ✅ | ❌ Optional | NA | 432-435 | ✅ | ID column |
| weight_var | ✅ | ❌ Optional | NA | 385-388 | ✅ | Weight column |
| dk_codes | ✅ | ❌ Optional | empty | 423-429 | ✅ | Comma-separated |
| unit_cost | ✅ | ❌ Optional | NA | 399-403 | ✅ | Numeric |
| vw_monotonicity_behavior | ✅ | ❌ Optional | flag_only | 406-412 | ✅ | drop/fix/flag_only |
| gg_monotonicity_behavior | ✅ | ❌ Optional | smooth | 414-420 | ✅ | diagnostic_only/smooth |
| segment_vars | ✅ | ❌ Optional | empty | 391-396 | ✅ | Comma-separated |
| output_file | ❌ | ❌ Optional | auto | 74-80 | ❌ | MISSING in template |
| verbose | ❌ | ❌ Optional | TRUE | 382 | ❌ | MISSING in template |

### VanWestendorp Sheet

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| col_too_cheap | ✅ | ✅ Yes | - | 250 | ✅ | Column name |
| col_cheap | ✅ | ✅ Yes | - | 251 | ✅ | Column name |
| col_expensive | ✅ | ✅ Yes | - | 252 | ✅ | Column name |
| col_too_expensive | ✅ | ✅ Yes | - | 253 | ✅ | Column name |
| validate_monotonicity | ✅ | ❌ Optional | TRUE | 256 | ✅ | Logical |
| violation_threshold | ✅ | ❌ Optional | 0.1 | 258 | ✅ | 0-1 |
| interpolation_method | ✅ | ❌ Optional | linear | 259 | ✅ | linear/spline |
| calculate_confidence | ✅ | ❌ Optional | FALSE | 260 | ✅ | Logical |
| confidence_level | ✅ | ❌ Optional | 0.95 | 261 | ✅ | 0-1 |
| bootstrap_iterations | ✅ | ❌ Optional | 1000 | 262 | ✅ | Numeric |
| exclude_violations | ❌ | ❌ Optional | FALSE | 257 | ❌ | MISSING in template |
| price_decimals | ❌ | ❌ Optional | 2 | 263 | ❌ | MISSING in template |

### GaborGranger Sheet

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| data_format | ✅ | ❌ Optional | wide | 278 | ✅ | wide/long |
| price_sequence | ✅ | ⚠️ Conditional | - | 211-212, 281-283 | ✅ | Semicolon-separated (wide format) |
| response_columns | ✅ | ⚠️ Conditional | - | 215-217, 284-286 | ✅ | Semicolon-separated (wide format) |
| response_coding | ✅ | ❌ | - | - | 🔄 | NAME MISMATCH - Code uses "response_type" |
| revenue_optimization | ✅ | ❌ Optional | TRUE | 300 | ✅ | Logical |
| price_column | ✅ | ⚠️ Conditional | - | 289 | ✅ | Column name (long format) |
| response_column | ✅ | ⚠️ Conditional | - | 290 | ✅ | Column name (long format) |
| respondent_column | ✅ | ⚠️ Conditional | - | 291 | ✅ | Column name (long format) |
| scale_threshold | ✅ | ❌ Optional | 3 | 295 | ✅ | Numeric |
| check_monotonicity | ✅ | ❌ Optional | TRUE | 298 | ✅ | Logical |
| calculate_elasticity | ✅ | ❌ Optional | TRUE | 299 | ✅ | Logical |
| confidence_intervals | ✅ | ❌ Optional | FALSE | 301 | ✅ | Logical |
| bootstrap_iterations | ✅ | ❌ Optional | 1000 | 302 | ✅ | Numeric |
| confidence_level | ✅ | ❌ Optional | 0.95 | 303 | ✅ | 0-1 |
| response_type | ❌ | ❌ Optional | binary | 294 | ❌ | MISSING - template has "response_coding" instead |
| run_simulation | ❌ | ❌ Optional | FALSE | 306 | ❌ | MISSING in template |
| market_size | ❌ | ❌ Optional | 10000 | 307 | ❌ | MISSING in template |

### Bootstrap Sheet (NOT LOADED)

**Status:** Sheet exists in template but code doesn't load it separately. Bootstrap settings are in VW and GG sheets.

### Validation Sheet

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| min_completeness | ✅ | ❌ Optional | 0.8 | 342 | ✅ | 0-1 |
| check_ranges | ✅ | ❌ | - | - | ⚠️ | Implied by min/max |
| min_price | ✅ | ❌ Optional | 0 | 343 | ✅ | Numeric (as price_min in code) |
| max_price | ✅ | ❌ Optional | 10000 | 344 | ✅ | Numeric (as price_max in code) |
| flag_outliers | ✅ | ❌ Optional | TRUE | 345 | ✅ | Logical |
| outlier_method | ✅ | ❌ Optional | iqr | 346 | ✅ | iqr/zscore/percentile |
| outlier_threshold | ✅ | ❌ Optional | 3 | 347 | ✅ | Numeric |

### Output Sheet (NOT LOADED)

**Status:** Sheet exists in template but code doesn't load it separately.

---

## 6. SEGMENT MODULE

### Config Sheet

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| data_file | ✅ | ✅ Yes | - | 156 | ✅ | File path |
| data_sheet | ✅ | ❌ Optional | Data | 184 | ✅ | Sheet name |
| id_variable | ✅ | ✅ Yes | - | 157 | ✅ | ID column |
| clustering_vars | ✅ | ✅ Yes | - | 160-177 | ✅ | Comma/semicolon-separated, min 2, max 20 |
| profile_vars | ✅ | ❌ Optional | NULL | 187-198 | ✅ | Comma/semicolon-separated |
| method | ✅ | ❌ Optional | kmeans | 201-202 | ✅ | Currently only kmeans |
| k_fixed | ✅ | ❌ Optional | NULL | 204-231 | ✅ | If set, must be ≥2 |
| k_min | ✅ | ❌ Optional | 3 | 211 | ✅ | Range 2-10 |
| k_max | ✅ | ❌ Optional | 6 | 212 | ✅ | Range 2-15 |
| nstart | ✅ | ❌ Optional | 50 | 213 | ✅ | Range 1-200 |
| seed | ✅ | ❌ Optional | 123 | 214 | ✅ | Min 1 |
| missing_data | ✅ | ❌ Optional | listwise_deletion | 234-239 | ✅ | listwise_deletion/mean_imputation/median_imputation/refuse |
| missing_threshold | ✅ | ❌ Optional | 15 | 241-242 | ✅ | Range 0-100 |
| standardize | ✅ | ❌ Optional | TRUE | 244 | ✅ | Logical |
| min_segment_size_pct | ✅ | ❌ Optional | 10 | 246-247 | ✅ | Range 0-50 |
| outlier_detection | ✅ | ❌ Optional | FALSE | 250-251 | ✅ | Logical |
| outlier_method | ✅ | ❌ Optional | zscore | 253-255 | ✅ | zscore/mahalanobis |
| outlier_threshold | ✅ | ❌ Optional | 3.0 | 257-258 | ✅ | Range 1.0-5.0 |
| outlier_min_vars | ✅ | ❌ Optional | 1 | 260-261 | ✅ | Min 1 |
| outlier_handling | ✅ | ❌ Optional | flag | 263-265 | ✅ | none/flag/remove |
| outlier_alpha | ✅ | ❌ Optional | 0.001 | 267-268 | ✅ | Range 0.0001-0.1 |
| variable_selection | ✅ | ❌ Optional | FALSE | 279-280 | ✅ | Logical |
| variable_selection_method | ✅ | ❌ Optional | variance_correlation | 282-286 | ✅ | variance_correlation/factor_analysis/both |
| max_clustering_vars | ✅ | ❌ Optional | 10 | 288-289 | ✅ | Range 2-20 |
| varsel_min_variance | ✅ | ❌ Optional | 0.1 | 291-292 | ✅ | Range 0.01-1.0 |
| varsel_max_correlation | ✅ | ❌ Optional | 0.8 | 294-295 | ✅ | Range 0.5-0.95 |
| k_selection_metrics | ✅ | ❌ Optional | silhouette,elbow | 308-319 | ✅ | Comma-separated: silhouette/elbow/gap |
| output_folder | ✅ | ❌ Optional | output/ | 322 | ✅ | Folder path |
| output_prefix | ✅ | ❌ Optional | seg_ | 323 | ✅ | Prefix |
| create_dated_folder | ✅ | ❌ Optional | TRUE | 324-325 | ✅ | Logical |
| segment_names | ✅ | ❌ Optional | auto | 327-343 | ✅ | auto or comma-separated |
| save_model | ✅ | ❌ Optional | TRUE | 345 | ✅ | Logical |
| project_name | ✅ | ❌ Optional | Segmentation Analysis | 348-349 | ✅ | Name |
| analyst_name | ✅ | ❌ Optional | Analyst | 350-351 | ✅ | Name |
| description | ✅ | ❌ Optional | empty | 352-353 | ✅ | Text |
| question_labels_file | ✅ | ❌ Optional | NULL | 355-363 | ✅ | File path |

**Perfect Alignment:** All 36 parameters match! ✅

---

## 7. SURVEY_STRUCTURE MODULE

### Project Sheet

| Parameter | Template | Code Required | Code Default | Code Line | Match | Notes |
|-----------|----------|---------------|--------------|-----------|-------|-------|
| project_name | ✅ | ❌ | - | - | ⚠️ | In template but not validated |
| project_code | ✅ | ❌ | - | - | ⚠️ | In template but not validated |
| client_name | ✅ | ❌ | - | - | ⚠️ | In template but not validated |
| study_type | ✅ | ❌ | - | - | ⚠️ | In template but not validated |
| study_date | ✅ | ❌ | - | - | ⚠️ | In template but not validated |
| data_file | ✅ | ✅ Yes | - | 322-329 | ✅ | Read from Project sheet |
| output_folder | ✅ | ❌ | - | - | ⚠️ | Implied usage |
| total_sample | ✅ | ❌ | - | - | ⚠️ | In template but not validated |
| contact_person | ✅ | ❌ | - | - | ⚠️ | In template but not validated |
| notes | ✅ | ❌ | - | - | ⚠️ | In template but not validated |
| weight_column_exists | ✅ | ❌ | - | - | ⚠️ | In template but not validated |
| weight_columns | ✅ | ❌ | - | - | ⚠️ | In template but not validated |
| default_weight | ✅ | ❌ | - | - | ⚠️ | In template but not validated |
| weight_description | ✅ | ❌ | - | - | ⚠️ | In template but not validated |

### Questions Sheet

**Columns:** QuestionCode, QuestionText, Variable_Type, Columns, Ranking_Format, Ranking_Positions, Ranking_Direction, Category, Notes, Min_Value, Max_Value

**Status:** Loaded by tabs processing, not validated in config_loader.R

### Options Sheet

**Columns:** QuestionCode, OptionText, DisplayText, DisplayOrder, ShowInOutput, ExcludeFromIndex, Index_Weight, BoxCategory, Min, Max

**Status:** Loaded by tabs processing, not validated in config_loader.R

### Composite_Metrics Sheet

**Status:** Sheet exists in template but not referenced in config_loader.R

---

## 8. TRACKER MODULE

### Waves Sheet

| Column | Template | Code Required | Code Default | Code Line | Match | Notes |
|--------|----------|---------------|--------------|-----------|-------|-------|
| WaveID | ✅ | ✅ Yes | - | 57-61, 250-252 | ✅ | Must be unique |
| WaveName | ✅ | ✅ Yes | - | 57 | ✅ | Wave name |
| DataFile | ✅ | ✅ Yes | - | 57 | ✅ | File path |
| FieldworkStart | ✅ | ✅ Yes | - | 57 | ✅ | Date |
| FieldworkEnd | ✅ | ✅ Yes | - | 57 | ✅ | Date, must be ≥ FieldworkStart |

### Settings Sheet

**Structure:** Setting, Value columns converted to named list (lines 63-74, 196-232)

**Required Settings (per validation):**
- project_name (line 286)
- decimal_places_ratings (line 286)
- show_significance (line 286)

**Status:** Template doesn't document which settings are required vs optional

### TrackedQuestions Sheet

| Column | Template | Code Required | Code Default | Code Line | Match | Notes |
|--------|----------|---------------|--------------|-----------|-------|-------|
| QuestionCode | ✅ | ✅ Yes | - | 98-100 | ✅ | Required |
| QuestionText | ✅ | ❌ | - | - | ⚠️ | In template, not validated (documentation) |
| Tracking detail | ✅ | ❌ | - | - | ⚠️ | In template, not validated (documentation) |

### Banner Sheet

| Column | Template | Code Required | Code Default | Code Line | Match | Notes |
|--------|----------|---------------|--------------|-----------|-------|-------|
| BreakVariable | ✅ | ✅ Yes | - | 84 | ✅ | Required |
| BreakLabel | ✅ | ✅ Yes | - | 84 | ✅ | Required |

**Validation:** Code checks for "Total" in banner (lines 301-304)

---

## 9. TRACKER_MAPPING MODULE

### QuestionMap Sheet

| Column | Template | Code Required | Code Default | Code Line | Match | Notes |
|--------|----------|---------------|--------------|-----------|-------|-------|
| Column | ✅ | ❌ | - | - | ⚠️ | Metadata, excluded from wave detection |
| QuestionCode | ✅ | ✅ Yes | - | 149 | ✅ | Required |
| QuestionText | ✅ | ✅ Yes | - | 149 | ✅ | Required |
| QuestionType | ✅ | ✅ Yes | - | 149 | ✅ | Required |
| TrackingSpecs | ✅ | ❌ | - | 158 | ⚠️ | Metadata, excluded from wave detection |
| Wave 1 | ✅ | ⚠️ Dynamic | - | 156-173 | ✅ | Wave columns detected dynamically |
| Wave 2 | ✅ | ⚠️ Dynamic | - | 156-173 | ✅ | Wave columns detected dynamically |
| SourceQuestions | ✅ | ❌ | - | 158 | ⚠️ | Metadata, excluded from wave detection |

**Note:** Code dynamically detects wave columns (W1, W2, Wave1, Wave2, etc.) by filtering non-metadata columns with >50% non-empty values

---

## Legend

- ✅ = Matches perfectly
- ❌ = Missing or not present
- ⚠️ = Present but not validated/used
- 🔄 = Name mismatch or inconsistency
- ⚠️ Conditional = Required only under certain conditions

**Report Date:** 2025-12-03
**Total Parameters Analyzed:** 200+
