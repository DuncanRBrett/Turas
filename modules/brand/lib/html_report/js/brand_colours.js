// =============================================================================
// TURAS BRAND COLOURS — Canonical colour resolution module
//
// Single source of truth for brand chip and chart colours across all panels.
// Every panel JS file calls TurasColours.getBrandColour(pd, brandCode) instead
// of maintaining its own palette, hash function, or resolution logic.
//
// Colour resolution priority (in order):
//   1. Explicit hex from the Brands sheet  (pd.config.brand_colours map)
//   2. Focal brand colour                  (pd.config.focal_colour or pd.focal_colour)
//   3. Stable Tableau-10 hash fallback     (same code → same colour, always)
//
// Data layout: panels store colour data under pd.config.brand_colours and
// pd.config.focal_colour.  The funnel panel additionally exposes pd.focal_colour
// at root; both paths are checked so the function is backwards-compatible.
//
// LOAD ORDER: this file must appear in the <script> bundle before any panel JS.
// =============================================================================

// SIZE-EXCEPTION: module pattern wraps constants + three tiny functions; no
// logic warrants splitting into separate files.
var TurasColours = (function () {
  'use strict';

  // ---------------------------------------------------------------------------
  // Palette
  // ---------------------------------------------------------------------------

  // 18-entry palette for the JS hash fallback.  Must stay in sync with
  // BRAND_COLOUR_PALETTE in 00_brand_colour_utils.R.
  //
  // In normal operation this fallback is never reached: R populates
  // pd.config.brand_colours for every brand via build_full_brand_colour_map(),
  // so getBrandColour() always hits the explicit-map branch.  The hash is
  // only a safety net for edge cases (unknown brand codes, old reports).
  //
  // Index 0–7: maximally distinct hues. Index 8+ reserved for large studies
  // and fallback edge cases.  Do not reorder indices 0–7.
  var PALETTE = [
    '#e15759',  //  0  red
    '#f28e2b',  //  1  orange
    '#59a14f',  //  2  green
    '#edc948',  //  3  yellow
    '#76b7b2',  //  4  teal
    '#b07aa1',  //  5  mauve
    '#d37295',  //  6  dark rose
    '#9c755f',  //  7  brown
    '#4e79a7',  //  8  steel blue
    '#499894',  //  9  dark teal
    '#e8a838',  // 10  amber
    '#1e8449',  // 11  dark green
    '#7d3c98',  // 12  deep purple
    '#2980b9',  // 13  bright blue
    '#ff9da7',  // 14  light rose
    '#bab0ac',  // 15  warm grey
    '#9d7660',  // 16  tan
    '#79706e'   // 17  charcoal
  ];

  // Neutral mid-grey used for pseudo-brands such as "__avg__" that are not
  // real competitors and should not compete visually with brand colours.
  var NEUTRAL = '#64748b';

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  // djb2 hash variant. Produces a stable non-negative integer for any string.
  // This is the ONE implementation — all brand colour hash lookups use it.
  function _djb2(str) {
    var h = 5381;
    for (var i = 0; i < str.length; i++) {
      h = ((h << 5) + h + str.charCodeAt(i)) & 0x7fffffff;
    }
    return h;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /**
   * Resolve the display colour for a brand code from a panel data object.
   *
   * @param  {Object} pd    Panel data object (parsed from the JSON script tag).
   * @param  {string} code  Brand code string.
   * @returns {string}      Hex colour string (always a valid value, never null).
   */
  function getBrandColour(pd, code) {
    if (!pd || !code) return NEUTRAL;

    // 1. Explicit per-brand override from the Brands sheet
    var colourMap = (pd.config && pd.config.brand_colours) || pd.brandColours;
    if (colourMap && colourMap[code]) return colourMap[code];

    // 2. Focal brand: use the project focal colour
    var focalCode = (pd.meta && pd.meta.focal_brand_code) || pd.focalBrand;
    if (code === focalCode) {
      return (pd.config && pd.config.focal_colour) ||
             pd.focal_colour  ||
             pd.focalColour   ||
             '#1A5276';
    }

    // 3. Stable Tableau-10 hash — identical result for a given code string
    //    regardless of how many brands are shown or their display order.
    return PALETTE[_djb2(code) % PALETTE.length];
  }

  /**
   * Return a stable palette colour for a brand code without any pd context.
   * Use only when building legends or annotations that have no focal/custom info.
   *
   * @param  {string} code  Brand code string.
   * @returns {string}      Hex colour string.
   */
  function hashColour(code) {
    if (!code) return NEUTRAL;
    return PALETTE[_djb2(code) % PALETTE.length];
  }

  return {
    getBrandColour: getBrandColour,
    hashColour:     hashColour,
    PALETTE:        PALETTE,
    NEUTRAL:        NEUTRAL
  };
}());
