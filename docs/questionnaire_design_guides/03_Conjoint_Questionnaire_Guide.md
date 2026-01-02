# Conjoint Analysis: Questionnaire Design Guide

**Purpose:** Design choice-based conjoint studies that produce reliable utility estimates

---

## What Conjoint Analysis Needs

Conjoint reveals how people value product features and make trade-off decisions. It requires:

1. **Choice tasks** - Respondents choose between product profiles
2. **Systematic attribute variation** - Features change across options
3. **Realistic combinations** - Profiles must be believable
4. **Sufficient choices** - Typically 8-15 tasks per person
5. **Adequate sample** - 200+ respondents for stable estimates

---

## The Golden Rules

### Rule #1: Choose 3-6 Attributes

**Sweet Spot: 4-5 Attributes**

**Too Few (< 3):**
- Limited insight
- Missing key trade-offs
- Could use simpler method

**Just Right (4-5):**
```
Example: Smartphone
1. Brand (Apple, Samsung, Google)
2. Screen Size (5.5", 6.1", 6.7")
3. Battery Life (1 day, 2 days, 3 days)
4. Camera Quality (Standard, Premium, Pro)
5. Price ($599, $799, $999, $1,199)
```

**Too Many (> 6):**
- Respondent cognitive overload
- Too many combinations to show
- Unstable estimates
- Consider running 2 studies

**Why 4-5 is Optimal:**
- Manageable for respondents
- Enough trade-offs to be interesting
- Statistical efficiency
- Covers key decision factors

---

### Rule #2: Each Attribute Needs 2-4 Levels

**Levels = The Options Within Each Attribute**

**Examples:**

**Brand (3 levels):**
- Apple
- Samsung
- Google

**Battery Life (3 levels):**
- 1 day
- 2 days
- 3 days

**Price (4 levels):**
- $599
- $799
- $999
- $1,199

**Guidelines:**

**Minimum: 2 levels**
- Binary attribute (Yes/No, Has it/Doesn't have it)
- Example: "5G Capable: Yes / No"

**Ideal: 3-4 levels**
- Shows non-linear preferences
- More realistic variation
- Better statistical power

**Maximum: 5 levels**
- More gets confusing
- Especially problematic for price (4 price points max)

**Warning on Price:**
- 3-4 price points recommended
- Cover realistic range
- Not too narrow (doesn't show trade-offs)
- Not too wide (unrealistic extremes)

---

### Rule #3: Levels Must Be Realistic & Feasible

**Bad Example - Unrealistic Combinations:**
```
Budget Brand + Premium Features + High Price
→ Respondents won't believe this exists
```

**Bad Example - Impossible Combinations:**
```
Economy Airline:
- First Class Seat (Premium Level)
- No Food Service (Economy Level)
- Lowest Price
→ Doesn't make sense
```

**Solution: Prohibited Combinations**
Design system should prevent impossible pairings:
- Don't show Budget Brand with Premium-only features
- Don't pair Economy Service with Luxury Pricing
- Use restrictions in design software

---

### Rule #4: Include Price as an Attribute

**Price Should Always Be Included (Almost Always)**

**Why:**
- Measures willingness-to-pay
- Enables revenue optimization
- Shows price sensitivity
- Allows cost-benefit trade-offs

**How to Set Price Levels:**

**Method 1: Current + Variations**
```
Current price: $799

Price Levels:
- $699 (-13%)
- $799 (current)
- $899 (+13%)
- $999 (+25%)
```

**Method 2: Competitive Range**
```
Competitive landscape:
- Competitor A: $650
- Competitor B: $850
- Competitor C: $1,100

Your Price Levels:
- $599 (undercut lowest)
- $799 (mid-range)
- $999 (premium)
- $1,199 (super-premium)
```

**Method 3: Cost-Based**
```
Cost to produce: $400

Price Levels:
- $599 (50% margin)
- $799 (100% margin)
- $999 (150% margin)
```

**Spacing:** Increments of 10-30% between levels works well

---

## Designing Choice Tasks

### Task Structure

**Standard Format:**
```
Which of these options would you choose?

OPTION A              OPTION B              OPTION C
Brand: Apple          Brand: Samsung        Brand: Google
Screen: 6.1"          Screen: 6.7"          Screen: 5.5"
Battery: 2 days       Battery: 1 day        Battery: 3 days
Camera: Premium       Camera: Pro           Camera: Standard
Price: $999           Price: $799           Price: $599

○ Choose A            ○ Choose B            ○ Choose C
```

**With "None" Option:**
```
OPTION A              OPTION B              ○ None of these
Brand: Apple          Brand: Samsung
Screen: 6.1"          Screen: 6.7"
Battery: 2 days       Battery: 1 day
Camera: Premium       Camera: Pro
Price: $999           Price: $799
```

**Key Elements:**
- 2-3 options per task (3 is most common)
- Attributes clearly labeled
- Values easy to compare
- "None" option (recommended for realistic market share)

---

### How Many Choice Tasks?

**Recommended: 10-15 tasks per respondent**

**Too Few (< 8 tasks):**
- Insufficient data per person
- Unstable individual estimates
- Missing important trade-offs

**Sweet Spot (10-15 tasks):**
- Good statistical coverage
- Not too fatiguing
- Reliable estimates

**Too Many (> 20 tasks):**
- Respondent fatigue
- Random clicking
- Data quality degrades

**Rule of Thumb:**
- Simple designs (3-4 attributes): 10 tasks
- Complex designs (5-6 attributes): 12-15 tasks

---

### Experimental Design

**DON'T Create Tasks Manually**

Use specialized software to generate tasks:
- Sawtooth Software (industry standard)
- R packages (`support.CEs`, `AlgDesign`)
- Excel-based generators (for simple designs)

**Why:**
- Ensures orthogonality (attributes vary independently)
- Balances attribute levels
- Prevents confounding
- Optimal statistical efficiency

**Key Design Principles:**

**Orthogonality:**
- Each attribute varies independently
- No systematic correlation between attributes
- Example: Brand shouldn't always be paired with high price

**Level Balance:**
- Each level appears roughly equal number of times
- Premium camera shown as often as Standard camera

**Randomization:**
- Different respondents see different task orders
- Prevents order effects
- Each person gets different randomly generated profiles

---

## Common Design Pitfalls

### Pitfall #1: Too Many Attributes

**Problem:**
```
Attributes:
1. Brand
2. Model
3. Screen size
4. Processor
5. RAM
6. Storage
7. Battery
8. Camera megapixels
9. Camera features
10. Price
```
→ 10 attributes = Cognitive overload!

**Solution:**
```
Core Attributes (5):
1. Brand
2. Screen size
3. Performance tier (combines processor + RAM + storage)
4. Camera quality (combines megapixels + features)
5. Price
```

**OR Run Two Studies:**
- Study 1: Brand, Size, Performance, Price
- Study 2: Camera, Battery, Build Quality, Price

---

### Pitfall #2: Too Many Levels

**Problem:**
```
Price Attribute:
- $499
- $599
- $699
- $799
- $899
- $999
- $1,099
- $1,199
```
→ 8 price levels = Too many!

**Solution:**
```
Price Attribute (4 levels):
- $599
- $799
- $999
- $1,199
```
→ Covers range, manageable for respondents

---

### Pitfall #3: Unrealistic Attribute Ranges

**Bad - Too Narrow:**
```
Price: $795, $799, $805
```
→ Differences too small to matter

**Bad - Too Wide:**
```
Price: $100, $500, $2,000, $5,000
```
→ Unrealistic range for same product type

**Good:**
```
Price: $699, $899, $1,099
```
→ Meaningful differences, realistic range

---

### Pitfall #4: Confusing Attribute Descriptions

**Bad:**
```
Performance: Level 1, Level 2, Level 3
```
→ What does "Level 2" mean?

**Good:**
```
Performance:
- Standard (suitable for email, web browsing)
- Enhanced (handles multitasking, light gaming)
- Premium (professional apps, heavy gaming)
```
→ Clear, concrete descriptions

**Bad:**
```
Battery: 3000mAh, 4000mAh, 5000mAh
```
→ Most people don't know what mAh means

**Good:**
```
Battery Life:
- 1 day of typical use
- 2 days of typical use
- 3 days of typical use
```
→ Meaningful to consumers

---

## Writing Clear Attribute Descriptions

### Use Consumer-Relevant Language

**Technical Jargon:**
```
❌ Processor: Snapdragon 888, A15 Bionic, Exynos 2100
❌ Display: AMOLED 120Hz, LCD 90Hz, OLED 60Hz
❌ RAM: 6GB, 8GB, 12GB
```

**Consumer-Friendly:**
```
✅ Performance: Standard, Enhanced, Pro
✅ Screen Quality: Good, Better, Best
✅ Multitasking Ability: Basic (6GB), Advanced (8GB), Pro (12GB)
```

**Include Context:**
```
Better:
Battery Life:
- 1 day (charge nightly)
- 2 days (charge every other day)
- 3 days (charge twice weekly)
```

---

### Keep Attribute Names Consistent

**Good - Consistent:**
```
Task 1:
Brand: Apple
Price: $999

Task 2:
Brand: Samsung
Price: $799
```

**Bad - Inconsistent:**
```
Task 1:
Manufacturer: Apple
Cost: $999

Task 2:
Brand: Samsung
Price: $799
```
→ Same attribute should have same label every time

---

## Sample Size Requirements

**Minimum: 200 respondents**
- For reliable aggregate estimates
- Market simulations reasonably stable

**Recommended: 300-500 respondents**
- Stable individual (HB) estimates
- Segment analysis feasible
- Robust market share predictions

**For Segmentation: 500+ respondents**
- Split into meaningful segments
- Each segment has stable estimates

**Rule of Thumb:**
- Need 200+ for basic analysis
- Add 100 per major segment you want to analyze separately

---

## Question Flow & Survey Structure

### Recommended Structure:

**PART 1: Introduction & Screening**
```
- Study purpose
- Time estimate (usually 15-20 minutes)
- Screening questions (category usage, etc.)
```

**PART 2: Category Context**
```
- Recent purchase/usage questions
- Familiarity with brands/features
- Current product owned
```

**PART 3: Conjoint Instructions**
```
Clear explanation:
"You will see several sets of product options.
For each set, choose the option you would most likely purchase.
Each set will show different features and prices.
Please consider each set carefully and select your preference."
```

**PART 4: Practice Task (Optional but Recommended)**
```
Show 1-2 practice tasks with feedback:
"This helps you get familiar with the format.
In the actual study, you'll see 12 sets like this."
```

**PART 5: Conjoint Tasks**
```
Task 1 of 12: [Choice set]
Task 2 of 12: [Choice set]
...
Task 12 of 12: [Choice set]

Tips:
- Show progress bar
- Allow breaks every 4-5 tasks (optional)
- Randomize task order
```

**PART 6: Follow-Up Questions**
```
- Difficulty rating ("How easy was this?")
- Attribute importance (holistic check)
- Open-ended feedback
```

**PART 7: Demographics**
```
- Age, gender, income
- Usage frequency
- Other segmentation variables
```

---

## Mobile-Friendliness

**Critical for Conjoint:**
- 60-70% of respondents may use mobile
- Choice tasks must be readable on phones
- Test on actual mobile devices

**Mobile Design Tips:**

**✅ Stack Options Vertically:**
```
OPTION A
Brand: Apple
Screen: 6.1"
Battery: 2 days
Camera: Premium
Price: $999
○ Choose Option A

───────────────

OPTION B
Brand: Samsung
Screen: 6.7"
Battery: 1 day
Camera: Pro
Price: $799
○ Choose Option B
```

**❌ Don't Use Side-by-Side Tables:**
→ Too small on mobile, requires zooming/scrolling

**Use Clear Buttons:**
```
[   Select Option A   ]
[   Select Option B   ]
[   None of these    ]
```

**Test Readability:**
- Font size minimum 14-16pt
- Adequate spacing
- Touch-friendly buttons

---

## Quality Checks & Validation

### Include Attention Checks

**Method 1: Dominant Option**
Insert 1-2 tasks where one option is clearly superior:
```
OPTION A               OPTION B
Brand: Premium         Brand: Budget
Features: All Premium  Features: All Basic
Price: $599           Price: $1,199

→ Anyone paying attention chooses A
```

**Method 2: Instructed Response**
```
"For quality control, please select Option B for this question."
```

**Use Sparingly:** 1-2 per survey, don't overuse

---

### Monitor Data Quality

**Red Flags:**
- **Straight-lining:** Always picking first option
- **Random clicking:** No logical pattern
- **Too fast:** Completing in < 50% of median time
- **Never selects "None":** If None option included

**Quality Filters:**
- Remove respondents who fail attention checks
- Flag impossibly fast completion
- Check for variance in responses

---

## Real-World Example: Hotel Conjoint

**Business Question:**
"What hotel features drive bookings? How much will customers pay for premium amenities?"

**Attributes (5):**

1. **Hotel Brand (3 levels):**
   - Budget Chain (e.g., Holiday Inn Express)
   - Mid-Scale Chain (e.g., Hilton Garden Inn)
   - Upscale Chain (e.g., Marriott)

2. **Room Type (3 levels):**
   - Standard Room
   - Large Room with Sitting Area
   - Suite

3. **Breakfast Included (2 levels):**
   - No Breakfast
   - Free Hot Breakfast

4. **Wi-Fi Speed (3 levels):**
   - Standard (web browsing)
   - Fast (streaming HD video)
   - Ultra-Fast (multiple devices, 4K streaming)

5. **Price Per Night (4 levels):**
   - $89
   - $119
   - $149
   - $189

**Choice Task Example:**
```
Task 5 of 12: Which hotel would you book for a business trip?

OPTION A                          OPTION B
Brand: Hilton Garden Inn          Brand: Holiday Inn Express
Room: Standard Room               Room: Suite
Breakfast: Free Hot Breakfast     Breakfast: No Breakfast
Wi-Fi: Fast (HD streaming)        Wi-Fi: Standard
Price: $149/night                 Price: $89/night

○ Book Option A     ○ Book Option B     ○ Would not book either
```

**Survey Flow:**
1. Screening (Traveled for business in past year?)
2. Current hotel preferences
3. Conjoint instructions
4. 12 choice tasks
5. Follow-up questions
6. Demographics

**Sample:** 400 business travelers

**Analysis Delivers:**
- Utility values for each feature level
- Willingness-to-pay for breakfast, Wi-Fi upgrades, room size
- Optimal configuration for different price points
- Market share simulation vs. competitors

---

## Quick Reference Checklist

**Design Specifications:**
- ✓ 3-6 attributes (ideally 4-5)
- ✓ 2-4 levels per attribute
- ✓ Price included as attribute
- ✓ Consumer-friendly descriptions
- ✓ Realistic attribute combinations

**Task Design:**
- ✓ 10-15 tasks per respondent
- ✓ 2-3 options per task
- ✓ Include "None" option (recommended)
- ✓ Orthogonal experimental design
- ✓ Randomized task order

**Sample & Quality:**
- ✓ Minimum 200 respondents
- ✓ Mobile-optimized design
- ✓ 1-2 attention checks included
- ✓ Progress bar shown
- ✓ Quality monitoring in place

**Survey Flow:**
- ✓ Clear instructions included
- ✓ Optional practice task
- ✓ 15-20 minute completion time
- ✓ Follow-up questions included

---

## Bottom Line

Conjoint is powerful but requires careful design:

**Critical Success Factors:**
1. **Limit to 4-5 attributes** - More creates overload
2. **3-4 levels per attribute** - Sweet spot for analysis
3. **Use experimental design software** - Don't create tasks manually
4. **Include price** - Enables willingness-to-pay estimates
5. **Test on mobile** - Most respondents use phones
6. **200+ sample minimum** - For stable estimates

Get the design right and conjoint delivers unmatched insight into customer preferences and optimal product configurations.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*
