# Template Validation - Action Checklist
## Prioritized Actions to Fix Template-Code Misalignments

**Date:** 2025-12-03
**Status:** DRAFT - Awaiting Review

---

## 🔴 CRITICAL - Fix Immediately (Breaking Issues)

### 1. PRICING: Fix Name Mismatch in GaborGranger Sheet
**Priority:** URGENT
**Impact:** Will cause errors if users try to use GaborGranger analysis
**Effort:** 2 minutes

**Action:**
- [ ] Open `Pricing_Config_Template_Annotated_Final.xlsx`
- [ ] Go to "GaborGranger" sheet
- [ ] Find row with parameter "response_coding"
- [ ] Change "response_coding" to "response_type"
- [ ] Update description to match: "binary, scale, or auto"
- [ ] Save file

**Verification:**
- [ ] Confirm parameter name is "response_type"
- [ ] Code expects this at line 294 in `/home/user/Turas/modules/pricing/R/01_config.R`

---

### 2. CONJOINT: Add Critical Missing Parameters for None-Option Handling
**Priority:** URGENT
**Impact:** Users cannot configure none-option behavior in choice_type='single_with_none'
**Effort:** 15 minutes

**Action:**
- [ ] Open `Conjoint_Config_Template_Annotated_Final.xlsx`
- [ ] Go to "Settings" sheet
- [ ] Add these rows after existing parameters:

| Setting | Value | Required | Default |
|---------|-------|----------|---------|
| none_as_baseline | FALSE | No | FALSE |
| none_label | None | No | None |
| alternative_id_column | alternative_id | No | alternative_id |
| rating_variable | rating | No | rating |

**Verification:**
- [ ] Code expects these at lines 179-180, 197-198 in `/home/user/Turas/modules/conjoint/R/01_config.R`

---

### 3. CONFIDENCE: Add Population_Margins Sheet
**Priority:** HIGH
**Impact:** Users cannot specify population targets for representativeness checking
**Effort:** 20 minutes

**Action:**
- [ ] Open `Confidence_Config_Template_Annotated_Final.xlsx`
- [ ] Add new sheet named "Population_Margins"
- [ ] Add header row with columns:

| Variable | Category_Label | Category_Code | Target_Prop | Include |
|----------|----------------|---------------|-------------|---------|
| Gender | Male | 1 | 0.48 | Y |
| Gender | Female | 2 | 0.52 | Y |
| Age_Group | 18-34 | 1 | 0.30 | Y |
| Age_Group | 35-54 | 2 | 0.35 | Y |
| Age_Group | 55+ | 3 | 0.35 | Y |

- [ ] Add instruction note: "OPTIONAL: This sheet enables population margin comparison. If not needed, you can leave empty or delete."
- [ ] Format as table with header styling
- [ ] Save file

**Verification:**
- [ ] Code loads this optional sheet at lines 567-695 in `/home/user/Turas/modules/confidence/R/01_load_config.R`
- [ ] Required columns: Variable, Category_Label, Target_Prop
- [ ] Optional columns: Category_Code, Include

---

## 🟡 HIGH PRIORITY - Fix Soon (Functional Gaps)

### 4. CONJOINT: Add Remaining Missing Parameters
**Priority:** HIGH
**Impact:** Users stuck with defaults, cannot customize important settings
**Effort:** 10 minutes

**Action:**
- [ ] Open `Conjoint_Config_Template_Annotated_Final.xlsx`
- [ ] Go to "Settings" sheet
- [ ] Add these additional rows:

| Setting | Value | Required | Default |
|---------|-------|----------|---------|
| include_diagnostics | TRUE | No | TRUE |
| bootstrap_iterations | 1000 | No | 1000 |
| min_responses_per_level | 10 | No | 10 |

**Verification:**
- [ ] Code expects these at lines 187-194 in `/home/user/Turas/modules/conjoint/R/01_config.R`

---

### 5. CONFIDENCE: Add random_seed Parameter
**Priority:** HIGH
**Impact:** Users cannot set random seed for reproducible results
**Effort:** 5 minutes

**Action:**
- [ ] Open `Confidence_Config_Template_Annotated_Final.xlsx`
- [ ] Go to "Study_Settings" sheet
- [ ] Add row after Decimal_Separator:

| Setting | Value | Notes |
|---------|-------|-------|
| random_seed | 123 | Optional: Set random seed for reproducible bootstrap results. Leave empty to use random seed. |

**Verification:**
- [ ] Code checks for this optional parameter at lines 437-446 in `/home/user/Turas/modules/confidence/R/01_load_config.R`

---

### 6. PRICING: Add Missing VanWestendorp Parameters
**Priority:** HIGH
**Impact:** Users cannot configure violation handling and price display precision
**Effort:** 5 minutes

**Action:**
- [ ] Open `Pricing_Config_Template_Annotated_Final.xlsx`
- [ ] Go to "VanWestendorp" sheet
- [ ] Add these rows:

| Setting | Value | Required | Description |
|---------|-------|----------|-------------|
| exclude_violations | FALSE | No | Remove respondents with price sequence violations |
| price_decimals | 2 | No | Number of decimal places for price display |

**Verification:**
- [ ] Code expects these at lines 257, 263 in `/home/user/Turas/modules/pricing/R/01_config.R`

---

### 7. PRICING: Add Missing Settings Sheet Parameters
**Priority:** HIGH
**Impact:** Users cannot specify output file or control verbosity
**Effort:** 5 minutes

**Action:**
- [ ] Open `Pricing_Config_Template_Annotated_Final.xlsx`
- [ ] Go to "Settings" sheet
- [ ] Add these rows:

| Setting | Value | Description |
|---------|-------|-------------|
| output_file | pricing_results.xlsx | Path for output file (relative to config or absolute) |
| verbose | TRUE | Show progress messages during analysis |

**Verification:**
- [ ] Code resolves output_file at lines 74-80
- [ ] Code uses verbose at line 382

---

### 8. PRICING: Remove or Implement Orphaned Sheets
**Priority:** HIGH
**Impact:** Confusing for users - sheets exist but aren't loaded
**Effort:** 10 minutes (decision + implementation)

**Decision Required:** Choose one:

**Option A: Remove Sheets**
- [ ] Open `Pricing_Config_Template_Annotated_Final.xlsx`
- [ ] Delete "Bootstrap" sheet (settings are in VW and GG sheets)
- [ ] Delete "Output" sheet (settings are in main Settings sheet)
- [ ] Save file

**Option B: Implement Loaders in Code**
- [ ] Modify `/home/user/Turas/modules/pricing/R/01_config.R`
- [ ] Add `load_bootstrap_config()` function
- [ ] Add `load_output_config()` function
- [ ] Integrate into main config loading
- [ ] Test thoroughly

**Recommendation:** Option A (remove sheets) - simpler and cleaner

---

## 🟢 MEDIUM PRIORITY - Fix When Possible (Cleanup)

### 9. CROSSTAB: Remove Unvalidated Parameters
**Priority:** MEDIUM
**Impact:** Users waste time configuring non-functional parameters
**Effort:** 20 minutes

**Action:**
- [ ] Open `Crosstab_Config_Template_Annotated_Final.xlsx`
- [ ] Go to "Settings" sheet
- [ ] Remove or clearly mark as "NOT YET IMPLEMENTED" these parameters:

**Weighting Parameters:**
- [ ] output_format (not used by code)
- [ ] weight_na_threshold (not validated)
- [ ] weight_zero_threshold (not validated)
- [ ] weight_deff_warning (not validated)

**Ranking Parameters:**
- [ ] ranking_tie_threshold_pct (not validated)
- [ ] ranking_gap_threshold_pct (not validated)
- [ ] ranking_completeness_threshold_pct (not validated)
- [ ] ranking_min_base (not validated)

**Index Summary Parameters:**
- [ ] create_index_summary (not validated)
- [ ] index_summary_show_sections (not validated)
- [ ] index_summary_show_base_sizes (not validated)
- [ ] index_summary_show_composites (not validated)
- [ ] index_summary_decimal_places (not validated)

**Alternative:** Add comments to these parameters: "⚠️ FUTURE FEATURE - Not yet implemented in code"

**Verification:**
- [ ] Confirm these are not validated in `/home/user/Turas/modules/tabs/lib/config_loader.R`

---

### 10. CONFIDENCE: Remove/Clarify Weight_Variable in File_Paths
**Priority:** MEDIUM
**Impact:** Unclear if this parameter is functional
**Effort:** 5 minutes

**Action:**
- [ ] Open `Confidence_Config_Template_Annotated_Final.xlsx`
- [ ] Go to "File_Paths" sheet
- [ ] Either:
  - **Option A:** Remove "Weight_Variable" row (not required by code)
  - **Option B:** Add note: "Optional - specify if using weights (not validated by config loader)"

**Verification:**
- [ ] Code doesn't require this in File_Paths sheet (lines 162-178)

---

### 11. KEYDRIVER: Document Available Settings
**Priority:** MEDIUM
**Impact:** Users don't know what settings are supported beyond the 3 shown
**Effort:** 15 minutes

**Action:**
- [ ] Open `KeyDriver_Config_Template_Annotated_Final.xlsx`
- [ ] Go to "Instructions" or add new section to Settings sheet
- [ ] Add documentation of all available settings:
  - data_file (required)
  - output_file (required)
  - analysis_name (optional)
  - [Any other settings extracted by code at lines 25-26]

**Note:** Code extracts ALL settings from Settings sheet, so template should document what's available

**Verification:**
- [ ] Check code to see what settings are actually used beyond data_file and output_file

---

### 12. SURVEY_STRUCTURE: Clarify Metadata vs Functional Parameters
**Priority:** MEDIUM
**Impact:** Users uncertain about which Project sheet parameters are required
**Effort:** 10 minutes

**Action:**
- [ ] Open `Survey_Structure_Template_Annotated_Final.xlsx`
- [ ] Go to "Project" sheet
- [ ] Add "Required" column
- [ ] Mark parameters:
  - data_file: ✅ Required
  - All others: ❌ Optional (Metadata)
- [ ] Add note: "Most Project parameters are for documentation/metadata. Only data_file is functionally used by code."

**Verification:**
- [ ] Code only reads data_file from Project sheet (lines 322-329 in config_loader.R)

---

### 13. SURVEY_STRUCTURE: Verify Composite_Metrics Usage
**Priority:** MEDIUM
**Impact:** Sheet may be unused and confusing
**Effort:** 30 minutes (investigation + decision)

**Action:**
- [ ] Search codebase for references to "Composite_Metrics"
- [ ] If used: Document its purpose in Instructions
- [ ] If NOT used: Delete sheet from template
- [ ] Save file

**Investigation Needed:**
- [ ] Check if used in tabs processing beyond config_loader.R

---

### 14. TRACKER: Document Required Settings
**Priority:** MEDIUM
**Impact:** Users don't know which settings are required vs optional
**Effort:** 15 minutes

**Action:**
- [ ] Open `Tracker_Config_Template_Annotated_Final.xlsx`
- [ ] Go to "Settings" sheet
- [ ] Add "Required" column
- [ ] Mark these as required (per code validation at lines 286-293):
  - project_name: ✅ Required
  - decimal_places_ratings: ✅ Required
  - show_significance: ✅ Required
- [ ] Add example values for other common optional settings

**Verification:**
- [ ] Code validates these required settings at lines 286-293 in tracker_config_loader.R

---

### 15. PRICING: Add Missing GaborGranger Parameters
**Priority:** MEDIUM
**Impact:** Users cannot configure simulation and market size
**Effort:** 5 minutes

**Action:**
- [ ] Open `Pricing_Config_Template_Annotated_Final.xlsx`
- [ ] Go to "GaborGranger" sheet
- [ ] Add these rows:

| Setting | Value | Required | Description |
|---------|-------|----------|-------------|
| run_simulation | FALSE | No | Run market simulation |
| market_size | 10000 | No | Market size for simulation |

**Note:** unit_cost might already be in main Settings, verify if needed here too

**Verification:**
- [ ] Code expects these at lines 306-308 in `/home/user/Turas/modules/pricing/R/01_config.R`

---

## 🎯 PROCESS IMPROVEMENTS

### 16. Add Template Version Tracking
**Priority:** LOW
**Impact:** Better change management
**Effort:** 5 minutes per template

**Action:** For EACH template:
- [ ] Add "Template_Version" to first configuration sheet
- [ ] Set initial version: 1.0.0
- [ ] Add "Last_Updated" field
- [ ] Document version changes

**Templates to Update:**
- [ ] Confidence_Config_Template_Annotated_Final.xlsx
- [ ] Conjoint_Config_Template_Annotated_Final.xlsx
- [ ] Crosstab_Config_Template_Annotated_Final.xlsx
- [ ] KeyDriver_Config_Template_Annotated_Final.xlsx
- [ ] Pricing_Config_Template_Annotated_Final.xlsx
- [ ] Segment_Config_Template_Annotated_Final.xlsx
- [ ] Survey_Structure_Template_Annotated_Final.xlsx
- [ ] Tracker_Config_Template_Annotated_Final.xlsx
- [ ] Tracker_Question_Mapping_Template_Annotated_Final.xlsx

---

### 17. Create Automated Validation Tests
**Priority:** LOW
**Impact:** Prevent future misalignments
**Effort:** 4 hours

**Action:**
- [ ] Create R script: `tests/test_template_alignment.R`
- [ ] For each module, extract:
  - Parameters from template (using readxl)
  - Parameters validated by code (using code analysis)
- [ ] Compare and report differences
- [ ] Run as part of CI/CD or periodic check

**Pseudocode:**
```r
test_confidence_alignment <- function() {
  template_params <- extract_template_params("Confidence_Config_Template_Annotated_Final.xlsx")
  code_params <- extract_code_params("modules/confidence/R/01_load_config.R")
  expect_equal(template_params$Study_Settings, code_params$study_settings)
}
```

---

### 18. Update Documentation
**Priority:** LOW
**Impact:** Better user understanding
**Effort:** 2 hours

**Action:**
- [ ] Update each template's Instructions sheet with:
  - Which sheets are required vs optional
  - Which parameters are required vs optional
  - Default values for all optional parameters
  - Version history
- [ ] Create master documentation: `templates/Final/README.md`
- [ ] Link to validation reports

---

## COMPLETION CHECKLIST

### Critical Items (Must Do)
- [ ] 1. Pricing: Fix name mismatch (response_coding → response_type)
- [ ] 2. Conjoint: Add none-handling parameters
- [ ] 3. Confidence: Add Population_Margins sheet

### High Priority Items (Should Do Soon)
- [ ] 4. Conjoint: Add remaining missing parameters
- [ ] 5. Confidence: Add random_seed parameter
- [ ] 6. Pricing: Add missing VanWestendorp parameters
- [ ] 7. Pricing: Add missing Settings parameters
- [ ] 8. Pricing: Remove Bootstrap and Output sheets

### Medium Priority Items (Do When Possible)
- [ ] 9. Crosstab: Remove unvalidated parameters
- [ ] 10. Confidence: Remove/clarify Weight_Variable
- [ ] 11. KeyDriver: Document available settings
- [ ] 12. Survey_Structure: Clarify metadata parameters
- [ ] 13. Survey_Structure: Verify Composite_Metrics usage
- [ ] 14. Tracker: Document required settings
- [ ] 15. Pricing: Add missing GaborGranger parameters

### Process Improvements (Nice to Have)
- [ ] 16. Add template version tracking
- [ ] 17. Create automated validation tests
- [ ] 18. Update documentation

---

## ESTIMATED EFFORT

| Priority | Items | Total Effort | Timeline |
|----------|-------|--------------|----------|
| Critical | 3 | ~40 minutes | Today |
| High | 5 | ~50 minutes | This Week |
| Medium | 7 | ~2 hours | This Month |
| Process | 3 | ~7 hours | Ongoing |
| **TOTAL** | **18** | **~10 hours** | - |

---

## TESTING CHECKLIST

After making changes, test each template:

- [ ] **Confidence:** Load config, verify Population_Margins loaded
- [ ] **Conjoint:** Load config with none_as_baseline=TRUE, verify works
- [ ] **Crosstab:** Load config, verify no errors from removed params
- [ ] **KeyDriver:** Load config, verify all settings parsed
- [ ] **Pricing:** Load config with response_type, verify GG works
- [ ] **Segment:** No changes needed (already perfect)
- [ ] **Survey_Structure:** Load structure, verify data_file loaded
- [ ] **Tracker:** Load config, verify required settings validated
- [ ] **Tracker_Mapping:** Load mapping, verify waves detected

---

## NOTES

- **Segment module** requires NO changes - perfect alignment already! 🎯
- **Tracker and Tracker_Mapping** are in good shape, just documentation needed
- **Focus effort on Confidence, Conjoint, and Pricing** - these have the most critical issues

---

**Checklist Created:** 2025-12-03
**Total Action Items:** 18
**Critical Items:** 3
**Estimated Completion:** 1-2 weeks for all items
