/**
 * The engine modules the cross-engine parity suite loads, in load order.
 *
 * Shared so that parity_stats_tests.mjs and production_bundle_tests.mjs agree
 * on what "the engine" is. The production gate concatenates exactly these
 * files, puts them through the shipped terser and obfuscator settings, and
 * runs the parity assertions against the result.
 */
export const PARITY_ENGINE_MODULES = [
  "00_namespace.js", "01_format.js", "03_svg.js", "20_data.js",
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js",
  "22_model.js", "23_render.js", "26_filter.js"
];
