#!/usr/bin/env python3
"""
Create sample CBC (Choice-Based Conjoint) data for testing
"""

import pandas as pd
import numpy as np
import random

# Set seed for reproducibility
random.seed(42)
np.random.seed(42)

# Define attributes and levels (matching example_config.xlsx)
attributes = {
    'Brand': ['Apple', 'Samsung', 'Google', 'OnePlus'],
    'Price': ['$299', '$399', '$499', '$599'],
    'Screen_Size': ['5.5 inches', '6.1 inches', '6.7 inches'],
    'Battery_Life': ['12 hours', '18 hours', '24 hours'],
    'Camera_Quality': ['Basic', 'Good', 'Excellent']
}

# True part-worth utilities (for generating realistic choices)
# These will drive choice behavior
true_utilities = {
    'Brand': {'Apple': 0.8, 'Samsung': 0.4, 'Google': 0.2, 'OnePlus': -1.4},
    'Price': {'$299': 1.2, '$399': 0.4, '$499': -0.3, '$599': -1.3},
    'Screen_Size': {'5.5 inches': -0.6, '6.1 inches': 0.0, '6.7 inches': 0.6},
    'Battery_Life': {'12 hours': -0.8, '18 hours': 0.0, '24 hours': 0.8},
    'Camera_Quality': {'Basic': -0.7, 'Good': 0.0, 'Excellent': 0.7}
}

# Study design parameters
n_respondents = 50
n_choice_sets_per_respondent = 8
n_alternatives_per_set = 3

# Generate data
data_rows = []
choice_set_counter = 0

for resp_id in range(1, n_respondents + 1):
    for cs in range(1, n_choice_sets_per_respondent + 1):
        choice_set_counter += 1

        # Generate alternatives for this choice set
        alternatives = []

        for alt in range(1, n_alternatives_per_set + 1):
            # Randomly select levels for each attribute
            profile = {
                'Brand': random.choice(attributes['Brand']),
                'Price': random.choice(attributes['Price']),
                'Screen_Size': random.choice(attributes['Screen_Size']),
                'Battery_Life': random.choice(attributes['Battery_Life']),
                'Camera_Quality': random.choice(attributes['Camera_Quality'])
            }

            # Calculate utility for this profile
            utility = sum(true_utilities[attr][profile[attr]] for attr in profile.keys())

            # Add random error (Gumbel distribution for logit)
            utility += np.random.gumbel(0, 1)

            alternatives.append({
                'resp_id': resp_id,
                'choice_set_id': choice_set_counter,
                'alternative_id': alt,
                **profile,
                'utility': utility
            })

        # Determine which alternative was chosen (highest utility)
        chosen_idx = max(range(len(alternatives)), key=lambda i: alternatives[i]['utility'])

        # Create data rows
        for idx, alt in enumerate(alternatives):
            data_rows.append({
                'resp_id': alt['resp_id'],
                'choice_set_id': alt['choice_set_id'],
                'alternative_id': alt['alternative_id'],
                'Brand': alt['Brand'],
                'Price': alt['Price'],
                'Screen_Size': alt['Screen_Size'],
                'Battery_Life': alt['Battery_Life'],
                'Camera_Quality': alt['Camera_Quality'],
                'chosen': 1 if idx == chosen_idx else 0
            })

# Create DataFrame
df = pd.DataFrame(data_rows)

# Verify data quality
print(f"✓ Generated {len(df)} rows of data")
print(f"  - {n_respondents} respondents")
print(f"  - {choice_set_counter} choice sets")
print(f"  - {n_alternatives_per_set} alternatives per choice set")
print(f"  - {df['chosen'].sum()} choices (should equal {choice_set_counter})")

# Check: exactly one chosen per choice set
choices_per_set = df.groupby('choice_set_id')['chosen'].sum()
if (choices_per_set == 1).all():
    print("  ✓ Data validation passed: exactly one chosen per choice set")
else:
    print(f"  ✗ WARNING: {(choices_per_set != 1).sum()} choice sets have wrong number of choices")

# Show level frequencies
print("\nLevel frequencies:")
for attr in ['Brand', 'Price', 'Screen_Size', 'Battery_Life', 'Camera_Quality']:
    print(f"\n{attr}:")
    freq = df[attr].value_counts().sort_index()
    for level, count in freq.items():
        chosen_count = df[(df[attr] == level) & (df['chosen'] == 1)].shape[0]
        choice_pct = (chosen_count / count * 100) if count > 0 else 0
        print(f"  {level:20s}: {count:4d} appearances, {chosen_count:3d} chosen ({choice_pct:5.1f}%)")

# Save to CSV
output_file = "/home/user/Turas/modules/conjoint/examples/sample_cbc_data.csv"
df.to_csv(output_file, index=False)

print(f"\n✓ Sample data saved: {output_file}")
print("\nFirst few rows:")
print(df.head(10))
