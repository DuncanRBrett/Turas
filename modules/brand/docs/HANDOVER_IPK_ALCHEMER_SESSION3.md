# IPK Alchemer Build — Session 3 Handover

**Survey:** IPK Brand Health Wave 1
**Alchemer URL:** survey.alchemer.com/s3/8822527/IPK-Brand-Health-Wave-1
**Survey ID:** 8822527
**Date:** 2026-04-29

---

## What's been built

| Page | Name | Status |
|---|---|---|
| 1 | Admin | Done |
| 2 | Intro & Consent | Done |
| 3 | Qualifying Questions | Done |
| 4 | Screener | Done |
| 5 | Target Window | Done |
| 6 | Cross-Category Brand Awareness | Done |
| DSS — CEP Matrix | BRANDATTR_DSS_CEP01–04 | Structure built, brands/statements NOT yet filled in |
| DSS — Brand Attitude | BRANDATT1_DSS × 10 brands | Structure built, brands NOT yet filled in |
| DSS — Rejection OE | BRANDATT2_DSS × 10 brands | Structure built, brands NOT yet filled in |
| DSS — WOM | WOM_POS_REC/NEG_REC/POS_SHARE/NEG_SHARE | Structure built, brands NOT yet filled in |
| DSS — WOM Count | WOM_POS_COUNT/NEG_COUNT × 10 brands | Structure built, brands NOT yet filled in |

**Next to build (when Jess is done filling in brands):**
- DSS — Category Buying (CATBUY_DSS + CATCOUNT_DSS)
- DSS — Brand Penetration (BRANDPEN1_DSS + BRANDPEN2_DSS)
- DSS — Purchase Frequency (BRANDPEN3_DSS × 10 brands)
- DSS — Channels & Pack Sizes (CHANNEL_DSS + PACKSIZE_DSS)
- Then copy full DSS block → POS (Page 8), PAS (Page 9), BAK (Page 10)
- Then all-respondent tail: Ad-hoc, DBA, Demographics

---

## Key decisions made this session

### Page naming convention
Use content-based names, NOT numbered (e.g. "DSS — CEP Matrix", not "DSS Deep Dive Pg1").
When copying to POS/PAS/BAK: find-replace "DSS —" with "POS —" etc.

Full DSS page structure:

| Page name | Contents |
|---|---|
| DSS — CEP Matrix | BRANDATTR_DSS_CEP01–04 |
| DSS — Brand Attitude | BRANDATT1_DSS × 10 brands |
| DSS — Rejection OE | BRANDATT2_DSS × 10 brands (conditional) |
| DSS — WOM | WOM_POS_REC/NEG_REC/POS_SHARE/NEG_SHARE |
| DSS — WOM Count | WOM_POS_COUNT/NEG_COUNT × 10 brands (conditional) |
| *(REACH omitted — see below)* | |
| DSS — Category Buying | CATBUY_DSS + CATCOUNT_DSS |
| DSS — Brand Penetration | BRANDPEN1_DSS + BRANDPEN2_DSS |
| DSS — Purchase Frequency | BRANDPEN3_DSS × 10 brands (conditional) |
| DSS — Channels & Pack Sizes | CHANNEL_DSS + PACKSIZE_DSS |

### Question labels
Set each question label to alias + descriptor. E.g. `BRANDATT1_DSS_IPK — Attitude`. Helps navigation in builder and in logic builder dropdowns.

### CEP matrix (BRANDATTR)
- Each CEP is a SEPARATE checkbox question (one per statement, brands as options)
- CEP statement ORDER is randomised at page level (page settings → Layout → Randomize Questions)
- Brand options within each CEP are randomised (NONE pinned at bottom)
- Page intro text is a text/instruction element (not a question) so it stays pinned at top during randomisation

### Brand attitude (BRANDATT1 + BRANDATT2)
- SEPARATE radio question per brand (NOT a grid/matrix) — required for clean rejection OE logic and mobile rendering
- BRANDATT1: all 10 on one page (DSS — Brand Attitude), question order randomised at page level
- BRANDATT2 rejection OEs: separate page (DSS — Rejection OE)
- Page-level show logic on DSS — Rejection OE: show if ANY of the 10 BRANDATT1 = 4

### WOM
- **Timeframe: 3 months** (confirmed)
- **WOM_NEG_SHARE_DSS is required** (confirmed)
- 5 question types: WOM_POS_REC_DSS, WOM_NEG_REC_DSS, WOM_POS_SHARE_DSS, WOM_NEG_SHARE_DSS, WOM_POS/NEG_COUNT_DSS per brand
- Count questions on SEPARATE page (DSS — WOM Count)
- Page-level show logic on DSS — WOM Count: WOM_POS_SHARE_DSS option NONE is NOT selected OR WOM_NEG_SHARE_DSS option NONE is NOT selected
- WOM aliases include category suffix: WOM_POS_REC_DSS, WOM_POS_COUNT_DSS_IPK etc.

### Branded Reach
- **OMITTED from Wave 1** — the spec correctly says "NOT IN IPK WAVE 1"
- Do NOT build a placeholder — risk of blank page hit if show logic wrong
- Add to Wave 2 copy when ad stimuli are ready

### CATCOUNT wording — purchase occasions not units
Romaniuk/Ehrenberg-Bass framework uses purchase occasions (shopping trips), not units/packs.
One trip where two brands are bought = ONE occasion (consistent with Kantar Worldpanel trips metric and NBD-Dirichlet model inputs).

**Confirmed CATCOUNT_DSS question text:**
> "Thinking about the last **3 months**, approximately how many different times have you bought **dry seasonings & spices**? Please count each shopping trip where you bought them — even if you bought more than one brand on the same trip."

CATBUY (frequency scale) and CATCOUNT (occasion count) cross-validate in analysis — large discrepancies flag data quality issues.

---

## DSS brand list reminder

IPK, ROB, KNORR, CART, RAJAH, SFRI, SPMEC, WWTDSS, PNPDSS, CKRDSS
(+ NONE pinned at bottom, all brands randomised)

## DSS CEPs reminder

| Alias | Statement |
|---|---|
| CEP01 | To add flavour to a meal |
| CEP02 | To experiment with a new dish |
| CEP03 | Is good value for money |
| CEP04 | Is proudly South African |

## CATCOUNT timeframes by category

| Category | Timeframe |
|---|---|
| DSS | 3 months |
| POS | 3 months |
| PAS | 3 months |
| BAK | **6 months** |

---

## Reference files

- `modules/brand/docs/ALCHEMER_PROGRAMMING_SPEC.md` — canonical spec
- `modules/brand/docs/HANDOVER_IPK_ALCHEMER_SESSION2.md` — previous session
- `modules/brand/docs/HANDOVER_IPK_ALCHEMER_SESSION3.md` — this file
