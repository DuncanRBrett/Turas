/**
 * seg_slide_export.js - Export chart sections as PNG for presentations
 * in Turas Segment HTML reports.
 * Serializes SVG elements to PNG via canvas at 3x resolution.
 */
(function() {
  'use strict';

  /**
   * Export SVG charts from a section as PNG files.
   * Each SVG in the section is rendered to a canvas at 3x scale
   * and downloaded as a PNG.
   * @param {string} sectionKey - Value of data-seg-section attribute
   */
  window.segExportSlide = function(sectionKey) {
    if (!sectionKey) return;

    var section = document.querySelector(
      '[data-seg-section="' + sectionKey + '"]'
    );
    if (!section) {
      alert('Section not found: ' + sectionKey);
      return;
    }

    var svgs = section.querySelectorAll('svg');
    if (svgs.length === 0) {
      alert('No charts to export in this section.');
      return;
    }

    var serializer = new XMLSerializer();
    var scale = 3; // 3x scale for high-quality output

    for (var i = 0; i < svgs.length; i++) {
      (function(svg, idx) {
        var svgString = serializer.serializeToString(svg);
        var svgBlob = new Blob([svgString], {
          type: 'image/svg+xml;charset=utf-8'
        });
        var url = URL.createObjectURL(svgBlob);

        var img = new Image();
        img.onload = function() {
          var canvas = document.createElement('canvas');
          var ctx = canvas.getContext('2d');

          canvas.width = img.width * scale;
          canvas.height = img.height * scale;
          ctx.scale(scale, scale);

          // White background
          ctx.fillStyle = '#ffffff';
          ctx.fillRect(0, 0, img.width, img.height);
          ctx.drawImage(img, 0, 0);

          canvas.toBlob(function(blob) {
            if (!blob) {
              URL.revokeObjectURL(url);
              return;
            }
            var suffix = svgs.length > 1 ? '_' + (idx + 1) : '';
            var filename = sectionKey + suffix + '.png';
            window.segDownloadBlob(blob, filename);
            URL.revokeObjectURL(url);
          }, 'image/png');
        };

        img.onerror = function() {
          URL.revokeObjectURL(url);
        };

        img.src = url;
      })(svgs[i], i);
    }
  };
})();
