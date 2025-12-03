# Confidence Module Basic Example

**Purpose:** Example for TURAS Confidence module (confidence intervals, MOE, DEFF)

**Status:** Working mock implementation

---

## Dataset Description

**Sample Size:** 100 respondents

**Variables:**
- `respondent_id` - Unique ID (1-100)
- `age_group` - 18-34, 35-54, 55+
- `region` - North, South, East, West
- `support_policy` - Binary (0/1), ~67% support
- `satisfaction` - Rating 5-9, mean ~7.3
- `weight` - Sampling weight (0.8-1.2)

---

## Calculations Tested

### Proportions (support_policy)
- Proportion supporting: ~67%
- MOE (unweighted): ~9.2%
- MOE (weighted): ~9.3%
- Wilson score CI: [57.1%, 75.7%]
- Design Effect (DEFF): ~1.015
- Effective N: ~98.5

### Means (satisfaction)
- Mean: ~7.3
- 95% CI: [7.03, 7.57]
- Standard error: ~0.14

---

## How to Run

```r
# From TURAS root
source("tests/regression/test_regression_confidence_mock.R")
```

**Expected:** All 12 checks pass ✅

---

**Created:** 2025-12-02
**TURAS Version:** 10.0
**Module:** Confidence (CIs, MOE, DEFF)
