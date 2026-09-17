// Block splitting — the unit the page paints and the agent answers.
//
// Reference implementation for QML. `agent/blocks.py` is the same algorithm
// in Python for the runner; `tests/test_blocks.py` runs both over
// `tests/fixtures/*.md` and fails if they ever disagree.
//
// A block is one of:
//   frontmatter  the leading `---` … `---` section (never sent to the agent)
//   heading      one `#` line
//   callout      consecutive `>` lines; `> [!private]` sets private = true
//   item         a top-level list item plus its indented continuation lines
//   paragraph    consecutive non-blank lines that are none of the above
// Blank lines separate blocks and belong to none. Identity is an FNV-1a
// 32-bit hash of the block text, so editing a block makes it a new block —
// no ids are ever written into the note.
.pragma library

var LIST_RE = /^([-*+]|\d+[.)])\s/
var HEADING_RE = /^#{1,6}\s/
var QUOTE_RE = /^>/
var PRIVATE_RE = /^>\s*\[!private\]/i
var INDENT_RE = /^[ \t]/

function fnv1a(str) {
  var h = 0x811c9dc5
  var bytes = utf8(str)
  for (var i = 0; i < bytes.length; i++) {
    h ^= bytes[i]
    h = Math.imul(h, 0x01000193) >>> 0
  }
  return ("0000000" + h.toString(16)).slice(-8)
}

function utf8(str) {
  var out = []
  for (var i = 0; i < str.length; i++) {
    var c = str.charCodeAt(i)
    if (c >= 0xd800 && c <= 0xdbff && i + 1 < str.length) {
      var d = str.charCodeAt(i + 1)
      if (d >= 0xdc00 && d <= 0xdfff) {
        c = 0x10000 + ((c - 0xd800) << 10) + (d - 0xdc00)
        i++
      }
    }
    if (c < 0x80) out.push(c)
    else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63))
    else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63))
    else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63))
  }
  return out
}

function isBlank(line) {
  return line.trim() === ""
}

// Returns [{ kind, start, end, text, hash, private }] where start/end are
// 0-based line indices, end exclusive.
function split(text) {
  var lines = text.split("\n")
  var blocks = []
  var i = 0
  var n = lines.length

  function push(kind, start, end, priv) {
    var body = lines.slice(start, end).join("\n")
    blocks.push({ kind: kind, start: start, end: end, text: body, hash: fnv1a(body), private: priv === true })
  }

  if (n > 0 && lines[0] === "---") {
    var j = 1
    while (j < n && lines[j] !== "---") j++
    if (j < n) {
      push("frontmatter", 0, j + 1, true)
      i = j + 1
    }
  }

  while (i < n) {
    var line = lines[i]
    if (isBlank(line)) { i++; continue }

    if (HEADING_RE.test(line)) {
      push("heading", i, i + 1)
      i++
      continue
    }

    if (QUOTE_RE.test(line)) {
      var qs = i
      var priv = PRIVATE_RE.test(line)
      while (i < n && QUOTE_RE.test(lines[i])) i++
      push("callout", qs, i, priv)
      continue
    }

    if (LIST_RE.test(line)) {
      var ls = i
      i++
      while (i < n && !isBlank(lines[i]) && INDENT_RE.test(lines[i])) i++
      push("item", ls, i)
      continue
    }

    var ps = i
    i++
    while (i < n && !isBlank(lines[i]) && !HEADING_RE.test(lines[i]) && !QUOTE_RE.test(lines[i]) && !LIST_RE.test(lines[i])) i++
    push("paragraph", ps, i)
  }
  return blocks
}

// Index of the block containing line `lineIndex`, or -1 when it sits on a
// blank line between blocks.
function blockAt(blocks, lineIndex) {
  for (var k = 0; k < blocks.length; k++)
    if (lineIndex >= blocks[k].start && lineIndex < blocks[k].end) return k
  return -1
}
