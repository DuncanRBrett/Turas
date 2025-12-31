# MaxDiff: Questionnaire Design Guide

**Purpose:** Design Maximum Difference Scaling studies for clean preference/importance rankings

---

## What MaxDiff Analysis Needs

MaxDiff reveals preference rankings by asking "most" and "least" questions across sets of items. It requires:

1. **10-30 items to rank** - Features, messages, attributes, benefits
2. **Best/Worst choices** - For each set shown
3. **Multiple tasks** - Show different item combinations
4. **All items rated on same dimension** - All must be comparable

---

## The Golden Rules

### Rule #1: Choose 10-30 Items

**Too Few (< 8 items):**
- Just use simple ranking instead
- MaxDiff is overkill
- No advantage over "rank top 5"

**Sweet Spot (12-20 items):**
```
Example: Product Feature Prioritization

1. Long battery life
2. Fast charging
3. Water resistance
4. 5G connectivity
5. Premium camera
6. Large screen
7. Lightweight design
8. Face recognition
9. Expandable storage
10. Wireless charging
11. Dual SIM capability
12. High refresh rate display
13. Stereo speakers
14. Headphone jack
15. Fingerprint sensor
```

**Too Many (> 30 items):**
- Survey too long
- Respondent fatigue
- Diminishing returns
- Consider splitting into 2 studies

**Why This Range:**
- Enough items to make ranking worthwhile
- Not so many that respondents get fatigued
- Optimal statistical efficiency

---

### Rule #2: All Items Must Be Comparable

**What "Comparable" Means:**
All items rated on the same underlying dimension:
- All are **features** (not mixing features with brands)
- All are **benefits** (not mixing benefits with prices)
- All are **attributes** (not mixing attributes with behaviors)

**Good - All Comparable (Features):**
```
Which feature is MOST important? Which is LEAST important?

☐ Water resistance
☐ Fast charging
☐ 5G connectivity
☐ Premium camera

All are product features → Comparable
```

**Bad - Mixed Types:**
```
Which is MOST important? Which is LEAST important?

☐ Water resistance (feature)
☐ Apple brand (brand) ❌
☐ $999 price (price) ❌
☐ I use it daily (behavior) ❌

Mixed types → Not comparable
```

**Think of it as:** You're ranking apples to apples, not apples to oranges to price tags.

---

### Rule #3: Items Must Be Specific & Distinct

**Good - Specific & Distinct:**
```
☐ Battery lasts 2+ days between charges
☐ Charges to 50% in 15 minutes
☐ Survives water submersion up to 2 meters
☐ Takes professional-quality photos in low light
```

**Bad - Vague & Overlapping:**
```
☐ Good battery ❌ (vague)
☐ Long-lasting battery ❌ (overlaps with "good battery")
☐ Great features ❌ (not specific)
☐ High quality ❌ (not specific)
```

**Test:** Can respondents clearly tell items apart? If two items seem the same, combine or drop one.

---

### Rule #4: Neutral, Unbiased Wording

**Good - Neutral:**
```
☐ Organic ingredients
☐ Locally sourced
☐ Fair trade certified
☐ Recyclable packaging
```

**Bad - Biased:**
```
☐ Our premium organic ingredients ❌
☐ Award-winning local sourcing ❌
☐ Ethical fair trade practices ❌ (implies others are unethical)
☐ Eco-friendly recyclable packaging ❌ (already signals "good")
```

**Why:** Biased wording inflates that item's preference scores artificially.

---

## Designing MaxDiff Tasks

### Task Structure

**Standard MaxDiff Task:**
```
Of these 4 features, which is MOST important to you?
Which is LEAST important to you?

                              MOST    LEAST
Long battery life              ○       ○
Water resistance               ○       ○
Fast charging                  ○       ○
5G connectivity                ○       ○
```

**Key Elements:**
- Show 4-5 items per task (4 is most common)
- Ask for "Most" and "Least"
- Radio buttons (can only select one for each)
- Clear labels

**Alternative Wording:**
- "Most important / Least important"
- "Most appealing / Least appealing"
- "Most preferred / Least preferred"
- "Best describes / Worst describes"

Pick one pair and use consistently throughout!

---

### How Many Items Per Task?

**Most Common: 4 items per task**

**3 items per task:**
- Easier for respondents
- Need more tasks to cover all items
- Less statistically efficient

**4 items per task (Recommended):**
- Optimal balance
- Good statistical coverage
- Not overwhelming

**5 items per task:**
- More efficient
- Can be overwhelming
- Risk of random clicking

**6+ items:**
- Too many
- Cognitive overload
- Data quality suffers

**Rule of Thumb:** Stick with 4 items per task.

---

### How Many Tasks Per Respondent?

**Formula:** Depends on number of items

| Total Items | Items Per Task | Recommended Tasks |
|------------|---------------|------------------|
| 10-15 | 4 | 8-10 tasks |
| 15-20 | 4 | 10-12 tasks |
| 20-25 | 4 | 12-15 tasks |
| 25-30 | 4 | 15-18 tasks |

**Why More Items = More Tasks:**
- Need to show each item multiple times
- Ensure all pairs of items are compared
- Statistical coverage

**Balance:**
- Too few tasks = unreliable estimates
- Too many tasks = respondent fatigue

**Optimal:** Each item appears 3-4 times across all tasks

---

### Experimental Design

**DON'T Create Tasks Manually**

Use design software to generate balanced tasks:
- Sawtooth Software (MaxDiff module)
- R packages (`support.CEs`, `choiceDes`)
- Online MaxDiff generators

**Why:**
- **Balance:** Each item appears equal times
- **Orthogonality:** Items don't always appear together
- **Efficiency:** Optimal statistical coverage
- **Randomization:** Different respondents see different tasks

**What Good Design Ensures:**
- Item 1 appears in roughly same number of tasks as Item 2
- Item 1 appears with Item 2 about same frequency as with Item 3
- No systematic patterns that bias results

---

## Common Design Pitfalls

### Pitfall #1: Items Aren't Truly Comparable

**Problem:**
```
MaxDiff set mixing different dimensions:

☐ Free shipping (benefit)
☐ Amazon brand (brand)
☐ $29.99 price (price)
☐ Delivered in 2 days (service level)

→ Comparing apples to oranges
```

**Solution:**
```
Option 1 - Features Only:
☐ Free shipping
☐ 2-day delivery
☐ Easy returns
☐ Package tracking

Option 2 - Brands Only:
☐ Amazon
☐ Walmart
☐ Target
☐ Costco
```

Pick ONE dimension and stick with it!

---

### Pitfall #2: Too Many Items

**Problem:**
```
45 items to rank
→ Requires 18-20 tasks
→ 20+ minutes
→ Respondent fatigue, random clicking
```

**Solutions:**

**Option 1: Cut Items**
- Ruthlessly prioritize
- Drop less important items
- Aim for 15-20 items max

**Option 2: Split Into Multiple Studies**
```
Study 1: Core Features (15 items)
Study 2: Advanced Features (15 items)
```

**Option 3: Use Different Method**
- Consider rating scale instead
- Or simple ranking (top 5)

---

### Pitfall #3: Items Too Similar

**Problem:**
```
☐ Long battery life
☐ Extended battery duration
☐ Battery lasts all day

→ All basically the same thing!
```

**Solution:**
```
Pick one battery item:
☐ Long battery life (2+ days)

Then use different features:
☐ Fast charging (50% in 15 min)
☐ Water resistance
☐ Premium camera
```

**Test:** If you can't clearly explain why two items are different, merge or drop one.

---

### Pitfall #4: Vague Item Descriptions

**Bad - Too Vague:**
```
☐ Quality
☐ Value
☐ Performance
☐ Service
```
→ Too abstract, respondents interpret differently

**Good - Specific:**
```
☐ Product lasts 5+ years without issues
☐ Price 20% below competitors for similar quality
☐ Runs professional software smoothly
☐ Customer support responds within 24 hours
```
→ Concrete, measurable, clear

---

## Writing Clear MaxDiff Items

### ✅ DO: Use Parallel Structure

**Good - Consistent Format:**
```
All items start with verb:

☐ Saves time on daily tasks
☐ Reduces monthly costs
☐ Increases productivity
☐ Simplifies complex processes
```

**Bad - Inconsistent:**
```
☐ Saves time
☐ Cost reduction ❌ (noun phrase)
☐ You become more productive ❌ (different structure)
☐ Makes complex processes simpler ❌ (different verb form)
```

**Why:** Parallel structure is easier to scan and compare.

---

### ✅ DO: Keep Items Similar Length

**Good - Similar Length:**
```
☐ Free shipping on all orders
☐ 30-day money-back guarantee
☐ 24/7 customer support line
☐ Exclusive member discounts
```

**Bad - Varying Length:**
```
☐ Free shipping
☐ If you're not satisfied, return it within 30 days for a full refund ❌
☐ Support
☐ Discounts for members ❌
```

**Why:** Very long items stand out visually, creating bias.

**Rule of Thumb:** Keep items to 5-10 words each.

---

### ✅ DO: Avoid Negatives

**Bad - Uses Negatives:**
```
☐ No hidden fees ❌
☐ No long-term contracts ❌
☐ Won't share your data ❌
```

**Good - Positive Framing:**
```
☐ Transparent pricing, all fees shown upfront
☐ Cancel anytime, no commitments
☐ Your data remains private
```

**Why:** Negatives are harder to process cognitively.

---

### ❌ DON'T: Use Technical Jargon

**Bad - Technical:**
```
☐ 802.11ax Wi-Fi protocol
☐ Snapdragon 888 processor
☐ 120Hz AMOLED display
☐ USB-C Power Delivery 3.0
```

**Good - Consumer Language:**
```
☐ Fastest Wi-Fi standard (Wi-Fi 6)
☐ High-performance processor
☐ Super-smooth 120Hz display
☐ Fast charging via USB-C
```

**Exception:** B2B studies where audience knows the jargon.

---

## Question Flow & Survey Structure

### Recommended Structure:

**PART 1: Introduction**
```
- Study purpose
- Time estimate (typically 10-12 minutes)
- Anonymity/confidentiality
```

**PART 2: Context Questions (Optional)**
```
- Category usage
- Current product owned
- Recent purchase behavior
```

**PART 3: MaxDiff Instructions**
```
Clear explanation:

"In the next section, you'll see sets of product features.

For each set:
- Select the feature that is MOST important to you
- Select the feature that is LEAST important to you

There are 12 sets total. Please consider each set carefully."
```

**PART 4: Practice Task (Recommended)**
```
Show 1 practice task with feedback:

"Here's an example to help you understand the format:

Of these 4 features, which is MOST important? Which is LEAST important?

[Show practice task]

Good! In the actual study, you'll see 12 sets like this."
```

**PART 5: MaxDiff Tasks**
```
Set 1 of 12: [MaxDiff task]
Set 2 of 12: [MaxDiff task]
...
Set 12 of 12: [MaxDiff task]

Show progress bar!
```

**PART 6: Follow-Up (Optional)**
```
- "How difficult was this task?" (1-5)
- Any items confusing?
- Open-ended feedback
```

**PART 7: Demographics**
```
- Standard demographic questions
- Segmentation variables
```

---

## Sample Size Requirements

**Minimum: 150 respondents**
- For aggregate preference scores
- Basic importance rankings

**Recommended: 300 respondents**
- Stable aggregate estimates
- Allows basic segmentation
- Reliable rankings

**For Hierarchical Bayes (Individual Scores): 200+ respondents**
- Individual-level preferences
- Advanced segmentation
- Person-level utilities

**Rule of Thumb:**
- Aggregate only: 150+
- HB individual scores: 200+
- Robust segmentation: 300+

---

## Mobile Optimization

**Critical Considerations:**

**✅ DO: Use Vertical Layout**
```
Of these features, which is MOST important?
Which is LEAST important?

                         MOST   LEAST
Long battery life         ○      ○
─────────────────────────────────────
Water resistance          ○      ○
─────────────────────────────────────
Fast charging             ○      ○
─────────────────────────────────────
5G connectivity           ○      ○
```

**✅ DO: Make Buttons Touch-Friendly**
- Minimum 44x44 pixels
- Adequate spacing between rows
- Clear visual separation

**✅ DO: Test on Actual Phones**
- iPhone and Android
- Various screen sizes
- Readable without zooming

**❌ DON'T: Use Tiny Radio Buttons**
- Hard to tap accurately
- Leads to errors
- Frustrates respondents

---

## Quality Checks

### Include 1-2 Dominant Sets

**Dominant Set:**
One item is obviously best, another obviously worst

```
Of these benefits, which is MOST appealing?
Which is LEAST appealing?

☐ Win $1,000,000 cash
☐ Receive a free pen
☐ Get 10% off your next purchase
☐ Qualify for monthly newsletter

→ Any logical person picks "$1M" as MOST, "free pen" as LEAST
```

**Use Sparingly:**
- 1-2 per survey max
- Too obvious = respondents feel insulted
- Just enough to catch random clickers

---

### Monitor Response Patterns

**Red Flags:**
- Always selects items in same position (first and last)
- Completion time < 50% of median
- No variation in responses
- Fails dominant set(s)

**Quality Filters:**
- Flag obvious speeders
- Remove failed attention checks
- Check for position bias

---

## Real-World Example: Feature Prioritization

**Business Question:**
"Which 5 features should we prioritize for our next product release?"

**MaxDiff Study Design:**

**Items (15 features):**
1. Longer battery life (2+ days)
2. Faster charging (50% in 15 minutes)
3. Better camera in low light
4. Larger screen display
5. 5G connectivity
6. Water resistance (IP68)
7. Wireless charging
8. Fingerprint sensor
9. Face recognition unlock
10. Expandable storage
11. Headphone jack
12. Dual SIM capability
13. Stereo speakers
14. Ultra-fast processor
15. Lightweight design

**Task Design:**
- 4 features per set
- 12 tasks per respondent
- Each feature appears 3-4 times

**Example Task:**
```
Task 5 of 12

Of these features, which is MOST important for your next smartphone?
Which is LEAST important?

                                    MOST   LEAST
Longer battery life (2+ days)        ○      ○
Water resistance (IP68)              ○      ○
Headphone jack                       ○      ○
Ultra-fast processor                 ○      ○
```

**Sample:** 300 smartphone users

**Results Show:**
1. Longer battery life (100 - highest)
2. Faster charging (87)
3. Better camera (81)
4. Water resistance (72)
5. Larger screen (68)
...
15. Dual SIM (22 - lowest)

**Business Decision:**
- Prioritize battery, charging, camera in next release
- Defer dual SIM, headphone jack, expandable storage

---

## Quick Reference Checklist

**Item List:**
- ✓ 10-30 items total (ideal: 15-20)
- ✓ All items comparable (same dimension)
- ✓ Specific, distinct items (no overlaps)
- ✓ Neutral wording (no bias)
- ✓ Similar length (5-10 words each)
- ✓ Parallel structure throughout

**Task Design:**
- ✓ 4 items shown per task
- ✓ 8-15 tasks per respondent
- ✓ Each item appears 3-4 times total
- ✓ Orthogonal experimental design
- ✓ Randomized task order

**Survey Flow:**
- ✓ Clear instructions included
- ✓ Practice task shown first
- ✓ Progress bar displayed
- ✓ 1-2 dominant sets for quality check
- ✓ Mobile-optimized layout

**Sample:**
- ✓ Minimum 150 respondents (aggregate)
- ✓ 200+ for individual HB estimates
- ✓ 300+ for segmentation

---

## Bottom Line

MaxDiff is ideal for ranking 10-30 items, but requires careful design:

**Critical Success Factors:**
1. **10-30 items** - Not too few, not too many
2. **All items comparable** - Same dimension (features, benefits, etc.)
3. **4 items per task** - Optimal cognitive load
4. **Use design software** - Ensures balance and efficiency
5. **Mobile-friendly** - Most respondents on phones
6. **150+ sample minimum** - For stable rankings

Get the design right and MaxDiff delivers precise importance rankings that simple rating scales can't match.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*
