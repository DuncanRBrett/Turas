# Q45 Multi-Category Tracking - FINAL FIX

## Issue Summary

When using TrackingSpecs with multiple categories:
```
Q45: category:Last week, category:Last 2 weeks
```

**Problem 1:** Wave History showed ALL response options instead of just the 2 selected
**Problem 2:** Detailed tracker showed only "Last week" instead of both categories

## Root Causes

### Wave History Issue (FIXED)
- **File:** `modules/tracker/banner_trends.R` line 204
- **Problem:** When "Use Banners" checkbox was enabled in GUI, code called OLD `calculate_single_choice_trend()` function that ignores TrackingSpecs
- **Fix:** Changed to use `calculate_single_choice_trend_enhanced()` which respects TrackingSpecs

### Detailed Tracker Issue (FIXED)
- **File:** `modules/tracker/tracker_output.R` line 924 (new code)
- **Problem:** The `write_banner_trend_table()` function had NO case for handling proportions metric type
- **Fix:** Added full proportions handling that loops through all response_codes and writes a row for each

## Commits

1. **fd9fd68** - Fix banner_trends to use enhanced single_choice function
2. **dbd9b03** - Fix logical indexing in all_codes collection
3. **60f1a78** - Fix 'condition has length > 1' error in wave history
4. **5e83967** - Add proportions support to banner trend table

## Testing Instructions

1. **Pull latest code** in GitHub Desktop
   - Branch: `claude/enhance-turas-tracker-01C8RSooxw5QTbAGN74VjZzh`

2. **Run tracker from GUI** with:
   - Use Banners: **CHECKED**
   - Q45 TrackingSpecs: `category:Last week, category:Last 2 weeks`

3. **Expected Results:**
   - ✅ Wave History: Shows 2 rows for Q45 (one for each category)
   - ✅ Detailed Tracker: Shows 2 rows under Q45 (both "Last week" and "Last 2 weeks")

## Status

- ✅ Wave History: **WORKING** (user confirmed)
- ✅ Detailed Tracker: **SHOULD BE FIXED** (needs testing)
- ❌ Q10 Multi_Mention: Still has issues (see Q10_ISSUES.md)

## Q10 Remaining Issues

User reports:
1. With `option:Q10_4` - gets error
2. With blank TrackingSpecs - gets 7 options but:
   - Labels show "Q10" instead of option names
   - All values show as 0

These are separate issues documented in Q10_ISSUES.md for follow-up.
