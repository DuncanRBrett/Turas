# Focal Category Assignment — Setup Manual

**Purpose:** Step-by-step setup for the quota-aware focal category assignment system used in IPK-style brand health studies on Alchemer.

**Audience:** Anyone setting up a new survey (test or live) that needs to randomly assign each respondent to one of N focal categories, while respecting quota fill levels.

**Companion docs:** - `IPK_FOCAL_ASSIGNMENT_SPEC.md` — design rationale, iteration history, full quota tables. - This file — practical setup checklist.

------------------------------------------------------------------------

## What this system does

On a screener page, the respondent ticks which of several product categories they buy (e.g. Dry Seasonings & Spices, Pour Over Sauces, Pasta Sauces, Baking Mixes). On clicking Next:

1.  JavaScript reads which boxes are ticked.
2.  JavaScript reads the current quota fill levels from a webhook response.
3.  JavaScript filters the ticked categories down to those whose quota isn't full.
4.  JavaScript random-picks one and writes it into a hidden value field.
5.  Alchemer's hard quotas catch any remaining over-fill as a safety net.

The result: even fill across all focal categories, with no manual quota management during fieldwork.

------------------------------------------------------------------------

## When to use this

Use this pattern when:

-   The survey has more than one possible focal category and you want a single random assignment per respondent.
-   You want to balance focal-category counts during fieldwork (not via post-hoc weighting).
-   You're using Alchemer's native quotas as a hard safety net.

Don't use this if:

-   Every respondent answers every category (no assignment needed).
-   You're balancing on demographic dimensions only — Alchemer's native quotas handle that without JavaScript.

------------------------------------------------------------------------

## Prerequisites

Before starting, have ready:

| Item | Source |
|----|----|
| Survey built with a multi-select screener question | Alchemer Build view |
| List of focal category codes (e.g. DSS, POS, PAS, BAK) | Your study design |
| Sample size targets per category | Your study design |
| Alchemer API token + secret | Account → API Access |
| Page order with demographics before the assignment page | Survey design |

------------------------------------------------------------------------

## Setup steps

### Step 1 — Create the hidden value for focal category

In Build view on the assignment page (typically your screener page):

1.  Click **Add New Action** → **Hidden Value Action**.
2.  **Name:** `Assign Focal Category` (this name becomes the column in exports).
3.  **Action Label** (optional but recommended): `focal_cat` — short, snake_case, becomes the SPSS variable name.
4.  Leave **Populate with the following** and **Populate with a calculated value** both empty. The JavaScript will write to this field.
5.  Save.
6.  **Note the question ID** — hover the action in Build view and the numeric ID appears. You'll need this for the JS (`DEST_QID`).

### Step 2 — Confirm the screener question reporting values

The screener question (call it SQ1) must have reporting values that are **stable and case-sensitive**. The JS doesn't read these directly, but downstream logic and exports do.

For each option that maps to a focal category, set its reporting value to the category code (e.g. `DSS`, `POS`, `PAS`, `BAK`). Non-core options (e.g. Pestos, Salad Dressings) can have any reporting value — they'll be ignored by the picker.

**Note the SQ1 question ID** — you'll need this for the JS (`SOURCE_QID`).

### Step 3 — Build the category quotas

For each focal category, create one hard quota:

**Build → Quotas → Create Quota:**

| Field | Setting |
|----|----|
| Quota Type | **Hard Quota — Disqualify when Full** |
| Quota Action | Display the Survey Disqualification Page |
| Name | `cat_<CODE>` — e.g. `cat_DSS` (lowercase `cat_`, uppercase code, single underscore) |
| Quota Limit | Your target sample size for that category |
| Qualification Logic | "Assign Focal Category" — *is exactly equal to* — `<CODE>` |

Repeat for each category. Names must match exactly — the JavaScript reads them by name via the webhook.

**Optional:** Add demographic × category split quotas (Region × Cat, Race × Cat) for finer-grained balance. These are pure Alchemer-side enforcement; the JS doesn't read them. See `IPK_FOCAL_ASSIGNMENT_SPEC.md` §2b–2c for the full structure.

### Step 4 — Get an Alchemer API key

If you already have an API key for the account, skip this step. Otherwise:

1.  **Account → API Access** (top-right user menu → Account → API Access).
2.  Click **Create API Key**.
3.  Name it descriptively (e.g. `Focal Assignment Quota Read`).
4.  Alchemer shows the **API Key** (token) and **API Key Secret**.
5.  **Copy both immediately** — the secret is shown only once and cannot be recovered later. If you lose it, you'll need to create a new key.
6.  Some Alchemer plans cap accounts at one API key; if so, the existing key must be reused.

**The API hostname for Alchemer is `api.alchemer.com`** — not `restapi.alchemer.com` (which is an older/different domain that returns 404). Confirm in Account → API Access; Alchemer displays the correct hostname for your account.

### Step 5 — Build the Webhook Action

On the assignment page:

1.  **Add New Action → Webhook Action**.

2.  **Name:** `Get Cat Quota Status`.

3.  **Method:** `Get`.

4.  **URL:**

    ```         
    https://api.alchemer.com/v5/survey/<SURVEY_ID>/quotas?api_token=<TOKEN>&api_token_secret=<SECRET>
    ```

    Replace `<SURVEY_ID>`, `<TOKEN>`, `<SECRET>` with your values. The protocol dropdown should be `https://`.

5.  **Fields to Pass:** leave on default; no fields need to be sent.

6.  **Run this action:** **Run when page is displayed to respondent**.

7.  **Asynchronous Connect:** **No**. The JS depends on the response being in the DOM before the click handler fires.

8.  **What do you want to do with the data/content returned from the URL?:** **Display it**. This puts the JSON into a `<div class="sg-http-content">` on the page where the JS can read it.

9.  Save.

**Action ordering:** In the Build view's list of actions for this page, the Webhook Action must appear **above** the JavaScript Action. Alchemer fires actions top-to-bottom.

### Step 6 — Build the JavaScript Action

On the assignment page:

1.  **Add New Action → JavaScript Action**.
2.  **Name:** `Focal Category Picker`.
3.  **Run this action:** **Run when page is displayed to respondent**.
4.  Paste the script below, then **update the constants at the top** (see Step 7).
5.  Save.

``` javascript
const DEST_QID = 12         // ID of the "Assign Focal Category" hidden value
const SOURCE_QID = 6        // ID of the multi-select screener question

const CORE_MATCHES = [      // Substring → category code mapping
  {match: 'Dry Seasoning', code: 'DSS'},
  {match: 'Pour Over',     code: 'POS'},
  {match: 'Pasta Sauce',   code: 'PAS'},
  {match: 'Baking Mix',    code: 'BAK'}
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

  // Returns {DSS:true, ...} for any cat whose quota is full.
  // Webhook missing/broken → returns {} (no filtering; Alchemer hard quota is the safety net).
  function getFullCats() {
    var full = {}
    var node = document.querySelector(".sg-http-content")
    if (!node) return full
    try {
      var parsed = JSON.parse(node.textContent)
      var quotas = parsed.data || parsed.quotas || []
      CORE_CODES.forEach(function(code) {
        for (var i = 0; i < quotas.length; i++) {
          if (quotas[i].name === "cat_" + code) {
            var count = parseInt(quotas[i].responses || quotas[i].count || 0, 10)
            var limit = parseInt(quotas[i].limit || 0, 10)
            if (limit > 0 && count >= limit) full[code] = true
            break
          }
        }
      })
    } catch (e) {}
    return full
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

      // Drop full cats; if all are full, fall back to the original list and let
      // Alchemer's hard quota DQ on submit (same safety net as before).
      var full = getFullCats()
      var pool = answers.filter(function(c) { return !full[c] })
      if (pool.length === 0) pool = answers

      if (dest) dest.value = shuffle(pool)[0] || ""
    })
  }
})
```

### Step 7 — Update the constants for your survey

The constants at the top of the JS are the only things that change between surveys:

| Constant | What to set it to |
|----|----|
| `DEST_QID` | Question ID of your "Assign Focal Category" hidden value (Step 1) |
| `SOURCE_QID` | Question ID of your multi-select screener question (Step 2) |
| `CORE_MATCHES` | One entry per focal category. `match` is a substring of the screener option's visible label; `code` is the category code (matches the quota names and the screener reporting values) |
| `CORE_CODES` | List of all category codes, used to build quota lookup keys |

**Important:** `CORE_MATCHES[i].match` is matched against the checkbox's `title` attribute — which is usually the option's visible label. If options are translated or reworded, update the substrings to match the new labels.

### Step 8 — Disable the Back button on the assignment page

In Build view, click the page, then **Page Settings → Show Back Button → Off**.

This prevents respondents from navigating back, re-ticking SQ1, and re-triggering the random pick — which could produce a different focal category and corrupt the quota fill.

### Step 9 — Hide the webhook output from respondents

By default, the webhook's "Display it" setting renders the raw JSON response on the page. Hide it via theme CSS:

1.  **Style tab → HTML/CSS Editor** (bottom-right of the Style tab).

2.  Add:

    ``` css
    .sg-http-content { display: none; }
    ```

3.  Save.

This applies survey-wide. The JS reads `.sg-http-content` via `.textContent`, which works regardless of `display: none`.

### Step 10 — Add fail-safe skip logic (optional but recommended)

On the assignment page, add page-level skip logic:

-   IF "Assign Focal Category" is empty (JS errored entirely) → skip to screen-out page.

This catches the edge case where the JS doesn't run at all (e.g. respondent has JavaScript disabled).

------------------------------------------------------------------------

## Per-survey configuration summary

When porting this setup to a new survey, update these values:

| Where | What to change |
|----|----|
| Webhook URL | Survey ID in path; API token + secret in query string |
| JS `DEST_QID` | Question ID of the hidden value in the new survey |
| JS `SOURCE_QID` | Question ID of the screener in the new survey |
| JS `CORE_MATCHES` | Substrings to match against screener option labels |
| JS `CORE_CODES` | Category codes |
| Quotas | Names (`cat_<CODE>`), limits (target sample sizes), qualification (point at the new hidden value) |
| Screener reporting values | Match the category codes (case-sensitive) |

Everything else — page settings, CSS, action ordering — is the same.

------------------------------------------------------------------------

## Testing checklist

### Before opening the survey

1.  **Webhook URL test:** Paste the full URL into a browser. Expected: JSON with `"result_ok":true` and a `quotas` array containing your `cat_<CODE>` entries with current counts and limits.
2.  **Reporting values:** Open the screener and the hidden value question; confirm the reporting values exactly match the codes used in quota qualification logic (case-sensitive).
3.  **Question IDs:** Hover questions in Build view; confirm `DEST_QID` and `SOURCE_QID` in the JS match the actual IDs.

### Smoke test (one response)

1.  Open the survey via the live launch link (Share tab → primary survey link), **not** the in-builder Preview — `SGAPI.surveyData` is unreliable in the in-builder preview.
2.  Get to the assignment page, tick two or three categories at the screener.
3.  Open DevTools → Console.
4.  Click Next.
5.  In Response Explorer, find the new response and check the "Assign Focal Category" field — should be one of the category codes for a category you ticked.

### Console diagnostic (if smoke test fails)

In the console on the assignment page (after ticking boxes but before clicking Next):

``` javascript
(function() {
  var sid = Object.keys(SGAPI.surveyData)[0]
  var info = SGAPI.surveyData[sid]
  var pg = info.currentpage
  var src = document.getElementById("sgE-"+info.id+"-"+pg+"-"+SOURCE_QID+"-box")
  var dst = document.getElementById("sgE-"+info.id+"-"+pg+"-"+DEST_QID+"-element")
  var http = document.querySelector(".sg-http-content")
  console.log("survey id:", info.id, "page:", pg)
  console.log("source (screener):", src)
  console.log("dest (focal cat):", dst)
  console.log("webhook content:", http ? http.textContent.substring(0, 300) : "MISSING")
  if (src) {
    src.querySelectorAll("[type=checkbox]:checked").forEach(function(b) {
      console.log("  checked title:", b.title)
    })
  }
})()
```

Use the **Troubleshooting** table below to interpret the output.

### Hard quota fire test

1.  Manually set one `cat_<CODE>` quota's limit to 1 in Alchemer.
2.  Submit a response that gets assigned to that category — quota now at 1/1.
3.  Submit a second response that ticks **only** that category at the screener.
4.  Expected: JS sees the cat is full, has nothing else to pick from → falls back to assigning the full category → Alchemer's hard quota DQs the respondent on submit.
5.  Reset the limit before opening real fieldwork.

------------------------------------------------------------------------

## Troubleshooting

| Symptom | Likely cause | Fix |
|----|----|----|
| Webhook URL returns 404 in browser | Wrong API hostname | Use `api.alchemer.com`, not `restapi.alchemer.com` |
| Webhook URL returns `{"result_ok":false,"code":"...","message":"Invalid credentials"}` | Wrong token, wrong secret, or secret was truncated when pasted | Re-copy from Account → API Access; if secret was lost at creation, create a new API key |
| Webhook returns `{"data":[]}` | Quotas haven't been built in the target survey | Build the `cat_<CODE>` quotas in this survey (quotas don't carry across surveys) |
| `.sg-http-content` div exists but is empty | Webhook action's "What do you want to do with the data" not set to "Display it" | Edit the Webhook Action and set response handling to "Display it" |
| `SGAPI.surveyData` is undefined / null | You're testing in the in-builder Preview, which doesn't fully load SGAPI | Test via the live launch link (Share tab → survey link), not the in-builder preview |
| `source element (screener): null` in diagnostic | `SOURCE_QID` doesn't match the screener's actual ID in this survey | Hover the screener in Build view, copy the ID, update `SOURCE_QID` in the JS |
| `dest element (focal cat): null` in diagnostic | `DEST_QID` doesn't match the hidden value's ID, OR they're not on the same page | Confirm both questions are on the same page; update `DEST_QID` |
| Checked boxes detected, but `answers` is empty | `CORE_MATCHES` substrings don't match the option labels | Check the actual option titles via DevTools Elements panel; update the `match` substrings |
| Focal category written, but always the same one | Pool only contains one eligible code (others full, or only one core option ticked) | Working as designed. Check quota fill levels and SQ1 tick patterns |
| Assignment fires but quota doesn't DQ when full | Quota qualification logic points at wrong question, OR reporting values mismatch | Open the quota; confirm qualification points at "Assign Focal Category" and the value is case-correct |

------------------------------------------------------------------------

## Security notes

The webhook URL contains your API token and secret in plain text. Who can see it:

-   **Anyone with survey edit access** can open the Webhook Action and read the URL.
-   **Anyone with response viewer access** sees the URL in the per-response action log.
-   **Respondents cannot** — the URL is server-side; only the response body is rendered to the page, and that's hidden via CSS.

Practical implications:

-   For solo or small-team studies (just the project owners with admin access), no special action required.
-   Before granting edit access to outside collaborators, consider whether they should see the credentials. There's no way to mask the URL field inside the Webhook Action UI.
-   If your Alchemer plan allows multiple API keys, use a dedicated key for the webhook (named for the project) so you can delete it at end of fieldwork without affecting other integrations.
-   If your plan caps you at one API key, treat that key as effectively permanent. Restrict edit access accordingly.
-   If credentials are ever compromised and self-service rotation isn't available, contact Alchemer support — they can regenerate keys server-side.

Don't paste the full URL (with credentials) into Slack, email, screen shares, or third-party tools beyond what's necessary.

------------------------------------------------------------------------

## Migration: test survey → live survey

When moving from test scale to live:

1.  **Build quotas in the live survey** at live limits. Quotas don't transfer between surveys — they must be recreated.
2.  **Copy the Webhook Action and JavaScript Action** to the live survey's assignment page (Build → Copy Page, then prune what you don't need).
3.  **Update the Webhook URL** with the live survey's ID. Use the same API key, or create a dedicated key for live (if your plan allows multiple).
4.  **Update `DEST_QID` and `SOURCE_QID`** in the JS to match the question IDs in the live survey — IDs do not carry across surveys.
5.  **Re-run the smoke test and hard-quota fire test** in live.
6.  **Delete any legacy/random-pick scripts** from the live survey to avoid double-assignment.
7.  **Send a small panel batch (\~20 responses)** first; check the "Assign Focal Category" distribution in the data before opening full fieldwork.

------------------------------------------------------------------------

## Maintenance during fieldwork

**Daily during active fieldwork:**

-   Alchemer Quotas dashboard → check fill levels; note any quota approaching cap.
-   Response Explorer → spot-check that "Assign Focal Category" is populated on every completed response.

**If a category fills early:**

-   The JS will stop assigning new respondents to that category automatically — no manual intervention needed.
-   Respondents who can only buy the full category will fall through to the hard quota and be DQ'd on submit.
-   If DQ rate exceeds 20%, investigate panel composition vs. screener selection patterns.

**At end of fieldwork:**

-   Export data with the "Assign Focal Category" column included as the focal-cat variable for analysis.
-   If you created a dedicated API key for this project, consider deleting it from Account → API Access.

------------------------------------------------------------------------

## Quick reference — checklist

A new survey is ready to launch when all of these are true:

-   [ ] Hidden value "Assign Focal Category" exists on the assignment page, populate fields are empty
-   [ ] Screener question has correct reporting values for each focal category code (case-sensitive)
-   [ ] One `cat_<CODE>` hard quota exists per focal category, with correct limit and qualification logic
-   [ ] Webhook Action exists, hostname is `api.alchemer.com`, async=No, response handling=Display it, runs on page display
-   [ ] JavaScript Action exists, constants updated for this survey, action sits below the Webhook Action in the action list
-   [ ] Back button disabled on the assignment page
-   [ ] CSS rule `.sg-http-content { display: none; }` added to theme
-   [ ] Webhook URL pasted into a browser returns JSON with `cat_<CODE>` entries
-   [ ] Console diagnostic shows source / dest / webhook content all present
-   [ ] One smoke-test response shows "Assign Focal Category" populated with a valid code
-   [ ] Hard quota fire test confirms full categories DQ correctly

When all 11 boxes are ticked, the system is ready.
