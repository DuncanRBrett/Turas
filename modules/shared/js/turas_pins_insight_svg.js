/**
 * TurasPins Shared Library — Insight SVG Rendering
 *
 * Parses insight HTML into structured blocks and renders them as
 * formatted SVG elements for PNG export. Handles headings, bold,
 * italic, bullets, blockquotes, and numbered lists.
 *
 * Depends on: turas_pins_utils.js (loaded first)
 * @namespace TurasPins
 */

/* global TurasPins */

(function() {
  "use strict";

  var NS = "http://www.w3.org/2000/svg";

  /**
   * Parse insight HTML into structured blocks.
   * Each block: {type, runs[], prefix?} where runs: {text, bold, italic}.
   */
  TurasPins._parseInsightHTML = function(html) {
    if (!html || !html.trim()) return [];
    var div = document.createElement("div");
    div.innerHTML = html;
    var blocks = [];

    for (var i = 0; i < div.childNodes.length; i++) {
      var el = div.childNodes[i];
      if (el.nodeType === 3) {
        var t = el.textContent.trim();
        if (t) blocks.push({ type: "para", runs: [{ text: t, bold: false, italic: false }] });
        continue;
      }
      if (el.nodeType !== 1) continue;
      var tag = el.tagName.toLowerCase();

      if (/^h[1-6]$/.test(tag)) {
        blocks.push({ type: "heading", level: parseInt(tag[1]), runs: _extractRuns(el, true, false) });
      } else if (tag === "ul" || tag === "ol") {
        var items = el.querySelectorAll("li");
        for (var j = 0; j < items.length; j++) {
          blocks.push({ type: "bullet", prefix: tag === "ol" ? (j + 1) + ". " : "\u2022 ",
            runs: _extractRuns(items[j], false, false) });
        }
      } else if (tag === "blockquote") {
        blocks.push({ type: "quote", runs: _extractRuns(el, false, false) });
      } else {
        var runs = _extractRuns(el, false, false);
        if (runs.length > 0) blocks.push({ type: "para", runs: runs });
      }
    }
    return blocks;
  };

  /** Extract text runs with formatting from an HTML element */
  function _extractRuns(node, bold, italic) {
    var runs = [];
    (function walk(n, b, it) {
      if (n.nodeType === 3) {
        if (n.textContent) runs.push({ text: n.textContent, bold: b, italic: it });
        return;
      }
      if (n.nodeType !== 1) return;
      var tag = n.tagName.toLowerCase();
      var nb = b, ni = it;
      if (tag === "strong" || tag === "b") nb = true;
      if (tag === "em" || tag === "i") ni = true;
      if (tag === "br") { runs.push({ text: "\n", bold: false, italic: false }); return; }
      for (var i = 0; i < n.childNodes.length; i++) walk(n.childNodes[i], nb, ni);
    })(node, bold, italic);
    return runs;
  }

  /**
   * Render parsed insight blocks as SVG elements.
   * @returns {{ element: SVGGElement, height: number }}
   */
  TurasPins._renderInsightSVG = function(blocks, x, startY, maxWidth, charWidth) {
    var g = document.createElementNS(NS, "g");
    var y = startY;
    var lineH = 17;

    for (var b = 0; b < blocks.length; b++) {
      var block = blocks[b];
      var indent = 0, fontSize = 13;
      var isHeading = block.type === "heading";
      var isQuote = block.type === "quote";

      if (isHeading) { fontSize = block.level <= 2 ? 15 : 14; if (b > 0) y += 6; }
      if (block.type === "bullet") indent = 16;
      if (isQuote) indent = 16;

      var annot = _buildAnnotated(block, isHeading, isQuote);
      if (annot.length === 0) continue;

      var fullText = "";
      for (var ci = 0; ci < annot.length; ci++) fullText += annot[ci].ch;

      var effectiveW = maxWidth - indent;
      var lineRanges = _wordWrap(fullText, effectiveW, charWidth);

      for (var li = 0; li < lineRanges.length; li++) {
        var lr = lineRanges[li];
        var ls = lr.s, le = lr.e;
        while (ls < le && fullText[ls] === " ") ls++;
        while (le > ls && fullText[le - 1] === " ") le--;
        if (ls >= le) continue;

        var textEl = document.createElementNS(NS, "text");
        textEl.setAttribute("x", x + indent);
        textEl.setAttribute("y", y);
        textEl.setAttribute("fill", isQuote ? "#64748b" : "#1a2744");
        textEl.setAttribute("font-size", fontSize);
        _appendTspans(textEl, annot, fullText, ls, le);
        g.appendChild(textEl);
        y += lineH;
      }

      if (block.type === "bullet" && b < blocks.length - 1 && blocks[b + 1].type !== "bullet") y += 4;
      else if (block.type !== "bullet") y += 4;
    }
    return { element: g, height: y - startY };
  };

  /** Build annotated character array with whitespace collapsed */
  function _buildAnnotated(block, isHeading, isQuote) {
    var annot = [];
    if (block.prefix) {
      for (var c = 0; c < block.prefix.length; c++)
        annot.push({ ch: block.prefix[c], bold: isHeading, italic: false });
    }
    for (var r = 0; r < block.runs.length; r++) {
      var run = block.runs[r];
      for (var c2 = 0; c2 < run.text.length; c2++)
        annot.push({ ch: run.text[c2], bold: run.bold || isHeading, italic: run.italic || isQuote });
    }
    // Collapse whitespace
    var out = [], lastSp = true;
    for (var i = 0; i < annot.length; i++) {
      if (/\s/.test(annot[i].ch)) { if (!lastSp) { out.push({ ch: " ", bold: annot[i].bold, italic: annot[i].italic }); lastSp = true; } }
      else { out.push(annot[i]); lastSp = false; }
    }
    while (out.length > 0 && out[out.length - 1].ch === " ") out.pop();
    return out;
  }

  /** Word wrap into line ranges */
  function _wordWrap(text, maxWidth, charWidth) {
    var maxChars = Math.floor(maxWidth / charWidth);
    var bounds = [], ws = -1;
    for (var i = 0; i <= text.length; i++) {
      if (i === text.length || text[i] === " ") { if (ws >= 0) bounds.push({ s: ws, e: i }); ws = -1; }
      else { if (ws < 0) ws = i; }
    }
    var ranges = [], lStart = 0, lLen = 0;
    for (var w = 0; w < bounds.length; w++) {
      var wb = bounds[w], wLen = wb.e - wb.s;
      var needed = lLen === 0 ? wLen : lLen + 1 + wLen;
      if (needed > maxChars && lLen > 0) { ranges.push({ s: lStart, e: wb.s }); lStart = wb.s; lLen = wLen; }
      else { lLen = needed; }
    }
    if (lStart < text.length) ranges.push({ s: lStart, e: text.length });
    return ranges;
  }

  /** Append tspan segments at formatting boundaries */
  function _appendTspans(textEl, annot, text, ls, le) {
    var segStart = ls;
    for (var ci = ls; ci <= le; ci++) {
      var atEnd = ci === le;
      var change = !atEnd && ci > ls &&
        (annot[ci].bold !== annot[ci - 1].bold || annot[ci].italic !== annot[ci - 1].italic);
      if (change || atEnd) {
        var seg = text.substring(segStart, ci);
        if (seg) {
          var ts = document.createElementNS(NS, "tspan");
          if (annot[segStart].bold) ts.setAttribute("font-weight", "700");
          if (annot[segStart].italic) ts.setAttribute("font-style", "italic");
          ts.textContent = seg;
          textEl.appendChild(ts);
        }
        segStart = ci;
      }
    }
  }

})();
