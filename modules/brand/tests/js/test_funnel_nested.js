// =============================================================================
// Tests for the nested-funnel base mode in brand_funnel_panel.js
//
// Run from the Turas project root with:
//   node modules/brand/tests/js/test_funnel_nested.js
//
// The panel file is an IIFE that reads the DOM, so it is run here against a
// stub document with no .fn-panel. initPanel() is never reached and the pure
// helpers it exposes on window.fnDerive are exercised directly, against cell
// objects shaped exactly like the ones .panel_table() writes in
// R/03c_funnel_panel_data.R.
//
// No test framework. Known-answer assertions only.
// =============================================================================

'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const doc = {
  readyState: 'complete',
  querySelector: function () { return null; },
  querySelectorAll: function () { return []; },
  getElementById: function () { return null; },
  addEventListener: function () {}
};
global.document = doc;
global.window = global;

const jsPath = path.join(
  __dirname, '../../lib/html_report/js/brand_funnel_panel.js'
);
vm.runInThisContext(fs.readFileSync(jsPath, 'utf8'));

const D = global.window.fnDerive;

let passed = 0;
let failed = 0;

function assert(description, condition) {
  if (condition) { passed++; return; }
  failed++;
  console.error('  FAIL: ' + description);
}

function assertEqual(description, actual, expected) {
  if (actual === expected) { passed++; return; }
  failed++;
  console.error('  FAIL: ' + description);
  console.error('    expected: ' + JSON.stringify(expected));
  console.error('    actual:   ' + JSON.stringify(actual));
}

function assertClose(description, actual, expected, tol) {
  const t = tol == null ? 1e-9 : tol;
  if (actual != null && Math.abs(actual - expected) <= t) { passed++; return; }
  failed++;
  console.error('  FAIL: ' + description);
  console.error('    expected: ' + expected + ' (+/- ' + t + ')');
  console.error('    actual:   ' + actual);
}

// ---------------------------------------------------------------------------
// The chain counts and the absolute percentages below were read off a
// generated IPK fixture report on 6 September 2026: focal brand IPK in Dry
// Seasonings and Spices, n_weighted 438.
//   aware          chain 405  abs 0.924658
//   consideration  chain 293  abs 0.668950
//   bought_long    chain 195  abs 0.623288
//   bought_target  chain 142  abs 0.449772
// pct_nested is written out as the exact ratio of those chain counts, which
// is what the engine computes. pct_aware is a stand-in: nothing here checks
// its value, only that the "aware" mode reads that field and no other.
// ---------------------------------------------------------------------------
const N_W = 438;
const STAGES = ['aware', 'consideration', 'bought_long', 'bought_target'];

function cell(stage, brand, chain, abs, nested, aware) {
  return {
    stage_key: stage,
    brand_code: brand,
    pct_absolute: abs,
    pct_nested: nested,
    pct_aware: aware,
    base_chain_filtered: chain
  };
}

const FIXTURE = [
  cell('aware',         'IPK', 405, 0.924658, 1.0,       1.0),
  cell('consideration', 'IPK', 293, 0.668950, 293 / 405, 0.11),
  cell('bought_long',   'IPK', 195, 0.623288, 195 / 293, 0.22),
  cell('bought_target', 'IPK', 142, 0.449772, 142 / 195, 0.33)
];

console.log('chainPct: the nested figure is the chain count over the base');
STAGES.forEach(function (sk, i) {
  const c = FIXTURE[i];
  assertClose('chain % at ' + sk, D.chainPct(c, N_W), c.base_chain_filtered / N_W);
});
assertClose('aware reads 92%', D.chainPct(FIXTURE[0], N_W), 405 / 438);
assertClose('prefer reads 67%', D.chainPct(FIXTURE[1], N_W), 293 / 438);
assertClose('past 12 months reads 45%', D.chainPct(FIXTURE[2], N_W), 195 / 438);
assertClose('past 3 months reads 32%', D.chainPct(FIXTURE[3], N_W), 142 / 438);

console.log('chainPct: the first stage agrees with its own absolute figure');
assertClose('stage one nested == absolute', D.chainPct(FIXTURE[0], N_W),
            FIXTURE[0].pct_absolute, 1e-6);

console.log('chainPct: the chain never rises');
for (let i = 1; i < FIXTURE.length; i++) {
  assert('stage ' + STAGES[i] + ' sits at or below the stage before it',
         D.chainPct(FIXTURE[i], N_W) <= D.chainPct(FIXTURE[i - 1], N_W));
}

console.log('chainPct: successive ratios are the % of previous view');
for (let i = 1; i < FIXTURE.length; i++) {
  const r = D.chainPct(FIXTURE[i], N_W) / D.chainPct(FIXTURE[i - 1], N_W);
  assertClose('ratio at ' + STAGES[i] + ' equals pct_nested', r,
              FIXTURE[i].pct_nested, 1e-6);
}

console.log('chainPct: missing inputs return null rather than a guess');
assertEqual('no cell', D.chainPct(null, N_W), null);
assertEqual('no base', D.chainPct(FIXTURE[0], null), null);
assertEqual('zero base is not a denominator', D.chainPct(FIXTURE[0], 0), null);
assertEqual('no chain count',
            D.chainPct({ stage_key: 'aware', pct_absolute: 0.5 }, N_W), null);
assertClose('a cell rebuilt from the td attribute is read straight',
            D.chainPct({ pct_chain: 0.324201 }, null), 0.324201);

console.log('cellValueForMode: each mode reads its own field');
const cv = FIXTURE[2];
assertClose('chain', D.cellValueForMode(cv, 'chain', 'aware', {}, N_W),
            195 / 438);
assertClose('total', D.cellValueForMode(cv, 'total', 'aware', {}, N_W),
            0.623288);
assertClose('previous', D.cellValueForMode(cv, 'previous', 'aware', {}, N_W),
            195 / 293);
assertClose('aware', D.cellValueForMode(cv, 'aware', 'aware', {}, N_W), 0.22);

console.log('cellValueForMode: chain falls back to the absolute figure');
const noChain = { stage_key: 'bought_long', brand_code: 'X',
                  pct_absolute: 0.4, pct_nested: 0.5, pct_aware: 0.6 };
assertClose('no chain count falls back rather than blanking',
            D.cellValueForMode(noChain, 'chain', 'aware', {}, N_W), 0.4);

console.log('chainAvgByStage: the formula per brand, then the mean');
const twoBrands = [
  cell('aware', 'A', 400, 0.9, 1.0, 1.0),
  cell('aware', 'B', 200, 0.45, 1.0, 1.0),
  cell('bought_target', 'A', 100, 0.3, 0.25, 0.25),
  cell('bought_target', 'B', 40,  0.1, 0.2,  0.2)
];
const avg = D.chainAvgByStage(twoBrands, ['aware', 'bought_target'], 1000);
assertClose('aware average', avg.aware, (0.4 + 0.2) / 2);
assertClose('target average', avg.bought_target, (0.1 + 0.04) / 2);
assert('it is not the ratio of the summed counts',
       Math.abs(avg.aware - 600 / 2000) > 1e-9 ||
       Math.abs(avg.aware - 0.3) < 1e-9);
const avgNone = D.chainAvgByStage([], ['aware'], 1000);
assertEqual('a stage with no brand values reports nothing', avgNone.aware, null);

console.log('baseModeLabelFor: every view names its own computation');
assertEqual('chain', D.baseModeLabelFor('chain'),
            'the nested funnel, % of all respondents');
assertEqual('total', D.baseModeLabelFor('total'), 'each stage on its own');
assertEqual('previous', D.baseModeLabelFor('previous'), '% of previous stage');
assertEqual('aware', D.baseModeLabelFor('aware'), '% of those aware');
assert('only the nested view is called a funnel',
       D.baseModeLabelFor('chain').indexOf('funnel') >= 0 &&
       D.baseModeLabelFor('total').indexOf('funnel') < 0 &&
       D.baseModeLabelFor('previous').indexOf('funnel') < 0 &&
       D.baseModeLabelFor('aware').indexOf('funnel') < 0);
assert('an unknown mode does not silently claim a nesting',
       D.baseModeLabelFor('total') !== D.baseModeLabelFor('chain'));

console.log('sigBadgeHtml: a direction the engine did not give makes no badge');
assert('higher', D.sigBadgeHtml('higher').indexOf('fn-sig-up') >= 0);
assert('lower', D.sigBadgeHtml('lower').indexOf('fn-sig-down') >= 0);
assertEqual('na', D.sigBadgeHtml('na'), '');
assertEqual('not_sig', D.sigBadgeHtml('not_sig'), '');
assertEqual('empty', D.sigBadgeHtml(''), '');

console.log('');
console.log(passed + ' passed, ' + failed + ' failed');
process.exit(failed === 0 ? 0 : 1);
