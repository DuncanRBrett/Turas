# TurasTracker Development Briefing
## Minimum Viable Tracker for Multi-Wave Analysis

**Version:** 1.0  
**Date:** 2025-11-06  
**Project Owner:** Duncan Brett  
**Purpose:** Strategic briefing for building TurasTracker MVT  
**Development Target:** Claude Code  

---

## EXECUTIVE SUMMARY

### Project Context

TurasTabs successfully handles **within-wave analysis** - analyzing a single survey wave with crosstabulation, significance testing, and reporting. TurasTracker will handle **across-wave analysis** - tracking how survey results change over time across multiple waves.

### Strategic Approach

**Build Minimum Viable Tracker First, Then Enhance**

Rather than building a full-featured tracking system immediately, we will:
1. Build a lean, functional MVT with core features only
2. Test the architecture and patterns with real data
3. Validate the question mapping approach
4. Prove the shared code strategy works
5. Then add advanced features iteratively

This approach:
- ✅ Delivers value faster (basic tracking works in 3-4 weeks)
- ✅ Validates technical decisions before major investment
- ✅ Allows user feedback to shape advanced features
- ✅ Reduces risk of over-engineering unused features

### Architectural Principle

```
┌─────────────────────────────────────────────────┐
│              SHARED CORE                        │
│  (weights, significance tests, calculations)    │
└──────────────┬──────────────────┬───────────────┘
               │                  │
       ┌───────▼────────┐  ┌─────▼──────────┐
       │  TurasTabs     │  │ TurasTracker   │
       │  (within-wave) │  │ (across-wave)  │
       └────────────────┘  └────────────────┘
```

**Key Principle:** TurasTabs and TurasTracker are separate modules that share a common calculation engine. This prevents code duplication and ensures consistent results.

---

## 1. MINIMUM VIABLE TRACKER (MVT) FEATURES

### What's IN the MVT

**✅ Core Features:**
1. Load multiple wave data files (CSV/Excel)
2. Map questions across waves using `question_mapping.xlsx`
3. Handle question renumbering (Q10 → Q11 between waves)
4. Generate time series tables (questions as rows, waves as columns)
5. Calculate wave-over-wave changes (absolute and percentage)
6. Basic significance testing (z-test for proportions, t-test for means)
7. Track composite scores across waves
8. Support total sample and banner breakouts (e.g., by Region)
9. Excel output with formatted trend tables

**✅ Supported Question Types:**
- Single choice (proportions)
- Rating questions (means)
- Likert questions (index scores)
- Composite scores (from TurasTabs logic)
- NPS scores

**✅ Output Format:**
- Excel workbook with multiple sheets:
  - Summary (metadata)
  - Trend Tables (one per question or banner segment)
  - Change Summary (all questions, change from baseline)
  - Metadata (config snapshot, wave info)

### What's OUT of the MVT (Future Enhancements)

**⛔ NOT in Version 1.0:**
- Panel data tracking (same respondents over time)
- Attrition analysis
- Individual trajectory analysis
- Effect size calculations (Cohen's d, etc.)
- Trend slope analysis
- Statistical forecasting
- Automated base drift warnings
- CSV/JSON exports for dashboards
- Visualization/charting
- Multi-mention question tracking

**Rationale:** These are valuable features, but not essential for basic tracking. Build them after validating the core architecture.

---

## 2. ARCHITECTURAL DESIGN

### 2.1 Module Structure

```
/TurasTracker/                      # New module directory
├── run_tracker.R                   # Main entry point
├── tracker_config_loader.R         # Load tracking configuration
├── wave_loader.R                   # Load and validate wave data
├── question_mapper.R               # Map questions across waves
├── trend_calculator.R              # Calculate trends and changes
├── tracker_output.R                # Excel output writer
└── validation_tracker.R            # Validation specific to tracking

/shared/                            # Shared with TurasTabs
├── weights.R                       # Weight calculation (reused)
├── significance_tests.R            # Sig testing (reused)
├── composite_calculator.R          # Composite logic (reused)
├── formatting.R                    # Number formatting (reused)
└── excel_styles.R                  # Excel styling (reused)
```

### 2.2 Shared Code Strategy

**Code to Share:**
- Weight calculations (effective-n, design effect)
- Significance testing (z-test, t-test)
- Composite score calculation
- Number formatting functions
- Excel styling functions

**Why Share?**
- Ensures consistent results between Tabs and Tracker
- Reduces maintenance burden (fix bugs once)
- Faster development (don't rewrite existing logic)

**How to Share:**
Move shared functions to `/shared/` directory and have both modules `source()` them.

### 2.3 Data Flow

```
1. Configuration Phase
   ├─ Load tracking_config.xlsx (wave files, settings)
   ├─ Load question_mapping.xlsx (cross-wave mapping)
   └─ Validate all files exist and are readable

2. Data Loading Phase
   ├─ For each wave:
   │  ├─ Load wave data file
   │  ├─ Validate structure
   │  ├─ Apply weights (if configured)
   │  └─ Calculate base statistics
   └─ Store in wave_data list

3. Question Mapping Phase
   ├─ For each tracked question:
   │  ├─ Find matching question in each wave
   │  ├─ Validate question compatibility
   │  └─ Create unified question metadata
   └─ Flag unmapped questions

4. Trend Calculation Phase
   ├─ For each tracked question:
   │  ├─ Calculate metric for each wave (%, mean, index)
   │  ├─ Calculate wave-over-wave changes
   │  ├─ Run significance tests
   │  └─ Format results
   └─ For each banner segment: repeat above

5. Output Phase
   ├─ Create Excel workbook
   ├─ Write summary sheet
   ├─ Write trend tables (one per question/segment)
   ├─ Write change summary
   ├─ Write metadata
   └─ Save output file
```

---

## 3. CONFIGURATION FILES

### 3.1 tracking_config.xlsx

**Purpose:** Define waves, settings, and analysis specifications

#### Sheet 1: Waves

| Column | Type | Required | Example | Description |
|--------|------|----------|---------|-------------|
| WaveID | Text | Yes | W1 | Unique wave identifier |
| WaveLabel | Text | Yes | Wave 1 (Jan 2024) | Display label |
| WaveDate | Date | No | 2024-01-15 | Survey date for ordering |
| DataFile | Text | Yes | Data/wave1.csv | Path to data file |
| IsBaseline | Text | No | Y | Y if baseline wave for change calcs |
| WeightVariable | Text | No | Weight | Column name for weights (if different per wave) |

**Example:**
```
WaveID | WaveLabel          | WaveDate   | DataFile           | IsBaseline
W1     | Wave 1 (Jan 2024) | 2024-01-15 | Data/wave1.csv     | Y
W2     | Wave 2 (Apr 2024) | 2024-04-15 | Data/wave2.csv     | 
W3     | Wave 3 (Jul 2024) | 2024-07-15 | Data/wave3.csv     |
```

#### Sheet 2: Settings

| Setting | Value | Options | Description |
|---------|-------|---------|-------------|
| output_file | Tracker_Results.xlsx | Path | Output filename |
| output_folder | Output/Tracking/ | Path | Output directory |
| baseline_wave | W1 | WaveID | Which wave is baseline |
| show_changes | Y | Y/N | Show change columns |
| show_percentage_change | Y | Y/N | Show % change |
| show_significance | Y | Y/N | Show sig testing |
| alpha | 0.05 | Numeric | Significance level |
| minimum_base | 30 | Numeric | Min sample for testing |
| decimal_places_percent | 0 | 0-3 | Decimals for % |
| decimal_places_mean | 1 | 0-3 | Decimals for means |
| apply_weighting | Y | Y/N | Use weights |

#### Sheet 3: Banner

Same structure as TurasTabs Banner configuration:

| QuestionCode | Label | Filter | ShowInOutput |
|--------------|-------|--------|--------------|
| TOTAL | Total | | Y |
| Region | | | Y |
| Age_Group | | | Y |

**Note:** Banner is applied separately within each wave. The tracker shows trends for each banner segment.

#### Sheet 4: TrackedQuestions

Define which questions to track:

| Column | Required | Example | Description |
|--------|----------|---------|-------------|
| TrackingCode | Yes | TRK_NPS | Unique tracking identifier |
| TrackingLabel | Yes | Net Promoter Score | Display label |
| QuestionType | Yes | NPS | Rating/Likert/NPS/SingleChoice/Composite |
| ShowInOutput | No | Y | Include in output (default Y) |

**Example:**
```
TrackingCode | TrackingLabel          | QuestionType | ShowInOutput
TRK_NPS      | Net Promoter Score     | NPS          | Y
TRK_SAT_01   | Product Satisfaction   | Rating       | Y
TRK_COMP_SAT | Overall Satisfaction   | Composite    | Y
```

---

### 3.2 question_mapping.xlsx

**Purpose:** Map questions across waves (handles renumbering)

#### Sheet 1: Question_Mapping

| Column | Required | Example | Description |
|--------|----------|---------|-------------|
| TrackingCode | Yes | TRK_SAT_01 | Links to TrackedQuestions |
| WaveID | Yes | W1 | Which wave |
| QuestionCode | Yes | SAT_PROD | Question code in this wave |
| OptionMapping | No | See below | Remaps options if changed |

**Example - Question Renumbering:**
```
TrackingCode | WaveID | QuestionCode | Notes
TRK_SAT_01   | W1     | Q10          | "Product satisfaction"
TRK_SAT_01   | W2     | Q11          | Same question, new position
TRK_SAT_01   | W3     | Q11          | Still in same position

TRK_NPS      | W1     | Q25          | "Recommend to friend"
TRK_NPS      | W2     | Q26          | 
TRK_NPS      | W3     | Q27          | Question moved again
```

**Key Points:**
- Each TrackingCode has one row per wave
- QuestionCode can differ across waves
- If question not asked in a wave, omit that row (shows as N/A in output)

#### Sheet 2: Option_Mapping (Optional)

**Purpose:** Handle option text/value changes across waves

| TrackingCode | WaveID | OriginalOption | MappedOption | MappedValue |
|--------------|--------|----------------|--------------|-------------|
| TRK_SAT_01 | W2 | Very Satisfied | Very satisfied | 5 |
| TRK_SAT_01 | W2 | Very Dissatisfied | Very dissatisfied | 1 |

**Use Case:** Wave 1 used "Very Satisfied" but Wave 2 changed to "Very satisfied" (lowercase). Map them to ensure consistent aggregation.

---

### 3.3 Composite Definitions

**Integration with TurasTabs:**

Composite scores are defined in the **Survey_Structure.xlsx** file (same as TurasTabs). The tracker:
1. Loads composite definitions from Survey_Structure.xlsx
2. Calculates composites for each wave using TurasTabs logic
3. Tracks composite scores across waves like any other question

**In question_mapping.xlsx:**
```
TrackingCode   | WaveID | QuestionCode    | Notes
TRK_COMP_SAT   | W1     | COMP_SAT_OVERALL| From Survey_Structure
TRK_COMP_SAT   | W2     | COMP_SAT_OVERALL| Same composite
TRK_COMP_SAT   | W3     | COMP_SAT_OVERALL| Same composite
```

**Key Point:** Composites are "virtual questions" calculated on-the-fly for each wave. The tracker treats them exactly like regular questions.

---

## 4. TECHNICAL SPECIFICATIONS

### 4.1 Question Mapping Logic

**Purpose:** Handle questions that change position, wording, or structure across waves

**Algorithm:**
```r
map_question_across_waves <- function(tracking_code, question_mapping, wave_data_list) {
  # 1. Get all mappings for this tracking code
  mappings <- question_mapping[question_mapping$TrackingCode == tracking_code, ]
  
  # 2. For each wave:
  wave_results <- list()
  for (wave_id in names(wave_data_list)) {
    # Find question code for this wave
    mapping <- mappings[mappings$WaveID == wave_id, ]
    
    if (nrow(mapping) == 0) {
      # Question not asked in this wave
      wave_results[[wave_id]] <- NA
      next
    }
    
    question_code <- mapping$QuestionCode
    
    # 3. Calculate metric for this wave
    wave_data <- wave_data_list[[wave_id]]
    
    if (!question_code %in% names(wave_data)) {
      warning(paste("Question", question_code, "not found in", wave_id))
      wave_results[[wave_id]] <- NA
      next
    }
    
    # 4. Apply option mapping if provided
    if (!is.na(mapping$OptionMapping)) {
      wave_data <- apply_option_mapping(wave_data, question_code, mapping$OptionMapping)
    }
    
    # 5. Calculate metric based on question type
    metric <- calculate_metric(wave_data, question_code, question_type)
    wave_results[[wave_id]] <- metric
  }
  
  return(wave_results)
}
```

### 4.2 Trend Calculation Logic

**For each tracked question, calculate:**

1. **Metric by Wave:**
   - Single choice: % selecting each option
   - Rating: Mean score
   - Likert: Index score (0-100)
   - NPS: Net Promoter Score
   - Composite: Calculated score

2. **Wave-over-Wave Change:**
   ```
   Change = Current Wave - Previous Wave
   ```

3. **Change from Baseline:**
   ```
   Change from Baseline = Current Wave - Baseline Wave
   ```

4. **Percentage Change:**
   ```
   % Change = ((Current - Previous) / Previous) * 100
   ```
   
   **Note:** Only for means/indices, not for proportions (can't say "10% increased by 50%")

5. **Significance Testing:**
   - **Proportions:** Z-test for two proportions
     ```r
     prop.test(x = c(n1_success, n2_success), 
               n = c(n1_total, n2_total))
     ```
   
   - **Means:** Independent samples t-test
     ```r
     t.test(wave1_values, wave2_values)
     ```
   
   - **Mark significant changes:** *, **, *** based on p-value

### 4.3 Banner Segment Tracking

**Process:**

For each banner segment (e.g., Region = North):
1. Filter each wave's data to segment
2. Calculate metric for filtered data
3. Track segment across waves
4. Test significance within segment

**Output Structure:**
```
Sheet: TRK_SAT_01_by_Region

Question: Product Satisfaction
Segment: Region

             | W1: Jan 2024 | W2: Apr 2024 | Change | Sig | W3: Jul 2024 | Change | Sig
-------------|--------------|--------------|--------|-----|--------------|--------|-----
Total        | 7.2          | 7.5          | +0.3   | *   | 7.8          | +0.3   | **
North        | 7.5          | 7.8          | +0.3   |     | 8.1          | +0.3   | *
South        | 6.9          | 7.2          | +0.3   | *   | 7.5          | +0.3   | *
East         | 7.3          | 7.6          | +0.3   |     | 7.9          | +0.3   | **
West         | 7.1          | 7.4          | +0.3   |     | 7.7          | +0.3   | *
```

### 4.4 Handling Missing Data

**Scenarios:**

1. **Question not asked in wave:**
   - Show "N/A" in output
   - Cannot calculate change
   - Mark as "Question not asked"

2. **No responses in wave:**
   - Show "Insufficient data"
   - Flag in metadata

3. **Different sample sizes:**
   - Use effective-n for weighted data
   - Flag small bases (< minimum_base setting)
   - Still calculate but mark with warning

---

## 5. OUTPUT SPECIFICATION

### 5.1 Excel Workbook Structure

```
Tracking_Results.xlsx
├── 1. Summary (metadata, wave info, settings)
├── 2. Change_Summary (all questions, baseline → latest)
├── 3. TRK_NPS (full trend table for NPS)
├── 4. TRK_SAT_01 (full trend table for Product Sat)
├── 5. TRK_COMP_SAT (full trend table for composite)
├── 6. TRK_NPS_by_Region (trend by region)
└── 7. Metadata (config snapshot, processing log)
```

### 5.2 Sheet Layouts

#### Summary Sheet

```
TRACKING ANALYSIS SUMMARY
Project: Customer Satisfaction Tracker
Baseline: Wave 1 (Jan 2024)
Latest Wave: Wave 3 (Jul 2024)
Total Waves: 3

Wave Information:
WaveID | Label              | Date       | Sample Size | Weighted n
W1     | Wave 1 (Jan 2024) | 2024-01-15 | 500         | 500
W2     | Wave 2 (Apr 2024) | 2024-04-15 | 520         | 520
W3     | Wave 3 (Jul 2024) | 2024-07-15 | 495         | 495

Settings:
Significance Level: 95%
Minimum Base Size: 30
Weighting Applied: Yes
```

#### Change Summary Sheet

```
CHANGE FROM BASELINE (W1 → W3)

Metric                  | Baseline | Latest | Change | % Change | Sig
------------------------|----------|--------|--------|----------|-----
Net Promoter Score      | +38      | +45    | +7     | +18.4%   | **
Product Satisfaction    | 7.2      | 7.8    | +0.6   | +8.3%    | ***
Service Quality         | 7.5      | 7.9    | +0.4   | +5.3%    | *
Overall Satisfaction    | 7.3      | 7.8    | +0.5   | +6.8%    | **
```

#### Trend Table Sheet (Example: TRK_NPS)

```
NET PROMOTER SCORE
Tracking Code: TRK_NPS
Question Type: NPS

Trend Table:
                    | W1: Jan 2024 | Change | Sig | W2: Apr 2024 | Change | Sig | W3: Jul 2024
--------------------|--------------|--------|-----|--------------|--------|-----|-------------
Total               |             |        |     |              |        |     |
  Promoters (9-10)  | 48%          | -      | -   | 52%          | +4pp   | *   | 55%
  Passives (7-8)    | 36%          | -      | -   | 33%          | -3pp   |     | 31%
  Detractors (0-6)  | 16%          | -      | -   | 15%          | -1pp   |     | 14%
  NPS               | +32          | -      | -   | +37          | +5     | *   | +41
  
Base Sizes:
  Unweighted n      | 500          |        |     | 520          |        |     | 495
  Weighted n        | 500          |        |     | 520          |        |     | 495

Notes:
* p < 0.05
** p < 0.01
*** p < 0.001
pp = percentage points
```

### 5.3 Excel Styling

**Colors:**
- Headers: Blue (#1F4E78)
- Positive changes: Light green (#C6EFCE)
- Negative changes: Light red (#FFC7CE)
- Significant changes: Bold text
- Section headers: Gray (#E8E8E8)

**Conditional Formatting:**
- Green if change > 0 and significant
- Red if change < 0 and significant
- No color if not significant

---

## 6. VALIDATION REQUIREMENTS

### 6.1 Configuration Validation

**Check on Load:**
- All wave data files exist and are readable
- All mapped questions exist in their respective waves
- WaveIDs are unique
- Baseline wave is specified and exists
- Banner variables exist in all waves
- TrackingCodes are unique

### 6.2 Data Validation

**Check per Wave:**
- Required columns present
- Question columns have valid data types
- Weight column exists (if configured)
- Sufficient sample size (> minimum_base)

### 6.3 Question Compatibility

**Check Across Waves:**
- Question types match (can't track Rating in W1 as NPS in W2)
- Option structures compatible (same scale)
- If option mapping provided, all options covered

**Warnings (not errors):**
- Sample size varies by >20% across waves
- Different weighting schemes across waves
- Question asked in some waves but not others

---

## 7. DEVELOPMENT APPROACH

### Phase 1: Foundation (Week 1)
**Goal:** Basic infrastructure working

- [ ] Create project structure
- [ ] Build configuration loader
- [ ] Build wave data loader
- [ ] Implement basic validation
- [ ] Test with 2-wave synthetic data

**Success Criteria:**
- Can load tracking_config.xlsx
- Can load question_mapping.xlsx
- Can load 2 wave data files
- Validation catches obvious errors

### Phase 2: Question Mapping (Week 1-2)
**Goal:** Question mapping logic working

- [ ] Implement question mapper
- [ ] Handle question renumbering
- [ ] Test with questions that change positions
- [ ] Handle missing questions gracefully

**Success Criteria:**
- Correctly maps Q10→Q11→Q12 across waves
- Handles unmapped questions
- Validates question type consistency

### Phase 3: Trend Calculation (Week 2)
**Goal:** Calculate trends and changes

- [ ] Implement metric calculation per wave
- [ ] Calculate wave-over-wave changes
- [ ] Calculate baseline changes
- [ ] Implement significance testing
- [ ] Handle banner segments

**Success Criteria:**
- Calculates correct means/proportions
- Calculates correct changes
- Significance tests match manual calculations
- Banner breakouts work correctly

### Phase 4: Composite Integration (Week 2-3)
**Goal:** Composites track across waves

- [ ] Load composite definitions
- [ ] Calculate composites per wave
- [ ] Track composites like regular questions
- [ ] Test with multi-wave composite data

**Success Criteria:**
- Composites calculate correctly each wave
- Composite trends match expected values
- Significance tests work for composites

### Phase 5: Excel Output (Week 3)
**Goal:** Professional Excel output

- [ ] Create output structure
- [ ] Write Summary sheet
- [ ] Write Change Summary sheet
- [ ] Write Trend Table sheets
- [ ] Apply styling and formatting
- [ ] Write Metadata sheet

**Success Criteria:**
- All sheets present and formatted
- Numbers display with correct decimals
- Conditional formatting works
- Significance markers correct

### Phase 6: Testing & Refinement (Week 3-4)
**Goal:** Production ready

- [ ] End-to-end test with real data
- [ ] Validation of all calculations
- [ ] Error handling for edge cases
- [ ] Documentation updates
- [ ] User acceptance testing

**Success Criteria:**
- Processes 3+ waves successfully
- All calculations verified
- Handles edge cases gracefully
- Users can operate independently

---

## 8. CRITICAL SUCCESS FACTORS

### 8.1 Code Quality Standards

**Follow TurasTabs Patterns:**
- Use same function naming conventions
- Use same error handling approach
- Use same logging patterns
- Match code structure and style

**Documentation:**
- Roxygen2 comments for all functions
- Clear parameter descriptions
- Examples in documentation
- README with quick start guide

**Testing:**
- Unit tests for calculation functions
- Integration test with synthetic data
- Manual QC with real data
- Regression tests (compare to manual calcs)

### 8.2 Performance Targets

**Must Handle:**
- 10 waves × 500 respondents × 50 questions = comfortable
- 25 waves × 5,000 respondents × 100 questions = acceptable
- Processing time < 2 minutes for typical project

**Optimization Strategies:**
- Calculate metrics once per wave, reuse for all comparisons
- Cache question lookups
- Vectorize calculations where possible
- Avoid nested loops

### 8.3 Extensibility Points

**Design for Future Features:**

1. **Panel Data:**
   - Wave loader should record respondent IDs
   - Question mapper can handle respondent-level matching
   - Trend calculator can switch between independent/paired tests

2. **Advanced Analytics:**
   - Trend calculator returns raw values + metadata
   - Easy to add effect size calculations later
   - Easy to add trend slope analysis later

3. **Alternative Outputs:**
   - Trend calculator produces data frame
   - Output writer is separate from calculation
   - Easy to add CSV/JSON exporters later

4. **Visualization:**
   - Output includes metadata for charting
   - Data in long format for easy plotting
   - Color schemes defined in config

---

## 9. SHARED CODE INTEGRATION

### 9.1 Functions to Extract from TurasTabs

**Move to /shared/ directory:**

```r
# shared/weights.R
calculate_effective_n()
apply_weights()
calculate_design_effect()

# shared/significance_tests.R
z_test_proportions()
t_test_means()
format_significance_markers()

# shared/composite_calculator.R
load_composite_definitions()
calculate_composite_values()
validate_composite_definitions()

# shared/formatting.R
format_number()
format_percentage()
format_change()

# shared/excel_styles.R
create_header_style()
create_data_style()
create_significance_style()
```

### 9.2 Refactoring TurasTabs

**Minimal changes needed:**

1. Move shared functions to `/shared/`
2. Update `source()` calls in TurasTabs
3. Add `source()` calls in TurasTracker
4. Test that TurasTabs still works identically

**Critical:** This refactoring must not break TurasTabs. Run full regression test suite after refactoring.

---

## 10. RISK MITIGATION

### 10.1 Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Question mapping too complex | High | Start with simple renumbering only, add option mapping later |
| Shared code breaks TurasTabs | High | Thorough regression testing, version control rollback ready |
| Performance issues with many waves | Medium | Profile code early, optimize hot paths, implement caching |
| Excel output too slow | Low | Use openxlsx efficiently, batch writes where possible |

### 10.2 User Adoption Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Configuration too complex | High | Provide templates, examples, step-by-step guide |
| Question mapping errors | High | Extensive validation, clear error messages, preview feature |
| Unexpected results | Medium | Comprehensive testing, comparison to manual calculations |
| Missing features users expect | Low | Start with MVT, gather feedback, prioritize enhancements |

---

## 11. FUTURE ENHANCEMENTS (POST-MVT)

### Priority 1 (Next)
- Effect size calculations (Cohen's d)
- Trend slope analysis (linear regression)
- Automated base drift warnings
- Multi-mention question tracking

### Priority 2 (Later)
- Panel data support
- Attrition analysis
- CSV/JSON exports
- Individual trajectory analysis

### Priority 3 (Future)
- Visualization/charting
- Dashboard integration
- Statistical forecasting
- Text analytics integration

---

## 12. DELIVERABLES CHECKLIST

### Code Deliverables
- [ ] `/TurasTracker/` module directory with all R files
- [ ] `/shared/` directory with shared functions
- [ ] Refactored TurasTabs using shared code
- [ ] Unit tests for all calculation functions
- [ ] Integration test with synthetic data
- [ ] Example data files (3 waves)

### Documentation Deliverables
- [ ] Developer documentation (function reference)
- [ ] User manual (end-user focused)
- [ ] Quick start guide (1-page)
- [ ] Configuration templates (Excel files)
- [ ] Example project (complete working example)

### Testing Deliverables
- [ ] Test data (synthetic multi-wave dataset)
- [ ] Test results (verified calculations)
- [ ] Regression test suite
- [ ] Performance benchmark results

---

## 13. DEVELOPMENT TIMELINE

```
Week 1: Foundation & Question Mapping
├─ Days 1-2: Project setup, config loader, wave loader
├─ Days 3-4: Question mapping logic
└─ Day 5: Testing and refinement

Week 2: Trend Calculation
├─ Days 1-2: Metric calculation per wave
├─ Days 3-4: Change calculation, significance testing
└─ Day 5: Banner segment tracking

Week 3: Composites & Output
├─ Days 1-2: Composite integration
├─ Days 3-4: Excel output generation
└─ Day 5: Testing and refinement

Week 4: Testing & Documentation
├─ Days 1-2: End-to-end testing, QC
├─ Days 3-4: Documentation, examples
└─ Day 5: User acceptance testing
```

**Total Estimated Effort:** 3-4 weeks

---

## 14. ACCEPTANCE CRITERIA

### Functional Requirements
✅ Loads 3+ waves of data successfully  
✅ Maps questions that change positions (Q10→Q11→Q12)  
✅ Calculates correct metrics for each wave  
✅ Calculates correct wave-over-wave changes  
✅ Performs significance tests correctly  
✅ Tracks composite scores across waves  
✅ Handles banner breakouts (e.g., by Region)  
✅ Generates formatted Excel output  
✅ Handles missing questions gracefully  
✅ Validates configuration files  

### Quality Requirements
✅ Code follows TurasTabs conventions  
✅ All functions have Roxygen2 documentation  
✅ Calculations match manual verification  
✅ Shared code doesn't break TurasTabs  
✅ Processes typical project in < 2 minutes  
✅ Clear error messages for common issues  

### Documentation Requirements
✅ User manual explains configuration  
✅ Quick start guide gets user running in 15 minutes  
✅ Example project demonstrates all features  
✅ Developer docs explain architecture  

---

## 15. QUESTIONS FOR CLARIFICATION

Before starting development, confirm:

1. **Data Format:**
   - Are all wave data files in same format (CSV vs Excel)?
   - Do all waves have consistent column structures?

2. **Weighting:**
   - Do all waves use same weight variable name?
   - Or can it differ per wave?

3. **Output Preferences:**
   - One sheet per question, or combine similar questions?
   - Show all waves in one table, or separate tables?

4. **Banner Priority:**
   - Just Total + banner breakouts?
   - Or also banner combinations (Region × Age)?

5. **Question Types:**
   - Are there numeric questions (e.g., "How many?")?
   - Are there multi-mention questions in Wave 1 data?

---

## 16. CONCLUSION

### Why This Approach Works

**Lean MVT First:**
- Delivers value in 3-4 weeks
- Validates architecture with real data
- Allows user feedback to shape advanced features
- Reduces risk of building unused features

**Shared Code Strategy:**
- Ensures consistency between Tabs and Tracker
- Reduces maintenance burden
- Enables rapid feature development

**Modular Design:**
- Easy to add new features later
- Clear separation of concerns
- Testable components

**Clear Requirements:**
- Everyone knows what's in/out of scope
- Measurable acceptance criteria
- Realistic timeline

### Next Steps

1. **Approval:** Review and approve this briefing
2. **Planning:** Finalize timeline and resource allocation
3. **Setup:** Create project structure, templates
4. **Development:** Follow phased approach outlined above
5. **Testing:** Validate with real data
6. **Launch:** Deploy MVT and gather feedback
7. **Enhance:** Build Priority 1 features based on usage

---

## APPENDIX A: EXAMPLE QUESTION MAPPING

### Scenario: Product Satisfaction Question Changes Position

**Wave 1 Survey:**
- Q10: Product satisfaction (1-10 scale)

**Wave 2 Survey:**
- Q11: Product satisfaction (1-10 scale)  ← Moved down one position
- New question inserted at Q10

**Wave 3 Survey:**
- Q12: Product satisfaction (1-10 scale)  ← Moved down again

**question_mapping.xlsx:**
```
TrackingCode | WaveID | QuestionCode
TRK_SAT_PROD | W1     | Q10
TRK_SAT_PROD | W2     | Q11
TRK_SAT_PROD | W3     | Q12
```

**Result:** Tracker correctly follows the question across all waves despite position changes.

---

## APPENDIX B: EXAMPLE COMPOSITE TRACKING

### Scenario: Overall Satisfaction Composite

**Survey_Structure.xlsx (Composite_Metrics sheet):**
```
CompositeCode    | CompositeLabel         | CalculationType | SourceQuestions
COMP_SAT_OVERALL | Overall Satisfaction   | Mean            | SAT_01,SAT_02,SAT_03
```

**question_mapping.xlsx:**
```
TrackingCode      | WaveID | QuestionCode
TRK_COMP_SAT      | W1     | COMP_SAT_OVERALL
TRK_COMP_SAT      | W2     | COMP_SAT_OVERALL
TRK_COMP_SAT      | W3     | COMP_SAT_OVERALL
```

**What Happens:**
1. TurasTracker loads composite definition from Survey_Structure.xlsx
2. For each wave:
   - Loads SAT_01, SAT_02, SAT_03 from wave data
   - Calculates composite using TurasTabs logic
   - Stores result as COMP_SAT_OVERALL
3. Tracks composite across waves like any other question
4. Shows trend: W1: 7.2 → W2: 7.5 (+0.3*) → W3: 7.8 (+0.3**)

---

## APPENDIX C: EXAMPLE BANNER TRACKING

### Scenario: Track NPS by Region

**tracking_config.xlsx (Banner sheet):**
```
QuestionCode | Label  | Filter | ShowInOutput
TOTAL        |        |        | Y
Region       | Region |        | Y
```

**Result - Excel Output:**

**Sheet: TRK_NPS_by_Region**
```
NET PROMOTER SCORE by Region

             | W1: Jan 2024 | Change | Sig | W2: Apr 2024 | Change | Sig
-------------|--------------|--------|-----|--------------|--------|-----
Total        | +38          | -      | -   | +45          | +7     | **
North        | +42          | -      | -   | +48          | +6     | *
South        | +35          | -      | -   | +43          | +8     | **
East         | +40          | -      | -   | +46          | +6     | *
West         | +36          | -      | -   | +44          | +8     | **
```

Each region's trend is tracked independently with its own significance tests.

---

**END OF BRIEFING DOCUMENT**

Version 1.0 | November 6, 2025  
Total Pages: 28  
Status: Ready for Development Approval
