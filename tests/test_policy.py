"""Deterministic risk-routing regression fixtures."""
import importlib.util
from pathlib import Path
import unittest

PATH=Path(__file__).resolve().parents[1]/"plugins/storyforge/scripts/bits-policy.py"
spec=importlib.util.spec_from_file_location("bits_policy",PATH)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

class PolicyTests(unittest.TestCase):
    def test_docs_are_fast(self):
        self.assertEqual(mod.classify("Fix typo",["README.md"],"auto")["mode"],"fast")
    def test_login_redirect_is_strict(self):
        self.assertEqual(mod.classify("Fix login redirect",["src/login.ts"],"fast")["mode"],"strict")
    def test_security_policy_doc_is_strict(self):
        self.assertEqual(mod.classify("Update file",["SECURITY.md"],"fast")["mode"],"strict")
    def test_one_line_auth_is_strict(self):
        self.assertEqual(mod.classify("Fix a one-line login auth check",["src/login.ts"],"fast")["mode"],"strict")
    def test_migrations_are_strict(self):
        self.assertEqual(mod.classify("Rename a field",["db/migrations/001.sql"],"auto")["mode"],"strict")
    def test_policy_files_are_strict(self):
        self.assertEqual(mod.classify("Improve config",[".github/workflows/ci.yml"],"fast")["mode"],"strict")
    def test_api_is_standard(self):
        self.assertEqual(mod.classify("Add paginated endpoint",["src/orders.ts"],"auto")["mode"],"standard")
    def test_user_may_choose_stricter(self):
        self.assertEqual(mod.classify("Update README",["README.md"],"strict")["mode"],"strict")
