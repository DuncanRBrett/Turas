/**
 * Minimal deterministic ZIP writer (method = STORE, fixed timestamp) plus
 * CRC-32. This is all OOXML needs: a .pptx is a zip of XML parts, and
 * PowerPoint accepts stored (uncompressed) entries. ~120 lines replace the
 * compression half of a 0.94 MB vendored library. Pure — tested in node.
 */
(function (global) {
  "use strict";
  var TR = global.TR, C = TR.CONST;

  var zip = TR.zip = {};

  var CRC_TABLE = (function () {
    var table = new Uint32Array(256);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      }
      table[n] = c >>> 0;
    }
    return table;
  })();

  /** CRC-32. Known answer: crc32(bytes("123456789")) === 0xCBF43926. */
  zip.crc32 = function (bytes) {
    var c = 0xFFFFFFFF;
    for (var i = 0; i < bytes.length; i++) {
      c = CRC_TABLE[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8);
    }
    return (c ^ 0xFFFFFFFF) >>> 0;
  };

  /** UTF-8 encode a string. */
  zip.bytes = function (str) {
    return new TextEncoder().encode(str);
  };

  function le16(arr, v) { arr.push(v & 255, (v >>> 8) & 255); }
  function le32(arr, v) {
    arr.push(v & 255, (v >>> 8) & 255, (v >>> 16) & 255, (v >>> 24) & 255);
  }

  /**
   * Build a ZIP archive. Deterministic: same entries -> same bytes.
   * @param {Array<{name: string, data: string|Uint8Array}>} entries
   * @returns {Uint8Array}
   * @throws {Error} when entries is empty (a zip with no parts is a bug).
   */
  zip.build = function (entries) {
    if (!Array.isArray(entries) || entries.length === 0) {
      throw new Error("IO_ZIP_EMPTY: zip.build needs at least one entry.");
    }
    var chunks = [], central = [], offset = 0;

    entries.forEach(function (entry) {
      var nameBytes = zip.bytes(entry.name);
      var data = typeof entry.data === "string" ? zip.bytes(entry.data) : entry.data;
      var crc = zip.crc32(data);

      var local = [];
      le32(local, 0x04034B50);            // local file header signature
      le16(local, 20); le16(local, 0); le16(local, 0); // version, flags, method=store
      le16(local, C.ZIP_DOS_TIME); le16(local, C.ZIP_DOS_DATE);
      le32(local, crc); le32(local, data.length); le32(local, data.length);
      le16(local, nameBytes.length); le16(local, 0);
      chunks.push(new Uint8Array(local), nameBytes, data);

      var cd = [];
      le32(cd, 0x02014B50);               // central directory signature
      le16(cd, 20); le16(cd, 20); le16(cd, 0); le16(cd, 0);
      le16(cd, C.ZIP_DOS_TIME); le16(cd, C.ZIP_DOS_DATE);
      le32(cd, crc); le32(cd, data.length); le32(cd, data.length);
      le16(cd, nameBytes.length); le16(cd, 0); le16(cd, 0);
      le16(cd, 0); le16(cd, 0); le32(cd, 0); le32(cd, offset);
      central.push(new Uint8Array(cd), nameBytes);

      offset += local.length + nameBytes.length + data.length;
    });

    var cdSize = central.reduce(function (sum, c) { return sum + c.length; }, 0);
    var eocd = [];
    le32(eocd, 0x06054B50);               // end of central directory
    le16(eocd, 0); le16(eocd, 0);
    le16(eocd, entries.length); le16(eocd, entries.length);
    le32(eocd, cdSize); le32(eocd, offset); le16(eocd, 0);

    var out = new Uint8Array(offset + cdSize + eocd.length);
    var pos = 0;
    chunks.concat(central, [new Uint8Array(eocd)]).forEach(function (chunk) {
      out.set(chunk, pos);
      pos += chunk.length;
    });
    return out;
  };

})(typeof window !== "undefined" ? window : globalThis);
