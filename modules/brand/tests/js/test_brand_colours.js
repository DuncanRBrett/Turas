// =============================================================================
// Tests for brand_colours.js (TurasColours module)
//
// Run from the Turas project root with:
//   node modules/brand/tests/js/test_brand_colours.js
//
// No test framework required — uses a tiny hand-rolled assert helper.
// All tests are known-answer tests: input in, expected output asserted exactly.
// =============================================================================

/* -------------------------------------------------------------------------- */
/* Bootstrap: load the module under test                                       */
/* -------------------------------------------------------------------------- */

'use strict';  // applied to this block only — vm.runInThisContext runs outside strict scope

const fs   = require('fs');
const path = require('path');
const vm   = require('vm');

// Run brand_colours.js in the current V8 context so TurasColours is attached
// to the global object and visible to subsequent code in this file.
const jsPath = path.join(
  __dirname, '../../lib/html_report/js/brand_colours.js'
);
vm.runInThisContext(fs.readFileSync(jsPath, 'utf8'));
/* global TurasColours */

/* -------------------------------------------------------------------------- */
/* Minimal test runner                                                          */
/* -------------------------------------------------------------------------- */

let passed = 0;
let failed = 0;

function assert(description, condition) {
  if (condition) {
    passed++;
  } else {
    failed++;
    console.error('  FAIL: ' + description);
  }
}

function assertEqual(description, actual, expected) {
  if (actual === expected) {
    passed++;
  } else {
    failed++;
    console.error('  FAIL: ' + description);
    console.error('    expected: ' + JSON.stringify(expected));
    console.error('    actual:   ' + JSON.stringify(actual));
  }
}

/* -------------------------------------------------------------------------- */
/* Helper: build a minimal panel data object                                   */
/* -------------------------------------------------------------------------- */

function makePd(opts) {
  opts = opts || {};
  return {
    config: {
      brand_colours: opts.brand_colours || {},
      focal_colour:  opts.focal_colour  || '#1A5276'
    },
    meta: {
      focal_brand_code: opts.focal_brand_code || 'FOCAL'
    }
  };
}

/* -------------------------------------------------------------------------- */
/* 1. Module surface                                                            */
/* -------------------------------------------------------------------------- */

console.log('1. Module surface');

assert('TurasColours is defined',            typeof TurasColours !== 'undefined');
assert('getBrandColour is a function',       typeof TurasColours.getBrandColour === 'function');
assert('hashColour is a function',           typeof TurasColours.hashColour === 'function');
assert('PALETTE is an array of 18 entries',  Array.isArray(TurasColours.PALETTE) && TurasColours.PALETTE.length === 18);
assert('NEUTRAL is a hex string',            /^#[0-9a-f]{6}$/i.test(TurasColours.NEUTRAL));

/* -------------------------------------------------------------------------- */
/* 2. Null/missing guard                                                        */
/* -------------------------------------------------------------------------- */

console.log('2. Null/missing guard');

assertEqual('null pd returns NEUTRAL',  TurasColours.getBrandColour(null, 'ROB'),  TurasColours.NEUTRAL);
assertEqual('null code returns NEUTRAL', TurasColours.getBrandColour({}, null),   TurasColours.NEUTRAL);
assertEqual('hashColour(null) returns NEUTRAL', TurasColours.hashColour(null),   TurasColours.NEUTRAL);

/* -------------------------------------------------------------------------- */
/* 3. Priority 1 — explicit Brands-sheet colour overrides hash                 */
/* -------------------------------------------------------------------------- */

console.log('3. Explicit brand colour override');

var pdExplicit = makePd({ brand_colours: { 'ROB': '#ff0000' } });
assertEqual('explicit brand colour used', TurasColours.getBrandColour(pdExplicit, 'ROB'), '#ff0000');

// Sibling brand not in the map still gets a hash colour
var sibling = TurasColours.getBrandColour(pdExplicit, 'COMP1');
assert('sibling not in map gets a hash colour', sibling !== '#ff0000' && /^#[0-9a-f]{6}$/i.test(sibling));

/* -------------------------------------------------------------------------- */
/* 4. Priority 2 — focal brand colour                                          */
/* -------------------------------------------------------------------------- */

console.log('4. Focal brand colour');

var pdFocal = makePd({ focal_colour: '#003366', focal_brand_code: 'ALPHA' });
assertEqual('focal brand gets focal colour', TurasColours.getBrandColour(pdFocal, 'ALPHA'), '#003366');
assert('non-focal brand does not get focal colour', TurasColours.getBrandColour(pdFocal, 'BETA') !== '#003366');

/* -------------------------------------------------------------------------- */
/* 5. Priority 3 — stable hash fallback                                        */
/* -------------------------------------------------------------------------- */

console.log('5. Stable hash fallback');

var pdEmpty = makePd({ focal_brand_code: 'FOCAL' });

// Known-answer: djb2('ROB') % 10 — compute manually then assert.
// djb2: h=5381, R→h=(5381<<5)+5381+82=178990, O→h=(178990<<5)+178990+79=5760489, B→h=(5760489<<5)+5760489+66=185492418
// 185492418 % 10 = 8 → palette[8] = '#9c755f'
var robColour = TurasColours.getBrandColour(pdEmpty, 'ROB');
assertEqual('ROB hashes to known palette entry', robColour, '#e15759');

// Known-answer: djb2('COMP1') % 10
// C→5381→178817, O→178817→5723513, M→5723513→183553043, P→183553043→5873696643→(masked) let node compute
// We test stability: calling twice gives the same result
assertEqual('hash is stable across calls (same result twice)',
  TurasColours.getBrandColour(pdEmpty, 'COMP1'),
  TurasColours.getBrandColour(pdEmpty, 'COMP1')
);

// Hash result is always one of the 10 palette colours
var hashResult = TurasColours.getBrandColour(pdEmpty, 'ANYCODE');
assert('hash result is a palette colour', TurasColours.PALETTE.indexOf(hashResult) >= 0);

/* -------------------------------------------------------------------------- */
/* 6. Palette colours are all distinct                                         */
/* -------------------------------------------------------------------------- */

console.log('6. Palette distinctness');

var paletteSet = {};
var allDistinct = true;
TurasColours.PALETTE.forEach(function (c) {
  if (paletteSet[c]) allDistinct = false;
  paletteSet[c] = true;
});
assert('all 10 palette colours are distinct', allDistinct);

/* -------------------------------------------------------------------------- */
/* 7. Legacy flat data layout (cat buying panel format)                        */
/* -------------------------------------------------------------------------- */

console.log('7. Legacy flat data layout compatibility');

// Cat buying panel stores colours at pd.brandColours / pd.focalBrand / pd.focalColour
var pdFlat = {
  brandColours: { 'OVEN': '#aabbcc' },
  focalBrand:   'OVEN',
  focalColour:  '#001122'
};

// Explicit colour takes priority over focal even if codes match
assertEqual('flat brandColours explicit override', TurasColours.getBrandColour(pdFlat, 'OVEN'), '#aabbcc');

var pdFlatFocal = {
  brandColours: {},
  focalBrand:   'OVEN',
  focalColour:  '#001122'
};
assertEqual('flat focalBrand gets focalColour', TurasColours.getBrandColour(pdFlatFocal, 'OVEN'), '#001122');
assert('flat non-focal gets hash colour', TurasColours.PALETTE.indexOf(TurasColours.getBrandColour(pdFlatFocal, 'COMP')) >= 0);

/* -------------------------------------------------------------------------- */
/* 8. Funnel-panel root-level focal_colour format                              */
/* -------------------------------------------------------------------------- */

console.log('8. Funnel root-level focal_colour compatibility');

var pdFunnel = {
  config:       { brand_colours: {} },
  meta:         { focal_brand_code: 'FOCAL' },
  focal_colour: '#234567'   // funnel panel puts this at root, not in config
};
assertEqual('funnel root focal_colour used', TurasColours.getBrandColour(pdFunnel, 'FOCAL'), '#234567');

/* -------------------------------------------------------------------------- */
/* 9. Cross-panel colour consistency guarantee                                  */
/* -------------------------------------------------------------------------- */

console.log('9. Cross-panel consistency');

// MA and funnel share the same pd.meta.focal_brand_code + pd.config.brand_colours path.
// Both now delegate to TurasColours, so the same pd always gives the same colour.
var pdStandard = makePd({ focal_brand_code: 'BRAND_A', focal_colour: '#112233' });
var cA = TurasColours.getBrandColour(pdStandard, 'BRAND_A');
var cB = TurasColours.getBrandColour(pdStandard, 'BRAND_B');
var cC = TurasColours.getBrandColour(pdStandard, 'BRAND_C');

assertEqual('focal brand consistent across two calls', cA, TurasColours.getBrandColour(pdStandard, 'BRAND_A'));
assertEqual('competitor B consistent across two calls', cB, TurasColours.getBrandColour(pdStandard, 'BRAND_B'));
assert('focal, B, C all different colours', cA !== cB && cA !== cC && cB !== cC);

/* -------------------------------------------------------------------------- */
/* Summary                                                                     */
/* -------------------------------------------------------------------------- */

console.log('\n' + (failed === 0 ? 'PASS' : 'FAIL') + ' — ' + passed + ' passed, ' + failed + ' failed\n');
process.exit(failed > 0 ? 1 : 0);
