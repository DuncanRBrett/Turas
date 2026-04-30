# Alchemer CBM Survey — Minimal Single-Category Template

## Copy this. Extend by adding brands and CEPs. Don't delete — add.

**Version:** 1.0\
**Author:** The Research LampPost\
**How to use:** This is the starting point for any new single-category CBM project.\
- Replace `{CAT}` with your category code (e.g. `DSS`, `BEER`, `SHAMP`)\
- Replace `{CAT_LABEL}` with the category display name (e.g. "Dry Seasonings & Spices")\
- Replace `{BRAND_A}`, `{BRAND_B}` with real brand codes; add `{BRAND_C}` etc. by duplicating\
- Replace `{CEP01_TEXT}`, `{CEP02_TEXT}` with real CEP wording; add CEP03 etc. by duplicating\
- Replace `{CLIENT_BRAND}` with the focal brand code\
- Delete the `[TEMPLATE NOTE]` comments before handing to Jess

------------------------------------------------------------------------

## Survey settings (hidden variables — add on Page 1)

| Variable | Default value | Purpose |
|----|----|----|
| `Focal_Category` | `{CAT}` | Fixed for single-cat projects — all respondents get this value |
| `Wave` | `1` | Update to `2`, `3` etc. for subsequent waves. Set via URL param `?wave=1` |

------------------------------------------------------------------------

## Page 1: Intro & Consent

**No question aliases needed.**

Wording:\
*"Thank you for taking part in this study. We are researching how people shop for [general category description — do not name client]. This should take around [X] minutes. Your responses are completely confidential and will only be reported in aggregate. By continuing you confirm you are happy to participate."*

Button: **I agree — let's start**

------------------------------------------------------------------------

## Page 2: Screeners

### Design principle: SQ1 is always a checkbox

**Never use a Yes/No radio for SQ1.** Even single-Core projects include adjacent categories in the screener. This captures cross-category buying and enables the portfolio map. The checkbox always includes: - Core categories (those getting the full deep dive) - Adjacent categories (brand awareness only) - Peripheral categories if any (screener data only, no questions) - None of the above

------------------------------------------------------------------------

### Q1: SQ1 — long window screener (all categories)

| Field | Value |
|----|----|
| Question alias | `SQ1` |
| Question type | **Checkbox (multi-select)** |
| Question text | "In the last **12 months**, which of the following have you personally bought for your household? Please select all that apply." |

**Options — fill in your categories. Order: Core first, Adjacent second, Peripheral third, None last.**

| Option alias               | Option label      | Role     |
|----------------------------|-------------------|----------|
| `{CAT}`                    | {CAT_LABEL}       | **Core** |
| `{ADJ1}`                   | {ADJ1_LABEL}      | Adjacent |
| `{ADJ2}`                   | {ADJ2_LABEL}      | Adjacent |
| — add more adjacent here — |                   |          |
| `NONE`                     | None of the above | —        |

**Exported columns:** `SQ1_{CAT}`, `SQ1_{ADJ1}`, `SQ1_{ADJ2}` — value = 1 if selected, 0 if not. Matches QuestionMap directly.

**[TEMPLATE NOTE: Replace `{ADJ1}`, `{ADJ1_LABEL}` etc. with real adjacent category codes and labels. If there are no adjacent categories (rare), the checkbox still works with just one core option + NONE.]**

------------------------------------------------------------------------

### Q2: SQ2\_{CAT} — target window (Core category only)

| Field | Value |
|----|----|
| Question alias | `SQ2_{CAT}` |
| Question type | Radio button |
| **Show logic** | `SQ1` option `{CAT}` is selected |
| Question text | "And in the last **3 months**, have you bought **{CAT_LABEL}**?" |
| Option value / label | `1` / Yes · `0` / No |

**[TEMPLATE NOTE: Change "3 months" to match `Timeframe_Target` for this category. Adjacent categories do not get an SQ2 — 12-month qualification is sufficient for them.]**

------------------------------------------------------------------------

### Routing: Screen-out action

Add a **Disqualify Action** on Page 2:

-   **Disqualify if:** `SQ1` option `{CAT}` is NOT selected
-   **Message:** *"Thank you for your time. Unfortunately you do not meet the criteria for this study."*

Only the Core category option triggers qualification. Respondents who selected adjacent categories but not the Core are disqualified.

------------------------------------------------------------------------

## Page 3: Adjacent category brand awareness

**Show one question per Adjacent category, to respondents who selected it in SQ1.**

**[TEMPLATE NOTE: This page captures brand awareness for Adjacent categories. For a Core category, awareness is captured in the brand funnel (Page 5) — not here. If there are no adjacent categories, skip this page entirely.]**

### Q3: BRANDAWARE\_{ADJ1}

| Field | Value |
|----|----|
| Question alias | `BRANDAWARE_{ADJ1}` |
| Question type | Checkbox (multi-select) |
| **Show logic** | `SQ1` option `{ADJ1}` is selected |
| Question text | "Which of the following **{ADJ1_LABEL}** brands have you heard of — even if you have never bought them?" |

**Options — add one row per brand:**

| Option alias             | Option label           |
|--------------------------|------------------------|
| `{BRAND_A}`              | [Brand A display name] |
| `{BRAND_B}`              | [Brand B display name] |
| — add more brands here — |                        |
| `NONE`                   | None of these          |

**Exported columns:** `BRANDAWARE_{ADJ1}_{BRAND_A}`, `BRANDAWARE_{ADJ1}_{BRAND_B}`, ...

Duplicate this question for each additional Adjacent category (`BRANDAWARE_{ADJ2}`, etc.), changing the alias, show logic, and question wording.

**[ADD MORE ADJACENT CATEGORIES: Duplicate Q3 for each Adjacent. Update alias to `BRANDAWARE_{ADJ2}` etc. and show logic to `SQ1` option `{ADJ2}` selected.]**

------------------------------------------------------------------------

## Page 4: Category buying

### Q4: CATBUY\_{CAT}

| Field | Value |
|----|----|
| Question alias | `CATBUY_{CAT}` |
| Question type | Radio button |
| Question text | "In a typical month, how often do you buy **{CAT_LABEL}**?" |

| Option value | Option label                  |
|--------------|-------------------------------|
| `1`          | Several times a week          |
| `2`          | About once a week             |
| `3`          | A few times a month           |
| `4`          | Monthly or less               |
| `5`          | I no longer buy this category |

OptionMapScale: `cat_buy_scale`

------------------------------------------------------------------------

### Q5: CATCOUNT\_{CAT}

| Field | Value |
|----|----|
| Question alias | `CATCOUNT_{CAT}` |
| Question type | Text entry (numeric, integer, 0–99) |
| Question text | "Roughly how many times have you bought **{CAT_LABEL}** in the last **3 months**?" |

**[TEMPLATE NOTE: Change "3 months" to match Timeframe_Target.]**

------------------------------------------------------------------------

## Page 5: Brand funnel — attitude

**Intro text on page:** *"We'd now like to understand how you feel about each of the following {CAT_LABEL} brands. Please answer for each brand, even ones you don't use — just say 'no opinion' if you don't know a brand."*

### Q6: BRANDATT1\_{CAT}\_{BRAND_A}

| Field | Value |
|----|----|
| Question alias | `BRANDATT1_{CAT}_{BRAND_A}` |
| Question type | Radio button |
| Question text | "Which of the following best describes how you feel about **[Brand A name]**?" |

| Option value | Option label |
|----|----|
| `1` | I love it — it's my favourite |
| `2` | It's among the ones I prefer |
| `3` | I wouldn't usually consider it, but I would if no other option |
| `4` | I would refuse to buy this brand |
| `5` | I have no opinion / I don't know this brand |

OptionMapScale: `attitude_scale`

### Q7: BRANDATT2\_{CAT}\_{BRAND_A} — rejection OE

| Field | Value |
|----|----|
| Question alias | `BRANDATT2_{CAT}_{BRAND_A}` |
| Question type | Essay / open-end text |
| **Show logic** | `BRANDATT1_{CAT}_{BRAND_A}` = `4` |
| Question text | "You said you would refuse to buy **[Brand A name]**. In your own words, why is that?" |

------------------------------------------------------------------------

### Q8: BRANDATT1\_{CAT}\_{BRAND_B}

*(Duplicate Q6, change alias to `BRANDATT1_{CAT}_{BRAND_B}`, change brand name in wording)*

### Q9: BRANDATT2\_{CAT}\_{BRAND_B}

*(Duplicate Q7, change alias to `BRANDATT2_{CAT}_{BRAND_B}`, update show logic to `BRANDATT1_{CAT}_{BRAND_B}` = `4`)*

**[ADD MORE BRANDS: Duplicate Q6+Q7 pair for each additional brand. Update alias and show logic. Keep pairs together.]**

------------------------------------------------------------------------

## Page 6: Brand funnel — penetration

### Q10: BRANDPEN1\_{CAT}

| Field | Value |
|----|----|
| Question alias | `BRANDPEN1_{CAT}` |
| Question type | Checkbox (multi-select) |
| Question text | "Which of these **{CAT_LABEL}** brands have you personally bought in the last **12 months**?" |

**Options — same brands as BRANDAWARE:**

| Option alias        | Option label           |
|---------------------|------------------------|
| `{BRAND_A}`         | [Brand A display name] |
| `{BRAND_B}`         | [Brand B display name] |
| — add more brands — |                        |
| `NONE`              | None of these          |

**Exported columns:** `BRANDPEN1_{CAT}_{BRAND_A}`, `BRANDPEN1_{CAT}_{BRAND_B}`, ...

------------------------------------------------------------------------

### Q11: BRANDPEN2\_{CAT}

| Field          | Value                                                 |
|----------------|-------------------------------------------------------|
| Question alias | `BRANDPEN2_{CAT}`                                     |
| Question type  | Checkbox (multi-select)                               |
| Question text  | "And which have you bought in the last **3 months**?" |
| Options        | Same brands + NONE                                    |

**[TEMPLATE NOTE: Change "3 months" to Timeframe_Target.]**

**Exported columns:** `BRANDPEN2_{CAT}_{BRAND_A}`, `BRANDPEN2_{CAT}_{BRAND_B}`, ...

------------------------------------------------------------------------

### Q12: BRANDPEN3\_{CAT}\_{BRAND_A} — purchase frequency

| Field | Value |
|----|----|
| Question alias | `BRANDPEN3_{CAT}_{BRAND_A}` |
| Question type | Radio button |
| **Show logic** | `BRANDPEN2_{CAT}` option `{BRAND_A}` is selected |
| Question text | "When you buy **{CAT_LABEL}**, how often do you choose **[Brand A name]**?" |

| Option value | Option label                       |
|--------------|------------------------------------|
| `1`          | Every time                         |
| `2`          | Most times                         |
| `3`          | About half the time                |
| `4`          | Occasionally                       |
| `5`          | Rarely — this was a first purchase |

OptionMapScale: `purchase_freq_scale`

### Q13: BRANDPEN3\_{CAT}\_{BRAND_B}

*(Duplicate Q12, change alias and show logic to `BRANDPEN2_{CAT}` option `{BRAND_B}` is selected)*

**[ADD MORE BRANDS: Duplicate Q12 for each brand in BRANDPEN2. Update alias and show logic.]**

------------------------------------------------------------------------

## Page 7: CEP × brand matrix

**Intro text on page:** *"Now we'd like to understand which brands come to mind in different situations. For each situation, please select all brands that come to mind — even if you don't buy them."*

### Q14: BRANDATTR\_{CAT}\_CEP01

| Field          | Value                                       |
|----------------|---------------------------------------------|
| Question alias | `BRANDATTR_{CAT}_CEP01`                     |
| Question type  | Checkbox (multi-select)                     |
| Question text  | "{CEP01_TEXT} — which brands come to mind?" |

**Options — same brands as BRANDAWARE:**

| Option alias        | Option label           |
|---------------------|------------------------|
| `{BRAND_A}`         | [Brand A display name] |
| `{BRAND_B}`         | [Brand B display name] |
| — add more brands — |                        |
| `NONE`              | None of these          |

**Exported columns:** `BRANDATTR_{CAT}_CEP01_{BRAND_A}`, `BRANDATTR_{CAT}_CEP01_{BRAND_B}`, ...

------------------------------------------------------------------------

### Q15: BRANDATTR\_{CAT}\_CEP02

*(Duplicate Q14, change alias to `BRANDATTR_{CAT}_CEP02`, change question text to `{CEP02_TEXT}`)*

**[ADD MORE CEPs: Duplicate Q14 for each CEP. Update alias (CEP03, CEP04...) and question text. Aim for 10–15 CEPs per category.]**

------------------------------------------------------------------------

## Page 8: Purchase channels

### Q16: CHANNEL\_{CAT}

| Field | Value |
|----|----|
| Question alias | `CHANNEL_{CAT}` |
| Question type | Checkbox (multi-select) |
| **Show logic** | `SQ2_{CAT}` = `1` (only ask recent buyers) |
| Question text | "Where have you bought **{CAT_LABEL}** in the last **3 months**? Select all that apply." |

**Options — customise channel list per category:**

| Option alias | Option label                                   |
|--------------|------------------------------------------------|
| `SPMKT`      | Supermarket (Pick n Pay, Checkers, Woolworths) |
| `DISCNT`     | Discount / warehouse store (Game, Makro)       |
| `CORNER`     | Corner shop / spaza shop                       |
| `ONLINE`     | Online (takealot, woolworths.co.za, etc.)      |
| `FARM`       | Farm stall / deli / speciality store           |
| `OTHER`      | Other                                          |

**Exported columns:** `CHANNEL_{CAT}_SPMKT`, `CHANNEL_{CAT}_DISCNT`, ...

------------------------------------------------------------------------

## Page 9: Pack sizes

### Q17: PACKSIZE\_{CAT}

| Field | Value |
|----|----|
| Question alias | `PACKSIZE_{CAT}` |
| Question type | Checkbox (multi-select) |
| **Show logic** | `SQ2_{CAT}` = `1` |
| Question text | "Which pack sizes of **{CAT_LABEL}** have you bought in the last **3 months**? Select all that apply." |

| Option alias | Option label                  |
|--------------|-------------------------------|
| `SMALL`      | Small / single-serve          |
| `MEDIUM`     | Medium / standard family pack |
| `LARGE`      | Large / value pack            |
| `MULTI`      | Multi-pack / bulk buy         |

------------------------------------------------------------------------

## Page 10: Ad-hoc questions [OPTIONAL — OMIT IF NOT NEEDED]

**[TEMPLATE NOTE: Add any project-specific questions here. See ALCHEMER_PROGRAMMING_SPEC.md Section 13 for naming rules and how to register these in Survey_Structure.xlsx AdHoc sheet.]**

### Example: NPS (sample-wide)

| Field | Value |
|----|----|
| Question alias | `ADHOC_NPS` |
| Question type | Radio button |
| Shown to | All respondents |
| Question text | "How likely are you to recommend **[Client Brand]** to a friend or family member? (0 = Not at all likely, 10 = Extremely likely)" |
| Options | `0` through `10` |

### Example: Future purchase intent (always keep category-specific)

| Field | Value |
|----|----|
| Question alias | `ADHOC_FUTURE_{CAT}` |
| Question type | Radio button |
| Shown to | All respondents (it's already category-scoped via the alias) |
| Question text | "How likely are you to buy **[Client Brand]** {CAT_LABEL} in the next 3 months?" |
| Options | `1` Definitely will · `2` Probably will · `3` Might or might not · `4` Probably won't · `5` Definitely won't |

------------------------------------------------------------------------

## Page 11: Word of Mouth [TOGGLE: element_wom]

**[OMIT this page if `element_wom = N`]**

### Q18: WOM_POS_REC

| Field | Value |
|----|----|
| Question alias | `WOM_POS_REC` |
| Question type | Checkbox (multi-select) |
| Question text | "In the last **3 months**, has someone you know — in person, by message, or online — said something **positive** about any of these brands?" |

**Options — focal category brands only:**

| Option alias        | Option label           |
|---------------------|------------------------|
| `{BRAND_A}`         | [Brand A display name] |
| `{BRAND_B}`         | [Brand B display name] |
| — add more brands — |                        |
| `NONE`              | No, none of these      |

**[TEMPLATE NOTE: "3 months" should match `wom_timeframe` in Brand_Config Settings.]**

------------------------------------------------------------------------

### Q19: WOM_NEG_REC

*(Duplicate Q18, change alias to `WOM_NEG_REC`, change wording to "said something **negative**")*

### Q20: WOM_POS_SHARE

*(Duplicate Q18, change alias to `WOM_POS_SHARE`, change wording to "Have **you** said something **positive** about any of these brands to someone else?")*

### Q21: WOM_NEG_SHARE

*(Duplicate Q18, change alias to `WOM_NEG_SHARE`, change wording to "Have **you** said something **negative**...")*

------------------------------------------------------------------------

### Q22: WOM_POS_COUNT\_{BRAND_A}

| Field | Value |
|----|----|
| Question alias | `WOM_POS_COUNT_{BRAND_A}` |
| Question type | Radio button |
| **Show logic** | `WOM_POS_SHARE` option `{BRAND_A}` is selected |
| Question text | "How many times did you say something positive about **[Brand A name]** in the last **3 months**?" |
| Options | `1` Once · `2` Twice · `3` 3 times · `4` 4 times · `5` 5 or more |

OptionMapScale: `wom_count_scale`

### Q23: WOM_POS_COUNT\_{BRAND_B}

*(Duplicate Q22, change alias to `WOM_POS_COUNT_{BRAND_B}`, update show logic to `WOM_POS_SHARE` option `{BRAND_B}` is selected)*

### Q24–Q25: WOM_NEG_COUNT\_{BRAND_A/B}

*(Same pattern — show if `WOM_NEG_SHARE` option `{BRAND}` is selected)*

**[ADD MORE BRANDS: One WOM_POS_COUNT and one WOM_NEG_COUNT per brand.]**

------------------------------------------------------------------------

## Page 12: Distinctive Brand Assets [TOGGLE: element_dba — default OFF]

**[OMIT this page if `element_dba = N`. Enabling DBA adds approximately 2 minutes to survey length.]**

**[TEMPLATE NOTE: Replace ASSET codes and labels with your actual DBA list. One pair of questions (FAME + UNIQUE) per asset. Show each asset image/stimulus inline using Alchemer's media embed feature.]**

### Q26: DBA_FAME\_{ASSET1}

| Field          | Value                                                     |
|----------------|-----------------------------------------------------------|
| Question alias | `DBA_FAME_{ASSET1}`                                       |
| Question type  | Radio button                                              |
| Question text  | "Have you seen this before?" [embed asset image]          |
| Options        | `1` / Yes, I have seen this before · `2` / No, I have not |

OptionMapScale: `dba_fame_scale`

### Q27: DBA_UNIQUE\_{ASSET1}

| Field | Value |
|----|----|
| Question alias | `DBA_UNIQUE_{ASSET1}` |
| Question type | Essay / open-end text |
| Question text | "Which brand do you think this belongs to?" [embed same asset image] |

*(Repeat Q26+Q27 pair for each asset: ASSET2, ASSET3, etc.)*

------------------------------------------------------------------------

## Page 13: Branded Reach [TOGGLE: element_branded_reach — default OFF]

**[OMIT this page if `element_branded_reach = N`. This section is included in the template for future use — it is not active by default.]**

*(See ALCHEMER_PROGRAMMING_SPEC.md Section 15 for full question spec.)*

------------------------------------------------------------------------

## Page 14: Demographics

### Q28: DEMO_GENDER

| Field | Value |
|----|----|
| Question alias | `DEMO_GENDER` |
| Question type | Radio button |
| Question text | "What is your gender?" |
| Options | `1` Female · `2` Male · `3` Non-binary / prefer to self-describe · `99` Prefer not to say |

### Q29: DEMO_AGE

| Field | Value |
|----|----|
| Question alias | `DEMO_AGE` |
| Question type | Radio button |
| Question text | "What is your age?" |
| Options | `1` 18–24 · `2` 25–34 · `3` 35–44 · `4` 45–54 · `5` 55–64 · `6` 65+ |

### Q30: DEMO_PROVINCE

| Field | Value |
|----|----|
| Question alias | `DEMO_PROVINCE` |
| Question type | Radio button |
| Question text | "Which province do you currently live in?" |
| Options | `1` Gauteng · `2` Western Cape · `3` KwaZulu-Natal · `4` Eastern Cape · `5` Limpopo · `6` Mpumalanga · `7` Free State · `8` North West · `9` Northern Cape |

### Q31: DEMO_GROCERY_ROLE

| Field | Value |
|----|----|
| Question alias | `DEMO_GROCERY_ROLE` |
| Question type | Radio button |
| Question text | "What is your role in grocery shopping for your household?" |
| Options | `1` I do all or most of the grocery shopping · `2` I share grocery shopping equally · `3` Someone else does most of the grocery shopping |

### Q32: DEMO_HH_SIZE

| Field | Value |
|----|----|
| Question alias | `DEMO_HH_SIZE` |
| Question type | Radio button |
| Question text | "How many people live in your household, including yourself?" |
| Options | `1` Just me · `2` 2 people · `3` 3–4 people · `4` 5+ people |

### Q33: DEMO_EMPLOYMENT

| Field | Value |
|----|----|
| Question alias | `DEMO_EMPLOYMENT` |
| Question type | Radio button |
| Question text | "What is your current employment status?" |
| Options | `1` Employed full-time · `2` Employed part-time · `3` Self-employed · `4` Not currently employed · `5` Retired · `99` Prefer not to say |

### Q34: DEMO_SEM

| Field | Value |
|----|----|
| Question alias | `DEMO_SEM` |
| Question type | Radio button |
| Question text | "Which of the following best describes your household's total monthly income from all sources?" |
| Options | `1` Under R5,000 · `2` R5,000–R14,999 · `3` R15,000–R29,999 · `4` R30,000–R49,999 · `5` R50,000 or more · `99` Prefer not to say |

------------------------------------------------------------------------

## Page 15: Thank you

*"Thank you for completing this survey. Your responses are greatly appreciated and will help us understand the market better. [Panel redirect link if applicable]"*

------------------------------------------------------------------------

## Checklist before handing to Jess

-   [ ] All `{CAT}` placeholders replaced with real Core category code
-   [ ] All `{ADJ1}`, `{ADJ2}` replaced with real Adjacent category codes; additional adjacent categories added to SQ1 checkbox and Page 3
-   [ ] All `{BRAND_A}`, `{BRAND_B}` replaced with real brand codes; additional brands added
-   [ ] All `{CEP01_TEXT}`, `{CEP02_TEXT}` replaced with real CEP wording; additional CEPs added
-   [ ] `Wave` hidden variable default set to correct wave number
-   [ ] `Focal_Category` hidden variable set to correct category code (fixed value for single-cat)
-   [ ] SQ1 question alias is `SQ1` (not `SQ1_{CAT}`), question type is Checkbox, includes Core + Adjacent options
-   [ ] SQ2 show logic: `SQ1` option `{CAT}` is selected (not `SQ1_{CAT}` = 1)
-   [ ] Disqualify Action: `SQ1` option `{CAT}` is NOT selected
-   [ ] Rejection OE show logic correct for each brand
-   [ ] WOM count show logic correct for each brand
-   [ ] Export settings: question aliases as column names, numeric option values, separate checkbox columns
-   [ ] Survey tested end-to-end with test responses before launch
-   [ ] Survey_Structure.xlsx QuestionMap updated with all question aliases
-   [ ] Any ad-hoc questions registered in AdHoc sheet

------------------------------------------------------------------------

## Checklist: extending to a second or third category

If the project grows from single-cat to multi-cat (or if you add additional full categories):

1.  Update SQ1 from a Yes/No radio to a combined checkbox (see ALCHEMER_PROGRAMMING_SPEC.md Section 5)
2.  Add SQ2 questions for each new Tier 1 category
3.  Set up Distributed Logic Quotas for category assignment (Routing 2 in the full spec)
4.  Add a `Focal_Category` hidden variable and Set Value Actions based on quota assignment
5.  Duplicate Pages 4–10 for each new focal category, updating all `{CAT}` codes
6.  Add cross-category awareness questions for any new categories
7.  Update Brand_Config Categories sheet and Survey_Structure Brands/CEPs sheets

------------------------------------------------------------------------

*End of minimal template. For full multi-category setup, refer to ALCHEMER_PROGRAMMING_SPEC.md.*
