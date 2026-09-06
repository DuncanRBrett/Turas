// =============================================================================
// Tests for the Overview derivations in brand_summary_panel.js
//
// Run from the Turas project root with:
//   node modules/brand/tests/js/test_summary_overview.js
//
// The panel file is an IIFE that reads the DOM, so it is run here against a
// stub document that has no .brsum-root. init() then returns immediately and
// the pure derivations it exposes on window.brsumDerive are exercised
// directly, with hand-built payload snapshots shaped exactly like the ones
// 14_summary_panel.R writes.
//
// No test framework. Known-answer assertions only.
// =============================================================================

'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

// ---------------------------------------------------------------------------
// Stub the two globals the panel touches at load time.
// ---------------------------------------------------------------------------
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
  __dirname, '../../lib/html_report/js/brand_summary_panel.js'
);
vm.runInThisContext(fs.readFileSync(jsPath, 'utf8'));

const D = global.window.brsumDerive;

// ---------------------------------------------------------------------------
// Minimal runner
// ---------------------------------------------------------------------------
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

function section(name) { console.log('\n' + name); }

// ---------------------------------------------------------------------------
// Payload builders. Shapes copied from a generated IPK fixture report:
//   focal_metrics[0] = { label: "MMS", value, cat_avg, rank: "Rank 1 / 15" }
//   ma_metrics       = mpen / ns / mms / som, no rank field at all
//   brand_summary    = pen / buy_rate / vol_share / scr_obs
// ---------------------------------------------------------------------------
function snapshot(opts) {
  const o = opts || {};
  const rank = o.rank == null ? null : 'Rank ' + o.rank + ' / ' + (o.of || 15);
  return {
    name: o.name || 'Focal Brand',
    code: o.code || 'FOC',
    colour: '#1A5276',
    focal_metrics: [
      { label: 'MMS', value: o.mms || '10%', cat_avg: o.mmsAvg || '7%',
        rank: rank },
      { label: 'MPen', value: o.mpen || '84%', cat_avg: o.mpenAvg || '56%',
        rank: null },
      { label: 'Bought target', value: o.bt || '45%', cat_avg: o.btAvg || '13%',
        rank: null },
      { label: 'Loyalty (Sole)', value: '22%', cat_avg: '15%', rank: null },
      { label: 'Net WOM', value: '+14', cat_avg: '+9', rank: null }
    ],
    ma_metrics: [
      { key: 'mpen', label: 'Mental Penetration (MPen)',
        value: o.mpen || '84%', cat_avg: o.mpenAvg || '56%',
        leader: 'Leader Brand', is_leader: false },
      { key: 'ns', label: 'Network Size (NS)', value: '2.71', cat_avg: '2.58',
        leader: 'Leader Brand', is_leader: false },
      { key: 'mms', label: 'Mental Market Share (MMS)',
        value: o.mms || '10%', cat_avg: o.mmsAvg || '7%',
        leader: 'Leader Brand', is_leader: false },
      { key: 'som', label: 'Share of Mind (SOM)', value: '12%', cat_avg: '12%',
        leader: 'Leader Brand', is_leader: false }
    ],
    brand_summary: [
      { key: 'pen', label: 'Penetration', value: o.pen || '45%',
        cat_avg: o.penAvg || '13%' },
      { key: 'buy_rate', label: 'Avg purchases / buyer', value: '7.2',
        cat_avg: '4.2' },
      { key: 'vol_share', label: 'Volume share', value: '32%', cat_avg: '6%' },
      { key: 'scr_obs', label: 'SCR (observed)', value: o.scr || '71%',
        cat_avg: o.scrAvg || '42%' }
    ],
    wom: { available: false }
  };
}

const CAT = { label: 'Dry Seasonings & Spices', n_brands: 15 };
const CAT_NAME = 'Dry Seasonings & Spices';

// ---------------------------------------------------------------------------
section('parseRank normalises every shape the payload could carry');
// ---------------------------------------------------------------------------
assertEqual('the string the R payload writes',
  JSON.stringify(D.parseRank('Rank 1 / 15')), JSON.stringify({ rank: 1, of: 15 }));
assertEqual('a bare number',
  JSON.stringify(D.parseRank(4)), JSON.stringify({ rank: 4, of: null }));
assertEqual('a hash form',
  JSON.stringify(D.parseRank('#7 of 12')), JSON.stringify({ rank: 7, of: 12 }));
assertEqual('a slash form',
  JSON.stringify(D.parseRank('3/9')), JSON.stringify({ rank: 3, of: 9 }));
assertEqual('an object form',
  JSON.stringify(D.parseRank({ rank: 2, of: 8 })),
  JSON.stringify({ rank: 2, of: 8 }));
assertEqual('null carries no rank',
  JSON.stringify(D.parseRank(null)), JSON.stringify({ rank: null, of: null }));
assertEqual('text with no digits carries no rank',
  JSON.stringify(D.parseRank('not ranked')),
  JSON.stringify({ rank: null, of: null }));
assertEqual('a zero rank is refused rather than shown',
  JSON.stringify(D.parseRank('Rank 0 / 15')),
  JSON.stringify({ rank: null, of: null }));

// ---------------------------------------------------------------------------
section('the rank reaches the hero from where the payload actually writes it');
// ---------------------------------------------------------------------------
// The regression this covers: heroAnchors read m.rank off ma_metrics, which
// carries no rank field, so mms_rank was always null, the rank badge was
// never emitted and the headline fell through to "<brand> in <category>".
const a1 = D.heroAnchors(snapshot({ rank: 1, of: 15 }));
assertEqual('rank read off focal_metrics', a1.mms_rank, 1);
assertEqual('the denominator comes with it', a1.mms_rank_of, 15);
assertEqual('the MMS value still resolves', a1.mms, '10%');
assertEqual('the MMS category average still resolves', a1.mms_avg, '7%');
assertEqual('MPen still resolves from ma_metrics', a1.mpen, '84%');
assertEqual('bought still resolves from brand_summary', a1.pen, '45%');
assertEqual('SCR still resolves from brand_summary', a1.scr, '71%');

// A payload that starts carrying the rank on ma_metrics keeps working.
const withMaRank = snapshot({ rank: null });
withMaRank.ma_metrics[2].rank = 'Rank 6 / 15';
const aMa = D.heroAnchors(withMaRank);
assertEqual('ma_metrics stays a live fallback', aMa.mms_rank, 6);
assertEqual('with its denominator', aMa.mms_rank_of, 15);

const aNone = D.heroAnchors(snapshot({ rank: null }));
assertEqual('no rank anywhere stays null', aNone.mms_rank, null);

// ---------------------------------------------------------------------------
section('the rank clause renders at rank 1, mid-table and last');
// ---------------------------------------------------------------------------
const top = D.heroHeadline(snapshot({ rank: 1, of: 15, name: 'Top Brand' }),
                           CAT, CAT_NAME);
assertEqual('rank 1 is read', top.rank, 1);
assert('rank 1 names the brand as category leader by Mental Market Share',
  top.headline.indexOf('Top Brand is the category leader by Mental Market Share') === 0);
assert('rank 1 names the category',
  top.headline.indexOf(CAT_NAME) > 0);

const mid = D.heroHeadline(snapshot({ rank: 8, of: 15, name: 'Mid Brand' }),
                           CAT, CAT_NAME);
assertEqual('mid rank is read', mid.rank, 8);
assert('mid-table states the rank and the field size',
  mid.headline.indexOf('#8 of 15') > 0);
assert('mid-table does not claim leadership',
  mid.headline.indexOf('category leader') === -1);
assert('mid-table does not claim a bottom quartile',
  mid.headline.indexOf('bottom-quartile') === -1);

const last = D.heroHeadline(snapshot({ rank: 15, of: 15, name: 'Last Brand' }),
                            CAT, CAT_NAME);
assertEqual('last rank is read', last.rank, 15);
assert('last states the rank and the field size',
  last.headline.indexOf('#15 of 15') > 0);
assert('last does not claim leadership',
  last.headline.indexOf('category leader') === -1);

// Every one of the three renders a clause that is not the bare fallback.
[top, mid, last].forEach(function (r, i) {
  const label = ['rank 1', 'mid-table', 'last'][i];
  assert(label + ' does not fall through to the bare brand-in-category clause',
    r.headline.indexOf(' in ' + CAT_NAME + '.') !== 0 &&
    r.headline.length > (CAT_NAME.length + 12));
});

// The denominator the rank was computed against wins over the picker count.
const nine = D.heroHeadline(snapshot({ rank: 9, of: 9, name: 'Short Field' }),
                            { label: CAT_NAME, n_brands: 15 }, CAT_NAME);
assert('the rank denominator wins over n_brands',
  nine.headline.indexOf('#9 of 9') > 0);

// ---------------------------------------------------------------------------
section('no em dash reaches a reader');
// ---------------------------------------------------------------------------
[top, mid, last, nine].forEach(function (r, i) {
  assert('headline ' + i + ' carries no em dash', r.headline.indexOf('—') === -1);
});

// ---------------------------------------------------------------------------
console.log('\n' + passed + ' passed, ' + failed + ' failed');
process.exit(failed === 0 ? 0 : 1);
