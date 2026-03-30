/**
 * TurasPins Shared Library — Utilities
 *
 * Pure utility functions for SVG compression, HTML sanitisation,
 * markdown rendering, and text escaping. No state, no DOM dependencies
 * beyond createElement for sanitisation.
 *
 * Part of the TurasPins shared pin system.
 * @namespace TurasPins
 */

/* global TurasPins */
var TurasPins = window.TurasPins || {};
window.TurasPins = TurasPins;

// ── Configuration Constants ──────────────────────────────────────────────────

/** Export SVG canvas width (px) */
TurasPins.EXPORT_WIDTH = 1280;
/** Canvas resolution multiplier for crisp PNGs */
TurasPins.EXPORT_RENDER_SCALE = 3;
/** Decimal places kept in SVG coordinate compression */
TurasPins.SVG_COMPRESS_DIGITS = 3;
/** Delay between sequential multi-pin exports (ms) */
TurasPins.EXPORT_ALL_DELAY_MS = 200;
/** Maximum image file size for uploads (bytes) */
TurasPins.MAX_IMAGE_SIZE = 10 * 1024 * 1024;
/** Maximum image dimension after resize (px) */
TurasPins.MAX_IMAGE_DIM = 1200;

// ── SVG Utilities ────────────────────────────────────────────────────────────

/**
 * Strip control characters that are invalid in XML 1.0.
 * @param {string} str - Input string
 * @returns {string} Cleaned string
 */
TurasPins._stripInvalidXmlChars = function(str) {
  return str.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, "");
};

/**
 * Convert SVG string to an Image-loadable data URI.
 * Uses encodeURIComponent instead of btoa for reliable UTF-8 handling.
 * Works on file:// protocol (no blob URLs needed).
 * @param {string} svgString - Raw SVG markup
 * @returns {string} Data URI
 */
TurasPins._svgToImageUrl = function(svgString) {
  return "data:image/svg+xml;charset=utf-8," +
    encodeURIComponent(TurasPins._stripInvalidXmlChars(svgString));
};

/**
 * Compress SVG by removing unnecessary whitespace and reducing coordinate
 * precision. Preserves whitespace between text/tspan elements where it is
 * semantically meaningful. Saves ~30% on typical chart SVGs.
 * @param {string} svg - Raw SVG string
 * @returns {string} Compressed SVG string
 */
TurasPins._compressSvg = function(svg) {
  if (!svg) return "";
  svg = svg.replace(/>([\s]+)</g, function(match, ws, offset) {
    var before = svg.substring(Math.max(0, offset - 7), offset + 1);
    var after = svg.substring(offset + match.length - 1, offset + match.length + 7);
    if (/tspan>$/.test(before) || /^<tspan/.test(after) ||
        /text>$/.test(before) || /^<text/.test(after)) {
      return ">" + (ws.indexOf("\n") !== -1 ? " " : ws.substring(0, 1)) + "<";
    }
    return "><";
  });
  var coordAttrs = /\b(d|x|y|x1|y1|x2|y2|cx|cy|r|rx|ry|width|height|viewBox|transform|points|offset|dx|dy|style)="([^"]*)"/g;
  svg = svg.replace(coordAttrs, function(full, attr, val) {
    return attr + '="' + val.replace(/(\d+\.\d{3})\d+/g, "$1") + '"';
  });
  svg = svg.replace(/\s+(style|class)=""/g, "");
  return svg;
};

// ── HTML Utilities ───────────────────────────────────────────────────────────

/**
 * Escape HTML entities for safe insertion into innerHTML.
 * @param {string} str - Raw string
 * @returns {string} Entity-escaped string
 */
TurasPins._escapeHtml = function(str) {
  if (!str) return "";
  return str.replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;");
};

/**
 * Sanitise HTML by removing dangerous elements and event handlers.
 * Defence-in-depth for content moved between report contexts.
 * @param {string} html - Raw HTML string
 * @returns {string} Sanitised HTML
 */
TurasPins._sanitizeHtml = function(html) {
  if (!html) return "";
  var scriptRe = new RegExp("<script\\b[^<]*(?:(?!<\\/script>)<[^<]*)*<\\/script>", "gi");
  var iframeRe = new RegExp("<iframe\\b[^<]*(?:(?!<\\/iframe>)<[^<]*)*<\\/iframe>", "gi");
  var objectRe = new RegExp("<object\\b[^<]*(?:(?!<\\/object>)<[^<]*)*<\\/object>", "gi");
  html = html.replace(scriptRe, "");
  html = html.replace(iframeRe, "");
  html = html.replace(objectRe, "");
  html = html.replace(/<embed\b[^>]*\/?>/gi, "");
  html = html.replace(/<link\b[^>]*\/?>/gi, "");
  html = html.replace(/\s+on\w+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi, "");
  html = html.replace(/(href|src|action)\s*=\s*["']?\s*javascript:/gi, '$1="');
  html = html.replace(/(href|src|action)\s*=\s*["']?\s*data:text\/html/gi, '$1="');
  return html;
};

/**
 * Detect whether a string contains HTML tags.
 * @param {string} str - Input string
 * @returns {boolean}
 */
TurasPins._containsHtml = function(str) {
  return /<[a-z][\s\S]*>/i.test(str);
};

// ── Markdown Renderer ────────────────────────────────────────────────────────

/**
 * Lightweight markdown renderer for pin insights.
 * Handles: **bold**, *italic*, ## headings, > blockquotes, - bullets.
 * @param {string} md - Markdown source
 * @returns {string} HTML string
 */
TurasPins._renderMarkdown = function(md) {
  if (!md) return "";
  var html = md
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/^## (.+)$/gm, "<h2>$1</h2>")
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/\*(.+?)\*/g, "<em>$1</em>")
    .replace(/^&gt; (.+)$/gm, "<blockquote>$1</blockquote>")
    .replace(/^- (.+)$/gm, "<li>$1</li>");
  html = html.replace(/((?:<li>.*<\/li>\s*)+)/g, function(match) {
    return "<ul>" + match + "</ul>";
  });
  html = html.replace(/<\/blockquote>\s*<blockquote>/g, "<br>");
  html = html.split("\n").map(function(line) {
    var trimmed = line.trim();
    if (!trimmed) return "";
    if (/^<(h2|ul|li|blockquote)/.test(trimmed)) return trimmed;
    return "<p>" + trimmed + "</p>";
  }).join("\n");
  return html;
};

// ── Toast Notification ───────────────────────────────────────────────────────

/**
 * Show a brief confirmation toast at the bottom of the viewport.
 * Auto-dismisses after 2.5 seconds.
 * @param {string} message - Toast text
 */
TurasPins._showToast = function(message) {
  var existing = document.getElementById("turas-pin-toast");
  if (existing) existing.parentNode.removeChild(existing);
  var toast = document.createElement("div");
  toast.id = "turas-pin-toast";
  toast.textContent = message;
  toast.style.cssText =
    "position:fixed;bottom:24px;left:50%;transform:translateX(-50%);" +
    "z-index:99999;background:#323367;color:#fff;padding:10px 24px;" +
    "border-radius:8px;font-size:13px;font-weight:500;" +
    "font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;" +
    "box-shadow:0 4px 16px rgba(0,0,0,0.2);opacity:0;" +
    "transition:opacity 0.3s ease;white-space:nowrap;max-width:90vw;" +
    "overflow:hidden;text-overflow:ellipsis;";
  document.body.appendChild(toast);
  toast.offsetHeight; // force reflow
  toast.style.opacity = "1";
  setTimeout(function() {
    toast.style.opacity = "0";
    setTimeout(function() {
      if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 300);
  }, 2500);
};
