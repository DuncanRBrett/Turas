# IPK Alchemer Build — Session 4 Handover

**Survey:** IPK Brand Health Wave 1
**Alchemer URL:** survey.alchemer.com/s3/8822527/IPK-Brand-Health-Wave-1
**Survey ID:** 8822527
**Date:** 2026-04-29

---

## Strategic shift — this session

**The IPK Alchemer survey is now the canonical template for the Turas brand module.** The old `generate_ipk_9cat_wave1.R` synthetic data generator is deprecated as a template example because:
- It is NOT compatible with the tabs module
- Real data exported from this Alchemer survey will be compatible with BOTH brand module and tabs module
- One AlchemerParser export feeds both analysis modules

The brand module will be rebuilt/validated using real IPK data from this survey.

---

## Current build status

### Pages 1–6: DONE
Admin, Intro, Qualifying, Screener, Target Window, Cross-Category Awareness.
Is_Dummy hidden field added to Admin page.

### DSS deep dive: structure built, Jess cleaning up

| Page | Status |
|---|---|
| DSS — CEP Matrix (BRANDATTR_DSS_CEP01–10) | Structure built |
| DSS — Attribute Matrix (BRANDATTR_DSS_ATTR01–10) | Structure built |
| DSS — Brand Attitude (BRANDATT1_DSS × 10) | Structure built |
| DSS — Rejection OE (BRANDATT2_DSS × 10) | Structure built |
| DSS — WOM (4 checkbox questions) | Structure built |
| DSS — WOM Count (continuous sum × 10 brands) | Structure built |
| DSS — Category Behaviour | Done |
| DSS — Brand Penetration 12m | Done |
| DSS — Brand Penetration 3m | Done |
| DSS — Purchase Frequency | Done |
| **DSS — Ad Hoc** | **STILL TO ADD** |

---

## Immediate next steps (new session)

1. **Add DSS — Ad Hoc placeholder**
   - Page name: `DSS — Ad Hoc`
   - Show logic: `Focal_Category = DSS`
   - Content: text/description element only — no questions
   - Text: `[AD HOC PLACEHOLDER — ADHOC_{KEY}_DSS format, show logic inherited from page]`

2. **Copy DSS block → POS, PAS, BAK**

   For each copy, change:
   - All page show logic: `Focal_Category = {CAT}`
   - All page names: `DSS —` → `{CAT} —`
   - All question aliases: `_DSS_` → `_{CAT}_` (and `_DSS` at end → `_{CAT}`)
   - Category name in all question text
   - Brand lists (all 10 + NONE per category)
   - CATCOUNT timeframe: **BAK = 6 months** (DSS/POS/PAS = 3 months)
   - CHANNEL/PACKSIZE SQ2 condition: `SQ2 option DSS` → `SQ2 option {CAT}`

3. **Build all-respondent tail**
   - Branded Reach (structure — no stimuli)
   - DBA — Brand Assets (5 assets × 2 questions)
   - Demographics (7 questions)

4. **Submit dummy record** via `?Is_Dummy=1` anonymous link — forces all piped columns into export

5. **Test via anonymous link**

---

## Key decisions made this session

### CEP + Attribute split
- Separate pages: DSS — CEP Matrix + DSS — Attribute Matrix
- 10 CEP slots (BRANDATTR_DSS_CEP01–10) + 10 ATTR slots (BRANDATTR_DSS_ATTR01–10) = 20 total
- Both pages: statements randomised at page level, brands randomised within each question

### BRANDPEN3 — continuous sum
- Question type: Continuous Sum (not 10 separate numeric questions)
- Rows piped from BRANDPEN2_DSS
- No required total
- Question text includes note: "If you bought more than one brand on the same shopping trip, count each brand separately"
- Can't hide running total in Alchemer — note in text is the workaround

### CATCOUNT — purchase occasions
- Ask about purchase occasions (shopping trips), NOT packs/units
- One trip buying 2 brands = 1 occasion (Ehrenberg-Bass/Romaniuk/NBD-Dirichlet standard)
- Wording: "...count each shopping trip where you bought them — even if you bought more than one brand on the same trip"

### Category Behaviour page consolidation
- CATBUY + CATCOUNT + CHANNEL + PACKSIZE on one page (DSS — Category Behaviour)
- CATBUY/CATCOUNT: page-level show logic only
- CHANNEL/PACKSIZE: individual show logic = SQ2 option DSS selected (recent buyers only)

### Dummy record
- Is_Dummy hidden field on Admin page (blank default)
- Submit via `?Is_Dummy=1` to mark test record
- Forces all piped columns (BRANDPEN2→3, WOM counts) into export
- Filter in prep_data.R: `data <- data[is.na(data$Is_Dummy) | data$Is_Dummy != 1, ]`

---

## Outstanding issues for new generator

When the new synthetic data generator is written to replace the old one, it must:
1. Use `BRANDATTR_{CAT}_CEP{NN}_{BRAND}` column naming (already fixed in old generator)
2. Use `BRANDATTR_{CAT}_ATTR{NN}_{BRAND}` column naming (already fixed in old generator)
3. Use `WOM_{TYPE}_{CAT}_{BRAND}` column naming — **WOM still uses old format `WOM_POS_REC_IPK` (no cat suffix). New generator must use `WOM_POS_REC_DSS_IPK` etc.**
4. Be structurally identical to the Alchemer export format
5. Be compatible with AlchemerParser → tabs module pipeline

---

## Reference files

- `modules/brand/docs/ALCHEMER_PROGRAMMING_SPEC.md` — canonical spec
- `modules/brand/docs/HANDOVER_IPK_ALCHEMER_SESSION4.md` — this file
- `modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R` — old generator (CEP/ATTR naming fixed, WOM still wrong)
