"""PR readiness and workspace-scope regression fixtures."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
WATCH=ROOT/"plugins/storyforge/scripts/pr-watch.sh"
WORKTREE=ROOT/"plugins/storyforge/scripts/worktree.sh"

class WatchTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.path=Path(self.temp.name)
        binpath=self.path/"bin";binpath.mkdir()
        gh=binpath/"gh"
        gh.write_text("#!/usr/bin/env bash\nprintf '%s\\n' \"$STORYFORGE_TEST_GH\"\n")
        gh.chmod(0o755)
        self.env=dict(os.environ,PATH=str(binpath)+os.pathsep+os.environ.get("PATH",""),
                      STORYFORGE_REQUIRED_CHECKS="regression",STORYFORGE_TEST_GH="")
    def run_watch(self,rollup,required="regression"):
        env=dict(self.env,STORYFORGE_TEST_GH=rollup,STORYFORGE_REQUIRED_CHECKS=required)
        return subprocess.run(["bash",str(WATCH),"1"],env=env,capture_output=True,text=True)
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
        (Path(str(self.path)+".worktrees")).symlink_to(actual,target_is_directory=True)
        p=subprocess.run(["bash",str(WORKTREE),"add","test-task"],cwd=self.path,capture_output=True,text=True)
        self.assertNotEqual(p.returncode,0)

    def test_worktree_rejects_path_traversal(self):
        subprocess.run(["git","init","-q",str(self.path)],check=True)
        p=subprocess.run(["bash",str(WORKTREE),"add","../escape"],cwd=self.path,capture_output=True,text=True)
        self.assertNotEqual(p.returncode,0)
