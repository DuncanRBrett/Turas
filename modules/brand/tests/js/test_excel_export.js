// =============================================================================
// Tests for the shared Excel workbook builder in brand_report.js
//
// Run from the Turas project root with:
//   node modules/brand/tests/js/test_excel_export.js
//
// Every destination toolbar and every section export button in the brand
// report goes through _brTablesToWorkbook. It walks the rendered table and
// turns each cell into a workbook cell, so anything the panels put inside a
// cell for the reader's eye reaches the workbook unless the builder is told
// what it is. Three defects came from that, found on 7 September 2026 by
// opening an exported workbook rather than only inspecting it:
//
//   * a category average of 61% with a 51 to 72 range rail beneath it was
//     written as the single number 615172;
//   * labels were coerced to numbers, because parseFloat("1/9") is 1;
//   * rows the reader's brand filter had hidden were in the file anyway.
//
// The tests below are known-answer tests against a hand-built stub DOM shaped
// exactly like the markup 02_ma_panel_table.R and 02_ma_panel_chart.R write.
// No test framework, no jsdom in this checkout.
// =============================================================================

'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

/* -------------------------------------------------------------------------- */
/* A stub DOM, big enough for the builder and no bigger                         */
/* -------------------------------------------------------------------------- */
// Selector support: comma-separated simple selectors, each one a tag name, a
// ".class", or "tag.class". That is everything the builder asks for.

function parseSelector(sel) {
  return String(sel).split(',').map(function (part) {
    const s = part.trim();
    // [name="value"], which is how _brExportPanel looks for an anchor.
    const attrVal = s.match(/^\[([^\]=]+)=["']?([^\]"']*)["']?\]$/);
    if (attrVal) return { tag: null, cls: null, attr: attrVal[1],
                          val: attrVal[2] };
    const attr = s.match(/^\[([^\]=]+)\]$/);
    if (attr) return { tag: null, cls: null, attr: attr[1] };
    const dot = s.indexOf('.');
    if (dot === -1) return { tag: s.toLowerCase(), cls: null };
    if (dot === 0) return { tag: null, cls: s.slice(1) };
    return { tag: s.slice(0, dot).toLowerCase(), cls: s.slice(dot + 1) };
  });
}

class El {
  constructor(tag, opts) {
    opts = opts || {};
    this.tagName = tag.toUpperCase();
    this.className = opts.cls || '';
    this.attrs = opts.attrs || {};
    this.style = Object.assign({ display: '', visibility: '' }, opts.style || {});
    this.text = opts.text || '';
    this.children = [];
    this.parentNode = null;
    (opts.children || []).forEach(this.append, this);
  }
  append(child) {
    child.parentNode = this;
    this.children.push(child);
    return this;
  }
  get classList() {
    const cls = this.className.split(/\s+/).filter(Boolean);
    return { contains: function (c) { return cls.indexOf(c) !== -1; } };
  }
  getAttribute(name) {
    return Object.prototype.hasOwnProperty.call(this.attrs, name)
      ? String(this.attrs[name]) : null;
  }
  hasAttribute(name) {
    return Object.prototype.hasOwnProperty.call(this.attrs, name);
  }
  get nodeType() { return 1; }
  // The builder walks childNodes and asks each one its nodeType, exactly as
  // it does in the browser. A leaf with text carries one text node.
  get childNodes() {
    if (this.children.length) return this.children;
    if (this.text === '') return [];
    return [{ nodeType: 3, nodeValue: this.text }];
  }
  get textContent() {
    if (!this.children.length) return this.text;
    return this.children.map(function (c) { return c.textContent; }).join('');
  }
  matches(sel) {
    const self = this;
    return parseSelector(sel).some(function (p) {
      if (p.attr) {
        if (!self.hasAttribute(p.attr)) return false;
        return p.val === undefined || self.getAttribute(p.attr) === p.val;
      }
      if (p.tag && self.tagName !== p.tag.toUpperCase()) return false;
      if (p.cls && !self.classList.contains(p.cls)) return false;
      return true;
    });
  }
  descendants() {
    let out = [];
    this.children.forEach(function (c) {
      out.push(c);
      out = out.concat(c.descendants());
    });
    return out;
  }
  querySelectorAll(sel) {
    return this.descendants().filter(function (d) { return d.matches(sel); });
  }
  querySelector(sel) {
    return this.querySelectorAll(sel)[0] || null;
  }
  closest(sel) {
    let n = this;
    while (n) {
      if (n.matches && n.matches(sel)) return n;
      n = n.parentNode;
    }
    return null;
  }
}

function e(tag, opts) { return new El(tag, opts); }

// The report reads the element's OWN computed display, never an ancestor's.
// The stub mirrors that: an inline display:none on the element itself is the
// only way a node is hidden here, exactly as getComputedStyle reports it for
// a node whose stylesheet or inline style hides it.
const INLINE_TAGS = { SPAN: 1, A: 1, EM: 1, STRONG: 1, B: 1, I: 1 };
global.getComputedStyle = function (el) {
  return {
    display: el.style.display ||
             (INLINE_TAGS[el.tagName] ? 'inline' : 'block'),
    visibility: el.style.visibility || 'visible'
  };
};

// A document with one installable tree. Section 10 needs it: _brExportPanel
// resolves an anchor name through getElementById and querySelectorAll, and
// the bug it fixes is about which of several matches is chosen, so the stub
// has to be able to hold more than one.
let docRoot = e('div');
const doc = {
  readyState: 'complete',
  setRoot: function (el) { docRoot = el; },
  querySelector: function (sel) { return docRoot.querySelector(sel); },
  querySelectorAll: function (sel) { return docRoot.querySelectorAll(sel); },
  getElementById: function (id) {
    return docRoot.descendants().filter(function (d) {
      return d.getAttribute('id') === id;
    })[0] || null;
  },
  addEventListener: function () {},
  createElement: function (t) { return e(t); },
  body: e('body'),
  documentElement: e('html')
};
// Enough of the download path to see what a button would have written. The
// workbook ends up in downloads[]; nothing leaves the process.
const downloads = [];
const alerts = [];
global.Blob = function (parts) { this.parts = parts.join(''); };
global.URL = {
  createObjectURL: function (b) { downloads.push(b.parts); return 'blob:x'; },
  revokeObjectURL: function () {}
};
global.alert = function (msg) { alerts.push(String(msg)); };
El.prototype.click = function () {};

global.document = doc;
global.window = global;
if (typeof global.window.addEventListener !== 'function') {
  global.window.addEventListener = function () {};
}

const jsPath = path.join(
  __dirname, '../../lib/html_report/js/brand_report.js'
);
vm.runInThisContext(fs.readFileSync(jsPath, 'utf8'));

const build = global.window._brTablesToWorkbook;

/* -------------------------------------------------------------------------- */
/* Minimal runner                                                              */
/* -------------------------------------------------------------------------- */

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

/* -------------------------------------------------------------------------- */
/* Helpers that read the XML back                                              */
/* -------------------------------------------------------------------------- */

// Every <Row> in the first worksheet, as arrays of { type, value } strings.
function rowsOf(xml, sheetIdx) {
  const sheets = xml.split('<Worksheet ').slice(1);
  const sheet = sheets[sheetIdx || 0] || '';
  const rows = sheet.split('<Row>').slice(1);
  return rows.map(function (r) {
    const cells = [];
    const re = /<Cell><Data ss:Type="([^"]+)">([\s\S]*?)<\/Data><\/Cell>/g;
    let m;
    while ((m = re.exec(r)) !== null) cells.push({ type: m[1], value: m[2] });
    return cells;
  });
}

function values(row) { return (row || []).map(function (c) { return c.value; }); }
function types(row) { return (row || []).map(function (c) { return c.type; }); }

// A missing cell must fail an assertion, not throw and hide the rest.
const MISSING = { type: '(no such cell)', value: '(no such cell)' };
function at(rows, r, c) {
  const row = rows[r];
  if (!row) return MISSING;
  if (c === undefined) return row;
  return row[c] || MISSING;
}

const DASH = '–';

/* -------------------------------------------------------------------------- */
/* Fixtures shaped like the real panel markup                                  */
/* -------------------------------------------------------------------------- */

// One category-average cell exactly as .ma_catavg_cell_html writes it:
// the figure in a .ct-val, then the rail, then the two bounds.
function catAvgCell(disp, lo, hi, ciTitle) {
  return e('td', {
    cls: 'ct-td ct-data-col ma-td-catavg ma-td-catavg-ci',
    attrs: { 'data-ma-brand': '__avg__' },
    children: [
      // .ma-td-catavg.ma-td-catavg-ci .ct-val { display: block } in
      // 02_ma_panel_styling.R
      e('span', { cls: 'ct-val', style: { display: 'block' }, text: disp }),
      e('div', {
        cls: 'ma-ci-bar-wrap',
        attrs: { title: (ciTitle || '95% CI') + ': ' + lo + ' ' + DASH + ' ' + hi },
        children: [
          e('div', { cls: 'ma-ci-bar-range' }),
          e('div', { cls: 'ma-ci-bar-tick' })
        ]
      }),
      e('div', {
        cls: 'ma-ci-limits',
        children: [e('span', { text: lo }), e('span', { text: hi })]
      })
    ]
  });
}

// A brand data cell: the figure, then a count annotation the stylesheet
// hides until the reader turns "Show count" on.
function pctCell(disp, count, opts) {
  opts = opts || {};
  return e('td', {
    cls: 'ct-td ct-data-col ma-heatmap-cell',
    attrs: { 'data-ma-brand': opts.brand || 'B1' },
    children: [
      e('span', { cls: 'ct-val ma-pct-primary', text: disp }),
      // .ma-n-primary is display:none until .ma-show-counts is on, and
      // display:block after it.
      e('span', {
        cls: 'ct-freq ma-n-primary',
        style: { display: opts.countsShown ? 'block' : 'none' },
        text: count
      })
    ]
  });
}

function labelCell(text) {
  return e('td', { cls: 'ct-td ct-label-col', text: text });
}

function headerCell(text) {
  return e('th', {
    cls: 'ct-th',
    children: [
      e('span', { cls: 'ct-header-text', text: text }),
      e('span', { cls: 'ct-sort-indicator ma-sort-btn', text: '⇅' })
    ]
  });
}

function row(cls, cells, style) {
  return e('tr', { cls: cls || '', style: style || {}, children: cells });
}

function table(rows) {
  return e('table', { cls: 'br-table', children: rows });
}

/* -------------------------------------------------------------------------- */
/* 1. The 615172 cell                                                          */
/* -------------------------------------------------------------------------- */
// The defect that started this: 61% displayed with a 51 to 72 rail beneath,
// written into one cell as 615172. The figure and the bounds are three
// numbers, and the workbook must not run them together.

console.log('\n1. A category average with a range rail beneath it');
{
  const t = table([
    row('', [headerCell('Brand'), headerCell('Cat avg')]),
    row('', [labelCell('Ina Paarman’s'), pctCell('58%', 'n=350')]),
    row('ma-row-avg', [labelCell('Category average'),
                       catAvgCell('61%', '51%', '72%')])
  ]);
  const xml = build([t], 'test');
  const rows = rowsOf(xml);

  assert('no cell anywhere carries the concatenated 615172',
         xml.indexOf('615172') === -1);
  assert('and no cell carries the raw concatenation either',
         xml.indexOf('61%51%72%') === -1);

  const ar = rows.length - 1;
  assertEqual('the category average cell reads 61', at(rows, ar, 1).value, '61');
  assertEqual('and is typed as a number', at(rows, ar, 1).type, 'Number');
  assertEqual('its label survives as a label',
              at(rows, ar, 0).value, 'Category average');
  assertEqual('and is typed as a string', at(rows, ar, 0).type, 'String');

  // The rail is a real measurement on the page, so it keeps its own cells
  // rather than being dropped. One ranged column, several rows: the extras
  // are columns beside the figure.
  assertEqual('the range low sits in its own cell', at(rows, ar, 2).value, '51');
  assertEqual('the range high sits in its own cell', at(rows, ar, 3).value, '72');
  assertEqual('the range low is a number', at(rows, ar, 2).type, 'Number');
  assertEqual('the range high is a number', at(rows, ar, 3).type, 'Number');

  assertEqual('the header names the range column from the rail’s own title',
              at(rows, 0, 2).value, 'Cat avg (95% CI low)');
  assertEqual('and the high column likewise',
              at(rows, 0, 3).value, 'Cat avg (95% CI high)');
  assertEqual('the header keeps its text and loses the sort control',
              at(rows, 0, 1).value, 'Cat avg');

  // A row with no range in a flagged column gets an en dash, not a blank
  // and not "n/a".
  assertEqual('a row with no range gets an en dash for the low column',
              at(rows, 1, 2).value, DASH);
  assertEqual('and for the high column', at(rows, 1, 3).value, DASH);
  assertEqual('every row has the same number of cells',
              rows.every(function (r) { return r.length === 4; }), true);
}

/* -------------------------------------------------------------------------- */
/* 2. Labels stay labels                                                       */
/* -------------------------------------------------------------------------- */
// parseFloat is lenient: it reads a leading numeric prefix and ignores the
// rest. "1/9" became 1 and "5 Roses" would become 5. A cell is a number only
// when the whole of it is one.

console.log('2. Labels are not coerced to numbers');
{
  const t = table([
    row('', [headerCell('Brand'), headerCell('Categories'), headerCell('Share')]),
    row('', [labelCell('5 Roses'),
             e('td', { cls: 'ct-td', children: [
               e('span', { cls: 'pf-fp-cats-num', text: '1' }),
               e('span', { cls: 'pf-fp-cats-of', text: '/9' })
             ] }),
             pctCell('12%', 'n=88')]),
    row('', [labelCell('2026 Wave'),
             e('td', { cls: 'ct-td', text: '3 of 9' }),
             e('td', { cls: 'ct-td', text: '1,234' })]),
    row('', [labelCell('Not asked'),
             e('td', { cls: 'ct-td', text: DASH }),
             e('td', { cls: 'ct-td', text: '-4.5%' })])
  ]);
  const rows = rowsOf(build([t], 'test'));

  assertEqual('a brand name beginning with a digit stays a string',
              types(rows[1])[0], 'String');
  assertEqual('and keeps its whole name', values(rows[1])[0], '5 Roses');
  assertEqual('"1/9" is not the number 1', types(rows[1])[1], 'String');
  assertEqual('and keeps its text', values(rows[1])[1], '1/9');
  assertEqual('a percentage is still a number', types(rows[1])[2], 'Number');
  assertEqual('with the sign stripped', values(rows[1])[2], '12');

  assertEqual('a label with a leading year stays a string',
              types(rows[2])[0], 'String');
  assertEqual('and keeps its whole text', values(rows[2])[0], '2026 Wave');
  assertEqual('"3 of 9" stays a string', types(rows[2])[1], 'String');
  assertEqual('a thousands-separated integer is a number',
              types(rows[2])[2], 'Number');
  assertEqual('and loses the separator', values(rows[2])[2], '1234');

  assertEqual('an en dash stays an en dash', values(rows[3])[1], DASH);
  assertEqual('and is a string', types(rows[3])[1], 'String');
  assertEqual('a negative percentage is a number', types(rows[3])[2], 'Number');
  assertEqual('with its sign kept', values(rows[3])[2], '-4.5');
}

/* -------------------------------------------------------------------------- */
/* 3. Hidden rows and hidden columns                                           */
/* -------------------------------------------------------------------------- */
// The reader's brand filter hides a row with style.display = "none". The
// portfolio footprint hides a column the same way, header cell and body cells
// together. A workbook that carries either is not the view it was taken from.

console.log('3. What the reader filtered out stays out');
{
  const t = table([
    row('', [headerCell('Brand'), headerCell('Awareness'),
             e('th', { cls: 'ct-th', style: { display: 'none' },
                       text: 'Dropped' })]),
    row('', [labelCell('Shown brand'), pctCell('44%', 'n=100'),
             e('td', { cls: 'ct-td', style: { display: 'none' }, text: '99%' })]),
    row('', [labelCell('Hidden brand'), pctCell('33%', 'n=90'),
             e('td', { cls: 'ct-td', style: { display: 'none' }, text: '98%' })],
        { display: 'none' })
  ]);
  const xml = build([t], 'test');
  const rows = rowsOf(xml);

  assert('a row the brand filter hid is not in the workbook',
         xml.indexOf('Hidden brand') === -1);
  assert('nor is its figure', xml.indexOf('33') === -1);
  assertEqual('the visible rows are all that is written', rows.length, 2);
  assert('a hidden column is not in the workbook',
         xml.indexOf('Dropped') === -1 && xml.indexOf('99') === -1);
  assertEqual('so each row is two cells wide', at(rows, 1).length, 2);
  assertEqual('and the visible brand is there',
              values(rows[1])[0], 'Shown brand');
}

/* -------------------------------------------------------------------------- */
/* 4. Annotations the stylesheet hides                                         */
/* -------------------------------------------------------------------------- */
// The count under each figure is display:none until the reader turns counts
// on. textContent reads it regardless, which is how "10%" became "10%995 /
// 9,525". The builder asks what is visible.

console.log('4. In-cell annotations follow their own visibility');
{
  const off = table([
    row('', [labelCell('Brand A'), pctCell('10%', 'n=995 / 9,525')])
  ]);
  const rowsOff = rowsOf(build([off], 'test'));
  assertEqual('a hidden count does not join the figure',
              values(rowsOff[0])[1], '10');
  assertEqual('and the figure is still a number',
              types(rowsOff[0])[1], 'Number');

  const on = table([
    row('', [labelCell('Brand A'),
             pctCell('10%', 'n=995 / 9,525', { countsShown: true })])
  ]);
  const rowsOn = rowsOf(build([on], 'test'));
  assertEqual('a count the reader turned on is not lost',
              values(rowsOn[0])[1], '10% n=995 / 9,525');
  assertEqual('and the cell is then a string',
              types(rowsOn[0])[1], 'String');
}

/* -------------------------------------------------------------------------- */
/* 5. A range that runs along a row, not down a column                         */
/* -------------------------------------------------------------------------- */
// The Metrics table puts the category average in a ROW, with a rail in every
// metric column. Two extra columns per metric would leave every brand row
// carrying en dashes in most of them, so the extras go underneath instead.

console.log('5. A row-shaped range gets rows, not columns');
{
  const t = table([
    row('', [headerCell('Brand'), headerCell('MMS'), headerCell('MPen'),
             headerCell('NS')]),
    row('', [labelCell('Ina Paarman’s'), pctCell('12%', 'n=1'),
             pctCell('56%', 'n=2'), pctCell('2.7', 'n=3')]),
    row('ma-metrics-cat-avg', [
      labelCell('Category average'),
      catAvgCell('7%', '5%', '8%'),
      catAvgCell('56%', '47%', '65%'),
      catAvgCell('2.58', '2.52', '2.63')
    ])
  ]);
  const rows = rowsOf(build([t], 'test'));

  assertEqual('the table keeps its four columns',
              rows.every(function (r) { return r.length === 4; }), true);
  assertEqual('five rows: header, brand, average, low, high', rows.length, 5);

  assertEqual('the average row carries the figures only',
              values(rows[2]).join('|'), 'Category average|7|56|2.58');
  assertEqual('the low row is labelled from the row it belongs to',
              values(rows[3])[0], 'Category average (95% CI low)');
  assertEqual('and carries the lower bounds',
              values(rows[3]).slice(1).join('|'), '5|47|2.52');
  assertEqual('the high row likewise',
              values(rows[4])[0], 'Category average (95% CI high)');
  assertEqual('and carries the upper bounds',
              values(rows[4]).slice(1).join('|'), '8|65|2.63');
  assertEqual('bounds are numbers', types(rows[3]).slice(1).join('|'),
              'Number|Number|Number');
}

/* -------------------------------------------------------------------------- */
/* 6. A rail whose title is not a confidence interval                          */
/* -------------------------------------------------------------------------- */
// Category Buying reuses the rail for one standard deviation across brands.
// Calling that a CI in the workbook would be a fabricated statistic, so the
// name comes from the rail's own title.

console.log('6. The range is named by what the page calls it');
{
  const t = table([
    row('', [headerCell('Measure'), headerCell('Cat avg')]),
    row('', [labelCell('Depth of purchase'),
             catAvgCell('10%', '8%', '12%',
                        '±1 SD across brands')])
  ]);
  const rows = rowsOf(build([t], 'test'));
  assertEqual('the column is named from the rail title',
              values(rows[0])[2], 'Cat avg (±1 SD across brands low)');
  assertEqual('and the high column too',
              values(rows[0])[3], 'Cat avg (±1 SD across brands high)');
}

/* -------------------------------------------------------------------------- */
/* 7. Sort chrome and adjacent labels                                          */
/* -------------------------------------------------------------------------- */
// initTableSort appends an arrow to a header's text and the panels put a
// sort button inside it. Neither belongs in a workbook. Two adjacent label
// spans must not run their words together.

console.log('7. Chrome is dropped and stacked labels keep a space');
{
  const t = table([
    row('', [e('th', { cls: 'ct-th', text: 'Awareness ▲' }),
             headerCell('Consideration'),
             e('th', { cls: 'ct-th', children: [
               e('span', { cls: 'ct-header-text', text: 'Preference' }),
               e('button', { cls: 'ma-sort-btn', text: 'sort' })
             ] })]),
    // .demo-opt-name and .demo-opt-role are both display:block in
    // 11_demographics_panel.R; .pf-fp-cats-num and .pf-fp-cats-of are plain
    // inline spans with nothing between them.
    row('', [e('td', { cls: 'demo-opt-label', children: [
               e('span', { cls: 'demo-opt-name', style: { display: 'block' },
                           text: 'Prefer not to say' }),
               e('span', { cls: 'demo-opt-role', style: { display: 'block' },
                           text: 'buyer' })
             ] }),
             e('td', { cls: 'ct-td', children: [
               e('span', { cls: 'pf-fp-cats-num', text: '1' }),
               e('span', { cls: 'pf-fp-cats-of', text: '/9' })
             ] }),
             labelCell('x')])
  ]);
  const rows = rowsOf(build([t], 'test'));
  assertEqual('a sort arrow is stripped', values(rows[0])[0], 'Awareness');
  assertEqual('a sort indicator span is stripped',
              values(rows[0])[1], 'Consideration');
  assertEqual('a sort button is stripped', values(rows[0])[2], 'Preference');
  assertEqual('two stacked labels are separated',
              values(rows[1])[0], 'Prefer not to say buyer');
  assertEqual('but a fraction on one line is not broken',
              values(rows[1])[1], '1/9');
}

// A FOCAL badge is an inline-block pill with a left margin, drawn as its own
// token. Running it into the brand name gave "Ina Paarman's KitchenFOCAL".
{
  const t = table([
    row('', [e('td', { cls: 'ct-td ct-label-col', children: [
               e('span', { text: 'Ina Paarman’s Kitchen' }),
               e('span', { cls: 'ma-focal-badge',
                           style: { display: 'inline-block' },
                           text: 'FOCAL' })
             ] })])
  ]);
  const rows = rowsOf(build([t], 'test'));
  assertEqual('a focal badge is a token of its own',
              values(rows[0])[0], 'Ina Paarman’s Kitchen FOCAL');
}

/* -------------------------------------------------------------------------- */
/* 8. Significance markers                                                     */
/* -------------------------------------------------------------------------- */
// A reader can turn significance markers on for a destination. Four of the
// six classes draw an arrow and one draws an asterisk. Before this, the
// arrows were dropped by the glyph strip and the asterisk was not, so the
// same table exported numbers in one column and text in the next. All six
// are chrome, and a figure stays a figure whether it is marked or not.

console.log('8. A significance marker does not stop a figure being a figure');
{
  function marked(disp, cls, glyph) {
    return e('td', { cls: 'ct-td ct-data-col', children: [
      e('span', { cls: 'ct-val', text: disp }),
      // .ma-sig is display:inline-block in 02_ma_panel_styling.R, and the
      // advantage marker computes to inline-block in the report too, so an
      // untreated marker would be pushed off with a space of its own.
      e('span', { cls: cls, style: { display: 'inline-block' }, text: glyph })
    ] });
  }
  const t = table([
    row('', [headerCell('Stimulus'), headerCell('MA score'),
             headerCell('Awareness'), headerCell('Attitude')]),
    row('', [labelCell('When I want bold flavour'),
             marked('+9.4', 'ma-fv-sig', '*'),
             marked('62%', 'ma-sig ma-sig-up', '↑'),
             marked('12%', 'ct-sig fn-sig-down', '▼')]),
    // The reader has significance off, so the markers are display:none and
    // never reach the cell whatever the class list says.
    row('', [labelCell('When I am cooking midweek'),
             e('td', { cls: 'ct-td ct-data-col', children: [
               e('span', { cls: 'ct-val', text: '+7.3' }),
               e('span', { cls: 'ma-fv-sig', style: { display: 'none' },
                           text: '*' })
             ] }),
             pctCell('58%', 'n=4'), pctCell('9%', 'n=5')])
  ]);
  const rows = rowsOf(build([t], 'test'));

  assertEqual('an asterisk-marked figure is still a number',
              types(rows[1])[1], 'Number');
  assertEqual('and carries the figure alone', values(rows[1])[1], '9.4');
  assertEqual('an up-arrow-marked figure is still a number',
              types(rows[1])[2], 'Number');
  assertEqual('and carries the figure alone', values(rows[1])[2], '62');
  assertEqual('a down-triangle-marked figure is still a number',
              types(rows[1])[3], 'Number');
  assertEqual('and carries the figure alone', values(rows[1])[3], '12');
  assertEqual('a marker the reader has switched off changes nothing',
              values(rows[2])[1], '7.3');
  assertEqual('the whole marked row is numeric',
              types(rows[1]).slice(1).join('|'), 'Number|Number|Number');
}

/* -------------------------------------------------------------------------- */
/* 9. Sheet naming still works                                                 */
/* -------------------------------------------------------------------------- */

console.log('9. Sheet naming is unchanged');
{
  const t1 = table([row('', [labelCell('a')])]);
  const t2 = table([row('', [labelCell('b')])]);
  const host = e('div', { cls: 'wrap', attrs: { 'data-section': 'ma-metrics' },
                          children: [t1] });
  const xml = build([host.querySelector('table'), t2], 'fallback');
  assert('a table under an anchor is named for it',
         xml.indexOf('ss:Name="ma-metrics"') !== -1);
  assert('an unanchored table falls back to the given name',
         xml.indexOf('ss:Name="fallback_1"') !== -1);
}

/* -------------------------------------------------------------------------- */
/* 10. Which element a section anchor means                                    */
/* -------------------------------------------------------------------------- */
// data-section names the pin button and the insight box as well as the panel,
// because all three are addressed by the same anchor. Taking the first match
// in document order gave the Portfolio sub-tabs their own pin button, which
// holds no table, so all four of their Excel buttons said "There is no table
// on this section to export" while the sub-tab beneath them held one. Driving
// the real report confirmed it: four alerts, no workbook.

console.log('10. A section anchor resolves to the element that has the table');
{
  const panelTable = table([
    row('', [headerCell('Brand'), headerCell('Categories')]),
    row('', [labelCell('5 Roses'),
             e('td', { cls: 'ct-td', children: [
               e('span', { cls: 'pf-fp-cats-num', text: '1' }),
               e('span', { cls: 'pf-fp-cats-of', text: '/9' })
             ] })])
  ]);
  // The pin button comes first in the document, exactly as the toolbar
  // renders it inside the sub-tab.
  const subtab = e('div', {
    cls: 'pf-subtab', attrs: { id: 'pf-subtab-footprint' },
    children: [
      e('div', { cls: 'br-section-toolbar', children: [
        e('button', { cls: 'br-pin-btn',
                      attrs: { 'data-section': 'pf-footprint' }, text: 'pin' })
      ] }),
      panelTable
    ]
  });
  doc.setRoot(e('div', { children: [subtab] }));
  downloads.length = 0;
  alerts.length = 0;
  window._brExportPanel('pf-footprint');

  assertEqual('the button exports rather than refusing', alerts.length, 0);
  assertEqual('and a workbook is written', downloads.length, 1);
  const rows = rowsOf(downloads[0] || '');
  assertEqual('the panel table is what it took', rows.length, 2);
  assertEqual('with the brand name intact', values(rows[1])[0], '5 Roses');
  assertEqual('and the fraction still a fraction', values(rows[1])[1], '1/9');

  // A section whose anchor genuinely has no table still says so, rather
  // than reaching sideways for a neighbour's numbers.
  doc.setRoot(e('div', { children: [
    e('div', { cls: 'br-element-section', attrs: { id: 'section-empty-one' },
               children: [e('p', { text: 'no table here' })] }),
    e('div', { cls: 'other', children: [
      table([row('', [labelCell('not mine')])])
    ] })
  ] }));
  downloads.length = 0;
  alerts.length = 0;
  window._brExportPanel('empty-one');
  assertEqual('an empty section writes nothing', downloads.length, 0);
  assertEqual('and says so once', alerts.length, 1);
}

/* -------------------------------------------------------------------------- */

console.log('\n' + passed + ' passed, ' + failed + ' failed');
process.exit(failed === 0 ? 0 : 1);
