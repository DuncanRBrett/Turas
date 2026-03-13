/* ===========================================================================
   TURAS PRICING REPORT - Navigation & UI
   Tab switching, keyboard nav, tooltips, chart export
   =========================================================================== */

(function() {
  "use strict";

  // ── Tab switching ──
  var tabs = document.querySelectorAll(".pr-tab-btn");
  var panels = document.querySelectorAll(".pr-panel");

  function switchTab(target) {
    tabs.forEach(function(t) { t.classList.remove("active"); });
    panels.forEach(function(p) { p.classList.remove("active"); });

    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].getAttribute("data-tab") === target) {
        tabs[i].classList.add("active");
        break;
      }
    }
    var panel = document.getElementById("panel-" + target);
    if (panel) panel.classList.add("active");

    // Lazy-init simulator when its tab is first activated
    if (target === "simulator" && typeof PricingSimulator !== "undefined" && !PricingSimulator._initialized) {
      PricingSimulator.lazyInit();
    }
  }

  tabs.forEach(function(tab) {
    tab.addEventListener("click", function() {
      switchTab(this.getAttribute("data-tab"));
    });
  });

  // ── Keyboard navigation ──
  document.addEventListener("keydown", function(e) {
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA" ||
        e.target.isContentEditable) return;

    var tabArr = Array.prototype.slice.call(tabs);
    var currentIdx = -1;
    for (var i = 0; i < tabArr.length; i++) {
      if (tabArr[i].classList.contains("active")) { currentIdx = i; break; }
    }

    // Number keys 1-9 for direct tab access
    if (e.key >= "1" && e.key <= "9") {
      var idx = parseInt(e.key) - 1;
      if (idx < tabArr.length) {
        switchTab(tabArr[idx].getAttribute("data-tab"));
      }
      return;
    }

    // Arrow keys for prev/next
    if (e.key === "ArrowLeft" && currentIdx > 0) {
      switchTab(tabArr[currentIdx - 1].getAttribute("data-tab"));
    } else if (e.key === "ArrowRight" && currentIdx < tabArr.length - 1) {
      switchTab(tabArr[currentIdx + 1].getAttribute("data-tab"));
    }
  });

  // ── SVG tooltip system ──
  var tooltip = document.createElement("div");
  tooltip.className = "pr-tooltip";
  document.body.appendChild(tooltip);

  document.addEventListener("mouseover", function(e) {
    var el = e.target.closest("[data-tooltip]");
    if (el) {
      tooltip.textContent = el.getAttribute("data-tooltip");
      tooltip.classList.add("visible");
    }
  });
  document.addEventListener("mousemove", function(e) {
    if (tooltip.classList.contains("visible")) {
      tooltip.style.left = (e.clientX + 12) + "px";
      tooltip.style.top = (e.clientY - 28) + "px";
    }
  });
  document.addEventListener("mouseout", function(e) {
    if (e.target.closest("[data-tooltip]")) {
      tooltip.classList.remove("visible");
    }
  });

  // Expose switchTab globally for other modules
  window.PricingNav = { switchTab: switchTab };

})();

// ── Chart export (SVG to PNG) ──
var TurasCharts = {
  exportSVG: function(btn) {
    var container = btn.parentElement;
    var svgEl = container.querySelector("svg");
    if (!svgEl) { alert("No chart found"); return; }

    var svgData = new XMLSerializer().serializeToString(svgEl);
    var canvas = document.createElement("canvas");
    var ctx = canvas.getContext("2d");
    var img = new Image();

    img.onload = function() {
      canvas.width = img.width * 2;
      canvas.height = img.height * 2;
      ctx.scale(2, 2);
      ctx.fillStyle = "white";
      ctx.fillRect(0, 0, img.width, img.height);
      ctx.drawImage(img, 0, 0);
      ctx.font = "10px sans-serif";
      ctx.fillStyle = "#94a3b8";
      ctx.fillText("TURAS Pricing Report", 10, img.height - 8);

      var link = document.createElement("a");
      link.download = "pricing_chart.png";
      link.href = canvas.toDataURL("image/png");
      link.click();
    };
    img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgData)));
  }
};
