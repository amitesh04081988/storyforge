"""Regression tests for StoryForge shell gates in a controlled temporary repository."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from helpers import BASH

ROOT = Path(__file__).resolve().parents[1]
HOOKS = ROOT / "plugins/storyforge/hooks"

class GateSafetyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        (self.root / ".storyforge").mkdir()
        (self.root / ".storyforge/phase").write_text("develop")
        (self.root / ".storyforge/story").write_text("20261030-test")
        (self.root / "storyforge.config.json").write_text(json.dumps({
            "test": "", "lint": "true", "typecheck": "true",
            "max_stop_blocks": 2, "scope_lock": True
        }))

    def run_hook(self, script, data=None):
        env = dict(os.environ, CLAUDE_PROJECT_DIR=str(self.root))
        return subprocess.run(
            [BASH, str(HOOKS / script)],
            cwd=self.root, env=env, input=json.dumps(data or {}),
            text=True, capture_output=True
        )

    def test_missing_test_command_blocks_even_when_lint_passes(self):
        result = self.run_hook("stop-gate.sh")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["decision"], "block")
        self.assertIn("required command missing", result.stdout)

    def test_stop_hook_exhaustion_does_not_claim_success(self):
        for _ in range(3):
            result = self.run_hook("stop-gate.sh")
        self.assertTrue((self.root / ".storyforge/gate-blocked").exists())
        self.assertNotIn('"decision":"pass"', result.stdout)

    def test_unfinished_ledger_blocks_stop_until_phase_blocked(self):
        (self.root / ".storyforge/phase").write_text("done")
        env = dict(os.environ, CLAUDE_PROJECT_DIR=str(self.root))
        tasks = HOOKS.parent / "scripts/bits-tasks.sh"
        subprocess.run([BASH, str(tasks), "add", "open item", "--mode", "direct"],
                       cwd=self.root, env=env, check=True, capture_output=True)
        result = self.run_hook("stop-gate.sh")
        self.assertEqual(json.loads(result.stdout)["decision"], "block")
        (self.root / ".storyforge/phase").write_text("blocked")
        self.assertEqual(self.run_hook("stop-gate.sh").stdout.strip(), "")

    def test_outside_project_write_is_denied(self):
        result = self.run_hook("edit-guard.sh", {
            "tool_input": {"file_path": str(self.root.parent / "escape.py")}
        })
        self.assertIn('"permissionDecision": "deny"', result.stdout)

    def test_protected_settings_write_is_denied(self):
        path = self.root / ".claude/settings.json"
        path.parent.mkdir()
        result = self.run_hook("edit-guard.sh", {
            "tool_input": {"file_path": str(path)}
        })
        self.assertIn('"permissionDecision": "deny"', result.stdout)

    def test_nonprotected_write_not_denied(self):
        result = self.run_hook("edit-guard.sh", {
            "tool_input": {"file_path": str(self.root / "src/app.py")}
        })
        self.assertNotIn('"permissionDecision": "deny"', result.stdout)

if __name__ == "__main__":
    unittest.main()
