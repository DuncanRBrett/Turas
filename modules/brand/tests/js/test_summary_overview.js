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
assert('rank 1 states the brand has the largest Mental Market Share',
  top.lines[0].indexOf('Top Brand has the largest Mental Market Share') === 0);
assert('rank 1 names the field size',
  top.lines[0].indexOf('of 15 brands measured') > 0);
assert('rank 1 names the category',
  top.headline.indexOf(CAT_NAME) > 0);

const mid = D.heroHeadline(snapshot({ rank: 8, of: 15, name: 'Mid Brand' }),
                           CAT, CAT_NAME);
assertEqual('mid rank is read', mid.rank, 8);
assert('mid-table states the rank and the field size',
  mid.headline.indexOf('#8 of 15') > 0);
assert('mid-table does not claim the largest share',
  mid.headline.indexOf('largest Mental Market Share') === -1);
assert('mid-table does not claim a bottom quartile',
  mid.headline.indexOf('bottom-quartile') === -1);

const last = D.heroHeadline(snapshot({ rank: 15, of: 15, name: 'Last Brand' }),
                            CAT, CAT_NAME);
assertEqual('last rank is read', last.rank, 15);
assert('last states the rank and the field size',
  last.headline.indexOf('#15 of 15') > 0);
assert('last does not claim the largest share',
  last.headline.indexOf('largest Mental Market Share') === -1);

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
section('the four headline tiles read the right field for each figure');
// ---------------------------------------------------------------------------
const FUNNEL = {
  available: true,
  stage_keys: ['aware', 'consideration', 'bought_long', 'bought_target'],
  stage_labels: ['Aware', 'Prefer', 'Past 12 months', 'Past 3 months'],
  base_label: 'n=438, total respondents',
  cat_avg: [0.613546, 0.243379, 0.233333, 0.125266],
  brands: { FOC: [0.924658, 0.66895, 0.623288, 0.449772] }
};
const CAT_F = { label: CAT_NAME, n_brands: 15, funnel: FUNNEL };

const facts = D.tileFacts(snapshot({ rank: 1, of: 15 }), CAT_F);
assertEqual('there are exactly four tiles', Object.keys(facts).length, 4);
assertEqual('Mental Penetration takes the MPen value', facts.mpen.value, '84%');
assertEqual('and its category average', facts.mpen.catAvg, '56%');
assertEqual('Mental Market Share takes the MMS value', facts.mms.value, '10%');
assertEqual('only Mental Market Share carries a rank', facts.mms.rank.rank, 1);
assert('Mental Penetration carries no manufactured rank', facts.mpen.rank == null);
assert('the bought tile carries no manufactured rank', facts.bt.rank == null);
assert('Share of Category Requirement carries no manufactured rank',
  facts.scr.rank == null);
assertEqual('the bought tile takes the funnel bought_target figure',
  facts.bt.value, '45%');
assertEqual('and its category average', facts.bt.catAvg, '13%');
assertEqual('Share of Category Requirement takes the observed SCR',
  facts.scr.value, '71%');
assertEqual('and its category average', facts.scr.catAvg, '42%');

assertEqual('the bought tile is labelled from the funnel stage label',
  facts.bt.label, 'Bought, past 3 months');
const FUNNEL_6M = JSON.parse(JSON.stringify(FUNNEL));
FUNNEL_6M.stage_labels[3] = 'Past 6 months';
assertEqual('a study with a different window reads its own words',
  D.boughtWindowLabel({ funnel: FUNNEL_6M }), 'Bought, past 6 months');
assertEqual('no funnel means the static label stands',
  D.boughtWindowLabel({}), null);
assertEqual('a funnel with no target stage means the same',
  D.boughtWindowLabel({ funnel: { available: true, stage_keys: ['aware'],
                                   stage_labels: ['Aware'] } }), null);

// A brand with no figure at all gets en dashes, never a zero.
const bare = { name: 'Bare Brand', focal_metrics: [], ma_metrics: [],
               brand_summary: [] };
const bareFacts = D.tileFacts(bare, { label: CAT_NAME });
['mpen', 'mms', 'bt', 'scr'].forEach(function (k) {
  assertEqual('an absent ' + k + ' figure is an en dash',
    bareFacts[k].value, '–');
});

// ---------------------------------------------------------------------------
section('What the numbers say states comparisons rather than diagnoses');
// ---------------------------------------------------------------------------
const above = D.heroHeadline(
  snapshot({ rank: 1, of: 15, name: 'Above Brand' }), CAT_F, CAT_NAME);
assert('it states Mental Penetration against the category average',
  above.headline.indexOf('Mental Penetration is above the category average at 84% against 56%') > 0);
assert('it states the bought share against the category average',
  above.headline.indexOf('the share who bought in the target window is above it at 45% against 13%') > 0);
assert('it states Share of Category Requirement',
  above.headline.indexOf('Share of Category Requirement is above the category average at 71% against 42%') > 0);

const below = D.heroHeadline(
  snapshot({ rank: 12, of: 15, name: 'Below Brand', mpen: '20%', mpenAvg: '56%',
             bt: '4%', btAvg: '13%', scr: '18%', scrAvg: '42%' }),
  CAT_F, CAT_NAME);
assert('a lagging brand is stated flat, not diagnosed',
  below.headline.indexOf('Mental Penetration is below the category average') > 0);
assert('the retired conversion-gap diagnosis is gone',
  below.headline.indexOf('conversion gap') === -1);
assert('the retired punching-above phrasing is gone',
  below.headline.indexOf('Punching above') === -1);

// A leader flag on ma_metrics is reported; nothing recomputes leadership.
const leader = snapshot({ rank: 1, of: 15, name: 'Leader Brand' });
leader.ma_metrics[0].is_leader = true;   // Mental Penetration (MPen)
leader.ma_metrics[2].is_leader = true;   // Mental Market Share (MMS)
const ld = D.heroHeadline(leader, CAT_F, CAT_NAME);
assert('the leadership clause names both measures it leads',
  ld.headline.indexOf('It leads the category on Mental Penetration (MPen) and Mental Market Share (MMS).') > 0);
const noLead = D.heroHeadline(snapshot({ rank: 5, of: 15 }), CAT_F, CAT_NAME);
assert('a brand that leads nothing gets no leadership clause',
  noLead.headline.indexOf('It leads the category') === -1);

// A clause whose figures are missing is dropped, never softened into prose.
const noScr = snapshot({ rank: 3, of: 15 });
noScr.brand_summary = noScr.brand_summary.filter(function (m) {
  return m.key !== 'scr_obs';
});
const ns = D.heroHeadline(noScr, CAT_F, CAT_NAME);
assert('a missing SCR drops its clause',
  ns.headline.indexOf('Share of Category Requirement') === -1);
assert('and the rest of the sentence still stands',
  ns.headline.indexOf('Mental Penetration is above') > 0);

// Word of mouth is reported only when the category collected it.
const wom = snapshot({ rank: 2, of: 15 });
wom.wom = { available: true,
            heard: { net: { label: 'Net heard', value: '+14', cat_avg: '+9' } } };
const wr = D.heroHeadline(wom, CAT_F, CAT_NAME);
assert('net word of mouth is compared when it exists',
  wr.headline.indexOf('Net word of mouth heard is above the category average at +14 against +9') > 0);
assert('and is absent when the category did not collect it',
  above.headline.indexOf('Net word of mouth') === -1);

// ---------------------------------------------------------------------------
section('Opportunities never manufactures a weakness');
// ---------------------------------------------------------------------------
// Shape copied from a generated IPK fixture report: stim_codes, stim_labels,
// cat_avg_pct and a per-brand { focal_pct, decision, advantage_pp }.
function advBlock(deltas, decisions, advantage) {
  const n = deltas.length;
  const avgs = [];
  const fps = [];
  for (let i = 0; i < n; i++) { avgs.push(10); fps.push(10 + deltas[i]); }
  return {
    available: true,
    stim_codes: deltas.map(function (d, i) { return 'S' + (i + 1); }),
    stim_labels: deltas.map(function (d, i) { return 'Item ' + (i + 1); }),
    cat_avg_pct: avgs,
    base_label: 'n=438, total respondents',
    brands: { FOC: { focal_pct: fps,
                     decision: decisions,
                     advantage_pp: advantage } }
  };
}

// The IPK fixture case, measured off the generated report: every one of the
// 15 category entry points and 15 attributes is above the category average
// (cep deltas 1.86 to 7.52, attrs 2.01 to 7.64) and every Mental Advantage
// decision is Maintain. There is no under-indexer and no defend or build.
const ALL_MAINTAIN = new Array(15).fill('Maintain');
const CEP_DELTAS = [1.86, 5.99, 6.91, 7.14, 2.09, 6.45, 3.68, 6.22, 7.14, 5.05,
                    3.46, 4.59, 7.52, 7.14, 5.77];
const ATTR_DELTAS = [2.01, 6.10, 7.00, 7.20, 2.20, 6.50, 3.80, 6.30, 7.10, 5.10,
                     3.50, 4.60, 7.64, 7.20, 5.80];
const CAT_EMPTY = {
  label: CAT_NAME, n_brands: 15, funnel: FUNNEL,
  cep:   advBlock(CEP_DELTAS,  ALL_MAINTAIN, CEP_DELTAS.map(function (d) { return d - 4; })),
  attrs: advBlock(ATTR_DELTAS, ALL_MAINTAIN, ATTR_DELTAS.map(function (d) { return d - 4; }))
};

const empty = D.advantageDecisions(CAT_EMPTY, 'FOC');
assert('both batteries were measured', empty.measured);
assertEqual('no defend item is found', empty.defend.length, 0);
assertEqual('no build item is found', empty.build.length, 0);
assertEqual('all thirty items are counted', empty.n, 30);
assertEqual('and the block names both batteries', empty.what,
  'category entry points and attributes');
assertEqual('the largest lead is the largest arithmetic gap',
  empty.best.label, 'Item 13');
assert('the largest lead uses the gap the Why cards display',
  Math.abs(empty.best.delta - 7.64) < 0.001);
assertEqual('the smallest lead is the smallest arithmetic gap',
  empty.worst.label, 'Item 1');
assert('the smallest lead is still a lead, not a shortfall',
  empty.worst.delta > 0);
assert('the smallest lead uses the gap the Why cards display',
  Math.abs(empty.worst.delta - 1.86) < 0.001);

// A brand that does have defend and build items still gets them.
const decs = ALL_MAINTAIN.slice();
decs[2] = 'Defend'; decs[7] = 'Build';
const advPP = CEP_DELTAS.map(function () { return 0; });
advPP[2] = 8.4; advPP[7] = -6.1;
const CAT_MIXED = {
  label: CAT_NAME, n_brands: 15, funnel: FUNNEL,
  cep: advBlock(CEP_DELTAS, decs, advPP),
  attrs: null
};
const mixed = D.advantageDecisions(CAT_MIXED, 'FOC');
assertEqual('the defend item is picked up', mixed.defend.length, 1);
assertEqual('by its label', mixed.defend[0].label, 'Item 3');
assertEqual('the build item is picked up', mixed.build.length, 1);
assertEqual('by its label', mixed.build[0].label, 'Item 8');
assertEqual('only the measured battery is named', mixed.what,
  'category entry points');

// Nothing measured at all is reported as nothing measured, not as no gaps.
const none = D.advantageDecisions({ label: CAT_NAME }, 'FOC');
assertEqual('an unmeasured category reports measured false', none.measured, false);
assertEqual('with no defend items', none.defend.length, 0);
assertEqual('and no build items', none.build.length, 0);

// A brand absent from the battery is not read as a brand with no gaps.
const absent = D.advantageDecisions(CAT_EMPTY, 'OTHER');
assertEqual('a brand absent from the battery reports measured false',
  absent.measured, false);

// ---------------------------------------------------------------------------
section('the funnel step is read off the funnel the page already draws');
// ---------------------------------------------------------------------------
const drop = D.biggestFunnelDrop(CAT_F, 'FOC');
assert('a step is found', !!drop);
assertEqual('from the stage before the largest fall', drop.from, 'Past 12 months');
assertEqual('to the stage after it', drop.to, 'Past 3 months');
// 0.449772 / 0.623288 = 0.7216117, which is the value .biggest_drop_for_focal()
// returns for this brand on the IPK fixture under the default ratio metric.
assert('and the ratio matches the engine to six places',
  Math.abs(drop.ratio - 0.7216117) < 0.000001);

assertEqual('no funnel means no step', D.biggestFunnelDrop({}, 'FOC'), null);
assertEqual('one stage means no step',
  D.biggestFunnelDrop({ funnel: { available: true, stage_keys: ['aware'],
                                  stage_labels: ['Aware'],
                                  brands: { FOC: [0.9] } } }, 'FOC'), null);
// A zero stage cannot be divided into, and is skipped rather than reported
// as an infinite fall.
const zeroed = D.biggestFunnelDrop({ funnel: {
  available: true,
  stage_keys: ['aware', 'consideration', 'bought_target'],
  stage_labels: ['Aware', 'Prefer', 'Past 3 months'],
  brands: { FOC: [0.5, 0, 0] } } }, 'FOC');
assertEqual('a zero stage is skipped', zeroed.from, 'Aware');
assertEqual('leaving the step that can be computed', zeroed.to, 'Prefer');

// ---------------------------------------------------------------------------
section('no em dash reaches a reader');
// ---------------------------------------------------------------------------
[top, mid, last, nine, above, below, ld, ns, wr].forEach(function (r, i) {
  assert('headline ' + i + ' carries no em dash', r.headline.indexOf('—') === -1);
});

// ---------------------------------------------------------------------------
console.log('\n' + passed + ' passed, ' + failed + ' failed');
process.exit(failed === 0 ? 0 : 1);
