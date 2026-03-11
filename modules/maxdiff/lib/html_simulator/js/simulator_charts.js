/**
 * TURAS MaxDiff Simulator Charts v11.0
 * SVG chart rendering for the interactive simulator
 */

var SimCharts = (function() {

  var brandColour = "#1e3a5f";

  function setBrandColour(colour) {
    brandColour = colour || "#1e3a5f";
  }

  /**
   * Render horizontal share bars
   * @param {Object[]} shares - Array of {label, share} sorted by share desc
   * @param {HTMLElement} container - DOM element to render into
   */
  function renderShareBars(shares, container) {
    if (!container || !shares || shares.length === 0) return;

    var maxShare = Math.max.apply(null, shares.map(function(s) { return s.share; }));
    if (maxShare <= 0) maxShare = 1;

    var html = '<div class="sim-share-bars">';
    for (var i = 0; i < shares.length; i++) {
      var s = shares[i];
      var width = Math.max(2, (s.share / maxShare) * 100);
      html += '<div class="sim-bar-row">' +
        '<div class="sim-bar-label">' + escapeHtml(s.label) + '</div>' +
        '<div class="sim-bar-track">' +
          '<div class="sim-bar-fill" style="width:' + width + '%;background:' + brandColour + '"></div>' +
        '</div>' +
        '<div class="sim-bar-value">' + s.share.toFixed(1) + '%</div>' +
      '</div>';
    }
    html += '</div>';
    container.innerHTML = html;
  }

  /**
   * Render head-to-head comparison
   * @param {Object} result - {probA, probB, itemA, itemB}
   * @param {HTMLElement} container
   */
  function renderHeadToHead(result, container) {
    if (!container) return;

    var html = '<div class="sim-h2h">' +
      '<div class="sim-h2h-bar">' +
        '<div class="sim-h2h-a" style="width:' + result.probA + '%;background:' + brandColour + '">' +
          '<span>' + result.probA + '%</span>' +
        '</div>' +
        '<div class="sim-h2h-b" style="width:' + result.probB + '%;background:#e74c3c">' +
          '<span>' + result.probB + '%</span>' +
        '</div>' +
      '</div>' +
      '<div class="sim-h2h-labels">' +
        '<span class="sim-h2h-label-a">' + escapeHtml(result.itemA || "Item A") + '</span>' +
        '<span class="sim-h2h-label-b">' + escapeHtml(result.itemB || "Item B") + '</span>' +
      '</div>' +
    '</div>';
    container.innerHTML = html;
  }

  /**
   * Render TURF reach indicator
   * @param {Object} reachResult - {reach, frequency, nReached, nTotal}
   * @param {HTMLElement} container
   */
  function renderTurfReach(reachResult, container) {
    if (!container) return;

    var r = reachResult;
    var angle = (r.reach / 100) * 360;
    var rad = (angle - 90) * Math.PI / 180;
    var large = angle > 180 ? 1 : 0;
    var cx = 60, cy = 60, radius = 50;
    var x = cx + radius * Math.cos(rad);
    var y = cy + radius * Math.sin(rad);

    var pathD = r.reach >= 99.9
      ? 'M ' + cx + ' ' + (cy - radius) + ' A ' + radius + ' ' + radius + ' 0 1 1 ' + (cx - 0.01) + ' ' + (cy - radius)
      : 'M ' + cx + ' ' + (cy - radius) + ' A ' + radius + ' ' + radius + ' 0 ' + large + ' 1 ' + x.toFixed(1) + ' ' + y.toFixed(1);

    var svg = '<svg viewBox="0 0 120 120" width="120" height="120">' +
      '<circle cx="' + cx + '" cy="' + cy + '" r="' + radius + '" fill="none" stroke="#e2e8f0" stroke-width="8"/>' +
      '<path d="' + pathD + '" fill="none" stroke="' + brandColour + '" stroke-width="8" stroke-linecap="round"/>' +
      '<text x="' + cx + '" y="' + (cy + 2) + '" text-anchor="middle" font-size="18" font-weight="700" fill="' + brandColour + '">' + r.reach + '%</text>' +
      '<text x="' + cx + '" y="' + (cy + 16) + '" text-anchor="middle" font-size="10" fill="#64748b">reach</text>' +
    '</svg>';

    var html = '<div class="sim-turf-gauge">' + svg +
      '<div class="sim-turf-stats">' +
        '<div>' + r.nReached + ' / ' + r.nTotal + ' respondents reached</div>' +
        '<div>Avg frequency: ' + r.frequency + ' items</div>' +
      '</div>' +
    '</div>';
    container.innerHTML = html;
  }

  function escapeHtml(str) {
    var div = document.createElement("div");
    div.appendChild(document.createTextNode(str || ""));
    return div.innerHTML;
  }

  return {
    setBrandColour: setBrandColour,
    renderShareBars: renderShareBars,
    renderHeadToHead: renderHeadToHead,
    renderTurfReach: renderTurfReach
  };
})();
