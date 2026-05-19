# IPK Focal Category Assignment — Build Spec

**Status:** Locked design, 2026-05-11 (revised same day to use the same-page click-handler approach — see §11 for what changed).

**Goal:** On the Screener / Focal Assignment page (same page in this design), randomly assign respondents to one of the 4 core categories (DSS / POS / PAS / BAK) such that:
1. The respondent is only assigned to a category they selected at SQ1 (12-month purchase).
2. Categories whose hard quota is full are excluded from the random pick.
3. Demographic balance (region within cat, race within cat) is governed by Alchemer's native hard quotas — NOT by the JavaScript picker.
4. If no eligible category remains, the respondent is screened out.

**Design principle:** Alchemer's native quota engine is the source of truth and the safety net. The JavaScript only adds end-game efficiency (avoid assigning to a full cat). If the webhook or JS fails, Alchemer's quotas still enforce — nothing over-quota gets into the data.

**Architecture in one paragraph:** SQ1 (checkboxes) and `hv_focal_cat` (hidden value) sit on the same page. A Webhook Action on the page fetches all quotas and writes JSON to `.sg-http-content`. A JavaScript Action attaches a click handler to the Next button. On click, the handler reads checked SQ1 boxes directly from DOM, maps them to cat codes, filters by webhook quota data, random-picks, and writes the result to `hv_focal_cat`. No merge-code piping, no text element, no span — just same-page DOM access.

---

## 1. Recommended page order

For quotas to fire on submit (rather than later in the survey), all quota dimensions should be populated by the time the Screener / Focal Assignment page submits.

**Required positions** (relative — slot into whatever admin/intro pages you already have):

| Stage | Contents | Why |
|---|---|---|
| Earlier pages | Existing admin / intro / qualifying — no changes required from this spec | — |
| Before Screener / Focal Assignment | **Region** and **Race** (and ideally Age, Income too) | Demographic quotas can only fire once these are answered. Ask them up-front so the cat × demographic quotas evaluate on the assignment page's submit |
| **Screener / Focal Assignment page** | SQ1 question + `hv_focal_cat` hidden value + Webhook Action + JavaScript Action + screen-out skip rule + Back button disabled | All assignment logic happens here. Same page = no merge-code piping needed |
| After Focal Assignment | Brand deep-dive blocks (CEP, attitudes, behaviour, etc.) | Respondent only reaches these if all quotas had room |

**Current test survey 8839203:** SQ1 (Q6) and `hv_focal_cat` (Q12) are already on the same page — good. Region (Q21) and Race (Q153) currently live LATER in the survey, which means the cat × Region and cat × Race quotas only fire after the brand blocks. Move them earlier (ideally before the assignment page) for quotas to DQ promptly. If you keep them late for now, the cat-only quotas (cat_DSS / POS / PAS / BAK) still fire on assignment page submit — that's what the JS filters against.

---

## 2. Quota list — 36 hard quotas

All quotas are **type: Disqualify when full** (hard quotas). All limits below are at production scale (1200 total interviews). For the test survey (8839203), divide each limit by 10 and round up.

### 2a. Category quotas (4) — AT target

| Quota name | Limit | Qualification logic |
|---|---|---|
| `cat_DSS` | **350** | `hv_focal_cat` is exactly `DSS` |
| `cat_POS` | **300** | `hv_focal_cat` is exactly `POS` |
| `cat_PAS` | **300** | `hv_focal_cat` is exactly `PAS` |
| `cat_BAK` | **250** | `hv_focal_cat` is exactly `BAK` |

### 2b. Region × Cat quotas (16) — target × 1.10, round up

Region split 50/20/20/10 (GAU/WC/KZN/EC) within each cat.

| Quota name | Limit (target → cap) | Qualification logic |
|---|---|---|
| `cat_DSS_REG_GAU` | 175 → **193** | `hv_focal_cat` = `DSS` AND `Region` = `GAU` |
| `cat_DSS_REG_WC` | 70 → **77** | `hv_focal_cat` = `DSS` AND `Region` = `WC` |
| `cat_DSS_REG_KZN` | 70 → **77** | `hv_focal_cat` = `DSS` AND `Region` = `KZN` |
| `cat_DSS_REG_EC` | 35 → **39** | `hv_focal_cat` = `DSS` AND `Region` = `EC` |
| `cat_POS_REG_GAU` | 150 → **165** | `hv_focal_cat` = `POS` AND `Region` = `GAU` |
| `cat_POS_REG_WC` | 60 → **66** | `hv_focal_cat` = `POS` AND `Region` = `WC` |
| `cat_POS_REG_KZN` | 60 → **66** | `hv_focal_cat` = `POS` AND `Region` = `KZN` |
| `cat_POS_REG_EC` | 30 → **33** | `hv_focal_cat` = `POS` AND `Region` = `EC` |
| `cat_PAS_REG_GAU` | 150 → **165** | `hv_focal_cat` = `PAS` AND `Region` = `GAU` |
| `cat_PAS_REG_WC` | 60 → **66** | `hv_focal_cat` = `PAS` AND `Region` = `WC` |
| `cat_PAS_REG_KZN` | 60 → **66** | `hv_focal_cat` = `PAS` AND `Region` = `KZN` |
| `cat_PAS_REG_EC` | 30 → **33** | `hv_focal_cat` = `PAS` AND `Region` = `EC` |
| `cat_BAK_REG_GAU` | 125 → **138** | `hv_focal_cat` = `BAK` AND `Region` = `GAU` |
| `cat_BAK_REG_WC` | 50 → **55** | `hv_focal_cat` = `BAK` AND `Region` = `WC` |
| `cat_BAK_REG_KZN` | 50 → **55** | `hv_focal_cat` = `BAK` AND `Region` = `KZN` |
| `cat_BAK_REG_EC` | 25 → **28** | `hv_focal_cat` = `BAK` AND `Region` = `EC` |

### 2c. Race × Cat quotas (16) — target × 1.10, round up

Race split 60/15/15/10 (Black/White/Coloured/Indian) within each cat.

| Quota name | Limit (target → cap) | Qualification logic |
|---|---|---|
| `cat_DSS_RACE_Black` | 210 → **231** | `hv_focal_cat` = `DSS` AND `Race` = `Black` |
| `cat_DSS_RACE_White` | 53 → **59** | `hv_focal_cat` = `DSS` AND `Race` = `White` |
| `cat_DSS_RACE_Coloured` | 53 → **59** | `hv_focal_cat` = `DSS` AND `Race` = `Coloured` |
| `cat_DSS_RACE_Indian` | 35 → **39** | `hv_focal_cat` = `DSS` AND `Race` = `Indian` |
| `cat_POS_RACE_Black` | 180 → **198** | `hv_focal_cat` = `POS` AND `Race` = `Black` |
| `cat_POS_RACE_White` | 45 → **50** | `hv_focal_cat` = `POS` AND `Race` = `White` |
| `cat_POS_RACE_Coloured` | 45 → **50** | `hv_focal_cat` = `POS` AND `Race` = `Coloured` |
| `cat_POS_RACE_Indian` | 30 → **33** | `hv_focal_cat` = `POS` AND `Race` = `Indian` |
| `cat_PAS_RACE_Black` | 180 → **198** | `hv_focal_cat` = `PAS` AND `Race` = `Black` |
| `cat_PAS_RACE_White` | 45 → **50** | `hv_focal_cat` = `PAS` AND `Race` = `White` |
| `cat_PAS_RACE_Coloured` | 45 → **50** | `hv_focal_cat` = `PAS` AND `Race` = `Coloured` |
| `cat_PAS_RACE_Indian` | 30 → **33** | `hv_focal_cat` = `PAS` AND `Race` = `Indian` |
| `cat_BAK_RACE_Black` | 150 → **165** | `hv_focal_cat` = `BAK` AND `Race` = `Black` |
| `cat_BAK_RACE_White` | 38 → **42** | `hv_focal_cat` = `BAK` AND `Race` = `White` |
| `cat_BAK_RACE_Coloured` | 38 → **42** | `hv_focal_cat` = `BAK` AND `Race` = `Coloured` |
| `cat_BAK_RACE_Indian` | 25 → **28** | `hv_focal_cat` = `BAK` AND `Race` = `Indian` |

### 2d. Income and Age — NOT quota'd (natural fallout)

By design. Monitor weekly in the Quotas dashboard; weight post-hoc if needed. Add quotas in a subsequent wave only if the natural distribution skews significantly.

### 2e. Race / Region edge buckets — not quota'd

Race `Other`, `Prefer not to answer`: accepted ungoverned (low volume, no balance target).
Region `OM` (Other Metros), `None`: screened out by existing Q21 disqualify rule.

### 2f. Test-scale quota table (survey 8839203)

For the test survey, use the limits below (production cap ÷ 10, round up). All 36 quotas; same names and same qualification logic as §2a–§2c, just with smaller limits for fast saturation.

| Quota name | Test limit | Quota name | Test limit |
|---|---|---|---|
| `cat_DSS` | 35 | `cat_DSS_RACE_Black` | 24 |
| `cat_POS` | 30 | `cat_DSS_RACE_White` | 6 |
| `cat_PAS` | 30 | `cat_DSS_RACE_Coloured` | 6 |
| `cat_BAK` | 25 | `cat_DSS_RACE_Indian` | 4 |
| `cat_DSS_REG_GAU` | 20 | `cat_POS_RACE_Black` | 20 |
| `cat_DSS_REG_WC` | 8 | `cat_POS_RACE_White` | 5 |
| `cat_DSS_REG_KZN` | 8 | `cat_POS_RACE_Coloured` | 5 |
| `cat_DSS_REG_EC` | 4 | `cat_POS_RACE_Indian` | 4 |
| `cat_POS_REG_GAU` | 17 | `cat_PAS_RACE_Black` | 20 |
| `cat_POS_REG_WC` | 7 | `cat_PAS_RACE_White` | 5 |
| `cat_POS_REG_KZN` | 7 | `cat_PAS_RACE_Coloured` | 5 |
| `cat_POS_REG_EC` | 4 | `cat_PAS_RACE_Indian` | 4 |
| `cat_PAS_REG_GAU` | 17 | `cat_BAK_RACE_Black` | 17 |
| `cat_PAS_REG_WC` | 7 | `cat_BAK_RACE_White` | 5 |
| `cat_PAS_REG_KZN` | 7 | `cat_BAK_RACE_Coloured` | 5 |
| `cat_PAS_REG_EC` | 4 | `cat_BAK_RACE_Indian` | 3 |
| `cat_BAK_REG_GAU` | 14 | | |
| `cat_BAK_REG_WC` | 6 | | |
| `cat_BAK_REG_KZN` | 6 | | |
| `cat_BAK_REG_EC` | 3 | | |

---

## 3. Hidden value on the assignment page

Only ONE hidden value is needed: `hv_focal_cat`. Its numeric question ID goes into the JS at `DEST_QID` (currently set to 12 in test survey 8839203 — verify in Build view).

| Alias | Field name in test survey 8839203 | Purpose | Default value |
|---|---|---|---|
| `hv_focal_cat` | "Assign Focal Category" | Set by JS to `DSS` / `POS` / `PAS` / `BAK` or `SCREENOUT` | empty |

**Existing fields to DELETE from test survey 8839203:**
- "Assignment log" (the old `hv_assign_log`) — not needed under the click-handler design. Optional: keep it and have JS write to it for per-respondent debugging, but the screenshot evidence in the response viewer is usually enough.
- "Assignment lock" (the old `hv_assign_locked`) — not needed when Back button is disabled on the assignment page (recommended in §1).
- "No Quota Screenout flag" (the old `hv_screen_no_quota`) — redundant. The JS writes `SCREENOUT` directly into `hv_focal_cat` when no eligible category exists.

**Page settings:**
- **Disable Back button on this page** (Alchemer page settings → uncheck "Show Back Button"). Prevents respondent from going back, changing SQ1, and re-triggering the random pick with a different outcome.

**Page-level skip logic on assignment page:**
- IF `hv_focal_cat` is exactly `SCREENOUT` → skip to screen-out terminal page
- IF `hv_focal_cat` is empty (JS errored entirely) → skip to screen-out terminal page (fail-safe)
- ELSE → continue to brand deep-dive pages

---

## 4. SQ1 reading — direct DOM access, no piping

Because SQ1 and `hv_focal_cat` are on the same page, the JavaScript reads SQ1's checkbox state directly from the DOM via `document.querySelectorAll("[type=checkbox]")` inside the SQ1 question wrapper. No merge codes, no spans, no Text element required.

**SQ1 reporting values** still need to be correct for the data export (not for the picker — the picker maps by checkbox `title` attribute via `CORE_MATCHES`). Reporting values: `DSS`, `POS`, `PAS`, `BAK` (case-sensitive) — verified 2026-05-11.

**CORE_MATCHES mapping in the JS** is what determines which checkbox → which code. Each entry pairs a substring of the question option's title with a code. Current mapping:

| Substring in option title | Maps to code |
|---|---|
| `Dry Seasoning` | `DSS` |
| `Pour Over` | `POS` |
| `Pasta Sauce` | `PAS` |
| `Baking Mix` | `BAK` |

If the option labels in SQ1 change, update `CORE_MATCHES` in the JS so the substring still matches.

---

## 5. Webhook config (existing, unchanged)

| Setting | Value |
|---|---|
| Type | Webhook Action |
| Name | IPK Quota Fetch |
| Method | GET |
| Protocol | https:// |
| URL | `restapi.alchemer.com/v5/survey/{SURVEY_ID}/quotas?api_token=...&api_token_secret=...` |
| Asynchronous | No |
| Response handling | Display it |
| Position | **Above** the JavaScript Action in the page action list |

The response JSON is written to a `<div class="sg-http-content">` on the rendered page. JS reads from that div.

---

## 6. JavaScript Action — full code

Paste the block below into the JavaScript Action on the Screener / Focal Assignment page. Update `DEST_QID` to the numeric question ID of `hv_focal_cat` and `SOURCE_QID` to the numeric question ID of SQ1 (both in Build view → hover question → ID shows). Current test survey 8839203 values are already filled in.

```javascript
const DEST_QID = 12
const SOURCE_QID = 6

const CORE_MATCHES = [
  {match: 'Dry Seasoning', code: 'DSS'},
  {match: 'Pour Over', code: 'POS'},
  {match: 'Pasta Sauce', code: 'PAS'},
  {match: 'Baking Mix', code: 'BAK'}
]

const CORE_CODES = ['DSS', 'POS', 'PAS', 'BAK']

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

  // Build {DSS: true/false, POS: ..., PAS: ..., BAK: ...} from webhook quota data.
  // Defaults to true if a cat quota isn't found (don't block on misconfig).
  // Returns null if webhook output is missing — caller falls back to no filtering.
  function getEligibleCats() {
    var node = document.querySelector(".sg-http-content")
    if (!node) return null
    try {
      var parsed = JSON.parse(node.innerText)
      if (parsed.result_ok !== true && parsed.result_ok !== "ok") return null
      var quotas = parsed.quotas || parsed.data || []
      var eligible = {}
      CORE_CODES.forEach(function(code) {
        eligible[code] = true
        for (var i = 0; i < quotas.length; i++) {
          if (quotas[i].name === "cat_" + code) {
            var count = parseInt(quotas[i].responses || quotas[i].count || 0, 10)
            var limit = parseInt(quotas[i].limit || 0, 10)
            eligible[code] = (count < limit)
            return
          }
        }
      })
      return eligible
    } catch (e) {
      return null
    }
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

      // Filter to cats with quota room. Webhook missing → don't filter (Alchemer hard quota catches overshoot).
      var eligible = getEligibleCats()
      var pool = eligible ? answers.filter(function(c) { return eligible[c] === true }) : answers

      if (pool.length === 0) {
        if (dest) dest.value = "SCREENOUT"
        return
      }

      if (dest) dest.value = shuffle(pool)[0] || ""
    })
  }
})
```

**Failure modes — by design:**
- **Webhook returns garbage / network fails / response absent** → `getEligibleCats()` returns `null` → pool = unfiltered answers → random pick from all SQ1-selected cats. Alchemer's hard `cat_*` quotas still enforce on submit. Worst case: respondent gets DQ'd by Alchemer on assignment-page submit rather than being prevented up front. No data corruption.
- **No SQ1 boxes checked** → `answers` is empty → `pool` is empty → `hv_focal_cat = "SCREENOUT"` → screen-out skip rule fires. (Add SQ1 required-validation on the question itself to prevent this in normal flow.)
- **All selected cats are full** → `pool` is empty → `SCREENOUT`.
- **JS error before click handler attaches** → `hv_focal_cat` stays empty → fail-safe skip rule sends respondent to screen-out.
- **Respondent navigates back** → prevented by disabling Back button on this page (see §3).

---

## 7. Quota trigger settings (Alchemer)

For each quota, set the trigger so DQ fires as early as possible:

- **Trigger:** "Display the Survey Disqualification Page"
- **Evaluation:** On every page submit (default)
- **Critical:** With the page order recommended in §1, all 36 quotas have their logic populated by the end of the Focal Assignment page. Quota DQ fires when respondent submits that page — they never reach the brand deep-dive blocks.

If you keep demographics late, regional/race quotas only fire when demographics are submitted. Respondent may complete most of the survey before getting DQ'd.

---

## 8. Test plan

### Test environment
- **Test survey:** 8839203 (IPK Brand Health control test)
- **Test scale:** all production limits ÷ 10, rounded up. E.g. cat_DSS = 35, cat_DSS_REG_GAU = 20 (193 ÷ 10 = 19.3 → 20).

### Pre-flight checks

1. **SQ1 reporting values** — open SQ1 in Build view, confirm 4 core options have reporting values exactly `DSS`, `POS`, `PAS`, `BAK`. ✓ Verified 2026-05-11.
2. **Region reporting values** — confirm `GAU`, `WC`, `KZN`, `EC`. ✓ Verified 2026-05-11.
3. **Race reporting values** — confirm `Black`, `White`, `Coloured`, `Indian`. ✓ Verified 2026-05-11.
4. **Question IDs in JS** — verify `DEST_QID` matches `hv_focal_cat`'s question ID and `SOURCE_QID` matches SQ1's question ID. Test survey 8839203: 12 and 6 respectively.
5. **CORE_MATCHES substrings** — verify each substring in the JS array appears in the corresponding SQ1 option's title (the visible question option label). If labels were translated or reworded, update the substrings.
6. **Webhook ordering** — confirm Webhook Action is ABOVE JS Action in the page action list. Webhook must have run before the page is interactive.
7. **Back button disabled** on the assignment page (Alchemer page settings).

### Smoke test (1 response)

Pick `Dry Seasonings & Spices` + `Pour Over Hot Beverages` at SQ1. Continue to next page.

In the Response Details viewer, "Assign Focal Category" should show either `DSS` or `POS` (both are eligible if both cat quotas have room).

For a deeper check, open browser DevTools console before clicking Next:
- After clicking Next, no errors should appear.
- If you want a per-pick log, temporarily add `console.log("IPK pick:", dest.value, "from pool", pool)` before the final `dest.value = ...` assignment.

### Hard quota fire test (manual)

1. Manually set `cat_DSS` limit to 1 in Alchemer.
2. Submit one response, force pick to DSS (or pick `Dry Seasonings & Spices` only at SQ1).
3. Submit a second response, pick `Dry Seasonings & Spices` only at SQ1.
4. Expected: response 2 hits `hv_focal_cat = SCREENOUT`, routed to screen-out page.

### Bulk simulation (100 responses, automated)

Use Alchemer's Test Data Generator with realistic SQ1 / Region / Race distributions. After 100 responses:
- All 4 cat_* should be partially filled.
- `hv_assign_log` distribution should show balanced eligibility filtering.
- No quota should be OVER its limit (Alchemer enforces).
- Region × Cat and Race × Cat distributions should be roughly proportional with no cell over 110% of target.

### Sign-off criteria
- Bulk sim shows correct assignment behaviour for at least 100 responses.
- No quota over limit.
- Screen-out fires when expected.
- Back-button preserves original assignment.

---

## 9. Migration: test → live IPK

After test survey passes sign-off:

1. **Live survey ID:** 8822527 (IPK Brand Health Wave 1).
2. **Rebuild 36 quotas in live survey** at production scale. Names must match exactly (the JS reads by name). Jess can populate from this spec.
3. **Restructure pages** per §1 if not already in that order.
4. **Copy the Text element, Webhook Action, JavaScript Action** from test to live (page copy via Build → Copy Page). Quotas do NOT transfer between surveys — rebuild manually.
5. **Update the webhook URL** with the LIVE survey's API token / survey ID.
6. **Look up new hidden value question IDs** in the live survey's Build view (they will differ from test) and update the JS.
7. **Re-run smoke test + hard quota fire test** in live.
8. **Delete the legacy random-pick JavaScript** from live (the pre-quota-aware version).
9. **Send a small batch (~20 responses)** through panel, verify `hv_assign_log` in the data, before opening full fieldwork.

---

## 10. Monitoring during fieldwork

**Daily:**
- Alchemer Quotas dashboard — note any cell approaching cap.
- Spot-check `hv_assign_log` for unexpected `SCREENOUT` rates.

**Weekly:**
- Age and Income natural-fallout distributions — compare to SA adult population. Flag if any band is < 50% of expected share.

**Manual intervention:**
- If a demographic cell hits cap while category total is still < 70% — top up panel for complementary cells, OR accept slight under-fill.
- If category screen-out rate exceeds 20% — investigate panel composition vs SQ1 selection patterns.

---

## 11. What this replaces — design evolution

This spec went through three iterations on 2026-05-11. Recording for future reference:

- **Iteration 1 (rejected as over-complex):** Soft-scoring JS that read 36 quotas via webhook + read Region/Race spans piped cross-page + computed fill % per dimension + tie-broke randomly. Fragile, hard to debug, span piping never validated.
- **Iteration 2 (intermediate):** Cross-page architecture with a separate Focal Assignment page. JS read 4 cat_* counts + filtered SQ1 candidates piped via hidden span. Demographics enforced by Alchemer's native quota engine. Still required a Text element with merge-code-piped span for SQ1, which was the unresolved blocker from the prior session.
- **Iteration 3 (LOCKED — what this spec describes):** SQ1 and `hv_focal_cat` on the **same page**. JS attaches click handler to Next button, reads SQ1 checkboxes directly via DOM (no piping), filters via webhook quota data, random-picks. Builds on Duncan's existing legacy random-pick script — adds only a `getEligibleCats()` function and a filter step. No Text element. No span. One hidden value instead of three or four.

The webhook stays unchanged across all iterations. The 36-quota structure stays unchanged.
