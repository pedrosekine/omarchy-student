"""Block splitting — Python twin of plugin-page/Blocks.js.

Same algorithm, same hashes. tests/test_blocks.py checks the two never drift.
"""
import re

LIST_RE = re.compile(r"^([-*+]|\d+[.)])\s")
HEADING_RE = re.compile(r"^#{1,6}\s")
QUOTE_RE = re.compile(r"^>")
PRIVATE_RE = re.compile(r"^>\s*\[!private\]", re.I)
INDENT_RE = re.compile(r"^[ \t]")


def fnv1a(text: str) -> str:
    h = 0x811C9DC5
    for b in text.encode("utf-8"):
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return f"{h:08x}"


def split(text: str) -> list[dict]:
    lines = text.split("\n")
    n = len(lines)
    blocks: list[dict] = []
    i = 0

    def push(kind, start, end, private=False):
        body = "\n".join(lines[start:end])
        blocks.append({"kind": kind, "start": start, "end": end, "text": body,
                       "hash": fnv1a(body), "private": private})

    if n > 0 and lines[0] == "---":
        j = 1
        while j < n and lines[j] != "---":
            j += 1
        if j < n:
            push("frontmatter", 0, j + 1, True)
            i = j + 1

    while i < n:
        line = lines[i]
        if line.strip() == "":
            i += 1
            continue
        if HEADING_RE.match(line):
            push("heading", i, i + 1)
            i += 1
            continue
        if QUOTE_RE.match(line):
            qs = i
            private = bool(PRIVATE_RE.match(line))
            while i < n and QUOTE_RE.match(lines[i]):
                i += 1
            push("callout", qs, i, private)
            continue
        if LIST_RE.match(line):
            ls = i
            i += 1
            while i < n and lines[i].strip() != "" and INDENT_RE.match(lines[i]):
                i += 1
            push("item", ls, i)
            continue
        ps = i
        i += 1
        while (i < n and lines[i].strip() != "" and not HEADING_RE.match(lines[i])
               and not QUOTE_RE.match(lines[i]) and not LIST_RE.match(lines[i])):
            i += 1
        push("paragraph", ps, i)
    return blocks


def block_at(blocks: list[dict], line_index: int) -> int:
    for k, b in enumerate(blocks):
        if b["start"] <= line_index < b["end"]:
            return k
    return -1


if __name__ == "__main__":
    import json
    import sys
    print(json.dumps(split(sys.stdin.read()), ensure_ascii=False))
