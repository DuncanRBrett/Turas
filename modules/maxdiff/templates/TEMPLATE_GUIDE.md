# MaxDiff Configuration Template Guide

## Quick Start

Run this command in R to generate the Excel template:

```r
setwd("path/to/Turas/modules/maxdiff")
source("templates/create_maxdiff_template.R")
```

This creates `templates/maxdiff_config_template.xlsx` with all sheets and instructions.

---

## Sheet Descriptions

### 1. PROJECT_SETTINGS (Required)

Core project configuration. Use Setting_Name and Value columns.

| Setting_Name | Required | Description | Options/Examples |
|--------------|----------|-------------|------------------|
| **Project_Name** | YES | Unique project name (no spaces) | `Brand_Study_2024` |
| **Mode** | YES | DESIGN or ANALYSIS | `DESIGN` = generate design, `ANALYSIS` = analyze results |
| Raw_Data_File | ANALYSIS | Path to survey data file | `data/survey.xlsx`, `C:/Data/results.csv` |
| Design_File | ANALYSIS | Path to design file | `output/design.xlsx` |
| Output_Folder | NO | Output folder path | `output` (default) |
| Data_File_Sheet | NO | Sheet name/number in data file | `1` (first sheet), `Data` |
| Respondent_ID_Variable | NO | Column with respondent IDs | `RespID` (default) |
| Weight_Variable | NO | Column for weighting | Leave blank for unweighted |
| Filter_Expression | NO | R filter expression | `Region == 'North'`, `Age >= 18` |
| Seed | NO | Random seed | `12345` (default) |

---

### 2. ITEMS (Required)

List of items/attributes to evaluate.

| Column | Required | Description |
|--------|----------|-------------|
| **Item_ID** | YES | Unique identifier (e.g., `ITEM_01`) - keep consistent between design and analysis! |
| **Item_Label** | YES | Text shown to respondents |
| Item_Group | NO | Optional grouping for reporting |
| Include | NO | `1` = include, `0` = exclude (default: 1) |
| Anchor_Item | NO | `1` = use as reference item (max 1) |
| Display_Order | NO | Order in output tables |
| Notes | NO | Comments |

**Example:**
```
Item_ID     | Item_Label                  | Item_Group | Include
------------|-----------------------------|-----------|---------
ITEM_01     | High quality materials      | Quality   | 1
ITEM_02     | Affordable price            | Price     | 1
ITEM_03     | Fast delivery               | Service   | 1
...
```

---

### 3. DESIGN_SETTINGS (Required for DESIGN mode)

Parameters for generating experimental designs.

| Parameter_Name | Default | Description | Recommendations |
|----------------|---------|-------------|-----------------|
| **Items_Per_Task** | 4 | Items shown per task | 4 for general, 5 for experienced respondents |
| **Tasks_Per_Respondent** | 12 | Tasks per respondent | 10-15 typical; more = better precision |
| Num_Versions | 1 | Design versions | 1 for small, 3-5 for large samples |
| Design_Type | BALANCED | Algorithm type | `BALANCED` (recommended), `RANDOM`, `OPTIMAL` |
| Allow_Item_Repeat_Per_Respondent | YES | Allow item repeats | YES recommended |
| Max_Item_Repeats | 3 | Max repeats per item | 2-4 typical |
| Force_Min_Pair_Balance | YES | Balance pair frequencies | YES recommended |
| Randomise_Task_Order | YES | Randomize task order | YES recommended |
| Randomise_Item_Order_Within_Task | YES | Randomize positions | YES recommended |
| Design_Efficiency_Threshold | 0.90 | Minimum D-efficiency | 0.90+ is good |

**Design Guidelines:**
- 15-25 items typical
- 4-5 items per task standard
- 10-15 tasks per respondent
- Minimum 200 respondents recommended

---

### 4. SURVEY_MAPPING (Required for ANALYSIS mode)

Maps survey column names to MaxDiff data structure.

| Mapping_Type | Description | Example |
|--------------|-------------|---------|
| **Version_Variable** | Column with design version number | `Version`, `DesignVersion` |
| **Best_Column_Pattern** | Pattern for Best columns, use `{task}` placeholder | `MaxDiff_T{task}_Best` |
| **Worst_Column_Pattern** | Pattern for Worst columns | `MaxDiff_T{task}_Worst` |
| Task_Number_Pattern | How task number appears | `{task}` |
| **Best_Value_Type** | What's stored in Best columns | `ITEM_POSITION` (1-5) or `ITEM_ID` |
| **Worst_Value_Type** | What's stored in Worst columns | `ITEM_POSITION` (1-5) or `ITEM_ID` |

**Column Pattern Example:**
If your survey has: `MD_T1_Best`, `MD_T1_Worst`, `MD_T2_Best`, `MD_T2_Worst`, ...
- Set `Best_Column_Pattern = MD_T{task}_Best`
- Set `Worst_Column_Pattern = MD_T{task}_Worst`

**Value Types:**
- `ITEM_POSITION`: Values are 1, 2, 3, 4, 5 (position in task)
- `ITEM_ID`: Values are actual IDs like `ITEM_01`, `ITEM_02`

---

### 5. SEGMENT_SETTINGS (Optional)

Define subgroups for segment analysis.

| Column | Required | Description |
|--------|----------|-------------|
| **Segment_ID** | YES | Grouping variable name (e.g., `Gender`) |
| **Segment_Name** | YES | Display name for level (e.g., `Male`) |
| **Variable_Name** | YES | Column name in data file |
| **Variable_Value** | YES | Value to match |
| Include | NO | `1` = include, `0` = skip |
| Display_Order | NO | Order within group |

**Example:**
```
Segment_ID | Segment_Name | Variable_Name | Variable_Value
-----------|--------------|---------------|----------------
Gender     | Male         | Gender        | 1
Gender     | Female       | Gender        | 2
Age_Group  | 18-34        | Age_Cat       | 1
Age_Group  | 35-54        | Age_Cat       | 2
Age_Group  | 55+          | Age_Cat       | 3
```

---

### 6. OUTPUT_SETTINGS (Optional)

Control what outputs are generated. All have sensible defaults.

| Setting_Name | Default | Description |
|--------------|---------|-------------|
| Generate_Design_File | YES | Create design file (DESIGN mode) |
| Generate_Count_Scores | YES | Best%, Worst%, Net scores |
| Generate_Aggregate_Logit | YES | Multinomial logit model |
| Generate_HB_Model | NO | Hierarchical Bayes (requires cmdstanr) |
| Generate_Segment_Tables | YES | Per-segment score tables |
| Generate_Charts | YES | Visualization charts |
| Utility_Scale | 0_100 | `RAW`, `0_100`, or `PROBABILITY` |
| Chart_Format | PNG | `PNG`, `PDF`, or `SVG` |

---

## Typical Workflow

### Design Mode
1. Set `Mode = DESIGN` in PROJECT_SETTINGS
2. Fill in ITEMS sheet with your items
3. Configure DESIGN_SETTINGS
4. Run MaxDiff → generates design file

### Analysis Mode
1. Set `Mode = ANALYSIS` in PROJECT_SETTINGS
2. Specify `Raw_Data_File` and `Design_File` paths
3. Use same ITEMS as design phase
4. Fill in SURVEY_MAPPING
5. Optionally add SEGMENT_SETTINGS
6. Run MaxDiff → generates output Excel with scores and charts

---

## Color Coding in Template

- **Yellow**: Required setting - must be filled in
- **Green**: Optional setting - has sensible default
- **Blue**: Example data - replace with your own

---

## Best Practices

1. **Keep Item_IDs consistent** between design and analysis phases
2. **Test your design** before fielding - check balance and efficiency
3. **Use at least 200 respondents** for stable estimates
4. **Balance survey length** - 12-15 tasks is typical
5. **Randomize** task and item order to reduce bias
