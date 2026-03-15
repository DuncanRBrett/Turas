# ==============================================================================
# TURAS>TABS - CONFIGURATION LOADER (V10.8.1 — Cleaned)
# ==============================================================================
# Legacy orchestration functions have been removed.
# All config loading is now handled by:
#   - config_utils.R     — load_config_sheet(), get_config_value()
#   - crosstabs_config.R — load_crosstabs_config(), build_config_object()
#   - data_setup.R       — load_crosstabs_data(), load_question_selection()
#
# This file is retained only as a source target in run_crosstabs.R (line 167)
# to avoid breaking the existing source() chain. It contains no functions.
# ==============================================================================

message("Turas>Tabs config_loader module loaded")
