# Tracker Enhancements - Testing Walkthrough

This guide walks you through testing the Phase 1 & 2 enhancements to ensure everything works correctly.

## Quick Start - Basic Functionality Test

Run the basic test script to verify core functions load and work:

```bash
cd /home/user/Turas/modules/tracker
Rscript test_data/test_enhancements.R
```

**Expected Output:**
- ✓ All functions should load successfully
- ✓ TrackingSpecs validation should pass/fail appropriately
- ✓ Multi-mention column detection should work
- ✓ Rating calculations should produce correct percentages

---

## Step-by-Step Testing

### TEST 1: Backward Compatibility (No Breaking Changes)

**Purpose:** Verify existing tracker configs still work without any changes.

**Steps:**
1. Find an existing tracker configuration (or use a template)
2. Run tracker WITHOUT adding TrackingSpecs column
3. Verify output matches previous behavior

**Expected Result:**
- Rating questions show "Mean" (default behavior)
- NPS questions show NPS score
- No errors or warnings about missing TrackingSpecs

**How to verify:**
```r
# In R console
setwd("/home/user/Turas/modules/tracker")
source("run_tracker.R")

# Load existing config (use your own config file)
# Should work exactly as before
```

---

### TEST 2: Enhanced Rating Metrics

**Purpose:** Test new rating question capabilities (top_box, ranges, etc.)

**Setup:**
1. Open your `question_mapping.xlsx`
2. Add a new column called `TrackingSpecs` (if not present)
3. For a rating question, add specs like:
   - `mean,top2_box` - Shows both mean and top 2 box
   - `range:9-10` - Shows % rating 9-10
   - `top_box,bottom_box` - Shows both ends of scale

**Example question_mapping.xlsx:**

| QuestionCode | QuestionText | QuestionType | TrackingSpecs | Wave1 | Wave2 |
|--------------|--------------|--------------|---------------|-------|-------|
| Q_SAT | Overall satisfaction (1-10) | Rating | mean,top2_box,range:9-10 | Q10 | Q11 |
| Q_LIKELY | Likelihood to recommend | Rating | top_box,mean | Q12 | Q13 |

**Expected Output in Excel:**
- Q_SAT sheet shows 3 rows: Mean, Top 2 Box %, % 9-10
- Q_LIKELY sheet shows 2 rows: Top Box %, Mean
- All values calculated correctly across waves

---

### TEST 3: Multi-Mention Questions

**Purpose:** Test multi-select question support with auto-detection.

**Setup:**
1. Create a multi-mention question with columns like:
   - Q30_1, Q30_2, Q30_3, Q30_4 (coded as 1/0)
2. In question_mapping.xlsx:

| QuestionCode | QuestionText | QuestionType | TrackingSpecs | Wave1 | Wave2 |
|--------------|--------------|---------------|---------------|-------|-------|
| Q30 | Features used (select all) | Multi_Mention | auto | Q30 | Q30 |

**Expected Behavior:**
- Tracker auto-detects Q30_1, Q30_2, Q30_3, Q30_4
- Sorts them numerically (Q30_1, Q30_2, ... Q30_10, Q30_11)
- Calculates % mentioning each option
- Shows all options in Excel output

**Advanced TrackingSpecs:**
```
auto,any,count_mean
```
This shows:
- % mentioning each option
- % mentioning at least one option (any)
- Mean number of options mentioned (count_mean)

**Selective tracking:**
```
option:Q30_1,option:Q30_3,any
```
Only tracks Q30_1 and Q30_3, plus "any" metric.

---

### TEST 4: Composite Questions with Enhanced Metrics

**Purpose:** Test that composites can use same metrics as ratings.

**Setup:**
1. Create a composite question with source questions
2. Add TrackingSpecs for the composite:

| QuestionCode | QuestionText | QuestionType | SourceQuestions | TrackingSpecs | Wave1 | Wave2 |
|--------------|--------------|--------------|-----------------|---------------|-------|-------|
| CX_INDEX | Customer Experience Index | Composite | Q10,Q11,Q12 | mean,top2_box,range:9-10 | - | - |

**Expected Output:**
- Composite calculated as mean of Q10, Q11, Q12
- Then enhanced metrics applied to composite scores
- Shows mean, top 2 box %, and % 9-10 of the composite

---

## Validation Checks

The tracker includes enhanced validation. Run tracker and check for:

**✓ Pre-flight Validation Messages:**
```
7. Validating TrackingSpecs...
  Question 'Q_SAT': TrackingSpecs validated (mean,top2_box)
  2 questions have custom TrackingSpecs
```

**✗ Error Detection:**
Try adding an invalid spec to test error handling:
- Add `TrackingSpecs: range:9-10` to an NPS question
- Should show error: "range:9-10 is only valid for Rating or Composite questions"

---

## Common Issues & Solutions

### Issue: "No multi-mention columns found"
**Cause:** Column naming doesn't match pattern or wave code wrong
**Solution:** Ensure columns are named {WaveCode}_{number} (e.g., Q30_1, Q30_2)

### Issue: "TrackingSpecs column not found"
**Cause:** Column name misspelled or missing
**Solution:** Add "TrackingSpecs" column to question_mapping.xlsx (exact spelling, case-sensitive)

### Issue: Top box shows 0%
**Cause:** Scale detection issue or data coding
**Solution:** Check that rating values are numeric (not text), verify scale matches expectations

---

## Verification Checklist

Run through this checklist to confirm everything works:

- [ ] Basic test script runs without errors
- [ ] Existing configs work unchanged (backward compatibility)
- [ ] Rating question with `mean` shows same as before
- [ ] Rating question with `top2_box` calculates correctly
- [ ] Custom range (e.g., `range:9-10`) shows expected %
- [ ] Multi-mention auto-detection finds all columns
- [ ] Multi-mention columns sorted numerically
- [ ] Multi-mention percentages sum correctly
- [ ] Composite with TrackingSpecs works
- [ ] Excel output shows all requested metrics
- [ ] Validation catches invalid TrackingSpecs

---

## Next Steps

Once basic testing passes:

1. **Test with Real Data** - Use actual survey data if available
2. **Test Edge Cases**:
   - Questions missing in some waves
   - Empty/NA responses
   - Very small sample sizes
3. **Banner Breakouts** - Test that enhancements work with banner analysis
4. **Review Documentation** - Update user manual with examples

---

## Getting Help

If you encounter issues:

1. Check validation messages - they're designed to be helpful
2. Verify column names and data types
3. Start with simple TrackingSpecs before adding complexity
4. Compare output to spec document: `TURAS_TRACKER_ENHANCEMENT.md`

## Questions to Answer During Testing

1. **Does backward compatibility work?**
   - Yes/No: Existing configs run without changes?

2. **Do enhanced ratings work?**
   - Yes/No: top_box, bottom_box, ranges calculate correctly?

3. **Does multi-mention work?**
   - Yes/No: Auto-detection finds columns?
   - Yes/No: Percentages look reasonable?

4. **Are error messages helpful?**
   - Yes/No: When you make a mistake, does validation help?

---

**Ready to test!** Start with the basic test script, then move to real data testing.
