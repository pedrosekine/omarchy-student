"""The loop's guarantees, tested offline against a stub opencode.

Run: python3 tests/test_agent.py

- allowlist: a private block and a private day never reach the payload
- no-write: the daily note's bytes and mtime are untouched by a run
- apply: transcript, state, ledger, and knowledge land where they should,
  and a knowledge path outside the allowed names is ignored
- open: no model call when nothing is new
"""
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
AGENT = ROOT / "agent" / "student-agent"

STUB = """#!/usr/bin/env python3
import json, sys
payload = sys.stdin.read()
import os
os.makedirs(os.environ["STUB_DIR"], exist_ok=True)
open(os.path.join(os.environ["STUB_DIR"], "last_payload.md"), "w").write(payload)
reply = json.loads(open(os.path.join(os.environ["STUB_DIR"], "reply.json")).read())
text = "```json\\n" + json.dumps(reply) + "\\n```"
ev = lambda t, part: print(json.dumps({"type": t, "sessionID": "ses_stub", "part": part}))
ev("step_start", {"type": "step-start"})
ev("text", {"type": "text", "text": text, "time": {"start": 1, "end": 2}})
ev("step_finish", {"type": "step-finish", "cost": 0.0002, "tokens": {"input": 100, "output": 20, "reasoning": 5, "total": 125}})
"""

NOTE = """---
agent: true
---
[[agents/student/daily/2026.09.17|agent]]

Read the DORO brief again.

- [ ] draft the one-pager by friday

> [!private]
> SECRET-PRIVATE-LINE do not send

@ what did I say about DORO?
"""


class T:
    def __init__(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp(prefix="student-agent-test-"))
        self.vault = self.tmp / "vault"
        self.daily = self.vault / "inbox" / "Daily"
        self.daily.mkdir(parents=True)
        (self.vault / "human" / "_Secrets").mkdir(parents=True)
        (self.vault / "human" / "_Secrets" / "keys.md").write_text("SECRET-VAULT-FILE\n")
        self.note = self.daily / "2026.09.17.md"
        self.note.write_text(NOTE)
        self.cfg = self.tmp / "config.json"
        self.cfg.write_text(json.dumps({"vault": str(self.vault), "daily": {"dir": "inbox/Daily", "format": "YYYY.MM.DD"},
                                        "agentDir": "agents/student", "opencode": str(self.tmp / "bin" / "opencode")}))
        (self.tmp / "bin").mkdir()
        stub = self.tmp / "bin" / "opencode"
        stub.write_text(STUB)
        stub.chmod(0o755)
        self.stub_dir = self.tmp / "stub"
        self.stub_dir.mkdir()
        self.state_home = self.tmp / "state"
        self.env = dict(os.environ, OMARCHY_STUDENT_CONFIG=str(self.cfg), XDG_STATE_HOME=str(self.state_home),
                        STUB_DIR=str(self.stub_dir), PATH=str(self.tmp / "bin") + ":" + os.environ["PATH"])
        # keep `pomo report` out of it: an empty PATH entry first means the real pomo is still found;
        # that is fine — its output is just another allowlisted source.

    def agent(self, *args):
        return subprocess.run([sys.executable, str(AGENT), *args], capture_output=True, text=True, env=self.env)

    def set_reply(self, **kw):
        base = {"reply": "", "proposals": [], "suggestions": [], "knowledge": []}
        base.update(kw)
        (self.stub_dir / "reply.json").write_text(json.dumps(base))

    def cleanup(self):
        shutil.rmtree(self.tmp)


def main() -> int:
    t = T()
    fails = []

    def check(cond, msg):
        if not cond:
            fails.append(msg)
            print("FAIL", msg)
        else:
            print("ok  ", msg)

    try:
        # Hash of the "@" block, computed the same way the page does.
        sys.path.insert(0, str(ROOT / "agent"))
        import blocks
        blks = blocks.split(NOTE)
        at_block = next(b for b in blks if b["text"].startswith("@ "))
        priv = next(b for b in blks if b["private"] and b["kind"] == "callout")

        # 1. allowlist: context contains the note minus private, never the secrets folder
        r = t.agent("context", "--trigger", "mention", "--hash", at_block["hash"], "--date", "2026.09.17")
        check(r.returncode == 0, f"context exits 0 ({r.stderr.strip()})")
        check("SECRET-PRIVATE-LINE" not in r.stdout, "private callout absent from payload")
        check("SECRET-VAULT-FILE" not in r.stdout, "vault secrets folder absent from payload")
        check("[[agents/student/daily/2026.09.17|agent]]" not in r.stdout, "template link line absent from payload")
        check("Read the DORO brief again." in r.stdout and "draft the one-pager" in r.stdout, "visible blocks present")
        check(f"block: {at_block['hash']}" in r.stdout, "fired block named")

        # 2. a private block cannot be the trigger
        r = t.agent("context", "--trigger", "question", "--hash", priv["hash"], "--date", "2026.09.17")
        check(r.returncode != 0, "private block refused as trigger")

        # 3. run: note untouched, artifacts written, knowledge guarded
        before = (t.note.read_bytes(), t.note.stat().st_mtime_ns)
        t.set_reply(reply="You said the brief was unclear.",
                    proposals=[{"kind": "deadline", "title": "one-pager", "when": "friday", "subject": "DORO"}],
                    suggestions=[{"text": "book a slot", "evidence": "one-pager due friday"}],
                    knowledge=[{"file": "subjects/DORO.md", "content": "one-pager due friday"},
                               {"file": "../../../escape.md", "content": "nope"},
                               {"file": "profile.md", "content": "student of IT-U"}])
        r = t.agent("run", "--trigger", "mention", "--hash", at_block["hash"], "--date", "2026.09.17")
        check(r.returncode == 0, f"run exits 0 ({r.stderr.strip()})")
        after = (t.note.read_bytes(), t.note.stat().st_mtime_ns)
        check(before == after, "daily note bytes and mtime untouched by a run")
        sent = (t.stub_dir / "last_payload.md").read_text()
        check("SECRET-PRIVATE-LINE" not in sent, "model received no private text")
        tr = t.vault / "agents" / "student" / "daily" / "2026.09.17.md"
        st = t.vault / "agents" / "student" / "daily" / "2026.09.17.json"
        check(tr.exists() and "You said the brief was unclear." in tr.read_text(), "transcript written with reply")
        check("add deadline: one-pager — friday · DORO" in tr.read_text(), "proposal rendered as a checkbox")
        s = json.loads(st.read_text())
        check(s["blocks"][at_block["hash"]]["state"] == "reply", "state marks fired block as reply")
        check(all(b["hash"] in s["blocks"] for b in blks if not b["private"] and "|agent]]" not in b["text"]),
              "every visible block marked seen")
        check(priv["hash"] not in s["blocks"], "private block not in state")
        check(s["blocks"][at_block["hash"]]["session"] == "ses_stub", "session id kept for dive-in")
        check((t.vault / "agents/student/knowledge/subjects/DORO.md").read_text() == "one-pager due friday\n",
              "knowledge file written")
        check((t.vault / "agents/student/knowledge/profile.md").exists(), "profile written")
        check(not (t.vault / "escape.md").exists() and not (t.tmp / "escape.md").exists(), "path escape ignored")
        ledger = (t.state_home / "omarchy-student" / "cost.tsv").read_text().splitlines()
        check(len(ledger) == 2 and "0.000200" in ledger[1], "cost ledger has one run")
        payloads = list((t.state_home / "omarchy-student" / "payloads").glob("*.md"))
        check(len(payloads) == 1 and "SECRET-PRIVATE-LINE" not in payloads[0].read_text(), "payload logged, clean")

        # 4. open with nothing new → no model call
        (t.stub_dir / "last_payload.md").unlink()
        r = t.agent("run", "--trigger", "open", "--date", "2026.09.17")
        check(r.returncode == 0 and "nothing new" in r.stdout, "open pass skips when nothing changed")
        check(not (t.stub_dir / "last_payload.md").exists(), "no model call on a quiet open")

        # 5. private day → refused
        t.note.write_text(NOTE.replace("agent: true", "agent: false"))
        r = t.agent("context", "--trigger", "open", "--date", "2026.09.17")
        check(r.returncode != 0 and "agent: false" in r.stderr, "agent: false day refused")

        # 6. stray editor: hash of an edited block no longer matches → refused, no run
        t.note.write_text(NOTE)
        r = t.agent("run", "--trigger", "question", "--hash", "deadbeef", "--date", "2026.09.17")
        check(r.returncode != 0, "unknown block hash refused")
    finally:
        t.cleanup()

    print("FAIL" if fails else "PASS")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
