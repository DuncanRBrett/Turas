/**
 * seg_navigation.js - Section navigation with smooth scroll and active tracking,
 * plus report-level tab switching between Analysis and Pinned Views,
 * for Turas Segment HTML reports.
 * Handles nav bar initialization, scroll-based active section highlighting,
 * report tab switching, page hydration, save, and print.
 */
(function() {
  'use strict';

  var navGroups = [];

  // =========================================================================
  // Section navigation
  // =========================================================================

  /**
   * Initialize all section navigation bars.
   * Finds .seg-section-nav elements, collects their links and target sections,
   * and attaches click handlers with smooth scroll offset.
   */
  function initNavBars() {
    var navBars = document.querySelectorAll('.seg-section-nav');
    for (var n = 0; n < navBars.length; n++) {
      var navBar = navBars[n];
      var anchors = navBar.querySelectorAll('a[href^="#"]');
      var links = [];
      var sections = [];

      for (var i = 0; i < anchors.length; i++) {
        var link = anchors[i];
        var targetId = link.getAttribute('href').substring(1);
        var targetEl = document.getElementById(targetId);
        if (!targetEl) continue;

        links.push(link);
        sections.push({ el: targetEl, link: link });

        (function(el, bar) {
          link.addEventListener('click', function(e) {
            e.preventDefault();
            var offset = bar.offsetHeight + 16;
            var top = el.offsetTop - offset;
            window.scrollTo({ top: top, behavior: 'smooth' });
          });
        })(targetEl, navBar);
      }

      navGroups.push({ navBar: navBar, links: links, sections: sections });
    }
  }

  /**
   * Update active nav link based on current scroll position.
   * Iterates sections in reverse to find the last one above the scroll threshold.
   */
  function updateActiveNav() {
    var scrollY = window.scrollY || window.pageYOffset;

    for (var g = 0; g < navGroups.length; g++) {
      var group = navGroups[g];
      var offset = group.navBar.offsetHeight + 16;
      var active = null;

      for (var i = group.sections.length - 1; i >= 0; i--) {
        if (group.sections[i].el.offsetTop <= scrollY + offset) {
          active = group.sections[i];
          break;
        }
      }

      for (var j = 0; j < group.links.length; j++) {
        group.links[j].classList.remove('active');
      }
      if (active) {
        active.link.classList.add('active');
      }
    }
  }

  // =========================================================================
  // Report-level tab switching (Analysis / Pinned Views)
  // =========================================================================

  /**
   * Initialize report-level tab buttons.
   * Finds .seg-report-tab-btn elements and attaches click handlers that
   * switch between the Analysis and Pinned Views panes.
   */
  function initReportTabs() {
    var tabBtns = document.querySelectorAll('.seg-report-tab-btn');
    if (!tabBtns.length) return;

    for (var i = 0; i < tabBtns.length; i++) {
      (function(btn) {
        btn.addEventListener('click', function() {
          var target = btn.getAttribute('data-tab');
          switchReportTab(target, tabBtns);
        });
      })(tabBtns[i]);
    }
  }

  /**
   * Switch the visible report tab and update button active states.
   * @param {string} tabName - 'analysis' or 'pinned'
   * @param {NodeList|Array} tabBtns - the set of tab button elements
   */
  function switchReportTab(tabName, tabBtns) {
    var analysisTab = document.getElementById('seg-analysis-tab');
    var pinnedTab   = document.getElementById('seg-pinned-tab');
    var sectionNav  = document.getElementById('seg-section-nav');

    // Toggle active class on tab buttons
    for (var i = 0; i < tabBtns.length; i++) {
      tabBtns[i].classList.toggle(
        'active',
        tabBtns[i].getAttribute('data-tab') === tabName
      );
    }

    if (tabName === 'pinned') {
      if (analysisTab) analysisTab.style.display = 'none';
      if (pinnedTab)   pinnedTab.style.display   = 'block';
      if (sectionNav)  sectionNav.style.display   = 'none';
    } else {
      if (analysisTab) analysisTab.style.display = 'block';
      if (pinnedTab)   pinnedTab.style.display   = 'none';
      if (sectionNav)  sectionNav.style.display   = '';
    }
  }

  /**
   * Public helper for programmatic tab switching (e.g. from a pin button click).
   * @param {string} tabName - 'analysis' or 'pinned'
   */
  window.segSwitchToTab = function(tabName) {
    var tabBtns = document.querySelectorAll('.seg-report-tab-btn');
    switchReportTab(tabName, tabBtns);
  };

  // =========================================================================
  // Page utilities (hydrate, save, print)
  // =========================================================================

  /**
   * Hydrate the page: run insight hydration and pinned views restoration.
   */
  window.segHydratePage = function() {
    if (typeof window.segHydrateInsights === 'function') {
      window.segHydrateInsights();
    }
    if (typeof window.segHydratePinnedViews === 'function') {
      window.segHydratePinnedViews();
    }
  };

  /**
   * Save the current report as a self-contained HTML file.
   * Shows a brief "Saved!" badge on success.
   */
  window.segSaveReportHTML = function() {
    var html = document.documentElement.outerHTML;
    var blob = new Blob([html], { type: 'text/html' });
    var filename = document.title.replace(/[^a-zA-Z0-9]/g, '_') + '.html';
    window.segDownloadBlob(blob, filename);

    var badge = document.getElementById('seg-saved-badge');
    if (badge) {
      badge.textContent = 'Saved!';
      badge.style.opacity = '1';
      setTimeout(function() {
        badge.style.opacity = '0';
      }, 2000);
    }
  };

  /**
   * Trigger browser print dialog for the report.
   */
  window.segPrint = function() {
    window.print();
  };

  // =========================================================================
  // Initialization
  // =========================================================================

  // Initialize on DOM ready
  document.addEventListener('DOMContentLoaded', function() {
    initNavBars();
    updateActiveNav();
    initReportTabs();
    window.segHydratePage();
  });

  // Track active section on scroll
  window.addEventListener('scroll', updateActiveNav, { passive: true });
})();
