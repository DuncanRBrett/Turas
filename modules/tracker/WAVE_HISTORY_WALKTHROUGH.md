# Wave History Report - Quick Walkthrough

**Version:** 1.0
**Date:** 2025-11-21
**Estimated Time:** 5 minutes

---

## What is Wave History Format?

Wave History is a compact, executive-friendly report format that shows tracking data with:
- **One row per question** (or per metric for questions with multiple TrackingSpecs)
- **One column per wave** for easy time-series viewing
- **Clean layout** that fits many questions on screen

### Comparison with Detailed Format

**Detailed Format (default):**
- One sheet per question
- Shows wave-to-wave changes, significance, confidence intervals
- Full statistical detail
- Best for: Analysts, detailed trend analysis

**Wave History Format (new):**
- One sheet per segment with all questions
- Shows only metric values across waves
- Compact, scannable layout
- Best for: Executives, quick overview, presentations

---

## How to Use

### Step 1: Add report_types Setting

Open your tracking configuration Excel file and go to the **Settings** sheet.

Add one of these settings:

#### Option A: Wave History Only
```
SettingName   | SettingValue
report_types  | wave_history
```

#### Option B: Both Report Types (Recommended)
```
SettingName   | SettingValue
report_types  | detailed,wave_history
```

#### Option C: Detailed Only (Default)
```
SettingName   | SettingValue
report_types  | detailed
```

Or simply omit the setting - defaults to detailed.

---

### Step 2: Run Tracker as Usual

```r
source("modules/tracker/run_tracker.R")

result <- run_tracker(
  tracking_config_path = "path/to/config.xlsx",
  question_mapping_path = "path/to/mapping.xlsx",
  use_banners = TRUE  # or FALSE
)
```

---

### Step 3: Review Output Files

**If you specified wave_history only:**
```
YourProject_WaveHistory_20251121.xlsx
```

**If you specified detailed,wave_history:**
```
YourProject_Tracker_20251121.xlsx       (detailed format)
YourProject_WaveHistory_20251121.xlsx   (wave history format)
```

---

## Wave History Output Format

### Sheet Structure

**Without Banners:**
- Single sheet: "Total"

**With Banners:**
- One sheet per segment: "Total", "Male", "Female", "18-34", etc.

### Column Layout

```
QuestionCode | Question                    | Type      | W1   | W2   | W3
Q38          | Overall satisfaction (1-10) | Mean      | 8.2  | 8.4  | 8.6
Q38          | Overall satisfaction (1-10) | Top 2 Box | 72   | 75   | 78
Q20          | Brand awareness             | % Yes     | 45   | 48   | 52
```

---

## How TrackingSpecs Work in Wave History

### Example 1: Rating Question with Multiple Metrics

**Question Mapping:**
```
QuestionCode | QuestionType | TrackingSpecs
Q38          | Rating       | mean,top2_box
```

**Wave History Output:**
```
QuestionCode | Question                    | Type      | W1  | W2  | W3
Q38          | Overall satisfaction (1-10) | Mean      | 8.2 | 8.4 | 8.6
Q38          | Overall satisfaction (1-10) | Top 2 Box | 72  | 75  | 78
```

Two rows: one for mean, one for top 2 box.

---

### Example 2: Multi-Mention Question

**Question Mapping:**
```
QuestionCode | QuestionType  | TrackingSpecs
Q15          | Multi_Mention | auto
```

**Wave History Output:**
```
QuestionCode | Question                    | Type        | W1 | W2 | W3
Q15          | Features used               | % Feature_1 | 45 | 48 | 50
Q15          | Features used               | % Feature_2 | 32 | 35 | 38
Q15          | Features used               | % Feature_3 | 18 | 20 | 22
```

One row per detected option.

---

### Example 3: Simple Mean Question

**Question Mapping:**
```
QuestionCode | QuestionType | TrackingSpecs
Q07          | Rating       |              (blank - defaults to mean)
```

**Wave History Output:**
```
QuestionCode | Question           | Type | W1  | W2  | W3
Q07          | Likelihood to... | Mean | 7.2 | 7.4 | 7.6
```

Single row showing mean.

---

## Use Cases

### Use Case 1: Executive Dashboard

Generate both formats:
- Share **Wave History** with executives for quick overview
- Keep **Detailed** for your analysis and reference

### Use Case 2: Presentation Prep

Use Wave History to:
- Quickly scan for interesting trends
- Copy data into PowerPoint tables
- Create simplified trend charts

### Use Case 3: Client Deliverable

Some clients prefer:
- **Detailed** for full transparency and statistical rigor
- **Wave History** for executive summary/appendix

Generate both and let client choose.

---

## Testing Your Setup

### Quick Test with Your Data

```r
setwd("~/Documents/Turas/modules/tracker")
source("test_wave_history.R")
```

This will:
1. Run tracker with your CCPB-CCS data
2. Test both with and without banners
3. Display test results

### Manual Verification Checklist

After generating Wave History output, verify:

- [ ] All tracked questions appear
- [ ] Questions with TrackingSpecs show multiple rows (one per metric)
- [ ] Wave columns show correct values (match detailed report)
- [ ] Banner segments each have their own sheet (if use_banners = TRUE)
- [ ] Column widths are readable
- [ ] Numeric formatting respects decimal_places setting

---

## Troubleshooting

### Issue: Only getting detailed report, not wave history

**Solution:** Check Settings sheet has `report_types` setting with value including "wave_history"

---

### Issue: Wave history shows wrong metric for proportion questions

**Solution:** For proportion questions, wave history uses first response code by default. If you want a specific code, add TrackingSpecs to specify it (future enhancement).

---

### Issue: Multi-mention questions missing from wave history

**Solution:** Ensure QuestionType is "Multi_Mention" and columns match pattern `{QuestionCode}_{number}` (e.g., Q15_1, Q15_2)

---

## Next Steps

1. **Try it out** - Add `report_types` setting and run tracker
2. **Compare formats** - Review both detailed and wave history outputs
3. **Share feedback** - Which format do different stakeholders prefer?
4. **Customize** - Add more TrackingSpecs to get the exact metrics you need

---

## Advanced: Configuration Examples

### Example: Full Setup with Both Formats

**Settings sheet:**
```
SettingName              | SettingValue
project_name             | Q4 2024 Brand Tracking
report_types             | detailed,wave_history
output_dir               | /path/to/output
decimal_places_ratings   | 1
decimal_separator        | .
```

**Question Mapping (excerpt):**
```
QuestionCode | QuestionType | TrackingSpecs   | Wave1 | Wave2 | Wave3
Q38          | Rating       | mean,top2_box   | Q38   | Q38   | Q38
Q20          | Single       |                 | Q20   | Q20A  | Q20B
Comp_Sat     | Composite    | mean            | -     | -     | -
```

**Output:**
- Detailed report with full analysis
- Wave History with mean + top2_box for Q38, standard metrics for others
- Both use decimal separator "." and 1 decimal place

---

**Questions?** Check USER_MANUAL.md Section 5 for full TrackingSpecs documentation.

*Version 1.0 | Wave History Walkthrough | Turas Tracker Module | Last Updated: 2025-11-21*
