Excel Configuration Template
============================

The MaxDiff configuration template (maxdiff_config_template.xlsx) can be generated using:

    cd modules/maxdiff
    Rscript templates/create_maxdiff_template.R

This will create the template at: templates/maxdiff_config_template.xlsx

The template includes:
- INSTRUCTIONS sheet with workflow guidance
- PROJECT_SETTINGS sheet with examples
- ITEMS sheet with sample items
- DESIGN_SETTINGS sheet with recommendations
- SURVEY_MAPPING sheet with mapping examples
- SEGMENT_SETTINGS sheet with segment examples
- OUTPUT_SETTINGS sheet with output options

All sheets include:
- Color coding (yellow = required, green = optional, blue = examples)
- In-sheet documentation
- Example values

The authoritative source for template information is the R script:
    modules/maxdiff/templates/create_maxdiff_template.R

For detailed template usage, see:
    modules/maxdiff/docs/USER_MANUAL.md (Section 8: Configuration Template Reference)
