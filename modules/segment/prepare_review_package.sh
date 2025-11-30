#!/bin/bash
# Turas Segmentation Module - Code Review Package Preparation Script
# This script collects all segmentation module files for external review

# Create review package directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REVIEW_DIR="segmentation_review_package_${TIMESTAMP}"
mkdir -p "${REVIEW_DIR}"

echo "========================================="
echo "Turas Segmentation Code Review Package"
echo "========================================="
echo ""
echo "Creating package in: ${REVIEW_DIR}"
echo ""

# Copy the review package documentation
cp SEGMENTATION_CODE_REVIEW_PACKAGE.md "${REVIEW_DIR}/"

# Create subdirectories
mkdir -p "${REVIEW_DIR}/main_scripts"
mkdir -p "${REVIEW_DIR}/lib"
mkdir -p "${REVIEW_DIR}/documentation"
mkdir -p "${REVIEW_DIR}/test_data"

# Copy main entry points
echo "Copying main entry points..."
cp run_segment.R "${REVIEW_DIR}/main_scripts/"
cp run_segment_gui.R "${REVIEW_DIR}/main_scripts/"

# Copy library files
echo "Copying library files..."
cp lib/segment_config.R "${REVIEW_DIR}/lib/"
cp lib/segment_data_prep.R "${REVIEW_DIR}/lib/"
cp lib/segment_kmeans.R "${REVIEW_DIR}/lib/"
cp lib/segment_validation.R "${REVIEW_DIR}/lib/"
cp lib/segment_profile.R "${REVIEW_DIR}/lib/"
cp lib/segment_profiling_enhanced.R "${REVIEW_DIR}/lib/"
cp lib/segment_outliers.R "${REVIEW_DIR}/lib/"
cp lib/segment_variable_selection.R "${REVIEW_DIR}/lib/"
cp lib/segment_export.R "${REVIEW_DIR}/lib/"
cp lib/segment_scoring.R "${REVIEW_DIR}/lib/"
cp lib/segment_visualization.R "${REVIEW_DIR}/lib/"
cp lib/segment_utils.R "${REVIEW_DIR}/lib/"

# Copy documentation files
echo "Copying documentation..."
cp README.md "${REVIEW_DIR}/documentation/"
cp USER_MANUAL.md "${REVIEW_DIR}/documentation/"
cp QUICK_START.md "${REVIEW_DIR}/documentation/"
cp EXAMPLE_WORKFLOWS.md "${REVIEW_DIR}/documentation/"
cp MAINTENANCE_MANUAL.md "${REVIEW_DIR}/documentation/"
cp TESTING_CHECKLIST.md "${REVIEW_DIR}/documentation/"
cp TESTING_SUMMARY.md "${REVIEW_DIR}/documentation/"

# Copy test data and configuration
echo "Copying test data and configuration..."
cp test_data/generate_test_data.R "${REVIEW_DIR}/test_data/"
cp test_data/generate_test_data_20vars.R "${REVIEW_DIR}/test_data/"
cp test_data/generate_test_question_labels.R "${REVIEW_DIR}/test_data/"
cp test_data/regenerate_test_config.R "${REVIEW_DIR}/test_data/"
cp test_data/test_segmentation_real_data.R "${REVIEW_DIR}/test_data/"
cp test_data/test_segment_config.xlsx "${REVIEW_DIR}/test_data/"
cp test_data/test_segment_config.csv "${REVIEW_DIR}/test_data/"
cp test_data/test_varsel_config.xlsx "${REVIEW_DIR}/test_data/"
cp test_data/test_varsel_config.csv "${REVIEW_DIR}/test_data/"
cp test_data/test_survey_data.csv "${REVIEW_DIR}/test_data/"
cp test_data/test_question_labels.xlsx "${REVIEW_DIR}/test_data/"
cp test_data/TEST_GUIDE.md "${REVIEW_DIR}/test_data/"
cp test_data/VARSEL_TEST_GUIDE.md "${REVIEW_DIR}/test_data/"

# Generate file inventory
echo ""
echo "Generating file inventory..."
cat > "${REVIEW_DIR}/FILE_INVENTORY.txt" << 'EOF'
TURAS SEGMENTATION MODULE - FILE INVENTORY
=========================================

MAIN SCRIPTS (2 files):
  main_scripts/run_segment.R
  main_scripts/run_segment_gui.R

LIBRARY FILES (12 files):
  lib/segment_config.R
  lib/segment_data_prep.R
  lib/segment_kmeans.R
  lib/segment_validation.R
  lib/segment_profile.R
  lib/segment_profiling_enhanced.R
  lib/segment_outliers.R
  lib/segment_variable_selection.R
  lib/segment_export.R
  lib/segment_scoring.R
  lib/segment_visualization.R
  lib/segment_utils.R

DOCUMENTATION (7 files):
  documentation/README.md
  documentation/USER_MANUAL.md
  documentation/QUICK_START.md
  documentation/EXAMPLE_WORKFLOWS.md
  documentation/MAINTENANCE_MANUAL.md
  documentation/TESTING_CHECKLIST.md
  documentation/TESTING_SUMMARY.md

TEST DATA & CONFIGURATION (13 files):
  test_data/generate_test_data.R
  test_data/generate_test_data_20vars.R
  test_data/generate_test_question_labels.R
  test_data/regenerate_test_config.R
  test_data/test_segmentation_real_data.R
  test_data/test_segment_config.xlsx
  test_data/test_segment_config.csv
  test_data/test_varsel_config.xlsx
  test_data/test_varsel_config.csv
  test_data/test_survey_data.csv
  test_data/test_question_labels.xlsx
  test_data/TEST_GUIDE.md
  test_data/VARSEL_TEST_GUIDE.md

REVIEW DOCUMENTATION:
  SEGMENTATION_CODE_REVIEW_PACKAGE.md
  FILE_INVENTORY.txt (this file)

TOTAL: 36 files

Line counts by file type:
EOF

# Add line counts to inventory
echo "" >> "${REVIEW_DIR}/FILE_INVENTORY.txt"
find "${REVIEW_DIR}" -name "*.R" -type f -exec wc -l {} + | sort -rn >> "${REVIEW_DIR}/FILE_INVENTORY.txt"
echo "" >> "${REVIEW_DIR}/FILE_INVENTORY.txt"
echo "Total R code lines:" >> "${REVIEW_DIR}/FILE_INVENTORY.txt"
find "${REVIEW_DIR}" -name "*.R" -type f -exec cat {} + | wc -l >> "${REVIEW_DIR}/FILE_INVENTORY.txt"

# Create archive
echo ""
echo "Creating compressed archive..."
tar -czf "${REVIEW_DIR}.tar.gz" "${REVIEW_DIR}"

# Create zip archive (alternative format)
if command -v zip &> /dev/null; then
    zip -r -q "${REVIEW_DIR}.zip" "${REVIEW_DIR}"
    echo "Created: ${REVIEW_DIR}.zip"
fi

echo "Created: ${REVIEW_DIR}.tar.gz"
echo ""
echo "========================================="
echo "Package preparation complete!"
echo "========================================="
echo ""
echo "Review package contents:"
echo "  Directory: ${REVIEW_DIR}/"
echo "  Archive: ${REVIEW_DIR}.tar.gz"
if [ -f "${REVIEW_DIR}.zip" ]; then
    echo "  Archive: ${REVIEW_DIR}.zip"
fi
echo ""
echo "To send for external review:"
echo "  1. Review SEGMENTATION_CODE_REVIEW_PACKAGE.md"
echo "  2. Share the .tar.gz or .zip archive"
echo "  3. Ensure reviewers have access to test data"
echo ""
echo "File statistics:"
find "${REVIEW_DIR}" -type f -name "*.R" | wc -l | xargs echo "  R source files:"
find "${REVIEW_DIR}" -type f -name "*.md" | wc -l | xargs echo "  Documentation files:"
find "${REVIEW_DIR}" -type f -name "*.csv" | wc -l | xargs echo "  CSV files:"
find "${REVIEW_DIR}" -type f -name "*.xlsx" | wc -l | xargs echo "  Excel files:"
echo ""
