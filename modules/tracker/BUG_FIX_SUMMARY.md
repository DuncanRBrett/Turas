# Critical Bug Fix: TrackingSpecs Not Working in GUI

## The Problem

When using the Turas GUI with "Use Banners" checkbox enabled:
- Q45 with `TrackingSpecs: category:Last week, category:Last 2 weeks` showed **ALL** response options instead of just the 2 selected
- This was working correctly before switching to the GUI

## Root Cause

The GUI has two code paths depending on the "Use Banners" checkbox:

### Path 1: Use Banners = UNCHECKED (default)
- Calls `calculate_all_trends()`
- Uses `calculate_single_choice_trend_enhanced()` ✓ Respects TrackingSpecs

### Path 2: Use Banners = CHECKED
- Calls `calculate_trends_with_banners()`
- Was calling `calculate_single_choice_trend()` ❌ **OLD version, ignores TrackingSpecs!**

## The Fix

**File:** `modules/tracker/banner_trends.R`
**Line:** 204

**Before:**
```r
} else if (q_type == "single_choice") {
  calculate_single_choice_trend(q_code, question_map, wave_data, config)
```

**After:**
```r
} else if (q_type == "single_choice") {
  # Use enhanced version (supports TrackingSpecs, backward compatible)
  calculate_single_choice_trend_enhanced(q_code, question_map, wave_data, config)
```

## How to Test

1. **Pull latest code in GitHub Desktop**
   - Branch: `claude/enhance-turas-tracker-01C8RSooxw5QTbAGN74VjZzh`
   - Click "Pull origin"

2. **Run tracker from Turas GUI** with these settings:
   - Use Banners: **CHECKED** (this was the bug)
   - Q45 TrackingSpecs: `category:Last week, category:Last 2 weeks`

3. **Expected Results:**
   - Detailed tracker: Shows rows for **BOTH** "Last week" AND "Last 2 weeks" (not all options)
   - Wave History: Shows **TWO** rows for Q45 (one for each category)

## Additional Fixes in This Commit

Also fixed logical indexing bug in line 409 (and 269) where collecting all response codes could cause "condition has length > 1" error.

## Why It Was Hard to Find

The bug only occurred when:
- Using the GUI **AND**
- "Use Banners" checkbox was **CHECKED**

Command-line usage and GUI with unchecked banners worked fine, which is why testing from the command line didn't reveal the issue.

## Status

- ✓ Fix committed and pushed
- ✓ Ready for testing
- ✓ Should fix both detailed tracker and wave history outputs
