# Part 5: Excel Data & Configuration File Structures

## Overview

This document provides explicit templates and examples for the two Excel files required to run Turas Conjoint Analysis:

1. **Data File** - Your survey response data (from Alchemer export)
2. **Configuration File** - Study parameters and attribute definitions

## 1. Data File Structure (Alchemer Export)

### 1.1 Required Format: Long Format

**One row per alternative per choice set per respondent**

### 1.2 Required Columns

| Column | Type | Description | Example Values |
|--------|------|-------------|----------------|
| `resp_id` | integer | Unique respondent identifier | 1, 2, 3, ... |
| `choice_set_id` | integer | Unique choice task identifier | 1, 2, 3, ... |
| `chosen` | integer | Selected alternative (1=chosen, 0=not chosen) | 0, 1 |
| `[attribute_1]` | character/factor | First attribute levels | "Low", "Medium", "High" |
| `[attribute_2]` | character/factor | Second attribute levels | "Brand A", "Brand B" |
| ... | ... | Additional attributes | ... |

### 1.3 Optional Columns

| Column | Type | Description | Example Values |
|--------|------|-------------|----------------|
| `alternative_id` | integer | Alternative position within choice set | 1, 2, 3 |
| `weight` | numeric | Respondent weight (for weighted analysis) | 1.0, 1.5, 0.8 |

### 1.4 Example: Standard CBC Data

**Filename:** `smartphone_conjoint_data.csv`

```csv
resp_id,choice_set_id,alternative_id,Price,Brand,Storage,Battery,chosen
1,1,1,$699,Apple,128GB,12hr,0
1,1,2,$599,Samsung,256GB,18hr,1
1,1,3,$499,Google,64GB,15hr,0
1,2,1,$799,Samsung,512GB,18hr,1
1,2,2,$699,Apple,256GB,12hr,0
1,2,3,$599,Google,128GB,15hr,0
2,1,1,$699,Apple,128GB,12hr,1
2,1,2,$599,Samsung,256GB,18hr,0
2,1,3,$499,Google,64GB,15hr,0
2,2,1,$799,Samsung,512GB,18hr,0
2,2,2,$699,Apple,256GB,12hr,0
2,2,3,$599,Google,128GB,15hr,1
```

**Key Points:**
- Respondent 1 saw 2 choice sets (ID 1 and 2)
- Each choice set has 3 alternatives
- Exactly ONE `chosen=1` per choice set
- All other alternatives have `chosen=0`
- Attribute values are EXACT text (case-sensitive)

### 1.5 Example: CBC with None Option

**Filename:** `restaurant_conjoint_data.csv`

```csv
resp_id,choice_set_id,alternative_id,Price,Cuisine,Location,Rating,chosen
1,1,1,$25,Italian,Downtown,4.2,0
1,1,2,$35,Japanese,Midtown,4.5,0
1,1,3,$20,Mexican,Uptown,4.0,1
1,2,1,$30,Italian,Uptown,4.3,0
1,2,2,$25,Japanese,Downtown,4.4,0
1,2,3,NONE,NONE,NONE,NONE,1
2,1,1,$25,Italian,Downtown,4.2,1
2,1,2,$35,Japanese,Midtown,4.5,0
2,1,3,$20,Mexican,Uptown,4.0,0
```

**Key Points for None Option:**
- None row has "NONE" (or "None") for all attributes
- Can use any consistent none label: "None", "NONE", "None of these", "Skip"
- Turas will auto-detect the none option
- Alternatively, can just have all `chosen=0` for a choice set (implicit none)

### 1.6 Validation Rules for Data File

✅ **MUST HAVE:**
1. Each choice set has exactly ONE `chosen=1`
2. Respondent IDs are consistent across their choice sets
3. Attribute values exactly match those in config file
4. No missing values in: resp_id, choice_set_id, chosen, or attributes
5. `chosen` column contains only 0 and 1

⚠️ **SHOULD HAVE:**
1. Balanced design (all respondents see same number of choice sets)
2. Consistent number of alternatives per choice set
3. At least 10 respondents per attribute level
4. Choice set IDs unique across all respondents (or use resp_id + set_number combination)

❌ **COMMON ERRORS:**
- Multiple `chosen=1` in same choice set
- No `chosen=1` in a choice set (unless intentional none)
- Attribute spelling doesn't match config (e.g., "Apple" vs. "apple")
- Missing choice sets for some respondents
- Non-integer values in chosen column

## 2. Configuration File Structure

### 2.1 File Format

**Excel workbook (.xlsx) with two sheets:**
1. **Settings** - Analysis parameters
2. **Attributes** - Attribute definitions

### 2.2 Settings Sheet Structure

Two columns: `Setting` and `Value`

| Setting | Value | Type | Required | Default | Description |
|---------|-------|------|----------|---------|-------------|
| `analysis_type` | `"choice"` | string | No | `"choice"` | Type of conjoint (always "choice" for CBC) |
| `estimation_method` | `"auto"` | string | No | `"auto"` | Estimation method: "auto", "mlogit", "clogit" |
| `baseline_handling` | `"first_level_zero"` | string | No | `"first_level_zero"` | "first_level_zero" or "all_levels_explicit" |
| `confidence_level` | `0.95` | numeric | No | `0.95` | Confidence level for intervals (0-1) |
| `choice_type` | `"single"` | string | No | `"single"` | "single", "single_with_none", "best_worst", "continuous_sum" |
| `data_file` | `"survey_data.csv"` | string | Yes* | - | Path to data file (relative or absolute) |
| `output_file` | `"results.xlsx"` | string | Yes* | - | Path for output file |
| `respondent_id_column` | `"resp_id"` | string | No | `"resp_id"` | Column name for respondent ID |
| `choice_set_column` | `"choice_set_id"` | string | No | `"choice_set_id"` | Column name for choice set ID |
| `chosen_column` | `"chosen"` | string | No | `"chosen"` | Column name for chosen indicator |
| `alternative_id_column` | `"alternative_id"` | string | No | `"alternative_id"` | Column name for alternative ID (optional) |
| `generate_market_simulator` | `TRUE` | logical | No | `TRUE` | Generate interactive market simulator? |
| `bootstrap_iterations` | `1000` | integer | No | `1000` | Bootstrap iterations for confidence intervals |
| `min_responses_per_level` | `10` | integer | No | `10` | Warning threshold for low response counts |
| `none_as_baseline` | `FALSE` | logical | No | `FALSE` | Force none option as baseline? |
| `none_label` | `"None"` | string | No | `"None"` | Label for none option in outputs |

\* Can be provided as arguments to `run_conjoint_analysis()` instead

### 2.3 Settings Sheet Example

**Sheet Name:** `Settings`

| Setting | Value |
|---------|-------|
| analysis_type | choice |
| estimation_method | auto |
| baseline_handling | first_level_zero |
| confidence_level | 0.95 |
| choice_type | single |
| data_file | smartphone_data.csv |
| output_file | smartphone_results.xlsx |
| respondent_id_column | resp_id |
| choice_set_column | choice_set_id |
| chosen_column | chosen |
| alternative_id_column | alternative_id |
| generate_market_simulator | TRUE |
| bootstrap_iterations | 1000 |
| min_responses_per_level | 10 |

### 2.4 Attributes Sheet Structure

Four columns: `AttributeName`, `NumLevels`, `LevelNames`, `DataType`

| Column | Type | Required | Description | Example |
|--------|------|----------|-------------|---------|
| `AttributeName` | string | Yes | Unique attribute identifier (must match data column name) | "Price" |
| `NumLevels` | integer | Yes | Number of levels for this attribute | 3 |
| `LevelNames` | string | Yes | Comma-separated list of level names (must match data exactly) | "$499, $599, $699" |
| `DataType` | string | No | "categorical" (only option in Phase 1) | "categorical" |

### 2.5 Attributes Sheet Example

**Sheet Name:** `Attributes`

| AttributeName | NumLevels | LevelNames | DataType |
|---------------|-----------|------------|----------|
| Price | 3 | $499, $599, $699 | categorical |
| Brand | 3 | Apple, Samsung, Google | categorical |
| Storage | 3 | 64GB, 128GB, 256GB | categorical |
| Battery | 3 | 12hr, 15hr, 18hr | categorical |

**Critical Rules:**
1. `AttributeName` MUST exactly match column name in data file
2. `LevelNames` MUST exactly match values in data (including capitalization, spaces, symbols)
3. Comma-separated list with NO extra spaces: `"Low, Medium, High"` ✅ NOT `"Low , Medium , High"` ❌
4. Order of levels determines baseline (first level = baseline if using `first_level_zero`)

## 3. Complete Examples

### 3.1 Example 1: Smartphone Preference Study

**Scenario:** Standard CBC, 3 brands × 3 price levels × 3 storage × 3 battery

#### Data File: `smartphone_data.csv`
```csv
resp_id,choice_set_id,alternative_id,Price,Brand,Storage,Battery,chosen
1,1,1,$699,Apple,128GB,12hr,0
1,1,2,$599,Samsung,256GB,18hr,1
1,1,3,$499,Google,64GB,15hr,0
1,2,1,$799,Samsung,512GB,18hr,1
1,2,2,$699,Apple,256GB,12hr,0
1,2,3,$599,Google,128GB,15hr,0
1,3,1,$499,Apple,64GB,18hr,0
1,3,2,$799,Google,512GB,12hr,0
1,3,3,$699,Samsung,128GB,15hr,1
# ... more respondents ...
```

#### Config File: `smartphone_config.xlsx`

**Settings Sheet:**
| Setting | Value |
|---------|-------|
| choice_type | single |
| data_file | smartphone_data.csv |
| output_file | smartphone_results.xlsx |
| respondent_id_column | resp_id |
| choice_set_column | choice_set_id |
| chosen_column | chosen |

**Attributes Sheet:**
| AttributeName | NumLevels | LevelNames | DataType |
|---------------|-----------|------------|----------|
| Price | 4 | $499, $599, $699, $799 | categorical |
| Brand | 3 | Apple, Samsung, Google | categorical |
| Storage | 4 | 64GB, 128GB, 256GB, 512GB | categorical |
| Battery | 3 | 12hr, 15hr, 18hr | categorical |

### 3.2 Example 2: Restaurant Choice with Opt-Out

**Scenario:** CBC with none option (can choose not to dine out)

#### Data File: `restaurant_data.csv`
```csv
resp_id,choice_set_id,alternative_id,Price,Cuisine,Location,Rating,chosen
1,1,1,$25,Italian,Downtown,4.2,0
1,1,2,$35,Japanese,Midtown,4.5,0
1,1,3,$20,Mexican,Uptown,4.0,0
1,1,4,NONE,NONE,NONE,NONE,1
1,2,1,$30,Italian,Uptown,4.3,1
1,2,2,$25,Japanese,Downtown,4.4,0
1,2,3,$40,Mexican,Midtown,4.6,0
1,2,4,NONE,NONE,NONE,NONE,0
# ... more respondents ...
```

#### Config File: `restaurant_config.xlsx`

**Settings Sheet:**
| Setting | Value |
|---------|-------|
| choice_type | single_with_none |
| data_file | restaurant_data.csv |
| output_file | restaurant_results.xlsx |
| none_label | None of these |
| none_as_baseline | FALSE |

**Attributes Sheet:**
| AttributeName | NumLevels | LevelNames | DataType |
|---------------|-----------|------------|----------|
| Price | 4 | $20, $25, $30, $35, $40 | categorical |
| Cuisine | 3 | Italian, Japanese, Mexican | categorical |
| Location | 3 | Downtown, Midtown, Uptown | categorical |
| Rating | 4 | 4.0, 4.2, 4.3, 4.4, 4.5, 4.6 | categorical |

**Note:** When defining levels for none option analysis:
- Include only the real product levels in `LevelNames`
- Do NOT include "NONE" in the level names
- Turas will auto-detect and handle the none option

### 3.3 Example 3: Your Noodle Study (from ChatGPT data)

**Scenario:** Real data from DE_noodle_conjoint_raw.xlsx

#### Data File: `DE_noodle_data.csv`
```csv
resp_id,choice_set_id,alternative_id,Price,MSG,PotassiumChloride,I+G,Salt,NutriScore,chosen
1,1,1,Low_071,MSG_Absent,PotassiumChloride_Absent,I+G_Absent,Salt_Normal,A,0
1,1,2,Mid_089,MSG_Present,PotassiumChloride_Present,I+G_Present,Salt_Reduced,C,1
1,1,3,High_107,MSG_Absent,PotassiumChloride_Present,I+G_Absent,Salt_Normal,E,0
# ... more data ...
```

#### Config File: `DE_noodle_config.xlsx`

**Settings Sheet:**
| Setting | Value |
|---------|-------|
| choice_type | single |
| data_file | DE_noodle_data.csv |
| output_file | DE_noodle_results.xlsx |
| baseline_handling | first_level_zero |
| estimation_method | mlogit |

**Attributes Sheet:**
| AttributeName | NumLevels | LevelNames | DataType |
|---------------|-----------|------------|----------|
| Price | 3 | High_107, Mid_089, Low_071 | categorical |
| MSG | 2 | MSG_Absent, MSG_Present | categorical |
| PotassiumChloride | 2 | PotassiumChloride_Absent, PotassiumChloride_Present | categorical |
| I+G | 2 | I+G_Absent, I+G_Present | categorical |
| Salt | 2 | Salt_Normal, Salt_Reduced | categorical |
| NutriScore | 5 | A, B, C, D, E | categorical |

**Important Notes:**
- Level names EXACTLY match data (e.g., "Low_071" not "Low")
- First level listed becomes baseline (utility=0) with `first_level_zero`
- Order matters for interpretation (typically worst→best for ordinal attributes)

## 4. Level Ordering Best Practices

### 4.1 Why Order Matters

**With `baseline_handling = "first_level_zero"`:**
- First level listed = baseline (utility = 0)
- Other levels' utilities are relative to baseline
- Affects interpretation but NOT relative importance

### 4.2 Recommended Ordering

**For Ordinal Attributes (has natural order):**

✅ **GOOD: Worst to Best**
```
Price: High, Medium, Low
Rating: 1-star, 2-star, 3-star, 4-star, 5-star
Quality: Poor, Fair, Good, Excellent
```
**Why:** Utilities will be increasingly positive, making interpretation intuitive

✅ **ALSO GOOD: Best to Worst**
```
Price: Low, Medium, High
Rating: 5-star, 4-star, 3-star, 2-star, 1-star
```
**Why:** Utilities will be increasingly negative, also interpretable

❌ **BAD: Random Order**
```
Price: Medium, High, Low
Rating: 3-star, 1-star, 5-star, 2-star
```
**Why:** Utilities will jump around, harder to interpret trends

**For Nominal Attributes (no natural order):**

✅ **GOOD: Alphabetical or Market Share**
```
Brand: Apple, Google, Samsung (alphabetical)
Brand: Samsung, Apple, Google (by market share)
Cuisine: Italian, Japanese, Mexican (alphabetical)
```
**Why:** Consistent, reproducible, no implicit bias

**For Binary Attributes:**

✅ **GOOD: Baseline First**
```
MSG: MSG_Absent, MSG_Present
WiFi: No WiFi, WiFi Enabled
Organic: Conventional, Organic
```
**Why:** Utility represents the effect of adding the feature

### 4.3 Special Case: Price

**Price is special because:**
- It's continuous but treated as categorical
- Always has natural ordering (cheap to expensive OR expensive to cheap)
- Affects interpretation of price sensitivity

**Recommended:**
```
Price: High, Medium, Low
```
**Why:** 
- Baseline = highest price (least desirable)
- Utilities will be positive and increasing
- Interpretation: "Utility gain from reducing price"

**Alternative (also valid):**
```
Price: Low, Medium, High  
```
**Interpretation changes to:** "Utility loss from increasing price" (negative utilities)

**Either works, but be consistent within a study and document your choice!**

## 5. Column Name Mapping

### 5.1 If Your Data Has Different Column Names

**Your Data:**
```csv
RespondentID,TaskNumber,OptionID,Selected,PriceLevel,BrandName,...
```

**Your Settings Sheet:**
| Setting | Value |
|---------|-------|
| respondent_id_column | RespondentID |
| choice_set_column | TaskNumber |
| alternative_id_column | OptionID |
| chosen_column | Selected |

**Your Attributes Sheet:**
| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| PriceLevel | 3 | Low, Medium, High |
| BrandName | 3 | Apple, Samsung, Google |

**Key Rule:** `AttributeName` MUST match your actual data column name

### 5.2 Flexible Naming

**These all work as long as consistent:**

✅ Respondent ID column:
- `resp_id`, `respondent_id`, `RespondentID`, `ID`, `participant_id`

✅ Choice Set ID column:
- `choice_set_id`, `task_id`, `TaskNumber`, `set`, `card_set_id`

✅ Chosen column:
- `chosen`, `selected`, `choice`, `pick`, `Selected`

✅ Alternative ID column:
- `alternative_id`, `alt_id`, `option`, `card_id`, `OptionNumber`

**Just specify in Settings sheet and Turas will use your naming!**

## 6. File Paths (Relative vs. Absolute)

### 6.1 Relative Paths (Recommended)

**Project structure:**
```
my_project/
├── config/
│   └── smartphone_config.xlsx
├── data/
│   └── smartphone_data.csv
└── results/
    └── (output goes here)
```

**In config Settings sheet:**
| Setting | Value |
|---------|-------|
| data_file | ../data/smartphone_data.csv |
| output_file | ../results/smartphone_results.xlsx |

**Paths are relative to config file location**

### 6.2 Absolute Paths

**Windows:**
```
C:/Users/YourName/Documents/Projects/conjoint/data/smartphone_data.csv
```

**Mac/Linux:**
```
/Users/YourName/Documents/Projects/conjoint/data/smartphone_data.csv
```

**In config Settings sheet:**
| Setting | Value |
|---------|-------|
| data_file | C:/Users/YourName/Documents/Projects/conjoint/data/smartphone_data.csv |
| output_file | C:/Users/YourName/Documents/Projects/conjoint/results/smartphone_results.xlsx |

**Note:** Use forward slashes `/` even on Windows (or double backslashes `\\`)

### 6.3 Same Directory as Config (Simplest)

**Project structure:**
```
my_project/
├── smartphone_config.xlsx
├── smartphone_data.csv
└── smartphone_results.xlsx (created)
```

**In config Settings sheet:**
| Setting | Value |
|---------|-------|
| data_file | smartphone_data.csv |
| output_file | smartphone_results.xlsx |

## 7. Quick Start Templates

### 7.1 Minimal Config Template

**Filename:** `minimal_config.xlsx`

**Settings Sheet:**
| Setting | Value |
|---------|-------|
| data_file | my_data.csv |
| output_file | my_results.xlsx |

**Attributes Sheet:**
| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| Attribute1 | 3 | Level1, Level2, Level3 |
| Attribute2 | 2 | LevelA, LevelB |

**That's it!** All other settings use defaults.

### 7.2 Standard Config Template

**Filename:** `standard_config.xlsx`

**Settings Sheet:**
| Setting | Value |
|---------|-------|
| choice_type | single |
| estimation_method | auto |
| baseline_handling | first_level_zero |
| data_file | survey_data.csv |
| output_file | conjoint_results.xlsx |
| respondent_id_column | resp_id |
| choice_set_column | choice_set_id |
| chosen_column | chosen |
| generate_market_simulator | TRUE |

**Attributes Sheet:**
| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| [Your Attribute 1] | [N] | [Level1, Level2, ...] |
| [Your Attribute 2] | [N] | [Level1, Level2, ...] |
| [Your Attribute 3] | [N] | [Level1, Level2, ...] |

### 7.3 Config with None Option Template

**Settings Sheet:**
| Setting | Value |
|---------|-------|
| choice_type | single_with_none |
| data_file | survey_data.csv |
| output_file | conjoint_results.xlsx |
| none_label | None of these options |
| none_as_baseline | FALSE |

**Attributes Sheet:**
- Same as standard (do NOT include "NONE" in level names)

## 8. Common Errors & Solutions

### 8.1 "Attribute levels in data don't match config"

**Error Message:**
```
[DATA] Error: Attribute 'Price' has levels in data not found in config
 → Data has: "$499", "$599", "$699"
 → Config expects: "$499", "$599", "$699 "
 → Note the extra space in config!
```

**Solution:**
1. Check for extra spaces in LevelNames
2. Check capitalization (case-sensitive)
3. Check special characters ($, %, &, etc.)
4. Use exact copy-paste from data to config

### 8.2 "Choice set has multiple chosen alternatives"

**Error Message:**
```
[DATA] Error: Choice set 15 has 2 alternatives marked as chosen
 → Each choice set must have exactly ONE chosen alternative
 → Check rows 145-148 in your data file
```

**Solution:**
1. Check for duplicate `chosen=1` in same choice set
2. Verify Alchemer export didn't have errors
3. Look at the specific rows mentioned

### 8.3 "Config file missing Attributes sheet"

**Error Message:**
```
[CONFIG] Error: Configuration file missing 'Attributes' sheet
 → Required sheets: 'Settings', 'Attributes'
 → Your file has: 'Settings', 'Sheet1'
```

**Solution:**
1. Excel sheet must be named EXACTLY "Attributes" (not "Attribute" or "attributes")
2. Check for hidden sheets
3. Re-create from template

### 8.4 "Number of levels doesn't match LevelNames"

**Error Message:**
```
[CONFIG] Error: Attribute 'Brand': expected 3 levels but found 2
 → NumLevels = 3
 → LevelNames = "Apple, Samsung"
```

**Solution:**
1. Count commas in LevelNames: n commas = n+1 levels
2. Add missing level OR reduce NumLevels
3. Check for missing commas

### 8.5 "AttributeName not found in data"

**Error Message:**
```
[DATA] Error: Attribute 'brand' not found in data columns
 → Config expects: brand
 → Data has: Brand, Price, Storage, Battery
```

**Solution:**
- Attribute names are case-sensitive
- Change config to "Brand" or data to "brand"

## 9. Validation Checklist

Before running analysis, verify:

### Data File:
- [ ] File exists and is readable (.csv, .xlsx, or .sav)
- [ ] Has required columns: resp_id, choice_set_id, chosen, attributes
- [ ] One row per alternative per choice set per respondent
- [ ] Exactly one `chosen=1` per choice set
- [ ] No missing values in required columns
- [ ] Attribute values match config exactly

### Config File:
- [ ] File exists and is readable (.xlsx)
- [ ] Has both "Settings" and "Attributes" sheets (exact names)
- [ ] Settings sheet has "Setting" and "Value" columns
- [ ] Attributes sheet has "AttributeName", "NumLevels", "LevelNames"
- [ ] data_file path is correct
- [ ] output_file path is writeable
- [ ] AttributeName matches data columns exactly
- [ ] LevelNames match data values exactly
- [ ] NumLevels matches number of items in LevelNames

### Logic:
- [ ] At least 2 attributes
- [ ] Each attribute has 2-10 levels
- [ ] At least 50 respondents (100+ recommended)
- [ ] At least 10 observations per level (ideally 20+)
- [ ] Choice sets have 2-6 alternatives (3-4 optimal)

## 10. Testing Your Files

### 10.1 Manual Validation

**Step 1: Load and inspect data**
```r
data <- read.csv("smartphone_data.csv")
head(data)
str(data)

# Check: Exactly one chosen per choice set
library(dplyr)
data %>% 
  group_by(choice_set_id) %>% 
  summarise(n_chosen = sum(chosen)) %>%
  filter(n_chosen != 1)
# Should return 0 rows
```

**Step 2: Load and inspect config**
```r
library(openxlsx)
settings <- read.xlsx("smartphone_config.xlsx", sheet = "Settings")
attributes <- read.xlsx("smartphone_config.xlsx", sheet = "Attributes")

print(settings)
print(attributes)

# Check: Attribute names match
attr_names <- attributes$AttributeName
data_cols <- names(data)
setdiff(attr_names, data_cols)  # Should be empty
```

**Step 3: Check level matching**
```r
# For each attribute, verify levels match
for (attr in attributes$AttributeName) {
  config_levels <- strsplit(attributes$LevelNames[attributes$AttributeName == attr], ", ")[[1]]
  data_levels <- unique(as.character(data[[attr]]))
  
  cat("\nAttribute:", attr, "\n")
  cat("Config levels:", paste(config_levels, collapse=", "), "\n")
  cat("Data levels:", paste(data_levels, collapse=", "), "\n")
  
  missing_in_config <- setdiff(data_levels, config_levels)
  missing_in_data <- setdiff(config_levels, data_levels)
  
  if (length(missing_in_config) > 0) {
    cat("ERROR: Levels in data but not config:", paste(missing_in_config, collapse=", "), "\n")
  }
  if (length(missing_in_data) > 0) {
    cat("WARNING: Levels in config but not data:", paste(missing_in_data, collapse=", "), "\n")
  }
}
```

### 10.2 Using Turas Validation

```r
# Load Turas modules
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/02_validation.R")

# Load and validate config
config <- load_conjoint_config("smartphone_config.xlsx")
# Will error if config invalid

# Load and validate data
data <- load_conjoint_data(config$data_file, config)
# Will error if data invalid

# If both load successfully, you're ready to run analysis!
```

## 11. Example: Converting Your Existing Data

### 11.1 If You Have Wide Format Data

**Your current data (WRONG format):**
```csv
resp_id,choice_set_id,alt1_price,alt1_brand,alt1_chosen,alt2_price,alt2_brand,alt2_chosen,alt3_price,alt3_brand,alt3_chosen
1,1,$699,Apple,0,$599,Samsung,1,$499,Google,0
```

**Convert to long format (CORRECT):**
```csv
resp_id,choice_set_id,alternative_id,Price,Brand,chosen
1,1,1,$699,Apple,0
1,1,2,$599,Samsung,1
1,1,3,$499,Google,0
```

**R code to convert:**
```r
wide_data <- read.csv("wide_format.csv")

# Reshape to long
long_data <- data.frame()

for (i in 1:nrow(wide_data)) {
  n_alts <- 3  # Adjust based on your data
  
  for (j in 1:n_alts) {
    row <- data.frame(
      resp_id = wide_data$resp_id[i],
      choice_set_id = wide_data$choice_set_id[i],
      alternative_id = j,
      Price = wide_data[[paste0("alt", j, "_price")]][i],
      Brand = wide_data[[paste0("alt", j, "_brand")]][i],
      chosen = wide_data[[paste0("alt", j, "_chosen")]][i]
    )
    long_data <- rbind(long_data, row)
  }
}

write.csv(long_data, "long_format.csv", row.names = FALSE)
```

### 11.2 If You Have Alchemer Export

**Good news:** Alchemer CBC exports in long format already!

**Just verify:**
1. One row per alternative
2. Has respondent ID column
3. Has choice set ID column  
4. Has chosen/selected column
5. Has attribute columns

Then create config file matching your column names.

## 12. Summary: File Structure at a Glance

### Data File (CSV):
```
resp_id | choice_set_id | alternative_id | Attr1 | Attr2 | ... | chosen
--------|---------------|----------------|-------|-------|-----|-------
   1    |       1       |       1        | Val1  | Val2  | ... |   0
   1    |       1       |       2        | Val3  | Val4  | ... |   1
   1    |       1       |       3        | Val5  | Val6  | ... |   0
   1    |       2       |       1        | Val7  | Val8  | ... |   1
   ...
```

### Config File (Excel):

**Sheet 1: Settings**
```
Setting                 | Value
------------------------|------------------
choice_type             | single
data_file               | my_data.csv
output_file             | my_results.xlsx
respondent_id_column    | resp_id
choice_set_column       | choice_set_id
chosen_column           | chosen
```

**Sheet 2: Attributes**
```
AttributeName | NumLevels | LevelNames
--------------|-----------|---------------------------
Attr1         | 3         | Level1, Level2, Level3
Attr2         | 2         | LevelA, LevelB
```

### Run Analysis:
```r
results <- run_conjoint_analysis(
  config_file = "my_config.xlsx"
)
```

Output created at path specified in config!

---

## Appendices

### A. Complete Field Reference

See sections 2.2 (Settings fields) and 2.4 (Attributes fields) for complete field documentation.

### B. Blank Templates

**Download links will be added when module is implemented**
- `blank_config_template.xlsx`
- `sample_data_template.csv`

### C. Real-World Examples

**From your actual studies:**
- DE_noodle example (Section 3.3)
- Restaurant with none (Section 3.2)
- Smartphone study (Section 3.1)

### D. Troubleshooting Guide

See Section 8 for common errors and solutions.

---

**Next Step:** Use these templates to create your config file and format your data, then proceed with analysis using the Turas module!

**See Part 1-4 for full technical specifications, testing requirements, and output details.**
