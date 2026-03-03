/* ==============================================================================
 * CATDRIVER HTML REPORT - NAVIGATION JS
 * ==============================================================================
 * Section navigation, factor picker, and print mode.
 * All functions prefixed cd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  // Section navigation - highlight active nav link on scroll
  var navLinks = document.querySelectorAll('.cd-nav a');
  var sections = [];

  navLinks.forEach(function(link) {
    var href = link.getAttribute('href');
    if (href && href.startsWith('#')) {
      var section = document.getElementById(href.slice(1));
      if (section) {
        sections.push({ el: section, link: link });
      }
    }

    link.addEventListener('click', function(e) {
      e.preventDefault();
      var target = document.getElementById(href.slice(1));
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  function updateActiveNav() {
    var scrollY = window.scrollY + 100;
    var active = null;

    for (var i = sections.length - 1; i >= 0; i--) {
      if (sections[i].el.offsetTop <= scrollY) {
        active = sections[i];
        break;
      }
    }

    navLinks.forEach(function(link) { link.classList.remove('active'); });
    if (active) {
      active.link.classList.add('active');
    }
  }

  window.addEventListener('scroll', updateActiveNav, { passive: true });
  updateActiveNav();

  // Factor picker
  window.cdShowFactor = function(factorId) {
    // Deactivate all tabs and panels
    document.querySelectorAll('.cd-factor-tab').forEach(function(tab) {
      tab.classList.remove('active');
    });
    document.querySelectorAll('.cd-factor-panel').forEach(function(panel) {
      panel.classList.remove('active');
    });

    // Activate selected
    var tab = document.querySelector('.cd-factor-tab[data-factor="' + factorId + '"]');
    var panel = document.getElementById('cd-panel-' + factorId);

    if (tab) tab.classList.add('active');
    if (panel) panel.classList.add('active');
  };

  // Print mode
  window.cdPrint = function() {
    window.print();
  };

})();
