"""Cross-check the JS and Python block splitters over every fixture.

Run: python3 tests/test_blocks.py   (needs node on PATH for the JS side)
"""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "agent"))
import blocks  # noqa: E402

JS_SHIM = """
const fs = require('fs');
let src = fs.readFileSync(process.argv[1], 'utf8').replace('.pragma library', '');
const m = {};
new Function('module', src + '\\nmodule.split = split;')(m);
process.stdout.write(JSON.stringify(m.split(fs.readFileSync(0, 'utf8'))));
"""


def js_split(text: str) -> list[dict]:
    out = subprocess.run(["node", "-e", JS_SHIM, str(ROOT / "plugin-page" / "Blocks.js")],
                         input=text.encode(), capture_output=True, check=True)
    return json.loads(out.stdout)


def main() -> int:
    failures = 0
    for fx in sorted((ROOT / "tests" / "fixtures").glob("*.md")):
        text = fx.read_text()
        py = blocks.split(text)
        js = js_split(text)
        if py != js:
            failures += 1
            print(f"MISMATCH {fx.name}\n  py={json.dumps(py, ensure_ascii=False)}\n  js={json.dumps(js, ensure_ascii=False)}")
        else:
            print(f"ok {fx.name}: {len(py)} blocks")

    # Spot checks on the mixed fixture: the shape the rest of the system relies on.
    mixed = blocks.split((ROOT / "tests" / "fixtures" / "mixed.md").read_text())
    kinds = [b["kind"] for b in mixed]
    expect = ["frontmatter", "paragraph", "heading", "paragraph", "item", "item", "item",
              "callout", "callout", "paragraph", "item", "item", "paragraph"]
    if kinds != expect:
        failures += 1
        print(f"KINDS {kinds}\n  expected {expect}")
    privates = [b["kind"] for b in mixed if b["private"]]
    if privates != ["frontmatter", "callout"]:
        failures += 1
        print(f"PRIVATE {privates}")
    if mixed[4]["text"] != "- [ ] draft the DORO one-pager by friday\n  with a note underneath":
        failures += 1
        print(f"ITEM {mixed[4]['text']!r}")
    if blocks.fnv1a("") != "811c9dc5" or blocks.fnv1a("a") != "e40c292c":
        failures += 1
        print("FNV vectors wrong")

    print("FAIL" if failures else "PASS")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
