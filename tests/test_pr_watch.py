"""PR readiness and workspace-scope regression fixtures."""
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest

from helpers import BASH

ROOT=Path(__file__).resolve().parents[1]
WATCH=ROOT/"plugins/storyforge/scripts/pr-watch.sh"
WORKTREE=ROOT/"plugins/storyforge/scripts/worktree.sh"

class WatchTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.path=Path(self.temp.name)
        binpath=self.path/"bin";binpath.mkdir()
        gh=binpath/"gh"
        gh.write_text("#!/usr/bin/env bash\n"
                      "if [ -n \"${STORYFORGE_TEST_GH_JSON:-}\" ]; then\n"
                      "  while [ $# -gt 0 ]; do [ \"$1\" = --jq ] && { expr=\"$2\"; break; }; shift; done\n"
                      "  printf '%s' \"$STORYFORGE_TEST_GH_JSON\" | jq -r \"$expr\"\n"
                      "else printf '%s\\n' \"$STORYFORGE_TEST_GH\"; fi\n")
        gh.chmod(0o755)
        self.env=dict(os.environ,PATH=str(binpath)+os.pathsep+os.environ.get("PATH",""),
                      STORYFORGE_REQUIRED_CHECKS="regression",STORYFORGE_TEST_GH="")
    def run_watch(self,rollup,required="regression"):
        env=dict(self.env,STORYFORGE_TEST_GH=rollup,STORYFORGE_REQUIRED_CHECKS=required)
        return subprocess.run([BASH,str(WATCH),"1"],env=env,capture_output=True,text=True)
    def run_json(self,checks,required="regression",extra=None):
        """Feed raw GitHub JSON through the real filter in pr-watch.sh (needs the jq binary)."""
        import json
        doc=dict({"state":"OPEN","mergeable":"MERGEABLE","reviewDecision":"APPROVED","headRefOid":"abcdef","statusCheckRollup":checks},**(extra or {}))
        env=dict(self.env,STORYFORGE_TEST_GH_JSON=json.dumps(doc),STORYFORGE_REQUIRED_CHECKS=required)
        return subprocess.run([BASH,str(WATCH),"1"],env=env,capture_output=True,text=True)
    @unittest.skipUnless(shutil.which("jq"),"jq is needed to run the real check filter")
    def test_skipped_and_neutral_checks_do_not_block(self):
        p=self.run_json([{"name":"regression","conclusion":"SUCCESS"},{"name":"label","conclusion":"SKIPPED"},{"name":"lint","conclusion":"NEUTRAL"}])
        self.assertEqual(p.returncode,0,p.stdout+p.stderr);self.assertIn("ci=pass",p.stdout)
    @unittest.skipUnless(shutil.which("jq"),"jq is needed to run the real check filter")
    def test_real_failure_is_act_even_without_policy(self):
        p=self.run_json([{"name":"regression","conclusion":"FAILURE"}],required="")
        self.assertEqual(p.returncode,2,p.stdout+p.stderr);self.assertIn("ci=fail",p.stdout)
    @unittest.skipUnless(shutil.which("jq"),"jq is needed to run the real check filter")
    def test_unfinished_check_waits(self):
        p=self.run_json([{"name":"regression","conclusion":"SUCCESS"},{"name":"slow","conclusion":""}])
        self.assertEqual(p.returncode,1,p.stdout+p.stderr);self.assertIn("ci=pending",p.stdout)
    @unittest.skipUnless(shutil.which("jq"),"jq is needed to run the real check filter")
    def test_status_context_states_are_read(self):
        p=self.run_json([{"context":"regression","state":"SUCCESS"}])
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
    @unittest.skipUnless(shutil.which("jq"),"jq is needed to run the real check filter")
    def test_required_name_with_commas(self):
        name="CodeQL-Build (go, manual, ./cfg.yml)"
        p=self.run_json([{"name":name,"conclusion":"SUCCESS"}],required=name+";regression-missing")
        self.assertEqual(p.returncode,1,p.stdout);self.assertIn("missing-required",p.stdout)
        p=self.run_json([{"name":name,"conclusion":"SUCCESS"},{"name":"regression","conclusion":"SUCCESS"}],required=name+";regression")
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
    def test_required_names_split_on_semicolons(self):
        p=self.run_watch("OPEN|MERGEABLE|APPROVED|abcdef|0|0|2|a\x1fb",required="a;b")
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        p=self.run_watch("OPEN|MERGEABLE|APPROVED|abcdef|0|0|2|a\x1fb",required="a;c")
        self.assertEqual(p.returncode,1);self.assertIn("missing-required",p.stdout)
    def test_failing_checks_are_act_even_without_policy(self):
        p=self.run_watch("OPEN|MERGEABLE|APPROVED|abcdef|1|0|1|regression",required="")
        self.assertEqual(p.returncode,2)
    def test_zero_checks_not_ready(self):
        p=self.run_watch("OPEN|MERGEABLE|APPROVED|abcdef|0|0|0|")
        self.assertNotEqual(p.returncode,0);self.assertIn("not-configured",p.stdout)
    def test_all_successful_required_check_ready(self):
        p=self.run_watch("OPEN|MERGEABLE|APPROVED|abcdef|0|0|1|regression")
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
    def test_missing_required_check_waits(self):
        p=self.run_watch("OPEN|MERGEABLE|APPROVED|abcdef|0|0|1|lint")
        self.assertNotEqual(p.returncode,0);self.assertIn("missing-required",p.stdout)
    def test_failed_check_not_ready(self):
        p=self.run_watch("OPEN|MERGEABLE|APPROVED|abcdef|1|0|1|regression")
        self.assertEqual(p.returncode,2)
    def test_pending_check_waits(self):
        p=self.run_watch("OPEN|MERGEABLE|APPROVED|abcdef|0|1|1|regression")
        self.assertEqual(p.returncode,1)
    def test_unconfigured_policy_not_ready(self):
        p=self.run_watch("OPEN|MERGEABLE|APPROVED|abcdef|0|0|1|regression",required="")
        self.assertNotEqual(p.returncode,0)
    def test_worktree_rejects_symlink_root(self):
        subprocess.run(["git","init","-q",str(self.path)],check=True)
        actual=self.path/"elsewhere";actual.mkdir()
        try:
            (Path(str(self.path)+".worktrees")).symlink_to(actual,target_is_directory=True)
        except OSError as error:
            self.skipTest("cannot create symlinks here: %s"%error)
        p=subprocess.run([BASH,str(WORKTREE),"add","test-task"],cwd=self.path,capture_output=True,text=True)
        self.assertNotEqual(p.returncode,0)

    def test_worktree_rejects_path_traversal(self):
        subprocess.run(["git","init","-q",str(self.path)],check=True)
        p=subprocess.run([BASH,str(WORKTREE),"add","../escape"],cwd=self.path,capture_output=True,text=True)
        self.assertNotEqual(p.returncode,0)
