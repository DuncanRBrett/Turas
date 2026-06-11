/**
 * Low-level SVG string builders + scale helpers. Pure string output: charts
 * carry literal colours (no CSS variables), so the same string renders in
 * the page, rasterises to PNG, and unit-tests in node without a DOM.
 */
(function (global) {
  "use strict";
  var TR = global.TR;
  var esc = TR.fmt.escapeHtml;

  var svg = TR.svg = {};

  /**
   * Build an SVG element string.
   * @param {string} name - tag name.
   * @param {object} attrs - attributes (null/undefined/false skipped).
   * @param {string|string[]} [children] - inner content; omit to self-close.
   */
  svg.el = function (name, attrs, children) {
    var out = "<" + name;
    Object.keys(attrs || {}).forEach(function (k) {
      var v = attrs[k];
      if (v === null || v === undefined || v === false) return;
      out += " " + k + '="' + esc(v) + '"';
    });
    if (children === undefined || children === null) return out + "/>";
    var inner = Array.isArray(children) ? children.join("") : String(children);
    return out + ">" + inner + "</" + name + ">";
  };

  /** Text node helper (content is escaped). */
  svg.text = function (x, y, str, attrs) {
    var merged = { x: x, y: y };
    Object.keys(attrs || {}).forEach(function (k) { merged[k] = attrs[k]; });
    return svg.el("text", merged, esc(str));
  };

  /** Round a positive max up to a "nice" chart axis maximum. */
  svg.niceMax = function (value) {
    if (!(value > 0)) return 10;
    var steps = [5, 10, 20, 25, 40, 50, 60, 75, 80, 100];
    for (var i = 0; i < steps.length; i++) {
      if (value <= steps[i]) return steps[i];
    }
    return Math.ceil(value / 50) * 50;
  };

  /** Linear scale: domain [0, domainMax] -> range [0, rangeMax]. */
  svg.linear = function (domainMax, rangeMax) {
    return function (v) {
      return domainMax === 0 ? 0 : (v / domainMax) * rangeMax;
    };
  };

  /**
   * Mix a hex colour towards white. strength 1 = full colour, 0 = white.
   * shade("#000000", 0.5) === "#808080".
   */
  svg.shade = function (hex, strength) {
    var c = String(hex || TR.DEFAULT_BRAND).replace("#", "");
    if (c.length === 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
    var channel = function (pos) {
      var raw = parseInt(c.substr(pos, 2), 16);
      var mixed = Math.round(255 - (255 - raw) * strength);
      return ("0" + mixed.toString(16)).slice(-2);
    };
    return "#" + channel(0) + channel(2) + channel(4);
  };

  /** Wrap a chart body in a root <svg> with viewBox + accessible title. */
  svg.root = function (width, height, title, body) {
    return svg.el("svg", {
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 " + width + " " + height,
      width: "100%",
      role: "img",
      "aria-label": title,
      "font-family": "-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif"
    }, [svg.el("title", {}, esc(title)), body]);
  };

  /**
   * Simple inline legend. Wraps to new lines when items overflow maxW.
   * @returns {{body: string, height: number}}
   */
  svg.legend = function (items, x0, y0, maxW) {
    var parts = [], x = x0, y = y0;
    var lineH = 18, charW = 6.2, swatch = 11;
    items.forEach(function (item) {
      var w = swatch + 6 + String(item.label).length * charW + 16;
      if (x + w > x0 + maxW && x > x0) { x = x0; y += lineH; }
      parts.push(svg.el("rect", {
        x: x, y: y - 9, width: swatch, height: swatch, rx: 3, fill: item.colour
      }));
      parts.push(svg.text(x + swatch + 5, y + 1, item.label,
        { "font-size": 11, fill: "#4b5263" }));
      x += w;
    });
    return { body: parts.join(""), height: y - y0 + lineH };
  };

})(typeof window !== "undefined" ? window : globalThis);
