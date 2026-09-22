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

  /** The screen the cover shows: the first one, whatever it is called. */
  narrative.first = function () {
    return narrative.screens()[0] || null;
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
   * Word list items arrive flat, each with a level and an ordered flag. They
   * nest here: a deeper item opens a list inside the open item, a shallower one
   * closes back out, and a change of type at the same level closes the one list
   * and opens the other. A jump of two levels is read as one, since there is no
   * item for the level in between to hang the list on.
   */
  function listHtml(items) {
    var out = [], stack = [];
    var open = function (tag) { out.push("<" + tag + ">"); stack.push(tag); };
    (items || []).forEach(function (it) {
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
      out.push("<li>" + runsHtml(runsOf(it)));
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

  /**
   * The same blocks as plain lines, for the deck. A paragraph, quote or
   * sub-heading is one line, a list item is a bullet line, and a table row is
   * its cells joined. Pictures carry no words and are left out.
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
        (b.items || []).forEach(function (it) { lines.push("• " + runsText(runsOf(it))); });
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
