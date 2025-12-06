# Turas Tracker Enhancement Specification
## Wave History Report Format

**Version:** 1.0  
**Date:** 2024-11-21  
**Status:** Proposed  
**Priority:** High  
**Complements:** Multi-mention detection, Composite questions, Rating ranges enhancements

---

## Overview

Add a **Wave History** report format that presents tracking data in a compact, executive-friendly layout with one row per question and one column per wave. This format emphasizes time-series visualization over wave-to-wave change analysis.

### Current State
Tracker generates detailed trend reports with:
- One sheet per question
- Wave-to-wave change indicators (↑↓→)
- Statistical detail (SD, CI, sample sizes)
- Separate change/significance sections

### Proposed Addition
**Wave History format:**
- One sheet per segment (Total, then each banner breakout)
- One row per question
- Columns: `QuestionCode | Question | Type | Wave 1 | Wave 2 | ... | Wave N`
- Only shows primary metric value per wave
- Clean, scannable format for executives

---

## Design Decisions

### 1. Multiple Report Types Strategy

**RECOMMENDATION: Support multiple simultaneous report types via configuration**

#### Rationale
- Different stakeholders need different views
- Analysts need detailed trends, executives need wave history
- Some projects may want both, others just one

#### Configuration Approach
Add to **Settings sheet**:

```
SettingName              | SettingValue
report_types             | detailed,wave_history  (comma-separated)
```

**Valid options:**
- `detailed` - Current format (default if not specified)
- `wave_history` - New compact format
- `detailed,wave_history` - Generate both
- `wave_history,detailed` - Same (order doesn't matter)

#### Output Naming
When multiple report types specified:
- `{project}_tracking_detailed.xlsx` - Detailed trend report
- `{project}_tracking_wave_history.xlsx` - Wave history report
- Both include same metadata sheet with cross-references

When single report type specified:
- `{project}_tracking_output.xlsx` - Contains that format

---

## Wave History Format Specification

### Sheet Structure

**One sheet per segment:**
- First sheet: "Total" (always present)
- Subsequent sheets: Each banner segment (e.g., "Male", "Female", "18-34", etc.)

**Sheet naming:**
- Total segment: "Total"
- Banner segments: Use BreakLabel from Banner sheet configuration

**Header rows:**
```
Row 1: [Segment label]          e.g., "Total sample" or "Filter: North region"
Row 2: [Blank]
Row 3: QuestionCode | Question | Type | Wave 1 | Wave 2 | Wave 3 | ...
```

### Column Definitions

| Column | Width | Content | Example |
|--------|-------|---------|---------|
| QuestionCode | 15 | Question identifier | Q02 |
| Question | 60 | Question text | "Overall satisfaction (1-10)" |
| Type | 12 | Metric type label | Mean, % Yes, NPS |
| Wave 1...N | 12 | Metric value for that wave | 8.9, 45, - |

### Metric Type Labels

Questions display different metric types based on TrackingSpecs:

| Question Type | TrackingSpecs | Display Label | Value Shown |
|---------------|---------------|---------------|-------------|
| Rating | (none) | Mean | Mean score |
| Rating | top_box | Top Box | % selecting top values |
| Rating | top_box=9-10 | Top 2 Box | % selecting 9-10 |
| Rating | range:7-10 | % 7-10 | % in range 7-10 |
| Single/Multi | (none) | % {option} | % for specified category |
| Single/Multi | category={value} | % {value} | % for that category |
| NPS | (none) | NPS | Net Promoter Score |
| Composite | (none) | Mean | Mean of composite |

---

## Configuration: Specifying Metrics to Track

### Enhanced TrackedQuestions Sheet

**Add optional columns to TrackedQuestions sheet:**

```
QuestionCode | TrackingSpecs                    | MetricLabel (optional)
Q02          |                                  | Mean
Q05          | category=shop around             | % shop around
Q07          |                                  | Mean
Q11          | category=Always                  | % Always
Q12          | category=Always                  | % Always
Q20          |                                  | NPS
Q21          | top_box=9-10                     | Top 2 Box
Q22          | range:7-10                       | % Satisfied (7-10)
```

**TrackingSpecs syntax:**
- `category={value}` - Track specific response category (for Single/Multi questions)
- `top_box` - Track top box (auto-detect from scale)
- `top_box={values}` - Track specific values as top box (e.g., 9-10)
- `range:{min}-{max}` - Track custom range
- (blank) - Use default for question type

**MetricLabel column:**
- Optional display label override
- If blank, auto-generate from TrackingSpecs and question type
- Allows custom wording (e.g., "% Satisfied" instead of "% 7-10")

### Auto-Detection Rules (when TrackingSpecs blank)

| Question Type | Auto-Detected Metric | Label |
|---------------|----------------------|-------|
| Rating | Mean | "Mean" |
| NPS | NPS score | "NPS" |
| Single choice | First category (alphabetically) | "% {category}" |
| Multi mention | Each mentioned option | "% {option}" (multiple rows) |
| Composite | Mean | "Mean" |

**Warning:** If TrackingSpecs blank for proportion questions, tracker shows warning and uses first category found.

---

## Data Formatting Rules

### Numeric Precision
Use same decimal places as detailed output:
- From Settings: `decimal_places_ratings`, `decimal_places_nps`, etc.
- Consistent across both report formats

### Missing Data
- Unavailable waves: **Blank cell** (not "-" or "NA")
- Excel cell value = empty string
- Allows proper numeric formatting in Excel

### Value Ranges
- Means: Format to specified decimal places (e.g., 8.9)
- Percentages: Format to specified decimal places, no % sign (e.g., 45 not 45%)
- NPS: Integer or 1 decimal (e.g., 32 or 32.5)

### Cell Formatting
- All numeric cells: Excel number format (not text)
- Enable Excel sorting/filtering on columns
- Apply conditional formatting for values (optional future enhancement)

---

## Implementation Approach

### Phase 1: Core Wave History Output

**New function:** `write_wave_history_output()`

**Location:** `tracker_output.R`

**Responsibilities:**
1. Read trend_results and extract wave values
2. Parse TrackingSpecs to determine metric extraction
3. Build one data frame per segment
4. Write to Excel with proper formatting

**Key logic:**
```r
for each tracked question:
  - Get TrackingSpecs from config
  - Parse specs to determine metric type and extraction rules
  - For each wave:
    - Extract appropriate metric from wave_results
    - Apply decimal formatting
  - Build row: [code, text, label, wave1_val, wave2_val, ...]
  
for each segment (Total + banners):
  - Create sheet
  - Write header rows
  - Write question rows
  - Format columns
```

### Phase 2: Multi-Report Type Support

**Modify:** `run_tracker()` main orchestration

**Changes:**
1. Read `report_types` from Settings
2. Parse comma-separated list
3. Call appropriate output functions:
   - `write_tracker_output()` if "detailed" specified
   - `write_wave_history_output()` if "wave_history" specified
4. Generate appropriate filenames

**Backward compatibility:**
- If `report_types` not specified, default to "detailed"
- Existing configs continue to work unchanged

---

## Configuration Examples

### Example 1: Generate Both Report Types

**tracking_config.xlsx - Settings sheet:**
```
SettingName              | SettingValue
project_name             | Q4 2024 Brand Tracking
report_types             | detailed,wave_history
output_file              | Q4_tracking.xlsx
decimal_places_ratings   | 1
```

**Output:**
- `Q4_tracking_detailed.xlsx` - Full trend analysis
- `Q4_tracking_wave_history.xlsx` - Wave history format

### Example 2: Wave History Only

**Settings:**
```
SettingName              | SettingValue
report_types             | wave_history
```

**Output:**
- `Q4_tracking_output.xlsx` - Contains wave history format

### Example 3: Proportion Question Tracking

**TrackedQuestions sheet:**
```
QuestionCode | TrackingSpecs        | MetricLabel
Q05          | category=shop around | % shop around
Q11          | category=Always      | % Always
Q12          | category=Always      | % Always
```

**Result:** Wave history shows % who selected "shop around", % who said "Always", etc.

### Example 4: Rating Ranges

**TrackedQuestions sheet:**
```
QuestionCode | TrackingSpecs   | MetricLabel
Q20          | top_box=9-10    | Top 2 Box
Q21          | range:7-10      | % Satisfied
Q22          |                 | Mean
```

**Result:**
- Q20: Shows % of 9-10 responses
- Q21: Shows % of 7-10 responses  
- Q22: Shows mean score

---

## Implementation Notes

### Extraction Logic by Metric Type

**Mean (rating questions):**
```r
value <- trend_results[[q_code]]$wave_results[[wave_id]]$mean
```

**Top Box:**
```r
# Parse top_box spec to get values (e.g., "9-10" → c(9,10))
# Calculate % in those values from distribution
# Or: Extract from pre-calculated top_box metric (if available)
```

**Category (proportion questions):**
```r
# Parse category spec (e.g., "category=Always" → "Always")
# Extract from proportions:
value <- trend_results[[q_code]]$wave_results[[wave_id]]$proportions[["Always"]]
```

**NPS:**
```r
value <- trend_results[[q_code]]$wave_results[[wave_id]]$nps
```

### Handling Multi-Mention Questions

**Two options:**

**Option A: Multiple rows per question**
```
QuestionCode | Question                          | Type        | Wave 1 | Wave 2
Q15          | Features used (select all) - App  | % Mention   | 45     | 48
Q15          | Features used (select all) - Web  | % Mention   | 32     | 35
Q15          | Features used (select all) - SMS  | % Mention   | 18     | 20
```

**Option B: Specify one option in TrackingSpecs**
```
QuestionCode | TrackingSpecs    | MetricLabel
Q15          | category=App     | % Use App
```

**RECOMMENDATION: Option B for simplicity**
- User specifies which option(s) to track
- One row per metric tracked
- If want multiple options, add multiple rows to TrackedQuestions with different TrackingSpecs

---

## Edge Cases and Validations

### Validation Rules

1. **TrackingSpecs for proportions:**
   - If question type is Single/Multi and TrackingSpecs blank → Warning + use first category
   - If category specified but not found in data → Warning + show NA

2. **TrackingSpecs for ratings:**
   - If top_box/range specified on non-rating question → Error
   - If range values invalid (min > max) → Error

3. **MetricLabel:**
   - Max 50 characters
   - If blank, auto-generate from TrackingSpecs

4. **Missing segments:**
   - If banner breakout has no data for a wave → Blank cell
   - If entire question unavailable for segment → Blank row (not omitted)

### Error Messages

```
Warning: Q05 is a proportion question but no category specified in TrackingSpecs.
         Using first category found: "shop around"
         Recommendation: Add TrackingSpecs: category=shop around

Error: Q20 has top_box=9-10 specified but question type is SingleChoice, not Rating.
       top_box is only valid for Rating questions.

Warning: Q11 TrackingSpecs specifies category=Always but "Always" not found in data.
         Available categories: "Often", "Sometimes", "Rarely", "Never"
```

---

## Benefits

### For Executives
- **Scannable format:** Quickly see trends across many waves
- **Compact:** Fits more metrics on screen
- **Familiar:** Looks like traditional tracking charts
- **Focus:** Only shows the numbers that matter

### For Analysts  
- **Dual outputs:** Both detailed and summary views
- **Flexibility:** Choose metrics that matter for each question
- **Consistency:** Same calculations as detailed report
- **Integration:** Works with all existing features (banners, composites, etc.)

### For Projects
- **Configurable:** Different reports for different stakeholders
- **Maintainable:** One configuration drives both formats
- **Scalable:** Handles 3 waves or 50+ waves equally well

---

## Testing Scenarios

### Test 1: Basic Wave History
- 3 waves, 5 rating questions
- Generate wave_history only
- Verify: One sheet (Total), correct headers, mean values match detailed output

### Test 2: Proportion Questions
- Include questions with category specifications
- Verify: Correct categories extracted, labels match MetricLabel column

### Test 3: Multiple Report Types
- Set report_types = "detailed,wave_history"
- Verify: Both files generated, same data in both, appropriate filenames

### Test 4: Banner Breakouts
- 3 banner segments
- Verify: 4 sheets (Total + 3 segments), same questions on each sheet

### Test 5: Missing Data
- Question not asked in some waves
- Verify: Blank cells (not errors), other waves populate correctly

### Test 6: Top Box / Ranges
- Rating questions with top_box and range specs
- Verify: Correct percentages calculated, labels display properly

---

## Migration Path

### Existing Projects
- Add `report_types` setting → Defaults to "detailed" if blank
- No changes required to existing configs
- Can add TrackingSpecs incrementally

### New Projects
- Recommend specifying report_types explicitly
- Use TrackingSpecs for proportion questions from start
- Optional MetricLabel for custom display

---

## Future Enhancements

### Phase 2 Additions (not in initial scope)
1. **Conditional formatting:** Color-code increases/decreases in wave history
2. **Sparklines:** Add mini trend charts in Excel
3. **Change indicators:** Optional column showing latest change (↑↓→)
4. **Multiple metrics per question:** Allow tracking both mean AND top box
5. **Custom column ordering:** Specify wave column order in config
6. **Export formats:** CSV, JSON options for wave history data

---

## Questions for Confirmation

Before implementation, confirm:

1. ✅ **TrackingSpecs approach** - Is the syntax clear and flexible enough?
2. ✅ **Multi-report strategy** - Comfortable with separate files for each report type?
3. ✅ **Multi-mention handling** - Option B (specify in TrackingSpecs) acceptable?
4. ✅ **MetricLabel optional** - OK with auto-generation when not specified?

---

## Implementation Estimate

**Effort:** Medium (8-12 hours)

**Breakdown:**
- Core wave history output function: 4 hours
- Multi-report type orchestration: 2 hours
- TrackingSpecs parsing and extraction: 3 hours
- Testing and edge cases: 2 hours
- Documentation updates: 1 hour

**Dependencies:**
- Builds on existing trend_results structure
- Uses same decimal separator handling (already implemented)
- Leverages banner breakout calculations (already working)

**Deliverables:**
1. Enhanced `tracker_output.R` with `write_wave_history_output()`
2. Updated `run_tracker.R` orchestration
3. Enhanced Settings and TrackedQuestions schema
4. Updated USER_MANUAL.md with wave history examples
5. Test suite for wave history format

---

## Summary

The Wave History report enhancement provides a compact, executive-friendly view of tracking data that complements the existing detailed trend analysis. By supporting multiple simultaneous report types and flexible metric specifications via TrackingSpecs, it gives users the control they need while maintaining simplicity for basic cases.

**Key principles:**
- **Additive, not breaking:** Existing configs work unchanged
- **Flexible configuration:** Control metric display via TrackingSpecs
- **Multiple audiences:** Detailed for analysts, wave history for executives
- **Consistent data:** Same calculations across all report types
