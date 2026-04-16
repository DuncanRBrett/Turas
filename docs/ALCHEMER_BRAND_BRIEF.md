# Alchemer Programming Brief -- Brand Health Module

**For:** Jess (Alchemer programming) + Claude (Lua scripting, routing logic, QA)
**Date:** 2026-04-16
**Status:** Ready for programming

---

## Overview

This brief covers Alchemer survey programming for the Turas brand health module using the Romaniuk CBM (Category Buyer Mindset) questionnaire architecture. The survey collects data across multiple categories with one focal category per respondent for the full CEP battery.

**Key constraint:** The CEP matrix (15-20 screens) can only run for ONE focal category per respondent. Everything else is lightweight and stretches across categories.

---

## Survey Flow

```
1. SCREENER + DEMOGRAPHICS
   |
2. CATEGORY QUALIFICATION (MR across all study categories)
   |
3. FOCAL CATEGORY ASSIGNMENT (invisible, Lua-driven)
   |
4. BRAND AWARENESS -- all qualified categories
   |
5. CEP MATRIX -- focal category only (15-20 screens)
   |
6. BRAND ATTITUDE -- focal category only (grid + conditional OE)
   |
7. CATEGORY BUYING -- focal category only
   |
8. BRAND PENETRATION FULL -- focal category only
   |
9. BRAND PENETRATION LIGHT -- non-focal qualified categories
   |
10. [OPTIONAL] WOM BATTERY -- brand-level (if enabled)
    |
11. [OPTIONAL] DBA BATTERY -- brand-level (if enabled)
    |
12. DEMOGRAPHICS (remainder) + CLOSE
```

---

## Lua Routing Logic

### Focal Category Assignment

The core routing challenge: assign ONE focal category per respondent from their qualified categories. Three methods (configurable per study):

#### Method 1: Balanced (default)

```lua
-- Balanced assignment: random with equal probability
-- Place this in a hidden question after category qualification

function balanced_assign(qualified_categories)
    if #qualified_categories == 0 then return nil end
    if #qualified_categories == 1 then return qualified_categories[1] end

    -- Use respondent ID as seed for reproducibility
    local resp_id = sgapi:get_respondent_id()
    math.randomseed(resp_id)
    local idx = math.random(1, #qualified_categories)
    return qualified_categories[idx]
end

-- Get qualified categories from screener MR question
local qualified = {}
local cat_options = {
    {id = 10001, name = "Frozen Vegetables"},
    {id = 10002, name = "Ready Meals"},
    {id = 10003, name = "Sauces"},
    {id = 10004, name = "Snacks"}
}

for _, opt in ipairs(cat_options) do
    if sgapi:get_value(opt.id) == 1 then
        table.insert(qualified, opt.name)
    end
end

local focal = balanced_assign(qualified)
sgapi:set_value(FOCAL_CATEGORY_HIDDEN_QID, focal)
```

#### Method 2: Quota-based

```lua
-- Quota assignment: ensures minimum n per category
-- Requires quota tracking via Alchemer quotas or custom counter

function quota_assign(qualified_categories, quotas)
    -- Find category with lowest fill rate among qualified
    local best_cat = nil
    local best_fill = math.huge

    for _, cat in ipairs(qualified_categories) do
        local fill = quotas[cat] or 0
        if fill < best_fill then
            best_fill = fill
            best_cat = cat
        end
    end

    return best_cat
end
```

#### Method 3: Priority-weighted

```lua
-- Priority assignment: over-sample priority categories
local priority_weights = {
    ["Frozen Vegetables"] = 0.35,
    ["Ready Meals"] = 0.25,
    ["Sauces"] = 0.20,
    ["Snacks"] = 0.20
}

function priority_assign(qualified_categories, weights)
    -- Build cumulative probability among qualified categories
    local total_weight = 0
    for _, cat in ipairs(qualified_categories) do
        total_weight = total_weight + (weights[cat] or 0.25)
    end

    local rand = math.random() * total_weight
    local cumulative = 0
    for _, cat in ipairs(qualified_categories) do
        cumulative = cumulative + (weights[cat] or 0.25)
        if rand <= cumulative then
            return cat
        end
    end

    return qualified_categories[1]  -- fallback
end
```

### Category-Conditional Display

```lua
-- Show/hide pages based on focal category assignment
-- Place as page logic on each category-specific page

local focal = sgapi:get_value(FOCAL_CATEGORY_HIDDEN_QID)

-- For CEP matrix pages (focal only):
if focal ~= "Frozen Vegetables" then
    sgapi:hide_page()
end

-- For brand awareness pages (all qualified):
local cat_qualified = sgapi:get_value(CAT_SCREENER_QID)
if not (cat_qualified == 1) then
    sgapi:hide_page()
end
```

### Brand List Piping

```lua
-- Pipe the correct brand list based on focal category
-- Each category has its own brand list

local brands = {
    ["Frozen Vegetables"] = {
        {id = "IPK", label = "IPK"},
        {id = "MCCAIN", label = "McCain"},
        {id = "FINDUS", label = "Findus"}
    },
    ["Ready Meals"] = {
        {id = "IPK", label = "IPK"},
        {id = "COMPA", label = "Competitor A"}
    }
}

local focal = sgapi:get_value(FOCAL_CATEGORY_HIDDEN_QID)
local brand_list = brands[focal] or {}

-- Set answer options dynamically
for i, brand in ipairs(brand_list) do
    sgapi:set_option_text(CEP_QUESTION_ID, i, brand.label)
end
```

### Rejection Open-End Loop

```lua
-- Show rejection OE for each brand coded 4 (Reject) at attitude question
local attitude_qid = ATT_QUESTION_ID
local brands = {"IPK", "MCCAIN", "FINDUS"}
local rejected_brands = {}

for i, brand in ipairs(brands) do
    local attitude_val = sgapi:get_value(attitude_qid, i)
    if attitude_val == 4 then
        table.insert(rejected_brands, brand)
    end
end

-- Show OE page for each rejected brand
-- Use piped text: [question("value"), id="FOCAL_CATEGORY"]
if #rejected_brands == 0 then
    sgapi:hide_page()
end
```

---

## Programming Notes

### CEP Matrix (Core Battery 2)

- **One statement per screen** (not a grid)
- Brand list as **buttons**, randomised per respondent, consistent across all screens
- Statement order **randomised across respondents**
- "None of these" anchored at end
- Intro screen shown once before first CEP screen
- 15-20 screens at ~15 seconds each

### Brand Attitude (Core Battery 3)

- **Grid format** on desktop, card-swipe on mobile
- 5-level scale (must not change codes across categories)
- Brand order randomised within grid
- QBRANDATT2 (rejection OE) loops for each rejected brand

### Brand Awareness (Core Battery 1)

- **Alphabetical order** (recognition task, not association)
- Show logos/pack images alongside names where available
- Run once per qualified category (not just focal)

### Brand Penetration (Core Battery 5)

- **Full version** (focal category): 2-3 questions depending on category type
- **Light version** (non-focal): single MR question only
- Brand list can be broader than attribute list (include smaller brands)

---

## Question Code Conventions

Codes must match Survey_Structure.xlsx QuestionCode column:

| Pattern | Example | Battery |
|---------|---------|---------|
| `BRANDAWARE_{CAT}` | `BRANDAWARE_FV` | awareness |
| `BRANDATTR_{CAT}_{NN}` | `BRANDATTR_FV_01` | cep_matrix |
| `BRANDATT1_{CAT}` | `BRANDATT1_FV` | attitude |
| `BRANDATT2_{CAT}` | `BRANDATT2_FV` | attitude_oe |
| `CATBUY_{CAT}` | `CATBUY_FV` | cat_buying |
| `BRANDPEN{N}_{CAT}` | `BRANDPEN1_FV` | penetration |
| `WOM_{TYPE}` | `WOM_POS_REC` | wom |
| `DBA_FAME_{ASSET}` | `DBA_FAME_LOGO` | dba |
| `DBA_UNIQUE_{ASSET}` | `DBA_UNIQUE_LOGO` | dba |

Category abbreviations should be consistent and documented in config.

---

## QA Checklist

Before fieldwork:

- [ ] All routing paths tested (qualify for 1 cat, 2 cats, 3 cats, all cats)
- [ ] Focal assignment produces balanced distribution (test with 20+ test completes)
- [ ] CEP matrix only shows for focal category
- [ ] Brand lists are correct per category (no cross-contamination)
- [ ] Statement randomisation working (check 3 different respondent paths)
- [ ] Brand button order randomised but consistent across CEP screens
- [ ] Rejection OE loops correctly for each rejected brand
- [ ] Light penetration only shows for non-focal qualified categories
- [ ] WOM/DBA batteries show/hide based on config
- [ ] Question codes match Survey_Structure.xlsx exactly
- [ ] Mobile rendering: card-swipe for attitude grid, readable CEP buttons
- [ ] Completion time within 15-minute target (test with real respondents)
- [ ] All "None of these" options anchored at end (not randomised)
- [ ] Data export produces expected column structure for Turas import

---

## Data Export Requirements

Alchemer export should produce:

- One row per respondent
- Column names matching question codes from Survey_Structure.xlsx
- Multi-mention questions: one column per brand (0/1 binary)
- Single-mention questions: one column with numeric code
- Open-ends: one column with text
- Hidden/system fields: focal category assignment column

The AlchemerParser module can generate Survey_Structure.xlsx from the Alchemer export structure if the question codes follow the conventions above.
