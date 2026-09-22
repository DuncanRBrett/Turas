/**
 * Narrative screens (TR.narrative). The report's Background, Executive summary
 * and any other summary screen, authored in a Word document or in the config's
 * Comments sheet and carried on the island as project.narrative:
 *
 *   [{ id: "executive-summary", title: "Executive summary", blocks: [...] }]
 *
 * The R reader (modules/tabs/lib/crosstabs/narrative_reader.R) owns the shape.
 * Its header lists the block kinds; this file is the ONE place they become
 * HTML. The Report tab cards, the cover, the story card and Present all call
 * blocksHtml, so no surface keeps a paragraph splitter of its own. blocksText
 * is the plain-text projection of the same blocks, for the deck, which cannot
 * take HTML.
 *
 * Everything here is authored text, so every value is escaped and no markup
 * inside a run is honoured. Bold and italic come from the run flags only.
 * Pure: no DOM access, so it unit-tests in node.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var narrative = TR.narrative = {};

  /** Every screen on the island, in document order. [] when none. */
  narrative.screens = function () {
    var s = TR.AGG && TR.AGG.project && TR.AGG.project.narrative;
    return Array.isArray(s) ? s : [];
  };

  /** The screen with this id, or null when the island no longer carries it. */
  narrative.byId = function (id) {
    var list = narrative.screens();
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].id === id) return list[i];
    }
    return null;
  };

  /** A title reduced to lower-case words: "Executive summary : In a
   *  nutshell" -> "executive summary in a nutshell". */
  function titleWords(title) {
    return String(title == null ? "" : title).toLowerCase()
      .replace(/[^a-z0-9]+/g, " ").trim();
  }

  /**
   * The screen the cover opens with, read from the island, never from a pin:
   * the first screen whose title starts with "Executive summary" (case,
   * spacing and punctuation ignored), else the first screen.
   *
   * Why not simply the first screen: a narrative written the natural way opens
   * with its background and method, so the cover would lead with how the
   * study was run rather than what it found. That is true of the Comments
   * fallback (Background, then Executive summary) and of real Word files
   * (SACS 2026 opens "Background and method", then "Executive summary : In a
   * nutshell"). The deck cover has only ever carried the executive summary.
   *
   * @returns {object|null} the screen, or null when there are none
   */
  narrative.coverScreen = function () {
    var list = narrative.screens();
    for (var i = 0; i < list.length; i++) {
      if (/^executive summary( |$)/.test(titleWords(list[i] && list[i].title))) {
        return list[i];
      }
    }
    return list[0] || null;
  };

  function runsOf(block) {
    return Array.isArray(block && block.runs) ? block.runs : [];
  }

  function runsHtml(runs) {
    return runs.map(function (r) {
      var t = fmt.escapeHtml(r && r.text != null ? r.text : "");
      if (r && r.italic) t = "<em>" + t + "</em>";
      if (r && r.bold) t = "<strong>" + t + "</strong>";
      return t;
    }).join("");
  }

  function runsText(runs) {
    return runs.map(function (r) {
      return r && r.text != null ? String(r.text) : "";
    }).join("");
  }

  /**
   * The number each list item shows: null for a bullet, else the number Word
   * shows (item.number, from the R reader, which keeps counting across a
   * paragraph that interrupts the list). An item without one, e.g. from an
   * older island, is counted here the way the nested HTML list would count it:
   * per level, restarting a level under each new parent and when the list type
   * changes. Shared by the HTML list, the plain-text lines and the deck slide,
   * so every surface shows the same numbers.
   *
   * @param {Array} items - a list block's items
   * @returns {Array} one number (or null) per item
   */
  narrative.listNumbers = function (items) {
    var count = [], kind = [];
    return (items || []).map(function (it) {
      var level = Math.max(0, parseInt(it && it.level, 10) || 0);
      var ordered = !!(it && it.ordered);
      count.length = kind.length = Math.min(count.length, level + 1);
      var n = kind[level] === ordered && count[level] ? count[level] + 1 : 1;
      count[level] = n;
      kind[level] = ordered;
      if (!ordered) return null;
      var given = parseInt(it.number, 10);
      if (isFinite(given)) count[level] = given;
      return isFinite(given) ? given : n;
    });
  };

  /**
   * Word list items arrive flat, each with a level and an ordered flag. They
   * nest here: a deeper item opens a list inside the open item, a shallower one
   * closes back out, and a change of type at the same level closes the one list
   * and opens the other. A jump of two levels is read as one, since there is no
   * item for the level in between to hang the list on.
   */
  function listHtml(items) {
    var out = [], stack = [], numbers = narrative.listNumbers(items);
    var open = function (tag) { out.push("<" + tag + ">"); stack.push(tag); };
    (items || []).forEach(function (it, i) {
      var level = Math.max(0, parseInt(it && it.level, 10) || 0);
      var tag = it && it.ordered ? "ol" : "ul";
      if (!stack.length) {
        open(tag);
      } else {
        level = Math.min(level, stack.length);
        if (level === stack.length) {
          open(tag);
        } else {
          while (stack.length > level + 1) out.push("</li></" + stack.pop() + ">");
          out.push("</li>");
          if (stack[stack.length - 1] !== tag) {
            out.push("</" + stack.pop() + ">");
            open(tag);
          }
        }
      }
      // an explicit value, so a list Word kept counting shows 3, not 1
      out.push((numbers[i] === null ? "<li>" : '<li value="' + numbers[i] + '">') +
        runsHtml(runsOf(it)));
    });
    while (stack.length) out.push("</li></" + stack.pop() + ">");
    return out.join("");
  }

  // Only an embedded picture renders. The reader emits nothing else, and a
  // client report must never fetch a picture from somewhere else when opened.
  function imageHtml(b) {
    var src = String(b.src || "");
    if (!/^data:image\/(png|jpeg|gif);base64,/i.test(src)) return "";
    var w = parseInt(b.width, 10), h = parseInt(b.height, 10);
    return '<figure class="nar-fig"><img src="' + fmt.escapeHtml(src) + '" alt="' +
      fmt.escapeHtml(b.alt || "") + '"' +
      (w > 0 && h > 0 ? ' width="' + w + '" height="' + h + '"' : "") +
      "></figure>";
  }

  function tableHtml(b) {
    var rows = Array.isArray(b.rows) ? b.rows : [];
    if (!rows.length) return "";
    return '<table class="nar-table"><tbody>' + rows.map(function (row) {
      return "<tr>" + (Array.isArray(row) ? row : [row]).map(function (cell) {
        return "<td>" + fmt.escapeHtml(cell == null ? "" : cell) + "</td>";
      }).join("") + "</tr>";
    }).join("") + "</tbody></table>";
  }

  function blockHtml(b, lead) {
    if (!b || typeof b !== "object") return "";
    switch (b.type) {
      case "subheading":
        return '<h4 class="nar-sub">' + fmt.escapeHtml(b.text || "") + "</h4>";
      case "paragraph":
        return (lead ? '<p class="nar-lead">' : "<p>") + runsHtml(runsOf(b)) + "</p>";
      case "quote":
        return '<blockquote class="nar-callout">' + runsHtml(runsOf(b)) + "</blockquote>";
      case "list":
        return listHtml(b.items);
      case "image":
        return imageHtml(b);
      case "table":
        return tableHtml(b);
      default:
        return "";   // a kind this renderer does not know renders nothing
    }
  }

  /**
   * A screen's blocks as HTML, in document order.
   *
   * @param {Array} blocks - the screen's blocks
   * @param {object} [opts] - {lead: true} marks the first block as the lead
   *   paragraph when it is one (Present)
   * @returns {string} "" when there is nothing to show
   */
  narrative.blocksHtml = function (blocks, opts) {
    var o = opts || {};
    return (Array.isArray(blocks) ? blocks : []).map(function (b, i) {
      return blockHtml(b, !!o.lead && i === 0);
    }).join("");
  };

  /** A list item as one plain line: "• text", or "3. text" when numbered. */
  function itemLine(it, number) {
    return (number === null ? "• " : number + ". ") + runsText(runsOf(it));
  }

  /**
   * The same blocks as plain lines, for the deck. A paragraph, quote or
   * sub-heading is one line, a list item is a bullet (or numbered) line, and a
   * table row is its cells joined. Pictures carry no words and are left out.
   *
   * @param {Array} blocks - the screen's blocks
   * @returns {string} lines joined with "\n"
   */
  narrative.blocksText = function (blocks) {
    var lines = [];
    (Array.isArray(blocks) ? blocks : []).forEach(function (b) {
      if (!b || typeof b !== "object") return;
      if (b.type === "subheading") lines.push(String(b.text || ""));
      if (b.type === "paragraph" || b.type === "quote") lines.push(runsText(runsOf(b)));
      if (b.type === "list") {
        var numbers = narrative.listNumbers(b.items);
        (b.items || []).forEach(function (it, i) { lines.push(itemLine(it, numbers[i])); });
      }
      if (b.type === "table") {
        (b.rows || []).forEach(function (row) {
          lines.push((Array.isArray(row) ? row : [row]).join(" | "));
        });
      }
    });
    return lines.filter(function (l) { return l.trim(); }).join("\n");
  };

  /**
   * The opening lines of a screen for the deck cover, which has room for a
   * couple of lines only: paragraphs, quotes and list items in document order,
   * as plain text. Sub-headings, tables and pictures are passed over, so a
   * screen that opens with a heading or a table still puts its first words on
   * the cover rather than the heading or a row of cells.
   *
   * @param {Array} blocks - the screen's blocks
   * @param {number} max - how many lines at most
   * @returns {Array} up to max non-empty lines
   */
  narrative.coverLines = function (blocks, max) {
    var lines = [];
    (Array.isArray(blocks) ? blocks : []).forEach(function (b) {
      if (!b || typeof b !== "object") return;
      if (b.type === "paragraph" || b.type === "quote") lines.push(runsText(runsOf(b)));
      if (b.type === "list") {
        var numbers = narrative.listNumbers(b.items);
        (b.items || []).forEach(function (it, i) { lines.push(itemLine(it, numbers[i])); });
      }
    });
    return lines.filter(function (l) { return l.trim(); }).slice(0, max);
  };

  /**
   * A screen laid out for Present: brand title, the first paragraph as the
   * lead, a long list in two columns, callout bands, and any picture beside
   * the text rather than in its flow. The layout itself is CSS on the wrapper's
   * classes; this only sorts the blocks.
   */
  narrative.presentHtml = function (screen) {
    var blocks = Array.isArray(screen && screen.blocks) ? screen.blocks : [];
    var pics = blocks.filter(function (b) { return b && b.type === "image"; });
    var words = blocks.filter(function (b) { return !(b && b.type === "image"); });
    var picsHtml = narrative.blocksHtml(pics);
    var longList = words.some(function (b) {
      return b && b.type === "list" && (b.items || []).length > 6;
    });
    return '<div class="pr-narrative' + (picsHtml ? " has-pic" : "") +
      (longList ? " long-list" : "") + '">' +
      '<h1 class="nar-title">' + fmt.escapeHtml((screen && screen.title) || "") + "</h1>" +
      '<div class="nar-grid"><div class="nar-text">' +
      narrative.blocksHtml(words, { lead: true }) + "</div>" +
      (picsHtml ? '<div class="nar-pics">' + picsHtml + "</div>" : "") +
      "</div></div>";
  };

})(typeof window !== "undefined" ? window : globalThis);
