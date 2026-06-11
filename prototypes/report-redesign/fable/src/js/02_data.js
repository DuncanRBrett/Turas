/**
 * Data layer — payload validation (error-accumulating, TRS-style codes)
 * and read helpers. Pure; the payload schema is documented in README.md.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var data = TR.data = {};

  function err(errors, code, message) {
    errors.push({ code: code, message: message });
  }

  /**
   * Validate a report payload. Accumulates every problem found so the
   * report author sees the full list at once (never fail-fast on data).
   * @returns {{ok: boolean, errors: Array<{code: string, message: string}>}}
   */
  data.validate = function (payload) {
    var errors = [];
    if (!payload || typeof payload !== "object") {
      err(errors, "DATA_NOT_OBJECT", "Report payload is not a JSON object.");
      return { ok: false, errors: errors };
    }
    if (!payload.project || !payload.project.name) {
      err(errors, "DATA_NO_PROJECT", "project.name is missing.");
    }
    var banner = payload.banner;
    if (!banner || !Array.isArray(banner.columns) || banner.columns.length === 0) {
      err(errors, "DATA_NO_BANNER", "banner.columns must be a non-empty array.");
    }
    if (!Array.isArray(payload.questions) || payload.questions.length === 0) {
      err(errors, "DATA_NO_QUESTIONS", "questions must be a non-empty array.");
      return { ok: errors.length === 0, errors: errors };
    }
    var seen = {};
    payload.questions.forEach(function (q, i) {
      validateQuestion(q, i, payload, seen, errors);
    });
    return { ok: errors.length === 0, errors: errors };
  };

  function validateQuestion(q, i, payload, seen, errors) {
    var label = "questions[" + i + "]" + (q && q.id ? " (" + q.id + ")" : "");
    if (!q || typeof q !== "object") {
      err(errors, "DATA_Q_NOT_OBJECT", label + " is not an object.");
      return;
    }
    if (!q.id) {
      err(errors, "DATA_Q_NO_ID", label + ": id is missing.");
    } else if (seen[q.id]) {
      err(errors, "DATA_Q_DUP_ID", label + ": duplicate id '" + q.id + "'.");
    } else {
      seen[q.id] = true;
    }
    if (!q.title) err(errors, "DATA_Q_NO_TITLE", label + ": title is missing.");
    if (TR.QUESTION_TYPES.indexOf(q.type) === -1) {
      err(errors, "DATA_Q_BAD_TYPE", label + ": type '" + q.type +
        "' is not one of " + TR.QUESTION_TYPES.join("/") + ".");
    }
    var nCols = data.bannerColumns(payload, q).length;
    if (q.bases && q.bases.length !== nCols) {
      err(errors, "DATA_Q_BASES_LEN", label + ": bases has " + q.bases.length +
        " entries; banner has " + nCols + " columns.");
    }
    (q.rows || []).forEach(function (row, r) {
      if (!row || !Array.isArray(row.values) || row.values.length !== nCols) {
        err(errors, "DATA_ROW_LEN", label + " rows[" + r + "]: values must have " +
          nCols + " entries (one per banner column).");
      }
      if (row && Array.isArray(row.sig) && row.sig.length !== nCols) {
        err(errors, "DATA_ROW_SIG_LEN", label + " rows[" + r + "]: sig must have " +
          nCols + " entries.");
      }
    });
    (q.stats || []).forEach(function (s, r) {
      if (!s || !Array.isArray(s.values) || s.values.length !== nCols) {
        err(errors, "DATA_STAT_LEN", label + " stats[" + r + "]: values must have " +
          nCols + " entries.");
      }
    });
    if ((!q.rows || q.rows.length === 0) && (!q.stats || q.stats.length === 0)) {
      err(errors, "DATA_Q_EMPTY", label + ": needs at least one row or stat.");
    }
    validateWaves(q, label, errors);
  }

  function validateWaves(q, label, errors) {
    var waves = q.meta && q.meta.waves;
    if (!waves) return;
    if (!Array.isArray(waves.labels) || waves.labels.length < 2) {
      err(errors, "DATA_WAVES_LABELS", label + ": meta.waves.labels needs >= 2 wave labels.");
      return;
    }
    (waves.series || []).forEach(function (s, i) {
      if (!s || !Array.isArray(s.values) || s.values.length !== waves.labels.length) {
        err(errors, "DATA_WAVES_LEN", label + " waves.series[" + i +
          "]: values must have " + waves.labels.length + " entries (one per wave).");
      }
    });
  }

  /** Banner columns for a question (per-question override wins). */
  data.bannerColumns = function (payload, q) {
    if (q && Array.isArray(q.banner) && q.banner.length) return q.banner;
    return (payload.banner && payload.banner.columns) || [];
  };

  /** Sig letters for the banner columns; generated T/A/B/C… when absent. */
  data.bannerLetters = function (payload, q) {
    var cols = data.bannerColumns(payload, q);
    var letters = (!q || !q.banner) && payload.banner && payload.banner.letters
      ? payload.banner.letters : [];
    return cols.map(function (_, i) {
      return letters[i] || (i === 0 ? "T" : String.fromCharCode(64 + i));
    });
  };

  /** Find a question by id; null when missing. */
  data.questionById = function (payload, id) {
    for (var i = 0; i < payload.questions.length; i++) {
      if (payload.questions[i].id === id) return payload.questions[i];
    }
    return null;
  };

  /** Largest row value across ALL banner columns (stable chart axis). */
  data.maxRowValue = function (q) {
    var max = 0;
    (q.rows || []).forEach(function (row) {
      (row.values || []).forEach(function (v) {
        if (typeof v === "number" && v > max) max = v;
      });
    });
    return max;
  };

  /** The wave series for a banner column, falling back to the first series. */
  data.waveSeriesFor = function (q, columnName) {
    var waves = q.meta && q.meta.waves;
    if (!waves || !Array.isArray(waves.series) || !waves.series.length) return null;
    for (var i = 0; i < waves.series.length; i++) {
      if (waves.series[i].column === columnName) return waves.series[i];
    }
    return waves.series[0];
  };

})(typeof window !== "undefined" ? window : globalThis);
