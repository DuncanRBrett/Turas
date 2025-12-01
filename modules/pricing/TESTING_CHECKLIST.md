# Pricing Module Testing Checklist

**Branch**: `claude/pricing-module-review-01N4UG5NMs3BCuSFCUFuZY3j`
**Date**: _________________
**Tester**: _________________

---

## Pre-Test Setup (5 minutes)

- [ ] Navigate to `modules/pricing/test_projects/`
- [ ] Run: `Rscript setup_all_projects.R`
- [ ] Verify 3 folders created: `consumer_electronics/`, `saas_subscription/`, `retail_product/`
- [ ] Check each folder has: `data.csv` and `config.xlsx`

**Optional**: Move test projects to OneDrive projects folder for real-world testing

---

## Test 1: Consumer Electronics - Phase 1 Features (10 minutes)

**Project**: Smart Speaker (Van Westendorp only)

- [ ] Launch Turas GUI
- [ ] Select `consumer_electronics` project
- [ ] Navigate to Pricing module
- [ ] **Load Config**: Click "Load Config" and verify all settings load correctly
- [ ] **Run Analysis**: Click "Run Pricing Analysis"

### Verify Results:

- [ ] VW plot displays correctly (4 curves)
- [ ] Optimal price range appears: $75-$95 expected
- [ ] Point of Marginal Cheapness/Expensiveness shown
- [ ] **Diagnostics tab** shows:
  - [ ] Response validation (should see some DK exclusions)
  - [ ] Monotonicity check results (some violations expected)
  - [ ] Weighted sample size: ~300 respondents
- [ ] **Excel Output**: Download and verify Summary sheet shows weight statistics

### Phase 1 Features Verified:
- [ ] Survey weighting working
- [ ] DK code handling working
- [ ] Monotonicity detection working

---

## Test 2: SaaS Subscription - Phase 2 Profit Optimization (10 minutes)

**Project**: Cloud Analytics Platform (Gabor-Granger with profit)

- [ ] Launch Turas GUI (or switch project)
- [ ] Select `saas_subscription` project
- [ ] Navigate to Pricing module
- [ ] **Load Config**: Verify unit_cost = $18.00 loads
- [ ] **Run Analysis**: Click "Run Pricing Analysis"

### Verify Results:

- [ ] GG demand curve displays
- [ ] **Revenue-Maximizing Price** shown: ~$59 expected
- [ ] **Profit-Maximizing Price** shown: ~$69 expected (higher than revenue-max!)
- [ ] **Additional Plots tab** shows:
  - [ ] Profit curve (purple) displayed
  - [ ] Revenue vs Profit comparison plot displayed
- [ ] **Profit table** shows:
  - [ ] Profit Index value
  - [ ] Margin calculation (Price - Cost)
- [ ] **Excel Output**: Verify separate sheets for Revenue-Max and Profit-Max

### Phase 2 Features Verified:
- [ ] Profit optimization working
- [ ] Unit cost integration working
- [ ] Revenue vs Profit tradeoff visible

---

## Test 3: Retail Product - Both Methods (10 minutes)

**Project**: Premium Coffee Maker (VW + GG combined)

- [ ] Launch Turas GUI (or switch project)
- [ ] Select `retail_product` project
- [ ] Navigate to Pricing module
- [ ] **Load Config**: Verify both VW and GG sections load
- [ ] **Run Analysis**: Click "Run Pricing Analysis"

### Verify Results:

- [ ] **Main Plot**: Shows VW optimal range
- [ ] **Additional Plots tab** shows:
  - [ ] GG demand curve
  - [ ] Method convergence comparison
- [ ] **Results Summary** shows:
  - [ ] VW optimal range: $140-$160 expected
  - [ ] GG optimal price: ~$150 expected
  - [ ] Methods converge (good sign!)
- [ ] **Excel Output**: Verify both VW and GG sheets present

### Both Methods Verified:
- [ ] VW analysis working
- [ ] GG analysis working
- [ ] Combined output working
- [ ] Method comparison working

---

## Edge Cases & Error Handling (Optional - 10 minutes)

- [ ] **Load invalid config**: Try loading a non-pricing config → Should show clear error
- [ ] **Missing cost**: Remove unit_cost from config, reload → Profit tab should hide
- [ ] **Invalid price point**: Edit data to have negative price → Should show validation error
- [ ] **Empty segments**: Try segment analysis with invalid segment variable → Should handle gracefully

---

## GUI Compatibility Checks (5 minutes)

- [ ] **Console output**: Check R console for any warnings/errors
  - [ ] No renderText() deprecation warnings
  - [ ] No unexpected error messages
- [ ] **Tab switching**: Switch between all tabs rapidly → No crashes
- [ ] **Multiple runs**: Run same analysis 3 times → Consistent results
- [ ] **Project switching**: Switch between projects without restarting GUI → Works correctly

---

## Documentation Spot Check (5 minutes)

- [ ] **QUICK_START.md**: Open and verify formatting looks good
- [ ] **TUTORIAL.md**: Skim through, verify code examples present
- [ ] **Test project READMEs**: Check one project README for completeness

---

## Final Sign-Off

### Critical Issues Found:
- [ ] None - Ready to merge to main ✓
- [ ] Issues found (describe below):

**Issue Description**:
```
(Describe any critical issues that would block merge)
```

---

### Non-Critical Issues Found:
```
(List minor issues for future improvement)
```

---

## Merge Decision

- [ ] **APPROVED**: All critical features working, ready to merge to main
- [ ] **NEEDS WORK**: Critical issues found, fix before merging

**Signature**: _________________ **Date**: _________________

---

## Post-Test Cleanup

- [ ] **If testing in current folder**: Delete test projects or keep for reference
- [ ] **If testing in OneDrive**: Delete test projects after successful merge
- [ ] **Save checklist**: Keep this filled checklist for documentation

---

**Estimated Total Time**: 30-40 minutes
**Questions?**: Review TUTORIAL.md or QUICK_START.md for additional help
