/**
 * Turas data-centric report prototype (fable) — namespace + constants.
 *
 * Every module attaches to the TR namespace. Modules numbered 00–06 and
 * 13–15 are pure (no DOM access) so they can be unit-tested in node.
 * Every magic number in the prototype lives in TR.CONST.
 */
(function (global) {
  "use strict";

  var TR = global.TR = global.TR || {};

  TR.CONST = {
    SCHEMA_VERSION: 1,

    /* number formatting */
    PCT_DECIMALS_DEFAULT: 0,

    /* chart geometry (SVG user units) */
    CHART_WIDTH: 660,
    CHART_LABEL_WIDTH: 170,
    CHART_VALUE_WIDTH: 64,
    BAR_HEIGHT: 22,
    BAR_GAP: 10,
    CHART_PAD_TOP: 8,
    CHART_PAD_BOTTOM: 26,
    STACK_ROW_HEIGHT: 30,
    STACK_ROW_GAP: 12,
    TREND_HEIGHT: 190,

    /* cross-question composer */
    COMPOSE_MIN: 2,
    COMPOSE_MAX: 6,

    /* PNG export */
    EXPORT_SCALE: 3,
    EXPORT_WIDTH: 920,

    /* PPTX geometry (EMU = English Metric Units) */
    EMU_PER_INCH: 914400,
    SLIDE_W_IN: 13.333,
    SLIDE_H_IN: 7.5,
    PPTX_TABLE_ROWS_PER_SLIDE: 16,

    /* deterministic ZIP timestamp: 2026-01-01 00:00 in DOS format */
    ZIP_DOS_DATE: ((2026 - 1980) << 9) | (1 << 5) | 1,
    ZIP_DOS_TIME: 0
  };

  /** Question types the renderer understands. */
  TR.QUESTION_TYPES = ["single", "multi", "scale", "nps", "numeric"];

  /** Fallback brand identity when the payload omits colours. */
  TR.DEFAULT_BRAND = "#323367";
  TR.DEFAULT_ACCENT = "#C9A84C";

})(typeof window !== "undefined" ? window : globalThis);
