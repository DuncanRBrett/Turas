# IPK Alchemer Build — Session 2 Handover

**Survey:** IPK Brand Health Wave 1
**Alchemer URL:** survey.alchemer.com/s3/8822527/IPK-Brand-Health-Wave-1
**Survey ID:** 8822527
**Date:** 2026-04-28

---

## What's been built

| Page | Name | Status |
|---|---|---|
| 1 | Admin | Done — Wave (hidden textbox, default=1) + Focal_Category (hidden textbox) |
| 2 | Intro & Consent | Done |
| 3 | Qualifying Questions | Done — Gender, Age, Industry_Screen, Region + disqualify actions |
| 4 | Screener | Done — SQ1 (9 categories), HVA + JS focal assignment |
| 5 | Target Window | Done — SQ2 with option-level show logic |
| 6 | Cross-Category Brand Awareness | Done — see below |

---

## Page 6 — final design decision

All 9 brand awareness questions are on ONE page. Question order is fixed:

1. BRANDAWARE_SLD
2. BRANDAWARE_STO
3. BRANDAWARE_PES
4. BRANDAWARE_COO
5. BRANDAWARE_ANT
6. BRANDAWARE_DSS
7. BRANDAWARE_POS
8. BRANDAWARE_PAS
9. BRANDAWARE_BAK

**Show logic on each:** `SQ1 includes [CAT]` — NO Focal_Category condition.

**Why:** Adjacent categories always appear before core categories, which reduces (but does not eliminate) the risk of focal category being answered before non-focal. The alternative (Page 6b split with duplicate aliases) created two columns per category in the export. One alias = one column is the hard requirement.

**Reporting values = brand codes** (e.g., IPK, KNORR, RAJAH). Brands randomised, NONE pinned at bottom.

**The deep dive does NOT repeat brand awareness.** Awareness is fully resolved on Page 6.

---

## What to build next — DSS deep dive (Page 7)

Show logic on all questions: `Focal_Category = DSS`

Build in this order (Romaniuk):

| # | Alias | Type | Notes |
|---|---|---|---|
| 1 | BRANDATTR_DSS_CEP01–CEP04 | Checkbox grid × brands | CEPs + attributes together. See brand list below. |
| 2 | BRANDATT1_DSS | Scale grid × brands | Brand attitude battery 1 |
| 3 | BRANDATT2_DSS | Scale grid × brands | Brand attitude battery 2 |
| 4 | WOM_DSS | Per spec | 5 question types |
| 5 | REACH_DSS | Per spec | Branded Reach |
| 6 | CATBUY_DSS | Radio | Category buying frequency |
| 7 | CATCOUNT_DSS | Radio | Purchase count |
| 8 | BRANDPEN1_DSS | Checkbox × brands | Consideration |
| 9 | BRANDPEN2_DSS | Checkbox × brands | Preference |
| 10 | BRANDPEN3_DSS | Checkbox × brands | Usage |
| 11 | CHANNEL_DSS | Checkbox | Purchase channel |
| 12 | PACKSIZE_DSS | Checkbox | Pack size |

After DSS, copy the block for POS (Page 8), PAS (Page 9), BAK (Page 10) — updating show logic and brand lists.

---

## DSS brand list (10 brands + NONE)

IPK, ROB, KNORR, CART, RAJAH, SFRI, SPMEC, WWTDSS, PNPDSS, CKRDSS, NONE

Brands randomised. NONE pinned at bottom. Reporting values = brand codes.

## DSS CEPs/Attributes (4 confirmed, up to 15 slots)

| Alias suffix | Text |
|---|---|
| CEP01 | To add flavour to a meal |
| CEP02 | To experiment with a new dish |
| CEP03 | Is good value for money |
| CEP04 | Is proudly South African |

---

## All brand lists

| Category | Brands |
|---|---|
| DSS | IPK, ROB, KNORR, CART, RAJAH, SFRI, SPMEC, WWTDSS, PNPDSS, CKRDSS |
| POS | IPK, KNORR, ROYCO, MAGGI, SWISS, BISTO, WWPOS, HOLLS, PNPPOS, CKRPOS |
| PAS | IPK, KNORR, DOLMIO, ALGLD, FATTS, BARLA, SDEL, WWPAS, PNPPAS, CKRPAS |
| BAK | IPK, INNAS, BAKELS, PILLSB, MOLLY, LANCL, WWBAK, PNPBAK, CKRBAK, SIMBOL |
| SLD | IPK, ALGLD, KRAFT, BULLS, NEWMN, BALEA, WWSLD, PNPSLD, CKRSLD, AMANU |
| STO | IPK, KNORR, MAGGI, ROYCO, SCHWTZ, NATST, WWSTO, PNPSTO, CKRSTO, ARTSTO |
| PES | IPK, BARLA, SACLA, BUONIT, NATFSH, PONTI, WWPES, PNPPES, CKRPES, ARTPST |
| COO | IPK, KNORR, ROYCO, DOLMIO, NDOS, SMAC, WWCOO, PNPCOO, CKRCOO, TASTY |
| ANT | IPK, BARLA, SACLA, PONTI, BUONIT, DELLAS, WWANT, PNPANT, CKRANT, ARTANT |

All lists: brands randomised, NONE pinned at bottom, reporting values = brand codes.

---

## Key technical facts for new session

- **Focal assignment:** JS script on Screener page randomly picks 1 Core category from SQ1 selections, writes to HVA (ID:12). Script in ALCHEMER_PROGRAMMING_SPEC.md Section 7. DO NOT use double-quotes in JS strings.
- **Testing:** Use Share → Anonymous link, NOT test mode (JS suppressed in test mode).
- **Reporting values:** Set by pasting brand codes into the bulk-paste field in Alchemer option editor.
- **AlchemerParser output:** BRANDAWARE_DSS_1…_10 (sequential suffix, value = brand code when selected).
- **Brand module normalization:** normalize_brandaware_columns() in 00_main.R renames _N → _BRANDCODE columns and recodes values to 1. To be implemented post-build.
- **WOM spec:** In ALCHEMER_PROGRAMMING_SPEC.md (5 question types, timeframe likely 3 months — confirm before building).
- **BRANDATTR alias convention:** All CEPs and attributes use BRANDATTR_{CAT}_CEP0N — even if some items are technically brand attributes not CEPs. This matches the synthetic data fixture.

---

## Reference files

- `modules/brand/docs/ALCHEMER_PROGRAMMING_SPEC.md` — canonical spec, question aliases, show logic, JS scripts
- `modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R` — synthetic data generator (DO NOT MODIFY)
- `modules/brand/docs/HANDOVER_IPK_ALCHEMER_SESSION2.md` — this file
