/* ============================================================================
 * TurasTracker - Trend Annotations
 * ============================================================================
 * Allows contextual annotations on chart data points (e.g., "Campaign launched").
 * Supports two sources:
 *   1. Pre-configured via config file (embedded at build time in JSON store)
 *   2. Interactive: user clicks a data point to add/edit/remove annotations
 * Annotations persist in a hidden JSON store within the HTML.
 * VERSION: 1.0.0
 * ============================================================================ */

(function() {
  "use strict";

  /** Escape a string for safe use inside HTML attributes. */
  function escapeAttr(s) { return String(s).replace(/&/g,"&amp;").replace(/'/g,"&#39;").replace(/"/g,"&quot;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }

  // ---- Annotation Data Store ----
  // Structure: [{metricId, waveId, segment, text, colour}]
  var annotations = [];

  /** Load annotations from hidden JSON store. */
  function loadAnnotations() {
    var store = document.getElementById("tk-annotations-data");
    if (!store) return;
    try {
      var data = JSON.parse(store.textContent);
      if (Array.isArray(data)) annotations = data;
    } catch(e) { console.warn("[Annotations] Parse error:", e.message); }
  }

  /** Save annotations to hidden JSON store. */
  function saveAnnotations() {
    var store = document.getElementById("tk-annotations-data");
    if (!store) return;
    store.textContent = JSON.stringify(annotations);
  }

  /** Find annotations for a specific metric. */
  function getAnnotationsForMetric(metricId) {
    return annotations.filter(function(a) { return a.metricId === metricId; });
  }

  /** Add or update an annotation. */
  function setAnnotation(metricId, waveId, segment, text, colour) {
    // Remove existing annotation at same position
    annotations = annotations.filter(function(a) {
      return !(a.metricId === metricId && a.waveId === waveId && (a.segment === segment || !segment));
    });
    if (text && text.trim()) {
      annotations.push({
        metricId: metricId,
        waveId: waveId,
        segment: segment || "Total",
        text: text.trim(),
        colour: colour || "#64748b"
      });
    }
    saveAnnotations();
    renderAnnotationMarkers(metricId);
  }

  /** Remove an annotation. */
  function removeAnnotation(metricId, waveId, segment) {
    annotations = annotations.filter(function(a) {
      return !(a.metricId === metricId && a.waveId === waveId && (a.segment === segment || !segment));
    });
    saveAnnotations();
    renderAnnotationMarkers(metricId);
  }

  // ---- SVG Annotation Rendering ----

  /** Render annotation markers on a chart SVG. */
  function renderAnnotationMarkers(metricId) {
    // Find the metric panel
    var panel = document.querySelector('.tk-metric-panel[data-metric-id="' + metricId + '"]');
    if (!panel) return;
    var svg = panel.querySelector(".tk-line-chart");
    if (!svg) return;

    // Remove existing annotation elements
    svg.querySelectorAll(".tk-annotation-group").forEach(function(el) { el.remove(); });

    var metricAnnotations = getAnnotationsForMetric(metricId);
    if (metricAnnotations.length === 0) return;

    // Get chart dimensions from viewBox
    var vb = svg.getAttribute("viewBox");
    if (!vb) return;
    var vbParts = vb.split(/\s+/).map(Number);
    var svgW = vbParts[2];
    var svgH = vbParts[3];

    // Find x positions for wave IDs from existing x-axis labels
    var xAxisLabels = svg.querySelectorAll(".tk-chart-xaxis");
    var waveXMap = {};
    xAxisLabels.forEach(function(label) {
      var waveId = label.getAttribute("data-wave");
      var x = parseFloat(label.getAttribute("x"));
      if (waveId && !isNaN(x)) waveXMap[waveId] = x;
    });

    // Get plot area transform (offset from the <g> element)
    var plotGroup = svg.querySelector("g[transform]");
    var offsetX = 0, offsetY = 0;
    if (plotGroup) {
      var t = plotGroup.getAttribute("transform");
      var match = t.match(/translate\((\d+),(\d+)\)/);
      if (match) { offsetX = parseInt(match[1]); offsetY = parseInt(match[2]); }
    }

    // Create annotation group
    var ns = "http://www.w3.org/2000/svg";
    var group = document.createElementNS(ns, "g");
    group.setAttribute("class", "tk-annotation-group");

    metricAnnotations.forEach(function(ann) {
      var xRel = waveXMap[ann.waveId];
      if (xRel === undefined) return;
      var x = xRel + offsetX;
      var colour = ann.colour || "#64748b";

      // Vertical dashed line
      var line = document.createElementNS(ns, "line");
      line.setAttribute("x1", x);
      line.setAttribute("y1", offsetY);
      line.setAttribute("x2", x);
      line.setAttribute("y2", svgH - 80); // above x-axis
      line.setAttribute("class", "tk-annotation-line");
      line.setAttribute("stroke", colour);
      group.appendChild(line);

      // Label text (rotated)
      var text = document.createElementNS(ns, "text");
      text.setAttribute("x", x + 4);
      text.setAttribute("y", offsetY + 10);
      text.setAttribute("class", "tk-annotation-label");
      text.setAttribute("fill", colour);
      text.setAttribute("transform", "rotate(-45," + (x + 4) + "," + (offsetY + 10) + ")");
      text.textContent = ann.text.length > 25 ? ann.text.substring(0, 25) + "\u2026" : ann.text;
      group.appendChild(text);
    });

    svg.appendChild(group);
  }

  // ---- Interactive Annotation UI ----
  var activePopover = null;

  function showAnnotationPopover(pointEl) {
    closeAnnotationPopover();

    var segment = pointEl.getAttribute("data-segment") || "";
    var waveId = pointEl.getAttribute("data-wave") || "";
    var waveLabel = pointEl.getAttribute("data-wave-label") || waveId;

    // Find metric panel to get metricId (Metrics tab, Overview tab, or Visualise tab)
    var metricId = pointEl.getAttribute("data-metric-id") || "";
    if (!metricId) {
      var panel = pointEl.closest(".tk-metric-panel");
      metricId = panel ? panel.getAttribute("data-metric-id") : "";
    }
    if (!metricId) {
      // Overview chart: try to find metricId from closest metric row via segment name
      var overviewContainer = pointEl.closest("#tk-combined-chart");
      if (overviewContainer) {
        metricId = "overview";
      }
    }
    if (!metricId) {
      // Visualise chart: use the segment data attribute as fallback
      var visChart = pointEl.closest(".vis-chart-area, .vis-line-chart");
      if (visChart) {
        metricId = "visualise";
      }
    }
    if (!metricId) return;

    // Check for existing annotation
    var existing = annotations.find(function(a) {
      return a.metricId === metricId && a.waveId === waveId;
    });

    var popover = document.createElement("div");
    popover.className = "tk-annotation-popover";
    popover.innerHTML =
      '<div style="font-size:11px;color:#64748b;margin-bottom:6px;">' +
        'Annotation for ' + waveLabel +
      '</div>' +
      '<input class="tk-annotation-input" type="text" placeholder="e.g., Campaign launched" value="' +
        (existing ? existing.text.replace(/"/g, '&quot;') : '') + '">' +
      '<div class="tk-annotation-actions">' +
        (existing ? '<button class="tk-btn tk-btn-sm" style="color:#c0392b;" onclick="window._removeAnnotation(\'' +
          escapeAttr(metricId) + "','" + escapeAttr(waveId) + "','" + escapeAttr(segment) + "'" + ')">Remove</button>' : '') +
        '<button class="tk-btn tk-btn-sm" onclick="window._cancelAnnotation()">Cancel</button>' +
        '<button class="tk-btn tk-btn-sm" style="background:var(--brand);color:#fff;border-color:var(--brand);" ' +
          'onclick="window._saveAnnotation(\'' + escapeAttr(metricId) + "','" + escapeAttr(waveId) + "','" + escapeAttr(segment) + "'" + ')">Save</button>' +
      '</div>';

    // Position near the data point using fixed positioning for stability
    var rect = pointEl.getBoundingClientRect();
    var popoverW = 260;
    var popoverH = 150; // estimated height for input + buttons + padding
    var popoverLeft = Math.max(8, Math.min(rect.left + rect.width / 2 - popoverW / 2, window.innerWidth - popoverW - 8));
    var popoverTop = rect.bottom + 8;
    // If near bottom of viewport, show above instead
    if (popoverTop + popoverH > window.innerHeight) {
      popoverTop = Math.max(8, rect.top - popoverH - 8);
    }
    popover.style.left = popoverLeft + "px";
    popover.style.top = popoverTop + "px";
    popover.style.position = "fixed";
    popover.style.zIndex = "9999";
    var panel = (typeof _tkPanel === "function") ? _tkPanel() : document.body;
    panel.appendChild(popover);
    activePopover = popover;

    // Focus input
    var input = popover.querySelector(".tk-annotation-input");
    if (input) {
      input.focus();
      input.addEventListener("keydown", function(e) {
        if (e.key === "Enter") {
          window._saveAnnotation(metricId, waveId, segment);
        } else if (e.key === "Escape") {
          window._cancelAnnotation();
        }
      });
    }
  }

  function closeAnnotationPopover() {
    if (activePopover) {
      activePopover.remove();
      activePopover = null;
    }
  }

  /** Notify Visualise chart to re-render after annotation change. */
  function notifyAnnotationChange() {
    // Dispatch custom event so the Visualise chart can re-render
    document.dispatchEvent(new CustomEvent("tk-annotation-changed"));
  }

  // Global handlers (called from inline onclick in popover)
  window._saveAnnotation = function(metricId, waveId, segment) {
    if (!activePopover) return;
    var input = activePopover.querySelector(".tk-annotation-input");
    var text = input ? input.value : "";
    setAnnotation(metricId, waveId, segment, text);
    closeAnnotationPopover();
    notifyAnnotationChange();
  };

  window._removeAnnotation = function(metricId, waveId, segment) {
    removeAnnotation(metricId, waveId, segment);
    closeAnnotationPopover();
    notifyAnnotationChange();
  };

  window._cancelAnnotation = function() {
    closeAnnotationPopover();
  };

  // ---- Click handler for data points (double-click = annotate) ----
  document.addEventListener("dblclick", function(e) {
    if (e.target.classList && e.target.classList.contains("tk-chart-point")) {
      showAnnotationPopover(e.target);
    }
  });

  // Close popover on click outside
  document.addEventListener("click", function(e) {
    if (activePopover && !activePopover.contains(e.target) &&
        !e.target.classList.contains("tk-chart-point")) {
      closeAnnotationPopover();
    }
  });

  // ---- Public API ----
  window.tkAnnotations = {
    load: loadAnnotations,
    save: saveAnnotations,
    set: setAnnotation,
    remove: removeAnnotation,
    getForMetric: getAnnotationsForMetric,
    renderMarkers: renderAnnotationMarkers,
    renderAll: function() {
      document.querySelectorAll(".tk-metric-panel[data-metric-id]").forEach(function(panel) {
        renderAnnotationMarkers(panel.getAttribute("data-metric-id"));
      });
    }
  };

  // Auto-load on DOM ready
  function init() {
    loadAnnotations();
    // Render markers for the active/visible metric panel
    window.tkAnnotations.renderAll();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

})();
