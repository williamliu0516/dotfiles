#!/usr/bin/env python3
"""claude-sims 的测试：假的 simctl / ps，不碰真的模拟器。

  python3 ~/.dotfiles/dev/claude-sims-test.py
"""
import importlib.machinery
import importlib.util
import json
import os
import sys
import tempfile
import time
import unittest
from datetime import datetime, timezone

sys.dont_write_bytecode = True
os.environ["CLAUDE_SIMS_DIR"] = tempfile.mkdtemp(prefix="claude-sims-test-")
_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", "claude-sims")
_loader = importlib.machinery.SourceFileLoader("claude_sims", _path)
_spec = importlib.util.spec_from_loader("claude_sims", _loader)
cs = importlib.util.module_from_spec(_spec)
_loader.exec_module(cs)

NOW = time.time()
U1 = "38A8D6B0-0000-4000-8000-000000000001"


def iso(t):
    return datetime.fromtimestamp(int(t), timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sim(udid=U1, name="reel upgrade check", booted_ago=60):
    return {"udid": udid, "name": name, "state": "Booted", "lastUsedAt": iso(NOW - booted_ago)}


# 两个 Claude Code：A（pid 100）、B（pid 200），各自一个 zsh
BASE = {
    1: (0, "boot", "/sbin/launchd"),
    99: (1, "w", "/Users/hermes/.local/share/claude-img/claude"),
    100: (99, "A", "claude"),
    101: (100, "a", "/bin/zsh -c eval 'sleep 600'"),
    200: (1, "B", "claude --resume x"),
    201: (200, "b", "/bin/zsh -c eval 'scripts/upgrade-check.sh'"),
    202: (201, "b2", "/bin/bash scripts/upgrade-check.sh"),
}


class T(unittest.TestCase):
    def setUp(self):
        for f in (cs.STATE, cs.LOG):
            if os.path.exists(f):
                os.remove(f)
        self.sims = [sim()]
        self.P = dict(BASE)
        self.downs = []
        cs.devices = lambda timeout=60: ([dict(d) for d in self.sims], {d["name"] for d in self.sims})
        cs.procs = lambda timeout=20: dict(self.P) if self.P is not None else None
        cs.shutdown = lambda d, why: self.downs.append((d["udid"], why))
        cs.my_claude = lambda P: self.me
        cs.DRY = False
        self.me = [100, "A"]

    def owner(self, udid=U1):
        with open(cs.STATE) as f:
            return json.load(f)["owners"].get(udid)

    def post(self, cmd, since=None, t=NOW):
        cs.check(t, {"cmd": cmd, "since": since, "session": "s", "cwd": "/x"})

    def test_text_does_not_claim(self):
        # 2026-10-16 的事故：A 的命令里一堆 boot 字样，B 的脚本开的模拟器不该记到 A 名下
        self.P[203] = (202, "b3", f"xcodebuild test -destination id={U1}")
        self.post("cat <<EOF\nxcrun simctl boot \"$SIM\"\nEOF", since=NOW - 600)
        self.assertEqual(self.owner()["pid"], 200)

    def test_text_alone_no_owner(self):
        # 没有进程在用、A 的命令也没点它的名：谁都不是主人
        self.post("xcrun simctl list devices booted | grep Booted", since=NOW - 600)
        self.assertIsNone(self.owner()["pid"])

    def test_foreground_boot_by_name(self):
        self.post('xcrun simctl boot "reel upgrade check"', since=NOW - 90)
        self.assertEqual(self.owner()["pid"], 100)

    def test_named_but_booted_before_the_command(self):
        # 命令点了它的名，可它在这条命令开始之前就开着了：只是在看它
        self.post(f"xcrun simctl io {U1} screenshot /tmp/a.png", since=NOW - 30)
        self.assertIsNone(self.owner()["pid"])

    def test_two_sessions_unsure_then_idle(self):
        self.P[203] = (202, "b3", f"xcrun simctl spawn {U1} log stream")
        self.P[102] = (101, "a2", f"xcrun simctl io {U1} screenshot x.png")
        cs.check(NOW)
        self.assertIsNone(self.owner()["pid"])
        del self.P[200], self.P[201], self.P[202], self.P[203]  # B 走了
        cs.check(NOW + 60)
        self.assertEqual(self.downs, [])                    # 认不准，不因为会话结束关
        self.assertIsNone(self.owner()["pid"])              # 只剩 A 在用了也不改认 A
        del self.P[102]
        cs.check(NOW + 60 + 44 * 60)
        self.assertEqual(self.downs, [])
        cs.check(NOW + 60 + 46 * 60)
        self.assertEqual(len(self.downs), 1)
        self.assertIn("idle", self.downs[0][1])

    def test_owner_exits(self):
        self.P[203] = (202, "b3", f"xcodebuild test -destination id={U1}")
        cs.check(NOW)
        del self.P[200], self.P[201], self.P[202], self.P[203]
        cs.check(NOW + 60)
        self.assertEqual(len(self.downs), 1)
        self.assertIn("pid 200 exited", self.downs[0][1])

    def test_owner_exits_but_still_used(self):
        self.P[203] = (202, "b3", f"xcodebuild test -destination id={U1}")
        cs.check(NOW)
        del self.P[200], self.P[201], self.P[202]
        self.P[203] = (1, "b3", f"xcodebuild test -destination id={U1}")  # 被 launchd 收养了，还在跑
        cs.check(NOW + 60)
        self.assertEqual(self.downs, [])
        self.assertIsNone(self.owner()["pid"])

    def test_pid_reused(self):
        self.P[203] = (202, "b3", f"xcodebuild test -destination id={U1}")
        cs.check(NOW)
        self.P = {k: v for k, v in BASE.items() if k < 200}
        self.P[200] = (1, "B-new", "claude")  # 同一个 pid，另一个进程
        cs.check(NOW + 60)
        self.assertEqual(len(self.downs), 1)

    def test_clear_keeps_owner(self):
        self.P[103] = (101, "a3", f"xcodebuild test -destination id={U1}")
        cs.check(NOW)
        spawned = []
        real = cs.subprocess.Popen
        cs.subprocess.Popen = lambda *a, **k: spawned.append(a)
        try:
            cs.end({"session_id": "s", "reason": "clear"}, NOW)
            self.assertEqual(spawned, [])
            cs.end({"session_id": "s", "reason": "prompt_input_exit"}, NOW)
            self.assertEqual(len(spawned), 1)
        finally:
            cs.subprocess.Popen = real
        cs.check(NOW + 60)  # /clear 之后 pid 还活着：照样是 A 的，不关
        self.assertEqual(self.owner()["pid"], 100)
        self.assertEqual(self.downs, [])

    def test_old_session_owner_becomes_unsure(self):
        os.makedirs(cs.DIR, exist_ok=True)
        with open(cs.STATE, "w") as f:
            json.dump({"owners": {U1: {"session": "1bb2a51c", "cwd": "/x", "boot": iso(NOW - 3600),
                                       "used": NOW - 60}},
                       "booting": {"1bb2a51c": NOW - 4000}}, f)
        self.sims = [sim(booted_ago=3600)]
        cs.end_pid(4242, "gone")  # 那个 pid 早没了：照样不关，只按闲置
        self.assertEqual(self.downs, [])
        with open(cs.STATE) as f:
            st = json.load(f)
        self.assertNotIn("booting", st)
        self.assertIsNone(st["owners"][U1]["pid"])

    def test_untouched_four_hours(self):
        self.sims = [sim(booted_ago=3 * 3600)]
        cs.check(NOW)
        self.assertEqual(self.downs, [])
        self.sims = [sim(booted_ago=5 * 3600)]
        os.remove(cs.STATE)
        cs.check(NOW)
        self.assertIn("no owner", self.downs[0][1])

    def test_late_toucher_is_not_owner(self):
        # 开机 20 分钟以后才来碰它的，多半是来看一眼的
        self.sims = [sim(booted_ago=30 * 60)]
        self.P[102] = (101, "a2", f"xcrun simctl io {U1} screenshot x.png")
        cs.check(NOW)
        self.assertIsNone(self.owner()["pid"])

    def test_ps_stuck_does_nothing(self):
        self.sims = [sim(booted_ago=10 * 3600)]
        self.P = None
        cs.check(NOW)
        self.assertEqual(self.downs, [])

    def test_dry_run(self):
        self.sims = [sim(booted_ago=10 * 3600)]
        cs.DRY = True
        _, drop, _ = cs.check(NOW, write=False)
        self.assertEqual(len(drop), 1)
        self.assertEqual(self.downs, [])
        self.assertFalse(os.path.exists(cs.STATE))
        self.assertFalse(os.path.exists(cs.LOG))

    def test_slot(self):
        cs.MAX = 3
        self.sims = [sim("U-1", "one"), sim("U-2", "two")]
        self.assertTrue(cs.slot("three", 0))          # 2 台开着：给
        self.assertFalse(cs.slot("four", 0))          # 2 台 + 1 个要开的：满了
        self.assertTrue(cs.slot("three", 0))          # 同一个再要一次：还是它的
        self.assertTrue(cs.slot("U-1", 0))            # 已经开着的：不占位子
        self.sims.append(sim("U-3", "three"))         # three 开起来了，位子换成真的
        self.assertFalse(cs.slot("four", 0))
        with cs.state() as st:
            self.assertEqual(st["slots"], {})
        self.sims.pop()                               # three 关了
        self.assertTrue(cs.slot("four", 0))
        with cs.state() as st:
            st["slots"]["four"] -= cs.SLOT_S + 1      # 给了位子一直没开：收回
        self.assertTrue(cs.slot("five", 0))

    def test_slot_simctl_stuck(self):
        def stuck(timeout=60):
            raise cs.subprocess.TimeoutExpired("xcrun", timeout)
        cs.devices = stuck
        self.assertFalse(cs.slot("one", 0))

    def test_real_claude_not_wrapper(self):
        P = dict(BASE)
        self.assertEqual(cs.claude_of(101, P), [100, "A"])
        self.assertIsNone(cs.claude_of(1, P))


if __name__ == "__main__":
    unittest.main(verbosity=1)
