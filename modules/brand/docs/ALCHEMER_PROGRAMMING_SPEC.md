# Alchemer Programming Specification

## Turas Brand Module — Category Buyer Metrics (CBM) Template

**Version:** 1.1\
**Author:** The Research LampPost\
**Audience:** Survey programmer (Jess)\
**Reference project:** Ina Paarman's Kitchen Brand Health Wave 1

------------------------------------------------------------------------

## 1. Purpose and how to use this document

This document is the complete programming brief for any Turas Brand Module CBM survey. It tells you exactly what questions to programme, what to name them, and how to set up the routing logic in Alchemer.

### How routing works in Alchemer — read this first

Almost all survey routing uses **Alchemer's built-in Logic system** — no scripting needed. Lua/Custom Scripts are a last resort for logic the built-in system cannot handle.

| Routing need | How to handle it in Alchemer |
|----|----|
| Screen out wrong demographics (gender, age) | Built-in: **Disqualify Action** on qualifying questions page |
| Screen out industry workers | Built-in: **Disqualify Action** on qualifying questions page |
| Screen out non-metro respondents | Built-in: **Disqualify Action** on qualifying questions page |
| Screen out unqualified category buyers | Built-in: **Disqualify Action** on the screener page |
| Assign respondent to a focal category | **JavaScript Action** + **Hidden Value Action** on screener page (see Section 7) |
| Show questions only to certain respondents | Built-in: **Show/Hide Logic** on the question |
| Show SQ2 options filtered by SQ1 | Built-in: **Option-level Logic** on each SQ2 option |
| Show rejection OE only when attitude = Reject | Built-in: **Show Logic** on the OE question |
| Show WOM count only when WOM was shared | Built-in: **Show Logic** on the count question |
| Show cross-cat awareness only if they bought it | Built-in: **Show Logic** on each awareness block |

Each of these is set up through Alchemer's **Logic tab** on the question or action — no code required. The sections below walk through each one step by step.

**IPK** is the reference implementation (9 categories). Most projects will have **one category only** — where this matters, you will see a `SINGLE-CAT` note.

Every question has a **question code** that must be used as the Alchemer question alias exactly as written. The Alchemer CSV export column names depend on this. If the alias is wrong the report will not run.

### Template toggles

Each section is controlled by an on/off toggle in the `Brand_Config.xlsx` Settings sheet. The toggle name is shown at the top of each section (e.g. `element_wom`). If that element is not in scope for a project, set its toggle to `N` — then skip that entire section when programming.

| Section | Toggle in Brand_Config | Default |
|----|----|----|
| Screeners | Always on | — |
| Cross-category awareness | `cross_category_awareness` | Y |
| Category buying | Always on | — |
| Brand funnel | `element_funnel` | Y |
| CEP × brand matrix | `element_mental_avail` | Y |
| Purchase channels | *(no toggle — included with cat buying)* | Y |
| Pack sizes | *(no toggle — included with cat buying)* | Y |
| Ad-hoc questions | *(no toggle — omit section if no ad-hoc qs)* | — |
| WOM | `element_wom` | Y |
| DBA | `element_dba` | N |
| Branded Reach | `element_branded_reach` | N |
| Portfolio (cross-cat awareness) | `element_portfolio` | Y |
| Demographics | Always on | — |

------------------------------------------------------------------------

## 2. Core naming conventions

**These rules are non-negotiable.** The Turas report engine reads column names from the exported CSV to find each question. If the name is wrong the analysis will fail silently or with an error.

### 2.1 Category codes

Each category has a short uppercase code used in all column names.

| Category | Code | Role | What happens |
|----|----|----|----|
| Dry Seasonings & Spices | `DSS` | **Core** | Full CBM deep dive + focal assignment |
| Pour Over Sauces | `POS` | **Core** | Full CBM deep dive + focal assignment |
| Pasta Sauces | `PAS` | **Core** | Full CBM deep dive + focal assignment |
| Baking Mixes | `BAK` | **Core** | Full CBM deep dive + focal assignment |
| Salad Dressings | `SLD` | **Adjacent** | Brand awareness only (if respondent qualifies) |
| Stock Powder / Liquid | `STO` | **Adjacent** | Brand awareness only (if respondent qualifies) |
| Pestos | `PES` | **Adjacent** | Brand awareness only (if respondent qualifies) |
| Cook-in Sauces | `COO` | **Adjacent** | Brand awareness only (if respondent qualifies) |
| Anti-pasta | `ANT` | **Adjacent** | Brand awareness only (if respondent qualifies) |

**Category roles — what they mean:**

| Role | `Analysis_Depth` in Brand_Config | Description |
|----|----|----|
| **Core** | `full` | Respondents are assigned to one Core category as their focal category. Full battery: cat buying, funnel, CEPs, channels, pack sizes, WOM. Qualification requires at least one Core. |
| **Adjacent** | `awareness_only` | Appears in screener. Brand awareness shown to respondents who qualify. No deep dive. Feeds portfolio map. |
| **Peripheral** | `screener_only` | Appears in screener only. No brand awareness questions. Used to capture demographic breadth of category buying without adding survey length. |

> **SINGLE-CAT NOTE:** Most projects have one Core category and two to four Adjacent categories. The screener always includes all of them as checkboxes. Even if there is only one Core, the screener is still a checkbox — not a Yes/No — because adjacent categories are always included.

### 2.2 Brand codes

Each brand has a short uppercase code. These must match the `BrandCode` column in the `Survey_Structure.xlsx` Brands sheet exactly. The survey programmer sets these — confirm with Duncan before programming.

Example (DSS): `IPK`, `ROB`, `KNORR`, `CART`, `RAJAH`, `SFRI`, `SPMEC`, `WWTDSS`, `PNPDSS`, `CKRDSS`

### 2.3 Column naming rules

| Question type | Alchemer setup | Exported column name |
|----|----|----|
| Per-category, per-brand (multi-select) | Question alias = `BRANDAWARE_DSS`, option alias = `IPK` | `BRANDAWARE_DSS_IPK` |
| Per-category, per-brand (single select) | Question alias = `BRANDATT1_DSS_IPK` | `BRANDATT1_DSS_IPK` |
| Per-category, per-CEP, per-brand (multi-select) | Question alias = `BRANDATTR_DSS_CEP01`, option alias = `IPK` | `BRANDATTR_DSS_CEP01_IPK` |
| Per-category only (single select or numeric) | Question alias = `CATBUY_DSS` | `CATBUY_DSS` |
| Per-category, per-channel (multi-select) | Question alias = `CHANNEL_DSS`, option alias = `SPMKT` | `CHANNEL_DSS_SPMKT` |
| Screener (single select) | Question alias = `SQ1_DSS` | `SQ1_DSS` |
| System / hidden | Variable name = `Focal_Category` | `Focal_Category` |
| WOM (per-brand, multi-select) | Question alias = `WOM_POS_REC`, option alias = `IPK` | `WOM_POS_REC_IPK` |
| WOM count (per-brand, single select) | Question alias = `WOM_POS_COUNT_IPK` | `WOM_POS_COUNT_IPK` |
| DBA fame (single select) | Question alias = `DBA_FAME_LOGO` | `DBA_FAME_LOGO` |
| DBA unique (open end) | Question alias = `DBA_UNIQUE_LOGO` | `DBA_UNIQUE_LOGO` |

### 2.4 Alchemer question type reference

| Turas variable type            | Alchemer question type to use              |
|--------------------------------|--------------------------------------------|
| Multi_Mention (per brand)      | Checkbox — one question, brands as options |
| Single_Response (per brand)    | Radio button — separate question per brand |
| Single_Response (per category) | Radio button — one question                |
| Numeric                        | Text entry (numeric validation)            |
| Open_End                       | Essay / text entry                         |

------------------------------------------------------------------------

## 3. Survey flow overview

```         
[Intro & Consent]
      ↓
[Section 0: Qualifying Questions]
  Gender screen   → disqualify if not target gender
  Age screen      → disqualify if outside target age range
  Industry screen → disqualify if works in MR/advertising/food/retail
  Region screen   → disqualify if non-metro
      ↓
[Section 1: Screeners]
  SQ1: checkbox — ALL categories (Core + Adjacent + Peripheral if any)
  → JavaScript Action assigns Focal_Category randomly from eligible Core cats
  → Hidden Value Action stores Focal_Category
  SQ2: checkbox — same options as SQ1, filtered by option-level logic to show only
       categories the respondent selected in SQ1. Not required (lapsed buyers allowed).
      ↓
[Routing 1: Disqualify if no Core category selected] ← Alchemer Disqualify Action
      ↓
[Section 2: Non-focal brand awareness]
  All Core + Adjacent categories EXCEPT focal: BRANDAWARE_{CAT}
  Show logic per question: SQ1 option selected AND Focal_Category ≠ that category
      ↓
[Section 3: Focal category full deep dive]
  3a. Brand awareness (focal cat) — BRANDAWARE_{FOCAL}
  3b. Category buying — CATBUY_{FOCAL}
  3c. Brand funnel — consideration, preference, usage
      ↓ (rejection OE: show logic, attitude = 4)
  3d. CEP × brand matrix
  3e. Channels & pack sizes
  3f. Ad-hoc questions (focal cat or sample-wide)
  3g. WOM                                          [toggle: element_wom]
      ↓
[Section 4: DBA — ALL RESPONDENTS]                [toggle: element_dba]
      ↓
[Section 5: Branded Reach — ALL RESPONDENTS]      [toggle: element_branded_reach]
      ↓
[Section 6: Demographics — ALL RESPONDENTS]
      ↓
[Thank you & close]
```

> **SINGLE-CAT:** Section 0 qualifying questions still apply. Section 1 screener is a checkbox with one Core + adjacent categories. No JS focal assignment needed — all respondents get the one Core category as focal (set Focal_Category as a fixed Hidden Value = that category code). Non-focal awareness block is adjacent categories only. Sections 3a–3g shown to all qualified respondents.

------------------------------------------------------------------------

## 4. Section 0: Survey intro & consent

Standard intro page. No question codes required. Include: - Study purpose (general: "understanding how people buy and use cooking products") - Estimated time (15–20 minutes) - Confidentiality statement - Consent checkbox (required to proceed)

Do not mention the client name or brand in the intro.

------------------------------------------------------------------------

## 4b. Section 0: Qualifying Questions

Place these on a dedicated page **before** the screener page. All disqualify actions fire when the respondent clicks Next on this page — they never reach SQ1.

| Question | Alias | Type | Disqualify condition |
|----|----|----|----|
| Gender | `Gender` | Radio | Not `Woman` (or target gender for project) |
| Age | `Age` | Radio | Outside target age range |
| Industry screen | `Industry_Screen` | Radio | Any industry other than `None` |
| Region / Metro | `Region` | Radio | `Other` (non-metro) |

**Gender options** (reporting values in parentheses): Woman (`Woman`), Man (`Man`), Non-binary or gender diverse (`Non-binary`), Prefer not to say (`Prefer_not_to_say`)

**Age options** (IPK: women 30–50): Under 30 (`Under_30`), 30–34 (`30_34`), 35–39 (`35_39`), 40–44 (`40_44`), 45–50 (`45_50`), Over 50 (`Over_50`). Disqualify if `Under_30` or `Over_50`.

**Industry screen options**: Market research or opinion polling (`MR`), Advertising or marketing (`Adv`), Food or grocery manufacturing (`Food`), Retail — grocery or supermarket (`Retail`), None of these (`None`). Disqualify if NOT `None`.

**Region options** (list key metros as city names, not province names — respondents in rural areas self-select to Other): Johannesburg / Pretoria (`GAU`), Cape Town (`WC`), Durban (`KZN`), Port Elizabeth / Gqeberha or East London (`EC`), Other (`Other`). Disqualify if `Other`.

> **Project-specific:** Target gender, age range, and metro list will vary per project. Confirm with Duncan before programming. The industry screen is standard across all projects.

> **Panel pre-screening:** If using a panel that pre-screens for gender, age, and region, these questions can be shortened to verification questions only (not hard disqualifiers). Confirm with the panel provider.

------------------------------------------------------------------------

## 5. Section 1: Screeners

**Purpose:** Establish which categories the respondent buys in. Qualify and assign to a focal Core category.

### Screener design principle

**SQ1 is always a checkbox — never a Yes/No.** Every project includes Core and Adjacent categories in the same checkbox, even when there is only one Core category. This gives you: - A richer picture of the respondent's category landscape - Cross-category awareness data for the portfolio map - Adjacent category buyer profiling without extra questions

The number of categories in the checkbox is a design decision, not a technical one. For IPK: 9 categories. For a typical single-brand project: 1 Core + 2–4 Adjacent.

### Screener logic rules

| Rule | Detail |
|----|----|
| **SQ1 — long window** | Single checkbox question. All categories (Core + Adjacent + Peripheral if any). "Bought in the last 12 months?" |
| **SQ2 — target window** | One radio question per Core category. Shown only to respondents who selected that Core category in SQ1. |
| **Target window duration** | Configurable per category in `Timeframe_Target` column of Brand_Config Categories sheet. Default 3 months; Baking Mixes 6 months. |
| **Qualification rule** | Must select at least one Core category in SQ1. Adjacent-only or Peripheral-only buyers are screened out. |
| **SQ2 is data, not a gate** | All respondents who selected a Core category in SQ1 see SQ2, regardless of their answer. SQ2 answer is stored for analysis (recent vs lapsed buyer). It does NOT determine qualification. |
| **Adjacent / Peripheral categories** | SQ1 only. No SQ2 asked. Used to route brand awareness questions. |

------------------------------------------------------------------------

### SQ1 — long window screener (all categories, always a checkbox)

**Critical naming rule:** Set the question alias to `SQ1` and set each category as a named option. Alchemer exports one column per option as `{QuestionAlias}_{OptionAlias}`. With alias `SQ1` and option `DSS`, the export column is `SQ1_DSS` — which matches the QuestionMap exactly.

Do **not** name the question `SQ1_ALL` — that exports as `SQ1_ALL_DSS`, which breaks the QuestionMap.

| Field | Value |
|----|----|
| Question alias | `SQ1` |
| Question type | **Checkbox (multi-select)** — always, even for single-Core projects |
| Question text | "In the last **12 months**, which of the following have you personally bought for your household? Please select all that apply." |

**Options — list Core categories first, then Adjacent, then Peripheral, then None:**

| Option alias | Option label | Role |
|----|----|----|
| `DSS` | Dry seasonings & spices (e.g. Ina Paarman's, Robertsons, Rajah) | Core |
| `POS` | Pour over sauces (e.g. Knorr, Royco, creamy pepper or mushroom sauces) | Core |
| `PAS` | Pasta sauces (e.g. Dolmio, Ina Paarman's, Knorr) | Core |
| `BAK` | Baking mixes (e.g. cake mix, scone mix, muffin mix) | Core |
| `SLD` | Salad dressings | Adjacent |
| `STO` | Stock powder or liquid stock | Adjacent |
| `PES` | Pestos | Adjacent |
| `COO` | Cook-in sauces | Adjacent |
| `ANT` | Antipasto / anti-pasta | Adjacent |
| `NONE` | None of the above | — |

**Exported columns:** `SQ1_DSS`, `SQ1_POS`, `SQ1_PAS`, `SQ1_BAK`, `SQ1_SLD`, `SQ1_STO`, `SQ1_PES`, `SQ1_COO`, `SQ1_ANT` — value = 1 if selected, 0 if not.

> **SINGLE-CAT EXAMPLE:** One Core category (e.g. Shampoo `SHA`) + two Adjacent (e.g. Conditioner `CON`, Hair Treatment `HTR`). Checkbox with three options: `SHA`, `CON`, `HTR`, `NONE`. Exports as `SQ1_SHA`, `SQ1_CON`, `SQ1_HTR`. Screen out if `SQ1_SHA` not selected.

> **PERIPHERAL CATEGORIES:** If a category should appear in the screener but not trigger any questions (purely for respondent profiling), add it to the checkbox as another option. Do not include it in any brand awareness or funnel questions. Set `Analysis_Depth = screener_only` in the Categories sheet.

------------------------------------------------------------------------

### SQ2 — target window (all categories, filtered by SQ1)

Programme as **one checkbox question** on a separate page (Target Window). Same category options as SQ1. Each option is shown only if the respondent selected that category in SQ1 — configured via **option-level Logic** on each option, not question-level logic.

| Field | Value |
|----|----|
| **Question alias** | `SQ2` |
| **Question type** | Checkbox (multi-select) |
| **Question text** | "And which of these have you personally bought in the last 3 months?" |
| **Required** | No — lapsed buyers (bought 12m but not 3m) still proceed |
| **Options** | Same 9 categories as SQ1 with same reporting values (DSS, POS, PAS, BAK, SLD, STO, PES, COO, ANT). Do NOT include "None of these". |

**Option-level show logic** — set on each individual option:

| Option                  | Show only if               |
|-------------------------|----------------------------|
| Dry Seasonings & Spices | SQ1 option DSS is selected |
| Pour Over Sauces        | SQ1 option POS is selected |
| Pasta Sauces            | SQ1 option PAS is selected |
| Baking Mixes            | SQ1 option BAK is selected |
| Salad Dressings         | SQ1 option SLD is selected |
| Stock Powder / Liquid   | SQ1 option STO is selected |
| Pestos                  | SQ1 option PES is selected |
| Cook-in Sauces          | SQ1 option COO is selected |
| Anti-pasta              | SQ1 option ANT is selected |

To set option-level logic in Alchemer: edit each option → Logic tab → set condition.

**Exported columns:** `SQ2_DSS`, `SQ2_POS`, `SQ2_PAS`, `SQ2_BAK`, `SQ2_SLD`, `SQ2_STO`, `SQ2_PES`, `SQ2_COO`, `SQ2_ANT` — value = 1 if selected, 0/blank if not.

> **SQ2 is data, not a gate.** The answer determines buyer vs lapsed-buyer classification in analysis. It does not affect qualification or routing.

------------------------------------------------------------------------

## 6. Routing 1: Qualification check (screen-out)

**When:** End of the screener page (after SQ1 and all SQ2 questions).\
**How:** Alchemer built-in **Disqualify Action** — no scripting needed.

**Step-by-step in Alchemer:**

1.  Go to the screener page → click **Add Action** → choose **Disqualify**

2.  On the Logic tab of the Disqualify action, set the condition as:

    *Disqualify if ALL of the following are true:*

    -   `SQ1` option `DSS` is NOT selected ← Core category
    -   `SQ1` option `POS` is NOT selected ← Core category
    -   `SQ1` option `PAS` is NOT selected ← Core category
    -   `SQ1` option `BAK` is NOT selected ← Core category

    *(List Core categories only — Adjacent and Peripheral do not qualify anyone)*

3.  Set the Disqualify message: *"Thank you for your time. Unfortunately you do not meet the criteria for this study."*

4.  Set the disqualify URL to your panel provider's screen-out redirect (if using a panel).

> **How to read it:** Only Core category buyers qualify. A respondent who selected Salad Dressings and Pestos (both Adjacent) but no Core category is disqualified. A respondent who selected even one Core category passes through.

> **SINGLE-CAT:** Disqualify if `SQ1` option `{CORE_CAT}` is NOT selected. Adjacent-only respondents are disqualified.

------------------------------------------------------------------------

## 7. Routing 2: Focal category assignment

**When:** On the screener page (same page as SQ1), fires when the respondent clicks Next.\
**How:** **JavaScript Action** + **Hidden Value Action** — both placed on the screener page after SQ1.

The JavaScript randomly selects one Core category from those the respondent ticked in SQ1 and writes the category code (e.g. `DSS`) into the Hidden Value Action field `Focal_Category`. Alchemer's Distributed Logic Quota (set up separately under Tools → Quotas) monitors the distribution for balance but does not set the variable directly.

### Step 1 — Add a Hidden Value Action to the screener page

On the screener page (same page as SQ1), click **Add New → Action → Hidden Value**.

| Field              | Value                                     |
|--------------------|-------------------------------------------|
| Name / Description | `Assign Focal Category`                   |
| Populate with      | *(leave blank — the JS will write to it)* |

Note the **ID number** shown on this action in the builder (e.g. ID: 12). You need this for the JS.

### Step 2 — Add a JavaScript Action to the screener page

On the same page, click **Add New → Action → JavaScript**. Name it `Assign Focal Category JS`.

Paste the following script, updating `DEST_QID` and `SOURCE_QID` with the actual Alchemer ID numbers for your survey:

``` javascript
const DEST_QID = 12    // ID of the Hidden Value Action above
const SOURCE_QID = 6   // ID of the SQ1 checkbox question

const CORE_MATCHES = [
  {match: 'Dry Seasoning', code: 'DSS'},
  {match: 'Pour Over', code: 'POS'},
  {match: 'Pasta Sauce', code: 'PAS'},
  {match: 'Baking Mix', code: 'BAK'}
]

document.addEventListener("DOMContentLoaded", function() {
  function getSgElemById(qid, oid) {
    oid = oid || "element"
    var surveyInfo = SGAPI.surveyData[Object.keys(SGAPI.surveyData)[0]]
    var id = "sgE-" + surveyInfo.id + "-" + surveyInfo.currentpage + "-" + qid + "-" + oid
    return document.getElementById(id)
  }

  function shuffle(array) {
    var currentIndex = array.length, temporaryValue, randomIndex
    while (0 !== currentIndex) {
      randomIndex = Math.floor(Math.random() * currentIndex)
      currentIndex -= 1
      temporaryValue = array[currentIndex]
      array[currentIndex] = array[randomIndex]
      array[randomIndex] = temporaryValue
    }
    return array
  }

  var source = getSgElemById(SOURCE_QID, "box")
  var dest = getSgElemById(DEST_QID)

  var elemNext = document.getElementById("sg_NextButton") || document.getElementById("sg_SubmitButton")
  if (elemNext) {
    elemNext.addEventListener("click", function() {
      var answers = []
      var boxes = source.querySelectorAll("[type=checkbox]")
      boxes.forEach(function(box) {
        if (box.checked) {
          for (var i = 0; i < CORE_MATCHES.length; i++) {
            if (box.title.indexOf(CORE_MATCHES[i].match) >= 0) {
              answers.push(CORE_MATCHES[i].code)
              break
            }
          }
        }
      })
      if (dest) dest.value = shuffle(answers)[0] || ""
    })
  }
})
```

**Important notes on the script:** - `CORE_MATCHES` uses partial title matching (not full option text) to avoid issues with `&` being HTML-encoded by Alchemer - Do NOT use double-quote characters inside string literals — Alchemer HTML-encodes them and breaks the JS - Test via the **Share → Anonymous link** in a browser with F12 console open. The test mode may suppress JS execution. - The script works correctly with the live survey link even if test mode shows no output

### Step 3 — Set up Distributed Logic Quota for balance monitoring

Go to **Tools → Quotas → Create Quota → Distributed Logic Quota**.

| Quota name  | Target n               | Logic condition            |
|-------------|------------------------|----------------------------|
| `Focal_DSS` | Your target (e.g. 100) | SQ1 option DSS is selected |
| `Focal_POS` | Your target            | SQ1 option POS is selected |
| `Focal_PAS` | Your target            | SQ1 option PAS is selected |
| `Focal_BAK` | Your target            | SQ1 option BAK is selected |

Set **Complete Actions** to: *Continue collecting responses* (not stop — the panel provider manages hard quotas on their side).

The quota monitors balance but does not set `Focal_Category` directly — the JS does that.

> **SINGLE-CAT:** No JS or quota needed. Add a Hidden Value Action to the screener page with a fixed value = your category code (e.g. `DSS`). All respondents get the same focal category.

> **Wave column:** Do not add a Wave question to the survey. Instead, add `Wave = 1` as a fixed derived column in `prep_data.R` when importing the export. Change to `Wave = 2` for the next wave.

------------------------------------------------------------------------

## 8. Section 2: Cross-category brand awareness

**Toggle:** `cross_category_awareness = Y` in Brand_Config. Also required when `element_portfolio = Y`.\
**Shown to:** All qualified respondents, but only for categories they bought in (SQ1 = selected).

**Purpose:** Collect brand awareness across all categories. Feeds both the per-category funnel (awareness step) and the portfolio map.

Programme as **one checkbox question per category**, each shown only to respondents who selected that category in SQ1.

**Question order matters:** Show ALL cross-category awareness questions (Core and Adjacent) before the focal category deep dive. This captures awareness before any brand-specific framing could prime recall.

### Core categories (DSS, POS, PAS, BAK)

Shown to respondents who selected that Core category in SQ1 — which includes both their focal category and any other Core categories they qualify for.

#### BRANDAWARE_DSS

| Field | Value |
|----|----|
| Question alias | `BRANDAWARE_DSS` |
| Question type | Checkbox (multi-select) |
| **Show logic** | `SQ1` option `DSS` is selected |
| Question text | "Which of the following brands of **dry seasonings & spices** have you heard of — even if you have never bought them?" |
| Options | One option per brand. Option alias = brand code. |
| Example options | `IPK` / Ina Paarman's Kitchen · `ROB` / Robertsons · `KNORR` / Knorr · `CART` / Cartwright's · `RAJAH` / Rajah · `SFRI` / Safari · `SPMEC` / Spice Mecca · `WWTDSS` / Woolworths Taste · `PNPDSS` / PnP No Name · `CKRDSS` / Checkers House Brand |
|  | `NONE` / None of these |
| Exported columns | `BRANDAWARE_DSS_IPK`, `BRANDAWARE_DSS_ROB`, ... |

Repeat pattern for **BRANDAWARE_POS**, **BRANDAWARE_PAS**, **BRANDAWARE_BAK**.

### Adjacent categories (SLD, STO, PES, COO, ANT)

Shown only to respondents who selected that category in SQ1. All other respondents skip it.

| Field | Value |
|----|----|
| Question alias | `BRANDAWARE_SLD` (one question per Adjacent category) |
| Question type | Checkbox (multi-select) |
| **Show logic** | `SQ1` option `SLD` is selected |
| Question text | "Which of the following brands of **salad dressings** have you heard of?" |
| Options | Relevant brand list for that category |

Repeat for `BRANDAWARE_STO`, `BRANDAWARE_PES`, `BRANDAWARE_COO`, `BRANDAWARE_ANT`.

### Peripheral categories

No brand awareness questions. Peripheral categories appear in SQ1 only. No questions are shown based on Peripheral selection.

> **SINGLE-CAT:** Show the Adjacent awareness question(s) to respondents who selected that Adjacent category in SQ1. Core category awareness is not shown here — it is captured in Section 4 (Brand Funnel) as the first funnel step.

------------------------------------------------------------------------

## 9. Section 3: Category buying

**Shown to:** Respondents assigned to this focal category only. Programme each question with the condition `Focal_Category = {CAT_CODE}`.

### 3a. Category buying frequency

| Field | Value |
|----|----|
| Question alias | `CATBUY_{CAT}` (e.g. `CATBUY_DSS`) |
| Question type | Radio button |
| Question text | "In a typical month, how often do you buy **[category name]**?" |
| Options | `1` / Several times a week · `2` / About once a week · `3` / A few times a month · `4` / Monthly or less · `5` / I no longer buy this category |
| OptionMapScale | `cat_buy_scale` (defined in Survey_Structure OptionMap) |

### 3b. Purchase count (target window)

| Field | Value |
|----|----|
| Question alias | `CATCOUNT_{CAT}` (e.g. `CATCOUNT_DSS`) |
| Question type | Text entry — numeric, integer, 0–99 |
| Question text | "Roughly how many times have you bought **[category name]** in the last **[target_timeframe]** months?" |
| Note | Target timeframe from `Timeframe_Target` in Categories sheet. DSS/POS/PAS = 3 months. BAK = 6 months. |

------------------------------------------------------------------------

## 10. Section 4: Brand funnel

**Shown to:** Focal category respondents only.\
**Covers:** Attitude and penetration (awareness is collected in Section 2).

### 4a. Brand attitude

Programme as a **separate radio button question for each brand**. Questions appear on the same page (or consecutive pages), one per brand.

| Field | Value |
|----|----|
| Question alias | `BRANDATT1_{CAT}_{BRAND}` (e.g. `BRANDATT1_DSS_IPK`) |
| Question type | Radio button |
| Question text | "Which of the following statements best describes how you feel about **[Brand Label]**?" |
| Options | `1` / I love it — it's my favourite · `2` / It's among the ones I prefer · `3` / I wouldn't usually consider it, but I would if no other option · `4` / I would refuse to buy this brand · `5` / I have no opinion / I don't know this brand |
| OptionMapScale | `attitude_scale` |

Repeat for each brand in the category. **All brands are shown regardless of awareness** — "no opinion" option handles brands they don't know. This is the Romaniuk approach.

> **Alchemer tip:** Group all attitude questions for a category on one page with a shared intro: *"For each of the following brands, please indicate how you feel about it."*

### 4b. Rejection open-end (built-in show logic)

No scripting needed. Use Alchemer's built-in **Show Logic** on each rejection OE question.

**Setup for each brand:**

Place each `BRANDATT2_{CAT}_{BRAND}` question immediately after the corresponding `BRANDATT1_{CAT}_{BRAND}` question.

On the Logic tab of `BRANDATT2_DSS_IPK`: - **Show this question if:** `BRANDATT1_DSS_IPK` = `4` (I would refuse to buy this brand)

| Field | Value |
|----|----|
| Question alias | `BRANDATT2_{CAT}_{BRAND}` (e.g. `BRANDATT2_DSS_IPK`) |
| Question type | Essay / open-end text |
| Question text | "You said you would refuse to buy **[Brand Label]**. In your own words, why is that?" |
| Show logic | `BRANDATT1_{CAT}_{BRAND}` = `4` |

> **NOTE:** One `BRANDATT2` question per brand per category. For IPK: 10 brands × 4 categories = 40 rejection OE questions, all hidden by default unless the respondent selects "refuse".

### 4c. Penetration — long window

| Field | Value |
|----|----|
| Question alias | `BRANDPEN1_{CAT}` (e.g. `BRANDPEN1_DSS`) |
| Question type | Checkbox (multi-select) |
| Question text | "Which of these **[category name]** brands have you personally bought in the last **12 months**?" |
| Options | One option per brand. Option alias = brand code. Plus `NONE` = None of these. |
| Exported columns | `BRANDPEN1_DSS_IPK`, `BRANDPEN1_DSS_ROB`, ... |

### 4d. Penetration — target window

| Field | Value |
|----|----|
| Question alias | `BRANDPEN2_{CAT}` (e.g. `BRANDPEN2_DSS`) |
| Question type | Checkbox (multi-select) |
| Question text | "And which have you bought in the last **[target_timeframe] months**?" |
| Options | Brands only (subset of BRANDPEN1 answers ideally via Alchemer piping — or show all brands) |
| Exported columns | `BRANDPEN2_DSS_IPK`, `BRANDPEN2_DSS_ROB`, ... |

### 4e. Purchase frequency (per brand)

| Field | Value |
|----|----|
| Question alias | `BRANDPEN3_{CAT}_{BRAND}` (e.g. `BRANDPEN3_DSS_IPK`) |
| Question type | Radio button |
| Shown to | Respondents who selected this brand in BRANDPEN2\_{CAT} |
| Question text | "When you buy **[category name]**, how often do you choose **[Brand Label]**?" |
| Options | `1` / Every time · `2` / Most times · `3` / About half the time · `4` / Occasionally · `5` / Rarely — this was a first purchase |
| OptionMapScale | `purchase_freq_scale` |

> **NOTE:** Programme one question per brand. Use Alchemer piping or conditional display so only brands selected in BRANDPEN2 are shown.

------------------------------------------------------------------------

## 11. Section 5: CEP × brand matrix

**Toggle:** `element_mental_avail = Y`\
**Shown to:** Focal category respondents only.\
**Purpose:** For each category entry point (moment), which brands come to mind?

Programme as **one checkbox question per CEP**, brands as options.

| Field | Value |
|----|----|
| Question alias | `BRANDATTR_{CAT}_{CEPCODE}` (e.g. `BRANDATTR_DSS_CEP01`) |
| Question type | Checkbox (multi-select) |
| Question text | "**[CEP statement]** — which brands come to mind?" (e.g. "When I'm seasoning a roast meat dish — which brands come to mind?") |
| Options | One option per brand. Option alias = brand code. Plus `NONE` = None of these. |
| Exported columns | `BRANDATTR_DSS_CEP01_IPK`, `BRANDATTR_DSS_CEP01_ROB`, ... |

Repeat for all 15 CEPs per category. For IPK: 15 CEPs × 4 categories = 60 questions.

> **INTRO TEXT:** Place an intro page before the CEP questions: *"We'd now like to understand which brands come to mind in different situations. For each situation, please select all brands that come to mind — even if you don't buy them."*

> **SINGLE-CAT:** 15 questions. Shown to all qualified respondents.

------------------------------------------------------------------------

## 12. Section 6: Purchase channels & pack sizes

**Shown to:** Focal category respondents only. Shown only to respondents who bought this category in the last 3 months (SQ2\_{CAT} = 1).

### 6a. Purchase channels

| Field | Value |
|----|----|
| Question alias | `CHANNEL_{CAT}` (e.g. `CHANNEL_DSS`) |
| Question type | Checkbox (multi-select) |
| Question text | "Where have you bought **[category name]** in the last **[target_timeframe] months**? Select all that apply." |
| Options (example) | `SPMKT` / Supermarket (Pick n Pay, Checkers, Woolworths) · `DISCNT` / Discount retailer (Game, Makro) · `CORNER` / Corner shop / spaza · `ONLINE` / Online (takealot, woolworths.co.za) · `FARM` / Farm stall / deli · `OTHER` / Other |
| Exported columns | `CHANNEL_DSS_SPMKT`, `CHANNEL_DSS_DISCNT`, ... |

> **TEMPLATE NOTE:** Define channel codes and labels in `Survey_Structure.xlsx` → Channels sheet. Use the same option aliases.

### 6b. Pack sizes

| Field | Value |
|----|----|
| Question alias | `PACKSIZE_{CAT}` (e.g. `PACKSIZE_DSS`) |
| Question type | Checkbox (multi-select) |
| Question text | "Which pack sizes have you bought in the last **[target_timeframe] months**? Select all that apply." |
| Options | `SMALL` / Small / single-serve · `MEDIUM` / Medium / family pack · `LARGE` / Large / value pack · `MULTI` / Multi-pack / bulk buy |
| Exported columns | `PACKSIZE_DSS_SMALL`, `PACKSIZE_DSS_MEDIUM`, ... |

------------------------------------------------------------------------

## 13. Section 6b: Ad-hoc questions

**No Brand_Config toggle** — simply omit this section if there are no ad-hoc questions for the project.\
**Shown to:** Either all respondents (sample-wide) or focal category respondents only (category-specific). Set per question.

Ad-hoc questions are project-specific items that don't belong to the standard CBM battery. Examples: NPS, future purchase intent, specific product questions, claimed media consumption, prior advertising recall.

### Naming convention

| Scope | Question alias format | QuestionMap role | Example |
|----|----|----|----|
| Sample-wide (all respondents) | `ADHOC_{KEY}` | `adhoc.{key}.ALL` | `ADHOC_NPS` |
| Category-specific (focal cat only) | `ADHOC_{KEY}_{CAT}` | `adhoc.{key}.{CATCODE}` | `ADHOC_FUTURE_DSS` |

The `{KEY}` is a short descriptive code you choose (e.g. `NPS`, `FUTURE`, `TRIAL`, `PROMO`). Keep it uppercase, no spaces.

### Question types

Ad-hoc questions can be any type (radio, checkbox, rating, open-end). The only requirements are: 1. The question alias follows the naming convention above 2. The question is registered in `Survey_Structure.xlsx` → **AdHoc sheet** with the correct role and scope

### AdHoc sheet in Survey_Structure.xlsx

Each ad-hoc question needs a row in the AdHoc sheet:

| Column | What to fill in |
|----|----|
| `Role` | `adhoc.{key}.ALL` or `adhoc.{key}.{CATCODE}` |
| `ClientCode` | The question alias exactly as in Alchemer |
| `QuestionText` | Full question wording |
| `QuestionTextShort` | Short label for UI chips |
| `Variable_Type` | `Single_Response`, `Multi_Mention`, `Numeric`, or `Open_End` |
| `OptionMapScale` | Scale name if question uses coded responses (else blank) |

### Example — NPS (sample-wide)

| Field | Value |
|----|----|
| Question alias | `ADHOC_NPS` |
| Question type | Radio button (0–10 scale) |
| Shown to | All respondents |
| Question text | "On a scale of 0 to 10, how likely are you to recommend **Ina Paarman's Kitchen** products to a friend or family member? (0 = Not at all likely, 10 = Extremely likely)" |
| Options | `0` through `10` as separate radio options |
| AdHoc sheet role | `adhoc.nps.ALL` |

### Example — Future purchase intent (category-specific)

| Field | Value |
|----|----|
| Question alias | `ADHOC_FUTURE_DSS` |
| Question type | Radio button |
| Shown to | `Focal_Category = DSS` |
| Question text | "How likely are you to buy **Ina Paarman's Kitchen** dry seasonings in the next 3 months?" |
| Options | `1` / Definitely will · `2` / Probably will · `3` / Might or might not · `4` / Probably won't · `5` / Definitely won't |
| AdHoc sheet role | `adhoc.future.DSS` |

> **TEMPLATE NOTE:** Ad-hoc questions should be placed after pack sizes / channels (Section 6) and before WOM (Section 7). This keeps them out of the core CBM battery but still within the focal category experience.

> **MULTI-CATEGORY:** For a sample-wide ad-hoc question in a multi-category study (e.g. NPS), show it to all respondents regardless of focal category. For a category-specific question (e.g. `ADHOC_FUTURE_DSS`), show it only to respondents where `Focal_Category = DSS`.

------------------------------------------------------------------------

## 14. Section 7: Word of Mouth (WOM)

**Toggle:** `element_wom = Y`\
**Shown to:** All qualified respondents. Questions refer to brands in the **focal category** only.

### 7a. Received positive WOM

| Field | Value |
|----|----|
| Question alias | `WOM_POS_REC` |
| Question type | Checkbox (multi-select) |
| Question text | "In the last **[wom_timeframe]** (e.g. 3 months), has someone you know — in person or online — said something **positive** about any of these brands?" |
| Options | One option per focal category brand. Option alias = brand code. Plus `NONE`. |
| Note | `wom_timeframe` from Brand_Config Settings. |
| Exported columns | `WOM_POS_REC_IPK`, `WOM_POS_REC_ROB`, ... |

### 7b. Received negative WOM

| Field | Value |
|----|----|
| Question alias | `WOM_NEG_REC` |
| Question type | Checkbox (multi-select) |
| Question text | "And has someone said something **negative** about any of these brands in the last **[wom_timeframe]**?" |
| Options | Same brands + `NONE` |
| Exported columns | `WOM_NEG_REC_IPK`, ... |

### 7c. Shared positive WOM

| Field | Value |
|----|----|
| Question alias | `WOM_POS_SHARE` |
| Question type | Checkbox (multi-select) |
| Question text | "Have **you** recommended or said something **positive** about any of these brands to someone else in the last **[wom_timeframe]**?" |
| Options | Same brands + `NONE` |
| Exported columns | `WOM_POS_SHARE_IPK`, ... |

### 7d. Positive WOM count (per brand — built-in show logic)

No scripting needed. Use Alchemer's built-in **Show Logic** on each count question.

Place all count questions after `WOM_POS_SHARE`. On the Logic tab of each: - **Show `WOM_POS_COUNT_IPK` if:** `WOM_POS_SHARE` option `IPK` is selected - **Show `WOM_POS_COUNT_ROB` if:** `WOM_POS_SHARE` option `ROB` is selected - *(repeat for each brand)*

| Field | Value |
|----|----|
| Question alias | `WOM_POS_COUNT_{BRAND}` (e.g. `WOM_POS_COUNT_IPK`) |
| Question type | Radio button |
| Show logic | `WOM_POS_SHARE` option `{BRAND}` is selected |
| Question text | "How many times did you recommend or say something positive about **[Brand Label]** in the last **[wom_timeframe]**?" |
| Options | `1` / Once · `2` / Twice · `3` / 3 times · `4` / 4 times · `5` / 5 or more times |
| OptionMapScale | `wom_count_scale` |

Repeat the same pattern for negative WOM: `WOM_NEG_COUNT_{BRAND}` shown if `WOM_NEG_SHARE` option `{BRAND}` is selected.

------------------------------------------------------------------------

## 14. Section 8: Distinctive Brand Assets (DBA)

**Toggle:** `element_dba = Y` (default N — add 2 min to survey length)\
**Shown to:** All respondents.\
**Purpose:** Which brand assets are famous? Which are uniquely attributed to IPK?

### 8a. Asset fame (recognition)

Show the asset (image, text, or audio). Ask if they've seen it before.

| Field | Value |
|----|----|
| Question alias | `DBA_FAME_{ASSET}` (e.g. `DBA_FAME_LOGO`) |
| Question type | Radio button |
| Question text | "Have you seen this before?" [show asset image/text] |
| Options | `1` / Yes, I have seen this before · `2` / No, I have not seen this before |
| OptionMapScale | `dba_fame_scale` |

### 8b. Asset attribution (uniqueness)

Shown to all respondents (not just those who recognised the asset — blind attribution reveals instinctive association).

| Field | Value |
|----|----|
| Question alias | `DBA_UNIQUE_{ASSET}` (e.g. `DBA_UNIQUE_LOGO`) |
| Question type | Open-end text (essay) |
| Question text | "Which brand do you think this belongs to?" [show same asset] |
| Note | Response is coded to a brand name post-field. The analysis engine calculates what % attribute to IPK. |

**IPK DBA assets (placeholder):**

| AssetCode | AssetLabel                       | AssetType |
|-----------|----------------------------------|-----------|
| `LOGO`    | Script logo                      | image     |
| `COLOUR`  | Red packaging colour             | image     |
| `JAR`     | Glass jar shape                  | image     |
| `CHEF`    | Ina Paarman character            | image     |
| `TAGLINE` | "Seasoned to perfection" tagline | text      |

------------------------------------------------------------------------

## 15. Section 9: Branded Reach [TEMPLATE — NOT IN IPK WAVE 1]

**Toggle:** `element_branded_reach = Y` (default N)\
**Shown to:** All respondents (or focal category respondents only — configurable).\
**Purpose:** Advertising recognition and media attribution.

### 9a. Advertising seen

| Field | Value |
|----|----|
| Question alias | `REACH_SEEN_{ADCODE}` (e.g. `REACH_SEEN_ADTV01`) |
| Question type | Radio button |
| Question text | "Have you seen or heard the following recently?" [show ad stimulus] |
| Options | `1` / Yes, I have seen / heard this · `2` / No, I have not |
| OptionMapScale | `reach_seen_scale` |

### 9b. Brand attributed

| Field | Value |
|----|----|
| Question alias | `REACH_BRAND_{ADCODE}` |
| Question type | Radio button |
| Shown to | `REACH_SEEN_{ADCODE} = 1` |
| Question text | "Which brand was this advertising for?" |
| Options | One option per brand + `DK` / Don't know + `OTHER` / Other brand |

### 9c. Media channel

| Field | Value |
|----|----|
| Question alias | `REACH_MEDIA_{ADCODE}` |
| Question type | Checkbox (multi-select) |
| Shown to | `REACH_SEEN_{ADCODE} = 1` |
| Question text | "Where did you see or hear this?" |
| Options | `TV` / Television · `SOCMED` / Social media · `PRINT` / Print / magazine · `OOH` / Outdoor / billboard · `RADIO` / Radio · `ONLINE` / Online / website · `OTHER` / Other |

------------------------------------------------------------------------

## 16. Section 10: Demographics

**Shown to:** All respondents.

| Question alias | Question text | Type | Options |
|----|----|----|----|
| `DEMO_GENDER` | What is your gender? | Radio | `1` Female · `2` Male · `3` Non-binary / prefer to self-describe · `99` Prefer not to say |
| `DEMO_AGE` | What is your age? | Radio | `1` 18–24 · `2` 25–34 · `3` 35–44 · `4` 45–54 · `5` 55–64 · `6` 65+ |
| `DEMO_PROVINCE` | Which province do you live in? | Radio | `1` Gauteng · `2` Western Cape · `3` KwaZulu-Natal · `4` Eastern Cape · `5` Other |
| `DEMO_GROCERY_ROLE` | What is your role in grocery shopping for your household? | Radio | `1` I do all or most of the grocery shopping · `2` I share grocery shopping equally · `3` Someone else does most of the grocery shopping |
| `DEMO_HH_SIZE` | How many people live in your household including yourself? | Radio | `1` Just me · `2` 2 people · `3` 3–4 people · `4` 5+ people |
| `DEMO_EMPLOYMENT` | What is your current employment status? | Radio | `1` Employed full-time · `2` Employed part-time · `3` Self-employed · `4` Not currently employed · `5` Retired · `99` Prefer not to say |
| `DEMO_SEM` | Without giving an exact figure, which of the following best describes your household's total monthly income? | Radio | `1` Under R5,000 · `2` R5,000–R14,999 · `3` R15,000–R29,999 · `4` R30,000–R49,999 · `5` R50,000+ · `99` Prefer not to say |

> **TEMPLATE NOTE:** Add or remove DEMO questions as needed. Always use the `DEMO_` prefix. These feed the Demographics sub-tab in the brand report.

------------------------------------------------------------------------

## 17. Alchemer export settings

When the survey is closed, export the data as follows:

| Setting | Value |
|----|----|
| Export format | CSV or Excel (.xlsx) |
| Include | All responses (completed + partial if applicable) |
| Column names | **Use question aliases** (not default Q1, Q2 etc.) |
| Option values | **Numeric codes** (not label text) — critical for analysis |
| Checkbox format | **Separate columns per option** — one column per brand |
| Missing / not shown | Export as blank / NA — do NOT use 0 for questions not shown |

> **WARNING:** If Alchemer exports checkbox responses as a single comma-separated string column (e.g. "IPK, ROB, KNORR") instead of separate columns, the analysis will fail. Ensure **"Separate columns per option"** is selected in export settings.

------------------------------------------------------------------------

## 18. Derived fields (post-field data preparation)

After export and before running the Turas report, run `prep_data.R` to add derived columns. These enable buyer vs non-buyer analysis in both the brand module and the tabs module.

For each focal category and each brand, add:

``` r
# Example for DSS focal respondents
data$Buyer_IPK_DSS   <- ifelse(data$BRANDPEN2_DSS_IPK == 1, 1, 0)
data$Buyer_ROB_DSS   <- ifelse(data$BRANDPEN2_DSS_ROB == 1, 1, 0)
data$Buyer_KNORR_DSS <- ifelse(data$BRANDPEN2_DSS_KNORR == 1, 1, 0)
# ... repeat for all brands

# Convenience: any competitor buyer (for focal brand non-overlap analysis)
data$Buyer_CompetitorOnly_DSS <- ifelse(
  data$Buyer_IPK_DSS == 0 &
  (data$Buyer_ROB_DSS == 1 | data$Buyer_KNORR_DSS == 1),
  1, 0
)
```

These derived columns are used as: - **Brand module Audience Lens:** `buyer_pair_DSS` audience uses `Buyer_IPK_DSS` to split buyer / non-buyer - **Tabs module banner:** use `Buyer_IPK_DSS` as a column break variable to run all metrics by IPK buyer status

------------------------------------------------------------------------

## 19. Wave tracking setup

IPK is a tracking study. Follow these rules to ensure wave-over-wave comparisons work.

| Setup step | Action |
|----|----|
| Wave variable | Add a hidden question with alias `Wave` and a default value = wave number. Set via URL parameter: `?wave=1` for wave 1, `?wave=2` for wave 2. |
| Survey copy | Copy the wave 1 survey for wave 2 — do not rebuild from scratch. Only the `Wave` default value changes. |
| CEP stability | **Do not add or remove CEP statements between waves.** CEPs must be identical for trend analysis. If a CEP needs replacing, carry it in wave 2 and retire it in wave 3. |
| Brand list | Adding brands between waves is acceptable but note they will have no wave 1 comparison. Removing brands breaks the trend. |
| Config | Update `wave` in Brand_Config Settings for each new wave (e.g. `wave = 2`). Do not change `tracker_ids` (must remain `Y` from wave 1 onwards). |
| Data files | Name each wave file clearly: `ipk_brand_wave1.xlsx`, `ipk_brand_wave2.xlsx`. Keep all waves in the same project folder. |

> **3-wave planning note:** With 3 waves, the tracker module can run linear trend lines, flag significant changes, and calculate effect sizes. Ensure wave 1 data is clean and fully validated — it becomes the baseline all future waves are judged against.

------------------------------------------------------------------------

## 20. Quick-reference: question count per project type

### IPK (4 full + 5 awareness-only categories, 10 brands per cat)

| Section                                               | Questions    |
|-------------------------------------------------------|--------------|
| Screeners (SQ1 combined + 4× SQ2)                     | 5            |
| Cross-category awareness (9 cats)                     | 9            |
| Category buying (4 cats × 2 questions)                | 8            |
| Brand attitude (4 cats × 10 brands)                   | 40           |
| Rejection OE (4 cats × 10 brands — hidden)            | 40           |
| Penetration 12m + 3m (4 cats × 2)                     | 8            |
| Purchase frequency (4 cats × 10 brands — conditional) | 40           |
| CEP matrix (4 cats × 15 CEPs)                         | 60           |
| Channels (4 cats)                                     | 4            |
| Pack sizes (4 cats)                                   | 4            |
| WOM (4 questions + 10 count × 2 — conditional)        | 24           |
| DBA (5 assets × 2 questions)                          | 10           |
| Demographics                                          | 7            |
| **Total (visible questions per respondent)**          | **\~80–100** |
| Total questions in survey (including hidden)          | \~260        |

### Typical single-category project (1 cat, 6–8 brands)

| Section                                     | Questions   |
|---------------------------------------------|-------------|
| Screeners                                   | 2           |
| Brand awareness                             | 1           |
| Category buying                             | 2           |
| Brand attitude (8 brands)                   | 8           |
| Rejection OE (hidden)                       | 8           |
| Penetration 12m + 3m                        | 2           |
| Purchase frequency (8 brands — conditional) | 8           |
| CEP matrix (12 CEPs)                        | 12          |
| Channels + pack sizes                       | 2           |
| WOM                                         | 6           |
| DBA (if in scope)                           | 10          |
| Demographics                                | 7           |
| **Total visible per respondent**            | **\~40–50** |

------------------------------------------------------------------------

*End of document. Maintained by The Research LampPost. Update version number when making structural changes.*
