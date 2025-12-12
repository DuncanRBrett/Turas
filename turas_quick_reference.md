# Turas Conjoint Module - Quick Reference for Sonnet 4.5

## Files to Create/Modify

| File | Action | Priority |
|------|--------|----------|
| 05_alchemer_import.R | CREATE | Phase 1 |
| 03_analysis.R | MODIFY (add mlogit) | Phase 1 |
| 06_simulator.R | CREATE | Phase 2 |
| 04_output.R | MODIFY (8 sheets) | Phase 2 |
| 01_config.R | MODIFY (new settings) | Phase 1 |
| 00_main.R | MODIFY (orchestration) | Phase 2 |

## Alchemer → Turas Column Mapping

| Alchemer | Turas | Notes |
|----------|-------|-------|
| ResponseID | resp_id | Integer |
| SetNumber | (part of choice_set_id) | Combined with ResponseID |
| CardNumber | alternative_id | 1, 2, 3 typically |
| Score | chosen | Normalize: >0 → 1, else 0 |
| [Attributes] | [Attributes] | Clean level names |

## Key mlogit Code Pattern

```r
library(mlogit)

# 1. Prepare data
mlogit_df <- mlogit.data(
  df,
  choice = "chosen",
  shape = "long",
  alt.var = "alternative_id",
  chid.var = "choice_set_id",
  id.var = "resp_id"
)

# 2. Fit model (| 0 suppresses ASCs)
model <- mlogit(chosen ~ Price + Brand + ... | 0, data = mlogit_df)

# 3. Extract results
coefs <- coef(model)
se <- sqrt(diag(vcov(model)))
ll <- model$logLik
```

## Expected Output Structure (8 Sheets)

1. **Market Simulator** - Interactive what-if tool
2. **Attribute Importance** - Ranked % importance
3. **Part-Worth Utilities** - Zero-centered utilities
4. **Utility Chart Data** - For Excel charting
5. **Model Fit** - R², hit rate, AIC, BIC
6. **Configuration** - Study design
7. **Raw Coefficients** - Uncentered with SEs
8. **Data Summary** - N, completion rates

## Validation Targets (DE Noodle Data)

| Attribute | Expected Importance |
|-----------|-------------------|
| NutriScore | 50-65% |
| Price | 10-20% |
| MSG | 8-15% |
| PotassiumChloride | 5-12% |
| I+G | 3-10% |
| Salt | 2-8% |

**Critical**: All attributes must show NON-ZERO importance.
If any shows 0%, check for multicollinearity or data issues.

## Market Simulator Formulas

```excel
# Total Utility (sum of VLOOKUPs)
=VLOOKUP(B7,UtilityTable,3,FALSE)+VLOOKUP(C7,UtilityTable,3,FALSE)+...

# Exp(Utility)
=EXP(H7)

# Market Share
=I7/SUM($I$7:$I$16)
```

## Testing Checklist

- [ ] Alchemer import produces correct row count
- [ ] All 6 attributes detected
- [ ] Level names cleaned properly
- [ ] mlogit model converges
- [ ] All attributes have non-zero importance
- [ ] Utilities zero-center (sum to ~0 per attribute)
- [ ] Market simulator dropdowns work
- [ ] Share calculations sum to 100%
